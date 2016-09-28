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
	@brief A single-clock FIFO
	
	Note that the reset line clears the FIFO to the empty state, regardless of the power-on init value
 */
module SingleClockFifo(
	clk,
	wr, din,
	rd, dout,
	overflow, underflow, empty, full, rsize, wsize, reset
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter WIDTH = 32;
	parameter DEPTH = 512;
	
	//number of bits in the address bus
	`include "clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);
	
	//set true to use block RAM, false for distributed RAM
	parameter USE_BLOCK = 1;
	
	//Specifies the register mode for outputs.
	//When FALSE:
	// * dout updates on the clk edge after a write if the fifo is empty
	// * read dout whenever empty is false, then strobe rd to advance pointer
	//When TRUE:
	// * dout updates on the clk edge after a read when the fifo has data in it
	// * assert rd, read dout the following cycle
	// * dout is stable until next rd pulse
	parameter OUT_REG = 1;
	
	//Initialize to address (takes precedence over INIT_FILE)
	parameter INIT_ADDR = 0;
	
	//Initialization file (set to empty string to fill with zeroes)
	parameter INIT_FILE = "";
	
	//Default if neither is set is to initialize to zero
	
	//Set to true for the FIFO to begin in the "full" state
	parameter INIT_FULL = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	input wire					clk;
	
	input wire					wr;
	input wire[WIDTH-1:0]		din;
	
	input wire					rd;
	output wire[WIDTH-1:0]		dout;
	
	output reg					overflow = 0;
	output reg					underflow = 0;
	
	output wire					empty;
	output wire					full;
	
	output wire[ADDR_BITS:0]	rsize;
	output wire[ADDR_BITS:0]	wsize;
	
	input wire					reset;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Control logic
	
	reg[ADDR_BITS:0]			rpos = 0;						//extra bit for full/empty detect
	reg[ADDR_BITS:0] 			wpos = INIT_FULL ? DEPTH : 0;
	
	wire[ADDR_BITS:0]			irpos = rpos + 1'd1;
	wire[ADDR_BITS:0]			iwpos = wpos + 1'd1;
	
	assign empty				= (rpos == wpos);			//if write pointer is at read pointer we're empty
	assign full					= (wpos == rpos + DEPTH);	//if write pointer is at far end of buffer, we're full
	
	//The number of values currently ready to read
	assign rsize				= wpos - rpos;
	
	//The number of spaces available for us to write to
	assign wsize				= DEPTH[ADDR_BITS:0] + rpos - wpos;
	
	always @(posedge clk) begin
		overflow <= 0;
		underflow <= 0;
		
		if(reset) begin
			rpos <= 0;
			wpos <= 0;
		end
		
		//Read
		if(rd) begin
		
			//Empty? Can't do anything
			if(empty) begin
				underflow <= 1;
				// synthesis translate_off
				$display("[SingleClockFifo] %m WARNING: Underflow occurred!");
				// synthesis translate_on
			end
			
			//All is well, bump stuff
			else begin
				rpos <= irpos;
			end
		
		end
				
		//Write only
		if(wr) begin
			
			//Full? Error
			if(full) begin
				overflow <= 1;
				// synthesis translate_off
				$display("[SingleClockFifo] %m WARNING: Overflow occurred!");
				// synthesis translate_on
			end
			
			//No, just write
			else begin
				wpos <= iwpos;
			end
			
		end

		//read during write when empty not legal
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The memory
	
	MemoryMacro #(
		.WIDTH(WIDTH),
		.DEPTH(DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(USE_BLOCK),
		.OUT_REG(OUT_REG),
		.INIT_ADDR(INIT_ADDR),
		.INIT_FILE(INIT_FILE)
	) mem (
		.porta_clk(clk),
		.porta_en(wr),
		.porta_addr(wpos[ADDR_BITS-1 : 0]),
		.porta_we(!full),
		.porta_din(din),
		.porta_dout(),
		.portb_clk(clk),
		.portb_en(rd),
		.portb_addr(rpos[ADDR_BITS-1 : 0]),
		.portb_we(1'b0),
		.portb_din({WIDTH{1'b0}}),
		.portb_dout(dout)
	);
	
endmodule
