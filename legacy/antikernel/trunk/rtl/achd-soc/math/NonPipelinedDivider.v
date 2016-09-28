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

//`define TRACE_DIVIDER

/**
	@file
	@author Andrew D. Zonenberg
	@brief A sequential divider using the shift-and-subtract algorithm.
	
	Run time: one bit per clock with early-outs, plus setup time
	
	Starting a new operation while an existing one in progress will abort the current division.
	
	Cycle 0: buffer inputs
	Cycle 1: shift stuff
	Cycle 2: start division
 */
module NonPipelinedDivider(clk, start, dend, dvsr, quot, rem, busy, done, sign);

	input wire clk;
	input wire start;
	input wire[31:0] dend;
	input wire[31:0] dvsr;
	output reg[31:0] quot = 0;
	output reg[31:0] rem = 0;
	output reg busy = 0;
	output reg done = 0;
	input wire sign;
	
	reg[4:0] digit = 0;				//current digit (left to right)
	
	//Inputs after signedness correction
	reg[31:0] dend_u = 0;
	reg[31:0] dvsr_u = 0;
	
	//Find the left-hand digits in the inputs
	`include "FindLeftHandDigit.vh"
	wire[4:0] lhd_dend = FindLeftHandDigit(dend);
	wire[4:0] lhd_dvsr = FindLeftHandDigit(dvsr);
		
	//The shifter for shift-and-subtract
	//Only used during the first clock when we set up the divide
	reg[5:0] shiftdigit = 0;
	reg[31:0] shout_buf = 0;
	always @(posedge clk) begin
		shiftdigit <= lhd_dend - lhd_dvsr;
	end
	 
	//Setup timer
	reg setup = 0;
	
	//Start bit delayed by one clock
	reg start_buf = 0;
	
	//If set, we should output the two's complement of our quotient and remainder
	reg flip_output = 0;
	
	//If set, we're ready to go once we complement the outputs
	reg flipanddone = 0;
	
	//Main processing
	always @(posedge clk) begin
	
		start_buf <= start;
		
		//Set done once outputs are complemented
		if(flipanddone) begin
			done <= 1;
			flipanddone <= 0;
			quot <= ~quot + 32'd1;
			rem <= ~rem + 32'd1;
		end
	
		//Start a new division
		if(start) begin
			quot <= 0;				//initial quotient is empty
			done <= 0;				//We're not done
			
			flip_output <= 0;
			
			//Sign processing
			if(sign) begin

				//If neither are negative, do nothing
				if(!dvsr[31] && !dend[31]) begin
					dend_u <= dend;
					dvsr_u <= dvsr;
				end
				
				//if both are neg, flip them both and don't do anything else
				else if(dvsr[31] && dend[31]) begin
					dend_u <= ~dend + 32'd1;
					dvsr_u <= ~dvsr + 32'd1;
				end

				//if one is neg, flip it and make a note that the output needs flipping
				else begin
				
					if(dvsr[31]) begin
						dend_u <= dend;
						dvsr_u <= ~dvsr + 32'd1;
					end
					else begin
						dend_u <= ~dend + 32'd1;
						dvsr_u <= dvsr;
					end
				
					flip_output <= 1;
				end
			end
			
			//Just save inputs
			else begin
				dend_u <= dend;
				dvsr_u <= dvsr;
			end
			
		end
		
		//TODO: We may be able to save a clock off of unsigned divisions
		//by forwarding dend and dvsr to dend_u and dvsr_u in the shifter etc
		if(start_buf) begin
			busy <= 1;				//We're busy
			setup <= 1;				//Wait for the initialization to finish
			
			rem <= dend_u;			//remainder starts with full value, then gradually subtract

			//Figure out how to align left digits of both
			//If divisor is greater than divident, quotient is zero and remainder is divisor
			if(dvsr_u > dend_u) begin
				done <= 1;
				busy <= 0;
			end
			
			//Otherwise, just subtract
			else 			
				digit <= lhd_dend - lhd_dvsr;
			
			`ifdef TRACE_DIVIDER
				$display("[DIVIDER] Starting: dividing %d by %d", dend_u, dvsr_u);
			`endif
		end
		
		//Done? Drop the flag next cycle and reset state
		else if(done) begin
		
			`ifdef TRACE_DIVIDER
			$display("[DIVIDER] Done: quotient=%d remainder=%d", quot, rem);
			`endif
			
			shout_buf <= 0;
			quot <= 0;
			rem <= 0;
			busy <= 0;
			digit <= 0;
			done <= 0;
		end
		
		//Do the actual division operation
		else if(busy) begin
		
			if(setup) begin
				setup <= 0;
				
				//Compute the shifted divisor value
				shout_buf <= (dvsr_u << shiftdigit);
			end
			
			else begin
		
				//Shift the divisor right by one
				shout_buf <= {1'b0, shout_buf[31:1]};
			
				//Take the shifted divisor and subtract if it fits
				if(shout_buf < rem) begin
					quot[digit] <= 1;
					rem <= rem - shout_buf;
				end
				
				//Done? Add this bit and stop
				else if(shout_buf == rem) begin
					quot[digit] <= 1;
					rem <= 0;
					busy <= 0;
					
					if(flip_output)
						flipanddone <= 1;
					else
						done <= 1;
				end
				
				//Doesn't fit, set this bit to a zero
				else begin
					quot[digit] <= 0;
				end
				
				//Go to the next digit or stop
				if(digit == 0) begin
					busy <= 0;
					
					if(flip_output)
						flipanddone <= 1;
					else
						done <= 1;
				end
				else begin
					digit <= digit - 5'd1;
				end
			end
		end
	
	end

endmodule
