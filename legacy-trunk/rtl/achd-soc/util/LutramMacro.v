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
	@brief A parameterizable width 32/64/128/256 level dual port LUT RAM.
 */
module LutramMacroDP(clk, porta_we, porta_addr, porta_din, porta_dout, portb_addr, portb_dout);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 16;
	parameter DEPTH = 32;
	
	`include "clog2.vh"
	
	//number of bits in the address bus
	localparam ADDR_BITS = clog2(DEPTH);
	
	input wire clk;
	input wire porta_we;
	input wire[ADDR_BITS-1:0] porta_addr;
	input wire[WIDTH-1:0] porta_din;
	output wire[WIDTH-1:0] porta_dout;
	input wire[ADDR_BITS-1:0] portb_addr;
	output wire[WIDTH-1:0] portb_dout;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The RAM itself
	
	wire porta_dout_low[WIDTH-1:0];
	wire porta_dout_high[WIDTH-1:0];
	wire portb_dout_low[WIDTH-1:0];
	wire portb_dout_high[WIDTH-1:0];
	
	genvar i;
	generate
		for(i=0; i<WIDTH; i = i+1) begin: ramblock

			if(DEPTH == 32) begin
				RAM32X1D #(.INIT(32'h00000000)) ram (
					.WCLK(clk),
					.WE(porta_we),
					.D(porta_din[i]),
					.SPO(porta_dout[i]),
					.A0(porta_addr[0]),
					.A1(porta_addr[1]),
					.A2(porta_addr[2]),
					.A3(porta_addr[3]),
					.A4(porta_addr[4]),
					
					.DPO(portb_dout[i]),
					.DPRA0(portb_addr[0]),
					.DPRA1(portb_addr[1]),
					.DPRA2(portb_addr[2]),
					.DPRA3(portb_addr[3]),
					.DPRA4(portb_addr[4])
				);
			end
			else if(DEPTH == 64) begin
				RAM64X1D #(.INIT(64'h00000000)) ram (
					.WCLK(clk),
					.WE(porta_we),
					.D(porta_din[i]),
					.SPO(porta_dout[i]),
					.A0(porta_addr[0]),
					.A1(porta_addr[1]),
					.A2(porta_addr[2]),
					.A3(porta_addr[3]),
					.A4(porta_addr[4]),
					.A5(porta_addr[5]),
					
					.DPO(portb_dout[i]),
					.DPRA0(portb_addr[0]),
					.DPRA1(portb_addr[1]),
					.DPRA2(portb_addr[2]),
					.DPRA3(portb_addr[3]),
					.DPRA4(portb_addr[4]),
					.DPRA5(portb_addr[5])
				);
			end
			else if(DEPTH == 128) begin
				RAM128X1D #(.INIT(128'h00000000)) ram (
					.WCLK(clk),
					.WE(porta_we),
					.D(porta_din[i]),
					.SPO(porta_dout[i]),
					.A(porta_addr),
					
					.DPO(portb_dout[i]),
					.DPRA(portb_addr)
				);
			end
			else if(DEPTH == 256) begin
			
				RAM128X1D #(.INIT(128'h00000000)) ram_low (
					.WCLK(clk),
					.WE(porta_we && !porta_addr[7]),
					.D(porta_din[i]),
					.SPO(porta_dout_low[i]),
					.A(porta_addr[6:0]),
					.DPO(portb_dout_low[i]),
					.DPRA(portb_addr[6:0])
				);
				
				RAM128X1D #(.INIT(128'h00000000)) ram_high (
					.WCLK(clk),
					.WE(porta_we && porta_addr[7]),
					.D(porta_din[i]),
					.SPO(porta_dout_high[i]),
					.A(porta_addr[6:0]),
					.DPO(portb_dout_high[i]),
					.DPRA(portb_addr[6:0])
				);
				
				assign porta_dout[i] = porta_addr[7] ? porta_dout_high[i] : porta_dout_low[i];
				assign portb_dout[i] = portb_addr[7] ? portb_dout_high[i] : portb_dout_low[i];

			end
			
			else begin
				initial begin
					$display("ERROR - LutramMacroDP only supports depth values in {32, 64, 128, 256}");
					$finish;
				end
			end
		end
	endgenerate

endmodule

/**
	@brief A parameterizable width 32 level simple dual port LUT RAM.
	
	Width must be a multiple of 6.
	
	Optional registered outputs.
 */
module LutramMacroSDP(clk, porta_we, porta_addr, porta_din, portb_addr, portb_dout);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O and parameter declarations

	parameter WIDTH = 18;
	parameter DEPTH = 32;
	
	parameter OUTREG = 0;
	
	`include "clog2.vh"
	
	//number of bits in the address bus
	localparam ADDR_BITS = clog2(DEPTH);
	
	generate
		initial begin	
			if(DEPTH != 32) begin
				$display("ERROR - LutramMacroSDP only supports depth value 32");
				$finish;
			end
		end
	endgenerate
	
	input wire clk;
	input wire porta_we;

	input wire[ADDR_BITS-1:0] porta_addr;
	input wire[WIDTH-1:0] porta_din;

	input wire[ADDR_BITS-1:0] portb_addr;
	output wire[WIDTH-1:0] portb_dout;
		
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The RAM itself
	
	wire[WIDTH*2 - 1:0] garbage;
	
	//Actual RAM output
	wire[WIDTH-1:0] portb_dout_raw;
	
	genvar i;
	generate
	
		//Register the outputs
		if(OUTREG) begin
			reg[WIDTH-1:0] portb_dout_ff = 0;
			assign portb_dout = portb_dout_ff;
			
			always @(posedge clk)
				portb_dout_ff <= portb_dout_raw;
			
		end
		else
			assign portb_dout = portb_dout_raw;
	
		for(i=0; i<WIDTH; i = i+6) begin: ramblock
			RAM32M #(
				.INIT_A(64'h0000000000000000),
				.INIT_B(64'h0000000000000000),
				.INIT_C(64'h0000000000000000),
				.INIT_D(64'h0000000000000000)
			) ramblock (
				.WCLK(clk),
				.WE(porta_we),
				.DIA(porta_din[i+1:i]),
				.DIB(porta_din[i+3:i+2]),
				.DIC(porta_din[i+5:i+4]),
				.DID(garbage[i*2+1 : i*2]),			//cannot use port D if doing dual port
													//since we have only four address ports
													//and would need five to have true random access
				.ADDRD(porta_addr),

				.DOA(portb_dout_raw[i+1:i]),
				.DOB(portb_dout_raw[i+3:i+2]),
				.DOC(portb_dout_raw[i+5:i+4]),
				.DOD(garbage[i*2+1 : i*2]),
				.ADDRA(portb_addr),
				.ADDRB(portb_addr),
				.ADDRC(portb_addr)		
			);
		end
	endgenerate

endmodule
