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
	@brief A FIFO for processing a stream of bytes in word-sized chunks
	
	To PUSH data:
		Assert wr_en with wr_data containing 1-4 bytes of data (LEFT justified).
		Set wr_count to the number of bytes being pushed, minus one.
		
		If wr_overflow is set, the FIFO overflowed and must be rolled back to avoid data loss.
			
	A full 32-bit word can be pushed at any point when there's at least one word available even if the FIFO has
	a non-integer number of words in it.
	
	Data pushed into the FIFO is not available for readout until it is committed (after verifying that the packet
	checksum and sequence numbers are good). Assert the wr_commit signal to commit pushed data and enable readout.
	If the pushed data is corrupted (bad checksum etc) assert the wr_rollback signal to drop the packet.	
	
	To POP data:
		Assert rd_en
		Note that if rd_avail isn't a multiple of 4 bytes the last word read may be partial (garbage at end)
		
	There is a 1-cycle latency period between writes and commits. A commit may not be issued the same cycle as,
	or immediately after, a write.
	
	Rollbacks may be issued at any time with respect to writes. A commit may not be issued the same cycle
	as a rollback.
	
	A read of the last word in the FIFO (if a partial word) may not be issued the same cycle as a write, commit,
	or rollback.
 */
module ByteStreamFifo(
	clk, reset,
	wr_en, wr_data, wr_count, wr_commit, wr_rollback, wr_overflow,
	rd_en, rd_data, rd_avail
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
	input wire			reset;
	
	//WRITE port
	input wire				wr_en;
	input wire[31:0]		wr_data;
	input wire[1:0]			wr_count;
	input wire				wr_commit;
	input wire				wr_rollback;
	output reg				wr_overflow	= 0;
	
	//READ port
	input wire					rd_en;
	output reg[31:0]			rd_data		= 0;
	output wire[ADDR_BITS+2:0]	rd_avail;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read logic
	
	//The committed state as of the start of the active packet. RIGHT aligned!
	reg[31:0]				saved_partial_wdata	= 0;
	reg[1:0]				saved_partial_count	= 0;
	reg[ADDR_BITS : 0]		saved_wptr			= 0;
	
	//Read address
	reg[ADDR_BITS : 0]		rptr				= 0;
	
	//The number of WORDS currently available to read
	wire[ADDR_BITS:0]		rd_words_avail		= saved_wptr - rptr;
	
	//The number of BYTES currently ready to read
	assign rd_avail			= {rd_words_avail, saved_partial_count};
	
	//Read data coming out of the RAM
	wire[31:0]				rd_data_raw;
	
	//Keep track of the previous read status
	reg						rd_from_ram_ff			= 0;
	reg[1:0]				saved_partial_count_ff	= 0;
	always @(posedge clk) begin
		rd_from_ram_ff			<= (rd_words_avail != 0);
		saved_partial_count_ff	<= saved_partial_count;
		
		if(reset) begin
			rd_from_ram_ff			<= 0;
			saved_partial_count_ff	<= 0;
		end
		
	end
	
	//TODO: Figure out how to handle commits during a read of the last word
	always @(*) begin
		
		//Reading from RAM?
		if(rd_from_ram_ff)
			rd_data		<= rd_data_raw;
			
		//Nope, send the committed partial word
		else begin
			case(saved_partial_count_ff)
				0:	rd_data	<= 32'h0;
				1:	rd_data	<= {saved_partial_wdata[7:0],  24'h0};
				2:	rd_data	<= {saved_partial_wdata[15:0], 16'h0};
				3:	rd_data	<= {saved_partial_wdata[23:0], 8'h0};
			endcase
		end
		
	end
	
	//Bump read pointer after a successful read
	always @(posedge clk) begin
		
		if(rd_words_avail && rd_en)
			rptr	<= rptr + 1'b1;
			
		if(reset)
			rptr	<= 0;
			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Write logic
	
	//The incomplete word being staged for a write
	//RIGHT justified
	reg[31:0]				partial_wdata	= 0;
	reg[1:0]				partial_count	= 0;
	
	//Write flags
	reg[ADDR_BITS : 0]		wptr			= 0;
	reg						mem_wr			= 0;
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
	
	//May need to do some special stuff if we're reading the last word
	wire	reading_last_word	= rd_en && (rd_words_avail == 0);
	
	//We have uncommitted data if the saved and current write pointers don't line up
	wire	has_uncommitted		= (wptr != saved_wptr);
	
	always @(posedge clk) begin
	
		mem_wr		<= 0;
		wr_overflow	<= 0;
		
		//Clear word counts if we are reading the last word
		if(reading_last_word) begin
			saved_partial_count	<= 0;
			if(!has_uncommitted)
				partial_count	<= 0;
		end
		
		//Bump write pointer if we just finished a write
		if(mem_wr)
			wptr		<= wptr + 1'd1;
		
		//Process writes
		if(wr_en) begin
		
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
		
		//Process commits
		if(wr_commit) begin
			saved_wptr			<= wptr;
			saved_partial_count	<= partial_count;
			saved_partial_wdata	<= partial_wdata;
		end
		
		//Process rollbacks
		if(wr_rollback) begin
			wptr				<= saved_wptr;
			partial_count		<= saved_partial_count;
			partial_wdata		<= saved_partial_wdata;
		end
		
		if(reset) begin
			wptr				<= 0;
			partial_count		<= 0;
			partial_wdata		<= 0;
			saved_partial_count	<= 0;
			saved_partial_wdata	<= 0;
		end
		
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
