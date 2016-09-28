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
	@brief Search matching for name server
 */
module NOCNameServer_TargetMatching(
	clk,
	host_out, addr_out,
	host_out_ff, addr_out_ff,
	target_host, target_addr,
	host_hit, addr_hit
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	input wire	 		clk;

	input wire[63:0]	host_out;
	input wire[15:0]	addr_out;
	
	output reg[63:0]	host_out_ff	= 0;
	output reg[15:0]	addr_out_ff	= 0;
	
	input wire[63:0]	target_host;
	input wire[15:0]	target_addr;
	
	output reg 			host_hit = 0;
	output reg 			addr_hit = 0;
	
	//Second register stage on memory outputs to improve timing
	always @(posedge clk) begin
		host_out_ff	<= host_out;
		addr_out_ff	<= addr_out;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Target matching (done in parallel with second register cycle)

	always @(posedge clk) begin
		addr_hit		<= (addr_out == target_addr);
		host_hit		<= (host_out == target_host);
	end
	
endmodule
