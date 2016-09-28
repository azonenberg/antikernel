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
	@brief Formal validation test harness for RPCv2Router ingress queues
	
	The goal of this test is to prove that, assuming RPCv2RouterTransceiver_receive is correct, that the ingress
	queue state is always correct.
	
	More formally:
		Incoming packets are correctly written to SRAM
		When the SRAM buffer is full, incoming packets are rejected with a NAK
		When tx_done from any port is asserted while tx_selected_sender points to us, the SRAM buffer is cleared
 */
module main(
	clk,
	rpc_rx_en, rpc_rx_data,
	port_selected_sender, port_fab_tx_done, port_fab_tx_rd_en, port_fab_tx_raddr
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
		
	input wire[14:0]	port_selected_sender;
	input wire[4:0]		port_fab_tx_done;
	input wire[4:0]		port_fab_tx_rd_en;
	input wire[9:0]		port_fab_tx_raddr;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Ingress queue stuff
	
	wire				rpc_fab_rx_en;
	wire[1:0]			rpc_fab_rx_waddr;
	wire[31:0]			rpc_fab_rx_wdata;
	wire[15:0]			rpc_fab_rx_dst_addr;
	wire				rpc_fab_rx_we;
	wire				rpc_fab_inbox_full;
	
	wire[1:0]			rpc_rx_ack;
	
	wire				rpc_fab_rx_done;
	
	parameter THIS_PORT = 3'h0;
	
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

	//Packet buffer SRAM is assumed correct
	
	wire[1:0]	port_rdbuf_addr;
	
	RPCv2RouterInboxTracking #(
		.PORT_COUNT(4),
		.THIS_PORT(THIS_PORT)
	) inbox_tracker (
		.clk(clk),
		.port_selected_sender(port_selected_sender),
		.port_fab_tx_rd_en(port_fab_tx_rd_en),
		.port_fab_tx_raddr(port_fab_tx_raddr),
		.port_fab_tx_done(port_fab_tx_done),
		.port_fab_rx_done(rpc_fab_rx_done),
		.port_rdbuf_addr(port_rdbuf_addr)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[2:0]	state	= 0;
	reg[2:0]	count	= 0;
	
	integer i;
	integer rpc_fab_rx_done_expected;
	
	always @(posedge clk) begin

		case(state)
			
			//IDLE - wait for something to happen
			0: begin
				
				assert(rpc_fab_inbox_full == 0);
				assert(rpc_fab_rx_waddr == 0);
				
				count <= 0;
			
				//If we get a rx_en, start buffering the packet. Take no action until the packet is fully received.
				if(rpc_rx_en) begin
					state <= 1;
					count <= 1;
					assert(rpc_fab_rx_we == 1);
				end
				else
					assert(rpc_fab_rx_we == 0);

			end	//state 0
			
			//Packet is currently being buffered into the SRAM. Don't use it yet.
			1: begin
				
				count <= count + 1;
				
				assert(rpc_fab_rx_waddr == count);			
				assert(rpc_fab_rx_we == 1);
				
				//Done receiving the packet
				if(count == 3) begin
					count <= 0;
					state <= 2;
				end
				
			end //state 1
			
			//Packet is now fully received. Wait for send to finish crunching it
			2: begin
				
				//Packet should be in buffer
				assert(rpc_fab_inbox_full == 1);
				assert(rpc_fab_rx_we == 0);
				assert(rpc_fab_rx_waddr == 0);
				
				//We're done if anyone is sending from us, and they've finished sending
				rpc_fab_rx_done_expected = 0;
				for(i=0; i<5; i=i+1) begin
					if( (port_selected_sender[i*3 +: 3] == THIS_PORT) && (port_fab_tx_done[i]) )
						rpc_fab_rx_done_expected = 1;
				end
				assert(rpc_fab_rx_done == rpc_fab_rx_done_expected);
				
				//Reset if we're done sending
				if(rpc_fab_rx_done)
					state <= 0;
				
			end

		endcase
		
	end
	
endmodule
