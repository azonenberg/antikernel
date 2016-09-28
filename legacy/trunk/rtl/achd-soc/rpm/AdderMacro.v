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
	@brief RPM for a vertical ripple-carry adder
 */

module AdderMacro(a, b, q);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 8;

	input wire[WIDTH-1:0] a;
	input wire[WIDTH-1:0] b;
	
	output wire[WIDTH-1:0] q;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity checks
	
	initial begin
		if(WIDTH[1:0]) begin
			$display("AdderMacro width must be multiple of 4 bits");
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual adder logic
	
	wire[(WIDTH >> 2)- 1 : 0] carry;
	
	`include "stringfuncs.vh"
	
	genvar g;
	generate
	
		for(g=0; g<WIDTH; g=g+4) begin : adder
		
			//No carry in for first state
			if(g == 0) begin
				
				(* RLOC = {"X", `VAR_TO_STRING(0), "Y", `VAR_TO_STRING(g[31:2])} *)
				AdderMacro4bit nibble (
					.cin(1'b0),
					.a(a[g +: 4]),
					.b(b[g +: 4]),
					.q(q[g +: 4]),
					.cout(carry[g >> 2])
				);
				
			end
			
			//We *do* need carry in here
			else begin
			
				(* RLOC = {"X", `VAR_TO_STRING(0), "Y", `VAR_TO_STRING(g[31:2])} *)
				AdderMacro4bit nibble (
					.cin(carry[(g >> 2) - 1]),
					.a(a[g +: 4]),
					.b(b[g +: 4]),
					.q(q[g +: 4]),
					.cout(carry[g >> 2])
				);
			end
			
		end
	
	endgenerate

endmodule

module AdderMacro4bit(cin, a, b, q, cout);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	input wire			cin;
	input wire[3:0]		a;
	input wire[3:0]		b;
	
	output wire[3:0]	q;
	output wire			cout;
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual adder logic
	
	//Carry state
	wire[3:0] lcout;
	wire[3:0] muxout;
	assign cout = muxout[3];
	
	//Carry generate/propagate LUTs
	//BEL constraints are inferred for now
	(* RLOC="X0Y0" *) AdderMacroCell lut0(.a(a[0]), .b(b[0]), .lcout(lcout[0]));
	(* RLOC="X0Y0" *) AdderMacroCell lut1(.a(a[1]), .b(b[1]), .lcout(lcout[1]));
	(* RLOC="X0Y0" *) AdderMacroCell lut2(.a(a[2]), .b(b[2]), .lcout(lcout[2]));
	(* RLOC="X0Y0" *) AdderMacroCell lut3(.a(a[3]), .b(b[3]), .lcout(lcout[3]));
	
	//Carry chain muxes
	(* RLOC="X0Y0" *) MUXCY mux0(.DI(a[0]), .CI(cin),       .S(lcout[0]), .O(muxout[0]));
	(* RLOC="X0Y0" *) MUXCY mux1(.DI(a[1]), .CI(muxout[0]), .S(lcout[1]), .O(muxout[1]));
	(* RLOC="X0Y0" *) MUXCY mux2(.DI(a[2]), .CI(muxout[1]), .S(lcout[2]), .O(muxout[2]));
	(* RLOC="X0Y0" *) MUXCY mux3(.DI(a[3]), .CI(muxout[2]), .S(lcout[3]), .O(muxout[3]));
	
	//Output XORs
	(* RLOC="X0Y0" *) XORCY xor0(.LI(lcout[0]), .CI(cin),       .O(q[0]));
	(* RLOC="X0Y0" *) XORCY xor1(.LI(lcout[1]), .CI(muxout[0]), .O(q[1]));
	(* RLOC="X0Y0" *) XORCY xor2(.LI(lcout[2]), .CI(muxout[1]), .O(q[2]));
	(* RLOC="X0Y0" *) XORCY xor3(.LI(lcout[3]), .CI(muxout[2]), .O(q[3]));

endmodule

(* LUT_MAP = "yes" *)
(* RLOC = "X0Y0" *)
module AdderMacroCell(a, b, lcout);
	
	input wire a;
	input wire b;
	
	output wire lcout;
	
	assign lcout = a ^ b;
	
endmodule
