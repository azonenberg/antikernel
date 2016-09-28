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
	@brief Transceiver for DMA network
	
	Transmit procedure:
		Wait for tx_busy to go low
		Load transmit buffer for write or read-response transactions
		Load header fields:
			tx_src_addr
			tx_dst_addr
			tx_op
			tx_addr
			tx_len
		Strobe tx_en for one cycle.
		External transmit SRAM should be connected to tx_rd, tx_raddr, tx_buf_out. Clocked by clk.
		Do not write to transmit buffer or header fields until tx_busy goes low
		
	Receive procedure
		Assert rx_ready. The transceiver will not acknowledge any inbound packets until rx_ready is high.
		Wait for rx_en to go high (single cycle pulse). Read header information immediately.
		Deassert rx_ready the immediately following cycle
		Use rx_buf_rd, rx_buf_addr, rx_buf_data to read data out of the buffer
		Assert rx_ready when ready to accept a new packet
		
	Streaming reads are implemented in DMATransceiverCore.
 */
module DMATransceiver(
	clk,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	tx_done, tx_busy, tx_src_addr, tx_dst_addr, tx_op, tx_addr, tx_len, tx_en, tx_rd, tx_raddr, tx_buf_out,
	rx_ready, rx_en, rx_src_addr, rx_dst_addr, rx_op, rx_addr, rx_len, rx_buf_rd, rx_buf_addr, rx_buf_data, rx_buf_rdclk
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Single clock
	input wire clk;
	
	//DMA network interface
	output wire dma_tx_en;
	output wire [31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	//Transmit interface to module
	output wire tx_done;
	output wire tx_busy;
	input wire[15:0] tx_src_addr;
	input wire[15:0] tx_dst_addr;
	input wire[1:0] tx_op;
	input wire[31:0] tx_addr;
	input wire[9:0] tx_len;
	input wire tx_en;
	
	//Transmit memory buffer interface (external, referenced to clk)
	output wire tx_rd;
	output wire[9:0] tx_raddr;
	input wire [31:0] tx_buf_out;
	
	//Receive interface to module
	input wire rx_ready;
	output wire rx_en;
	output wire[15:0] rx_src_addr;
	output wire[15:0] rx_dst_addr;
	output wire[1:0] rx_op;
	output wire[31:0] rx_addr;
	output wire[9:0] rx_len;
	input wire rx_buf_rd;
	input wire[8:0] rx_buf_addr;
	output reg[31:0] rx_buf_data = 0;
	input wire rx_buf_rdclk;
	
	parameter LEAF_PORT = 0;
	parameter LEAF_ADDR = 16'h0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive memory buffer
	
	reg[31:0] rx_buf[511:0];
	
	//Fill buffer to zero by default
	integer i;
	initial begin
		for(i=0; i<512; i = i+1)
			rx_buf[i] = 0;
	end
	
	//Write to receive buffer
	wire rx_we ;
	wire[8:0] rx_buf_waddr;
	wire[31:0] rx_buf_wdata;
	always @(posedge clk) begin
		if(rx_we)
			rx_buf[rx_buf_waddr] <= rx_buf_wdata;
	end
	
	//Read from receive buffer
	always @(posedge rx_buf_rdclk) begin
		if(rx_buf_rd)
			rx_buf_data <= rx_buf[rx_buf_addr];
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceiver
	
	DMATransceiverCore #(
		.LEAF_PORT(LEAF_PORT),
		.LEAF_ADDR(LEAF_ADDR)
	) txvr_core (
		.clk(clk),
		.dma_tx_en(dma_tx_en),
		.dma_tx_data(dma_tx_data),
		.dma_tx_ack(dma_tx_ack),
		.dma_rx_en(dma_rx_en),
		.dma_rx_data(dma_rx_data),
		.dma_rx_ack(dma_rx_ack),
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
		.tx_buf_out(tx_buf_out),
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
		.rx_state_header_2()
	);
	
endmodule
