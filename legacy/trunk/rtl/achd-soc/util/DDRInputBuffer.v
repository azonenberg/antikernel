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
	@brief Ganged collection of DDR I/O buffers for a parallel DDR input bus
	
	Supports Spartan-6 and 7 series.
 */
module DDRInputBuffer(clk_p, clk_n, din, dout0, dout1);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 16;
	
	//Clocks
	input wire clk_p;
	input wire clk_n;
	
	//Input data (pin domain)
	input wire[WIDTH-1:0] din;
	
	//Output data (clk_p domain)
	output wire[WIDTH-1:0] dout0;
	output wire[WIDTH-1:0] dout1;

	////////////////////////////////////////////////////////////////////////////////////////////////
	// The IO buffers
	
	genvar i;
	generate
		for(i=0; i<WIDTH; i = i+1) begin: buffers
		
			`ifdef XILINX_SPARTAN6
				IDDR2 #
				(
					.DDR_ALIGNMENT("C0"),
					.SRTYPE("ASYNC"),
					.INIT_Q0(0),
					.INIT_Q1(0)
				) ddr_ibuf
				(
					.C0(clk_p),
					.C1(clk_n),
					.D(din[i]),
					.CE(1'b1),
					.R(1'b0),
					.S(1'b0),
					.Q0(dout0[i]),
					.Q1(dout1[i])
				);
			`endif
			
			//for reasons unknown, we have to flip the ddr nibble order on 7 series vs 6
			`ifdef XILINX_7SERIES
				IDDR #
				(
					.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
					.SRTYPE("ASYNC"),
					.INIT_Q1(0),
					.INIT_Q2(0)
				) ddr_ibuf
				(
					.C(clk_p),
					.D(din[i]),
					.CE(1'b1),
					.R(1'b0),
					.S(1'b0),
					.Q1(dout1[i]),
					.Q2(dout0[i])
				);
			`endif
			
		end
	endgenerate

endmodule
