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
	@brief A single-clock FIFO divided into many individual tiny FIFOs
	
	This module logically consists of MAX_THREADS independent FIFOs, each consisting of WORDS_PER_THREAD individual
	WIDTH-bit words.
	
	Status flags are combinatorial, _r are registered
	
	Reset is PER THREAD and requires wr_tid and rd_tid to be tied to the same value.
 */
module MultithreadedSingleClockFifo(
	clk,
	wr_tid,
	rd_tid,
	wr, din,
	rd, dout, peek,
	overflow, underflow,
	overflow_r, underflow_r,
	empty, full, reset
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
    
    parameter WIDTH 			= 32;
	
	parameter MAX_THREADS		= 32;
	parameter WORDS_PER_THREAD	= 8;
	
	`include "clog2.vh"
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	//Number of bits in a pointer for each thread
	localparam ADDR_BITS		= clog2(WORDS_PER_THREAD);
	
	//set true to use block RAM, false for distributed RAM
	parameter USE_BLOCK = 1;
	
	//Specifies the register mode for outputs.
	//When FALSE:
	// * dout updates on the clk edge after a write if the fifo is empty
	// * read dout whenever empty is false, then strobe rd to advance pointer
	//When TRUE:
	// * dout updates on the clk edge after a read when the fifo has data in it
	// * assert rd, read dout the following cycle
	// * dout changes on the next read (even if from another thread)
	parameter OUT_REG		= 1;
	
	//Default if neither is set is to initialize to zero
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	input wire					clk;
	
	input wire[TID_BITS-1 : 0]	wr_tid;
	input wire					wr;
	input wire[WIDTH-1:0]		din;
	
	input wire[TID_BITS-1 : 0]	rd_tid;
	input wire					rd;
	input wire					peek;		//read without touching pointers
	output wire[WIDTH-1:0]		dout;
	
	output reg					overflow_r 	= 0;
	output reg					underflow_r = 0;
	
	output reg					overflow 	= 0;
	output reg					underflow 	= 0;
	
	output reg					empty = 0;
	output reg					full = 0;
	
	input wire					reset;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read and write pointers for each thread
	// Extra bit for full/empty detection
	
	reg							rd_ptr_wr		= 0;
	wire[ADDR_BITS : 0]			rd_ptr;
	wire[ADDR_BITS : 0]			rd_ptr_wport;
	reg[ADDR_BITS : 0]			rd_ptr_next		= 0;
	
	reg							wr_ptr_wr		= 0;
	wire[ADDR_BITS : 0]			wr_ptr;
	wire[ADDR_BITS : 0]			wr_ptr_rport;
	reg[ADDR_BITS : 0]			wr_ptr_next		= 0;
	
	MemoryMacro #(
		.WIDTH(ADDR_BITS + 1),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b0),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) rd_ptr_mem (
		.porta_clk(clk),
		.porta_en(1'b1),
		.porta_addr(rd_tid),
		.porta_we(rd_ptr_wr || reset),
		.porta_din(rd_ptr_next),
		.porta_dout(rd_ptr),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(wr_tid),
		.portb_we(1'b0),
		.portb_din({ADDR_BITS+1{1'b0}}),
		.portb_dout(rd_ptr_wport)
	);
	
	MemoryMacro #(
		.WIDTH(ADDR_BITS + 1),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b0),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) wr_ptr_mem (
		.porta_clk(clk),
		.porta_en(1'b1),
		.porta_addr(wr_tid),
		.porta_we(wr_ptr_wr || reset),
		.porta_din(wr_ptr_next),
		.porta_dout(wr_ptr),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(rd_tid),
		.portb_we(1'b0),
		.portb_din({ADDR_BITS+1{1'b0}}),
		.portb_dout(wr_ptr_rport)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual data memory
	
	MemoryMacro #(
		.WIDTH(WIDTH),
		.DEPTH(MAX_THREADS * WORDS_PER_THREAD),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(USE_BLOCK),
		.OUT_REG(OUT_REG),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) mem (
		.porta_clk(clk),
		.porta_en(wr),
		.porta_addr({wr_tid, wr_ptr[ADDR_BITS-1 : 0]}),
		.porta_we(wr),
		.porta_din(din),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(rd || peek),
		.portb_addr({rd_tid, rd_ptr[ADDR_BITS-1 : 0]}),
		.portb_we(1'b0),
		.portb_din({WIDTH{1'b0}}),
		.portb_dout(dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Control logic
	
	always @(*) begin
	
		//Always incrementing pointers, can never decrement
		wr_ptr_next		<= wr_ptr + 1'h1;
		rd_ptr_next		<= rd_ptr + 1'h1;
		
		//If resetting, set pointers to zero
		if(reset) begin
			wr_ptr_next	<= 0;
			rd_ptr_next	<= 0;
		end
	
		//Compute status flags
		//empty is referenced to read port
		//full is referenced to write port
		empty			<= (rd_ptr == wr_ptr_rport);
		full			<= (wr_ptr == rd_ptr_wport + WORDS_PER_THREAD);
		
		//Compute under/overflow flags
		underflow		<= rd && empty;
		overflow		<= wr && full;
		
		//Write to pointers if reading/writing and not erroring
		wr_ptr_wr		<= wr && !full;
		rd_ptr_wr		<= rd && !empty;
		
	end
	
	always @(posedge clk) begin
		overflow_r		<= overflow;
		underflow_r		<= underflow;
	end
    
endmodule
