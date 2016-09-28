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
	@brief L1 cache for SARATOGA CPU
	
	Contains two banks, one for I-side and one D-side.
	
	Entirely virtually addressed, no DMA or MMU logic.
	
	Not super efficient: we can probably get a lot faster by pipelining multiple outstanding transactions.
 */
module SaratogaCPUL1Cache(
	clk,
	ifetch0_tid, ifetch0_iside_rd, ifetch0_iside_addr, ifetch0_thread_active,
	ifetch1_tid, ifetch1_thread_active,
	decode0_tid, decode0_insn, decode0_iside_hit,
	exec0_tid, exec0_dside_rd, exec0_dside_wr, exec0_dside_wmask, exec0_dside_addr, exec0_dside_din, exec0_thread_active,
	exec1_tid, exec1_thread_active,
	exec2_tid, exec2_dside_dout, exec2_dside_hit,
	miss_rd, miss_tid, miss_addr, miss_perms,
	push_wr, push_tid, push_addr, push_data,
	flush_en, flush_tid, flush_addr, flush_dout, flush_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	//Number of levels of associativity in the cache
	parameter ASSOC_WAYS		= 2;
	
	//Number of words in a cache line (must be even)
	parameter WORDS_PER_LINE	= 8;
	
	//Number of cache lines in a bank
	parameter LINES_PER_BANK	= 16;
	
	//Number of bits for byte indexing (constant)
	localparam BYTE_ADDR_BITS	= 2;
	
	//Number of bits for word addressing
	localparam WORD_ADDR_BITS = clog2(WORDS_PER_LINE);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;

	//Pipeline status
	input wire[TID_BITS-1 : 0]	ifetch0_tid;
	input wire					ifetch0_thread_active;
	input wire[TID_BITS-1 : 0]	ifetch1_tid;
	input wire					ifetch1_thread_active;
	input wire[TID_BITS-1 : 0]	decode0_tid;
	input wire[TID_BITS-1 : 0]	exec0_tid;
	input wire					exec0_thread_active;
	input wire[TID_BITS-1 : 0]	exec1_tid;
	input wire					exec1_thread_active;
	input wire[TID_BITS-1 : 0]	exec2_tid;
	
	//I-side bus
	input wire					ifetch0_iside_rd;
	input wire[31:0]			ifetch0_iside_addr;
	output wire[63:0]			decode0_insn;
	output wire[1:0]			decode0_iside_hit;		//Indicates if there was a cache hit
	
	input wire					exec0_dside_rd;
	input wire					exec0_dside_wr;
	input wire[3:0]				exec0_dside_wmask;
	input wire[31:0]			exec0_dside_addr;
	input wire[31:0]			exec0_dside_din;
	output wire[63:0]			exec2_dside_dout;
	output wire[1:0]			exec2_dside_hit;
	
	//Miss requests
	output reg					miss_rd		= 0;
	output reg[2:0]				miss_perms	= 0;
	output reg[TID_BITS-1 : 0]	miss_tid	= 0;
	output reg[31:0]			miss_addr	= 0;
	
	//Miss/prefetch handling
	input wire					push_wr;
	input wire[TID_BITS-1 : 0]	push_tid;
	input wire[31:0]			push_addr;
	input wire[63:0]			push_data;
	
	//Flush bus
	output reg					flush_en	= 0;
	output wire[TID_BITS-1 : 0]	flush_tid;
	output reg[31:0]			flush_addr	= 0;
	output wire[63:0]			flush_dout;
	input wire					flush_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual cache banks
	
	wire					iside_miss_rd;
	wire[TID_BITS-1 : 0]	iside_miss_tid;
	wire[31:0]				iside_miss_addr;
	
	reg						iside_push_wr	= 0;
	reg[TID_BITS-1 : 0]		iside_push_tid	= 0;
	reg[31:0]				iside_push_addr	= 0;
	reg[63:0]				iside_push_data	= 0;
	
	wire					dside_miss_rd;
	wire[TID_BITS-1 : 0]	dside_miss_tid;
	wire[31:0]				dside_miss_addr;
	
	reg						dside_push_wr	= 0;
	reg[TID_BITS-1 : 0]		dside_push_tid	= 0;
	reg[31:0]				dside_push_addr	= 0;
	reg[63:0]				dside_push_data	= 0;
	
	wire					dside_flush_en;
	wire[TID_BITS-1 : 0]	dside_flush_tid;
	wire[31:0]				dside_flush_addr;
	wire[63:0]				dside_flush_dout;
	
	//I-side cache bank, not writable
	SaratogaCPUL1CacheBank #(
		.MAX_THREADS(MAX_THREADS),
		.ASSOC_WAYS(ASSOC_WAYS),
		.WORDS_PER_LINE(WORDS_PER_LINE),
		.LINES_PER_BANK(LINES_PER_BANK)
	) iside_bank (
		.clk(clk),
		
		.c0_tid(ifetch0_tid),
		.c0_rd(ifetch0_iside_rd),
		.c0_wr(1'b0),
		.c0_wmask(4'b0),
		.c0_addr(ifetch0_iside_addr),
		.c0_din(32'h0),
		
		.c1_tid(ifetch1_tid),
		
		.c2_tid(decode0_tid),
		.c2_dout(decode0_insn),
		.c2_hit(decode0_iside_hit),
		
		.miss_rd(iside_miss_rd),
		.miss_tid(iside_miss_tid),
		.miss_addr(iside_miss_addr),
		
		.push_wr(iside_push_wr),
		.push_tid(iside_push_tid),
		.push_addr(iside_push_addr),
		.push_data(iside_push_data),
		
		//I-side flush port ignored since we can't write to it
		.flush_en(),
		.flush_tid(),
		.flush_addr(),
		.flush_dout()
		);
		
	//D-side cache bank
	SaratogaCPUL1CacheBank #(
		.MAX_THREADS(MAX_THREADS),
		.ASSOC_WAYS(ASSOC_WAYS),
		.WORDS_PER_LINE(WORDS_PER_LINE),
		.LINES_PER_BANK(LINES_PER_BANK)
	) dside_bank (
		.clk(clk),
		
		.c0_tid(exec0_tid),
		.c0_rd(exec0_dside_rd),
		.c0_wr(exec0_dside_wr),
		.c0_wmask(exec0_dside_wmask),
		.c0_addr(exec0_dside_addr),
		.c0_din(exec0_dside_din),
		
		.c1_tid(exec1_tid),
		
		.c2_tid(exec2_tid),
		.c2_dout(exec2_dside_dout),
		.c2_hit(exec2_dside_hit),
		
		.miss_rd(dside_miss_rd),
		.miss_tid(dside_miss_tid),
		.miss_addr(dside_miss_addr),
		
		.push_wr(dside_push_wr),
		.push_tid(dside_push_tid),
		.push_addr(dside_push_addr),
		.push_data(dside_push_data),
		
		.flush_en(dside_flush_en),
		.flush_tid(dside_flush_tid),
		.flush_addr(dside_flush_addr),
		.flush_dout(dside_flush_dout)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Buffer of evicted cache lines that need to be flushed
	
	//Flag indicating if this is the first word in a flush
	reg			flush_first		= 0;
	
	//Flag indicating if this is the last word in a flush
	reg			flush_last		= 0;
	
	reg			flush_data_rd	= 0;
	
	//The flush data
	MultithreadedSingleClockFifo #(
		.WIDTH(64),
		.MAX_THREADS(MAX_THREADS),
		.WORDS_PER_THREAD(WORDS_PER_LINE),
		.OUT_REG(1),
		.USE_BLOCK(1)
	) flush_data_mem (
		.clk(clk),
		.reset(1'b0),
		.peek(1'b0),
		
		//push data when it comes in from the master
		//ignore status/overflow fields because we cannot have >1 request outstanding per thread at a time
		.wr_tid(dside_flush_tid),
		.wr(dside_flush_en),
		.din(dside_flush_dout),
		.overflow_r(),
		.overflow(),
		.full(),
		
		.rd(flush_data_rd),
		.rd_tid(flush_tid),
		.dout(flush_dout),
		.underflow(),
		.underflow_r(),
		.empty()
    );
    	
	//Indicates there is a flush eligible to be popped right now
	reg flush_eligible		= 0;
	reg	flush_eligible_ff	= 0;

	//The address being flushed, for each thread
	wire[31:0]				flush_base_addr;
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) flush_addr_mem (

		.porta_clk(clk),
		.porta_en(dside_flush_en),
		.porta_addr(dside_flush_tid),
		.porta_we(flush_first),
		.porta_din(dside_flush_addr),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(flush_eligible_ff),
		.portb_addr(flush_tid),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(flush_base_addr)
	);

	//Indicates there is something ready to flush
	wire					flush_ready;

	//The FIFO of stuff being flushed
	wire					flush_tid_empty;
	SingleClockFifo #(
		.WIDTH(TID_BITS),
		.DEPTH(MAX_THREADS),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_FULL(0)
	) flush_tid_fifo (
		.clk(clk),
		.wr(flush_last),
		.din(dside_flush_tid),
		.rd(flush_eligible),
		.dout(flush_tid),
		.overflow(),
		.underflow(),
		.empty(flush_tid_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
		);
	assign flush_ready = !flush_tid_empty;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFOs of virtual addresses that need to be fetched
	
	reg					iside_fetch_addr_rd		= 0;
	wire				iside_fetch_addr_empty;
	wire[TID_BITS-1:0]	iside_fetch_tid_out;
	wire[31:0]			iside_fetch_addr_dout;
	
	SingleClockFifo #(
		.WIDTH(32 + TID_BITS),
		.DEPTH(MAX_THREADS),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_FULL(0)
	) iside_fetch_addr_fifo (
		.clk(clk),
		.wr(iside_miss_rd),
		.din({iside_miss_tid, iside_miss_addr}),
		.rd(iside_fetch_addr_rd),
		.dout({iside_fetch_tid_out, iside_fetch_addr_dout}),
		.overflow(),
		.underflow(),
		.empty(iside_fetch_addr_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
		);
		
	reg					dside_fetch_addr_rd;
	wire				dside_fetch_addr_empty;
	wire[TID_BITS-1:0]	dside_fetch_tid_out;
	wire[31:0]			dside_fetch_addr_dout;
	
	SingleClockFifo #(
		.WIDTH(32 + TID_BITS),
		.DEPTH(MAX_THREADS),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_FULL(0)
	) dside_fetch_addr_fifo (
		.clk(clk),
		.wr(dside_miss_rd),
		.din({dside_miss_tid, dside_miss_addr}),
		.rd(dside_fetch_addr_rd),
		.dout({dside_fetch_tid_out, dside_fetch_addr_dout}),
		.overflow(),
		.underflow(),
		.empty(dside_fetch_addr_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Flush handling logic

	//Flushes must have higher priority than reads here.
	//We can easily block if reads are delayed by writes, but writing too fast will overflow the buffer and lose data.

	//Indicates we're currently handling a miss (outstanding DMA)
	reg miss_active		= 0;
	
	//Indicates we're currently handling a flush (outstanding DMA)
	reg	flush_active	= 0;
	
	always @(*) begin
		flush_first			<= dside_flush_en &&
								(dside_flush_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == 0);
		flush_last			<= dside_flush_en &&
								(dside_flush_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == {{WORD_ADDR_BITS-1{1'h1}}, 1'h0});
		flush_eligible		<= flush_ready && !miss_active && !flush_active;
		
	end
	
	reg	flush_eligible_ff2	= 0;
	
	always @(posedge clk) begin
	
		flush_eligible_ff	<= flush_eligible;
		flush_eligible_ff2	<= flush_eligible_ff;
		
		//Streaming out flush data the cycle after a read
		flush_en				<= flush_data_rd;
	
		//If there is a cache line ready to flush, and we aren't already servicing a miss, process it.
		//Begin by reading the thread ID (combinatorially)
		if(flush_eligible)
			flush_active		<= 1;
			
		//Then read the base address of the flush (combinatorially on flush_eligible_ff)
		//and start reading the data
		if(flush_eligible_ff)
			flush_data_rd		<= 1;
			
		//Once we have the first data word, update the address
		if(flush_eligible_ff2)
			flush_addr			<= flush_base_addr;
			
		//Increment the address by 64 bits every word (except the first)
		else if(flush_data_rd)
			flush_addr			<= flush_addr + 8;
			
		//If we are sending the last word, stop sending.
		//Stop reading one cycle before that.
		if((flush_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] + 2'h2) == {{WORD_ADDR_BITS-1{1'h1}}, 1'h0})
			flush_data_rd		<= 0;
			
		//When the external handler completes, we're done flushing.
		//Leave the address on the wire until then.
		if(flush_done) begin
			flush_active		<= 0;
			flush_addr			<= 0;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Miss handling logic
	
	`include "SaratogaCPUPagePermissions_constants.v"
	
	//Keep track of which cache the miss came from (iside = 1)
	reg miss_source			= 0;
	
	//Arbitration for next pop
	reg next_miss_source	= 0;
	
	//Push fifo outputs directly to top level ports
	always @(*) begin
		if(miss_source == 1) begin
			miss_tid	<= iside_fetch_tid_out;
			miss_addr	<= iside_fetch_addr_dout;
			miss_perms	<= PAGE_EXECUTE;
		end
		else begin
			miss_tid	<= dside_fetch_tid_out;
			miss_addr	<= dside_fetch_addr_dout;
			miss_perms	<= PAGE_READ;	//TODO: checks for writes
										//Right now, mapping a page r/o will be ignored and it can still be written
										//iff the underlying physical memory is writable
		end
	end
	
	always @(posedge clk) begin
		
		iside_fetch_addr_rd	<= 0;
		dside_fetch_addr_rd	<= 0;
		
		//If we're reading from either cache, the other one has priority next time
		if(iside_fetch_addr_rd)
			next_miss_source	<= 0;
		if(dside_fetch_addr_rd)
			next_miss_source	<= 1;
		
		//If there are misses to pop, and there isn't already one outstanding, fetch it
		//If we're already processing a flush, let that finish first
		if( (!iside_fetch_addr_empty || !dside_fetch_addr_empty) && !miss_active && !flush_active && !flush_ready) begin
			miss_active		<= 1;
			
			//If only one cache has misses, pop it and select the other as the arbitration winner
			if(dside_fetch_addr_empty) begin
				iside_fetch_addr_rd	<= 1;
				miss_source			<= 1;
			end
			else if(iside_fetch_addr_empty) begin
				dside_fetch_addr_rd	<= 1;
				miss_source			<= 0;
			end
			
			//If both have misses, pop the one we didn't pop last time
			else if(next_miss_source == 1) begin
				iside_fetch_addr_rd	<= 1;
				miss_source			<= 1;
			end
			else begin
				dside_fetch_addr_rd	<= 1;
				miss_source			<= 0;
			end
			
		end
		
		//If we are pushing the last word in a miss burst, clear the active flag
		if(push_last)
			miss_active		<= 0;
		
		//FIFO has 1-cycle read latency
		miss_rd				<= iside_fetch_addr_rd || dside_fetch_addr_rd;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO of data going back to the caches
	
	reg push_first	= 0;
	reg push_last	= 0;
	always @(*) begin
		push_first		<= push_wr && (push_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == { {WORD_ADDR_BITS-1{1'b0}}, 1'b0});
		push_last		<= (push_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == { {WORD_ADDR_BITS-1{1'b1}}, 1'b0});
	end
	
	//Data FIFOs per thread, per bank
	wire		iside_push_fifo_underflow;
	wire[63:0]	iside_push_fifo_dout;
	wire[31:0]	iside_push_fifo_raddr;
	MultithreadedSingleClockFifo #(
		.WIDTH(64),
		.MAX_THREADS(MAX_THREADS),
		.WORDS_PER_THREAD(WORDS_PER_LINE),
		.OUT_REG(1),
		.USE_BLOCK(1)
	) iside_push_fifo (
		.clk(clk),
		.reset(1'b0),
		.peek(1'b0),
		
		//push data when it comes in from the master
		//ignore status/overflow fields because we cannot have >1 request outstanding per thread at a time
		.wr_tid(push_tid),
		.wr(push_wr && (miss_source == 1) ),
		.din(push_data),
		.overflow_r(),
		.overflow(),
		.full(),
		
		//Read any time the thread is active
		.rd(ifetch0_thread_active),
		.rd_tid(ifetch0_tid),
		.dout(iside_push_fifo_dout),
		.underflow(),
		.underflow_r(iside_push_fifo_underflow),
		.empty()
    );
    
    wire		dside_push_fifo_underflow;
	wire[63:0]	dside_push_fifo_dout;
	wire[31:0]	dside_push_fifo_raddr;
	MultithreadedSingleClockFifo #(
		.WIDTH(64),
		.MAX_THREADS(MAX_THREADS),
		.WORDS_PER_THREAD(WORDS_PER_LINE),
		.OUT_REG(1),
		.USE_BLOCK(1)
	) dside_push_fifo (
		.clk(clk),
		.reset(1'b0),
		.peek(1'b0),
		
		//push data when it comes in from the master
		//ignore status/overflow fields because we cannot have >1 request outstanding per thread at a time
		.wr_tid(push_tid),
		.wr(push_wr && (miss_source == 0) ),
		.din(push_data),
		.overflow(),
		.overflow_r(),
		.full(),
		
		//Read any time the thread is active
		.rd(exec0_thread_active),
		.rd_tid(exec0_tid),
		.dout(dside_push_fifo_dout),
		.underflow(),
		.underflow_r(dside_push_fifo_underflow),
		.empty()
    );
    
    //Miss is valid if we arent underflowing the fifo
	wire iside_miss_valid = !iside_push_fifo_underflow && ifetch1_thread_active;
	wire dside_miss_valid = !dside_push_fifo_underflow && exec1_thread_active;
    
    //Saved address per thread
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) iside_push_addresses (
		.porta_clk(clk),
		.porta_en(push_wr && (miss_source == 1)),
		.porta_addr(push_tid),
		.porta_we(push_first),
		.porta_din(push_addr),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(ifetch0_tid),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(iside_push_fifo_raddr)
	);
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) dside_push_addresses (
		.porta_clk(clk),
		.porta_en(push_wr && (miss_source == 0)),
		.porta_addr(push_tid),
		.porta_we(push_first),
		.porta_din(push_addr),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(exec0_tid),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(dside_push_fifo_raddr)
	);
	
	//Offset for pushes within a cache line
	//Cleared to zero when a miss goes out
	wire[WORD_ADDR_BITS-1:0]		iside_push_offset;
	wire[WORD_ADDR_BITS-1:0]		iside_push_offset_next = iside_push_offset + 1'h1;
	wire[WORD_ADDR_BITS-1:0]		dside_push_offset;
	wire[WORD_ADDR_BITS-1:0]		dside_push_offset_next = dside_push_offset + 1'h1;
	
	MultiportMemoryMacro #(
		.WIDTH(WORD_ADDR_BITS),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(0)
	) iside_push_offsets (
		.clk,
		.wr_en(  {iside_miss_rd,			iside_miss_valid}),
		.wr_addr({iside_miss_tid, 			ifetch1_tid}),
		.wr_data({{WORD_ADDR_BITS{1'b0}},	iside_push_offset_next }),
		.rd_en(1'b1),
		.rd_addr(ifetch1_tid),
		.rd_data(iside_push_offset)
	);
	
	MultiportMemoryMacro #(
		.WIDTH(WORD_ADDR_BITS),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(0)
	) dside_push_offsets (
		.clk,
		.wr_en(  {dside_miss_rd,			dside_miss_valid}),
		.wr_addr({dside_miss_tid, 			exec1_tid}),
		.wr_data({{WORD_ADDR_BITS{1'b0}},	dside_push_offset_next }),
		.rd_en(1'b1),
		.rd_addr(exec1_tid),
		.rd_data(dside_push_offset)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push handling logic
	
	/*
		Every clock cycle, check if there's data in the requesting thread's fifo.
		If so, push it to that thread
	 */
	
	always @(posedge clk) begin
		
		
		//Push data regardless
		//Offset gets multiplied by 8 since each push is 8 bytes
		iside_push_addr		<= iside_push_fifo_raddr + {iside_push_offset, 3'h0};
		iside_push_data		<= iside_push_fifo_dout;
		iside_push_tid		<= ifetch1_tid;
		dside_push_addr		<= dside_push_fifo_raddr + {dside_push_offset, 3'h0};
		dside_push_data		<= dside_push_fifo_dout;
		dside_push_tid		<= exec1_tid;
		
		//Enable if it's valid
		iside_push_wr		<= iside_miss_valid;
		dside_push_wr		<= dside_miss_valid;
		
	end
	
endmodule
