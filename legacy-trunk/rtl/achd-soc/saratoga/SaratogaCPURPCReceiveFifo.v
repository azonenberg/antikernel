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
	@brief The FIFO for incoming packets destined to a particular thread
	
	WRITE procedure:
		* Assert wr_en, wr_tid, wr_data when a message arrives
		* If wr_overflow goes high the following cycle, the message was dropped
		  (CPU should deal with this at some point. Segfault app? Return error?)
		
	READ procedure:
		* Assert rd_en and rd_tid
		* Next cycle, check rd_valid is high
		* Next cycle, if rd_valid was high, rd_data is valid, else fifo was empty
		
	rd_peek is used to read without touching fifo pointers
 */
module SaratogaCPURPCReceiveFifo(
	clk,
	wr_en, wr_tid, wr_data, wr_overflow,
	rd_en, rd_tid, rd_data, rd_valid, rd_peek
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Our address
	parameter NOC_ADDR				= 16'h0;
	
	//Number of thread contexts
	parameter MAX_THREADS			= 32;
	
	//Number of messages per thread to store in the FIFO
	parameter MESSAGES_PER_THREAD	= 16;
	
	//Number of bits in a thread ID
	localparam TID_BITS				= clog2(MAX_THREADS);
	
	//Number of bits in the address bus
	localparam ADDR_BITS 			= clog2(MESSAGES_PER_THREAD) + 1;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clock
	input wire					clk;
	
	//Incoming data
	input wire					wr_en;
	input wire[TID_BITS-1 : 0]	wr_tid;
	input wire[127:0]			wr_data;
	output reg					wr_overflow		= 0;
	
	//Outbound data
	input wire					rd_peek;
	input wire					rd_en;
	input wire[TID_BITS-1 : 0]	rd_tid;
	output wire[127:0]			rd_data;
	output reg					rd_valid		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Address pointers (default all to zero = empty)
	
	reg						rd_ptr_wr	= 0;
	wire[ADDR_BITS-1 : 0]	rd_ptr_cur;
	wire[ADDR_BITS-1 : 0]	rd_ptr_wcur;
	reg[ADDR_BITS-1 : 0]	rd_ptr_next	= 0;
	
	MemoryMacro #(
		.WIDTH(ADDR_BITS),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(0),
		.INIT_VALUE(0)
	) read_ptr_mem (
		
		.porta_clk(clk),
		.porta_en(1'b1),
		.porta_addr(rd_tid),
		.porta_we(rd_ptr_wr),
		.porta_din(rd_ptr_next),
		.porta_dout(rd_ptr_cur),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(wr_tid),
		.portb_we(1'b0),
		.portb_din({ADDR_BITS{1'b0}}),
		.portb_dout(rd_ptr_wcur)
	);
	
	reg						wr_ptr_wr	= 0;
	wire[ADDR_BITS-1 : 0]	wr_ptr_cur;
	wire[ADDR_BITS-1 : 0]	wr_ptr_rcur;
	reg[ADDR_BITS-1 : 0]	wr_ptr_next	= 0;
	
	MemoryMacro #(
		.WIDTH(ADDR_BITS),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(0),
		.INIT_VALUE(0)
	) write_ptr_mem (
		
		.porta_clk(clk),
		.porta_en(1'b1),
		.porta_addr(wr_tid),
		.porta_we(wr_ptr_wr),
		.porta_din(wr_ptr_next),
		.porta_dout(wr_ptr_cur),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(rd_tid),
		.portb_we(1'b0),
		.portb_din({ADDR_BITS{1'b0}}),
		.portb_dout(wr_ptr_rcur)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Control logic
	
	reg[ADDR_BITS-1 : 0]	rd_size	= 0;
	reg[ADDR_BITS-1 : 0]	wr_size	= 0;
	
	reg						rd_empty		= 0;
	reg						wr_full			= 0;
	
	//Control flags to main memory
	reg						rd_en_real		= 0;
	reg						wr_en_real		= 0;

	always @(*) begin
		
		//Get read/write size values
		rd_size				<= wr_ptr_rcur - rd_ptr_cur;
		wr_size				<= MESSAGES_PER_THREAD[ADDR_BITS-1 : 0] + rd_ptr_wcur - wr_ptr_cur;
		
		//Get empty/full status
		rd_empty			<= wr_ptr_rcur == rd_ptr_cur;
		wr_full				<= wr_ptr_cur == (rd_ptr_wcur + MESSAGES_PER_THREAD);
		
		//Update write pointer if we just wrote something
		wr_ptr_wr			<= (wr_en && !wr_full);
		wr_ptr_next			<= wr_ptr_cur + 1'd1;
		
		//Update read pointer if we just read something
		rd_ptr_wr			<= (rd_en && !rd_empty && !rd_peek);
		rd_ptr_next			<= rd_ptr_cur + 1'd1;
		
		//Enable writes if we have data to write, and there's room for it
		wr_en_real			<= wr_en && !wr_full;
		
		//Enable reads if we have data to read
		rd_en_real			<= rd_en && !rd_empty;
		
	end
		
	always @(posedge clk) begin

		//Set overflow flag if we just pushed a write that won't fit
		wr_overflow			<= (wr_en && wr_full);
		
		//Set valid flag one cycle BEFORE read data is ready due to BRAM latency!
		rd_valid			<= rd_en_real;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The main memory array
	
	MemoryMacro #(
		.WIDTH(128),
		.DEPTH(MAX_THREADS * MESSAGES_PER_THREAD),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(0),
		.INIT_VALUE(128'h0)
	) mem (
		.porta_clk(clk),
		.porta_en(wr_en_real),
		.porta_addr({wr_tid, wr_ptr_cur[ADDR_BITS-2 : 0]}),
		.porta_we(wr_en_real),
		.porta_din(wr_data),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(rd_en_real),
		.portb_addr({rd_tid, rd_ptr_cur[ADDR_BITS-2 : 0]}),
		.portb_we(1'b0),
		.portb_din(128'h0),
		.portb_dout(rd_data)
	);
		
endmodule

