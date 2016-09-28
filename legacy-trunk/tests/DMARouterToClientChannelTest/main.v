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
	
	The goal of this test is to prove that when a DMARouterTransceiver talks to a DMATransceiverCore_rx
	the packets are always forwarded correctly and unchanged.
 */
module main(
	clk,
	tx_en, header_rd_data, data_rd_data,
	rx_ready
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			tx_en;
	input wire[31:0]	header_rd_data;
	input wire[31:0]	data_rd_data;

	input wire			rx_ready;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceivers
	
	//The DMA bus between endpoints
	wire		link_en;
	wire[31:0]	link_data;
	wire		link_ack;
	
	//Transmit outputs
	wire		tx_done;
	
	//Memory interfaces
	wire		header_rd_en;
	wire[1:0]	header_rd_addr;
	wire		data_rd_en;
	wire[8:0]	data_rd_addr;
	
	DMARouterTransceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(16'h8001)
	) txvr (
		.clk(clk),
		
		.dma_tx_en(link_en),
		.dma_tx_data(link_data),
		.dma_tx_ack(link_ack),
		.dma_rx_en(1'b0),
		.dma_rx_data(32'h0),
		.dma_rx_ack(),
		
		.tx_en(tx_en),
		.tx_done(tx_done),
		.rx_en(),
		.rx_done(1'b1),
		.rx_inbox_full(),
		.rx_inbox_full_cts(),
		.rx_dst_addr(),
		
		.header_wr_en(),
		.header_wr_addr(),
		.header_wr_data(),
		.header_rd_en(header_rd_en),
		.header_rd_addr(header_rd_addr),
		.header_rd_data(header_rd_data), 
		.data_wr_en(),
		.data_wr_addr(),
		.data_wr_data(),
		.data_rd_en(data_rd_en),
		.data_rd_addr(data_rd_addr),
		.data_rd_data(data_rd_data)
	);
	
	//Receive status flags
	wire		rx_en;
	wire[15:0]	rx_src_addr;
	wire[15:0]	rx_dst_addr;
	wire[1:0]	rx_op;
	wire[31:0]	rx_addr;
	wire[9:0]	rx_len;
	wire		rx_we;
	wire[8:0]	rx_buf_waddr;
	wire[31:0]	rx_buf_wdata;
	wire		rx_state_header_2;
	DMATransceiverCore_rx rx (
		.clk(clk),
		.dma_rx_en(link_en),
		.dma_rx_data(link_data),
		.dma_rx_ack(link_ack),
		.rx_ready(rx_ready),
		.rx_en(rx_en),
		.rx_src_addr(rx_src_addr),
		.rx_dst_addr(rx_dst_addr),
		.rx_op(rx_op),
		.rx_addr(rx_addr),
		.rx_len(rx_len),
		.rx_we(rx_we),
		.rx_buf_waddr(rx_buf_waddr),
		.rx_buf_wdata(rx_buf_wdata),
		.rx_state_header_2(rx_state_header_2)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Hang logic
	
	// No transmit verification since DMARouterToRouterChannelTest does that
	
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
	
	reg[31:0]	header_rd_data_ff		= 0;
	reg[31:0]	header_rd_data_ff2		= 0;
	reg[15:0]	rx_dst_addr_expected	= 0;
	reg[1:0]	rx_op_expected			= 0;
	reg[9:0]	rx_len_expected			= 0;
	reg[31:0]	rx_addr_expected		= 0;
	
	reg			rx_ready_ff				= 0;
	reg[31:0]	rx_buf_wdata_expected	= 0;
	reg[9:0]	rx_buf_waddr_ff			= 0;
	
	wire[9:0]	rx_buf_waddr_ff_inc		= rx_buf_waddr_ff + 1;
	
	reg			link_en_ff				= 0;

	always @(posedge clk) begin
	
		if(hang) begin
			
		end
		
		else begin
		
			assert(rx_buf_wdata == link_data);
			
			rx_ready_ff	<= 1;
			
			link_en_ff	<= link_en;
			
			header_rd_data_ff		<= header_rd_data;
			
			//We shouldn't ACK transmissions unless they were actually sent, and we're ready for them.
			//Should not be ACKing except when idle.
			if(link_ack) begin
				assert(link_en == 1);
				assert(rx_ready_ff == 1);
				assert(rxstate == 0);
			end
			
			case(rxstate)
				
				//Idle, wait for a new packet to arrive
				0: begin
					
					//Keep track of what the transmit address should be
					if(link_en && !link_en_ff)
						rx_dst_addr_expected		<= header_rd_data_ff[15:0];
				
					//Idle, nothing going on
					//Can't make any assumptions about the header outputs since those hold values from the last message
					//rx_buf_waddr will be freely counting

					assert(rx_en == 0);
					assert(rx_we == 0);
					
					//If a transmit was acknowledged, we get the routing header next cycle
					if(link_ack)
						rxstate	<= 1;
					
				end
				
				//Routing header
				1: begin
					
					assert(rx_dst_addr == rx_dst_addr_expected);
					assert(rx_src_addr == 16'h8001);
					
					//Should not be writing to data memory yet, or done receiving
					assert(rx_en == 0);
					assert(rx_we == 0);
					
					//Push expected opcode header down the pipeline
					rx_op_expected				<= header_rd_data_ff[31:30];
					rx_len_expected				<= header_rd_data_ff[9:0];
					
					rxstate	<= 2;
				end
				
				//Opcode header
				2: begin
				
					//Address should still be valid
					assert(rx_dst_addr == rx_dst_addr_expected);
					assert(rx_src_addr == 16'h8001);
					
					//but now opcode should be valid too
					assert(rx_op == rx_op_expected);
					assert(rx_len == rx_len_expected);
					
					//Should not be writing to data memory yet, or done receiving
					assert(rx_en == 0);
					assert(rx_we == 0);
					
					//Push expected address header down the pipeline
					rx_addr_expected			<= header_rd_data_ff;
					
					//Drop the packet if the length is invalid
					if(rx_len > 512)
						rxstate	<= 0;
						
					//Nope, keep going
					else
						rxstate <= 3;
				end
				
				//Address header
				3: begin
					
					//Address and opcode should still be valid
					assert(rx_dst_addr == rx_dst_addr_expected);
					assert(rx_src_addr == 16'h8001);
					assert(rx_op == rx_op_expected);
					assert(rx_len == rx_len_expected);
					
					//as well as address
					assert(rx_addr == rx_addr_expected);
					
					rx_buf_waddr_ff	<= 0;
					
					//If we are sending a header-only packet, we're done
					if( (rx_len == 0) || (rx_op == DMA_OP_READ_REQUEST) ) begin
						assert(rx_en == 1);
						assert(rx_we == 0);
						rxstate	<= 0;
					end
					
					//If we have data, write the 0th word
					else begin
						assert(rx_en == 0);
						assert(rx_buf_waddr == 0);
						assert(rx_we == 1);
						rxstate	<= 4;
					end
					
				end
				
				//Data, if any
				4: begin
				
					//should be incrementing counter
					rx_buf_waddr_ff	<= rx_buf_waddr;
					assert(rx_buf_waddr_ff_inc == rx_buf_waddr);
					
					//If we wrote the last word LAST cycle, then THIS cycle is done
					if(rx_buf_waddr_ff_inc == rx_len) begin
						assert(rx_en == 1);
						assert(rx_we == 0);
						rxstate	<= 0;
					end
					
					//Nope, not done yet.
					//Should be writing
					else begin
						assert(rx_en == 0);
						assert(rx_we == 1);
					end
				
				end
				
			endcase
			
		end
	
	end
	
	
endmodule
