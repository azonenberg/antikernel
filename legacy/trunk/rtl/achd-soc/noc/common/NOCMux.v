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
	@brief N-bit M-to-1 mux for use by NoC routers
 */
module NOCMux(sel, din, dout);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
		
	parameter WIDTH = 32;
	
	//Number of downstream ports (upstream not included in total)
	parameter PORT_COUNT				= 4;
	
	//Number of total ports including upstream
	localparam TOTAL_PORT_COUNT			= PORT_COUNT + 1;
		
	input wire[2:0]								sel;
	input wire[WIDTH*TOTAL_PORT_COUNT - 1 : 0]	din;
	output reg[WIDTH-1:0]						dout = 0;

	////////////////////////////////////////////////////////////////////////////////////////////////
	// The mux

	integer i;
	
	always @(*) begin
	
		//Default to zero if invalid
		dout <= 0;

		//Check each port
		//This complex structure is necessary to synthesize a non-power-of-two mux without xst complaining
		for(i=0; i<TOTAL_PORT_COUNT; i=i+1) begin
			if(i == sel)
				dout <= din[i*WIDTH +: WIDTH];
		end

	end

	
endmodule

