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
	@brief Formal validation test harness for RPCv2RouterTransceiver
	
	The goal of this test is to prove that when a RPCv2RouterTransceiver_transmit talks to a RPCv2RouterTransceiver_receive,
	the packets are always forwarded correctly and unchanged.
 */
module main(
	clk,
	rpc_fab_tx_en, rpc_fab_tx_rdata,
	rpc_fab_rx_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			rpc_fab_tx_en;
	input wire[31:0]	rpc_fab_tx_rdata;
	
	input wire			rpc_fab_rx_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceivers

	//The RPC bus between endpoints
	wire				link_en;
	wire[31:0]			link_data;
	wire[1:0]			link_ack;
	
	wire				rpc_fab_tx_rd_en;
	wire[1:0]			rpc_fab_tx_raddr;
	wire				rpc_fab_tx_done;

	localparam CLIENT_ADDR = 16'h8002;

	RPCv2RouterTransceiver_transmit #(
		.LEAF_PORT(1),
		.LEAF_ADDR(CLIENT_ADDR)
	) txvr (
		.clk(clk),
		
		.rpc_tx_en(link_en),
		.rpc_tx_data(link_data),
		.rpc_tx_ack(link_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_rd_en(rpc_fab_tx_rd_en),
		.rpc_fab_tx_raddr(rpc_fab_tx_raddr),
		.rpc_fab_tx_rdata(rpc_fab_tx_rdata),
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
	
	always @(posedge clk) begin
		
		rpc_fab_rx_done_buf		<= rpc_fab_rx_done;

		case(state)
			
			//IDLE - wait for something to happen
			0: begin
				
				//Should generally not be sending anything yet
				assert(rpc_fab_tx_done == 0);
				assert(rpc_fab_tx_rd_en == 0);
				assert(rpc_fab_tx_raddr == 0);
				
				//Inbox should be empty. There's a once-cycle latency clearing this flag, though.
				if(!rpc_fab_rx_done_buf)
					assert(rpc_fab_inbox_full == 0);
				
				//Should not be writing yet
				assert(rpc_fab_rx_en == 0);
				assert(rpc_fab_rx_we == 0);
				assert(rpc_fab_rx_wdata == 0);
				assert(rpc_fab_rx_waddr == 0);
				assert(rpc_fab_rx_dst_addr == 0);

				//Value of rx data lines is undefined once rx_done is asserted, so no checks on that
			
				//Reset flags
				count		<= 0;
				
				//Prepare to read header
				if(rpc_fab_tx_en)
					state		<= 1;
			
			end	//state 0

			//Wait for transmit latency
			1: begin
			
				count		<= count + 1;
				
				case(count)
				
					//Read routing header
					0: begin
						
						//Not yet sending
						assert(link_en == 0);
						
						//Should be reading
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 0);
						
						//Should not be writing yet
						assert(rpc_fab_inbox_full == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_rx_we == 0);
						assert(rpc_fab_rx_wdata == 0);
						assert(rpc_fab_rx_waddr == 0);
						
					end
					
					//Send routing header, read data word 0
					1: begin
					
						//Starting packet
						assert(link_en == 1);
					
						//Transmit still in progress, not done.
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 1);
						
						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_wdata == {CLIENT_ADDR, rpc_fab_tx_rdata[15:0]});

					end
					
					//Send data word 0, read data word 1
					2: begin
					
						//Packet in progress
						assert(link_en == 0);
					
						//Transmit still in progress, not done.
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 2);
						
						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_waddr == 1);
						assert(rpc_fab_rx_wdata == rpc_fab_tx_rdata);
						
					end
					
					//Send data word 1, read data word 2
					3: begin
						
						//Packet in progress
						assert(link_en == 0);
						
						//Transmit still in progress, not done.
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 3);
						
						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_waddr == 2);
						assert(rpc_fab_rx_wdata == rpc_fab_tx_rdata);
						
					end
					
					//Send data word 2
					4: begin
					
						//Packet in progress
						assert(link_en == 0);
					
						//Transmit still in progress, not done.
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);

						//Should not be reading
						assert(rpc_fab_tx_rd_en == 0);
						assert(rpc_fab_tx_raddr == 0);
						
						//Should be writing straight to the receive buffer
						assert(rpc_fab_rx_we == 1);
						assert(rpc_fab_rx_waddr == 3);
						assert(rpc_fab_rx_wdata == rpc_fab_tx_rdata);
						
					end
					
					//Expect packet to arrive
					5: begin
					
						//Packet in progress
						assert(link_en == 0);
					
						//Should not be writing
						assert(rpc_fab_rx_we == 0);
						assert(rpc_fab_rx_waddr == 0);
						assert(rpc_fab_rx_wdata == 0);
					
						//Should not be reading
						assert(rpc_fab_tx_rd_en == 0);
						assert(rpc_fab_tx_raddr == 0);
					
						//Transmit done, receive done.
						assert(rpc_fab_tx_done == 1);
						assert(rpc_fab_rx_en == 1);
						assert(rpc_fab_inbox_full == 1);

						count <= 0;

						//Can start transmit immediately! Need to handle this
						if(rpc_fab_tx_en) begin
							if(rpc_fab_rx_done)
								state	<= 1;
							else
								state	<= 3;
						end
						
						//Done right now? Reset
						else if(rpc_fab_rx_done)
							state		<= 0;

						//Wait for rx_done
						else
							state		<= 2;

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
				end

				//If we get tx_en and the receive buffer is full, we need to block. Handle this separately.
				if(rpc_fab_tx_en) begin
					
					//If we finished the receive, jump right into the transmit cycle
					if(rpc_fab_rx_done) begin
						state <= 1;
						count <= 0;
					end
					
					//No, there's still blocking required.
					else begin
						count <= 0;
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
				
				if(count == 1)
					assert(link_en);
				else
					assert(link_en == 0);
				
				//Should not be modifying anything
				assert(rpc_fab_rx_we == 0);
				assert(rpc_fab_rx_waddr == 0);
				
				//Wait for this transmit cycle to end (it's going to get NAK'd because the rx is blocking)
				count		<= count + 1;
							
				//Inter-frame gap. Prepare to retransmit.
				if(count == 5) begin
					
					count <= 0;
				
					//If the inbox is now empty, retransmit.
					//If not, go back and wait again
					if(rpc_fab_rx_done || rpc_fab_rx_done_buf || !rpc_fab_inbox_full)
						state		<= 1;

				end
				
				//If we get a "done" flag the first cycle, jump straight into the normal transmit path
				if(rpc_fab_rx_done && (count == 0))
					state <= 1;
				
			end

		endcase

	end
	
endmodule
