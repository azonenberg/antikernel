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
	@brief ISim simulation test for ByteStreamFifo
 */

module testByteStreamFifo;

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
	reg			wr_commit = 0;
	reg			wr_rollback = 0;
	wire		wr_overflow;
	
	reg			rd_en		= 0;
	wire[12:0]	rd_avail;
	wire[31:0]	rd_data;
	
	ByteStreamFifo #(
		.DEPTH(1024)
	) fifo (
		.clk(clk),
		.reset(1'b0),
		.wr_en(wr_en),
		.wr_data(wr_data),
		.wr_count(wr_count),
		.wr_commit(wr_commit),
		.wr_rollback(wr_rollback),
		.wr_overflow(wr_overflow),
		.rd_en(rd_en),
		.rd_avail(rd_avail),
		.rd_data(rd_data)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test logic
	
	reg[7:0] state	= 0;
	reg[7:0] count	= 0;
		
	always @(posedge clk) begin
	
		wr_en		<= 0;
		wr_commit	<= 0;
		wr_rollback	<= 0;
		rd_en		<= 0;
	
		case(state)
			
			//Push one byte at a time for five bytes.
			//At the end of this we should have 'h01234567 in RAM and 'h89 pending
			0: begin
				wr_en		<= 1;
				wr_data		<= 32'h01000000;
				wr_count	<= 0;
				state		<= 1;
			end
			1: begin
				wr_en		<= 1;
				wr_data		<= 32'h23000000;
				wr_count	<= 0;
				state		<= 2;
			end
			2: begin
				wr_en		<= 1;
				wr_data		<= 32'h45000000;
				wr_count	<= 0;
				state		<= 3;
			end
			3: begin
				wr_en		<= 1;
				wr_data		<= 32'h67000000;
				wr_count	<= 0;
				state		<= 4;
			end
			4: begin
				wr_en		<= 1;
				wr_data		<= 32'h89000000;
				wr_count	<= 0;
				state		<= 5;
			end
			
			//Push two more bytes in. We should now have 'h89abcd pending
			5: begin
				wr_en		<= 1;
				wr_data		<= 32'habcd0000;
				wr_count	<= 1;
				state		<= 6;
			end
			
			//Push two more bytes. Should push 'h89abcdef to RAM and have 'hcc pending
			6: begin
				wr_en		<= 1;
				wr_data		<= 32'hefcc0000;
				wr_count	<= 1;
				state		<= 7;
			end
			
			//Push three more. Should push 'hccddeeff to RAM and have nothing pending
			7: begin
				wr_en		<= 1;
				wr_data		<= 32'hddeeff00;
				wr_count	<= 2;
				state		<= 8;
			end
			
			//Push four bytes in one go
			8: begin
				wr_en		<= 1;
				wr_data		<= 32'h11223344;
				wr_count	<= 3;
				state		<= 9;
			end
			
			//then push one more byte which will stay in the pending queue
			9: begin
				wr_en		<= 1;
				wr_data		<= 32'haa000000;
				wr_count	<= 0;
				state		<= 10;
			end
			
			//Wait for write to complete
			10: begin
				state		<= 11;
			end
			
			//Checksum of our fictional packet (17 bytes) is good, commit changes
			11: begin
				wr_commit	<= 1;
				state		<= 12;
			end
			
			//Push three more bytes that will later be reverted
			12: begin
				wr_en		<= 1;
				wr_data		<= 32'hcdcdcd00;
				wr_count	<= 2;
				state		<= 13;
			end
			
			//Roll it back
			13: begin
			
				//Verify that we have 17 bytes ready to read
				if(rd_avail != 17) begin
					$display("FAIL: Expected 17 bytes ready to read, got %d instead", rd_avail);
					$finish;
				end
				
				//Do the rollback
				wr_rollback	<= 1;
				state		<= 14;
			end
			
			//Push three more bytes that we're keeping
			14: begin
				wr_en		<= 1;
				wr_data		<= 32'heeeeee00;
				wr_count	<= 2;
				state		<= 15;
			end
			
			//Wait for write to complete
			15: begin
				state		<= 16;
			end
			
			//Checksum of our fictional packet (3 bytes, total 20) is good, commit changes
			16: begin
				wr_commit	<= 1;
				state		<= 17;
			end
			
			//Wait for flag update latency
			17: begin
				state		<= 18;
			end
			
			//Verify that we have 20 bytes ready to read
			18: begin
				if(rd_avail != 20) begin
					$display("FAIL: Expected 20 bytes ready to read, got %d instead", rd_avail);
					$finish;
				end
				state		<= 19;
			end
			
			//Push and commit two bytes
			19: begin
				wr_en		<= 1;
				wr_data		<= 32'hbeef0000;
				wr_count	<= 1;
				state		<= 20;
			end
			20: begin
				state		<= 21;
			end
			21: begin
				wr_commit	<= 1;
				state		<= 22;
			end
			22: begin
				state		<= 23;
			end
			
			//Verify we have 22 bytes (5 words + 2 bytes) ready to read
			23: begin
				if(rd_avail != 22) begin
					$display("FAIL: Expected 22 bytes ready to read, got %d instead", rd_avail);
					$finish;
				end
				state		<= 24;
			end
			
			//Read the 5 full words and verify them
			24: begin
				rd_en		<= 1;
				state		<= 25;
			end
			25: begin
				rd_en		<= 1;
				state		<= 26;
			end
			26: begin
				rd_en		<= 1;
				state		<= 27;
				
				if( (rd_avail != 18) || (rd_data != 32'h01234567) ) begin
					$display("FAIL: Expected 32'h01234567 with 18 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			27: begin
				rd_en		<= 1;
				state		<= 28;

				if( (rd_avail != 14) || (rd_data != 32'h89abcdef) ) begin
					$display("FAIL: Expected 32'h89abcdef with 14 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			28: begin
				rd_en		<= 1;
				state		<= 29;
				
				if( (rd_avail != 10) || (rd_data != 32'hccddeeff) ) begin
					$display("FAIL: Expected 32'hccddeeff with 10 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			29: begin
				state		<= 30;
				
				if( (rd_avail != 6) || (rd_data != 32'h11223344) ) begin
					$display("FAIL: Expected 32'h11223344 with 6 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			30: begin
				state		<= 31;
				
				if( (rd_avail != 2) || (rd_data != 32'haaeeeeee) ) begin
					$display("FAIL: Expected 32'haaeeeeee with 2 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			
			//Read the last two bytes (partial word)
			31: begin
				rd_en		<= 1;
				state		<= 32;
			end
			32: begin
				state		<= 33;
			end
			
			//Validate (last 16 bits are don't care)
			33: begin
				if( (rd_avail != 0) || (rd_data[31:16] != 16'hbeef) ) begin
					$display("FAIL: Expected 32'hbeefxxxx with 0 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				state	<= 34;
			end

			//Push in "hello world"
			34: begin
				wr_en		<= 1;
				wr_data		<= 32'h68656c5c;
				wr_count	<= 3;
				state		<= 35;
			end
			35: begin
				wr_en		<= 1;
				wr_data		<= 32'h6f20776f;
				wr_count	<= 3;
				state		<= 36;
			end
			36: begin
				wr_en		<= 1;
				wr_data		<= 32'h726c6400;
				wr_count	<= 2;
				state		<= 37;
			end
			
			//Commit it
			37: begin
				state		<= 38;
			end
			38: begin
				wr_commit	<= 1;
				state		<= 39;
			end
			39: begin
				state		<= 40;
			end
			
			//Verify it's good
			40: begin
				if(rd_avail != 11) begin
					$display("FAIL: Expected 11 bytes ready to read, got %d instead", rd_avail);
					$finish;
				end
				state		<= 41;
			end
			41: begin
				rd_en		<= 1;
				state		<= 42;
			end
			42: begin
				rd_en		<= 1;
				state		<= 43;
			end
			43: begin
				rd_en		<= 1;
				state		<= 44;
				
				if( (rd_avail != 7) || (rd_data != 32'h68656c5c) ) begin
					$display("FAIL: Expected 32'h68656c5c with 7 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			44: begin
				state		<= 45;
				
				if( (rd_avail != 3) || (rd_data != 32'h6f20776f) ) begin
					$display("FAIL: Expected 32'h6f20776f with 3 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
			end
			45: begin
				state		<= 46;
				
				if( (rd_avail != 0) || (rd_data[31:8] != 24'h726c64) ) begin
					$display("FAIL: Expected 32'h726c64xx with 0 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
			end
			
			//Push in "hai!"
			46: begin
				wr_en		<= 1;
				wr_data		<= 32'h68616921;
				wr_count	<= 3;
				state		<= 47;
			end
			
			//Commit it
			47: begin
				state		<= 48;
			end
			48: begin
				wr_commit	<= 1;
				state		<= 49;
			end
			49: begin
				state		<= 50;
			end
			
			50: begin
				if(rd_avail != 4) begin
					$display("FAIL: Expected 4 bytes ready to read, got %d instead", rd_avail);
					$finish;
				end
				state		<= 51;
			end
			51: begin
				rd_en		<= 1;
				state		<= 52;
			end
			52: begin
				state		<= 53;
			end
			53: begin
				rd_en		<= 1;
				state		<= 54;
				
				if( (rd_avail != 0) || (rd_data != 32'h68616921) ) begin
					$display("FAIL: Expected 32'h68616921 with 0 bytes ready to read");
					$display("    got %08x with %d bytes ready instead", rd_data, rd_avail);
					$finish;
				end
				
			end
			
			//For now, we're good
			54: begin
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

