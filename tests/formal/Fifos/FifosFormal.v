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

	`include "../../../antikernel-ipcores/synth_helpers/clog2.vh"
	`include "../../../antikernel-ipcores/proof_helpers/implies.vh"

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Proof configuration

	localparam WIDTH = 4;
	localparam DEPTH = 4;

	//number of bits in the address bus
	localparam ADDR_BITS = clog2(DEPTH);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The FIFOs

	wire[WIDTH-1:0]		shreg_dout;
	wire				shreg_overflow;
	wire				shreg_underflow;
	wire				shreg_empty;
	wire				shreg_full;
	wire[ADDR_BITS:0]	shreg_rsize;
	wire[ADDR_BITS:0]	shreg_wsize;

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

	wire[WIDTH-1:0]		ram_dout;
	wire				ram_overflow;
	wire				ram_underflow;
	wire				ram_empty;
	wire				ram_full;
	wire[ADDR_BITS:0]	ram_rsize;
	wire[ADDR_BITS:0]	ram_wsize;

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
	// Verification helpers

	//Remember what the state was last cycle
	reg					rd_ff			= 0;
	reg					wr_ff			= 0;
	reg					reset_ff		= 0;

	reg[ADDR_BITS:0]	rsize_ff		= 0;
	reg[ADDR_BITS:0]	wsize_ff		= 0;
	reg					full_ff			= 0;
	reg					empty_ff		= 0;

	reg					overflow_ff		= 0;
	reg					underflow_ff	= 0;

	always @(posedge clk) begin
		rd_ff			<= rd;
		wr_ff			<= wr;
		reset_ff		<= reset;

		rsize_ff		<= ram_rsize;
		wsize_ff		<= ram_wsize;
		full_ff			<= ram_full;
		empty_ff		<= ram_empty;

		overflow_ff		<= ram_overflow;
		underflow_ff	<= ram_underflow;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Create friendly names for some common situations

	wire wrote_without_overflowing = (wr_ff && !full_ff);
	wire read_without_underflowing = (rd_ff && !empty_ff);

	wire size_increased = (ram_rsize == (rsize_ff + 1'h1) );
	wire size_decreased = (ram_rsize == (rsize_ff - 1'h1) );
	wire size_unchanged = (ram_rsize == rsize_ff);

	wire reset_singleword_fifo = (reset_ff && (rsize_ff == 1) );

	reg last_read_was_underflow = 0;
	always @(posedge clk) begin
		if(rd_ff)
			last_read_was_underflow <= ram_underflow;
	end

	wire last_read_was_valid = (!ram_underflow && !last_read_was_underflow);

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
	//(If underflowing, read data is undefined.)
	assert property( implies(last_read_was_valid, ram_dout == shreg_dout) );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verify correct control-plane operation of the RAM FIFO (shreg is proven by equivalence)

	//The amount of used and empty space must always sum to the total capacity
	assert property( (ram_rsize + ram_wsize) == DEPTH );

	//Iff we write to a full FIFO, it should overflow
	//(no forwarding so reading during the write won't help)
	assert property( (wr_ff && full_ff) == ram_overflow);

	//Iff we read from an empty FIFO, it should underflow
	//(no forwarding so writing during the read won't help)
	assert property( (rd_ff && empty_ff) == ram_underflow);

	//After a successful write, unless we also read, we should have one more word in the fifo now.
	//This is the only time this should happen.
	assert property( (wrote_without_overflowing && !read_without_underflowing) == size_increased );

	//We should have one less word in the fifo if we read a word (unless we also wrote).
	//But it can also happen if we had one word in the fifo when we reset it!
	assert property(
		(
			(read_without_underflowing && !wrote_without_overflowing) ||
			(reset_singleword_fifo)
		) == size_decreased);

	//After simultaneous successful read and write, size shouldn't change.
	assert property( implies(read_without_underflowing && wrote_without_overflowing, size_unchanged) );

	//If we reset the FIFO, it should now be empty (but this can of course happen other ways too)
	assert property( implies(reset_ff, ram_empty ) );

	//Empty means size is zero
	assert property( (ram_rsize == 0) == ram_empty);

	//Full means size is max
	assert property( (ram_rsize == DEPTH) == ram_full);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Data-plane model of the FIFO

	//The FIFO data
	//[rsize - 1] is always the next word to be read
	reg[WIDTH-1:0]		fifo_data[DEPTH-1:0];

	//Data we just read
	reg[WIDTH-1:0] 		fifo_rdata = 0;

	//Behavioral model of the data-plane side of the FIFO.
	//We don't have to model the control plane because we've already verified that, so use the existing control signals
	integer i;
	always @(posedge clk) begin

		//Don't touch buffer on read
		if(!ram_empty && rd)
			fifo_rdata			<= fifo_data[ram_rsize - 1'b1];

		//Write to the start of the buffer and push things down
		if(!ram_full && wr) begin
			for(i=1; i<DEPTH; i=i+1)
				fifo_data[i]	<= fifo_data[i-1];
			fifo_data[0] <= din;
		end

	end

	//Concatenated copy of the memory
	reg[WIDTH*DEPTH-1 : 0]	fifo_contents = 0;
	always @(*) begin
		for(i=0; i<DEPTH; i=i+1) begin
			if(i < ram_rsize)
				fifo_contents[i*WIDTH +: WIDTH]	<= fifo_data[i];
			else
				fifo_contents[i*WIDTH +: WIDTH]	<= {WIDTH{1'b0}};
		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verify correct data-plane operation

	//Our behavioral model of the memory should always have the same data as the synthesizeable one
	assert property(fifo_contents == ram_contents);

	//After a successful read, we should be reading the same data
	assert property( implies(last_read_was_valid, ram_dout == fifo_rdata) );

endmodule
