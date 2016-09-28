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
	`include "clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);
	
	//set true to enable port B
	parameter DUAL_PORT = 1;
	
	//set true to use block RAM, false for distributed RAM
	parameter USE_BLOCK = 1;
	
	//set 0 to not register outputs
	//set 1 to register outputs with one stage
	//set 2 to register outputs with two stages
	//note that USE_BLOCK requires OUT_REG to be nonzero.
	//Read enables are ignored if OUT_REG is zero.
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
	output wire[WIDTH-1 : 0]	porta_dout;
	
	input wire					portb_clk;
	input wire					portb_en;
	input wire[ADDR_BITS-1 : 0]	portb_addr;
	input wire					portb_we;
	input wire[WIDTH-1 : 0]		portb_din;
	output wire[WIDTH-1 : 0]	portb_dout;
	
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
	reg[WIDTH-1 : 0]			storage[DEPTH-1 : 0];
	
	//Width capped to 32 for initialization
	localparam PWIDTH = (WIDTH > 32) ? 32 : WIDTH;
	
	//Initialization
	integer i;
	generate
		initial begin
			
			//address fill
			if(INIT_ADDR) begin
				for(i=0; i<DEPTH; i=i+1)
					storage[i] <= i[PWIDTH-1 : 0];
			end
			
			//file load
			else if(INIT_FILE != "")
				$readmemh(INIT_FILE, storage);
			
			//zero fill otherwise
			else begin
				for(i=0; i<DEPTH; i=i+1)
					storage[i] <= INIT_VALUE[PWIDTH-1 : 0];
			end
			
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Port A
	
	reg[WIDTH-1 : 0]		porta_dout_raw 		= 0;
	reg[WIDTH-1 : 0]		porta_dout_raw_ff	= 0;
	
	generate
	
		//Write port is always enabled
		always @(posedge porta_clk) begin
			if(porta_we && porta_en)
				storage[porta_addr] <= porta_din;
		end
		
		if(OUT_REG) begin
			always @(posedge porta_clk) begin
				porta_dout_raw_ff	<= porta_dout_raw;
				if(porta_en)
					porta_dout_raw	<= storage[porta_addr];
			end
			
		end
		else begin
			always @(*)
				porta_dout_raw <= storage[porta_addr];
		end
		
		if( (OUT_REG == 0) || (OUT_REG == 1) )
			assign porta_dout	= porta_dout_raw;
		else
			assign porta_dout	= porta_dout_raw_ff;
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Port B
	
	generate
	
		if(DUAL_PORT) begin
		
			reg[WIDTH-1 : 0]		portb_dout_raw 		= 0;
			reg[WIDTH-1 : 0]		portb_dout_raw_ff	= 0;
	
			//write port is only enabled in true dual port mode
			if(TRUE_DUAL) begin
				always @(posedge portb_clk) begin
					if(portb_we && portb_en)
						storage[portb_addr] <= portb_din;
				end
			end
			
			if(OUT_REG) begin
				always @(posedge portb_clk) begin
					portb_dout_raw_ff	<= portb_dout_raw;
					if(portb_en)
						portb_dout_raw <= storage[portb_addr];
				end
			end
			else begin
				always @(*)
					portb_dout_raw <= storage[portb_addr];
			end
			
			if( (OUT_REG == 0) || (OUT_REG == 1) )
				assign portb_dout	= portb_dout_raw;
			else
				assign portb_dout	= portb_dout_raw_ff;
			
		end
		
		else
			assign portb_dout = {WIDTH{1'b0}};
	
	endgenerate
	
endmodule
