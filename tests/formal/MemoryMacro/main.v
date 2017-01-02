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
	localparam DEPTH = 4;

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

		  wire[WIDTH-1:0]		porta_dout_0_comb;
		  wire[WIDTH-1:0]		porta_dout_1_comb;
		  wire[WIDTH-1:0]		porta_dout_2_comb;

	input wire					portb_en;
	input wire					portb_we;
	input wire[ADDR_BITS-1:0]	portb_addr;
	input wire[WIDTH-1:0]		portb_din;
		  wire[WIDTH-1:0]		portb_dout_0;
		  wire[WIDTH-1:0]		portb_dout_1;
		  wire[WIDTH-1:0]		portb_dout_2;

		  wire[WIDTH-1:0]		portb_dout_0_comb;
		  wire[WIDTH-1:0]		portb_dout_1_comb;
		  wire[WIDTH-1:0]		portb_dout_2_comb;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUTs: three memories with different latency for each

	MemoryMacro #(
		.DUAL_PORT(1),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.TRUE_DUAL(1),
		.INIT_VALUE(0),
		.WIDTH(WIDTH),
		.DEPTH(DEPTH)
	) mem_lat0 (
		.porta_clk(clk),
		.porta_en(porta_en),
		.porta_addr(porta_addr),
		.porta_we(porta_we),
		.porta_din(porta_din),
		.porta_dout(porta_dout_0),
		.porta_dout_comb(porta_dout_0_comb),

		.portb_clk(clk),
		.portb_en(portb_en),
		.portb_addr(portb_addr),
		.portb_we(portb_we),
		.portb_din(portb_din),
		.portb_dout(portb_dout_0),
		.portb_dout_comb(portb_dout_0_comb)
	);

	MemoryMacro #(
		.DUAL_PORT(1),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.TRUE_DUAL(1),
		.INIT_VALUE(0),
		.WIDTH(WIDTH),
		.DEPTH(DEPTH)
	) mem_lat1 (
		.porta_clk(clk),
		.porta_en(porta_en),
		.porta_addr(porta_addr),
		.porta_we(porta_we),
		.porta_din(porta_din),
		.porta_dout(porta_dout_1),
		.porta_dout_comb(porta_dout_1_comb),

		.portb_clk(clk),
		.portb_en(portb_en),
		.portb_addr(portb_addr),
		.portb_we(portb_we),
		.portb_din(portb_din),
		.portb_dout(portb_dout_1),
		.portb_dout_comb(portb_dout_1_comb)
	);

	MemoryMacro #(
		.DUAL_PORT(1),
		.USE_BLOCK(1),
		.OUT_REG(2),
		.TRUE_DUAL(1),
		.INIT_VALUE(0),
		.WIDTH(WIDTH),
		.DEPTH(DEPTH)
	) mem_lat2 (
		.porta_clk(clk),
		.porta_en(porta_en),
		.porta_addr(porta_addr),
		.porta_we(porta_we),
		.porta_din(porta_din),
		.porta_dout(porta_dout_2),
		.porta_dout_comb(porta_dout_2_comb),

		.portb_clk(clk),
		.portb_en(portb_en),
		.portb_addr(portb_addr),
		.portb_we(portb_we),
		.portb_din(portb_din),
		.portb_dout(portb_dout_2),
		.portb_dout_comb(portb_dout_2_comb)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification helpers

	//Write enable is gated by port enable so save the gated value for reference
	wire porta_writing = (porta_en & porta_we);
	wire portb_writing = (portb_en & portb_we);

	//Check if we're reading the same address on both ports
	wire address_match = (porta_addr == portb_addr);

	//Check if we got the same data on both ports (combinatorially)
	wire data_match = (porta_dout_0_comb == portb_dout_0_comb);

	//Keep track of when each port was enabled.
	reg					porta_en_ff  = 0;
	reg					portb_en_ff  = 0;
	always @(posedge clk) begin
		porta_en_ff			<= porta_en;
		portb_en_ff			<= portb_en;
	end

	//Delay all of the combinatorial and registered outputs to an overall 2 clocks of latency.
	//Output holds stable when enable is low.
	reg[WIDTH-1:0]		porta_dout_0_ff  = 0;
	reg[WIDTH-1:0]		portb_dout_0_ff  = 0;
	reg[WIDTH-1:0]		porta_dout_0_ff2 = 0;
	reg[WIDTH-1:0]		portb_dout_0_ff2 = 0;
	reg[WIDTH-1:0]		porta_dout_1_ff  = 0;
	reg[WIDTH-1:0]		portb_dout_1_ff  = 0;
	always @(posedge clk) begin
		if(porta_en)
			porta_dout_0_ff		<= porta_dout_0;
		if(portb_en)
			portb_dout_0_ff		<= portb_dout_0;

		if(porta_en_ff) begin
			porta_dout_0_ff2	<= porta_dout_0_ff;
			porta_dout_1_ff		<= porta_dout_1;
		end
		if(portb_en_ff) begin
			portb_dout_0_ff2	<= portb_dout_0_ff;
			portb_dout_1_ff		<= portb_dout_1;
		end

	end

	//Cycle counter
	reg[ADDR_BITS:0] count = 0;
	wire setup = (count < DEPTH);
	always @(posedge clk) begin
		if(count < DEPTH)
			count <= count + 1'b1;
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Simple behavioral model of the combinatorial memory

	reg[WIDTH-1:0] vmem[DEPTH-1:0];

	always @(posedge clk) begin
		if(porta_writing)
			vmem[porta_addr] <= porta_din;
		if(portb_writing)
			vmem[portb_addr] <= portb_din;
	end

	//Read it
	wire[WIDTH-1:0] vm_a = vmem[porta_addr];
	wire[WIDTH-1:0] vm_b = vmem[portb_addr];

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Preconditions

	//Don't assert write enable when port isn't enabled (there's no point)
	assume property(!porta_we || porta_en);
	assume property(!portb_we || portb_en);

	//Result of simultaneous writes to the same address on both ports is undefined, so don't allow it
	assume property ( !porta_writing || !portb_writing || !address_match );

	//Initialize all memory to zero during the setup period
	//FIXME: Why do we need to do vm_a/vm_b separately?
	always @(posedge clk) begin
		if(setup) begin
			assume(vm_a == 0);
			assume(vm_b == 0);
			assume(porta_en && porta_we && porta_din == 0 && porta_addr == count);
		emd
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties	

	//Reading the memory should give the same value as our simple behavioral model
	assert property (vm_a == porta_dout_0_comb);
	assert property (vm_b == portb_dout_0_comb);

	//All copies of the memory must be equal (combinatorial reads should give identical results)
	assert property (porta_dout_0_comb == porta_dout_1_comb);
	assert property (porta_dout_0_comb == porta_dout_2_comb);

	//If port A has identical data, port B must (since it's reading from the same RAM)
	assert property(portb_dout_0_comb == portb_dout_1_comb);
	assert property(portb_dout_0_comb == portb_dout_2_comb);

	//Both ports are point to the same memory (reading the same address on both ports should give identical results)
	assert property(!address_match || data_match);

	//Latency-0 memory (LUTRAM with no FF) should be a combinatorial read
	assert property (porta_dout_0 == porta_dout_0_comb);
	assert property (portb_dout_0 == portb_dout_0_comb);
	
	//Make sure all memories have the requested latency.
	//A combinatorial memory delayed by one clock should be the same as a synchronous one.
	//A synchronous memory delayed by one clock should be the same as a synchronous one with output register.
	assert property (porta_dout_0_ff == porta_dout_1);
	assert property (porta_dout_0_ff2 == porta_dout_1_ff);
	assert property (porta_dout_1_ff == porta_dout_2);

	assert property (portb_dout_0_ff == portb_dout_1);
	assert property (portb_dout_0_ff2 == portb_dout_1_ff);
	assert property (portb_dout_1_ff == portb_dout_2);

endmodule
