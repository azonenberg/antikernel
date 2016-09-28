`default_nettype none
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
	@brief Integer divide unit
	
	Operation:
		At any time, assert in_start.
		Set in_sign to high for signed and low for unsigned division.
		Set in_tid to the thread ID and in_dend/in_dvsr to the input values.
 */
module SaratogaCPUDivider(
	clk,
	
	in_start, in_sign, in_tid, in_dend, in_dvsr,
	
	out_done, out_tid, out_quot, out_rem
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;
	
	//Input bus
	input wire					in_start;
	input wire					in_sign;
	input wire[TID_BITS-1 : 0]	in_tid;
	input wire[31:0]			in_dend;
	input wire[31:0]			in_dvsr;
	
	//Output bus
	output reg					out_done	= 0;
	output reg[TID_BITS-1 : 0]	out_tid		= 0;
	output reg[31:0]			out_quot	= 0;
	output reg[31:0]			out_rem		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The main divide logic
	
	`include "../math/FindLeftHandDigit.vh"
	
	//State variables
	//Step number indicates state is valid at the entry of that state
	//Note that step 31 is the first one to execute
	integer i;
	reg					step_valid[31:0];				//Indicates if the output of this stage is valid
	reg					step_output_invert[31:0];		//Indicates if the division should negate the quotient and remainder
	reg[31:0]			step_rem[31:0];					//Remainder as of start of this cycle
	reg[31:0]			step_quot[31:0];				//Quotient as of start of this cycle
	reg[31:0]			step_dvsr[31:0];				//Divisor for this division
	reg[4:0]			step_lhd[31:0];					//Left-hand digit of divisor
	reg[TID_BITS-1 : 0]	step_tid[31:0];					//Thread ID of this ste[
	initial begin
		for(i=0; i<32; i=i+1) begin
			step_valid[i]			<= 0;
			step_output_invert[i]	<= 0;
			step_rem[i]				<= 0;
			step_quot[i]			<= 0;
			step_dvsr[i]			<= 0;
			step_lhd[i]				<= 0;
			step_tid[i]				<= 0;
		end
	end
	
	//Combinatorial inversion of negative inputs
	reg[31:0]	dend_flipped 		= 0;
	reg[31:0]	dvsr_flipped 		= 0;
	reg			dend_is_negative	= 0;
	reg			dvsr_is_negative	= 0;
	always @(*) begin
		dend_flipped 		<= ~(in_dend) + 32'h1;
		dvsr_flipped 		<= ~(in_dvsr) + 32'h1;
		dend_is_negative	<= in_dend[31] && in_sign;
		dvsr_is_negative	<= in_dvsr[31] && in_sign;
	end
	
	reg						internal_valid			= 0;
	reg						internal_output_invert	= 0;
	reg[31:0]				internal_rem			= 0;
	reg[31:0]				internal_quot			= 0;
	reg[TID_BITS - 1 : 0]	internal_tid			= 0;

	always @(posedge clk) begin
		
		//SETUP
		//Save start state and inputs (after flipping to positive as necessary).
		//Quotient starts out as zero.
		//Invert output if exactly one input is negative
		step_valid[31]			<= in_start;
		step_quot[31]			<= 0;
		step_rem[31]			<= dend_is_negative ? dend_flipped : in_dend;
		step_dvsr[31]			<= dvsr_is_negative ? dvsr_flipped : in_dvsr;
		step_lhd[31]			<= dvsr_is_negative ? FindLeftHandDigit(dvsr_flipped) : FindLeftHandDigit(in_dvsr);
		step_output_invert[31]	<= dend_is_negative ^ dvsr_is_negative;
		step_tid[31]			<= in_tid;
			
		//Loop over all bits. Note that division progresses from the MSB to the LSB.
		//Input #31 is set by the last stage
		for(i=0; i<31; i=i+1) begin
			
			//Pass status down the pipeline
			step_valid[i]			<= step_valid[i+1];
			step_dvsr[i]			<= step_dvsr[i+1];
			step_lhd[i]				<= step_lhd[i+1];
			step_output_invert[i]	<= step_output_invert[i+1];
			step_tid[i]				<= step_tid[i+1];
			
			//default to zero quotient for this stage
			step_quot[i]			<= step_quot[i+1];
			step_rem[i]				<= step_rem[i+1];
			
			//If we'd overflow when shifting, don't even bother checking
			if(step_lhd[i+1] >= (31 - i)) begin
				
			end
			
			//Otherwise, shift and subtract if it fits
			else if( (step_dvsr[i+1] << i) <= step_rem[i+1] ) begin
				step_rem[i]			<= step_rem[i+1] - (step_dvsr[i+1] << i);
				step_quot[i]		<= step_quot[i+1] | (32'h1 << i);
			end
			
		end
		
		//Last stage of the division
		//No need to do range check or save lhd/divisor
		internal_valid				<= step_valid[0];
		internal_output_invert		<= step_output_invert[0];
		internal_tid				<= step_tid[0];
		internal_rem				<= step_rem[0];
		internal_quot				<= step_quot[0];
		if(step_rem[0] >= step_dvsr[0]) begin
			internal_rem			<= step_rem[0] - step_dvsr[0];
			internal_quot[0]		<= 1'b1;
		end
		
		//Final postprocessing - complement outputs if needed, otherwise just output them
		out_done					<= internal_valid;
		out_tid						<= internal_tid;
		out_quot					<= internal_quot;
		out_rem						<= internal_rem;
		if(internal_output_invert) begin
			out_quot				<= ~internal_quot + 32'h1;
			out_rem					<= ~internal_rem + 32'h1;
		end
		
	end
	
endmodule
