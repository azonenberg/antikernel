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
	@brief Smaller version of NonPipelinedDivider optimized for the unsigned-only case.
	
	Run time: one bit per two clocks with early-outs, plus setup time
	
	Starting a new operation while an existing one in progress will abort the current division.

 */
module UnsignedNonPipelinedDivider(clk, start, dend, dvsr, quot, rem, busy, done);

	input wire clk;
	input wire start;
	input wire[31:0] dend;
	input wire[31:0] dvsr;
	output reg[31:0] quot = 0;
	output reg[31:0] rem = 0;
	output reg busy = 0;
	output reg done = 0;
	
	reg compare	= 0;
	reg compare_result_less = 0;
	reg compare_result_eq = 0;
	
	reg[4:0] digit = 0;				//current digit (left to right)
	
	//The shifter for shift-and-subtract
	//Only used during the first clock when we set up the divide
	`include "FindLeftHandDigit.vh"
	reg[4:0] shiftdigit = 0;
	reg[31:0] shout_buf = 0;
	always @(posedge clk) begin
		shiftdigit <= FindLeftHandDigit(dend) - FindLeftHandDigit(dvsr);
	end
	 
	//Setup timer
	reg setup = 0;
	
	//Main processing
	always @(posedge clk) begin
	
		setup <= 0;
		done <= 0;
		
		//Start a new division
		if(start) begin
			quot <= 0;				//initial quotient is empty
			
			busy <= 1;				//We're busy
			setup <= 1;				//Wait for the initialization to finish
			
			rem <= dend;			//remainder starts with full value, then gradually subtract

			//Figure out how to align left digits of both
			//If divisor is greater than divident, quotient is zero and remainder is divisor
			if(dvsr > dend) begin
				done <= 1;
				busy <= 0;
			end
			
			`ifdef TRACE_DIVIDER
				$display("[DIVIDER] Starting: dividing %d by %d", dend, dvsr);
			`endif
		end
		
		//Do the actual division operation
		else if(busy) begin
		
			compare <= !compare;
		
			//Compute the shifted divisor value
			if(setup) begin
				shout_buf	<= (dvsr << shiftdigit);
				digit		<= shiftdigit;
				compare		<= 1;
			end
			
			else if(compare) begin	
				compare_result_less <= (shout_buf < rem);
				compare_result_eq	<= (shout_buf == rem);
			end
			
			else begin
			
				//Shift the divisor right by one and go on to the next digit
				shout_buf <= {1'b0, shout_buf[31:1]};
				digit <= digit - 5'd1;
			
				//Take the shifted divisor and subtract if it fits
				if(compare_result_less) begin
					quot[digit] <= 1;
					rem <= rem - shout_buf;
				end
				
				//Done? Add this bit and stop
				else if(compare_result_eq) begin
					quot[digit] <= 1;
					rem <= 0;
					busy <= 0;
					
					done <= 1;
				end

				//Go to the next digit or stop
				if(digit == 0) begin
					busy <= 0;					
					done <= 1;
				end
				
			end
		end
	
	end

endmodule
