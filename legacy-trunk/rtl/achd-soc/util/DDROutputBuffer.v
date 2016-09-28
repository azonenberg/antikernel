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
	@brief Ganged collection of DDR I/O buffers for a parallel DDR output bus
	
	Supports Spartan-6 and 7 series.
 */
module DDROutputBuffer(clk_p, clk_n, dout, din0, din1);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 16;
	
	//Clocks
	input wire clk_p;
	input wire clk_n;
	
	//Output data
	output wire[WIDTH-1:0] dout;
	
	//Input data (clk_p domain)
	input wire[WIDTH-1:0] din0;
	input wire[WIDTH-1:0] din1;

	////////////////////////////////////////////////////////////////////////////////////////////////
	// The IO buffers
	
	genvar i;
	generate
		for(i=0; i<WIDTH; i = i+1) begin: buffers
		
			`ifdef XILINX_SPARTAN6
				ODDR2 #
				(
					.DDR_ALIGNMENT("C0"),
					.SRTYPE("ASYNC"),
					.INIT(0)
				) ddr_obuf
				(
					.C0(clk_p),
					.C1(clk_n),
					.D0(din0[i]),
					.D1(din1[i]),
					.CE(1'b1),
					.R(1'b0),
					.S(1'b0),
					.Q(dout[i])
				);
			`endif
			
			`ifdef XILINX_7SERIES
				ODDR #
				(
					.DDR_CLK_EDGE("SAME_EDGE"),
					.SRTYPE("ASYNC"),
					.INIT(0)
				) ddr_obuf
				(
					.C(clk_p),
					.D1(din0[i]),
					.D2(din1[i]),
					.CE(1'b1),
					.R(1'b0),
					.S(1'b0),
					.Q(dout[i])
				);
			`endif
				
		end
	endgenerate

endmodule
