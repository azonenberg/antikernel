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
	@brief GF(2^n) mod
	
	Operation:
		Load din/poly, assert start
		Wait for done to go high, do not change poly
		Rem is valid the cycle done goes high
 */
module GF2NMod(
	clk,
	start, din, poly,
	done, rem
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	parameter data_bits = 16;
	parameter poly_bits = 15;
	
	input wire clk;
	input wire start;
	
	localparam shregbits = data_bits + poly_bits;
	
	input wire[shregbits-1 : 0] din;
	input wire[poly_bits-1 : 0] poly;
	
	output reg done = 0;
	output wire[14:0] rem;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Core LFSR logic
	
	reg[shregbits-1 : 0] shreg = 0;
	assign rem = shreg[shregbits-1 : data_bits];
	
	reg active = 0;
	reg[7:0] count = 0;
	integer i;
	
	//Zero-pad poly at left with one bit for loop convenience
	wire[poly_bits:0] padded_poly;
	assign padded_poly = {1'b0, poly};
		
	always @(posedge clk) begin
		
		done <= 0;
		
		if(start) begin
			shreg <= din;
			active <= 1;
		end
		
		else if(active) begin

			//The actual LFSR
			shreg[data_bits-1:0] <= {shreg[data_bits-2:0], 1'b0};			
			for(i = data_bits; i < shregbits; i = i+1)			
				shreg[i] <= shreg[i - 1] ^ (shreg[shregbits-1] & padded_poly[i-data_bits]);

			//Done yet?
			count <= count + 8'h1;
			if(count == poly_bits) begin
				active <= 0;
				done <= 1;
				count <= 0;
			end
		end
		
	end

endmodule
