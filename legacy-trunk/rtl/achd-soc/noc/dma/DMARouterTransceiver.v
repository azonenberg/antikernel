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
	@brief Transceiver for DMA network with router interface
 */
module DMARouterTransceiver(
	clk,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	tx_en, tx_done,
	rx_en, rx_done, rx_inbox_full, rx_dst_addr, rx_inbox_full_cts,
	
	header_wr_en, header_wr_addr, header_wr_data, header_rd_en, header_rd_addr, header_rd_data, 
	data_wr_en, data_wr_addr, data_wr_data, data_rd_en, data_rd_addr, data_rd_data
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Single clock
	input wire clk;
	
	//DMA network interface
	output reg			dma_tx_en			= 0;
	output reg[31:0]	dma_tx_data			= 0;
	input wire			dma_tx_ack;
	input wire			dma_rx_en;
	input wire[31:0]	dma_rx_data;
	output reg			dma_rx_ack			= 0;
	
	//Transmit interface
	input wire			tx_en;
	output reg			tx_done				= 0;
	
	//Receive interface
	output reg			rx_en				= 0;
	input wire			rx_done;
	output reg			rx_inbox_full		= 0;
	output reg			rx_inbox_full_cts	= 0;	//Cut-through switching flag
													//asserted as soon as first word is read
	output reg[15:0]	rx_dst_addr			= 0;
	
	//Header memory interface
	output reg			header_wr_en		= 0;
	output reg[1:0]		header_wr_addr		= 0;
	output reg[31:0]	header_wr_data		= 0;
	output reg			header_rd_en		= 0;
	output reg[1:0]		header_rd_addr		= 0;
	input wire[31:0]	header_rd_data;
	
	//Data memory
	output reg			data_wr_en			= 0;
	output reg[8:0]		data_wr_addr		= 0;
	output reg[31:0]	data_wr_data		= 0;
	output reg			data_rd_en			= 0;
	output reg[8:0]		data_rd_addr		= 0;
	input wire[31:0]	data_rd_data;
	
	parameter LEAF_PORT = 0;
	parameter LEAF_ADDR = 16'h0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmitter
	
	localparam TX_STATE_IDLE 	= 0;
	localparam TX_STATE_HEADER	= 1;
	localparam TX_STATE_DATA	= 2;
	localparam TX_STATE_LAST	= 3;
	
	reg[2:0]			tx_state			= TX_STATE_IDLE;
	
	always @(*) begin
	
		//Start reading headers immediately upon asserting send
		header_rd_en	<= (tx_state == TX_STATE_HEADER) || ( (tx_state == TX_STATE_IDLE) && tx_en && !tx_done);
		data_rd_en		<= (tx_state == TX_STATE_DATA) || (tx_state == TX_STATE_LAST);
		
	end
	
	`include "DMARouter_constants.v"

	reg[9:0]	tx_packet_len		= 0;
	reg			acked				= 0;
	
	//Compute read address
	reg[1:0]	header_rd_addr_ff	= 0;
	always @(*) begin
		if(tx_state == TX_STATE_HEADER) begin
			if(acked || dma_tx_ack || !dma_tx_en)
				header_rd_addr	<= header_rd_addr_ff + 2'h1;
			else
				header_rd_addr	<= header_rd_addr_ff;
		end
		else
			header_rd_addr	<= 0;
		
	end
	
	//Save packet header
	reg[31:0]	saved_header		= 0;
	
	always @(posedge clk) begin
		
		dma_tx_en			<= 0;
		tx_done				<= 0;
		
		header_rd_addr_ff	<= header_rd_addr;
		
		//Transmit data is muxed down from one ram or the other
		//Don't use second register in block RAM, by doing this mux in LUTs we can sneak a little bit more this cycle
		//and leave the output fully registered for better routing
		if( (tx_state == TX_STATE_HEADER) || ((tx_state == TX_STATE_DATA) && (data_rd_addr == 0)) ) begin
			if(acked || dma_tx_ack)
				dma_tx_data		<= header_rd_data;
			else
				dma_tx_data		<= saved_header;
			if( LEAF_PORT && (tx_state == TX_STATE_HEADER) && (header_rd_addr == 1) )
				dma_tx_data[31:16] <= LEAF_ADDR;
		end
		else if( (tx_state == TX_STATE_DATA) || (tx_state == TX_STATE_LAST) )
			dma_tx_data		<= data_rd_data;
		else
			dma_tx_data		<= 0;
		
		case(tx_state)
			
			//Idle? Wait for a send
			TX_STATE_IDLE: begin
				
				//Read is dispatched combinatorially, so bump address for next read
				//Starting a new packet while the last one is still being finished is illegal
				if(tx_en && !tx_done) begin
					acked			<= 0;
					data_rd_addr	<= 0;
					tx_state		<= TX_STATE_HEADER;
				end
				
			end
			
			//Reading headers? Send them and continue
			TX_STATE_HEADER: begin
				
				if(!acked && !dma_tx_ack)
					dma_tx_en		<= 1;
					
				if(!dma_tx_en)
					saved_header	<= header_rd_data;
				
				//Go on to the next word if we got an ACK
				if(dma_tx_ack)
					acked			<= 1;
				
				//Data is ready? Request a transmit
				if(header_rd_addr == 1)
					dma_tx_en		<= 1;
				
				//Move to data when we finish the header
				if(header_rd_addr == 2) begin
				
					//If it's a read request, actual data length is always zero
					if(header_rd_data[31:30] == DMA_OP_READ_REQUEST)
						tx_packet_len	<= 0;
							
					//No, cap to 512
					else if(header_rd_data[9:0] > 512)
						tx_packet_len	<= 512;
					else
						tx_packet_len	<= header_rd_data[9:0];

					tx_state		<= TX_STATE_DATA;
				end
					
			end
			
			//Reading data?
			TX_STATE_DATA: begin
			
				//Go on to the next word
				data_rd_addr		<= data_rd_addr + 1'h1;
			
				//If we just read the last word, stop.
				if(data_rd_addr == tx_packet_len) begin
					tx_state	<= TX_STATE_IDLE;
					tx_done		<= 1;
				end
				
				//If we're about to overflow, wait one more cycle
				if(data_rd_addr == 511)
					tx_state	<= TX_STATE_LAST;

			end
			
			TX_STATE_LAST: begin
				tx_state	<= TX_STATE_IDLE;
				tx_done		<= 1;
			end
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receiver
	
	localparam RX_STATE_IDLE 		= 0;
	localparam RX_STATE_HEADER		= 1;
	localparam RX_STATE_DATA		= 2;
	localparam RX_STATE_WAIT		= 3;
	
	reg[1:0] rx_state			= RX_STATE_IDLE;
	reg[9:0] rx_packet_len		= 0;
	
	//ignore rx_done during rx_en cycle
	always @(*) begin
		rx_inbox_full		<= ((rx_state == RX_STATE_WAIT) && !rx_done) || rx_en;
		rx_inbox_full_cts	<= (
									(rx_state == RX_STATE_HEADER) || 
									(rx_state == RX_STATE_DATA) || 
									( (rx_state == RX_STATE_WAIT) && !rx_done )
								) || rx_en;
	end
	
	always @(posedge clk) begin
		
		dma_rx_ack		<= 0;
		
		header_wr_en	<= 0;
		header_wr_addr	<= 0;
		header_wr_data	<= 0;
		
		data_wr_en		<= 0;
		data_wr_addr	<= 0;
		data_wr_data	<= 0;
		
		rx_en			<= 0;
		
		case(rx_state)
		
			//When a new request comes in, acknowledge and write header to buffer
			RX_STATE_IDLE: begin
				
				if(dma_rx_en && !dma_rx_ack)
					dma_rx_ack		<= 1;
				
				if(dma_rx_ack) begin
					header_wr_addr		<= 0;
					header_wr_en		<= 1;
					header_wr_data		<= dma_rx_data;
					rx_dst_addr			<= dma_rx_data[15:0];
					rx_state			<= RX_STATE_HEADER;
				end
				
			end
			
			//Receive header words
			RX_STATE_HEADER: begin
				
				header_wr_en		<= 1;				
				header_wr_addr		<= header_wr_addr + 1'h1;
				header_wr_data		<= dma_rx_data;
				
				//Processing length header
				if(header_wr_addr == 0) begin
				
					//If it's a read request, actual data length is always zero
					if(dma_rx_data[31:30] == DMA_OP_READ_REQUEST)
						rx_packet_len	<= 0;
						
					//If it's more than 512 words long, drop it (invalid)
					else if(dma_rx_data[9:0] > 512)
						rx_state		<= 0;
						
					//Good packet
					else
						rx_packet_len	<= dma_rx_data[9:0];
				end
				
				//Done with headers
				if(header_wr_addr == 1) begin
				
					//If packet has no payload we're finished
					if(rx_packet_len == 0) begin
						rx_state	<= RX_STATE_WAIT;
						rx_en		<= 1;
					end
					
					else
						rx_state		<= RX_STATE_DATA;
					
				end
				
			end
			
			//Receive data words
			RX_STATE_DATA: begin
				
				data_wr_en		<= 1;	
				data_wr_addr	<= data_wr_addr + 1'h1;
				data_wr_data	<= dma_rx_data;
				
				//Stay at zero for the first word
				if(header_wr_en)
					data_wr_addr	<= 0;
				
				//If we just wrote the last word, stop.
				//Don't assert the 'done' flag the same cycle as the last word for length-1 messages
				if( ((data_wr_addr + 10'h1) == rx_packet_len) && !header_wr_en) begin
					
					//always allow write to first word
					//0-length packets bail out from RX_STATE_HEADER
					if(data_wr_addr != 0)
						data_wr_en	<= 0;
					
					rx_state	<= RX_STATE_WAIT;
					rx_en		<= 1;
				end
				
			end
			
			//Wait for receive to finish
			//Ignore rx_done during rx_en cycle
			RX_STATE_WAIT: begin
				if(rx_done && !rx_en) begin
					rx_state	<= RX_STATE_IDLE;
					rx_dst_addr	<= 0;
				end
			end
		
		endcase
		
	end
	
endmodule

