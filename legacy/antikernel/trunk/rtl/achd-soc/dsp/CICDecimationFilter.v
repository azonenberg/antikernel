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
	@brief CIC decimation filter
 */
module CICDecimationFilter(
	clk,
	din, din_valid,
	dout, dout_valid
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter IN_WIDTH			= 1;		//Width of the input data stream
	parameter TEMP_WIDTH		= 24;		//Width of intermediate accumulators
	parameter OUT_WIDTH			= 16;		//Width of the output vector
	parameter ORDER				= 3;		//Number of filter stages
	parameter DECIMATION		= 52;		//Decimation factor
	
	`include "../util/clog2.vh";
	localparam COUNT_BITS		= clog2(DECIMATION);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire						clk;
	
	input wire[IN_WIDTH - 1 : 0]	din;				//The input data
	input wire						din_valid;			//Set true to process data, false to ignore
	
	output reg[OUT_WIDTH-1 : 0]		dout		= 0;	//Output bus
	output reg						dout_valid	= 0;	//Goes high to indicate a new value is ready
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Integrators
	
	reg[TEMP_WIDTH-1:0]	integrator[ORDER-1:0];
	
	integer i;
	initial begin
		for(i=0; i<ORDER; i=i+1)
			integrator[i] = 0;
	end
	
	always @(posedge clk) begin
		if(din_valid) begin
			integrator[0]	<= integrator[0] + din;
			
			for(i=1; i<ORDER; i=i+1)
				integrator[i]	<= integrator[i] + integrator[i-1];
		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Decimation clock
	
	//Timer for slow clock
	reg[COUNT_BITS:0]		count 		= 0;
	reg						slow_clk	= 0;
	always @(posedge clk) begin
		slow_clk	<= 0;
		
		if(din_valid == 1) begin
			count	<= count + 1'h1;
			
			if(count == (DECIMATION - 1)) begin
				slow_clk	<= 1;
				count		<= 0;
			end
			
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Differentiators
	
	wire[TEMP_WIDTH-1:0]	differentiator[ORDER:0];
	reg[TEMP_WIDTH-1:0]	differentiator_ff[ORDER:0];
	
	initial begin
		for(i=0; i<=ORDER; i=i+1)
			differentiator_ff[i] = 0;
	end
	
	genvar g;
	generate
		
		//Pre-seed the first differentiator with the integrator output
		assign differentiator[0] = integrator[ORDER-1];
		
		//Then differentiate from here on
		for(g=1; g<=ORDER; g=g+1) begin : intblock
			assign differentiator[g] = differentiator[g-1] - differentiator_ff[g-1]; 
		end		
		
	endgenerate
	
	//Register outputs
	always @(posedge clk) begin

		if(slow_clk) begin
			for(i=0; i<=ORDER; i=i+1)
				differentiator_ff[i]	<= differentiator[i];
		end

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output
	
	always @(posedge clk) begin
		dout_valid	<= 0;
		if(slow_clk) begin
			dout_valid	<= 1;
			dout		<= differentiator_ff[ORDER][OUT_WIDTH-1:0];
		end
	end
		
endmodule
