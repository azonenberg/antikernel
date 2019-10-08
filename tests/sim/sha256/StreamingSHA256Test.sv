`timescale 1ns / 1ps
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2019 Andrew D. Zonenberg                                                                          *
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

module StreamingSHA256Test();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock synthesis

	logic		clk = 0;

	always begin
		#5;
		clk = 0;
		#5;
		clk = 1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	logic		start 		= 0;
	logic		update 		= 0;
	logic[31:0]	data_in		= 0;
	logic[2:0]	bytes_valid	= 0;
	logic		finalize	= 0;

	wire		hash_valid;
	wire[255:0]	hash;

	StreamingSHA256 dut(
		.clk(clk),
		.start(start),
		.update(update),
		.data_in(data_in),
		.bytes_valid(bytes_valid),
		.finalize(finalize),
		.hash_valid(hash_valid),
		.hash(hash)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test inputs

	logic[7:0] state = 0;
	logic[7:0] count = 0;

	always_ff @(posedge clk) begin

		start		<= 0;
		update		<= 0;
		finalize	<= 0;
		count		<= 0;

		case(state)

			//"a" -> ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
			//Single byte
			0: begin
				start		<= 1;
				state		<= 1;
				$display("Hash 'a':");
			end

			1: begin
				update		<= 1;
				data_in		<= {"a", 24'h0};
				bytes_valid	<= 1;
				state		<= 2;
			end

			2: begin
				finalize	<= 1;
				state		<= 3;
			end

			3: begin
				if(hash_valid) begin
					if(hash == 256'hca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb) begin
						$display("PASS");

						//"" -> e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
						//Empty string
						start		<= 1;
						state		<= 4;
						$display("Hash '':");
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

			4: begin
				finalize	<= 1;
				state		<= 5;
			end

			5: begin
				if(hash_valid) begin
					if(hash == 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855) begin
						$display("PASS");

						//"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ->
						//d53eda7a637c99cc7fb566d96e9fa109bf15c478410a3f5eb4d4c4e26cd081f6
						//Full block of content, then second block with padding+length
						$display("Hash 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA':");
						start	<= 1;
						state	<= 6;
						count	<= 0;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end

			end

			6: begin
				update		<= 1;
				data_in		<= "AAAA";
				bytes_valid	<= 4;
				count		<= count + 1;

				if(count == 15)
					state	<= 7;
			end

			7: begin
				finalize	<= 1;
				state		<= 8;
			end

			8: begin
				if(hash_valid) begin
					if(hash == 256'hd53eda7a637c99cc7fb566d96e9fa109bf15c478410a3f5eb4d4c4e26cd081f6) begin
						$display("PASS");
						state	<= 9;

						//"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ->
						//836203944f4c0280461ad73d31457c22ba19d1d99e232dc231000085899e00a2
						//Full block, then second block with one byte of data then padding/length
						$display("Hash 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA':");
						start	<= 1;
						state	<= 9;
						count	<= 0;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

			9: begin
				update		<= 1;
				data_in		<= "AAAA";
				bytes_valid	<= 4;
				count		<= count + 1;

				if(count == 16) begin
					bytes_valid	<= 1;
					data_in		<= "A   ";
					state		<= 10;
				end

			end

			10: begin
				finalize	<= 1;
				state		<= 11;
			end

			11: begin
				if(hash_valid) begin
					if(hash == 256'h836203944f4c0280461ad73d31457c22ba19d1d99e232dc231000085899e00a2) begin
						$display("PASS");

						//"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ->
						//1b58d00f5b1fbd2a1884d666a2be33c2fa7463dff32cd60ef200c0f750a6b70f
						//Full block of content, padding, then second block with length only
						$display("Hash 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA':");
						start	<= 1;
						state	<= 12;
						count	<= 0;

					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

			12: begin
				update		<= 1;
				data_in		<= "AAAA";
				bytes_valid	<= 4;
				count		<= count + 1;

				if(count == 15) begin
					bytes_valid	<= 3;
					data_in		<= "AAA ";
					state		<= 13;
				end

			end

			13: begin
				finalize	<= 1;
				state		<= 14;
			end

			14: begin
				if(hash_valid) begin
					if(hash == 256'h1b58d00f5b1fbd2a1884d666a2be33c2fa7463dff32cd60ef200c0f750a6b70f) begin
						$display("PASS");

						//"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ->
						//96b437b3df7c62fc877a121b087899f5e36a58f6d87ba52d997e92bb016aa575
						//Full block of content, then second block with a bunch of data then padding and length
						$display("Hash 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA':");
						start	<= 1;
						state	<= 15;
						count	<= 0;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

			15: begin
				update		<= 1;
				data_in		<= "AAAA";
				bytes_valid	<= 4;
				count		<= count + 1;

				if(count == 17) begin
					bytes_valid	<= 3;
					data_in		<= "AAA ";
					state		<= 16;
				end

			end

			16: begin
				finalize	<= 1;
				state		<= 17;
			end

			17: begin
				if(hash_valid) begin
					if(hash == 256'h96b437b3df7c62fc877a121b087899f5e36a58f6d87ba52d997e92bb016aa575) begin
						$display("PASS");

						//"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ->
						//1581baebc5f9dcfd89c658b3c3303203fc0e2f93e3f9e0b593d8b2b8112c6eda
						//Full block of content, then second block with a bunch of data then padding and length
						$display("Hash 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA':");
						start	<= 1;
						state	<= 18;
						count	<= 0;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

			18: begin
				update		<= 1;
				data_in		<= "AAAA";
				bytes_valid	<= 4;
				count		<= count + 1;

				if(count == 19) begin
					bytes_valid	<= 3;
					data_in		<= "AAA ";
					state		<= 19;
				end

			end

			19: begin
				finalize	<= 1;
				state		<= 20;
			end

			20: begin
				if(hash_valid) begin
					if(hash == 256'h1581baebc5f9dcfd89c658b3c3303203fc0e2f93e3f9e0b593d8b2b8112c6eda) begin
						$display("PASS");
						state	<= 21;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end

		endcase

	end

endmodule
