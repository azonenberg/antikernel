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
	@brief Unit test for MicrocodedSHA256
 */

module MicrocodedSHA256Test();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Oscillator
	reg clk		= 0;
	reg ready	= 0;
	initial begin
		#100;
		ready	= 1;
	end
	always begin
		#5;
		clk = 0;
		#5;
		clk = ready;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The hasher
	
	reg			start_en 	= 0;
	reg			data_en		= 0;
	reg			finish_en	= 0;
	reg[31:0]	din			= 0;
	
	wire		done;
	wire		dout_valid;
	wire[31:0]	dout;
	
	MicrocodedSHA256 hasher(
		.clk(clk),
		.start_en(start_en),
		.data_en(data_en),
		.finish_en(finish_en),
		.din(din),
		.done(done),
		.dout_valid(dout_valid),
		.dout(dout)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	reg[7:0] state = 0;
	reg[7:0] count = 0;
	
	reg[255:0] output_hash = 0;
	
	always @(posedge clk) begin
	
		start_en	<= 0;
		data_en		<= 0;
		finish_en	<= 0;
		din			<= 0;
		
		//Save output hash
		if(dout_valid)
			output_hash <= {output_hash[223:0], dout};
	
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 1: empty string
			
			//Initialize hasher
			0: begin
				$display("Preparing to start hash");
				start_en	<= 1;
				state		<= 1;
			end
			
			//Wait for reset
			1: begin
				if(done)
					state <= 2;
			end
			
			//Hash the empty string (no additional input)
			2: begin
				$display("Hashing empty string");
				finish_en	<= 1;
				state		<= 3;
			end
			
			//Wait for it to be done
			3: begin
				if(done) begin
					
					if(output_hash == 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855)
						$display("  Got correct hash");
					
					else begin
						$display("FAIL: Wrong hash");
						$finish;
					end
					
					state	<= 4;
				end
			end

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 2: "abcd"
			
			4: begin
				$display("Preparing to start hash");
				start_en	<= 1;
				state		<= 5;
			end
			
			//Wait for reset
			5: begin
				if(done)
					state <= 6;
			end
			
			//Feed in the string
			6: begin
				data_en	<= 1;
				din		<= "abcd";
				state	<= 7;
			end
			
			//Wait for it to be saved
			7: begin
				if(done)
					state <= 8;
			end

			//Hash it
			8: begin
				$display("Hashing abcd");
				finish_en	<= 1;
				state		<= 9;
			end
			
			9: begin
				if(done) begin
					
					//$display("Hash done: %x", output_hash);
					
					if(output_hash == 256'h88d4266fd4e6338d13b845fcf289579d209c897823b9217da3e161936f031589)
						$display("  Got correct hash");
					
					else begin
						$display("FAIL: Wrong hash");
						$finish;
					end
					
					state	<= 10;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 3: "abcdefghabcdefghabcdefghabcdefgh"
			
			10: begin
				$display("Preparing to start hash");
				start_en	<= 1;
				count		<= 0;
				state		<= 11;
			end
			
			//Wait for reset
			11: begin
				if(done)
					state <= 12;
			end
			
			//Feed in the string
			12: begin
				data_en	<= 1;
				din		<= "abcd";
				state	<= 13;
			end
			
			//Wait for it to be saved
			13: begin
				if(done) begin
					data_en	<= 1;
					din		<= "efgh";
					count	<= count + 1;
					state	<= 14;
				end
			end
			
			//Check if we're done (4 reps)
			14: begin
				if(done) begin
					if(count == 4)
						state <= 15;
					else
						state <= 12;
				end
			end
			
			//Hash it
			15: begin
				$display("Finishing abcdefghabcdefghabcdefghabcdefgh");
				finish_en	<= 1;
				state		<= 16;
			end
			
			16: begin
				if(done) begin
					
					$display("Hash done: %x", output_hash);
					
					if(output_hash == 256'h1d6e6c1b375918f2c312a2c52bd4b93666537044f08b82a4c3b265e921928416)
						$display("  Got correct hash");
					
					else begin
						$display("FAIL: Wrong hash");
						$finish;
					end
					
					state	<= 17;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 4: "abcdefghabcdefghabcdefghabcdefgh"
			
			17: begin
				$display("Preparing to start hash");
				start_en	<= 1;
				count		<= 0;
				state		<= 18;
			end
			
			//Wait for reset
			18: begin
				if(done)
					state <= 19;
			end
			
			//Feed in the string
			19: begin
				data_en	<= 1;
				din		<= "abcd";
				state	<= 20;
			end
			
			//Wait for it to be saved
			20: begin
				if(done) begin
					data_en	<= 1;
					din		<= "efgh";
					count	<= count + 1;
					state	<= 21;
				end
			end
			
			//Check if we're done (8 reps)
			21: begin
				if(done) begin
					if(count == 8)
						state <= 22;
					else
						state <= 19;
				end
			end
			
			//Hash it
			22: begin
				$display("Finishing abcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefgh");
				finish_en	<= 1;
				state		<= 23;
			end
			
			23: begin
				if(done) begin
					
					$display("Hash done: %x", output_hash);
					
					if(output_hash == 256'h606279ea3d1b4f964b5059cd7e96e6fb7c54a71919ed4380030d0a645d97edf7)
						$display("  Got correct hash");
					
					else begin
						$display("FAIL: Wrong hash");
						$finish;
					end
					
					state	<= 24;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 5: MIPS executable plus HMAC padding
			
			24: begin
				$display("Preparing to start hash (MIPS EXE)");
				start_en	<= 1;
				count		<= 0;
				state		<= 25;
			end
			
			//Wait for reset
			25: begin
				if(done) begin
					count	<= 0;
					state 	<= 26;
				end
			end
			
			//Feed in the string
			26: begin
				data_en	<= 1;
				count	<= count + 1;
				state	<= 27;
				
				case(count)
					 0: din <= 32'he325b9c2;
					 1: din <= 32'hbdaa5951;
					 2: din <= 32'h764ad833;
					 3: din <= 32'h0a54868e;
					 4: din <= 32'h569ee26e;
					 5: din <= 32'h7040f017;
					 6: din <= 32'hae43caaa;
					 7: din <= 32'hfd5c01aa;
					 8: din <= 32'he0aaf705;
					 9: din <= 32'hd116f84e;
					10: din <= 32'h7fb1ff7a;
					11: din <= 32'hd3142285;
					12: din <= 32'hc4966274;
					13: din <= 32'h6ba76ab3;
					14: din <= 32'hd5dbfdfb;
					15: din <= 32'hc0d55aed;
					16: din <= 32'h40000000;
					17: din <= 32'h3c08feed;
					18: din <= 32'h3508face;
					19: din <= 32'h01000013;
					20: din <= 32'h00004812;
					21: din <= 32'h3c0adead;
					22: din <= 32'h354af00d;
					23: din <= 32'h01400011;
					24: din <= 32'h00004010;
					25: din <= 32'h3c047261;
					26: din <= 32'h34846d00;
					27: din <= 32'h00002821;
					28: din <= 32'h0c00000f;
					29: din <= 32'h00200825;
					30: din <= 32'h0800000d;
					31: din <= 32'h00200825;
					32: din <= 32'h00a03821;
					33: din <= 32'h00803021;
					34: din <= 32'h3c040001;
					35: din <= 32'h34848000;
					36: din <= 32'h3c050100;
					37: din <= 32'h0000000c;
					38: din <= 32'h34098000;
					39: din <= 32'h3c040002;
					40: din <= 32'h0000000c;
					41: din <= 32'h00034402;
					42: din <= 32'h1509fffc;
					43: din <= 32'h00200825;
					44: din <= 32'h24030000;
					45: din <= 32'h00024542;
					46: din <= 32'h31080007;
					47: din <= 32'h240a0001;
					48: din <= 32'h150a0001;
					49: din <= 32'h24030001;
					50: din <= 32'h3042ffff;
					51: din <= 32'h03e00008;
					52: din <= 32'h00200825;
					53: din <= 32'h27bdfff8;
					54: din <= 32'hafbe0004;
					55: din <= 32'h03a0f021;
					56: din <= 32'h08000027;
					57: din <= 32'h00200825;
					58: din <= 32'h00200825;
					59: din <= 32'h00200825;
					60: din <= 32'h00200825;
				endcase
			end
			
			//Wait for it to be saved
			27: begin
				if(done) begin
					state		<= 26;
					if(count == 61)
						state	<= 28;
				end
			end
			
			28: begin
				$display("Finishing hash");
				finish_en	<= 1;
				state		<= 29;
			end
			
			29: begin
				if(done) begin
					
					$display("Hash done: %x", output_hash);
					
					if(output_hash == 256'haae4812135993d4f973aa6aad2417172c366c52b58ac8314c6d214e2c99026ae)
						$display("  Got correct hash");
					
					else begin
						$display("FAIL: Wrong hash");
						$finish;
					end
					
					state	<= 30;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Done 
			
			30: begin
				$display("PASS");
				$finish;
			end
		
		endcase
	
	end
	
	initial begin
		#5000000;
		$display("FAIL: Test timed out");
		$finish;
	end

endmodule
