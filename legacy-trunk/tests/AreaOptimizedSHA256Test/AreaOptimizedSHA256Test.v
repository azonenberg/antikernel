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
	@brief Unit test for AreaOptimizedSHA256
 */

module AreaOptimizedSHA256Test();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Oscillator
	reg clk_100mhz = 0;
	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	always begin
		#5;
		clk_100mhz = 0;
		#5;
		clk_100mhz = ready;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The hasher
	
	reg reset = 0;
	reg we = 0;
	reg[31:0] din = 0;
	reg blockend = 0;
	reg finish = 0;
	wire resetdone;
	wire blockdone;
	wire done;
	wire[31:0] dout;
	
	AreaOptimizedSHA256 hasher(
		.clk(clk_100mhz),
		.reset(reset),
		.resetdone(resetdone),
		.we(we),
		.din(din),
		.blockend(blockend),
		.blockdone(blockdone),
		.finish(finish),
		.done(done),
		.dout(dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	reg[31:0] expected_hash = 0;
	reg[15:0] outcount = 0;
	always @(*) begin
	
		expected_hash <= 32'hcccccccc;
	
		case(outcount)
			0: expected_hash <= 32'he3b0c442;	//hash of empty string
			1: expected_hash <= 32'h98fc1c14;
			2: expected_hash <= 32'h9afbf4c8;
			3: expected_hash <= 32'h996fb924;
			4: expected_hash <= 32'h27ae41e4;
			5: expected_hash <= 32'h649b934c;
			6: expected_hash <= 32'ha495991b;
			7: expected_hash <= 32'h7852b855;
			
			8: expected_hash <= 32'h248d6a61;	//hash of abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq
			9: expected_hash <= 32'hd20638b8;
			10: expected_hash <= 32'he5c02693;
			11: expected_hash <= 32'h0c3e6039;
			12: expected_hash <= 32'ha33ce459;
			13: expected_hash <= 32'h64ff2167;
			14: expected_hash <= 32'hf6ecedd4;
			15: expected_hash <= 32'h19db06c1;
		endcase
	end
	
	wire hash_ok = (dout == expected_hash);
	
	reg[15:0] state = 0;
	reg[15:0] count = 0;
	always @(posedge clk_100mhz) begin
	
		reset <= 0;
		we <= 0;
		blockend <= 0;
		finish <= 0;
	
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// TEST 1 - single hash block
			
			//Hash the empty string and check results
			0: begin
				reset <= 1;
				state <= 1;
			end
			1: begin
				if(resetdone)
					state <= 2;
			end
			2: begin
				$display("Hashing the empty string");
				blockend <= 1;
				finish <= 1;
				state <= 3;
				outcount <= 0;
			end
			3: begin
				if(done) begin
					if(!hash_ok) begin
						$display("    FAIL (output mismatch, should be %x)\n", expected_hash);
						$finish;
					end
					state <= 4;
					outcount <= outcount + 1;
				end
			end
			4: begin
				outcount <= outcount + 1;
				if(!hash_ok) begin
					$display("    FAIL (output mismatch, should be %x)\n", expected_hash);
					$finish;
				end
				if(outcount == 7) begin
					state <= 5;
					$display("   OK");
				end
			end

			//Hash the string "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
			5: begin
				$display("Hashing \"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq\"");
				reset <= 1;
				state <= 6;
			end
			6: begin
				if(resetdone) begin
					state <= 7;
					count <= 0;
				end
			end
			7: begin
				we <= 1;
				count <= count + 1;
				case(count)
					0: din <= "abcd";
					1: din <= "bcde";
					2: din <= "cdef";
					3: din <= "defg";
					4: din <= "efgh";
					5: din <= "fghi";
					6: din <= "ghij";
					7: din <= "hijk";
					8: din <= "ijkl";
					9: din <= "jklm";
					10: din <= "klmn";
					11: din <= "lmno";
					12: din <= "mnop";
					13: begin
						din <= "nopq";
						state <= 8;
					end
				endcase
			end
			8: begin
				blockend <= 1;
				finish <= 1;
				state <= 9;
			end
			9: begin
				if(done) begin
					if(!hash_ok) begin
						$display("    FAIL (output mismatch, should be %x)\n", expected_hash);
						$finish;
					end
					state <= 10;
					outcount <= outcount + 1;
				end
			end
			10: begin
				outcount <= outcount + 1;
				if(!hash_ok) begin
					$display("    FAIL (output mismatch, should be %x)\n", expected_hash);
					$finish;
				end
				if(outcount == 15) begin
					state <= 11;
					$display("   OK");
				end
			end
			11: begin
				$display("PASS");
				$finish;
			end
			
			/*
			8: begin
				if(done) begin
					$display("    Hash is: %x", dout);
					if(dout != 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1) begin
						$display("FAIL (output mismatch)\n");
						$finish;
					end
					else begin
						$display("    OK");
						state <= 9;
					end
				end
			end
			
			
			*/
			default: begin
				$display("FAIL (invalid state)\n");
				$finish;
			end

		endcase
	end
	
	initial begin
		#10000;
		$display("FAIL (timeout)");
		$finish;
	end
		
endmodule

