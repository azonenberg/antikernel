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
	@brief A FIFO for processing a stream of bytes in word-sized chunks without a rollback mechanism.
	
	There are NO restrictions on write-during-read etc, making it suitable for arbitrary data processing.
	
	Note that if the FIFO is read to empty, the last read may contain <4 bytes of data.
	
	To PUSH data:
		Assert wr_en with wr_data containing 1-4 bytes of data (LEFT justified).
		Set wr_count to the number of bytes being pushed, minus one.
		
	To POP data:
		Wait for rd_avail to be a nonzero value
		Assert rd_en
		The next cycle:
			rd_data will have a left-justified value in it
			rd_size is the number of valid bytes in rd_data, minus one
 */
module ByteStreamFifoNoRevert(
	clk,
	wr_en, wr_data, wr_count, wr_size, wr_overflow,
	rd_en, rd_data, rd_avail, rd_size
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//1024 32-bit words = 4KB = two RAMB18
	parameter DEPTH	= 1024;
	
	//number of bits in the address bus
	`include "clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	//WRITE port
	input wire					wr_en;
	input wire[31:0]			wr_data;
	input wire[1:0]				wr_count;
	output wire[ADDR_BITS+2:0]	wr_size;
	output reg					wr_overflow = 0;
	
	//READ port
	input wire					rd_en;
	output reg[31:0]			rd_data		= 0;
	output reg[1:0]				rd_size		= 0;
	output wire[ADDR_BITS+2:0]	rd_avail;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read logic
	
	//Pointers
	reg[ADDR_BITS : 0]		rptr				= 0;
	reg[ADDR_BITS : 0]		wptr				= 0;
	
	reg						mem_wr			= 0;
	
	//The number of WORDS currently available to read
	wire[ADDR_BITS:0]		rd_words_avail		= wptr - rptr;
	
	//The incomplete word being staged for a write
	//RIGHT justified
	reg[31:0]				partial_wdata	= 0;
	reg[1:0]				partial_count	= 0;
	
	//The number of BYTES currently ready to read
	assign rd_avail			= {rd_words_avail, partial_count};
	
	//The number of BYTES available for us to write to
	wire[ADDR_BITS:0]		wptr_fwd = mem_wr ? (wptr + 1'd1) : wptr;
	wire[ADDR_BITS:0]		wr_wordsize = DEPTH[ADDR_BITS:0] + rptr - wptr_fwd;
	wire[2:0]				partial_count_inv = 3'd4 - partial_count;
	assign wr_size			= {wr_wordsize, 2'b00} + partial_count_inv;
	
	//Read data coming out of the RAM
	wire[31:0]				rd_data_raw;
	
	//Keep track of the previous read status
	reg						rd_from_ram_ff			= 0;
	reg[1:0]				partial_count_ff		= 0;
	reg[31:0]				partial_wdata_ff		= 0;
	always @(posedge clk) begin
		if(rd_en) begin
			rd_from_ram_ff		<= (rd_words_avail != 0);
			partial_count_ff	<= partial_count;
			partial_wdata_ff	<= partial_wdata;
		end
	end
	
	//May need to do some special stuff if we're reading the last word
	wire	reading_last_word	= rd_en && (rd_words_avail == 0);
	
	always @(*) begin
		
		
		//Reading from RAM?
		if(rd_from_ram_ff) begin
			rd_data		<= rd_data_raw;
			rd_size		<= 3;
		end
			
		//Nope, send the partial word. 
		//Spam the write data into the right side if a write is in prorgess
		else begin
		
			case(partial_count_ff)
				0:	rd_data	<= 32'h0;
				1:	rd_data	<= {partial_wdata_ff[7:0],  24'h0};
				2:	rd_data	<= {partial_wdata_ff[15:0], 16'h0};
				3:	rd_data	<= {partial_wdata_ff[23:0], 8'h0};
			endcase
			
			rd_size		<= partial_count_ff - 1'd1;
		end
		
	end
	
	//Bump read pointer after a successful read
	always @(posedge clk) begin
		
		if(rd_words_avail && rd_en)
			rptr	<= rptr + 1'b1;
			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Write logic
	
	//Write flags
	reg[31:0]				mem_wdata		= 0;
	
	//Number of bytes we have between the saved and incoming word
	wire[2:0]				total_bcount		= partial_count + wr_count + 1;

	//Concatenate the incoming data with the existing stuff and shift right
	//to truncate insignificant bits on the incoming data.
	reg[63:0]				wdata_concat_trunc		= 0;
	always @(*) begin
		case(wr_count)
			0:				wdata_concat_trunc	<= {24'h0, partial_wdata, wr_data[31:24]};
			1:				wdata_concat_trunc	<= {16'h0, partial_wdata, wr_data[31:16]};
			2:				wdata_concat_trunc	<= {8'h0, partial_wdata, wr_data[31:8]};
			3:				wdata_concat_trunc	<= {partial_wdata, wr_data};
		endcase
	end
	
	always @(posedge clk) begin
	
		mem_wr		<= 0;
		wr_overflow	<= 0;
		
		if(wr_en) begin
		
			//Write to the buffer
			if(!reading_last_word) begin
				
				//Save whatever data we're NOT writing right away
				partial_wdata	<= wdata_concat_trunc[31:0];
			
				//Detect if we're full and alarm
				if(wptr == (rptr + DEPTH))
					wr_overflow	<= 1;
				
				//If we have a partial word, use it
				else if(partial_count != 0) begin
					
					//Write the proper offset from the combined saved/incoming data
					case(total_bcount)
						4:	mem_wdata		<= wdata_concat_trunc[0 +: 32];
						5:	mem_wdata		<= wdata_concat_trunc[8 +: 32];
						6:	mem_wdata		<= wdata_concat_trunc[16 +: 32];
						7:	mem_wdata		<= wdata_concat_trunc[24 +: 32];
					endcase
					
					//Do we have enough to make data to push? If so, send it to memory
					if(total_bcount >= 4 )
						mem_wr		<= 1;
					
					//Update the count
					partial_count	<= total_bcount[1:0];

				end
				
				//No partial word
				else begin
						
					mem_wdata		<= wr_data;
							
					//Pushing a whole word? Easy
					if(wr_count == 3) begin
						mem_wr			<= 1;
						partial_count	<= 0;
					end
					
					//Nope, save the incoming data
					else
						partial_count	<= total_bcount[1:0];
				
				end
				
			end
		
			//Reading last word during a write - forward to the output and write whatever is left
			else begin
				
				//All of the saved, and some of the incoming, data are going to the output
				//Save whatever is left
				case(total_bcount[1:0])
					0:	partial_wdata	<= 0;
					1:	partial_wdata	<= wdata_concat_trunc[7:0];
					2:	partial_wdata	<= wdata_concat_trunc[15:0];
					3:	partial_wdata	<= wdata_concat_trunc[23:0];
				endcase
				
				//Trim off the 4 bytes, anything left is good
				partial_count			<= total_bcount[1:0];
								
			end
			
		end
		
		//If reading the last word, clear out the partial word
		else if(reading_last_word)
			partial_count	<= 0;
		
		//Bump write pointer if we just finished a write
		if(mem_wr)
			wptr		<= wptr + 1'd1;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The memory
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) mem (
	
		.porta_clk(clk),
		.porta_en(mem_wr),
		.porta_addr(wptr[ADDR_BITS-1 : 0]),
		.porta_we(mem_wr),
		.porta_din(mem_wdata),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(rd_en),
		.portb_addr(rptr[ADDR_BITS-1 : 0]),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(rd_data_raw)
	);
	
endmodule
