`timescale 1ns / 1ps
`default_nettype none
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
	@brief Pipeline status flags for SaratogaCPUThreadScheduler
	
	ENTRY PORT
	Each clock cycle, if entry_en is set, check if threads[entry_tid] is currently in the pipeline and set entry_inpipe
	accordingly. If it is *not* already in the pipeline, mark it as in the pipeline.
	
	EXIT PORT
	Each clock cycle, if exit_en is set, mark threads[exit_tid] as no longer in the pipeline.
 */
module SaratogaCPUThreadScheduler_PipelineStatus(
	clk,
	entry_en, entry_tid, entry_inpipe,
	exit_en, exit_tid
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
	
	//Clock
	input wire					clk;
	
	//Entry port
	input wire					entry_en;
	input wire[TID_BITS-1 : 0]	entry_tid;
	output reg					entry_inpipe;
	
	//Exit port
	input wire					exit_en;
	input wire[TID_BITS-1 : 0]	exit_tid;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Forwarding logic to handle simultaneous entry and exit (legal)
	
	reg							entry_en_fwd;
	reg							exit_en_fwd;
	wire						entry_inpipe_raw;
	
	always @(*) begin
		entry_en_fwd		<= entry_en;
		exit_en_fwd			<= exit_en;
		entry_inpipe		<= entry_inpipe_raw;
		
		//If entering and leaving with same TID, don't touch the memory.
		//We have leave-before-enter semantics, meaning that this is considered "not busy"
		if( (entry_tid == exit_tid) && entry_en && exit_en) begin
			entry_en_fwd	<= 0;
			exit_en_fwd		<= 0;
			entry_inpipe	<= 0;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The memory
	
	MultiportMemoryMacro #(
		.WIDTH(1),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) mem (
		.clk(clk),
		
		.wr_en(  {entry_en_fwd,  exit_en_fwd}),
		.wr_addr({entry_tid, exit_tid}),
		.wr_data({1'b1,      1'b0}),
		
		.rd_en(entry_en),
		.rd_addr(entry_tid),
		.rd_data(entry_inpipe_raw)
		
	);
	
endmodule
