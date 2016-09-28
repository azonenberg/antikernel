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
	@brief Router for the DMA network
	
	The DMA network is optimized for bulk data transfers and typically has higher latency than the RPC network (since
	packets are large it's necessary to wait a long time for the router to be free).
	
	Each packet can transfer up to 2KB of data. The padding must be all zero bits in order to ensure compatibility with
	future system versions which allow >2KB transfers.
	
	The 2KB limit was chosen because so that a single DMA transfer can move a full 2KB page of NAND flash or a 1500-byte
	Ethernet frame while still fitting in a single Spartan-6 block RAM.
	
	Packet format (32-bit words)
		Word							Data
		0								Source network address (16 bits)
										Dest network address	(16 bits)
		1								Opcode (2 bits)
										Padding (20 bits)
										Payload length in words (10 bits)
		2								Physical memory address
		Data							0 to 512 words.
		
	Opcodes
		0								Write request (contains data)
		1								Read request (no data, length field is the length REQUESTED)
		2								Read response (contains data)
		All other values reserved.
		
	Packet headers are 3 words in length so a maximal length packet is 515 words, for protocol overhead of 0.58%.
 */
module DMARouter(
	clk,
	
	port_rx_en, port_rx_data, port_rx_ack,
	port_tx_en, port_tx_data, port_tx_ack
	 );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk;		//Global network clock. All nodes on the network must use the same I/O
						//clock, internal clocks in a node can run at whatever speed the node
						//sees fit.	
	
	//Bitmap of disabled ports
	parameter PORT_DISABLE				= 5'h0;
	
	parameter SUBNET_MASK = 16'hFFFC;	//default to /14 subnet
	parameter SUBNET_ADDR = 16'h8000;	//first valid subnet address
	parameter HOST_BIT_HIGH = 1;		//host bits
	
	//Vector ports
	input wire[4:0]		port_rx_en;
	input wire[159:0]	port_rx_data;
	output wire[4:0]	port_rx_ack;
	
	output wire[4:0]	port_tx_en;
	output wire[159:0]	port_tx_data;
	input wire[4:0]		port_tx_ack;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Actual port logic
	
	//Header memory
	wire[4:0]			header_wr_en;
	wire[1:0]			header_wr_addr[4:0];
	wire[31:0]			header_wr_data[4:0];
	
	wire[4:0]			header_rd_en;
	wire[1:0]			header_rd_addr[4:0];
	wire[159:0]			header_rd_data;
	
	//Data memory
	wire[4:0]			data_wr_en;
	wire[8:0]			data_wr_addr[4:0];
	wire[31:0]			data_wr_data[4:0];
	
	wire[4:0]			data_rd_en;
	wire[8:0]			data_rd_addr[4:0];
	wire[159:0]			data_rd_data;
	
	//Read signals from transceiver
	wire[4:0]	 		port_fab_data_rd_en;
	wire[4:0]	 		port_fab_hdr_rd_en;
	wire[9:0]			port_fab_tx_hdr_addr;
	wire[44:0]			port_fab_tx_raddr;
	
	//Transmit signals
	wire[4:0]	tx_en;
	wire[4:0]	tx_done;
	wire[14:0]	port_selected_sender;
	wire[31:0]	port_rd_data[4:0];
	wire[31:0]	port_hdr_data[4:0];
	
	//Receive signals
	wire[4:0]	port_inbox_full;
	wire[4:0]	rx_en;
	wire[4:0]	rx_done;
	wire[15:0]	rx_dst_addr[4:0];
	
	genvar i;
	generate
		for(i=0; i<5; i=i+1) begin : txvrs
			
			//If port is unused, set all the lines to default state (zero)
			if(PORT_DISABLE[i]) begin
			
				assign port_inbox_full[i]				= 0;
				
				assign port_rx_ack[i]					= 0;
				assign port_tx_en[i]					= 0;
				assign port_tx_data[i*32 +: 32]			= 32'h0;
			
				assign port_selected_sender[i*3 +: 3]	= 0;

				assign header_wr_en[i]					= 1'h0;
				assign header_wr_addr[i]				= 2'h0;
				assign header_wr_data[i]				= 32'h0;
				
				assign data_wr_en[i]					= 1'h0;
				assign data_wr_addr[i]					= 2'h0;
				assign data_wr_data[i]					= 32'h0;
				
				assign header_rd_en[i]					= 1'h0;
				assign header_rd_addr[i]				= 2'h0;
				assign header_rd_data[i*32 +: 32]		= 32'h0;
				
				assign data_rd_en[i]					= 1'h0;
				assign data_rd_addr[i]					= 2'h0;
				assign data_rd_data[i*32 +: 32]			= 32'h0;
				
				assign port_fab_data_rd_en[i]			= 0;
				assign port_fab_hdr_rd_en[i]			= 0;
				assign port_fab_tx_hdr_addr[i*2 +: 2]	= 2'h0;
				assign port_fab_tx_raddr[i*9 +: 9]		= 9'h0;
				
				assign tx_en[i]							= 0;
				assign tx_done[i]						= 0;
				assign port_rd_data[i]					= 32'h0;
				assign port_hdr_data[i]					= 32'h0;
				
				assign rx_en[i]							= 0;
				assign rx_done[i]						= 0;
				assign rx_dst_addr[i]					= 16'h0;
			
			end
			
			//Otherwise have actual logic
			else begin
			
				//Header memory
				MemoryMacro #(
					.WIDTH(32),
					.DEPTH(32),
					.DUAL_PORT(1),
					.TRUE_DUAL(0),
					.USE_BLOCK(0),
					.OUT_REG(1),
					.INIT_ADDR(0),
					.INIT_FILE(""),
					.INIT_VALUE(0)
				) header_mem (
					.porta_clk(clk),
					.porta_en(header_wr_en[i]),
					.porta_addr({3'b0, header_wr_addr[i]}),
					.porta_we(header_wr_en[i]),
					.porta_din(header_wr_data[i]),
					.porta_dout(),
					.portb_clk(clk),
					.portb_en(header_rd_en[i]),
					.portb_addr({3'b0, header_rd_addr[i]}),
					.portb_we(1'b0),
					.portb_din(32'h0),
					.portb_dout(header_rd_data[i*32 +: 32])
				);
				
				//The main data memory
				MemoryMacro #(
					.WIDTH(32),
					.DEPTH(512),
					.DUAL_PORT(1),
					.TRUE_DUAL(0),
					.USE_BLOCK(1),
					.OUT_REG(1),
					.INIT_ADDR(0),
					.INIT_FILE(""),
					.INIT_VALUE(0)
				) data_mem (
					.porta_clk(clk),
					.porta_en(data_wr_en[i]),
					.porta_addr(data_wr_addr[i]),
					.porta_we(data_wr_en[i]),
					.porta_din(data_wr_data[i]),
					.porta_dout(),
					.portb_clk(clk),
					.portb_en(data_rd_en[i]),
					.portb_addr(data_rd_addr[i]),
					.portb_we(1'b0),
					.portb_din(32'h0),
					.portb_dout(data_rd_data[i*32 +: 32])
				);
				
				//The transceiver
				DMARouterTransceiver #(
					.LEAF_PORT(1'b0),
					.LEAF_ADDR(16'h0)
				) txvr (
					.clk(clk),
					.dma_tx_en(port_tx_en[i]),
					.dma_tx_data(port_tx_data[i*32 +: 32]),
					.dma_tx_ack(port_tx_ack[i]),
					.dma_rx_en(port_rx_en[i]),
					.dma_rx_data(port_rx_data[i*32 +: 32]),
					.dma_rx_ack(port_rx_ack[i]),
					
					.tx_en(tx_en[i]),
					.tx_done(tx_done[i]),
					
					.rx_en(rx_en[i]),
					.rx_done(rx_done[i]),
					.rx_inbox_full(),
					.rx_inbox_full_cts(port_inbox_full[i]),	//use cut-through switching inbox flag
															//which goes high on FIRST word of packet
					.rx_dst_addr(rx_dst_addr[i]),
				
					.header_wr_en(header_wr_en[i]),
					.header_wr_addr(header_wr_addr[i]),
					.header_wr_data(header_wr_data[i]),
					.header_rd_en(port_fab_hdr_rd_en[i]),
					.header_rd_addr(port_fab_tx_hdr_addr[i*2 +: 2]),
					.header_rd_data(port_hdr_data[i]), 
					
					.data_wr_en(data_wr_en[i]),
					.data_wr_addr(data_wr_addr[i]),
					.data_wr_data(data_wr_data[i]),
					.data_rd_en(port_fab_data_rd_en[i]),
					.data_rd_addr(port_fab_tx_raddr[i*9 +: 9]),
					.data_rd_data(port_rd_data[i])
				);
				
				//Arbitration
				RPCv2Arbiter #(
					.THIS_PORT(i),
					.SUBNET_MASK(SUBNET_MASK),
					.SUBNET_ADDR(SUBNET_ADDR),
					.HOST_BIT_HIGH(HOST_BIT_HIGH)
				) arbiter (
					.clk(clk),
					.port_inbox_full(port_inbox_full),
					.port_dst_addr({rx_dst_addr[4], rx_dst_addr[3], rx_dst_addr[2], rx_dst_addr[1], rx_dst_addr[0]}),
					.tx_en(tx_en[i]),
					.tx_done(tx_done[i]),
					.selected_sender(port_selected_sender[3*i +: 3])
				);
				
				//Keep track of inbox state
				DMARouterInboxTracking #(
					.PORT_COUNT(4),
					.THIS_PORT(i)
				) inbox_tracker (
					.clk(clk),
					.port_selected_sender(port_selected_sender),
					.port_fab_data_rd_en(port_fab_data_rd_en),
					.port_fab_hdr_rd_en(port_fab_hdr_rd_en),
					.port_fab_tx_raddr(port_fab_tx_raddr),
					.port_fab_tx_hdr_addr(port_fab_tx_hdr_addr),
					.port_fab_tx_done(tx_done),
					.port_fab_rx_done(rx_done[i]),
					.port_rdbuf_addr(data_rd_addr[i]),
					.port_hdr_addr(header_rd_addr[i]),
					.port_hdr_rd_en(header_rd_en[i]),
					.port_data_rd_en(data_rd_en[i])
				);
				
				//The actual crossbar muxes
				NOCMux #(
					.WIDTH(32),
					.PORT_COUNT(4)
				) hdrmux (
					.sel(port_selected_sender[3*i +: 3]),
					.din(header_rd_data),
					.dout(port_hdr_data[i])
				);
				NOCMux #(
					.WIDTH(32),
					.PORT_COUNT(4)
				) datmux (
					.sel(port_selected_sender[3*i +: 3]),
					.din(data_rd_data),
					.dout(port_rd_data[i])
				);
			end
						
		end
	endgenerate
	
endmodule
