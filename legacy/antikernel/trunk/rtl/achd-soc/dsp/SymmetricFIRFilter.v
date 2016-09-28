`timescale 1ns / 1ps
`default_nettype none
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
	@brief A parameterizable, symmetric FIR filter using a Kaiser-Bessel window
	
	Works with fixed-point twos complement data with the radix point implied at far left.
	Legal inputs are logically in the range -1 to +1.
	
	Latency is TBD cycles from Y to Z.
	
	Internal filter coefficients use 24 bit fixed point math in calculation and are truncated as necessary.
 */
module SymmetricFIRFilter(
	clk,
	in_data, in_valid, in_busy,
	out_data, out_valid
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter ORDER					= 31;	//Number of points in the filter (must be 2^n - 1)
	
	parameter CYCLES_PER_SAMPLE		= 4;	//Must be an integer divisor of ORDER_POT
											//We need ORDER_POT / CYCLES_PER_SAMPLE multipliers in DSP mode
											
	parameter DATA_WIDTH			= 16;	//Width of the fractional part of the data
	
	parameter ADDER_TREE_WIDTH		= 4;	//Maxmimum fan-in of a single adder
											//4 seems to be a nice choice since we can hit 300+ MHz on -2 s6
											
	parameter MULT_TYPE				= "DSP";			//Type of multipliers to use
														//SHIFT_ADD_APPROX = use highest few "1" bits
														//DSP = use inferred DSP blocks at full precision
															
	parameter COEFF_ONE_BITS		= 2;				//Max number of "1" bits in a coefficient
														//for MULT_TYPE == SHIFT_ADD_APPROX
									
	parameter FILTER_TYPE			= "BAND_PASS";		//Type of filter
														//Must be LOW_PASS, HIGH_PASS, BAND_PASS, or NOTCH
														//NOTCH not yet implemented
	
	parameter ATTEN_DB				= 50;				//Attenuation of the stop band, in dB
	
	parameter SAMPLE_FREQ			= 8;				//Frequency of the sampling clock
														//Units may be either Hz, kHz, or MHz
														//but must be same units as cutoff freqs
															
	parameter CUTOFF_A				= 1;
	parameter CUTOFF_B				= 2;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Calculate derived parameters
	
	`include "../util/clog2.vh"
	
	localparam NYQUIST_FREQ		= SAMPLE_FREQ / 2;			//Nyquist limit
	
	localparam DATA_WIDTH_BITS	= clog2(DATA_WIDTH);		//Number of bits needed to select one bit out of the data
	
	localparam CYCLE_BITS		= clog2(CYCLES_PER_SAMPLE);	//Number of bits needed to identify one phase
	
	localparam ORDER_POT		= ORDER+1;					//The order of the filter, rounded up to power of two
	localparam RADIUS			= ORDER >> 1;				//Radius of the filter from center to edge
		
	localparam ORDER_BITS		= clog2(ORDER_POT);			//Number of bits needed to identify a single FIR point
	
	//Fixed point scaling factors for internal math
	localparam FIXED_SCALE		= 16777215;					//0xffffff = 24 bit resolution
	localparam FIXED_ISCALE		= (1.0 / FIXED_SCALE);
	
	localparam DATA_SCALE		= (1 << DATA_WIDTH) - 1;	//max value of a data point
	
	localparam M_PI				= 3.1415926535;
	
	localparam POINTS_PER_CYCLE	= ORDER_POT / CYCLES_PER_SAMPLE;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire						clk;
	
	//Input FIFO
	input wire						in_valid;
	input wire[DATA_WIDTH-1 : 0]	in_data;
	output reg						in_busy		= 0;
	
	//Output FIFO
	output wire						out_valid;
	output wire[DATA_WIDTH-1 : 0]	out_data;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity checks
	
	initial begin
		
		//MULT_TYPE must be good
		if( (MULT_TYPE == "SHIFT_ADD_APPROX") || (MULT_TYPE == "DSP") ) begin
		end
		else begin
			$display("ERROR: invalid MULT_TYPE");
			$finish;
		end
		
		//Sanity check sample rate
		if(SAMPLE_FREQ == 0) begin
			$display("ERROR: Sample rate must not be zero, otherwise filtering makes no sense");
			$finish;
		end
		
		//Sanity check cutoffs
		if(CUTOFF_A >= CUTOFF_B) begin
			$display("ERROR: Cutoff frequency A must be less than cutoff B");
			$finish;
		end
		if(CUTOFF_B > NYQUIST_FREQ) begin
			$display("ERROR: Cutoff frequency B must not be greater than Nyquist limit");
			$finish;
		end
		else if(CUTOFF_A < 0) begin
			$display("ERROR: Cutoff frequency A must not be less than zero");
			$finish;
		end
		
		//FILTER_TYPE must be good and cutoffs must be well formed for that type of filter
		if(FILTER_TYPE == "LOW_PASS") begin
			if(CUTOFF_A != 0) begin
				$display("ERROR: Cutoff A for LOW_PASS must be zero");
				$finish;
			end
		end
		else if(FILTER_TYPE == "HIGH_PASS") begin
			if(CUTOFF_B != NYQUIST_FREQ ) begin
				$display("ERROR: Cutoff B for BAND_PASS must be equal to Nyquist limit");
				$finish;
			end
		end
		else if(FILTER_TYPE == "BAND_PASS") begin
			//Any legal coefficient is OK
		end
		else begin
			$display("ERROR: invalid FILTER_TYPE");
			$finish;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Kaiser-Bessel filter coefficient generation

	//Based on public domain code and math from these resources
	//http://www.arc.id.au/FilterDesign.html
	//http://www.arc.id.au/dspUtils-11.js

	//Calculation of window shape parameter \alpha
	//Attenuation is integer dB, return value is fixed point
	function [63:0] CalculateAlpha;
		input integer atten;
		
		begin
		
			if(atten > 50)
				CalculateAlpha = FIXED_SCALE * (0.1102 * (atten - 8.7));
				
			else if(atten >= 21)
				CalculateAlpha = FIXED_SCALE * (0.5842 * ($pow(atten - 21, 0.4)) + 0.07886*(atten - 21));
				
			else
				CalculateAlpha = 0;
				
		end
		
	endfunction
	
	//0th order Bessel function
	function [63:0] BesselHelper;
		input [63:0] x;
		
		time d;
		time ds;
		time s;
		
		begin
		
			d = 0;
			ds = 1*FIXED_SCALE;
			s = 1*FIXED_SCALE;
		
			while(ds*1000000 > s) begin
				
				d = d + 2 * FIXED_SCALE;
				
				ds = FIXED_SCALE *
						( (x*FIXED_ISCALE)*(x*FIXED_ISCALE)*(ds*FIXED_ISCALE) ) /
						( (d*FIXED_ISCALE)*(d*FIXED_ISCALE) );
						
				s = s + ds;
				
			end
		
			BesselHelper = s;
		end
		
	endfunction
	
	//Decimal fixed point intermediate values
	//Need to be reg vs localparam due to XST quirks
	reg[63:0] impulse[RADIUS:0];							//Impulse response of the filter
	reg[63:0] alpha;										//Window shape 
	reg[63:0] balpha;
	reg[63:0] tmp;
	reg[63:0] wcoeff[ORDER-1:0];							//Final windowed filter coefficients (before truncation)
	reg[31:0] wcoeff_trunc[ORDER_POT-1:0];					//Final coefficients with unused upper bits removed
	reg[31:0] wcoeff_trunc_comp[ORDER-1:0];					//Two's complement of wcoeff_trunc

	//We need at most COEFF_ONE_BITS bits per sample
	//If there's not at least that many "1" bits set, the mask for that position goes to zero
	//Fill from least to most significant so coeff_used_mask[0] is first to be set
	//Sign bit is 0 for unsigned, 1 for negative
	reg[COEFF_ONE_BITS-1:0] 					coeff_used_mask[ORDER-1:0];
	reg						 					coeff_sign[ORDER-1:0];
	localparam COEFF_INDEX_BITS = 5;
	reg[COEFF_INDEX_BITS*COEFF_ONE_BITS-1:0]	coeff_indices[ORDER-1:0];
		
	integer i;
	integer bits_used;
	integer bits_left;
	integer max_correction;
	integer corr_bits;
	integer k;
	integer j;
	integer delta;
	integer overshoot;
	initial begin
	
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Calculate the actual coefficients in full fixed point precision
	
		//Window shape parameter
		alpha = CalculateAlpha(ATTEN_DB);
	
		//Filter impulse response
		impulse[0] = 2 * FIXED_SCALE * (CUTOFF_B - CUTOFF_A)/SAMPLE_FREQ;
		for(i=1; i<=RADIUS; i=i+1) begin
			impulse[i] = FIXED_SCALE * (
							(
								$sin(2 * i * M_PI * CUTOFF_B/SAMPLE_FREQ) -
								$sin(2 * i * M_PI * CUTOFF_A/SAMPLE_FREQ)
							) / (i*M_PI) );
		end
		
		//Apply the Kaiser-Bessel window
		balpha = BesselHelper(alpha);
		for(i=0; i<=RADIUS; i=i+1) begin

			//Input to sqrt, in fixed point
			tmp = FIXED_SCALE - ((i*i*FIXED_SCALE) / (RADIUS*RADIUS));
		
			//Input to Bessel function, in fixed point
			tmp = alpha * $sqrt(tmp*FIXED_ISCALE);
			
			//Final windowed coefficient value, in fixed point
			wcoeff[RADIUS+i] =  (impulse[i]*FIXED_ISCALE) * BesselHelper(tmp) / (balpha*FIXED_ISCALE);
		end
		for(i=0; i<RADIUS; i=i+1)
			wcoeff[i] = wcoeff[ORDER-1-i];
		
		//Truncate to get the final coefficients
		for(i=0; i<ORDER; i=i+1)
			wcoeff_trunc[i] = wcoeff[i][31:0];
			
		//pad so we can use power-of-two addressing without synth warnings
		wcoeff_trunc[ORDER] = 0;
			
		//Calculate two's complements
		for(i=0; i<ORDER; i=i+1)
			wcoeff_trunc_comp[i] = ~wcoeff_trunc[i] + 32'h1;
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Round coefficients to most significant N bits for SHIFT_ADD_APPROX (not used in other modes)
		
		for(i=0; i<ORDER; i=i+1) begin
		
			//Default to 0 for this position
			coeff_used_mask[i] = 0;
			
			//Default to unsigned
			coeff_sign[i] 		= 0;
			
			//If value is negative, works on the two's complement of it instead
			tmp = wcoeff_trunc[i];
			if(wcoeff_trunc[i][31]) begin
				tmp = wcoeff_trunc_comp[i];
				coeff_sign[i] = 1;
			end
		
			//Go from MSB down to LSB and stop when we've found the necessary number of bits
			bits_used = 0;
			for(j=30; j>=0; j=j-1) begin
			
				//Figure out, given how many bits are left, what the max correction we can make
				//toward the target value if we do not set this bit
				bits_left = COEFF_ONE_BITS - bits_used;
				corr_bits = bits_left;
				max_correction = 0;
				for(k=j-1; k>=0; k=k-1) begin
					if(corr_bits > 0) begin
						max_correction = max_correction + (1 << k);
						corr_bits = corr_bits - 1;
					end
				end
				
				//Default to not overshooting
				overshoot = 0;
			
				//Still have room for more bits? Check for more
				if(bits_left) begin
				
					//We should overshoot if setting this bit will bring us closer than the max future correction would
					if( (max_correction < tmp) && (  ((1 << j) - tmp) < (tmp - max_correction)  ) )
						overshoot = 1;

					//If we're setting this bit, for any reason, some work is needed
					if(tmp[j] || overshoot) begin
						
						//Save the bit position
						coeff_used_mask[i][bits_used]										= 1;
						coeff_indices[i][COEFF_INDEX_BITS*bits_used +: COEFF_INDEX_BITS]	= j[COEFF_INDEX_BITS-1:0];
						
						//If we undershot, remove the delta from the running total
						if(!overshoot) begin
							bits_used = bits_used + 1;
							tmp = tmp - (1 << j);
						end
						
						//If we overshot, we're done regardless - adding more will make things worse
						else begin
							bits_used = COEFF_ONE_BITS;
							tmp = 0;
						end
						
					end
										
				end
				
			end
		
		end
		
		//Print out the final results for debugging
		
		for(i=0; i<ORDER; i=i+1) begin
			
			//Get the approximated value
			tmp = 0;
			for(j=0; j<COEFF_ONE_BITS; j=j+1) begin
				if(coeff_used_mask[i][j])
					tmp = tmp + (1 << coeff_indices[i][COEFF_INDEX_BITS*j +: COEFF_INDEX_BITS]);
			end
			
			//Sign flip if necessary
			if(coeff_sign[i])
				tmp = -tmp;
			
			//Calculate error
			delta = wcoeff_trunc[i] - tmp[31:0];
			$display("wcoeff_approx[%2d] = %9.6f, actual = %9.6f, delta = %9.6f / %5.2f %% [%8x, actual is %8x]",
				i,
				tmp[31:0]*FIXED_ISCALE,
				wcoeff_trunc[i] * FIXED_ISCALE,
				delta * FIXED_ISCALE,
				(wcoeff_trunc[i] == 0) ? 0 : (delta * 100 * FIXED_ISCALE / (wcoeff_trunc[i] * FIXED_ISCALE)),
				tmp[31:0],
				wcoeff_trunc[i]);
			
		end
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Delay line for saving inputs
	
	reg[DATA_WIDTH-1 : 0] delay_line[ORDER : 0];	//extra element at the end ignored
													//just there so we can do integer addresses w/o warnings
	
	//Whenever a new sample shows up, push it down the line
	always @(posedge clk) begin
		if(in_valid) begin
			for(i=1; i<ORDER; i=i+1)
				delay_line[i] <= delay_line[i-1];
			delay_line[0]	<= in_data;
			
			//should be optimized out, but needs to be driven to avoid warning
			delay_line[ORDER] <= 0;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Phase tracking
	
	reg[CYCLE_BITS-1:0] 	phase = 0;
	wire[CYCLE_BITS-1:0]	next_phase = phase + 1'd1;
	
	always @(posedge clk) begin
	
		if(in_valid) begin
			phase	<= 0;
			in_busy	<= 1;
		end
		
		if(in_busy) begin
			if(next_phase == 0)
				in_busy	<= 0;
			else
				phase	<= next_phase;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multiplier input muxing from the delay line
	
	//Multiplier inputs
	reg[DATA_WIDTH-1:0] mult_a[POINTS_PER_CYCLE-1 : 0];
	reg[DATA_WIDTH-1:0] mult_b[POINTS_PER_CYCLE-1 : 0];

	//Get the original coefficients for this sample
	wire[31:0] wcoeff_current[POINTS_PER_CYCLE-1:0];
	genvar g;
	generate
		for(g=0; g<POINTS_PER_CYCLE; g=g+1) begin : wassign
			assign wcoeff_current[g] = wcoeff_trunc[phase*POINTS_PER_CYCLE + g];
		end
	endgenerate
	
	//Status flags
	reg mult_input_valid_adv	= 0;
	reg	mult_input_valid		= 0;
	reg	mult_output_valid		= 0;
	reg	mult_output_valid_ff	= 0;
	reg	mult_output_valid_ff2	= 0;
	reg mult_output_valid_ff3	= 0;
	wire sum_start				= mult_output_valid_ff2 && !mult_output_valid_ff3;
	always @(posedge clk) begin
		mult_input_valid_adv	<= in_valid || in_busy;
		mult_input_valid		<= mult_input_valid_adv;
		mult_output_valid		<= mult_input_valid;
		mult_output_valid_ff	<= mult_output_valid;
		mult_output_valid_ff2	<= mult_output_valid_ff;
		mult_output_valid_ff3	<= mult_output_valid_ff2;
	end
	
	//TODO: Symmetry optimization
	always @(posedge clk) begin
		
		for(i=0; i<POINTS_PER_CYCLE; i=i+1) begin
			
			//Truncate coefficient as necessary
			mult_a[i]	<= wcoeff_current[i][31 : (32 - DATA_WIDTH)];

			mult_b[i]	<= delay_line[phase*POINTS_PER_CYCLE + i];
			
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multiplier block
	
	//Multiplier outputs (double width)
	(* MULT_STYLE = "pipe_block" *)
	reg[DATA_WIDTH*2-1:0] multiplier_outputs[POINTS_PER_CYCLE-1 : 0];
	reg[DATA_WIDTH*2-1:0] multiplier_outputs_ff[POINTS_PER_CYCLE-1 : 0];
	reg[DATA_WIDTH*2-1:0] multiplier_outputs_ff2[POINTS_PER_CYCLE-1 : 0];
	
	//Clear outputs to zero
	initial begin
		for(i=0; i<POINTS_PER_CYCLE; i=i+1) begin
			multiplier_outputs[i]		<= 0;
			multiplier_outputs_ff[i]	<= 0;
			multiplier_outputs_ff2[i]	<= 0;
		end
	end
	
	//The actual multipliers
	always @(posedge clk) begin
		
		for(i=0; i<POINTS_PER_CYCLE; i=i+1) begin
		
			//Do the multiplication (TODO gate when not in use)
			multiplier_outputs[i]		<= $signed(mult_a[i]) * $signed(mult_b[i]);
		
			//Push multiplier results down the pipeline
			multiplier_outputs_ff[i]	<= multiplier_outputs[i];
			multiplier_outputs_ff2[i]	<= multiplier_outputs_ff[i];
		end
		
	end
	
	//Truncate unused LSBs of multiply, and concatenate
	wire[DATA_WIDTH*POINTS_PER_CYCLE-1:0] multiplier_outputs_ff2_trunc;
	generate
		for(g=0; g<POINTS_PER_CYCLE; g=g+1) begin : lsbtrunc
			assign multiplier_outputs_ff2_trunc[g*DATA_WIDTH +: DATA_WIDTH] =
				multiplier_outputs_ff2[g][DATA_WIDTH*2-1 : DATA_WIDTH];
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Summation block
	
	AdderTree #(
		.DATA_WIDTH(DATA_WIDTH),
		.SUM_WIDTH(ORDER_POT),
		.SAMPLES_PER_CLOCK(POINTS_PER_CYCLE),
		.TREE_FANIN(ADDER_TREE_WIDTH)
	) dut (
		.clk(clk),
		.din(multiplier_outputs_ff2_trunc),
		.din_valid(mult_output_valid_ff2),
		.din_start(sum_start),
		.dout(out_data),
		.dout_valid(out_valid)
		);
	
endmodule

