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
	@brief ROM-based sine wave generator
	
	Output is fixed point twos complement fractional with the non-symmetric value (-2^n) not used.
	For example with 8 bit precision:
	
	sin( 0 deg)	 =  0.00
	sin(90 deg)  =  0.7F
	sin(180 deg) =  0.00
	sin(270 deg) = -0.7F
	
	Phase goes from 0 to 2^{PHASE_BITS}-1. For example with 10 bit precision:
	0x000		= 0 deg
	0x100		= 90 deg
	0x200		= 180 deg
	0x300		= 270 deg
	
	Usage:
		Bring update high for one cycle with phase set
		After latency (3 clocks) dout is updated
		TODO: Make latency parameterizable
 */
 
module SineWaveGenerator(clk, update, phase, sin_out, cos_out);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	parameter PHASE_SIZE 	= 1024;						//Number of entries in the phase ROM table
	localparam PHASE_BITS	= clog2(PHASE_SIZE);		//Size of a ROM address (0-90 deg)
	localparam PHASE_RBITS	= PHASE_BITS + 2;			//Size of an input phase (0-360 deg)
	parameter FRAC_BITS		= 16;						//Number of bits in the sine wave output
														//This includes the sign bit so the ROM is one bit smaller
														//These parameters will fill one 18kbit block RAM.

	localparam ROM_DBITS	= FRAC_BITS - 1;			//Number of data bits in the ROM (unsigned)
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire						clk;
	input wire						update;
	input wire[PHASE_RBITS-1 : 0]	phase;
	output reg[FRAC_BITS-1 : 0]		sin_out		= 0;
	output reg[FRAC_BITS-1 : 0]		cos_out		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Generate the ROM address
	
	reg[PHASE_BITS-1 : 0]		sin_addr	= 0;
	reg[PHASE_BITS-1 : 0]		cos_addr	= 0;
	reg							sin_flip	= 0;
	reg							cos_flip	= 0;
	
	//SINE output
	always @(*) begin
	
		//90-180 or 270-360 deg
		if(phase[PHASE_RBITS-2])
			sin_addr	<= {PHASE_BITS{1'b1}} - phase[0 +: PHASE_BITS];
			
		//0-90 or 180-270 deg
		else
			sin_addr	<= phase[0 +: PHASE_BITS];
			
		//180 - 360 deg
		if(phase[PHASE_RBITS-1] && (sin_addr != 0))
			sin_flip	<= 1;
		
		//0 - 180 deg
		else
			sin_flip	<= 0;
		
	end
	
	//COSINE output
	reg[PHASE_RBITS-1 : 0]			cos_phase;
	always @(*) begin
		cos_phase	<= phase + PHASE_SIZE[PHASE_RBITS-1 : 0];
		
		//90-180 or 270-360 deg
		if(cos_phase[PHASE_RBITS-2])
			cos_addr	<= {PHASE_BITS{1'b1}} - cos_phase[0 +: PHASE_BITS];
			
		//0-90 or 180-270 deg
		else
			cos_addr	<= cos_phase[0 +: PHASE_BITS];
			
		//180 - 360 deg
		if(cos_phase[PHASE_RBITS-1] && (cos_addr != 0))
			cos_flip	<= 1;
		
		//0 - 180 deg
		else
			cos_flip	<= 0;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register status flags for reads
	
	//valid same cycle as *_romout
	reg		sin_flip_ff		= 0;
	reg		cos_flip_ff		= 0;
	
	//valid same cycle as *_romout_ff
	reg		sin_flip_ff2	= 0;
	reg		cos_flip_ff2	= 0;
	
	//valid same cycle as *_pos/neg
	reg		sin_flip_ff3	= 0;
	reg		cos_flip_ff3	= 0;
	
	always @(posedge clk) begin
		sin_flip_ff		<= sin_flip;
		cos_flip_ff		<= cos_flip;
		sin_flip_ff2	<= sin_flip_ff;
		cos_flip_ff2	<= cos_flip_ff;
		sin_flip_ff3	<= sin_flip_ff2;
		cos_flip_ff3	<= cos_flip_ff2;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Compute true and inverted ROM outputs
	
	//Need the KEEP constraint to prevent these from being merged into the ROM (LUT FFs have lower Tcko)
	//This optimization is only needed for Spartan-6 due to high BRAM Tcko with output register
	//For -2 spartan6 Tcko of BRAM with no register is 2100 ps, or 1750 with pipeline register
	//but a fabric FF is only 530ps
	`ifdef XILINX_SPARTAN6
		(* KEEP = "yes" *) reg[ROM_DBITS-1 : 0]	sin_romout_ff	= 0;
		(* KEEP = "yes" *) reg[ROM_DBITS-1 : 0]	cos_romout_ff	= 0;
	`else
		reg[ROM_DBITS-1 : 0]	sin_romout_ff	= 0;
		reg[ROM_DBITS-1 : 0]	cos_romout_ff	= 0;
	`endif
	
	reg[FRAC_BITS-1 : 0]	sin_out_pos	= 0;
	reg[FRAC_BITS-1 : 0]	sin_out_neg	= 0;
	reg[FRAC_BITS-1 : 0]	cos_out_pos	= 0;
	reg[FRAC_BITS-1 : 0]	cos_out_neg	= 0;
	
	//Negate without sign extension
	reg[ROM_DBITS-1 : 0]	sin_romout_ff_neg	= 0;
	reg[ROM_DBITS-1 : 0]	cos_romout_ff_neg	= 0;
	always @(*) begin
		sin_romout_ff_neg	<= ~(sin_romout_ff) + 1'b1;
		cos_romout_ff_neg	<= ~(cos_romout_ff) + 1'b1;
	end
	
	always @(posedge clk) begin
		sin_out_pos		<= sin_romout_ff;
		sin_out_neg		<= {1'b1, sin_romout_ff_neg};
		cos_out_pos		<= cos_romout_ff;
		cos_out_neg		<= {1'b1, cos_romout_ff_neg};
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Mux ROM outputs down to final outputs
	
	always @(posedge clk) begin
		sin_out			<= sin_flip_ff3 ? sin_out_neg : sin_out_pos;
		cos_out			<= cos_flip_ff3 ? cos_out_neg : cos_out_pos;		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual sinewave lookup table
	
	reg[ROM_DBITS-1:0] sine_table[PHASE_SIZE-1:0];
	
	//Load the ROM
	integer fullscale;
	integer i;
	time tmp;
	initial begin
	
		//Full-scale value (2^n - 1)
		fullscale = {1'b1, {ROM_DBITS{1'b0}} } - 1'b1;
		
		//Load the sine table
		//Intermediate results have to be stored as 1.6 precision decimal fixed point
		//because XST is derpy and won't let us use reals even if they're intermediate results (not synthesized)
		for(i=0; i<PHASE_SIZE; i=i+1) begin
			tmp = $sin($itor(i * 1570796 / PHASE_SIZE) / 1000000) * fullscale;
			sine_table[i] = tmp[ROM_DBITS-1 : 0];
		end

	end

	reg[ROM_DBITS-1 : 0]	sin_romout	= 0;
	reg[ROM_DBITS-1 : 0]	cos_romout	= 0;
	
	//Read it
	always @(posedge clk) begin
		if(update) begin
			sin_romout	<= sine_table[sin_addr];
			cos_romout	<= sine_table[cos_addr];
		end
		
		sin_romout_ff	<= sin_romout;
		cos_romout_ff	<= cos_romout;
	end

endmodule
