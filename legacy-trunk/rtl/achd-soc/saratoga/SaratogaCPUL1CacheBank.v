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
	@brief L1 cache bank for SARATOGA CPU
	
	Total cache size (for each bank) is ASSOC_WAYS * WORDS_PER_LINE * LINES_PER_BANK 32-bit words per thread context,
	virtually addressed.
	
	For the default configuration we have 256 words = 1KB * 32 threads = 32 KB total size.
	
	Each data way in the default configuration is 32 bits x 4096 words = 4 36kbit BRAM.
	Each tag way in the default configuration  is 32 bits (23 used for tag) x 512 rows = 1 18kbit BRAM
	
	Total is (4+1) * 2 = 10 36kbit BRAMs.
	
	Default address breakdown:
		31:9	Tag
		8:5		Line within bank
		4:2		Word within cache line
		1:0		Byte within word
		
	Timing structure for reads
		Cycle 0: Assert c0_rd with addr and tid valid
		Cycle 1: Wait
		Cycle 2: c2_dout and hit are set appropriately
		
	Timing structure for writes (1 bit in mask = write, 0 = inhibit)
		Cycle 0: Assert c0_wr with addr, wmask, and din valid
		Cycle 1: Wait
		Cycle 2: If hit is set, the data was cached and the write has committed
				 else the data missed and we need to try again once it's in cache
				 
	c2_tid must equal push_tid if push_wr is asserted.
 */
module SaratogaCPUL1CacheBank(
	clk,
	
	c0_tid, c0_rd, c0_wr, c0_wmask, c0_addr, c0_din,
	c1_tid,
	c2_tid, c2_dout, c2_hit,
	
	miss_rd, miss_tid, miss_addr,
	push_wr, push_tid, push_addr, push_data,
	flush_en, flush_tid, flush_addr, flush_dout
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
	
	//Number of bits needed to represent an associativity level
	localparam ASSOC_BITS		= clog2(ASSOC_WAYS);
	
	//Number of bits for byte indexing (constant)
	localparam BYTE_ADDR_BITS	= 2;
	
	//Number of words in a cache line (must be even)
	parameter WORDS_PER_LINE	= 8;
	
	//Number of bits for word addressing
	localparam WORD_ADDR_BITS = clog2(WORDS_PER_LINE);
	
	//Number of cache lines in a bank
	parameter LINES_PER_BANK	= 16;
	
	//Number of bits for line indexing
	localparam LINE_ADDR_BITS	= clog2(LINES_PER_BANK);
	
	//Number of bits of real tag
	//Address size minus cache address size
	localparam RTAG_BITS		= 32 - TAG_LSB;
	
	//Number of bits per tag
	//Address size minus cache address size, plus one each for valid and dirty bits
	localparam TAG_BITS			= RTAG_BITS + 2;
	
	//LSB of the tag
	localparam TAG_LSB			= BYTE_ADDR_BITS + WORD_ADDR_BITS + LINE_ADDR_BITS;
	
	//Number of words in the tag memory
	localparam TAG_MEM_DEPTH	= LINES_PER_BANK * MAX_THREADS;
	
	//Number of bits in a tag address including TID
	localparam TAG_ADDR_BITS	= clog2(TAG_MEM_DEPTH);
	
	//Number of bits in a thread's tag address
	localparam TBANK_ADDR_BITS	= clog2(LINES_PER_BANK);
	
	//Number of words in the data memory
	localparam DATA_MEM_DEPTH	= WORDS_PER_LINE * TAG_MEM_DEPTH;
	
	//Number of bits in a thread's data address
	//Subtract one because we split across even and odd banks
	localparam DBANK_ADDR_BITS	= TBANK_ADDR_BITS + WORD_ADDR_BITS - 1;
	
	//Number of bits in a data address
	localparam DATA_ADDR_BITS	= clog2(DATA_MEM_DEPTH);
	
	//Number of words in one data memory half-bank
	localparam HDATA_MEM_DEPTH	= DATA_MEM_DEPTH / 2;
	
	//Number of bits in a data half-bank address
	localparam HDATA_ADDR_BITS	= clog2(HDATA_MEM_DEPTH);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;
	
	//CPU-side bus
	input wire[TID_BITS-1 : 0]	c0_tid;
	input wire					c0_rd;
	input wire					c0_wr;
	input wire[3:0]				c0_wmask;
	input wire[31:0]			c0_addr;
	input wire[31:0]			c0_din;
	input wire[TID_BITS-1 : 0]	c1_tid;
	input wire[TID_BITS-1 : 0]	c2_tid;
	(* REGISTER_BALANCING = "yes" *)
	output reg[1:0]				c2_hit	= 0;
	output reg[63:0]			c2_dout	= 64'h0;
	
	//Miss requests
	output reg					miss_rd		= 0;
	output reg[TID_BITS-1 : 0]	miss_tid	= 0;
	output reg[31:0]			miss_addr	= 0;
	
	//Miss/prefetch handling
	input wire					push_wr;
	input wire[TID_BITS-1 : 0]	push_tid;
	input wire[31:0]			push_addr;
	input wire[63:0]			push_data;
	
	//Flush port
	output reg					flush_en	= 0;
	output reg[TID_BITS-1 : 0]	flush_tid	= 0;
	output reg[31:0]			flush_addr	= 0;
	output reg[63:0]			flush_dout	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Check if this is the first or last address in the push
	
	reg push_first	= 0;
	reg push_last	= 0;
	always @(*) begin
		push_first		<= (push_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == {WORD_ADDR_BITS{1'b0}});
		push_last		<= (push_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == { {WORD_ADDR_BITS-1{1'b1}}, 1'b0});
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cache replacement policy: Round robin
	
	wire[ASSOC_BITS-1:0]	miss_way;
	wire[ASSOC_BITS-1:0]	miss_way_next  = miss_way + 1'h1;
	
	MemoryMacro #(
		.WIDTH(ASSOC_BITS),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(0),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b0),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) miss_way_mem (
	
		.porta_clk(clk),
		.porta_en(push_wr),
		.porta_addr(push_tid),
		.porta_we(push_last),
		.porta_din(miss_way_next),
		.porta_dout(miss_way),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr({TID_BITS{1'b0}}),
		.portb_we(1'b0),
		.portb_din({ASSOC_BITS{1'b0}}),
		.portb_dout()
	);
	
	//valid for the cycle after a push (used for flush)
	reg[ASSOC_BITS-1:0]		miss_way_ff;
	reg[ASSOC_BITS-1:0]		miss_way_ff2;
	always @(posedge clk) begin
		miss_way_ff		<= miss_way;
		miss_way_ff2	<= miss_way_ff;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory arrays
	
	genvar i;
	
	//Port A signals for tag memory.
	//Active whenever the corresponding thread is active
	//Used for CPU-side reads and pushing miss data into the cache
	reg							taga_en				= 0;
	reg[TAG_ADDR_BITS-1 : 0]	taga_addr			= 0;
	wire[31:0]					taga_rdata[ASSOC_WAYS-1 : 0];
	
	//Port B signals for tag memory
	//Used for committing writes (2-cycle latency from reads)
	reg							tagb_en				= 0;
	reg							tagb_wr				= 0;
	reg							tagb_wr_way			= 0;
	reg[TAG_ADDR_BITS-1 : 0]	tagb_addr			= 0;
	reg[31:0]					tagb_wdata			= 0;
	wire[31:0]					tagb_rdata[ASSOC_WAYS-1 : 0];
	
	//Port A signals for data memory.
	//Active whenever the corresponding thread is active
	//Used for CPU-side reads
	//Separate addresses for even and odd banks so we can do unaligned reads.
	//Writes are always aligned.
	reg							data_en				= 0;
	reg[DATA_ADDR_BITS-2 : 0]	data_addr_even		= 0;
	reg[DATA_ADDR_BITS-2 : 0]	data_addr_odd		= 0;
	wire[31:0]					data_rdata_even[ASSOC_WAYS-1 : 0];
	wire[31:0]					data_rdata_odd[ASSOC_WAYS-1 : 0];
	
	//Port B signals for data memory.
	//Used for committing writes (2-cycle latency from reads)
	//and pushing miss data into the cache
	reg							datb_en				= 0;
	reg							datb_wr				= 0;
	reg							datb_wr_way			= 0;
	reg[DATA_ADDR_BITS-2 : 0]	datb_addr_even		= 0;
	reg[DATA_ADDR_BITS-2 : 0]	datb_addr_odd		= 0;
	reg[63:0]					datb_wdata			= 0;
	wire[31:0]					datb_rdata_even[ASSOC_WAYS-1 : 0];
	wire[31:0]					datb_rdata_odd[ASSOC_WAYS-1 : 0];
	
	//Register port B signals by one cycle to improve timing
	reg							tagb_en_ff			= 0;
	reg							tagb_wr_ff			= 0;
	reg							tagb_wr_way_ff		= 0;
	reg[TAG_ADDR_BITS-1 : 0]	tagb_addr_ff		= 0;
	reg[31:0]					tagb_wdata_ff		= 0;
	
	reg							datb_en_ff			= 0;
	reg							datb_wr_ff			= 0;
	reg							datb_wr_way_ff		= 0;
	reg[DATA_ADDR_BITS-2 : 0]	datb_addr_even_ff	= 0;
	reg[DATA_ADDR_BITS-2 : 0]	datb_addr_odd_ff	= 0;
	reg[63:0]					datb_wdata_ff		= 0;
	
	always @(posedge clk) begin
	
		//Default: Register port B signals from CPU-side bus
		tagb_en_ff			<= tagb_en;
		tagb_wr_ff			<= tagb_wr;
		tagb_wr_way_ff		<= tagb_wr_way;
		tagb_addr_ff		<= tagb_addr;
		tagb_wdata_ff		<= tagb_wdata;
		
		datb_en_ff			<= datb_en;
		datb_wr_ff			<= datb_wr;
		datb_wr_way_ff		<= datb_wr_way;
		datb_addr_even_ff	<= datb_addr_even;
		datb_addr_odd_ff	<= datb_addr_odd;
		datb_wdata_ff		<= datb_wdata;
		
		//Override if we have a push coming in
		//No risk of collisions: Pushes are only sent in response to cache misses, which block the thread ctx
		if(push_wr) begin
		
			//Enable and write to tag and data banks
			tagb_en_ff			<= 1;
			tagb_wr_ff			<= 1;
			
			datb_en_ff			<= 1;
			datb_wr_ff			<= 1;
			
			//Use the current way
			tagb_wr_way_ff		<= miss_way;
			datb_wr_way_ff		<= miss_way;
			
			//Data is always 64-bit aligned so no fancy addressing
			tagb_addr_ff		<= { push_tid, push_addr[BYTE_ADDR_BITS + WORD_ADDR_BITS +: TBANK_ADDR_BITS] };
			datb_addr_even_ff	<= { push_tid, push_addr[BYTE_ADDR_BITS+1 +: DBANK_ADDR_BITS] };
			datb_addr_odd_ff	<= { push_tid, push_addr[BYTE_ADDR_BITS+1 +: DBANK_ADDR_BITS] };
			
			//If we're not the last word in the cache, blow out the tag.
			//Otherwise update it: Valid, not dirty, address
			if(!push_last)
				tagb_wdata_ff	<= 0;
			else
				tagb_wdata_ff	<= {1'b1, 1'b0, push_addr[31:TAG_LSB]};
			
			datb_wdata_ff		<= push_data;
		
		end
				
	end
	
	generate
	
		for(i=0; i<ASSOC_WAYS; i=i+1) begin : memblocks
			
			//Tag memory - one bank
			MemoryMacro #(
				.WIDTH(32),
				.DEPTH(TAG_MEM_DEPTH),
				.DUAL_PORT(1),
				.TRUE_DUAL(1),
				.USE_BLOCK(1),
				.OUT_REG(1),
				.INIT_ADDR(0),
				.INIT_FILE(""),
				.INIT_VALUE(0)
			) tag_mem (
				.porta_clk(clk),
				.porta_en(taga_en),
				.porta_addr(taga_addr),
				.porta_we(1'b0),
				.porta_din(32'h0),
				.porta_dout(taga_rdata[i]),
		
				.portb_clk(clk),
				.portb_en(tagb_en_ff),
				.portb_addr(tagb_addr_ff),
				.portb_we(tagb_wr_ff && (tagb_wr_way_ff == i)),
				.portb_din(tagb_wdata_ff),
				.portb_dout(tagb_rdata[i])
			);
			
			//Data memory - split, one half-bank for even addresses and one for odd
			MemoryMacro #(
				.WIDTH(32),
				.DEPTH(HDATA_MEM_DEPTH),
				.DUAL_PORT(1),
				.TRUE_DUAL(1),
				.USE_BLOCK(1),
				.OUT_REG(1),
				.INIT_ADDR(0),
				.INIT_FILE(""),
				.INIT_VALUE(0)
			) data_mem_even (
				.porta_clk(clk),
				.porta_en(data_en) ,
				.porta_addr(data_addr_even),
				.porta_we(1'b0),
				.porta_din(32'h0),
				.porta_dout(data_rdata_even[i]),
			
				.portb_clk(clk),
				.portb_en(datb_en_ff),
				.portb_addr(datb_addr_even_ff),
				.portb_we(datb_wr_ff && (datb_wr_way_ff == i)),
				.portb_din(datb_wdata_ff[63:32]),
				.portb_dout(datb_rdata_even[i])
			);
			
			MemoryMacro #(
				.WIDTH(32),
				.DEPTH(HDATA_MEM_DEPTH),
				.DUAL_PORT(1),
				.TRUE_DUAL(1),
				.USE_BLOCK(1),
				.OUT_REG(1),
				.INIT_ADDR(0),
				.INIT_FILE(""),
				.INIT_VALUE(0)
			) data_mem_odd (
				.porta_clk(clk),
				.porta_en(data_en) ,
				.porta_addr(data_addr_odd),
				.porta_we(1'b0),
				.porta_din(32'h0),
				.porta_dout(data_rdata_odd[i]),
			
				.portb_clk(clk),
				.portb_en(datb_en_ff),
				.portb_addr(datb_addr_odd_ff),
				.portb_we(datb_wr_ff && (datb_wr_way_ff == i)),
				.portb_din(datb_wdata_ff[31:0]),
				.portb_dout(datb_rdata_odd[i])
			);
			
		end
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Keep track of which threads currently have a miss going on
	
	wire	c2_miss_active;
	
	MultiportMemoryMacro #(
		.NREAD(1),
		.NWRITE(2),
		.WIDTH(1),

		.DEPTH(MAX_THREADS),
		.USE_BLOCK(0),
		.OUT_REG(0)
	) miss_active (
		.clk(clk),
	
		.wr_en(  {miss_rd,  (push_last && push_wr)}),
		.wr_addr({miss_tid, push_tid}),
		.wr_data({1'b1,     1'b0}),
	
		.rd_en(1'b1),
		.rd_addr(c2_tid),
		.rd_data(c2_miss_active)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cycle 0 processing
	
	reg[31:0]				c0_addr_next	= 0;

	always @(*) begin
	
		//Address of the next word (the second value we're fetching)
		c0_addr_next		<= c0_addr + 32'h4;	
	
		//If reading or writing, see if the data is in the cache
		taga_en			<= (c0_rd || c0_wr);
		data_en			<= (c0_rd || c0_wr);
	
		//Tag address is easy to calculate
		taga_addr		<= { c0_tid, c0_addr[BYTE_ADDR_BITS + WORD_ADDR_BITS +: TBANK_ADDR_BITS] };
			
		//If we're fetching from an EVEN word address, grab the address from the even bank.
		//The same row in the odd bank has the next word
		//If we're doing a write, do an aligned fetch too.
		if( (c0_addr[BYTE_ADDR_BITS] == 0) || c0_wr ) begin
			data_addr_even	<= { c0_tid, c0_addr[BYTE_ADDR_BITS + 1 +: DBANK_ADDR_BITS]};
			data_addr_odd	<= { c0_tid, c0_addr[BYTE_ADDR_BITS + 1 +: DBANK_ADDR_BITS]};
		end
		
		//If fetching from an ODD word address, grab the address from the odd bank.
		//The next row up in the even bank has the next word
		else begin
			data_addr_odd	<= { c0_tid, c0_addr[BYTE_ADDR_BITS + 1 +: DBANK_ADDR_BITS]};
			data_addr_even	<= { c0_tid, c0_addr_next[BYTE_ADDR_BITS + 1 +: DBANK_ADDR_BITS]};
		end

	end
	
	reg				c1_rd		= 0;
	reg[31:0]		c1_addr		= 0;
	reg				c1_wr		= 0;
	reg[31:0]		c1_wdata	= 0;
	reg[3:0]		c1_wmask	= 0;
	
	always @(posedge clk) begin
		c1_rd		<= c0_rd;
		c1_wr		<= c0_wr;
		c1_addr		<= c0_addr;
		c1_wdata	<= c0_din;
		c1_wmask	<= c0_wmask;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cycle 1 processing
	
	reg[RTAG_BITS-1 : 0]	tag_match_target	= 0;
	
	reg						c2_rd		= 0;
	reg						c2_wr		= 0;
	reg[31:0]				c2_addr		= 0;
	reg[3:0]				c2_wmask	= 0;
	
	//Move a few declarations up for access by this stuff
	reg[1:0]				c2_hit_adv	= 0;
	reg[ASSOC_WAYS-1 : 0]	c1_hit_mask	= 0;
	reg[ASSOC_WAYS-1 : 0]	tag_valid	= 0;
	reg[ASSOC_WAYS-1 : 0]	tag_dirty	= 0;
	reg[ASSOC_WAYS-1 : 0]	tag_match	= 0;
	
	integer j;
	always @(*) begin
		
		//Target address for matching tags to
		tag_match_target	<= c1_addr[31 : TAG_LSB];
		
		//Pull out some status bits for each tag's way
		for(j=0; j<ASSOC_WAYS; j=j+1) begin
			tag_valid[j]	<= taga_rdata[j][RTAG_BITS+1];
			tag_dirty[j]	<= taga_rdata[j][RTAG_BITS];
			tag_match[j]	<= taga_rdata[j][RTAG_BITS-1 : 0] == tag_match_target;
		end
		
		//At the end of cycle 1, we have the memory words ready
		//Decide if it was a hit or not
		//Tag valid bit is TAG_BITS+1
		//Dirty bit is TAG_BITS
		c2_hit_adv		<= 0;
		c1_hit_mask		<= 0;
		
		if(c1_rd || c1_wr) begin
			
			//Check all ways in parallel
			for(j=0; j<ASSOC_WAYS; j=j+1) begin
				
				//Set both hit bits, plus data, if the tag matches
				if(tag_valid[j] && tag_match[j]) begin
					c2_hit_adv		<= 2'b11;
					c1_hit_mask[j]	<= 1;
				end
					
			end
				
			//Clear second hit bit if this is the last word in the cache line
			if(c1_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] == {WORD_ADDR_BITS{1'b1}})
				c2_hit_adv[0]	<= 0;
			
		end

	end
	
	//KEEP constraints needed to prevent registers from getting absorbed into block ram.
	//This allows the register to be placed closer to the c2_dout mux, absorbing some of the routing delay
	(* KEEP = "true" *)
	reg[31:0]	c2_rdata_odd[ASSOC_WAYS-1 : 0];
	(* KEEP = "true" *)
	reg[31:0]	c2_rdata_even[ASSOC_WAYS-1 : 0];
	(* KEEP = "true" *)
	reg[31:0]	c2_tagrdata[ASSOC_WAYS-1 : 0];
	
	(* MAX_FANOUT = "reduce" *)
	(* REGISTER_BALANCING = "yes" *)
	reg[ASSOC_WAYS-1 : 0]	c2_hit_mask	= 0;
	reg[ASSOC_BITS-1 : 0]	c2_hit_way		= 0;
	reg						c2_addr_odd		= 0;
	
	//Register write stuff to improve timing
	reg[31:0]	c2_wdata		= 0;
	
	always @(*) begin
		c2_hit_way	<= 0;
		for(j=0; j<ASSOC_WAYS; j=j+1) begin
			if(c2_hit_mask[j])
				c2_hit_way	<= j[ASSOC_BITS-1 : 0];
		end
	end
		
	always @(posedge clk) begin
	
		//Push status down the pipe
		c2_rd				<= c1_rd;
		c2_wr				<= c1_wr;
		c2_addr				<= c1_addr;
		c2_wmask			<= c1_wmask;
	
		//Register hit status
		c2_hit				<= c2_hit_adv;

		//If word-aligned address is even, return {even odd} else {odd even}
		c2_addr_odd			<= c1_addr[BYTE_ADDR_BITS] != 0;
		c2_hit_mask			<= c1_hit_mask;
		for(j=0; j<ASSOC_WAYS; j=j+1) begin
			c2_rdata_odd[j]		<= data_rdata_odd[j];
			c2_rdata_even[j]	<= data_rdata_even[j];
			c2_tagrdata[j]		<= taga_rdata[j];
		end
		
		//If we're writing to port B, write to the active way
		datb_wr_way				<= c2_hit_way;
		tagb_wr_way				<= c2_hit_way;
		
		//Register data to be written
		c2_wdata				<= c1_wdata;
		
		//If we're writing port B, we're writing the data that was sent to us earlier.
		//For now we only have a 32-bit write datapath so the other bank just writes whatever data was in it.
		datb_wdata					<= {c2_rdata_even[c2_hit_way], c2_rdata_odd[c2_hit_way]};
		if(c2_addr_odd) begin
			if(c2_wmask[3])
				datb_wdata[31:24]	<= c2_wdata[31:24];
			if(c2_wmask[2])
				datb_wdata[23:16]	<= c2_wdata[23:16];
			if(c2_wmask[1])
				datb_wdata[15:8]	<= c2_wdata[15:8];
			if(c2_wmask[0])
				datb_wdata[7:0]		<= c2_wdata[7:0];
		end
		else begin
			if(c2_wmask[3])
				datb_wdata[63:56]	<= c2_wdata[31:24];
			if(c2_wmask[2])
				datb_wdata[55:48]	<= c2_wdata[23:16];
			if(c2_wmask[1])
				datb_wdata[47:40]	<= c2_wdata[15:8];
			if(c2_wmask[0])
				datb_wdata[39:32]	<= c2_wdata[7:0];
		end
			
		//If we're writing to port B, write back the previous tag but set the dirty bit
		tagb_wdata					<= c2_tagrdata[c2_hit_way];
		tagb_wdata[RTAG_BITS]		<= 1'b1;
		
		//Select the proper address
		tagb_addr				<= { c2_tid, c2_addr[BYTE_ADDR_BITS + WORD_ADDR_BITS +: TBANK_ADDR_BITS] };
		datb_addr_even			<= { c2_tid, c2_addr[BYTE_ADDR_BITS + 1 +: DBANK_ADDR_BITS]};
		datb_addr_odd			<= { c2_tid, c2_addr[BYTE_ADDR_BITS + 1 +: DBANK_ADDR_BITS]};
		
		//Do the write if we have a pending write, and the associated cache line is present
		datb_wr					<= c2_hit && c2_wr;
		tagb_wr					<= c2_hit && c2_wr;

	end
	
	//Final output muxing gets done as part of the next cycle
	always @(*) begin
		if(c2_addr_odd)
			c2_dout				<= {c2_rdata_odd[c2_hit_way], c2_rdata_even[c2_hit_way]};
		else
			c2_dout				<= {c2_rdata_even[c2_hit_way], c2_rdata_odd[c2_hit_way]};
	end
	
	//For now, enable and write are the same signal
	always @(*) begin
		datb_en		<= datb_wr;
		tagb_en		<= tagb_wr;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cycle 3 processing
		
	always @(posedge clk) begin
	
		miss_rd		<= 0;
		miss_tid	<= 0;
		miss_addr	<= 0;
		
		//If we had a read or write, but it didn't hit, dispatch the miss request
		//Do not dispatch a new miss if one is already pending
		if((c2_rd || c2_wr) && !c2_hit[1] && !c2_miss_active) begin
			miss_rd		<= 1;
			miss_tid	<= c2_tid;
			miss_addr	<= c2_addr;
			
			//round address down to start of cache line
			miss_addr[WORD_ADDR_BITS + BYTE_ADDR_BITS - 1 : 0]	<= 0;
			
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Flush processing
	
	/*
		Push stuff down the pipeline.
		push_wr/push_tid cycle/miss_way			Do nothing 
		push_wr_buf/push_tid_buf/miss_way_ff	Execute read
		push_wr_buf2/push_tid_buf2/miss_way_ff2	Read is done
	 */
	reg						push_wr_buf		= 0;
	reg						push_wr_buf2	= 0;
	reg[TID_BITS-1 : 0]		push_tid_buf	= 0;
	reg[TID_BITS-1 : 0]		push_tid_buf2	= 0;
	reg						push_first_buf	= 0;
	reg						push_first_buf2	= 0;
	reg						push_last_buf	= 0;
	reg						push_last_buf2	= 0;
	reg[31:0]				push_addr_buf	= 0;
	reg[31:0]				push_addr_buf2	= 0;
	always @(posedge clk) begin
		push_wr_buf			<= push_wr;
		push_wr_buf2		<= push_wr_buf;
		push_tid_buf		<= push_tid;
		push_tid_buf2		<= push_tid_buf;
		push_first_buf		<= push_first;
		push_first_buf2		<= push_first_buf;
		push_last_buf		<= push_last;
		push_last_buf2		<= push_last_buf;
		push_addr_buf		<= push_addr;
		push_addr_buf2		<= push_addr_buf;
	end
	
	//Figure out what the previous address stored in this cache line is.
	//The LSBs are going to be the cache address
	wire[31:0] tagb_rdata_active = tagb_rdata[miss_way_ff2];
	wire[31:0] flush_addr_old_adv = 
	{
		tagb_rdata_active[RTAG_BITS-1 : 0],
		push_addr_buf2[TAG_LSB-1 : 0]
	};
	
	//Per-thread dirty flags
	reg[MAX_THREADS-1 : 0]	push_is_dirty	= 0;
	
	//Pull out status bits for the push port
	reg[ASSOC_WAYS-1 : 0]	push_tag_valid	= 0;
	reg[ASSOC_WAYS-1 : 0]	push_tag_dirty	= 0;
	reg						current_push_dirty	= 0;
	reg						current_tag_dirty	= 0;
	reg						current_tag_valid	= 0;
	reg						first_push_dirty	= 0;
	reg						current_tag_dirty_ff	= 0;
	reg						current_tag_valid_ff	= 0;
	always @(*) begin
		for(j=0; j<ASSOC_WAYS; j=j+1) begin
			push_tag_valid[j]	<= tagb_rdata[j][RTAG_BITS+1];
			push_tag_dirty[j]	<= tagb_rdata[j][RTAG_BITS];
		end
		
		current_push_dirty		<= push_is_dirty[push_tid_buf2];
		current_tag_dirty		<= tag_dirty[miss_way_ff2];
		current_tag_valid		<= push_tag_valid[miss_way_ff2];
		first_push_dirty		<= push_tag_dirty[miss_way_ff2] && current_tag_valid;
		
	end

	always @(posedge clk) begin

		current_tag_dirty_ff	<= current_tag_dirty;
		current_tag_valid_ff	<= current_tag_valid;
	
		if(push_wr_buf2) begin
	
			//Set/clear dirty flag on the first cycle
			if(push_first_buf2)
				push_is_dirty[push_tid_buf2]	<= first_push_dirty;
		
			//Clear dirty flag on the last cycle
			else if(push_last_buf2)
				push_is_dirty[push_tid_buf2]	<= 0;
				
		end
			
	end

	always @(posedge clk) begin
		
		//Flush if we're writing to a dirty cache line.
		//Do dirtiness test when pushing the FIRST line
		//otherwise check the previously saved value
		flush_en				<= push_wr_buf2 &&
									(
										(push_first_buf2 && first_push_dirty) ||
										(!push_first_buf2 && current_push_dirty)
									);
		
		//Push to our current thread
		flush_tid				<= push_tid_buf2;
		flush_dout				<= {datb_rdata_even[miss_way_ff2], datb_rdata_odd[miss_way_ff2]};
		
		//If this is a new flush, send the address
		//If not only send LSBs (for writing to the output buffer memory)
		if(push_first_buf2)
			flush_addr			<= flush_addr_old_adv;
		else
			flush_addr			<= 32'h00000000;
			
		flush_addr[BYTE_ADDR_BITS +: WORD_ADDR_BITS] <= push_addr_buf2[BYTE_ADDR_BITS +: WORD_ADDR_BITS];
		
	end

endmodule
