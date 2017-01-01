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
	@brief Formal validation test harness for MemoryMacro
	
	The goal of this test is to prove that a MemoryMacro actually functions like memory and has the correct latency.

	This test only covers a single clock domain; multi-domain behavior is not tested.
 */
module main(
	clk,
	porta_en, porta_we, porta_addr, porta_din,
	portb_en, portb_we, portb_addr, portb_din
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Proof configuration

	//Dimensions of the memory.
	//This is parameterizable and we make it small for the formal test so it completes faster.
	//The proof should easily generalize to wider or deeper memories.
	localparam WIDTH = 2;
	localparam DEPTH = 16;

	//get bus size
	`include "../../../antikernel-ipcores/synth_helpers/clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;

	input wire					porta_en;
	input wire					porta_we;
	input wire[ADDR_BITS-1:0]	porta_addr;
	input wire[WIDTH-1:0]		porta_din;
		  wire[WIDTH-1:0]		porta_dout_0;
		  wire[WIDTH-1:0]		porta_dout_1;
		  wire[WIDTH-1:0]		porta_dout_2;

	input wire					portb_en;
	input wire					portb_we;
	input wire[ADDR_BITS-1:0]	portb_addr;
	input wire[WIDTH-1:0]		portb_din;
		  wire[WIDTH-1:0]		portb_dout_0;
		  wire[WIDTH-1:0]		portb_dout_1;
		  wire[WIDTH-1:0]		portb_dout_2;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUTs

	MemoryMacro #(
		.DUAL_PORT(1),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.TRUE_DUAL(1),
		.NO_INIT(1)
	) mem_lat0 (
		.porta_clk(clk),
		.porta_en(porta_en),
		.porta_addr(porta_addr),
		.porta_we(porta_we),
		.porta_din(porta_din),
		.porta_dout(porta_dout_0),

		.portb_clk(clk),
		.portb_en(portb_en),
		.portb_addr(portb_addr),
		.portb_we(portb_we),
		.portb_din(portb_din),
		.portb_dout(portb_dout_0)
	);

	MemoryMacro #(
		.DUAL_PORT(1),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.TRUE_DUAL(1),
		.NO_INIT(1)
	) mem_lat1 (
		.porta_clk(clk),
		.porta_en(porta_en),
		.porta_addr(porta_addr),
		.porta_we(porta_we),
		.porta_din(porta_din),
		.porta_dout(porta_dout_1),

		.portb_clk(clk),
		.portb_en(portb_en),
		.portb_addr(portb_addr),
		.portb_we(portb_we),
		.portb_din(portb_din),
		.portb_dout(portb_dout_1)
	);
	
	MemoryMacro #(
		.DUAL_PORT(1),
		.USE_BLOCK(1),
		.OUT_REG(2),
		.TRUE_DUAL(1),
		.NO_INIT(1)
	) mem_lat2 (
		.porta_clk(clk),
		.porta_en(porta_en),
		.porta_addr(porta_addr),
		.porta_we(porta_we),
		.porta_din(porta_din),
		.porta_dout(porta_dout_2),

		.portb_clk(clk),
		.portb_en(portb_en),
		.portb_addr(portb_addr),
		.portb_we(portb_we),
		.portb_din(portb_din),
		.portb_dout(portb_dout_2)
	);

	//Delay all of the combinatorial and registered outputs to an overall 2 clocks of latency
	reg[WIDTH-1:0]		porta_dout_0_ff  = 0;
	reg[WIDTH-1:0]		portb_dout_0_ff  = 0;
	reg[WIDTH-1:0]		porta_dout_0_ff2 = 0;
	reg[WIDTH-1:0]		portb_dout_0_ff2 = 0;

	reg[WIDTH-1:0]		porta_dout_1_ff  = 0;
	reg[WIDTH-1:0]		portb_dout_1_ff  = 0;

	always @(posedge clk) begin
		porta_dout_0_ff		<= porta_dout_0;
		portb_dout_0_ff		<= portb_dout_0;

		porta_dout_0_ff2	<= porta_dout_0_ff;
		portb_dout_0_ff2	<= portb_dout_0_ff;

		porta_dout_1_ff		<= porta_dout_1;
		portb_dout_1_ff		<= portb_dout_1;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic

	//First pass: make sure all memories have the requested latency.
	//A combinatorial memory delayed by one clock should be the same as a synchronous one.
	//A synchronous memory delayed by one clock should be the same as a synchronous one with output register.
	assert property(porta_dout_0_ff2 == porta_dout_2);
	assert property(portb_dout_0_ff2 == portb_dout_2);
	assert property(porta_dout_1_ff == porta_dout_2);
	assert property(portb_dout_1_ff == portb_dout_2);
	
endmodule
