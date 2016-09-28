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
	@brief Arbiter for MMU write requests between RPC subsystem and bootloader
 */
module SaratogaCPUMMUArbiter(
	clk,

	mmu_mgmt_wr_en, mmu_mgmt_wr_tid, mmu_mgmt_wr_valid, mmu_mgmt_wr_perms,
		mmu_mgmt_wr_vaddr, mmu_mgmt_wr_nocaddr, mmu_mgmt_wr_phyaddr, mmu_mgmt_wr_done,
		
	bootloader_mmu_wr_en, bootloader_mmu_wr_tid, bootloader_mmu_wr_valid, bootloader_mmu_wr_perms,
		bootloader_mmu_wr_vaddr, bootloader_mmu_wr_nocaddr, bootloader_mmu_wr_phyaddr, bootloader_mmu_wr_done,
		
	rpc_mmu_wr_en, rpc_mmu_wr_tid, rpc_mmu_wr_valid, rpc_mmu_wr_perms,
		rpc_mmu_wr_vaddr, rpc_mmu_wr_nocaddr, rpc_mmu_wr_phyaddr, rpc_mmu_wr_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;
	
	//Bus to MMU
	output reg					mmu_mgmt_wr_en		= 0;
	output reg[TID_BITS-1 : 0]	mmu_mgmt_wr_tid		= 0;
	output reg					mmu_mgmt_wr_valid	= 0;
	output reg[2:0]				mmu_mgmt_wr_perms	= 0;
	output reg[31:0]			mmu_mgmt_wr_vaddr	= 0;
	output reg[15:0]			mmu_mgmt_wr_nocaddr	= 0;
	output reg[31:0]			mmu_mgmt_wr_phyaddr	= 0;
	input wire					mmu_mgmt_wr_done;
	
	//Bus to bootloader
	input wire					bootloader_mmu_wr_en;
	input wire[TID_BITS-1 : 0]	bootloader_mmu_wr_tid;
	input wire					bootloader_mmu_wr_valid;
	input wire[2:0]				bootloader_mmu_wr_perms;
	input wire[31:0]			bootloader_mmu_wr_vaddr;
	input wire[15:0]			bootloader_mmu_wr_nocaddr;
	input wire[31:0]			bootloader_mmu_wr_phyaddr;
	output reg					bootloader_mmu_wr_done	= 0;
	
	//Bus to RPC subsystem
	input wire					rpc_mmu_wr_en;
	input wire[TID_BITS-1 : 0]	rpc_mmu_wr_tid;
	input wire					rpc_mmu_wr_valid;
	input wire[2:0]				rpc_mmu_wr_perms;
	input wire[31:0]			rpc_mmu_wr_vaddr;
	input wire[15:0]			rpc_mmu_wr_nocaddr;
	input wire[31:0]			rpc_mmu_wr_phyaddr;
	output reg					rpc_mmu_wr_done	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//Main state logic
	
	reg		bootloader_active	= 0;
	reg		rpc_active			= 0;
	
	//Register pending writes
	reg					bootloader_pending_en		= 0;
	reg[TID_BITS-1 : 0]	bootloader_pending_tid		= 0;
	reg					bootloader_pending_valid	= 0;
	reg[2:0]			bootloader_pending_perms	= 0;
	reg[31:0]			bootloader_pending_vaddr	= 0;
	reg[15:0]			bootloader_pending_nocaddr	= 0;
	reg[31:0]			bootloader_pending_phyaddr	= 0;
	
	reg					rpc_pending_en		= 0;
	reg[TID_BITS-1 : 0]	rpc_pending_tid		= 0;
	reg					rpc_pending_valid	= 0;
	reg[2:0]			rpc_pending_perms	= 0;
	reg[31:0]			rpc_pending_vaddr	= 0;
	reg[15:0]			rpc_pending_nocaddr	= 0;
	reg[31:0]			rpc_pending_phyaddr	= 0;
	
	always @(posedge clk) begin
	
		rpc_mmu_wr_done			<= 0;
		bootloader_mmu_wr_done	<= 0;
		
		mmu_mgmt_wr_en			<= 0;
		mmu_mgmt_wr_tid			<= 0;
		mmu_mgmt_wr_valid		<= 0;
		mmu_mgmt_wr_perms		<= 0;
		mmu_mgmt_wr_vaddr		<= 0;
		mmu_mgmt_wr_nocaddr		<= 0;
		mmu_mgmt_wr_phyaddr		<= 0;
	
		//Register pending writes
		if(!bootloader_active && bootloader_mmu_wr_en) begin
			bootloader_pending_en		<= 1;
			bootloader_pending_tid		<= bootloader_mmu_wr_tid;
			bootloader_pending_valid	<= bootloader_mmu_wr_valid;
			bootloader_pending_perms	<= bootloader_mmu_wr_perms;
			bootloader_pending_vaddr	<= bootloader_mmu_wr_vaddr;
			bootloader_pending_nocaddr	<= bootloader_mmu_wr_nocaddr;
			bootloader_pending_phyaddr	<= bootloader_mmu_wr_phyaddr;
		end
		
		if(!rpc_active && rpc_mmu_wr_en) begin
			rpc_pending_en		<= 1;
			rpc_pending_tid		<= rpc_mmu_wr_tid;
			rpc_pending_valid	<= rpc_mmu_wr_valid;
			rpc_pending_perms	<= rpc_mmu_wr_perms;
			rpc_pending_vaddr	<= rpc_mmu_wr_vaddr;
			rpc_pending_nocaddr	<= rpc_mmu_wr_nocaddr;
			rpc_pending_phyaddr	<= rpc_mmu_wr_phyaddr;
		end
		
		//Completion of writes
		if(mmu_mgmt_wr_done && rpc_active) begin
			rpc_active		<= 0;
			rpc_mmu_wr_done	<= 1;
		end
		
		//Completion of writes
		if(mmu_mgmt_wr_done && bootloader_active) begin
			bootloader_active		<= 0;
			bootloader_mmu_wr_done	<= 1;
		end
		
		//Start a write if something is pending and nothing is active
		if(!bootloader_active && !rpc_active) begin
			if(bootloader_pending_en) begin
				bootloader_pending_en	<= 0;
				bootloader_active		<= 1;
				mmu_mgmt_wr_en			<= 1;
				mmu_mgmt_wr_tid			<= bootloader_pending_tid;
				mmu_mgmt_wr_valid		<= bootloader_pending_valid;
				mmu_mgmt_wr_perms		<= bootloader_pending_perms;
				mmu_mgmt_wr_vaddr		<= bootloader_pending_vaddr;
				mmu_mgmt_wr_nocaddr		<= bootloader_pending_nocaddr;
				mmu_mgmt_wr_phyaddr		<= bootloader_pending_phyaddr;
			end
			else if(rpc_pending_en) begin
				rpc_pending_en			<= 0;
				rpc_active				<= 1;
				mmu_mgmt_wr_en			<= 1;
				mmu_mgmt_wr_tid			<= rpc_pending_tid;
				mmu_mgmt_wr_valid		<= rpc_pending_valid;
				mmu_mgmt_wr_perms		<= rpc_pending_perms;
				mmu_mgmt_wr_vaddr		<= rpc_pending_vaddr;
				mmu_mgmt_wr_nocaddr		<= rpc_pending_nocaddr;
				mmu_mgmt_wr_phyaddr		<= rpc_pending_phyaddr;
			end
		end
	
	end
	
endmodule
