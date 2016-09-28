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
	@brief Helper functions for ReconfigurablePLL
 */
 
//Return the actual period at the phase-frequency detector given the input period and input divider
function integer pll_pfd_period;

	input integer	inperiod;
	input integer	div;
	
	pll_pfd_period	= inperiod * div;

endfunction

//Return the actual period at the VCO given the input period and multiplier/divider
function integer pll_vco_period;

	input integer	inperiod;
	input integer	mult;
	input integer	div;
	
	pll_vco_period = pll_pfd_period(inperiod, div) / mult;

endfunction

//Test whether a PLL configuration is legal
function integer pll_vco_sanitycheck;

	input integer	inperiod;
	input integer	speed;
	input integer	mult;
	input integer	div;
	
	//Verify PFD configuration is sane
	if( (pll_pfd_period(inperiod, div) > pll_pfd_max_period(speed)) ||
		(pll_pfd_period(inperiod, div) < pll_pfd_min_period(speed)) ) begin
		pll_vco_sanitycheck = 0;
	end
	
	//Verify VCO settings are sane
	else if( (pll_vco_period(inperiod, mult, div) > pll_vco_max_period(speed)) ||
			 (pll_vco_period(inperiod, mult, div) < pll_vco_min_period(speed)) ) begin
		pll_vco_sanitycheck = 0;
	end

	//nope, we're good to go
	else begin
		pll_vco_sanitycheck = 1;
	end

endfunction

//Determines the expected (rounded) divisor for a PLL output
function integer pll_output_expected_divisor;
	input integer	vco_period;
	input integer	target_period;
	
	pll_output_expected_divisor = target_period / vco_period;
	
endfunction

//Determines if the given output frequency can be produced by a PLL with the specified VCO configuration.
function integer pll_vco_outdivcheck;

	input integer	inperiod;
	input integer	mult;
	input integer	div;
	
	input integer	target_period;
	
	//If the computed divisor is too big, give up
	if(pll_output_expected_divisor(pll_vco_period(inperiod, mult, div), target_period) > pll_outdiv_max(1))
	begin
		pll_vco_outdivcheck = 0;
	end
	
	//If it doesn't divide evenly, give up
	else if((pll_output_expected_divisor(pll_vco_period(inperiod, mult, div), target_period) *
			pll_vco_period(inperiod, mult, div)) != target_period) begin
		pll_vco_outdivcheck = 0;
	end
		
	//all good
	else begin
		pll_vco_outdivcheck = pll_output_expected_divisor(pll_vco_period(inperiod, mult, div), target_period);
	end
	
endfunction

//Determines if the given PLL configuration is usable
function integer pll_config_usable;

	input integer	inperiod;
	input integer	mult;
	input integer	div;
	input integer	t0_period;
	input integer	t1_period;
	input integer	t2_period;
	input integer	t3_period;
	input integer	t4_period;
	input integer	t5_period;
	
	pll_config_usable =
		pll_vco_outdivcheck(inperiod, mult, div, t0_period) && pll_vco_outdivcheck(inperiod, mult, div, t1_period) &&
		pll_vco_outdivcheck(inperiod, mult, div, t2_period) && pll_vco_outdivcheck(inperiod, mult, div, t3_period) &&
		pll_vco_outdivcheck(inperiod, mult, div, t4_period) && pll_vco_outdivcheck(inperiod, mult, div, t5_period);

endfunction

//Finds a legal PLL configuration given target parameters
function [15:0] find_pll_config;

	input integer	inperiod;
	input integer	speed;
	input integer	t0_period;
	input integer	t1_period;
	input integer	t2_period;
	input integer	t3_period;
	input integer	t4_period;
	input integer	t5_period;

	integer mult;
	integer tmp;
	integer hit;
	
	begin
		hit = 0;
	
		for(mult=pll_mult_max(speed); mult > 0; mult = mult - 1) begin
		
			//See if any divisors will work
			tmp = find_pll_divisor(
				inperiod,
				mult,
				speed,
				t0_period,
				t1_period,
				t2_period,
				t3_period,
				t4_period,
				t5_period);
				
			if(tmp > 0) begin
				find_pll_config = {mult[7:0], tmp[7:0]};
				hit = 1;
			end

		end
		
		//If nothing hit by the very end, give up
		if(!hit)
			find_pll_config	= 0;
		
	end

endfunction

//Helper for find_pll_config: test each legal divisor for a given multiplier and see if any are good
function[7:0] find_pll_divisor;

	input integer	inperiod;
	input integer	mult;
	input integer	speed;
	input integer	t0_period;
	input integer	t1_period;
	input integer	t2_period;
	input integer	t3_period;
	input integer	t4_period;
	input integer	t5_period;

	integer div;
	integer hit;
	
	begin
		hit = 0;
		
		//Cap input divisor at 16 rather than the true max input divisor
		//This is a workaround for the terribad constant function evaluation in XST
		for(div=/*pll_indiv_max(speed)*/16; div > 0; div = div - 1) begin
			if(
				pll_vco_sanitycheck(inperiod, speed, mult, div) &&					
				pll_config_usable(inperiod, mult, div, t0_period, t1_period, t2_period, t3_period, t4_period, t5_period)
				) begin
			
				find_pll_divisor = div;
				hit = 1;

			end
		end
		
		//If nothing hit by the very end, give up
		if(!hit)
			find_pll_divisor = 0;
	
	end

endfunction
