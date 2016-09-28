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
	@brief DMA receiver
 */
module DMATransceiverCore_rx(
	clk,
	dma_rx_en, dma_rx_data, dma_rx_ack,
	rx_ready, rx_en, rx_src_addr, rx_dst_addr, rx_op, rx_addr, rx_len, rx_we, rx_buf_waddr, rx_buf_wdata,
	rx_state_header_2
	);
	
	`include "DMARouter_constants.v"
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Single clock
	input wire clk;
	
	//DMA network interface
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output reg dma_rx_ack = 0;
	
	//Receive interface to module
	input wire rx_ready;
	output reg rx_en = 0;
	output reg[15:0] rx_src_addr = 0;
	output reg[15:0] rx_dst_addr = 0;
	output reg[1:0] rx_op = 0;
	output reg[31:0] rx_addr = 0;
	output reg[9:0] rx_len = 0;
	
	output reg rx_we = 0;
	output reg[8:0] rx_buf_waddr = 0;
	output wire[31:0] rx_buf_wdata;
	assign rx_buf_wdata = dma_rx_data;
	
	output wire rx_state_header_2;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit state machine
	
	localparam RX_STATE_IDLE 		= 0;
	localparam RX_STATE_HEADER_1	= 1;
	localparam RX_STATE_HEADER_2	= 2;
	localparam RX_STATE_DATA		= 3;
	reg[1:0] rx_state = RX_STATE_IDLE;
	
	assign rx_state_header_2 = (rx_state == RX_STATE_HEADER_2);
	
	reg[9:0] rx_count = 0;
	always @(*) begin
		rx_we <= (rx_state == RX_STATE_DATA);
		rx_buf_waddr <= rx_count[8:0] - 9'h1;
	end
	
	always @(posedge clk) begin
	
		dma_rx_ack <= 0;
		rx_en <= 0;
	
		//rx_count is the number of words received as of this cycle (1 for the first word, etc).
		//Freely counts when not receiving.
		rx_count <= rx_count + 10'h1;
	
		case(rx_state)
			
			//Wait for receive request to come in
			RX_STATE_IDLE: begin
				
				//Acknowledge receive requests.
				//Do not ACK if an ACK was sent last cycle.
				if(dma_rx_en) begin
					if(rx_ready && !rx_en && !dma_rx_ack)
						dma_rx_ack <= 1;
				end
				
				//If ACKing, save header info
				if(dma_rx_ack) begin
					rx_src_addr <= dma_rx_data[31:16];
					rx_dst_addr <= dma_rx_data[15:0];
					rx_state <= RX_STATE_HEADER_1;
				end
				
			end	//end RX_STATE_IDLE
			
			//Read headers
			RX_STATE_HEADER_1: begin
			
				//Reset stuff and get ready for data payload
				rx_count <= 0;
				rx_op <= dma_rx_data[31:30];
				rx_len <= dma_rx_data[9:0];
				
				//Drop packets with invalid length
				if(dma_rx_data[9:0] > 512)
					rx_state <= RX_STATE_IDLE;
				else
					rx_state <= RX_STATE_HEADER_2;
			
			end	//end RX_STATE_HEADER_1
			
			RX_STATE_HEADER_2: begin
				rx_addr <= dma_rx_data;
				
				//Stop now if it's a header-only packet
				if( (rx_len == 0) || (rx_op == DMA_OP_READ_REQUEST)) begin
					rx_en <= 1;
					rx_state <= RX_STATE_IDLE;
				end
				
				//Prepare to read data payload
				else
					rx_state <= RX_STATE_DATA;
				
			end	//end RX_STATE_HEADER_2
			
			//Read data
			RX_STATE_DATA: begin
				
				//Stop if we just read the last word
				if(rx_count == rx_len) begin
					rx_en <= 1;
					rx_state <= RX_STATE_IDLE;
				end
			end
			
		endcase
	end
		
endmodule

