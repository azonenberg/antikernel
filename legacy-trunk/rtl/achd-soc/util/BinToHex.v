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
	@brief Binary-to-ASCII-hex conversion table
 */
 
module BinToHex(
	nibble_in,
	ascii_out
    );
	 
	input wire[3:0] nibble_in;
	output reg[7:0] ascii_out = 0;
	
	always @(nibble_in) begin
		case(nibble_in)
			0: ascii_out <= "0";
			1: ascii_out <= "1";
			2: ascii_out <= "2";
			3: ascii_out <= "3";
			4: ascii_out <= "4";
			5: ascii_out <= "5";
			6: ascii_out <= "6";
			7: ascii_out <= "7";
			8: ascii_out <= "8";
			9: ascii_out <= "9";
			10: ascii_out <= "A";
			11: ascii_out <= "B";
			12: ascii_out <= "C";
			13: ascii_out <= "D";
			14: ascii_out <= "E";
			15: ascii_out <= "F";
		endcase
	end

endmodule

module BinToHexArray(
	binary_in,
	ascii_out);
	
	parameter NIBBLE_WIDTH = 8;	//32 bits
	
	input wire[NIBBLE_WIDTH*4 - 1:0] binary_in;
	output wire[NIBBLE_WIDTH*8 - 1:0] ascii_out;
	
	genvar i;
	generate
		for(i=0; i<NIBBLE_WIDTH; i = i+1) begin: convblock
			BinToHex converter(
				.nibble_in(binary_in[i*4 + 3 : i*4]),
				.ascii_out(ascii_out[i*8 + 7 : i*8]));
		end
	endgenerate
	
endmodule
