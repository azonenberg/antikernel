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
	@brief A column of ten ring oscillators
 */
module CryptRingOscillatorColumn(clk, reset, clkout);
	
	input wire clk;
	input wire reset;
	
	output reg clkout = 0;
	
	//The oscillators
	//Stagger different ring lengths in hopes of having less coupling
	(* S = "yes" *) wire[9:0] clkout_raw;
	(* RLOC = "X0Y0" *) CryptRingOscillator ring0(.reset(reset), .clkout(clkout_raw[0]));
	(* RLOC = "X0Y1" *) CryptRingOscillator ring1(.reset(reset), .clkout(clkout_raw[1]));
	(* RLOC = "X0Y2" *) CryptRingOscillator ring2(.reset(reset), .clkout(clkout_raw[2]));
	(* RLOC = "X0Y3" *) CryptRingOscillator ring3(.reset(reset), .clkout(clkout_raw[3]));
	(* RLOC = "X0Y4" *) CryptRingOscillator ring4(.reset(reset), .clkout(clkout_raw[4]));
	(* RLOC = "X0Y5" *) CryptRingOscillator ring5(.reset(reset), .clkout(clkout_raw[5]));
	(* RLOC = "X0Y6" *) CryptRingOscillator ring6(.reset(reset), .clkout(clkout_raw[6]));
	(* RLOC = "X0Y7" *) CryptRingOscillator ring7(.reset(reset), .clkout(clkout_raw[7]));
	(* RLOC = "X0Y8" *) CryptRingOscillator ring8(.reset(reset), .clkout(clkout_raw[8]));
	(* RLOC = "X0Y9" *) CryptRingOscillator ring9(.reset(reset), .clkout(clkout_raw[9]));
	
	//Buffer output
	reg[9:0] clkout_raw_buf = 0;
	always @(posedge clk) begin
		clkout_raw_buf <= clkout_raw;
		if(reset)
			clkout_raw_buf <= 0;
	end
	
	//XORed output
	reg[1:0] clkout_xor = 0;
	always @(posedge clk) begin
		clkout_xor[0] <= clkout_raw_buf[0] ^ clkout_raw_buf[1] ^ clkout_raw_buf[2] ^ clkout_raw_buf[3] ^ clkout_raw_buf[4];
		clkout_xor[1] <= clkout_raw_buf[5] ^ clkout_raw_buf[6] ^ clkout_raw_buf[7] ^ clkout_raw_buf[8] ^ clkout_raw_buf[9];
		clkout <= clkout_xor[0] ^ clkout_xor[1];
		
		if(reset) begin
			clkout_xor <= 0;
			clkout <= 0;
		end
	end

endmodule
