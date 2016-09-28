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
	@brief Program counters and fetch logic
 */
module SaratogaCPUProgramCounters(
	clk,
	bootloader_pc_wr, bootloader_pc_tid, bootloader_pc_addr,
	ifetch0_thread_active, ifetch0_tid,
	ifetch0_iside_rd, ifetch0_iside_addr,
	ifetch1_pc, decode0_pc, decode1_pc, exec0_pc, exec0_pcp4, exec1_pc, exec2_pc, exec3_pc,
	exec2_tid, exec2_pc_we, exec2_pc_wdata
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS	= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS		= clog2(MAX_THREADS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk;
	
	//Inputs for IFETCH0 stage (current thread context)
	input wire					ifetch0_thread_active;
	input wire[TID_BITS-1 : 0]	ifetch0_tid;
	
	//Inputs from bootloader
	input wire					bootloader_pc_wr;
	input wire[TID_BITS-1:0]	bootloader_pc_tid;
	input wire[31:0]			bootloader_pc_addr;
	
	//Outputs for IFETCH0 stage (fetch address to I-side L1 cache)
	output wire					ifetch0_iside_rd;
	output wire[31:0]			ifetch0_iside_addr;
	
	//Outputs for other pipeline stages (program counters)
	output reg[31:0]			ifetch1_pc = 0;
	(* MAX_FANOUT = "reduce" *)
	output reg[31:0]			decode0_pc = 0;
	output reg[31:0]			decode1_pc = 0;
	output reg[31:0]			exec0_pc = 0;
	output reg[31:0]			exec0_pcp4 = 0;
	output reg[31:0]			exec1_pc = 0;
	output reg[31:0]			exec2_pc = 0;
	output reg[31:0]			exec3_pc = 0;
	
	//Inputs for EXEC3 stage - new program counter
	input wire[TID_BITS-1 : 0]	exec2_tid;
	input wire					exec2_pc_we;
	input wire[31:0]			exec2_pc_wdata;
	
	assign ifetch0_iside_rd		= ifetch0_thread_active;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Program counter storage
	
	MultiportMemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(32'hcccccccc)	//initialize to invalid
	) pc_mem (
		.clk(clk),
		.wr_en({exec2_pc_we, bootloader_pc_wr}),
		.wr_addr({exec2_tid, bootloader_pc_tid}),
		.wr_data({exec2_pc_wdata, bootloader_pc_addr}),
		.rd_en(ifetch0_thread_active),
		.rd_addr(ifetch0_tid),
		.rd_data(ifetch0_iside_addr)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push current counter values down the pipeline
	
	always @(posedge clk) begin
		ifetch1_pc	<= ifetch0_iside_addr;
		decode0_pc	<= ifetch1_pc;
		decode1_pc	<= decode0_pc;
		exec0_pc	<= decode1_pc;
		exec0_pcp4	<= decode1_pc + 32'h4;
		exec1_pc	<= exec0_pc;
		exec2_pc	<= exec1_pc;
		exec3_pc	<= exec2_pc;
	end
	
endmodule
