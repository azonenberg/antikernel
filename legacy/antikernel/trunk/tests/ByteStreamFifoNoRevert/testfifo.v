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
	@brief ISim simulation test for ByteStreamFifoNoRevert
 */

module testByteStreamFifoNoRevert;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock generation

	reg	clk	= 0;
	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	
	always begin
		#5;
		clk = 0;
		#5;
		clk = ready;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	reg			wr_en	= 0;
	reg[31:0]	wr_data	= 0;
	reg[1:0]	wr_count = 0;
	wire		wr_overflow;
	wire[12:0]	wr_size;
	
	reg			rd_en		= 0;
	wire[12:0]	rd_avail;
	wire[31:0]	rd_data;
	wire[1:0]	rd_size;
	
	ByteStreamFifoNoRevert #(
		.DEPTH(1024)
	) fifo (
		.clk(clk),
		.wr_en(wr_en),
		.wr_data(wr_data),
		.wr_count(wr_count),
		.wr_size(wr_size),
		.wr_overflow(wr_overflow),
		.rd_en(rd_en),
		.rd_avail(rd_avail),
		.rd_data(rd_data),
		.rd_size(rd_size)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test logic
	
	reg[7:0] state	= 0;
	reg[7:0] count	= 0;
		
	always @(posedge clk) begin
		
		wr_en		<= 0;
		rd_en		<= 0;
		
		case(state)
			
			//Write 3 bytes, then 2 more
			0: begin
				wr_en		<= 1;
				wr_data		<= 32'hccddee00;
				wr_count	<= 2;
				state		<= 1;
			end
			1: begin
				wr_en		<= 1;
				wr_data		<= 32'hffaa0000;
				wr_count	<= 1;
				state		<= 2;
			end
			
			//Verify there are 5 words ready to read
			2: 	state		<= 3;
			3:	state		<= 4;
			4: begin
				if(rd_avail != 5) begin
					$display("FAIL: Expected 5 bytes ready to read, got %d\n", rd_avail);
					$finish;
				end
				state		<= 5;
			end
			
			//Read the first word, no big deal
			5: begin
				rd_en		<= 1;
				state		<= 6;
			end
			6:	state		<= 7;
			7: begin
				if( (rd_avail != 1) || (rd_data[31:0] != 32'hccddeeff) || (rd_size != 3) ) begin
					$display("FAIL: Expected 32'hccddeeff with 1 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				state		<= 8;
			end
			
			//There's now one byte ready. Push an additional word in one clock before, then read
			8: begin
				wr_en		<= 1;
				wr_data		<= 32'hbb000000;
				wr_count	<= 0;
				state		<= 9;
			end
			9: begin
				rd_en		<= 1;
				state		<= 10;
			end
			10: state		<= 11;
			
			11: begin
				if( (rd_avail != 0) || (rd_data[31:16] != 16'haabb) || (rd_size != 1) ) begin
					$display("FAIL: Expected 32'haabbxxxx with 0 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				state		<= 12;
			end
			
			//Push another byte
			12: begin
				wr_en		<= 1;
				wr_data		<= 32'hcc000000;
				wr_count	<= 0;
				state		<= 13;
			end
			
			//Issue a read immediately
			13: begin
				rd_en		<= 1;
				state		<= 14;
			end
			
			//Then issue a write during the delay period
			14: begin
				wr_en		<= 1;
				wr_data		<= 32'hdd000000;
				wr_count	<= 0;
				state		<= 15;
			end
			
			//Expected result is for the first write to commit, then anything after the read to be queued
			//Note that rd_avail is 0 after this read since the write hasn't committed yet
			15: begin
				if( (rd_avail != 0) || (rd_data[31:24] != 8'hcc) || (rd_size != 0) ) begin
					$display("FAIL: Expected 32'hccxxxxxx with 0 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				state		<= 16;
			end
			
			//One cycle later, there should be data to read
			16: begin
				if(rd_avail != 1) begin
					$display("FAIL: Expected 1 bytes ready to read, got %d\n", rd_avail);
					$finish;
				end
				state		<= 17;
			end
			
			//Read this and verify it's correct
			17: begin
				rd_en		<= 1;
				state		<= 18;
			end
			18:	state		<= 19;
			
			19: begin
				if( (rd_avail != 0) || (rd_data[31:24] != 8'hdd) || (rd_size != 0) ) begin
					$display("FAIL: Expected 32'hddxxxxxx with 0 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				state		<= 20;
			end
			
			//For now, we're good
			20: begin
				$display("PASS");
				$finish;
			end
			
		endcase
	
	end
	
	initial begin
		#25000;
		$display("FAIL: Test timed out");
		$finish;
	end
	
endmodule

