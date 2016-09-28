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
	@brief Pulse-stretching activity LED.
	
	LED output is normally in IDLE_STATE. Whenever an edge is seen on data_in it will change to the opposite state for
	a short time, then back. Edges seen during this period are ignored.
 */
module PulseStretcher(clk, data_in, led_out);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	parameter IDLE_STATE = 1;
	
	input wire clk;
	input wire data_in;
	output reg led_out = IDLE_STATE;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	reg[22:0] count = 0;
	reg data_in_old = 0;

	reg[1:0] state = 0;
	always @(posedge clk) begin
	
		data_in_old <= data_in;
	
		case(state)
		
			//Idle - sit around and wait for edges
			0: begin
				led_out <= IDLE_STATE;
				if(data_in != data_in_old) begin
					count <= 1;
					state <= 1;
					led_out <= !IDLE_STATE;
				end
			end
			
			//LED is in blink state, count until we overflow and turn it back to the idle state
			1: begin
				if(count == 0) begin
					led_out <= IDLE_STATE;
					state <= 2;
				end
				
				count <= count + 23'h1;
			end
			
			//LED is back in idle state, but don't blink again until we've been here for a while
			2: begin
				if(count == 0)
					state <= 0;
					
				count <= count + 23'h1;
			end
		
		endcase	
	end

endmodule

