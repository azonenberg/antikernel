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
	@brief Helper functions for Spartan-6 IODELAY
 */

//Table of max delay values excerpted from DS162 table 39
//note that this only supports -3 and -2 speed, not 3N and 1L
function integer s6_iodelay_val_singletap;
	input [3:0] ntap;
	
	//Speed grade 3
	if(SPEED_GRADE == 3) begin
		case(ntap)
			0:	s6_iodelay_val_singletap = 0;	//no extra delay
			1:	s6_iodelay_val_singletap = 8;
			2:	s6_iodelay_val_singletap = 40;
			3:	s6_iodelay_val_singletap = 95;
			4:	s6_iodelay_val_singletap = 108;
			5:	s6_iodelay_val_singletap = 171;
			6:	s6_iodelay_val_singletap = 207;
			7:	s6_iodelay_val_singletap = 212;
			8:	s6_iodelay_val_singletap = 322;
		endcase
	end
	
	//Speed grade 2
	else if(SPEED_GRADE == 2) begin
		case(ntap)
			0:	s6_iodelay_val_singletap = 0;	//no extra delay
			1:	s6_iodelay_val_singletap = 16;
			2:	s6_iodelay_val_singletap = 77;
			3:	s6_iodelay_val_singletap = 140;
			4:	s6_iodelay_val_singletap = 166;
			5:	s6_iodelay_val_singletap = 231;
			6:	s6_iodelay_val_singletap = 292;
			7:	s6_iodelay_val_singletap = 343;
			8:	s6_iodelay_val_singletap = 424;
		endcase
	end
	
	else begin
		$display("Unrecognized speed grade");
		$finish;
	end
	
endfunction

//Compute the delay for a Spartan-6 input delay line at a given tap count
//see DS162 table 39 note 2
function integer s6_iodelay_val;
	input [31:0] ntap;		
	s6_iodelay_val = (ntap[31:3] * s6_iodelay_val_singletap(8)) + s6_iodelay_val_singletap(ntap[2:0]);
endfunction
	
//Compute the number of taps to use for a given target delay
function integer s6_target_delay;
	input [31:0] target;
	integer i;
	integer remaining_delay;
	integer current_taps;
	begin
	
		//Get rough tap count (8 taps at a time)
		s6_target_delay = 0;
		current_taps = 0;
		remaining_delay = 0;
		if(target > s6_iodelay_val_singletap(8)) begin
			current_taps = 8 * (target / s6_iodelay_val_singletap(8));
			remaining_delay = target - (s6_iodelay_val_singletap(8) * current_taps/8);
		end
			
		//We now have close to the desired number of taps
		//Figure out how many additional taps we can fit
		if(s6_iodelay_val_singletap(7) > remaining_delay)
			s6_target_delay = current_taps + 7;
		else if(s6_iodelay_val_singletap(6) > remaining_delay)
			s6_target_delay = current_taps + 6;
		else if(s6_iodelay_val_singletap(5) > remaining_delay)
			s6_target_delay = current_taps + 5;
		else if(s6_iodelay_val_singletap(4) > remaining_delay)
			s6_target_delay = current_taps + 4;
		else if(s6_iodelay_val_singletap(3) > remaining_delay)
			s6_target_delay = current_taps + 3;
		else if(s6_iodelay_val_singletap(2) > remaining_delay)
			s6_target_delay = current_taps + 2;
		else if(s6_iodelay_val_singletap(1) > remaining_delay)
			s6_target_delay = current_taps + 1;
		else
			s6_target_delay = current_taps;

	end
endfunction
