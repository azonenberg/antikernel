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
	@brief Converts a 32 bit binary number to ASCII text output.
	
	Verilog port of the K&R itoa(3) function.
	
	Unsigned only for now.
 */
module HardItoa(
	clk,
	din, start, busy, done, dout, doutlen
    );

	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk;
	
	input wire[31:0] din;			//32-bit number
	input wire start;					//Asserted for one cycle to start the conversion
	output reg busy = 0;				//Asserted when we're busy
	output reg done = 0;				//Asserted for one clock when we've finished
	output reg[79:0] dout = 0;		//ASCII output (padded on the right with nulls)
	output reg[3:0] doutlen = 0;	//Length of output, in characters
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The divider
	
	reg divstart = 0;
	reg[31:0] dend = 0;
	wire[31:0] quot;
	wire[31:0] rem;
	wire divbusy;
	wire divdone;
	
	NonPipelinedDivider divider (
		.clk(clk), 
		.start(divstart), 
		.dend(dend), 
		.dvsr(32'd10), 
		.quot(quot), 
		.rem(rem), 
		.busy(divbusy), 
		.done(divdone), 
		.sign(1'b0)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	always @(posedge clk) begin

		divstart <= 0;
		dend <= 0;
		done <= 0;
	
		//Start the division
		if(start && !busy) begin
			divstart <= 1;
			dend <= din;
			busy <= 1;
			dout <= 0;
			doutlen <= 0;
		end
				
		//Division done? Process the result
		if(divdone) begin
			
			//Remainder is the current digit
			//Shift buffer right and add another character
			dout <= {rem[7:0] + 8'h30, dout[79:8]};
			
			doutlen <= doutlen + 4'd1;
			
			//Are we done?
			if(quot == 0) begin
				busy <= 0;
				done <= 1;
			end
			
			//No, divide again
			else begin
				divstart <= 1;
				dend <= quot;
			end
			
		end
		
	end

endmodule
