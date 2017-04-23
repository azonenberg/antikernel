`default_nettype none
`timescale 1ns / 1ps
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Formal validation test harness for SingleClockFifo and SingleClockShiftRegisterFifo
 */
module FifosFormal(
	input wire					clk,

	input wire					reset,

	input wire					wr,
	input wire					rd,
	input wire[3:0]				din
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Proof configuration

	localparam WIDTH = 4;
	localparam DEPTH = 4;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The FIFOs

	wire[WIDTH-1:0]	shreg_dout;
	wire			shreg_overflow;
	wire			shreg_underflow;
	wire			shreg_empty;
	wire			shreg_full;
	wire[2:0]		shreg_rsize;
	wire[2:0]		shreg_wsize;

	wire[WIDTH*DEPTH-1 : 0] shreg_contents;

	SingleClockShiftRegisterFifo #(
		.WIDTH(WIDTH),
		.DEPTH(DEPTH),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1)
	) shreg_fifo(
		.clk(clk),
		.wr(wr),
		.din(din),
		.rd(rd),
		.dout(shreg_dout),
		.overflow(shreg_overflow),
		.underflow(shreg_underflow),
		.empty(shreg_empty),
		.full(shreg_full),
		.rsize(shreg_rsize),
		.wsize(shreg_wsize),
		.reset(reset),

		.dout_formal(shreg_contents)
		);

	wire[WIDTH-1:0]	ram_dout;
	wire			ram_overflow;
	wire			ram_underflow;
	wire			ram_empty;
	wire			ram_full;
	wire[2:0]		ram_rsize;
	wire[2:0]		ram_wsize;

	wire[WIDTH*DEPTH-1 : 0] ram_contents;

	SingleClockFifo #(
		.WIDTH(WIDTH),
		.DEPTH(DEPTH),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1)
	) ram_fifo(
		.clk(clk),
		.wr(wr),
		.din(din),
		.rd(rd),
		.dout(ram_dout),
		.overflow(ram_overflow),
		.underflow(ram_underflow),
		.empty(ram_empty),
		.full(ram_full),
		.rsize(ram_rsize),
		.wsize(ram_wsize),
		.reset(reset),

		.dout_formal(ram_contents)
		);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verify equivalence of the fifos against each other

	//Reset while reading/writing is undefined, don't do it
	assume property(! (reset && rd) );
	assume property(! (reset && wr) );

	//Both FIFOs must have the same status state
	assert property(ram_overflow == shreg_overflow);
	assert property(ram_underflow == shreg_underflow);
	assert property(ram_empty == shreg_empty);
	assert property(ram_full == shreg_full);
	assert property(ram_wsize == shreg_wsize);
	assert property(ram_rsize == shreg_rsize);

	//Memory contents must match up (FIFOs mask off the dontcare bits for us)
	assert property(ram_contents == shreg_contents);

	//Check read values for match iff we're not underflowing.
	//If underflowing, read data is undefined.
	reg		last_read_was_underflow = 0;
	reg		rd_ff					= 0;
	always @(posedge clk) begin
		rd_ff		<= rd;

		if(rd_ff)
			last_read_was_underflow <= ram_underflow;

		if(!ram_underflow && !last_read_was_underflow)
			assert(ram_dout == shreg_dout);
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verify correct operation of the RAM FIFO (shreg is proven by equivalence)

	//The amount of used and empty space must always sum to the total capacity
	assert property( (ram_rsize + ram_wsize) == DEPTH );

endmodule
