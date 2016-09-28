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
	@brief DMA transmitter
 */
module DMATransceiverCore_tx(
	clk,
	dma_tx_en, dma_tx_data, dma_tx_ack,
	tx_done, tx_busy, tx_src_addr, tx_dst_addr, tx_op, tx_addr, tx_len, tx_en, tx_rd, tx_raddr, tx_buf_out
	);
	
	`include "DMARouter_constants.v"
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Single clock
	input wire clk;
	
	//DMA network interface
	output reg dma_tx_en = 0;
	output reg[31:0] dma_tx_data = 0;
	input wire dma_tx_ack;
	
	//Transmit interface to module
	output reg tx_done = 0;
	output reg tx_busy = 0;
	input wire[15:0] tx_src_addr;
	input wire[15:0] tx_dst_addr;
	input wire[1:0] tx_op;
	input wire[31:0] tx_addr;
	input wire[9:0] tx_len;
	input wire tx_en;
	
	//Transmit memory buffer interface (external, referenced to clk)
	output reg tx_rd = 0;
	output reg[9:0] tx_raddr = 0;
	input wire [31:0] tx_buf_out;
	
	parameter LEAF_PORT = 0;
	parameter LEAF_ADDR = 16'h0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit state machine
	
	localparam TX_STATE_IDLE 	= 0;
	localparam TX_STATE_HEADER	= 1;
	localparam TX_STATE_DATA	= 2;
	
	reg[1:0] tx_state = TX_STATE_IDLE;
	always @(posedge clk) begin
	
		dma_tx_en	<= 0;
		tx_rd		<= 0;
		tx_done		<= 0;
	
		case(tx_state)
		
			//Wait for transmit request to come in, then send first and second word
			TX_STATE_IDLE: begin
			
				tx_raddr <= 0;
			
				if(tx_en || tx_busy) begin
					tx_busy <= 1;
					
					//ACKed, send second and continue.
					//Cap length to 512
					if(dma_tx_ack) begin
						if(tx_len > 512)
							dma_tx_data <= {tx_op, 20'h0, 10'd512};
						else
							dma_tx_data <= {tx_op, 20'h0, tx_len};
						tx_state <= TX_STATE_HEADER;
						
						//Prepare to read the first data word
						tx_rd <= 1;
					end
					
					//Not ACKed, send first header word again
					else begin
						dma_tx_en <= 1;
						if(LEAF_PORT)
							dma_tx_data <= {LEAF_ADDR, tx_dst_addr};
						else
							dma_tx_data <= {tx_src_addr, tx_dst_addr};
					end
					
				end				
			end	//end TX_STATE_IDLE

			//Transmit third header word
			TX_STATE_HEADER: begin
				dma_tx_data <= tx_addr;

				tx_rd <= 0;
				tx_raddr <= 1;
				
				//If we're sending a header-only packet, stop now
				if( (tx_len == 0) || (tx_op == DMA_OP_READ_REQUEST)) begin
					tx_state	<= TX_STATE_IDLE;
					tx_done		<= 1;
					tx_busy 	<= 0;
				end
				
				//Prepare to send the first data word. Start reading the second.
				else begin
					if(tx_len != 1)
						tx_rd <= 1;
					tx_state <= TX_STATE_DATA;
				end
			end	//end TX_STATE_HEADER

			//Transmit data
			TX_STATE_DATA: begin

				//Send this word
				dma_tx_data <= tx_buf_out;
				
				//Bump address in preparation for reading the next word
				tx_raddr <= tx_raddr + 10'h1;
				
				//Stop if we just sent the last word
				if(tx_raddr >= tx_len) begin
					tx_state	<= TX_STATE_IDLE;
					tx_done		<= 1;
					tx_busy		<= 0;
				end
				
				//Bump address and read the next word
				else begin
					if( (tx_raddr + 10'h1) < tx_len )
						tx_rd <= 1;
				end
				
			end	//end TX_STATE_DATA
				
		endcase
	end
		
endmodule

