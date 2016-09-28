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
	@brief A block of several SwitchDebouncers
 */
module SwitchDebouncerBlock(clk, buttons, buttons_debounced);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	parameter WIDTH = 4;
	parameter INIT_VAL = 0;
	
	input wire clk;
	input wire[WIDTH-1:0] buttons;
	output wire[WIDTH-1:0] buttons_debounced;

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Generate a nice slow debouncing clock
	reg clk_slow_edge = 0;							//asserted for one clk cycle every 2^16 cycles (roughly 1 KHz at 80 MHz)
	reg[15:0] clkdiv = 0;
	always @(posedge clk) begin
		clkdiv <= clkdiv + 16'h1;
		clk_slow_edge <= 0;
		if(clkdiv == 0)
			clk_slow_edge <= 1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Create the debouncers
	
	genvar i;
	generate
		for(i=0; i<WIDTH; i = i+1) begin: debouncers
			SwitchDebouncer #(.INIT_VAL(INIT_VAL[i])) debouncer (.clk(clk), .clken(clk_slow_edge), .din(buttons[i]), .dout(buttons_debounced[i]));
		end
	endgenerate

endmodule
