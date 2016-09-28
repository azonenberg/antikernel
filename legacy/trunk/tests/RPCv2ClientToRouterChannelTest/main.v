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
	@brief Formal validation test harness for RPCv2Transceiver / RPCv2RouterTransceiver
	
	The goal of this test is to prove that when a RPCv2Transceiver_transmit talks to a RPCv2RouterTransceiver_receive,
	the packets are always forwarded correctly and unchanged.
 */
module main(
	clk,
	rpc_fab_tx_en, rpc_fab_tx_src_addr, rpc_fab_tx_dst_addr, rpc_fab_tx_callnum,
	rpc_fab_tx_type, rpc_fab_tx_d0, rpc_fab_tx_d1, rpc_fab_tx_d2,
	rpc_fab_rx_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			rpc_fab_tx_en;
	input wire[15:0]	rpc_fab_tx_src_addr;
	input wire[15:0]	rpc_fab_tx_dst_addr;
	input wire[7:0]		rpc_fab_tx_callnum;
	input wire[2:0]		rpc_fab_tx_type;
	input wire[20:0]	rpc_fab_tx_d0;
	input wire[31:0]	rpc_fab_tx_d1;
	input wire[31:0]	rpc_fab_tx_d2;
	
	input wire			rpc_fab_rx_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceivers

	//The RPC bus between endpoints
	wire		link_en;
	wire[31:0]	link_data;
	wire[1:0]	link_ack;
	
	wire		rpc_fab_tx_done;

	RPCv2Transceiver_transmit txvr (
		.clk(clk),
		
		.rpc_tx_en(link_en),
		.rpc_tx_data(link_data),
		.rpc_tx_ack(link_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(rpc_fab_tx_src_addr),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done)
	);

	wire				rpc_fab_rx_en;
	wire[1:0]			rpc_fab_rx_waddr;
	wire[31:0]			rpc_fab_rx_wdata;
	wire[15:0]			rpc_fab_rx_dst_addr;
	wire				rpc_fab_rx_we;
	wire				rpc_fab_inbox_full;
	
	RPCv2RouterTransceiver_receive rx(
		.clk(clk),
		
		.rpc_rx_en(link_en),
		.rpc_rx_data(link_data),
		.rpc_rx_ack(link_ack),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_waddr(rpc_fab_rx_waddr),
		.rpc_fab_rx_wdata(rpc_fab_rx_wdata),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		
		.rpc_fab_rx_we(rpc_fab_rx_we),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[2:0]	state	= 0;
	reg[2:0]	count	= 0;

	reg			rpc_fab_rx_done_buf				= 0;
	
	reg			retransmit						= 0;
	
	always @(posedge clk) begin
	
		rpc_fab_rx_done_buf		<= rpc_fab_rx_done;
		
		case(state)
			
			//IDLE - wait for something to happen
			0: begin
			
				//Should not be sending anything yet.
				assert(rpc_fab_tx_done == 0);
				assert(rpc_fab_rx_en == 0);
				assert(rpc_fab_inbox_full == 0);
				assert(rpc_fab_rx_dst_addr == 0);
				
				//Should be preparing to write to address 0
				assert(rpc_fab_rx_waddr == 0);

				//Value of rx data lines is undefined once rx_done is asserted, so no checks on that
			
				//Reset flags
				count		<= 0;
				retransmit	<= 0;
				
				//Lock in and send header
				if(rpc_fab_tx_en || retransmit) begin
					state							<= 1;
					
					//Should be writing straight to the receive buffer
					assert(rpc_fab_rx_we == 1);
					assert(rpc_fab_rx_wdata == {rpc_fab_tx_src_addr, rpc_fab_tx_dst_addr});
					
				end
				
				//Should not be writing unless we're just starting to send a packet
				else begin
					assert(rpc_fab_rx_we == 0);
					assert(rpc_fab_rx_wdata == 0);
				end
			
			end	//state 0
			
			//Wait for transmit latency
			1: begin
			
				count		<= count + 1;
				
				case(count)
				
					//Data word 1
					0: begin
						
						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_waddr == 1);
						assert(rpc_fab_rx_wdata == {rpc_fab_tx_callnum, rpc_fab_tx_type, rpc_fab_tx_d0});
						
						//Transmit still in progress
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
					end
					
					//Data word 2
					1: begin

						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_waddr == 2);
						assert(rpc_fab_rx_wdata == rpc_fab_tx_d1);
						
						//Transmit still in progress
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
					end
					
					//Data word 3
					2: begin
						
						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_waddr == 3);
						assert(rpc_fab_rx_wdata == rpc_fab_tx_d2);
						
						//Transmit still in progress
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
					end
					
					//Expect packet to arrive
					3: begin
					
						//Should not be writing
						assert(rpc_fab_rx_we == 0);
						assert(rpc_fab_rx_waddr == 0);
						assert(rpc_fab_rx_wdata == 0);
					
						//Transmit done, receive done.
						assert(rpc_fab_tx_done == 1);
						assert(rpc_fab_rx_en == 1);
						assert(rpc_fab_inbox_full == 1);

						//Wait for rx_done
						state	<= 2;
						
					end
				
				endcase
				
			end	//state 1
			
			//Wait for receiver to finish dealing with the packet
			2: begin
				
				//Should be ready to write to start of buffer again
				assert(rpc_fab_rx_waddr == 0);

				//If we're done, go back to the start
				if(rpc_fab_rx_done || rpc_fab_rx_done_buf) begin

					state		<= 0;
					count		<= 0;
					retransmit	<= 0;

				end
				
				//If we get tx_en and the receive buffer is full, we need to block. Handle this separately.
				if(rpc_fab_tx_en) begin
					
					//If we finished the receive LAST cycle, jump right into the transmit cycle
					if(rpc_fab_rx_done_buf) begin
						state <= 1;
						count <= 0;
					end
					
					//No, there's still blocking required.
					else begin
						assert(link_en == 1);
						count <= 1;
						state <= 3;
					end

				end
				
				//Should not be writing unless a new packet is coming
				else begin
					assert(rpc_fab_rx_we == 0);
					assert(rpc_fab_rx_wdata == 0);
				end
				
				//Transmit and receive are both blocking
				assert(rpc_fab_tx_done == 0);
				assert(rpc_fab_rx_en == 0);
				
				//Inbox should be full unless rx_done was asserted combinatorially at the end of state 1
				if(rpc_fab_rx_done_buf)
					assert(rpc_fab_inbox_full == 0);
				else
					assert(rpc_fab_inbox_full == 1);			

			end
			
			//We got a send while the receiver was busy, transmitter is going to block.
			3: begin
				
				//Wait for this transmit cycle to end (it's going to get NAK'd because the rx is blocking)
				count		<= count + 1;
				
				//Should be starting a new transmit
				if(count == 0)
					assert(link_en);
				
				//Inter-frame gap. Prepare to retransmit.
				if(count == 4) begin

					count <= 0;
				
					//If the inbox is now empty, retransmit.
					//If not, go back and wait again
					if(rpc_fab_rx_done || rpc_fab_rx_done_buf || !rpc_fab_inbox_full) begin
						state		<= 0;
						retransmit	<= 1;
					end

				end

			end

		endcase

	end
	
endmodule
