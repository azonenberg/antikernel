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
	@brief A generic dual-port memory macro.
	
	Parameterizable width, depth, etc.
	
	Read enables ignored in combinatorial mode.
 */
module MemoryMacro(
	porta_clk, porta_en, porta_addr, porta_we, porta_din, porta_dout,
	portb_clk, portb_en, portb_addr, portb_we, portb_din, portb_dout
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//dimensions of the array
	parameter WIDTH = 16;
	parameter DEPTH = 512;
	
	//number of bits in the address bus
	`include "../../rtl/achd-soc/util/clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);
	
	//set true to enable port B
	parameter DUAL_PORT = 1;
	
	//set true to use block RAM, false for distributed RAM
	parameter USE_BLOCK = 1;
	
	//set true to register outputs, false to not register
	//note that USE_BLOCK requires OUT_REG to be true.
	//Read enables are ignored if OUT_REG is not set.
	parameter OUT_REG = 1;
	
	//set true to enable writes on port B (ignored if not dual port)
	parameter TRUE_DUAL = 1;
	
	//Initialize to address (takes precedence over INIT_FILE)
	parameter INIT_ADDR = 0;
	
	//Initialization file (set to empty string to fill with zeroes)
	parameter INIT_FILE = "";
	
	//If neither INIT_ADDR nor INIT_FILE is set, set to INIT_VALUE
	parameter INIT_VALUE = {WIDTH{1'h0}};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					porta_clk;
	input wire					porta_en;
	input wire[ADDR_BITS-1 : 0]	porta_addr;
	input wire					porta_we;
	input wire[WIDTH-1 : 0]		porta_din;
	output reg[WIDTH-1 : 0]		porta_dout = 0;
	
	input wire					portb_clk;
	input wire					portb_en;
	input wire[ADDR_BITS-1 : 0]	portb_addr;
	input wire					portb_we;
	input wire[WIDTH-1 : 0]		portb_din;
	output reg[WIDTH-1 : 0]		portb_dout = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity checks
	
	initial begin
		if(USE_BLOCK && !OUT_REG) begin
			$display("[MemoryMacro] Block RAM requires output registers");
			$finish;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The memory
	
	localparam rstyle = USE_BLOCK ? "block" : "distributed";
	
	//The data
	(* RAM_STYLE = rstyle *)
	//(* nomem2reg *)
	reg[WIDTH-1 : 0]			storage[DEPTH-1 : 0];
	
	//Initialization
	integer i;
	initial begin
		for(i=0; i<DEPTH; i=i+1)
			storage[i] <= INIT_VALUE[WIDTH-1 : 0];
	end
	
	always @(*) begin
		assert(INIT_ADDR == 0);
		assert(INIT_FILE == "");
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Port A
	
	generate
	
		always @(posedge porta_clk) begin
			if(porta_we && porta_en)
				storage[porta_addr] <= porta_din;
		end
		
		if(OUT_REG) begin
			always @(posedge porta_clk) begin
				if(porta_en)
					porta_dout <= storage[porta_addr];
			end
		end
		else begin
			always @(*)
				porta_dout <= storage[porta_addr];
		end
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Port B
	
	generate
	
		if(DUAL_PORT) begin
	
			if(TRUE_DUAL) begin
				always @(posedge portb_clk) begin
					if(portb_we && portb_en)
						storage[portb_addr] <= portb_din;
				end
			end
			
			if(OUT_REG) begin
				always @(posedge portb_clk) begin
					if(portb_en)
						portb_dout <= storage[portb_addr];
				end
			end
			else begin
				always @(*)
					portb_dout <= storage[portb_addr];
			end
			
		end
	
	endgenerate
	
endmodule
