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
	@brief Test vectors for the Internet checksum.	 computed in 32-bit mode
 */
module testInternetChecksum32bit;

	// Inputs
	reg clk = 0;
	reg load = 0;
	reg process = 0;
	reg [31:0] din = 0;

	// Outputs
	wire [15:0] sumout;
	wire [15:0] csumout;

	// Instantiate the Unit Under Test (UUT)
	InternetChecksum32bit uut (
		.clk(clk), 
		.load(load), 
		.process(process), 
		.din(din), 
		.sumout(sumout),
		.csumout(csumout)
	);

	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	
	always begin
		#5;
		clk = ready;
		#5;
		clk = 1;
	end
	
	reg[15:0] state = 0;
	always @(posedge clk) begin
		load <= 0;
		process <= 0;
		din <= 0;
		
		case(state)
			//Test vector from RFC1071
			0: begin
				$display("Running RFC1071 test vector...");
				load <= 1;
				din <= 32'h0001f203;
				state <= 1;
			end
			
			1: begin
				process <= 1;
				din <= 32'hf4f5f6f7;
				state <= 2;
			end
			
			//Final calculation
			2: begin
				state <= 3;
			end
			
			//Verify checksum
			3: begin
				if(sumout == 16'hddf2) begin
					$display("PASS");
				end
				else
					$display("FAIL (%08x)", sumout);
				state <= 4;
			end
			
			4: begin
				$finish;
			end
			
		endcase
		
	end
      
endmodule

