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
	@brief A parameterizable width / depth (addressable up to 32 bits for now) shift register.
 */

module ShiftRegisterMacro(clk, addr, din, ce, dout);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 16;
	parameter DEPTH = 32;
	
	`include "clog2.vh"
	
	//number of bits in the address bus
	localparam ADDR_BITS = clog2(DEPTH);
	
	generate
		initial begin	
			if(DEPTH != 32) begin
				$display("ERROR - ShiftRegisterMacro only supports depth value 32 for now");
				$finish;
			end
		end
	endgenerate
	
	input wire clk;
	input wire[ADDR_BITS-1:0] addr;
	input wire[WIDTH-1:0] din;
	input wire ce;
	output wire[WIDTH-1:0] dout;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The RAM itself

	genvar i;
	generate
		for(i=0; i<WIDTH; i = i+1) begin: shregblock
			ShiftRegisterPrimitiveWrapper #(.DEPTH(DEPTH), .ADDR_BITS(ADDR_BITS)) shregbit (
				.clk(clk), 
				.addr(addr),
				.din(din[i]),
				.ce(ce),
				.dout(dout[i])
				);			
		end
	endgenerate

endmodule

/**
	@brief Dumb wrapper around a single SRL* to use vector addresses.
	
	Parameterizable depth.
 */
module ShiftRegisterPrimitiveWrapper(clk, addr, din, ce, dout);
	
	parameter DEPTH = 32;
	parameter ADDR_BITS = 5;

	input wire clk;
	input wire[ADDR_BITS-1:0] addr;
	input wire din;
	input wire ce;
	output wire dout;
	
	generate
		if(DEPTH == 32) begin
			SRLC32E #(
				.INIT(32'h00000000)
			) shreg (
				.Q(dout),
				.Q31(),		//cascade output not used yet
				.A(addr),
				.CE(ce),
				.CLK(clk),
				.D(din)
			);
		end
		else begin
			initial begin
				$display("Invalid depth");
				$finish;
			end
		end
	endgenerate
	
endmodule
