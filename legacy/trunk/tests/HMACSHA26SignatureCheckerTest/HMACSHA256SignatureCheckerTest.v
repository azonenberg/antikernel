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
	@brief Unit test for HMACSHA256SignatureChecker
 */

module HMACSHA256SignatureCheckerTest();

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
	
	wire		done2;
	wire		dout_valid2;
	wire[31:0]	dout2;
	
	HMACSHA256SignatureChecker #(
		.KEY_0(32'h0b0b0b0b),
		.KEY_1(32'h0b0b0b0b),
		.KEY_2(32'h0b0b0b0b),
		.KEY_3(32'h0b0b0b0b),
		.KEY_4(32'h0b0b0b0b),
		.KEY_5(32'h00000000),
		.KEY_6(32'h00000000),
		.KEY_7(32'h00000000),
		.KEY_8(32'h00000000),
		.KEY_9(32'h00000000),
		.KEY_A(32'h00000000),
		.KEY_B(32'h00000000),
		.KEY_C(32'h00000000),
		.KEY_D(32'h00000000),
		.KEY_E(32'h00000000),
		.KEY_F(32'h00000000)
	) hmac(
		.clk(clk),
		.start_en(start_en),
		.data_en(data_en),
		.finish_en(finish_en),
		.din(din),
		.done(done),
		.dout_valid(dout_valid),
		.dout(dout)
		);
		
	HMACSHA256SignatureChecker #(
		.KEY_0(32'hd5138ff4),
		.KEY_1(32'h8b9c6f67),
		.KEY_2(32'h407cee05),
		.KEY_3(32'h3c62b0b8),
		.KEY_4(32'h60a8d458),
		.KEY_5(32'h4676c621),
		.KEY_6(32'h9875fc9c),
		.KEY_7(32'hcb6a379c),
		.KEY_8(32'hd69cc133),
		.KEY_9(32'he720ce78),
		.KEY_A(32'h4987c94c),
		.KEY_B(32'he52214b3),
		.KEY_C(32'hf2a05442),
		.KEY_D(32'h5d915c85),
		.KEY_E(32'he3edcbcd),
		.KEY_F(32'hf6e36cdb)
	) hmac2(
		.clk(clk),
		.start_en(start_en),
		.data_en(data_en),
		.finish_en(finish_en),
		.din(din),
		.done(done2),
		.dout_valid(dout_valid2),
		.dout(dout2)
		);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	reg[7:0] state = 0;
	reg[7:0] count = 0;
	
	reg[255:0] output_hash = 0;
	reg[255:0] output_hash2 = 0;
	
	always @(posedge clk) begin
	
		start_en	<= 0;
		data_en		<= 0;
		finish_en	<= 0;
		din			<= 0;
		
		//Save output hash
		if(dout_valid)
			output_hash <= {output_hash[223:0], dout};
		if(dout_valid2)
			output_hash2 <= {output_hash2[223:0], dout2};
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 1: RFC 4231 test vector 1
			
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
			
			//Feed in the string
			2: begin
				data_en	<= 1;
				din		<= "Hi T";
				state	<= 3;
			end
			
			3: begin
				if(done) begin
					data_en	<= 1;
					din		<= "here";
					state	<= 4;
				end
			end
			
			4: begin
				if(done)
					state	<= 5;
			end
			
			//Hash the string
			5: begin
				$display("Hashing RFC 4231 test vector");
				finish_en	<= 1;
				state		<= 6;
			end
			
			//Wait for it to be done
			6: begin
				if(done) begin
					
					if(output_hash == 256'hb0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7) begin
						$display("Got correct hash");
					end
					
					else begin
						$display("FAIL: Wrong hash");
						$finish;
					end
					
					state	<= 7;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hash test 2: MIPS executable
			
			//Initialize hasher
			7: begin
				$display("Preparing to start hash (MIPS EXE)");
				start_en	<= 1;
				count		<= 0;
				state		<= 8;
			end
			
			//Wait for reset
			8: begin
				if(done2)
					state <= 9;
			end

			//Feed in the string
			9: begin
				data_en	<= 1;
				count	<= count + 1;
				state	<= 10;
				
				case(count)
					 0: din <= 32'h40000000;
					 1: din <= 32'h08000000;
					 2: din <= 32'h00000000;
					 3: din <= 32'h27bdfff8;
					 4: din <= 32'hafbe0004;
					 5: din <= 32'h03a0f021;
					 6: din <= 32'h08000005;
					 7: din <= 32'h00000000;
					 8: din <= 32'h00000000;
					 9: din <= 32'h00000100;
					10: din <= 32'h01010001;
					11: din <= 32'h00000000;
					12: din <= 32'h00000000;
					13: din <= 32'h00000000;
					14: din <= 32'h00000000;
				endcase
			end
			
			//Wait for it to be saved
			10: begin
				if(done2) begin
					state		<= 9;
					if(count == 15)
						state	<= 11;
				end
			end
			
			//Hash the string
			11: begin
				$display("Finishing");
				finish_en	<= 1;
				state		<= 12;
			end
			
			//Wait for it to be done
			12: begin
				if(done2) begin
					
					if(output_hash2 == 256'h7920a9cd65dc4ed4dcfba8091536e0359eb805b15503b3e0db219f9345c97a4e) begin
						$display("PASS: Got correct hash");
						$finish;
					end
					else begin
						$display("FAIL: Wrong hash (%x)", output_hash2);
						$finish;
					end

				end
			end
		
		endcase
	
	end
	
	initial begin
		#2000000;
		$display("FAIL: Test timed out");
		$finish;
	end

endmodule
