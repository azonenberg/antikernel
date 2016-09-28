`default_nettype none
`timescale 1ns / 1ps
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2016 Andrew D. Zonenberg                                                                          *
* All rights reserved.                                                                                                 *
*                                                                                                                      *
* Redistribution and use in source and binary forms, with or without modification, are permitted provided that the     *
* following conditions are met:                                                                                        *
*                                                                                                                      *
*    * Redistributions of source code must retain the above copyright notice, this list of conditions, and the         *
*      following disclaimer.                                                                                           *
*                                                                                                                      *
*    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the       *
*      following disclaimer in the documentation and/or other materials provided with the distribution.                *
*                                                                                                                      *
*    * Neither the name of the author nor the names of any contributors may be used to endorse or promote products     *
*      derived from this software without specific prior written permission.                                           *
*                                                                                                                      *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   *
* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL *
* THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES        *
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR       *
* BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE       *
* POSSIBILITY OF SUCH DAMAGE.                                                                                          *
*                                                                                                                      *
***********************************************************************************************************************/

/**
	@file
	@author Andrew D. Zonenberg
	@brief MMU SARATOGA CPU
	
	For now it's just a TLB that isn't backed by an external page table.
	
	For now, all pages must be mapped starting at virtual address 0x40000000. The legal virtual address range is from
	0x40000000 to 0x40000000 + PAGES_PER_THREAD*0x800.
	
	Translation interface:
		Assert translate_en while setting translate_tid, translate_vaddr, and translate_perms
		Wait for translate_done to go high
		Read status
		
	Management interface
		Assert mgmt_wr_en with write data valid
		Wait for mgmt_wr_done to go high before doing another write
 */
module SaratogaCPUMMU(
	clk,
	translate_en, translate_tid, translate_vaddr, translate_perms, translate_nocaddr, translate_phyaddr,
		translate_done, translate_failed,
	mgmt_wr_en, mgmt_wr_tid, mgmt_wr_valid, mgmt_wr_perms, mgmt_wr_vaddr, mgmt_wr_nocaddr, mgmt_wr_phyaddr,
		mgmt_wr_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	//Number of pages per thread
	parameter PAGES_PER_THREAD	= 32;
	
	//Number of bits in a page ID
	localparam PAGE_ID_BITS		= clog2(PAGES_PER_THREAD);
	
	//Low bit of a page ID
	localparam PAGE_BIT_LOW		= 11;
	
	//High bit of a page ID
	localparam PAGE_BIT_HIGH	= PAGE_BIT_LOW + PAGE_ID_BITS - 1;
	
	//Memory depth
	localparam DEPTH			= PAGES_PER_THREAD * MAX_THREADS;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	//Translation interface
	input wire					translate_en;
	input wire[TID_BITS-1 : 0]	translate_tid;
	input wire[31:0]			translate_vaddr;
	input wire[2:0]				translate_perms;
	output reg[15:0]			translate_nocaddr	= 0;
	output reg[31:0]			translate_phyaddr	= 0;
	output reg					translate_done		= 0;
	output reg					translate_failed	= 0;
	
	//Management interface
	input wire					mgmt_wr_en;
	input wire[TID_BITS-1 : 0]	mgmt_wr_tid;
	input wire					mgmt_wr_valid;
	input wire[2:0]				mgmt_wr_perms;
	input wire[31:0]			mgmt_wr_vaddr;
	input wire[15:0]			mgmt_wr_nocaddr;
	input wire[31:0]			mgmt_wr_phyaddr;
	output reg					mgmt_wr_done		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual page table
	
	/*
		Page table format
		63:41			Reserved
		40				Valid bit
		39:37			RWX permission flags
		36:16			Physical page ID within node
		15:0			Node ID
	 */
	 
	wire[63:0]	mmu_rdata;
	
	MemoryMacro #(
		.WIDTH(64),
		.DEPTH(DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) pagetable (
		.porta_clk(clk),
		.porta_en(mgmt_wr_en) ,
		.porta_addr({mgmt_wr_tid, mgmt_wr_vaddr[PAGE_BIT_HIGH:PAGE_BIT_LOW]}),
		.porta_we(mgmt_wr_en),
		.porta_din({23'h0, mgmt_wr_valid, mgmt_wr_perms, mgmt_wr_phyaddr[31:PAGE_BIT_LOW], mgmt_wr_nocaddr}),
		.porta_dout(),
	
		.portb_clk(clk),
		.portb_en(translate_en),
		.portb_addr({translate_tid, translate_vaddr[PAGE_BIT_HIGH:PAGE_BIT_LOW]}),
		.portb_we(1'b0),
		.portb_din(64'h0),
		.portb_dout(mmu_rdata)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state logic
	
	reg			translate_en_ff		= 0;
	reg[2:0]	translate_perms_ff	= 0;
	reg[31:0]	translate_vaddr_ff	= 0;
	
	//Extract fields
	wire			mmu_rdata_valid	= mmu_rdata[40];
	wire[2:0]		mmu_rdata_perms	= mmu_rdata[39:37];
	wire[20:0]		mmu_rdata_page	= mmu_rdata[36:16];
	wire[15:0]		mmu_rdata_host	= mmu_rdata[15:0];
	
	always @(posedge clk) begin
		translate_en_ff		<= translate_en;
		translate_perms_ff	<= translate_perms;
		translate_vaddr_ff	<= translate_vaddr;
		
		mgmt_wr_done		<= mgmt_wr_en;
		
		translate_failed	<= 0;
		
		//Done one cycle after the read
		translate_done		<= translate_en_ff;
		
		if(translate_en_ff) begin
		
			//Output results regardless of success/fail status
			translate_nocaddr	<= mmu_rdata_host;
			translate_phyaddr	<= { mmu_rdata_page, translate_vaddr_ff[10:0] };
			
			//All good, output the results
			if(mmu_rdata_valid &&													//TLB line is valid
				(translate_perms_ff == (translate_perms_ff & mmu_rdata_perms)) &&	//permissions match what we asked for
				(translate_vaddr_ff[31:28] == 4'h4) &&								//in mapped address space
				(translate_vaddr_ff[27 : PAGE_BIT_HIGH + 1] == 0)					//in mapped address space
				) begin
				
			end
			
			//If the entry is invalid, or permissions don't match, fail
			else
				translate_failed	<= 1;
			
		end
		
	end

endmodule
