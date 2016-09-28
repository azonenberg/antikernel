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
	@brief True random number generator with native interface
	
	Basic structure:
		5 ring oscillator columns
			Each column is ten rings, each 8 gate delays but with four different levels of routing delay
		Output of all 50 oscillators is sampled at 100 MHz and stored in FFs
		Sampled output goes through a pipelined XOR tree and a von Neumann corrector
		32 bits of von Neumann output are XORed to produce the final output
	
	@param clk		Input sampling clock
	@param reset	Reset input
	@param valid	Indicates the output bit is valid
	@param dout		Raw output bit
 */
module NativeTrueRNG(clk, reset, valid, dout);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations

	input wire clk;
	input wire reset;
	output reg valid = 0;
	output reg dout = 0;
	
	//The actual oscillators
	wire[4:0] clkout_raw;
	(* RLOC = "X0Y0" *) CryptRingOscillatorColumn block0(.clk(clk), .reset(reset), .clkout(clkout_raw[0]));
	(* RLOC = "X1Y0" *) CryptRingOscillatorColumn block1(.clk(clk), .reset(reset), .clkout(clkout_raw[1]));
	(* RLOC = "X2Y0" *) CryptRingOscillatorColumn block2(.clk(clk), .reset(reset), .clkout(clkout_raw[2]));
	(* RLOC = "X3Y0" *) CryptRingOscillatorColumn block3(.clk(clk), .reset(reset), .clkout(clkout_raw[3]));
	(* RLOC = "X4Y0" *) CryptRingOscillatorColumn block4(.clk(clk), .reset(reset), .clkout(clkout_raw[4]));
	
	//Final xor stage
	reg dout_raw = 0;
	always @(posedge clk) begin
		dout_raw <= clkout_raw[0] ^ clkout_raw[1] ^ clkout_raw[2] ^ clkout_raw[3] ^ clkout_raw[4];
		if(reset)
			dout_raw <= 0;
	end
	
	//von Neumann corrector
	reg state = 0;
	reg fbit = 0;
	reg s0_valid = 0;
	reg s0_dout = 0;
	always @(posedge clk) begin
		
		s0_valid <= 0;
		
		state <= ~state;
		
		//Reading first bit
		if(state == 0)
			fbit <= dout_raw;
		
		//Reset
		else if(reset) begin
			state <= 0;
			fbit <= 0;
			s0_dout <= 0;
		end
		
		//Reading second bit
		else begin
		
			//Drop pair if equal, otherwise use first
			if(fbit != dout_raw) begin
				s0_valid <= 1;
				s0_dout <= fbit;
			end
			
		end
		
	end
	
	//Final 32:1 mixing of output bits to distill entropy a bit more
	reg[32:0] dsreg = 0;
	reg[5:0] outcount = 0;
	reg[5:0] s1_dout = 0;
	reg s1_valid = 0;
	always @(posedge clk) begin
		
		valid <= 0;
		s1_valid <= 0;
		
		//Reset
		if(reset) begin
			dout <= 0;
			dsreg <= 0;
			s1_dout <= 0;
		end
		
		//Shifting in new random bits
		if(s0_valid) begin
			dsreg <= {dsreg[30:0], s0_dout};
			outcount <= outcount + 6'h1;
		end
		
		//Every 32 bits gets distilled to one output bit
		if(outcount == 32) begin
			dsreg <= 0;
			outcount <= 0;
			
			s1_valid <= 1;
			s1_dout[0] <= dsreg[0] ^ dsreg[1] ^ dsreg[2] ^ dsreg[3] ^ dsreg[4] ^ dsreg[5];
			s1_dout[1] <= dsreg[6] ^ dsreg[7] ^ dsreg[8] ^ dsreg[9] ^ dsreg[10] ^ dsreg[11];
			s1_dout[2] <= dsreg[12] ^ dsreg[13] ^ dsreg[14] ^ dsreg[15] ^ dsreg[16] ^ dsreg[17];
			s1_dout[3] <= dsreg[18] ^ dsreg[19] ^ dsreg[20] ^ dsreg[21] ^ dsreg[22] ^ dsreg[23];
			s1_dout[4] <= dsreg[24] ^ dsreg[25] ^ dsreg[26] ^ dsreg[27] ^ dsreg[28] ^ dsreg[29];
			s1_dout[5] <= dsreg[30] ^ dsreg[31];
		end
		
		if(s1_valid) begin
			valid <= 1;
			dout <= s1_dout[0] ^ s1_dout[1] ^ s1_dout[2] ^ s1_dout[3] ^ s1_dout[4] ^ s1_dout[5];
		end
		
	end
	
endmodule
