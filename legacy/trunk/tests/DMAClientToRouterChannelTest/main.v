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
	@brief Formal validation test harness for DMATransceiver and DMARouterTransceiver
	
	The goal of this test is to prove that when a DMATransceiver talks to a DMARouterTransceiver
	the packets are always forwarded correctly and unchanged.
 */
module main(
	clk,
	tx_src_addr, tx_dst_addr, tx_op, tx_addr, tx_len, tx_en, tx_buf_out,
	rx_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire[15:0]	tx_src_addr;
	input wire[15:0]	tx_dst_addr;
	input wire[1:0]		tx_op;
	input wire[31:0]	tx_addr;
	input wire[9:0]		tx_len;
	input wire			tx_en;
	input wire[31:0]	tx_buf_out;
	
	input wire			rx_done;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceivers
	
	//The DMA bus between endpoints
	wire		link_en;
	wire[31:0]	link_data;
	wire		link_ack;

	//Transmit status flags
	wire		tx_done;
	wire		tx_busy;
	wire		tx_rd;
	wire[9:0]	tx_raddr;
	
	//Receiver outputs
	wire		rx_en;
	wire		rx_inbox_full;
	wire		rx_inbox_full_cts;
	wire[15:0]	rx_dst_addr;

	//Memory interfaces
	wire		header_wr_en;
	wire[1:0]	header_wr_addr;
	wire[31:0]	header_wr_data;
	wire		data_wr_en;
	wire[8:0]	data_wr_addr;
	wire[31:0]	data_wr_data;
	
	DMATransceiverCore_tx #(
		.LEAF_PORT(1),
		.LEAF_ADDR(16'h8001)
	) core_tx (
		.clk(clk),
		.dma_tx_en(link_en),
		.dma_tx_data(link_data),
		.dma_tx_ack(link_ack),
		.tx_done(tx_done),
		.tx_busy(tx_busy),
		.tx_src_addr(tx_src_addr),
		.tx_dst_addr(tx_dst_addr),
		.tx_op(tx_op),
		.tx_addr(tx_addr),
		.tx_len(tx_len),
		.tx_en(tx_en),
		.tx_rd(tx_rd),
		.tx_raddr(tx_raddr),
		.tx_buf_out(tx_buf_out)
	);

	DMARouterTransceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(16'h8001)
	) router_txvr (
		.clk(clk),
		
		.dma_tx_en(),
		.dma_tx_data(),
		.dma_tx_ack(1'b0),
		.dma_rx_en(link_en),
		.dma_rx_data(link_data),
		.dma_rx_ack(link_ack),
		
		.tx_en(1'b0),
		.tx_done(),
		.rx_en(rx_en),
		.rx_done(rx_done),
		.rx_inbox_full(rx_inbox_full),
		.rx_inbox_full_cts(rx_inbox_full_cts),
		.rx_dst_addr(rx_dst_addr),
		
		.header_wr_en(header_wr_en),
		.header_wr_addr(header_wr_addr),
		.header_wr_data(header_wr_data),
		.header_rd_en(),
		.header_rd_addr(),
		.header_rd_data(32'h0), 
		.data_wr_en(data_wr_en),
		.data_wr_addr(data_wr_addr),
		.data_wr_data(data_wr_data),
		.data_rd_en(),
		.data_rd_addr(),
		.data_rd_data(32'h0)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Hang logic
	
	// No transmit verification since DMAClientToClientChannelTest does that
	
	`include "DMARouter_constants.v"

	reg[5:0]	count	= 0;
	reg			hang	= 0;
	
	always @(posedge clk) begin

		if(!hang) begin
		
			//Limit the proof to 64 cycles in length for now
			count	<= count + 1;
			if(count == 63)
				hang	<= 1;
		
		end

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive verification logic
	
	reg[2:0]	rxstate = 0;
	
	reg[31:0]	link_data_ff	 		= 0;
	reg[15:0]	rx_dst_addr_expected	= 0;
	reg[9:0]	packet_len				= 0;
	reg[8:0]	data_wr_addr_ff			= 0;
		
	reg			rx_packet_empty			= 0;
	
	wire[8:0]	data_wr_addr_ff_inc		= data_wr_addr_ff + 1;

	always @(posedge clk) begin
	
		if(hang) begin
			
		end
		
		else begin
			
			link_data_ff	<= link_data;
			data_wr_addr_ff	<= data_wr_addr;
			
			//We shouldn't ACK transmissions unless they were actually sent, and we're ready for them.
			//Should not be ACKing except when idle.
			if(link_ack) begin
				assert(link_en == 1);
				//assert(rxstate == 0);
			end
			
			case(rxstate)
				
				//Idle, wait for a new packet to arrive
				0: begin
				
					//Not receiving so everything should be idle
					assert(rx_en == 0);
					assert(rx_inbox_full == 0);
					assert(rx_inbox_full_cts == 0);
					assert(header_wr_en == 0);
					assert(header_wr_addr == 0);
					assert(header_wr_data == 0);
					assert(data_wr_en == 0);
					assert(data_wr_addr == 0);
					assert(data_wr_data == 0);
					
					//If a transmit was acknowledged, we get the routing header next cycle
					if(link_ack) begin
						rxstate		<= 1;
						rx_dst_addr_expected	<=	link_data[15:0];
					end
					
				end
				
				//Routing header
				1: begin
					
					//Valid dest addr required
					assert(rx_dst_addr == rx_dst_addr_expected);
					
					//Not done yet
					assert(rx_en == 0);
					assert(rx_inbox_full == 0);
					assert(rx_inbox_full_cts == 1);
					
					//Should be writing to header
					assert(header_wr_en == 1);
					assert(header_wr_addr == 0);
					assert(header_wr_data == link_data_ff);
					
					//Should not be writing to data
					assert(data_wr_en == 0);
					assert(data_wr_addr == 0);
					assert(data_wr_data == 0);
					
					//Save packet length
					packet_len		<= link_data[9:0];
					rx_packet_empty	<= 0;
					if( (link_data[31:30] == DMA_OP_READ_REQUEST) || (link_data[9:0] == 0) ) begin
						packet_len		<= 0;
						rx_packet_empty	<= 1;
					end
						
					//Drop the packet if length is invalid
					if(link_data[9:0] > 512)
						rxstate		<= 0;
					
					//Well formed, time for the next header word
					else
						rxstate	<= 2;
					
				end
				
				//Opcode header
				2: begin
				
					//Message is now in flight
					assert(rx_inbox_full_cts == 1);

					//Valid dest addr required
					assert(rx_dst_addr == rx_dst_addr_expected);
					
					//Not done yet
					assert(rx_en == 0);
					assert(rx_inbox_full == 0);
					
					//Should be writing to header
					assert(header_wr_en == 1);
					assert(header_wr_addr == 1);
					assert(header_wr_data == link_data_ff);
					
					//Should not be writing to data
					assert(data_wr_en == 0);
					assert(data_wr_addr == 0);
					assert(data_wr_data == 0);
					
					rxstate	<= 3;
				
				end
				
				//Address header
				3: begin
				
					//Valid dest addr required
					assert(rx_dst_addr == rx_dst_addr_expected);
					
					//Should be writing to header
					assert(header_wr_en == 1);
					assert(header_wr_addr == 2);
					assert(header_wr_data == link_data_ff);
					
					//Should not be writing to data
					assert(data_wr_en == 0);
					assert(data_wr_addr == 0);
					assert(data_wr_data == 0);
					
					//Clear out address so addr_ff+1 will overflow to zero
					data_wr_addr_ff		<= 511;
					
					//If packet is empty, we're done
					if(rx_packet_empty) begin
						assert(rx_inbox_full == 1);
						assert(rx_inbox_full_cts == 1);
						assert(rx_en == 1);
						rxstate	<= 6;
					end
					
					//Not done yet, get data
					else begin
						assert(rx_en == 0);
						assert(rx_inbox_full == 0);
						assert(rx_inbox_full_cts == 1);
						rxstate	<= 4;
					end
				
				end
				
				//Data
				4: begin
					
					//Valid dest addr required
					assert(rx_dst_addr == rx_dst_addr_expected);
				
					//Should be writing to data
					assert(data_wr_en == 1);
					assert(data_wr_addr == data_wr_addr_ff_inc);
					assert(data_wr_data == link_data_ff);
					
					//Should not be writing to header
					assert(header_wr_en == 0);
					assert(header_wr_addr == 0);
					assert(header_wr_data == 0);
					
					//If we just wrote the last word, we're done
					if( (data_wr_addr + 1) >= packet_len)
						rxstate	<= 5;
					
					assert(rx_en == 0);
					assert(rx_inbox_full == 0);
					assert(rx_inbox_full_cts == 1);
					
				end
				
				//Done flag
				5: begin
					assert(rx_en == 1);
					assert(rx_inbox_full == 1);
					assert(rx_inbox_full_cts == 1);
					rxstate	<= 6;
				end
				
				//Message is done, wait for done flag
				6: begin
				
					//Valid dest addr required
					assert(rx_dst_addr == rx_dst_addr_expected);
				
					//Everything should be idle except inbox state
					assert(rx_en == 0);
					assert(header_wr_en == 0);
					assert(header_wr_addr == 0);
					assert(header_wr_data == 0);
					assert(data_wr_en == 0);
					assert(data_wr_addr == 0);
					assert(data_wr_data == 0);
				
					//Check if we're done
					if(rx_done) begin
						assert(rx_inbox_full == 0);
						assert(rx_inbox_full_cts == 0);
						rxstate	<= 0;
					end
					
					//Nope, inbox still full
					else begin
						assert(rx_inbox_full == 1);
						assert(rx_inbox_full_cts == 1);
					end
						
				end
				
			endcase
			
		end
	
	end
	
endmodule
