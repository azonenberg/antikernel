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
	@brief Formal validation test harness for RPCv2Transceiver
	
	The goal of this test is to prove that when a RPCv2RouterTransceiver_transmit talks to a RPCv2Transceiver_receive,
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
	wire		link_en;
	wire[31:0]	link_data;
	wire[1:0]	link_ack;
	
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
	
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	wire		rpc_fab_rx_done;
	wire		rpc_fab_inbox_full;
	
	RPCv2Transceiver_receive rx(
		.clk(clk),
		
		.rpc_rx_en(link_en),
		.rpc_rx_data(link_data),
		.rpc_rx_ack(link_ack),
		
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[1:0]	state	= 0;
	reg[2:0]	count	= 0;
	
	reg[15:0]	rpc_fab_rx_dst_addr_expected	= 0;
	reg[7:0]	rpc_fab_rx_callnum_expected		= 0;
	reg[2:0]	rpc_fab_rx_type_expected		= 0;
	reg[20:0]	rpc_fab_rx_d0_expected			= 0;
	reg[31:0]	rpc_fab_rx_d1_expected			= 0;
	reg[31:0]	rpc_fab_rx_d2_expected			= 0;
	
	reg			rpc_fab_rx_done_buf				= 0;
	
	always @(posedge clk) begin
	
		rpc_fab_rx_done_buf		<= rpc_fab_rx_done;
		
		case(state)
			
			//IDLE - wait for something to happen
			0: begin
			
				//Should not be sending anything yet.
				assert(rpc_fab_tx_done == 0);
				assert(rpc_fab_rx_en == 0);
				assert(rpc_fab_inbox_full == 0);
				
				//Should not be reading yet
				assert(rpc_fab_tx_rd_en == 0);
				assert(rpc_fab_tx_raddr == 0);

				//Value of rx data lines is undefined once rx_done is asserted, so no checks on that
			
				//Reset flags
				count		<= 0;
				
				//Get ready to send header
				if(rpc_fab_tx_en)
					state			<= 1;
			
			end	//state 0

			//Wait for transmit latency
			1: begin
			
				count		<= count + 1;
				
				case(count)
				
					//Read routing header
					0: begin
										
						//Transmit still in progress, not done. Output data lines undefined
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 0);
						
					end
					
					//Send routing header, read data word 0
					1: begin
					
						rpc_fab_rx_dst_addr_expected	<= rpc_fab_tx_rdata[15:0];					
						
						//Transmit still in progress, not done. Output data lines undefined
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 1);
						
					end
					
					//Send data word 0, read data word 1
					2: begin
					
						rpc_fab_rx_callnum_expected	<= rpc_fab_tx_rdata[31:24];
						rpc_fab_rx_type_expected	<= rpc_fab_tx_rdata[23:21];
						rpc_fab_rx_d0_expected		<= rpc_fab_tx_rdata[20:0];
						
						//Transmit still in progress, not done. Output data lines undefined
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 2);
						
					end
					
					//Send data word 1, read data word 2
					3: begin

						rpc_fab_rx_d1_expected		<= rpc_fab_tx_rdata;
						
						//Transmit still in progress, not done. Output data lines undefined
						assert(rpc_fab_tx_done == 0);
						assert(rpc_fab_rx_en == 0);
						assert(rpc_fab_inbox_full == 0);
						
						//Should be reading
						assert(rpc_fab_tx_rd_en == 1);
						assert(rpc_fab_tx_raddr == 3);
						
					end
					
					//Send data word 2
					4: begin
						rpc_fab_rx_d2_expected		<= rpc_fab_tx_rdata;
						
						//Should not be reading
						assert(rpc_fab_tx_rd_en == 0);
						assert(rpc_fab_tx_raddr == 0);
						
					end
										
					//Expect packet to arrive
					5: begin
					
						//Should not be reading
						assert(rpc_fab_tx_rd_en == 0);
						assert(rpc_fab_tx_raddr == 0);
					
						//Transmit done, receive done.
						assert(rpc_fab_tx_done == 1);
						assert(rpc_fab_rx_en == 1);
						assert(rpc_fab_inbox_full == 1);
						
						//Data lines should be valid
						assert(rpc_fab_rx_src_addr == CLIENT_ADDR);
						assert(rpc_fab_rx_dst_addr == rpc_fab_rx_dst_addr_expected);
						assert(rpc_fab_rx_callnum == rpc_fab_rx_callnum_expected);
						assert(rpc_fab_rx_type == rpc_fab_rx_type_expected);
						assert(rpc_fab_rx_d0 == rpc_fab_rx_d0_expected);
						assert(rpc_fab_rx_d1 == rpc_fab_rx_d1_expected);
						assert(rpc_fab_rx_d2 == rpc_fab_rx_d2_expected);
						
						//Wait for rx_done
						state	<= 2;
						count	<= 0;
						
						//Can start transmit immediately! Need to handle this
						if(rpc_fab_tx_en) begin
							if(rpc_fab_rx_done)
								state <= 1;
							else
								state <= 3;
						end
						
					end

				endcase
				
			end	//state 1
			
			//Wait for receiver to finish dealing with the packet
			2: begin
				
				//If we're done, go back to the start
				if(rpc_fab_rx_done || rpc_fab_rx_done_buf)
					state		<= 0;
				
				//If we get tx_en and the receive buffer is full, we need to block. Handle this separately.
				if(rpc_fab_tx_en) begin

					//If we finished the receive already, jump right into the transmit cycle
					if(rpc_fab_rx_done_buf || rpc_fab_rx_done)
						state <= 1;
						
					//No, there's still blocking required.
					else
						state <= 3;
						
				end
				
				//Transmit and receive are both blocking
				assert(rpc_fab_tx_done == 0);
				assert(rpc_fab_rx_en == 0);
				
				//Inbox should be full unless rx_done was asserted combinatorially at the end of state 1
				if(rpc_fab_rx_done_buf)
					assert(rpc_fab_inbox_full == 0);
				else
					assert(rpc_fab_inbox_full == 1);

				//Data lines should be valid
				assert(rpc_fab_rx_src_addr == CLIENT_ADDR);
				assert(rpc_fab_rx_dst_addr == rpc_fab_rx_dst_addr_expected);
				assert(rpc_fab_rx_callnum == rpc_fab_rx_callnum_expected);
				assert(rpc_fab_rx_type == rpc_fab_rx_type_expected);
				assert(rpc_fab_rx_d0 == rpc_fab_rx_d0_expected);
				assert(rpc_fab_rx_d1 == rpc_fab_rx_d1_expected);
				assert(rpc_fab_rx_d2 == rpc_fab_rx_d2_expected);

			end	//state 2
			
			//We got a send while the receiver was busy, transmitter is going to block.
			3: begin
				
				//If inbox hasn't been flushed yet, data lines should still be valid
				if(rpc_fab_inbox_full) begin
				
					//Data lines should be valid
					assert(rpc_fab_rx_src_addr == CLIENT_ADDR);
					assert(rpc_fab_rx_dst_addr == rpc_fab_rx_dst_addr_expected);
					assert(rpc_fab_rx_callnum == rpc_fab_rx_callnum_expected);
					assert(rpc_fab_rx_type == rpc_fab_rx_type_expected);
					assert(rpc_fab_rx_d0 == rpc_fab_rx_d0_expected);
					assert(rpc_fab_rx_d1 == rpc_fab_rx_d1_expected);
					assert(rpc_fab_rx_d2 == rpc_fab_rx_d2_expected);
					
				end
				
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
				
				//If we get a "done" signal on the first cycle of the transmit, we're not going to get a NAK.
				//Jump back to the normal transmit path.
				if( (count == 0) && rpc_fab_rx_done )
					state <= 1;

			end	//state 3

		endcase

	end
	
endmodule
