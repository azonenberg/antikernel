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
	@brief The register file
 */
module GraftonCPURegisterFile(
	clk,
	
	decode_stallin, decode_regid_a, decode_regid_b,
	
	execute_regval_a, execute_regval_b,
	
	writeback_we, writeback_regid, writeback_regval
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//DECODE interface
	input wire decode_stallin;
	input wire[4:0] decode_regid_a;
	input wire[4:0] decode_regid_b;
	
	//EXECUTE interface
	output reg[31:0] execute_regval_a;
	output reg[31:0] execute_regval_b;
	
	//WRITEBACK interface
	input wire writeback_we;
	input wire[4:0] writeback_regid;
	input wire[31:0] writeback_regval;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual RAM banks
	
	wire[31:0] execute_regval_a_async;
	wire[31:0] execute_regval_b_async;
	
	LutramMacroDP #(
		.WIDTH(32),
		.DEPTH(32)
		) rambank_a (
		.clk(clk),
		.porta_we(writeback_we && (writeback_regid != 0)),
		.porta_addr(writeback_regid),
		.porta_din(writeback_regval),
		.porta_dout(),
		.portb_addr(decode_regid_a),
		.portb_dout(execute_regval_a_async)
		);
		
	LutramMacroDP #(
		.WIDTH(32),
		.DEPTH(32)
		) rambank_b (
		.clk(clk),
		.porta_we(writeback_we && (writeback_regid != 0)),
		.porta_addr(writeback_regid),
		.porta_din(writeback_regval),
		.porta_dout(),
		.portb_addr(decode_regid_b),
		.portb_dout(execute_regval_b_async)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output buffering and forwarding from writeback stage
	
	always @(posedge clk) begin
	
		if(!decode_stallin) begin
			
			execute_regval_a <= execute_regval_a_async;
			execute_regval_b <= execute_regval_b_async;
			
			//Don't forward writes to $zero
			if(writeback_we && (writeback_regid != 0)) begin
				if(decode_regid_a == writeback_regid)
					execute_regval_a <= writeback_regval;
				if(decode_regid_b == writeback_regid)
					execute_regval_b <= writeback_regval;
			end
				
		end
	
	end
	
endmodule
