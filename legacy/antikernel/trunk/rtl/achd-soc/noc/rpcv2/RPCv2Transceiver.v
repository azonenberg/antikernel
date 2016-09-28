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
	@brief Transceiver for RPC network, protocol version 2
	
	Network-side protocol documentation is at http://redmine.drawersteak.com/projects/achd-soc/wiki/NewRPCProtocol.
	
	Fabric interface, transmit side:
		Load rpc_fab_tx_*
		Assert rpc_fab_tx_en for one cycle
		Wait for rpc_fab_tx_done to pulse (one cycle only).
			Do not touch rpc_fab_tx_* during the delay period.
			The delay will be at least 4 clk cycles but may be more if retransmits are required.
		Can now write to rpc_fab_tx_* for the next message
		
	Fabric interface, receieve side:
		Wait for rpc_fab_rx_en to go high
		Process data. During this time, no new packets can be received.
		Assert rpc_fab_rx_done for one cycle when packet processing is complete.
		
	The transmit and receive datapaths are fully independent and can operate in full duplex mode.
 */
module RPCv2Transceiver(
	
	//System-synchronous clock
	clk,
	
	//Network interface, outbound side
	rpc_tx_en, rpc_tx_data, rpc_tx_ack,
	
	//Network interface, inbound side
	rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	
	//Fabric interface, outbound side
	rpc_fab_tx_en,
	rpc_fab_tx_src_addr, rpc_fab_tx_dst_addr,
	rpc_fab_tx_callnum, rpc_fab_tx_type, rpc_fab_tx_d0,
	rpc_fab_tx_d1,
	rpc_fab_tx_d2,
	rpc_fab_tx_done,
	
	//Fabric interface, inbound side
	rpc_fab_rx_en,
	rpc_fab_rx_src_addr, rpc_fab_rx_dst_addr,
	rpc_fab_rx_callnum, rpc_fab_rx_type, rpc_fab_rx_d0,
	rpc_fab_rx_d1,
	rpc_fab_rx_d2,
	rpc_fab_rx_done, rpc_fab_inbox_full
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//System-synchronous clock
	input wire clk;
	
	//Network interface, outbound side
	output wire			rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	
	//Network interface, inbound side
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0]	rpc_rx_ack;
	
	//Fabric interface, outbound side
	input wire 			rpc_fab_tx_en;
	input wire[15:0]	rpc_fab_tx_src_addr;
	input wire[15:0]	rpc_fab_tx_dst_addr;
	input wire[7:0]		rpc_fab_tx_callnum;
	input wire[2:0]		rpc_fab_tx_type;
	input wire[20:0]	rpc_fab_tx_d0;
	input wire[31:0]	rpc_fab_tx_d1;
	input wire[31:0]	rpc_fab_tx_d2;
	output wire			rpc_fab_tx_done;
	
	//Fabric interface, inbound side
	output wire			rpc_fab_rx_en;
	output wire[15:0]	rpc_fab_rx_src_addr;
	output wire[15:0]	rpc_fab_rx_dst_addr;
	output wire[7:0]	rpc_fab_rx_callnum;
	output wire[2:0]	rpc_fab_rx_type;
	output wire[20:0]	rpc_fab_rx_d0;
	output wire[31:0]	rpc_fab_rx_d1;
	output wire[31:0]	rpc_fab_rx_d2;
	input wire			rpc_fab_rx_done;
	output wire			rpc_fab_inbox_full;
	
	parameter LEAF_PORT = 0;
	parameter LEAF_ADDR = 16'h0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit side
	
	RPCv2Transceiver_transmit tx (
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(LEAF_PORT ? LEAF_ADDR : rpc_fab_tx_src_addr),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive side
	
	RPCv2Transceiver_receive rx (
		.clk(clk),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
	);
	
endmodule
