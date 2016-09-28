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
	@brief Testbench code for GF2NMod
 */
module testbench();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clocking

	reg clk = 0;
	
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
	
	reg start = 0;
	reg[30:0] din = 0;
	reg[14:0] poly = 15'h8faf;
	wire done;
	wire[14:0] rem;
	
	GF2NMod #(
		.data_bits(16),
		.poly_bits(15)
	) dut (
		.clk(clk),
		.start(start),
		.din(din),
		.poly(poly),
		.done(done),
		.rem(rem)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	// Test state machine
	
	reg[15:0] state = 0;
	
	always @(posedge clk) begin
		start <= 0;
		
		case(state)
		
			0: begin
				din <= {16'h0041, 15'h0};
				start <= 1;
				state <= 1;
			end
			
			1: begin
				if(done) begin
					$display("Encoded value: 0x%x (should be 4a22)", rem);
					if(rem == 'h4a22)
						state <= 2;
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end
			
			2: begin
				din <= 'h0020ca22;
				start <= 1;
				state <= 3;
			end
			
			3: begin
				if(done) begin
					$display("Syndrome: 0x%x (should be 0)", rem);
					if(rem == 'h0) begin
						$display("PASS");
						$finish;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end
						
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	// Die if test hangs
	initial begin
		#1000000;
		$display("FAIL (timeout)");
		$finish;
	end
	
endmodule
