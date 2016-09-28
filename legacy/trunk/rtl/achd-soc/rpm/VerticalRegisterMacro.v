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
	@brief RPM for a vertically placed register with LSB at bottom
	
	TODO: make direction parameterizable?
 */

module VerticalRegisterMacro(clk, d, ce, q);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 32;
	parameter INIT	= 32'h0;
	parameter CE  	= 1;
	parameter PACKING_DENSITY = 4;
	
	input wire				clk;
	input wire				ce;
	input wire[WIDTH-1:0]	d;
	output wire[WIDTH-1:0]	q;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual flipflops
	
	`include "stringfuncs.vh"
	
	genvar g;
	generate
	
		for(g=0; g<WIDTH; g=g+1) begin : ffarr
		
			//TODO: BEL constraints
			
			if(PACKING_DENSITY == 4) begin
				(* RLOC = {"X", `VAR_TO_STRING(0), "Y", `VAR_TO_STRING(g[31:2])} *)			
				RegisterMacro #(
					.INIT(INIT[g]),
					.CE(CE)
				) ff_bit (
					.clk(clk),
					.d(d[g]),
					.ce(ce),
					.q(q[g])
					);
			end
			
			else if(PACKING_DENSITY == 8) begin
				(* RLOC = {"X", `VAR_TO_STRING(0), "Y", `VAR_TO_STRING(g[31:3])} *)			
				RegisterMacro #(
					.INIT(INIT[g]),
					.CE(CE)
				) ff_bit (
					.clk(clk),
					.d(d[g]),
					.ce(ce),
					.q(q[g])
					);
			end
			
			else begin
				initial begin
					$display("VerticalRegisterMacro must have PACKING_DENSITY of 4 or 8");
					$finish;
				end
			end
			
		end
		
	endgenerate

endmodule

