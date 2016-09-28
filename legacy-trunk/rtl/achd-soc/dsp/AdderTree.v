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
	@brief Pipelined, tree-based adder for summing a large number of integers
	
	Basic workflow:
		When data is ready, feed SAMPLES_PER_CLOCK words of DATA_WIDTH bits each into din and assert din_valid.
			Set din_start to indicate the start of a new sum.
		After (SUM_WIDTH / SAMPLES_PER_CLOCK) blocks of data have been fed in, a single sum is computed.
		
		dout_valid goes high for one cycle to indicate a sum is ready.
		
	The internal latency is:
		Stage 1: log_{TREE\_FANIN}(SAMPLES_PER_CLOCK) cycles to reduce each parallel block to one
		Stage 2: SUM_WIDTH / SAMPLES_PER_CLOCK cycles to reduce all blocks to one
		One final register cycle to improve output timing
 */
module AdderTree(
	clk,
	din, din_valid, din_start,
	dout, dout_valid
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter DATA_WIDTH		= 32;		//Width of one integer being summed
	parameter SUM_WIDTH			= 64;		//Number of integers to sum
	parameter SAMPLES_PER_CLOCK	= 8;		//Number of input values per clock
											//Must evenly divide SUM_WIDTH
	parameter TREE_FANIN		= 4;		//Maximum number of inputs to add in a single clock cycle.
											//Must evenly divide SAMPLES_PER_CLOCK
											//Must be a power of two
												
	localparam BLOCK_COUNT		= SUM_WIDTH / SAMPLES_PER_CLOCK;	//Number of input blocks in one sum
	
	`include "../util/clog2.vh";
	localparam BLOCK_BITS		= clog2(BLOCK_COUNT);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire						clk;
	
	//width of the input bus
	localparam IN_WIDTH = DATA_WIDTH * SAMPLES_PER_CLOCK;
	
	input wire						din_start;			//Set true to reset the counter and start a new block
	input wire[IN_WIDTH - 1 : 0]	din;				//The input data
	input wire						din_valid;			//Set true to process data, false to ignore
	
	output reg[DATA_WIDTH-1 : 0]	dout		= 0;	//Output bus
	output reg						dout_valid	= 0;	//Goes high to indicate a sum is ready
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity checks
	
	initial begin
		if(TREE_FANIN > SAMPLES_PER_CLOCK) begin
			$display("ERROR: TREE_FANIN (%d) must be <= SAMPLES_PER_CLOCK (%d)", TREE_FANIN, SAMPLES_PER_CLOCK);
			$finish;
		end
		
		if(SAMPLES_PER_CLOCK % TREE_FANIN) begin
			$display("ERROR: TREE_FANIN must evenly divide SAMPLES_PER_CLOCK");
			$finish;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// STAGE 1 reduction
	
	//Calculate the number of summations we need in order to reduce the input
	localparam STAGE1_DEPTH		= clogn(SAMPLES_PER_CLOCK, TREE_FANIN);
	
	//We need to declare the whole (square) matrix, even though it's actually right upper triangular
	//XST should optimize out the lower triangle... hopefully? anyone?
	wire[IN_WIDTH-1 : 0] stage1_sums[STAGE1_DEPTH : 0];
	wire[IN_WIDTH-1 : 0] stage1_sum_last = stage1_sums[STAGE1_DEPTH];
	
	//Validity flags for the matrix rows
	wire				stage1_sum_valid[STAGE1_DEPTH : 0];
	wire				stage1_block_start[STAGE1_DEPTH : 0];
	
	//Load the first row with the initial data
	assign				stage1_sums[0] = din;
	assign				stage1_sum_valid[0]	= din_valid;
	assign				stage1_block_start[0] = din_start;
	reg					stage1_start_ff[STAGE1_DEPTH-1 : 0];
	
	//Calculate the number of samples being summed for a given level of the triangular matrix
	function integer sumwidth;
		input integer level;
		begin
			sumwidth = SAMPLES_PER_CLOCK >> (level * clog2(TREE_FANIN));
		end
	endfunction
	
	//Create the adder trees for each level
	//Sum only the upper triangle of the matrix
	genvar i;
	generate
		for(i=0; i<STAGE1_DEPTH; i=i+1) begin:stage1
		
			//Clear out the start flag
			initial begin
				stage1_start_ff[i] = 0;
			end
		
			//Do the actual addition
			AdderTreeLevel #(
				.DATA_WIDTH(DATA_WIDTH),
				.SUM_WIDTH(sumwidth(i)),
				.TREE_FANIN(TREE_FANIN),
				.PAD_WIDTH(IN_WIDTH)
			) adderstage (
				.clk(clk),
				.din(stage1_sums[i]),
				.din_valid(stage1_sum_valid[i]),
				.dout(stage1_sums[i+1]),
				.dout_valid(stage1_sum_valid[i+1])
			);
			
			//Push the start flag down the piipeline
			always @(posedge clk) begin
				stage1_start_ff[i] <= stage1_block_start[i];
			end
			assign stage1_block_start[i+1] = stage1_start_ff[i];
			
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// STAGE 2 reduction

	reg[DATA_WIDTH-1 : 0]	accum 		= 0;
	reg[BLOCK_BITS : 0]		blocknum 	= 0;	
	reg						accum_new	= 0;
	
	always @(posedge clk) begin
	
		accum_new	<= 0;
		dout_valid	<= 0;
	
		//Update if we have a sum coming out the pipe
		if(stage1_sum_valid[STAGE1_DEPTH]) begin
		
			//Start of a new sum? Just save it
			if(stage1_block_start[STAGE1_DEPTH]) begin
				accum		<= stage1_sum_last[0 +: DATA_WIDTH];
				blocknum	<= 1;	//use 1-based indexing for easier comparison at the end
				accum_new	<= 1;
			end
				
			//Nope, add it
			else begin
				accum		<= accum + stage1_sum_last[0 +: DATA_WIDTH];
				blocknum	<= blocknum + 1'd1;
				accum_new	<= 1;
			end
		
		end
		
		//If we just calculated the last sum, feed it out
		if( (blocknum == BLOCK_COUNT) && accum_new) begin
			dout		<= accum;
			dout_valid	<= 1;
		end
	
	end
		
endmodule
