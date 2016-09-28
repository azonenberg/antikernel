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
	@brief NoC wrapper around the LED bank
 */
module NetworkedLEDBank(
	clk,
	leds, 
	noc_tx_en, noc_tx_data, noc_tx_ack, noc_rx_en, noc_rx_data, noc_rx_ack
    );

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	input wire clk;
	
	output reg[7:0] leds = 0;
	
	output wire noc_tx_en;
	output wire[31:0] noc_tx_data;
	input wire noc_tx_ack;
	input wire noc_rx_en;
	input wire[31:0] noc_rx_data;
	output wire noc_rx_ack;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The transceiver
	wire rx_en;
	wire[31:0] rx_d0;
	RPCTransceiver txvr(
		.clk(clk),
		.rpc_tx_en(noc_tx_en),
		.rpc_tx_data(noc_tx_data),
		.rpc_tx_ack(noc_tx_ack),
		.rpc_rx_en(noc_rx_en),
		.rpc_rx_data(noc_rx_data),
		.rpc_rx_ack(noc_rx_ack),
		.tx_ready(),
		.tx_ready_c(),
		.tx_en(1'b0),
		.tx_src_addr(16'h0),
		.tx_dst_addr(16'h0),
		.tx_d0(32'h0),
		.tx_d1(32'h0),
		.tx_d2(32'h0),
		.rx_ready(1'b1),
		.rx_en(rx_en),
		.rx_src_addr(),
		.rx_dst_addr(),
		.rx_d0(rx_d0),
		.rx_d1(),
		.rx_d2()
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine

	always @(posedge clk) begin
	
		//first data word
		if(rx_en)
			leds <= rx_d0[7:0];
	end

endmodule
