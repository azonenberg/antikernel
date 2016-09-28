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
	@brief The MMU for the CPU
	
	0x4000 0000 = base address
	
	512 2KB pages (1MB) of virtual address space
	
	Each page maps to a (physical address, noc address, permissions) tuple
	
	512 pages = 9 bits
	Each page is 2048 (2^11) bits - 19:11
	
	39:37 = r|w|x bits
	36:21 = NOC address of host
	20:0  = physical address within host (left aligned)
 */
module GraftonCPUMMU(
	clk,
	translate_en, vaddr, phyaddr, nocaddr, permissions, invalid,
	mmu_wr_en, mmu_wr_page_id, mmu_wr_phyaddr, mmu_wr_nocaddr, mmu_wr_permissions
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//Address translation
	input wire translate_en;
	input wire[31:0] vaddr;
	output wire[31:0] phyaddr;
	output wire[15:0] nocaddr;
	output wire[2:0] permissions;
	output wire invalid;
	
	//Control interface
	input wire mmu_wr_en;
	input wire[8:0] mmu_wr_page_id;
	input wire[31:0] mmu_wr_phyaddr;
	input wire[15:0] mmu_wr_nocaddr;
	input wire[2:0] mmu_wr_permissions;
	
	//Initialization
	parameter bootloader_host = 16'h0000;
	parameter bootloader_addr = 32'h00000000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory bank
	
	reg[39:0] mmu_data[511:0];
	
	integer i;
	initial begin
		for(i=1; i<512; i=i+1) begin
			mmu_data[i] <= 0;
		end
		
		//Boot loader is r/x only
		mmu_data[0] <= { 3'b101, bootloader_host, bootloader_addr[31:11]};
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read logic
	
	reg[10:0] page_offset = 0;
	
	reg[31:0] vaddr_buf = 0;
	reg[39:0] mmu_dout = 0;
	always @(posedge clk) begin
		vaddr_buf <= vaddr;
		if(translate_en) begin
			mmu_dout <= mmu_data[vaddr[19:11]];
			page_offset <= vaddr[10:0];
		end
	end
	
	assign invalid = (vaddr_buf[31:20] != 12'h400);
	assign permissions = mmu_dout[39:37];
	assign nocaddr = mmu_dout[36:21];
	assign phyaddr = {mmu_dout[20:0], page_offset};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Write logic
	
	always @(posedge clk) begin
		if(mmu_wr_en) begin
			mmu_data[mmu_wr_page_id] <= {mmu_wr_permissions, mmu_wr_nocaddr, mmu_wr_phyaddr[31:11]};
			
			//synthesis translate_off
			$display("[GraftonCPUMMU] Mapping 0x%08x from host %08x to page %x (permissions %o)",
				mmu_wr_phyaddr, mmu_wr_nocaddr, mmu_wr_page_id, mmu_wr_permissions);
			//synthesis translate_on
		end
	end
	
endmodule
