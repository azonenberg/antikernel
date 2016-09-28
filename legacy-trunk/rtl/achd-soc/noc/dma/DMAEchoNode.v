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
	@brief "Ping" style test node for DMA network.
	
	All incoming write request messages are echoed back to the sender as a write request to the same address.
 */
module DMAEchoNode(clk, dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	input wire clk;
	
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	parameter NOC_ADDR = 16'h0000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Transceiver
	
	`include "DMARouter_constants.v"
	
	//DMA transmit signals
	wire dtx_busy;
	reg[15:0] dtx_dst_addr = 0;
	reg[1:0] dtx_op = 0;
	reg[9:0] dtx_len = 0;
	reg[31:0] dtx_addr = 0;
	reg dtx_en = 0;
	wire dtx_rd;
	wire[9:0] dtx_raddr;
	reg[31:0] dtx_buf_out = 0;
	
	//DMA receive signals
	reg drx_ready = 1;
	wire drx_en;
	wire[15:0] drx_src_addr;
	wire[15:0] drx_dst_addr;
	wire[1:0] drx_op;
	wire[31:0] drx_addr;
	wire[9:0] drx_len;	
	reg drx_buf_rd = 0;
	reg[8:0] drx_buf_addr = 0;
	wire[31:0] drx_buf_data;
	
	//DMA transceiver
	DMATransceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(NOC_ADDR)
	) dma_txvr(
		.clk(clk),
		.dma_tx_en(dma_tx_en), .dma_tx_data(dma_tx_data), .dma_tx_ack(dma_tx_ack),
		.dma_rx_en(dma_rx_en), .dma_rx_data(dma_rx_data), .dma_rx_ack(dma_rx_ack),
	
		.tx_done(),
		.tx_busy(dtx_busy), .tx_src_addr(16'h0000), .tx_dst_addr(dtx_dst_addr), .tx_op(dtx_op), .tx_len(dtx_len),
		.tx_addr(dtx_addr), .tx_en(dtx_en), .tx_rd(dtx_rd), .tx_raddr(dtx_raddr), .tx_buf_out(dtx_buf_out),
		
		.rx_ready(drx_ready), .rx_en(drx_en), .rx_src_addr(drx_src_addr), .rx_dst_addr(drx_dst_addr),
		.rx_op(drx_op), .rx_addr(drx_addr), .rx_len(drx_len),
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr), .rx_buf_data(drx_buf_data),
		.rx_buf_rdclk(clk)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transmit buffer
	
	reg[31:0] dtx_buf[511:0];
	
	//Fill buffer to zero by default
	integer i;
	initial begin
		for(i=0; i<512; i = i+1)
			dtx_buf[i] = 0;
	end
	
	//Write to transmit buffer
	reg dtx_we = 0;
	reg[8:0] dtx_buf_addr = 0;
	reg[31:0] dtx_buf_data;
	always @(posedge clk) begin
		if(dtx_we) 
			dtx_buf[dtx_buf_addr] <= dtx_buf_data;
	end
	
	//Read from transmit buffer (by transceiver)
	always @(posedge clk) begin
		if(dtx_rd)
			dtx_buf_out <= dtx_buf[dtx_raddr];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Forwarding logic
	
	localparam STATE_IDLE = 0;
	localparam STATE_COPY_WAIT = 1;
	localparam STATE_COPY_BUFFER = 2;
	localparam STATE_TX_WAIT = 3;
	reg[1:0] state = STATE_IDLE;
	
	always @(posedge clk) begin
		
		dtx_en <= 0;
		dtx_we <= 0;

		case(state)
		
			//Sit around and wait for a DMA write packet to show up
			STATE_IDLE: begin			
				drx_ready <= 1;
				if(drx_en && (drx_op == DMA_OP_WRITE_REQUEST) ) begin
					//Copy the headers over
					dtx_dst_addr <= drx_src_addr;
					dtx_op <= drx_op;
					dtx_len <= drx_len;
					dtx_addr <= drx_addr;
					
					//Pause the receiver and get ready to copy the data
					drx_ready <= 0;
					drx_buf_rd <= 1;
					drx_buf_addr <= 0;
					state <= STATE_COPY_WAIT;
					
					//If packet has no body, skip the copy
					if(drx_len == 0) begin
						dtx_en <= 1;
						state <= STATE_TX_WAIT;
					end
					
				end
			end	//end STATE_IDLE
			
			STATE_COPY_WAIT: begin
				state <= STATE_COPY_BUFFER;
			end	//end STATE_COPY_WAIT
			
			//Copy the data
			//TODO: this takes twice as long as it should, optimize!
			STATE_COPY_BUFFER: begin
			
				//Copy the message body
				dtx_we <= 1;
				dtx_buf_addr <= drx_buf_addr;
				dtx_buf_data <= drx_buf_data;
				
				//See if we're done
				if( (drx_buf_addr + 1) == dtx_len) begin
					dtx_en <= 1;
					state <= STATE_TX_WAIT;
				end
				
				//Read the next word
				else begin
					drx_buf_addr <= drx_buf_addr + 9'h1;
					drx_buf_rd <= 1;
					state <= STATE_COPY_WAIT;
				end
			
			end	//end STATE_COPY_BUFFER
			
			//Wait for transmit to finish
			STATE_TX_WAIT: begin
				if(!dtx_en && !dtx_busy)
					state <= STATE_IDLE;
			end	//end STATE_TX_WAIT
		
		endcase
	end
	
endmodule
