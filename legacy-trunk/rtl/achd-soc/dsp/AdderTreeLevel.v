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
	@brief A single level of an adder tree
 */
module AdderTreeLevel(
	clk,
	din, din_valid,
	dout, dout_valid
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter	DATA_WIDTH			= 32;		//Width of one integer being summed
	parameter	SUM_WIDTH			= 8;		//Number of integers to sum per clock
	parameter	TREE_FANIN			= 4;		//Maximum number of inputs to add in a single clock cycle.
												//Must evenly divide SUM_WIDTH
												//Must be a power of two
												
	parameter	PAD_WIDTH			= 0;		//If set nonzero, pads ports to this width
												//(avoids warnings in some cascade structures)

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Number of sums being evaluated per clock
	//Need to cap at 1 to avoid problems with the last tree level
	localparam PARALLEL_SUMS	= (SUM_WIDTH < TREE_FANIN) ? 1 : SUM_WIDTH / TREE_FANIN;
	
	localparam IN_WIDTH_REAL 	= DATA_WIDTH * SUM_WIDTH;
	localparam IN_WIDTH			= PAD_WIDTH ? PAD_WIDTH : IN_WIDTH_REAL;
	localparam OUT_WIDTH_REAL	= DATA_WIDTH * PARALLEL_SUMS;
	localparam OUT_WIDTH		= PAD_WIDTH ? PAD_WIDTH : OUT_WIDTH_REAL;
	
	input wire						clk;
	
	input wire[IN_WIDTH-1 : 0]		din;
	input wire						din_valid;
	
	output reg[OUT_WIDTH-1 : 0]		dout		= 0;
	output reg						dout_valid	= 0;
	
	//Actual adder fan-in.
	//Always equal to TREE_FANIN unless we're in the last stage of the tree
	//in which case we cap it at SUM_WIDTH
	localparam REAL_FANIN		= (SUM_WIDTH < TREE_FANIN) ? SUM_WIDTH : TREE_FANIN;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual adder tree
	
	integer block;
	integer i;
	
	reg[DATA_WIDTH-1 : 0] temp;
	always @(posedge clk) begin
	
		//push status down the pipe
		dout_valid		<= din_valid;
		
		//Sum blocks in parallel
		for(block=0; block<PARALLEL_SUMS; block=block+1) begin
		
			//Do the actual addition
			for(i=0; i<REAL_FANIN; i=i+1) begin
				if(i == 0)
					temp = din[block*DATA_WIDTH*TREE_FANIN + i*DATA_WIDTH +: DATA_WIDTH];
				else
					temp = temp + din[block*DATA_WIDTH*TREE_FANIN + i*DATA_WIDTH +: DATA_WIDTH];
			end
				
			//Write to the output register
			dout[block*DATA_WIDTH +: DATA_WIDTH]	<= temp;
			
		end
		
		//Fill unused outputs with zeroes
		if(PAD_WIDTH)
			dout[OUT_WIDTH-1 : OUT_WIDTH_REAL]	<= 0;
	
	end

endmodule
