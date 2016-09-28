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
	@brief A single bank of the L1 cache
	
	Cache organization
		Direct mapped
		128 lines of four 32-bit words each
		Dual ported - one to DMA state machine and one to CPU
		
		Total cache size is 2048 bytes = 2^11
		Need 21 bits of tag plus valid bit and dirty bit
		
	If we have a miss, we need to tell the cache controller so that they can service it.
		Assert ctl_rd_en with ctl_rd_addr set to the (aligned) base address of the line being fetched
		
		When the cache line has been fetched, the controller will assert ctl_rd_valid with ctl_rd_daddr and
		ctl_rd_data valid for four consecutive cycles. On the last cycle the controller will assert ctl_rd_done,
		which indicates that the cache should repeat the last missed read.
		
	Cache flush interface
		Assert ctl_wr_en with ctl_wr_addr set to the address of the cache line
		ctl_wr_data will be valid for this and the next three cycles
		ctl_wr_done is asserted externally when the write has finished
		
	To request a full flush of the cache (pushing all dirty lines out)
		Assert ctl_flush_en
		Wait until ctl_flush_done is et
		
	The entire cache bank operates in virtual address space.
 */
module GraftonCPUL1CacheBank(

	//Clocks
	clk,

	//CPU interface
	cpu_addr,
	wr_en, wr_data, wr_mask, wr_done,
	rd_en, rd_data, rd_valid,
	
	//Cache controller interface
	ctl_rd_en, ctl_rd_addr, ctl_rd_data, ctl_rd_daddr, ctl_rd_valid, ctl_rd_done,
	ctl_wr_en, ctl_wr_addr, ctl_wr_data, ctl_wr_done, ctl_flush_en, ctl_flush_done,
	
	ctl_segfault
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//CPU interface
	input wire[31:0] cpu_addr;
	input wire wr_en;
	input wire[31:0] wr_data;
	input wire[3:0] wr_mask;
	output reg wr_done = 0;
	input wire rd_en;
	output reg[31:0] rd_data = 0;
	output reg rd_valid = 0;
	
	//Interface to cache controller for misses
	output reg ctl_rd_en				= 0;
	output reg[31:0] ctl_rd_addr		= 0;
	input wire[31:0] ctl_rd_data;
	input wire[31:0] ctl_rd_daddr;
	input wire ctl_rd_valid;
	input wire ctl_rd_done;
	
	//Interface to cache controller for flushes
	output reg ctl_wr_en				= 0;
	output wire[31:0] ctl_wr_addr;
	output reg[31:0] ctl_wr_data		= 0;
	input wire ctl_wr_done;
	input wire ctl_flush_en;
	output reg ctl_flush_done			= 0;
	
	//General controller metadata
	input wire ctl_segfault;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory bank
	
	//The cache data
	(* RAM_STYLE = "BLOCK" *)
	reg[31:0] cache_mem[511:0];
	
	//Tag memory
	//Tag[0] applies to cache[0...3], tag[1] goes to cache[4...7], etc.
	//Bit 22 = dirty bit
	//Bit 21 = valid bit
	//Bit 20:0 = tag
	(* RAM_STYLE = "BLOCK" *)
	reg[22:0] tag_mem[127:0];
	
	//Zero-fill everything
	integer i;
	initial begin
		for(i=0; i<512; i=i+1)
			cache_mem[i] <= 0;
		for(i=0; i<128; i=i+1)
			tag_mem[i] <= 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State definitions
	
	`include "GraftonCPUL1CacheBank_states_constants.v";
	
	reg[2:0] state = STATE_IDLE;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cache bank read logic (CPU side)
	
	//rd_addr[1:0]   = ignored (always zero) since all reads/writes on the CPU bus are aligned
	//rd_addr[3:2]   = column inside the cache line
	//rd_addr[10:4]  = cache line index
	//rd_addr[31:11] = tag
	
	reg[31:0] cache_bank_out = 0;
	reg[22:0] cache_tag_out = 0;
	reg[31:0] cpu_addr_buf = 0;
	
	reg rd_en_buf = 0;
	reg wr_en_buf = 0;
	
	wire cache_p1_re;
	assign cache_p1_re = rd_en || wr_en || ctl_wr_done;
	
	always @(posedge clk) begin
		
		if(cache_p1_re) begin
			cpu_addr_buf <= cpu_addr;
			cache_tag_out <= tag_mem[cpu_addr[10:4]];
			cache_bank_out <= cache_mem[cpu_addr[10:2]];
		end
		
	end
	
	wire cache_line_match;
	assign cache_line_match = (cache_tag_out[20:0] == cpu_addr_buf[31:11])	&& cache_tag_out[21];
	
	//Cache hit/miss processing
	reg cache_miss = 0;
	always @(*) begin
		rd_data <= 0;
		rd_valid <= 0;
		cache_miss <= 0;
		
		//Do nothing if not processing a read
		if(rd_en_buf) begin
			
			//If last cycle was a miss, and/or we're processing a miss, declare this read to be a miss
			if(state != STATE_IDLE) begin
				cache_miss <= 1;
			end
			
			//If the tag matches and is valid, we're a hit
			else if( cache_line_match ) begin
				rd_data <= cache_bank_out;
				rd_valid <= 1;
			end
			
			//Otherwise, it's a miss
			else
				cache_miss <= 1;
				
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Controller-side interface
	
	reg cache_we = 0;
	reg[22:0] cache_tag_in = 0;
	reg[31:0] cache_data_in = 0;
	reg[8:0] cache_mem_addr = 0;
	
	reg cache_p2_en = 0;
	reg[22:0] cache_p2_tag_out = 0;
	
	always @(posedge clk) begin
	
		if(cache_p2_en) begin
			cache_p2_tag_out <= tag_mem[cache_mem_addr[8:2]];
			ctl_wr_data <= cache_mem[cache_mem_addr];
		
			if(cache_we) begin
				tag_mem[cache_mem_addr[8:2]] <= cache_tag_in;
				cache_mem[cache_mem_addr] <= cache_data_in;
			end
		end

	end

	assign ctl_wr_addr = {cache_p2_tag_out[20:0], cache_mem_addr[8:2], 4'b0};

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cache fetch state machine
	
	reg ctl_rd_done_buf = 0;
	reg flush_is_read = 0;
	
	//Combinatorial logic for cache writes
	//TODO: Try to eliminate all of the FFs for cache_we, cache_tag_in, cache_data_in, cache_mem_addr, cache_p2_en
	always @(*) begin
		
	end
	
	//Main sequential logic
	always @(posedge clk) begin
		
		ctl_rd_en <= 0;
		ctl_rd_done_buf <= ctl_rd_done;
		wr_done <= 0;
		ctl_wr_en <= 0;
		
		cache_we <= 0;
		cache_p2_en <= 0;
		
		rd_en_buf <= rd_en;
		wr_en_buf <= wr_en;
		
		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Sit around and wait for a cache miss
			
			STATE_IDLE: begin

				//Default tag: loopback and make dirty (used in wr_en_buf && cache_line_match case)
				cache_tag_in <= {1'b1, cache_tag_out[21:0]};
				cache_data_in <= cache_bank_out;
				cache_mem_addr <= cpu_addr[10:2];

				//Write was dispatched to cache, see if we have the line resident
				if(wr_en_buf) begin
					
					//If the line is already in cache, just write to it
					if(cache_line_match) begin
						
						//Start out by looping back the same data
						cache_we <= 1;
						cache_p2_en <= 1;
						
						//Write unmasked bits
						if(wr_mask[3])
							cache_data_in[31:24] <= wr_data[31:24];
						if(wr_mask[2])
							cache_data_in[23:16] <= wr_data[23:16];
						if(wr_mask[1])
							cache_data_in[15:8] <= wr_data[15:8];
						if(wr_mask[0])
							cache_data_in[7:0] <= wr_data[7:0];
						
						//Declare done immediately
						wr_done <= 1;
					end
					
					//Cache line is NOT a match.
					//If we're dirty, flush it.
					else if(cache_tag_out[22]) begin
				
						//Save flush settings
						flush_is_read <= 0;
						
						//Read the first word in the cache line
						cache_p2_en <= 1;
						cache_mem_addr <= {cpu_addr[10:4], 2'b0};
						
						//Wait a cycle for the read to complete
						state <= STATE_CACHE_FLUSH_0;
						
					end
					
					//Wrong cache line, but it's not dirty. Throw it away and load a new line.
					else begin
						ctl_rd_en <= 1;
						ctl_rd_addr <= {cpu_addr_buf[31:4], 4'h0};
						state <= STATE_WAIT_FOR_READ_WR;
					end
					
				end
			
				//Issue a read request to the cache controller
				else if(cache_miss) begin
				
					//We're dirty, need to flush old data before reading new stuff
					if(cache_tag_out[22]) begin
						
						//Save flush settings
						flush_is_read <= 1;
						
						//Read the first word in the cache line
						cache_p2_en <= 1;
						cache_mem_addr <= {cpu_addr[10:4], 2'b0};
						
						//Wait a cycle for the read to complete
						state <= STATE_CACHE_FLUSH_0;
						
					end
				
					//No, just issue the read
					else begin
						ctl_rd_en <= 1;
						ctl_rd_addr <= {cpu_addr_buf[31:4], 4'h0};
						state <= STATE_WAIT_FOR_READ;
					end
				end
				
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read logic
			
			//Wait for a read to come back from the DMA controller
			STATE_WAIT_FOR_READ: begin
			
				//Rewrite the tag for each write, it's mandatory for the cache controller to do a full-line write
				//To enforce this, clear the valid bit until the write is done
				cache_data_in <= ctl_rd_data;
				cache_tag_in <= {1'b0, ctl_rd_done, ctl_rd_daddr[31:11]};
				cache_mem_addr <= ctl_rd_daddr[10:2];
				if(ctl_rd_valid) begin
					cache_we <= 1;
					cache_p2_en <= 1;
				end
			
				if(ctl_rd_done_buf)
					state <= STATE_IDLE;
					
			end	//end STATE_WAIT_FOR_READ
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Write logic
			
			//Wait for a read to come back from the DMA controller, writing as we do so
			STATE_WAIT_FOR_READ_WR: begin
				
				//Write the original data back by default (valid and dirty)
				cache_data_in <= ctl_rd_data;
				cache_tag_in <= {2'b11, ctl_rd_daddr[31:11]};
				cache_mem_addr <= ctl_rd_daddr[10:2];
				
				if(ctl_rd_valid) begin
					cache_we <= 1;
					cache_p2_en <= 1;
					
					//Check if this is the correct word within the cache line, if so write to it
					if(ctl_rd_daddr[3:2] == cpu_addr[3:2]) begin
		
						//Write unmasked bits
						if(wr_mask[3])
							cache_data_in[31:24] <= wr_data[31:24];
						if(wr_mask[2])
							cache_data_in[23:16] <= wr_data[23:16];
						if(wr_mask[1])
							cache_data_in[15:8] <= wr_data[15:8];
						if(wr_mask[0])
							cache_data_in[7:0] <= wr_data[7:0];
							
					end

				end
			
				if(ctl_rd_done_buf) begin
					state <= STATE_IDLE;
					wr_done <= 1;
				end
			end	//end STATE_WAIT_FOR_READ_WR
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Flushing
			
			//Read the cache lines
			STATE_CACHE_FLUSH_0: begin
				
				//Read the next row
				cache_p2_en <= 1;
				cache_mem_addr <= cache_mem_addr + 9'h1;
								
				//Write this one back
				ctl_wr_en <= 1;
				if(cache_mem_addr[1:0] == 2'b10)
					state <= STATE_CACHE_FLUSH_1;
				
			end	//end STATE_CACHE_FLUSH_0
			
			//Read the last one
			STATE_CACHE_FLUSH_1: begin
								
				//Write this one back
				ctl_wr_en <= 1;
				state <= STATE_CACHE_FLUSH_2;
				
				//Blow out the tag on this line now that it's been flushed (leave data at whatever it was)
				cache_we <= 1;
				cache_p2_en <= 1;
				cache_tag_in <= 0;
				
			end	//end STATE_CACHE_FLUSH_1
			
			//Wait for DMA transaction to finish
			STATE_CACHE_FLUSH_2: begin
			
				//When the write finishes, continue whatever interrupted transaction we had in progress
				if(ctl_wr_done) begin
					
					if(flush_is_read)
						rd_en_buf <= 1;
										
					else
						wr_en_buf <= 1;
						
					state <= STATE_IDLE;
										
				end
			
			end	//end STATE_CACHE_FLUSH_2

			
		endcase
		
		//If we segfaulted, reset our state
		if(ctl_segfault) begin
			state <= STATE_IDLE;
			rd_en_buf <= 0;
			wr_en_buf <= 0;
		end
		
	end
	
endmodule

