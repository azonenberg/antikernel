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
	@brief Automatic gain control module
 */
module AutomaticGainControl(
	clk,
	din, din_valid,
	dout, dout_valid,
	
	agc_gain
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	localparam DATA_WIDTH		= 32;		//Width of one integer being summed
	parameter AGC_SAMPLES		= 2048;		//Number of samples to run over for the peak detector
	
	parameter MIN_AMPLITUDE		= 32'h20000000;
	parameter MAX_AMPLITUDE		= 32'h40000000;
	
	`include "../util/clog2.vh";
	localparam AGC_BITS = clog2(AGC_SAMPLES);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire						clk;
		
	input wire[DATA_WIDTH - 1 : 0]	din;				//The input data
	input wire						din_valid;			//Set true to process data, false to ignore
	
	output reg[DATA_WIDTH-1 : 0]	dout		= 0;	//Output bus
	output reg						dout_valid	= 0;	//Goes high to indicate new data is ready
	
	output reg[DATA_WIDTH-1:0] 	agc_gain	= 32'h00010000;	//fixed point 16.16, unity gain
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The core AGC logic
	
	//Gain compensation
	(* MULT_STYLE = "PIPE_BLOCK" *)
	reg[DATA_WIDTH*2-1:0]	agc_mult		= 0;
	reg[DATA_WIDTH*2-1:0]	agc_mult_ff		= 0;
	reg[DATA_WIDTH*2-1:0]	agc_mult_ff2	= 0;
	
	reg						din_valid_ff	= 0;
	reg						din_valid_ff2	= 0;
	reg						din_valid_ff3	= 0;
	always @(posedge clk) begin
		
		agc_mult		<= $signed(agc_gain) * $signed(din);
		agc_mult_ff		<= agc_mult;
		agc_mult_ff2	<= agc_mult_ff;
		
		din_valid_ff	<= din_valid;
		din_valid_ff2	<= din_valid_ff;
		din_valid_ff3	<= din_valid_ff2;
		
		dout_valid		<= din_valid_ff3;
		dout			<= agc_mult_ff2[47:16];	//fixed point shift
		
	end

	//Post-gain control peak detector and feedback logic
	reg[31:0]			agc_max		= 0;
	reg[AGC_BITS-1:0]	agc_count	= 0;
	wire[AGC_BITS-1:0]	agc_count_next	= agc_count + 1'h1;
	always @(posedge clk) begin
		
		//Peak detector
		if($signed(dout) >= 0) begin
			if(dout > agc_max)
				agc_max	<= dout;
		end
		else begin
			if(-$signed(dout) > agc_max)
				agc_max	<= -$signed(dout);
		end
		
		agc_count		<= agc_count_next;
		
		//Count period is done, update the input gain
		//TODO: smoother steps when updating (say 1/8192 every few clocks for N clocks)
		if(agc_count_next == 0) begin
			
			//If the signal is too weak and AGC isn't already maxed out, increase the gain by 1/128
			if( (agc_max < MIN_AMPLITUDE) && (agc_gain < 32'h40000000) )
				agc_gain	<= agc_gain + agc_gain[31:9];
				
			//If the signal is too strong and AGC isn't already bottomed out, decrease the gain by 1/128
			if( (agc_max > MAX_AMPLITUDE) && (agc_gain > 32'h00000100) )
				agc_gain	<= agc_gain - agc_gain[31:9];
		
			agc_max		<= 0;
		end
	end	
	
endmodule
