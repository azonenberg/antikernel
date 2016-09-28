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
	@brief Transceiver for RPC network, protocol version 2, router interface.
	
	Network-side protocol documentation is at http://redmine.drawersteak.com/projects/achd-soc/wiki/NewRPCProtocol.
	
	Fabric interface, transmit side:
		Load a 32x4 LUTRAM with the packet to send (hooked to raddr, rdata)
			rdata is REGISTERED
		Assert rpc_fab_tx_en for one cycle
		Wait for rpc_fab_tx_done to pulse (one cycle only).
			Do not touch the data during the delay period.
			The delay will be at least 4 clk cycles but may be more if retransmits are required.
	
	Fabric interface, receieve side:
		Wait for rpc_fab_rx_en to go high
			rx_en may be asserted as soon as the header arrives to permit cut-through switching
			Process data. During this time, no new packets can be received.
		rpc_fab_inbox_full is high whenever a valid packet is present
		Assert rpc_fab_rx_done for one cycle when packet processing is complete.
		
	The transmit and receive datapaths are fully independent and can operate in full duplex mode.
 */
module RPCv2RouterTransceiver(
	
	//System-synchronous clock
	clk,
	
	//Network interface, outbound side
	rpc_tx_en, rpc_tx_data, rpc_tx_ack,
	
	//Network interface, inbound side
	rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	
	//Fabric interface, outbound side
	rpc_fab_tx_en,
	rpc_fab_tx_rd_en, rpc_fab_tx_raddr, rpc_fab_tx_rdata,
	rpc_fab_tx_done,
	
	//Fabric interface, inbound side
	rpc_fab_rx_en,
	rpc_fab_rx_waddr, rpc_fab_rx_wdata, rpc_fab_rx_dst_addr, rpc_fab_rx_we,
	rpc_fab_rx_done, rpc_fab_inbox_full
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	//System-synchronous clock
	input wire clk;
	
	//Network interface, outbound side
	output wire     	rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	
	//Network interface, inbound side
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0] 	rpc_rx_ack;
	
	//Fabric interface, outbound side
	input wire     		rpc_fab_tx_en;
	output wire	 		rpc_fab_tx_rd_en;
	output wire[1:0]	rpc_fab_tx_raddr;
	input wire[31:0]	rpc_fab_tx_rdata;
	output wire			rpc_fab_tx_done;

	//Fabric interface, inbound side
	output wire			rpc_fab_rx_en;
	output wire[1:0]	rpc_fab_rx_waddr;
	output wire[31:0]	rpc_fab_rx_wdata;
	output wire[15:0]	rpc_fab_rx_dst_addr;
	output wire			rpc_fab_rx_we;
	input wire 			rpc_fab_rx_done;
	output wire			rpc_fab_inbox_full;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The transmitter
	
	parameter LEAF_PORT = 0;
	parameter LEAF_ADDR = 16'h0;
	
	RPCv2RouterTransceiver_transmit #(
		.LEAF_PORT(LEAF_PORT),
		.LEAF_ADDR(LEAF_ADDR)
	) tx (
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
	
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_rd_en(rpc_fab_tx_rd_en),
		.rpc_fab_tx_raddr(rpc_fab_tx_raddr),
		.rpc_fab_tx_rdata(rpc_fab_tx_rdata),
		.rpc_fab_tx_done(rpc_fab_tx_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The receiver
	
	RPCv2RouterTransceiver_receive rx(
		.clk(clk),
	
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_waddr(rpc_fab_rx_waddr),
		.rpc_fab_rx_wdata(rpc_fab_rx_wdata),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_we(rpc_fab_rx_we),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
	);
	
endmodule
