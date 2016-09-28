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
	@brief Implementation of NetworkedEthernetMAC
	
	@module
	@brief			NoC-connected 10/100/1000 Ethernet MAC core
	@opcodefile		NetworkedEthernetMAC_opcodes.constants
	
	@rpcfn			ETH_RESET
	@brief			Resets the MAC.
	
	@rpcfn_ok		ETH_RESET
	@brief			Reset completed successfully.
	
	@rpcfn			ETH_REGISTER_TYPE
	@brief			Registers an EtherType value.
	@param			ethertype	d0[15:0]:hex					EtherType value
	
	@rpcfn_ok		ETH_REGISTER_TYPE
	@brief			EtherType registered
	
	@rpcfn_fail		ETH_REGISTER_TYPE
	@brief			EtherType invalid or already registered to another host	
	
	@rpcfn			ETH_SET_MAC
	@brief			Sets the MAC address for this instance
	@param			mac			{d0[15:0],d1[31:0]}:mac			MAC address
	
	@rpcfn_ok		ETH_SET_MAC
	@brief			Source MAC address set
	
	@rpcfn			ETH_SET_DSTMAC
	@brief			Sets the destination MAC address for the next frame to be sent
	@param			mac			{d0[15:0],d1[31:0]}:mac			MAC address
	
	@rpcfn_ok		ETH_SET_DSTMAC
	@brief			Destination MAC address set
	
	@rpcfn			ETH_SEND_FRAME
	@brief			Sends a frame by DMA
	@param			addr		{d0[15:0],d1[31:0]}:phyaddr		Physical address of frame
	@param			ethertype	d0[15:0]:hex					EtherType of frame
	@param			wordlen		d2[8:0]:dec						Length of frame
	
	@rpcfn_ok		ETH_SEND_FRAME
	@brief			Frame sent

	@rpcfn			ETH_GET_STATUS
	@brief			Gets the status of the NIC
	
	@rpcfn_ok		ETH_GET_STATUS
	@brief			Current link status
	@param			link_state		d0[0]:dec					Link state
	@param			duplex_state	d0[1]:dec					Duplex state (only valid if link up)
	@param			link_speed		d0[3:2]:dec					Link speed (only valid if link is up)
	
	@rpcint			ETH_FRAME_READY
	@brief			New frame ready
	@param			wordlen		d0[8:0]							Length of frame
	@param			addr		{d2[15:0],d1[31:0]}:phyaddr		Physical address of frame
	@param			ethertype	d2[31:16]						EtherType of frame
	
	@rpcint			ETH_LINK_STATE
	@brief			Link status changed
	@param			link_state		d0[0]:dec					Link state
	@param			duplex_state	d0[1]:dec					Duplex state (only valid if link up)
	@param			link_speed		d0[3:2]:dec					Link speed (only valid if link is up)
 */
module NetworkedEthernetMAC(
	
	//Clocks
	clk, clk_25mhz, clk_125mhz,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//[R]GMII signals
	xmii_rxc, xmii_rxd, xmii_rx_ctl,
	xmii_txc, xmii_txd, xmii_tx_ctl,
	
	//Management and interrupt signals
	mgmt_mdio, mgmt_mdc, reset_n, clkout,
	
	//SFP signals
	sfp_refclk,
	sfp_tx_p, sfp_tx_n,
	sfp_rx_p, sfp_rx_n
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	input wire clk_25mhz;
	input wire clk_125mhz;
	
	//NoC interface
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;
	
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	//Set this to "RGMII", "GMII", or "SFP"
	parameter PHY_INTERFACE = "INVALID";
	
	//Default for backward compatibility
	parameter OUTPUT_PHASE_SHIFT = "DELAY";
	
	//Clock buffer type
	//default required for backward compatibility
	parameter CLOCK_BUF_TYPE = "GLOBAL";
	
	//Width of data/control buses
	localparam DATA_WIDTH = (PHY_INTERFACE == "RGMII") ? 4 : 8;
	localparam CTRL_WIDTH = (PHY_INTERFACE == "RGMII") ? 1 : 2;
	
	//[R]GMII signals
	input wire xmii_rxc;
	input wire[DATA_WIDTH-1:0] xmii_rxd;
	input wire[CTRL_WIDTH-1:0] xmii_rx_ctl;
	output wire xmii_txc;
	output wire[DATA_WIDTH-1:0] xmii_txd;
	output wire[CTRL_WIDTH-1:0] xmii_tx_ctl;
	
	//Management and interrupt signals
	inout wire mgmt_mdio;
	output wire mgmt_mdc;
	output wire reset_n;
	output wire clkout;
	
	//SFP-specific signals
	input wire	sfp_refclk;
	output wire sfp_tx_p;
	output wire sfp_tx_n;
	input wire	sfp_rx_p;
	input wire	sfp_rx_n;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "DMARouter_constants.v"
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR			= 16'h0000;
	parameter PHY_CHIPSET 		= "INVALID";
	parameter AUTO_POR			= 0;		//must default to 0 for backward compatibility with PDU etc
	
	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;
	
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	reg			rpc_fab_rx_done		= 0;
	wire		rpc_fab_inbox_full;
	
	RPCv2Transceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(NOC_ADDR)
	) txvr(
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(16'h0000),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		
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
	reg drx_ready = 0;
	wire drx_en;
	wire[15:0] drx_src_addr;
	wire[15:0] drx_dst_addr;
	wire[1:0] drx_op;
	wire[31:0] drx_addr;
	wire[9:0] drx_len;	
	reg drx_buf_rd = 0;
	reg[9:0] drx_buf_addr = 0;
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
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(xmii_rxc)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual MAC
	
	parameter PHY_MD_ADDR = 5'b00001;

	//Real signals
	wire mac_reset;
	wire mac_reset_done;
	
	//Status outputs
	wire link_state;
	wire duplex_state;
	wire[1:0] link_speed;
	
	//Receiver data outputs (gmii_rxc domain)
	wire rx_frame_start;
	wire rx_frame_data_valid;
	wire[31:0] rx_frame_data;
	wire rx_frame_done;
	wire rx_frame_drop;
	
	//Transmitter data inputs (gmii_rxc domain)
	//Must run at a minimum of 8 bits per gmii_txc cycle with no gaps
	//to prevent buffer underruns
	reg[31:0] tx_frame_data = 0;
	reg tx_frame_data_valid = 0;
	wire tx_frame_done;
	
	//Our MAC address
	reg[47:0] client_mac_address = 48'hffffffffffff;
	
	//MAC address of the next frame to be sent
	reg[47:0] dst_mac_address = 48'hffffffffffff;
	
	//Recovered, buffered clock for tx/rx logic
	wire	gmii_rxc;
	
	generate
	
		if(PHY_INTERFACE == "SFP") begin
		
			assign mgmt_mdio = 1'b0;
		
			GigabitEthernetMAC_SFP #(
				.AUTO_POR(AUTO_POR),
				.CLOCK_BUF_TYPE(CLOCK_BUF_TYPE)
			) mac (
				
				//Clocks
				.clk_125mhz(clk_125mhz),
				.refclk(sfp_refclk),
				
				//SFP interface
				.sfp_tx_p(sfp_tx_p),
				.sfp_tx_n(sfp_tx_n),
				.sfp_rx_p(sfp_rx_p),
				.sfp_rx_n(sfp_rx_n),
				
				//Recovered clock for tx/rx logic
				.clk_fabric(gmii_rxc),
				
				//Control inputs
				.mac_reset(mac_reset),
				.mac_reset_done(mac_reset_done),
				
				//Receiver data outputs
				.rx_frame_start(rx_frame_start),
				.rx_frame_data_valid(rx_frame_data_valid),
				.rx_frame_data(rx_frame_data),
				.rx_frame_done(rx_frame_done),
				.rx_frame_drop(rx_frame_drop),
				
				//Transmitter data inputs
				.tx_frame_data(tx_frame_data),
				.tx_frame_data_valid(tx_frame_data_valid),
				.tx_frame_done(tx_frame_done),
				
				//Status outputs
				.link_state(link_state),
				.duplex_state(duplex_state),
				.link_speed(link_speed)
			);
			
		end
		
		//GMII and RGMII both handled here
		else begin
		
			TriModeEthernetMAC #(
				.PHY_MD_ADDR(PHY_MD_ADDR),
				.PHY_CHIPSET(PHY_CHIPSET),
				.PHY_INTERFACE(PHY_INTERFACE),
				.OUTPUT_PHASE_SHIFT(OUTPUT_PHASE_SHIFT),
				.AUTO_POR(AUTO_POR),
				.CLOCK_BUF_TYPE(CLOCK_BUF_TYPE)
			) mac (
				
				//Clocks
				.clk_25mhz(clk_25mhz),
				.clk_125mhz(clk_125mhz),
				
				//GMII interface		
				.xmii_rxc(xmii_rxc),
				.xmii_rxd(xmii_rxd),
				.xmii_rx_ctl(xmii_rx_ctl),
				.xmii_txc(xmii_txc),
				.xmii_txd(xmii_txd),
				.xmii_tx_ctl(xmii_tx_ctl),
				
				//Recovered clock for tx/rx logic
				.gmii_rxc(gmii_rxc),
				
				//PHY control/management
				.mgmt_mdio(mgmt_mdio),
				.mgmt_mdc(mgmt_mdc),
				.phy_reset_n(reset_n),
				.clkout(clkout),
				
				//Control inputs
				.mac_reset(mac_reset),
				.mac_reset_done(mac_reset_done),
				
				//Receiver data outputs
				.rx_frame_start(rx_frame_start),
				.rx_frame_data_valid(rx_frame_data_valid),
				.rx_frame_data(rx_frame_data),
				.rx_frame_done(rx_frame_done),
				.rx_frame_drop(rx_frame_drop),
				
				//Transmitter data inputs
				.tx_frame_data(tx_frame_data),
				.tx_frame_data_valid(tx_frame_data_valid),
				.tx_frame_done(tx_frame_done),
				
				//Status outputs
				.link_state(link_state),
				.duplex_state(duplex_state),
				.link_speed(link_speed)
			);
			
		end
		
	endgenerate
	
	//Clock domain crossing for reset
	wire mac_reset_done_sync;
	reg mac_reset_raw = 0;
	HandshakeSynchronizer sync_reset
		(.clk_a(clk),			.en_a(mac_reset_raw), 		.ack_a(mac_reset_done_sync), .busy_a(),
		 .clk_b(clk_125mhz), 	.en_b(mac_reset),			.ack_b(mac_reset_done));
		 
	//Clock domain crossing for link state
	wire link_state_sync;
	wire duplex_state_sync;
	ThreeStageSynchronizer sync_link_state(.clk_in(gmii_rxc), .din(link_state), .clk_out(clk), .dout(link_state_sync));
	ThreeStageSynchronizer sync_duplex_state(.clk_in(gmii_rxc), .din(duplex_state), .clk_out(clk), .dout(duplex_state_sync));
	
	reg link_state_sync_buf = 0;
	reg link_state_changed = 0;
	reg clear_link_state_changed = 0;
	always @(posedge clk) begin
		link_state_sync_buf <= link_state_sync;
		
		if(link_state_sync_buf != link_state_sync)
			link_state_changed <= 1;
			
		if(clear_link_state_changed)
			link_state_changed <= 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Packet receive buffer
	
	//The actual buffer
	integer j;
	reg[31:0] packet_rx_buf[1023:0];
	initial begin
		for(j=0; j<1024; j = j+1)
			packet_rx_buf[j] = 32'hcccccccc;
	end
	
	//Keep track of which buffers are free
	reg[1:0] rx_buffer_free = 2'b11;
	
	//The current buffer to write to
	reg rx_buffer_id = 0;
	
	//Buffer ID that the clk_noc logic is processing
	reg rx_process_buffer_id = 0;
	
	//Length of frame that clk_noc logic is processing
	reg[8:0] rx_process_frame_len = 0;

	//Synchronizer for us to inform clk_noc that a buffer is ready to be processed
	reg rx_buffer_ready = 0;
	wire rx_buffer_ready_sync;
	reg rx_buffer_done = 0;
	wire rx_buffer_done_sync;
	reg rx_buffer_busy = 0;
	HandshakeSynchronizer sync_rxbuf_ready
		(.clk_a(gmii_rxc),		.en_a(rx_buffer_ready),      .ack_a(rx_buffer_done_sync), .busy_a(),
		 .clk_b(clk), 			.en_b(rx_buffer_ready_sync), .ack_b(rx_buffer_done));
		 
	//Read logic for DMA transmits
	wire[9:0] packet_rx_buf_addr = {rx_process_buffer_id, dtx_raddr[8:0]};
	always @(posedge clk) begin
		if(dtx_rd)
			dtx_buf_out <= packet_rx_buf[packet_rx_buf_addr];
	end
	
	reg rx_buffer_we = 0;
	reg rx_buffer_wfirst = 0;			//set to true to clear address on next write
	reg[8:0] rx_buffer_wptr = 0;
	reg[31:0] rx_buffer_wdata = 0;
	wire[9:0] packet_rx_buf_waddr = {rx_buffer_id, rx_buffer_wptr};
	always @(posedge gmii_rxc) begin
		if(rx_buffer_we)
			packet_rx_buf[packet_rx_buf_waddr] <= rx_buffer_wdata;
	end
	
	//Synchronzier for clk_noc to inform transmit clock domain that data is ready to be send
	reg tx_buffer_ready;
	wire tx_buffer_ready_sync;
	reg tx_buffer_done = 0;
	wire tx_buffer_done_sync;
	HandshakeSynchronizer sync_txbuf_ready
		(.clk_a(clk),			.en_a(tx_buffer_ready),      .ack_a(tx_buffer_done_sync), .busy_a(),
		 .clk_b(gmii_rxc), 	.en_b(tx_buffer_ready_sync), .ack_b(tx_buffer_done));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive state machine (gmii_rxc clock domain)
	
	`include "NetworkedEthernetMAC_rx_states_constants.v"
	
	/*
		Type field - generated from Ethernet type/length field and LLC header.

		If the high byte is zero, the low byte is an 802.2 LLC DSAP type.
		If the high byte is nonzero, it's an Ethernet II EtherType field.
	*/
	reg[15:0] rx_frame_ethertype = 0;
	reg[10:0] rx_frame_wordsize[1:0];
	initial begin
		rx_frame_wordsize[0] <= 0;
		rx_frame_wordsize[1] <= 0;
	end

	//Frame is read 32 bits at a time, but phase-shifted due to the layer 2 header
	reg[15:0] frame_temp_data = 0;
	reg last_frame_word = 0;
	
	//The ethertype of the frame currently being processed
	reg[15:0] process_ethertype = 0;
	
	//Debug - counter of frames dropped due to lack of buffer space
	reg[15:0] frames_dropped = 0;
	
	//Helper - size of the current frame, in words
	wire[10:0] rx_frame_current_wordsize = rx_frame_wordsize[rx_buffer_id];
	
	/*
		Process the frame

		Strip off layer-2 header as we go.
	*/
	reg[3:0] rx_state = RX_STATE_IDLE;
	always @(posedge gmii_rxc) begin

		rx_buffer_ready <= 0;
		rx_buffer_we 	<= 0;
		last_frame_word <= 0;

		//Process alerts from clk domain saying "buffer X is free"
		if(rx_buffer_done_sync) begin
			rx_buffer_busy <= 0;
			rx_buffer_free[rx_process_buffer_id] <= 1;
		end

		case(rx_state)
	
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Idle, wait for frame to start
			RX_STATE_IDLE: begin
			
				if(rx_frame_start) begin
					
					//Are both buffers full?
					if(!rx_buffer_free) begin
						//The NoC is falling behind :( Drop the frame, we have nowhere to put it
						frames_dropped <= frames_dropped + 16'h1;
					end
				
					//Nope, good to go
					else begin
						rx_state <= RX_STATE_ACTIVE;
						rx_frame_ethertype[rx_buffer_id] <= 0;
						rx_frame_wordsize[rx_buffer_id]	<= 0;
						rx_buffer_wfirst <= 1;
					end
					
				end				
			end	//end RX_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Actively recieving a frame
			RX_STATE_ACTIVE: begin
			
				if(rx_frame_data_valid) begin
					rx_frame_wordsize[rx_buffer_id] <= rx_frame_current_wordsize + 11'h1;
					
					//Store 802.3 header info as needed
					//TODO: Drop frames not addressed to client_mac_address or broadcast
					//(if we're on a switched network, not needed)
					case(rx_frame_current_wordsize)
						0:	begin
							//dest mac, high half
						end
						1:	begin
							//dest mac, low half
							//source mac, high half
						end
						2: begin
							//source mac, low half
						end
						3: begin
							
							//Large value = Ethernet II ethertype
							if(rx_frame_data[31:16] >= 16'd1536)
								rx_frame_ethertype <= rx_frame_data[31:16];
								
							//Small value means it's a size
							//Read the LLC header and use the DSAP flag as the type instead
							else
								rx_frame_ethertype <= {8'h0, rx_frame_data[15:8] };
								
							frame_temp_data <= rx_frame_data[15:0];
						end
						
						//Frame body
						default: begin
						
							//Save the lower half of the word
							frame_temp_data <= rx_frame_data[15:0];
							
							//Bump address
							if(rx_buffer_wfirst) begin
								rx_buffer_wptr <= 0;
								rx_buffer_wfirst <= 0;
							end
							else
								rx_buffer_wptr <= rx_buffer_wptr + 9'h1;
							
							//Write the high half and the previous low half to RAM
							rx_buffer_we <= 1;
							rx_buffer_wdata <= {frame_temp_data, rx_frame_data[31:16]};
						end
					endcase
					
				end
				
				//Successful completion of frame? Process it
				if(rx_frame_done) begin
					
					//Mark the current buffer as used
					rx_buffer_free[rx_buffer_id] <= 0;
					
					//Save last word if needed
					if(rx_frame_data_valid)
						last_frame_word <= 1;
					
					rx_state <= RX_STATE_NOTIFY;
				end
					
				//Bad frame? Drop it
				if(rx_frame_drop)
					rx_state <= RX_STATE_IDLE;

			end	//end RX_STATE_ACTIVE
			
			RX_STATE_NOTIFY: begin
			
				//Send 16-bit chunk to buffer if needed
				if(last_frame_word) begin
					rx_buffer_we <= 1;
					rx_buffer_wdata <= {frame_temp_data, 16'h00};
					rx_buffer_wptr <= rx_buffer_wptr + 9'h1;
				end
			
				if(!rx_buffer_busy) begin
					rx_buffer_busy <= 1;
					
					//Swap buffers
					rx_buffer_id <= ~rx_buffer_id;
													
					//Send the "buffer ready" alert
					rx_process_buffer_id <= rx_buffer_id;
					process_ethertype <= rx_frame_ethertype;
					rx_buffer_ready <= 1;
					if(last_frame_word)
						rx_process_frame_len <= rx_buffer_wptr + 9'h1;
					else
						rx_process_frame_len <= rx_buffer_wptr;
					
					rx_state <= RX_STATE_IDLE;
				end
			end	//end RX_STATE_NOTIFY
		
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit state machine (gmii_rxc clock domain)
	
	`include "NetworkedEthernetMAC_tx_states_constants.v"
	
	//We need to send the transmit-begin alert to the MAC, then have it request data.
	
	reg[9:0] tx_frame_wordsize;
		
	reg[3:0] tx_state = TX_STATE_IDLE;
	always @(posedge gmii_rxc) begin
		tx_buffer_done <= 0;
		
		tx_frame_data_valid <= 0;
		tx_frame_data <= 0;
		
		drx_buf_rd <= 0;
		
		case(tx_state)
		
			TX_STATE_IDLE: begin
				if(tx_buffer_ready_sync) begin
					
					//Simplify code and avoid the phase shift
					//by sending two zero bytes before the preamble
					tx_frame_data <= 32'h00005555;	//preamble 0, 1
					tx_frame_data_valid <= 1;
					tx_state <= TX_STATE_HEADER_0;

				end
			end	//end TX_STATE_IDLE
			
			TX_STATE_HEADER_0: begin
			
				tx_frame_data <= 32'h55555555;	//preamble 2, 3, 4, 5
				tx_frame_data_valid <= 1;
				
				//Get ready to read the first data word
				drx_buf_addr <= 0;
				drx_buf_rd <= 1;
			
				tx_state <= TX_STATE_HEADER_1;
			end	//end TX_STATE_HEADER_0
			
			TX_STATE_HEADER_1: begin
			
				tx_frame_data <= {16'h55d5, dst_mac_address[47:32]};	//preamble 6, SFD, first third of dest mac
				tx_frame_data_valid <= 1;
							
				tx_state <= TX_STATE_HEADER_2;
			end	//end TX_STATE_HEADER_1
			
			TX_STATE_HEADER_2: begin
			
				tx_frame_data <= dst_mac_address[31:0];
				tx_frame_data_valid <= 1;
							
				tx_state <= TX_STATE_HEADER_3;
			end	//end TX_STATE_HEADER_2
			
			TX_STATE_HEADER_3: begin
			
				tx_frame_data <= client_mac_address[47:16];
				tx_frame_data_valid <= 1;
				
				//Read the first data word
				drx_buf_addr <= 0;
				drx_buf_rd <= 1;
							
				tx_state <= TX_STATE_HEADER_4;
			end	//end TX_STATE_HEADER_3
			
			TX_STATE_HEADER_4: begin
			
				tx_frame_data <= {client_mac_address[15:0], tx_ethertype};
				tx_frame_data_valid <= 1;
				
				//Read the second data word
				drx_buf_addr <= 1;
				drx_buf_rd <= 1;
			
				tx_state <= TX_STATE_DATA;
			end	//end TX_STATE_HEADER_4
			
			TX_STATE_DATA: begin
				
				//Push the word out to the transmitter
				tx_frame_data_valid <= 1;
				tx_frame_data <= drx_buf_data;
					
				//One more to go? Bump count but don't read
				if( (drx_buf_addr + 10'h1) == tx_frame_wordsize) begin
					drx_buf_addr <= drx_buf_addr + 10'h1;
				end
				
				///Stop if we just send the last word
				else if( drx_buf_addr == tx_frame_wordsize) begin
					tx_state <= TX_STATE_WAIT;
				end
				
				//Nope, read the next one
				else begin
					drx_buf_addr <= drx_buf_addr + 10'h1;
					drx_buf_rd <= 1;
				end

			end	//end TX_STATE_DATA
			
			TX_STATE_WAIT: begin
				if(tx_frame_done) begin
					tx_buffer_done <= 1;
					tx_state <= TX_STATE_IDLE;
				end
			end	//end TX_STATE_WAIT
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Table mapping ethertypes to NoC addresses
	// Hash table with 16 4-element buckets
		
	//All I/O is in clk domain (async reads)
	reg			ethertype_table_wr_valid = 0;	//Valid bit to write
	reg[11:0]	ethertype_table_wr_tag = 0;		//Tag to write
	reg[15:0]	ethertype_table_wr_owner = 0;	//Owner to write
	reg			ethertype_table_wr_en = 0;
	reg[3:0]	ethertype_table_bucket = 0;		//Bucket ID
	reg[1:0]	ethertype_table_row = 0;		//Row in the bucket
	wire		ethertype_table_rd_valid;
	wire[11:0]	ethertype_table_rd_tag;
	wire[15:0]	ethertype_table_rd_owner;
	reg[3:0]	ethertype_table_free_sets = 0;

	//Initialization
	reg[29:0] ethertype_cache[63:0];
	initial begin
		for(j=0; j<64; j = j+1)
			ethertype_cache[j] <=0;
	end
	
	//Writes
	wire[5:0] ethertype_table_addr = {ethertype_table_bucket, ethertype_table_row};
	always @(posedge clk) begin
		if(ethertype_table_wr_en)
			ethertype_cache[ethertype_table_addr] <= {ethertype_table_wr_valid, ethertype_table_wr_tag, ethertype_table_wr_owner};
	end
	
	//Reads
	wire[28:0] ethertype_table_out = ethertype_cache[ethertype_table_addr];
	assign ethertype_table_rd_valid = ethertype_table_out[28];
	assign ethertype_table_rd_tag = ethertype_table_out[27:16];
	assign ethertype_table_rd_owner = ethertype_table_out[15:0];
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Network state machine (network clock domain)
	
	//Pull in our own state and opcode definitions
	`include "NetworkedEthernetMAC_opcodes_constants.v"
	`include "NetworkedEthernetMAC_states_constants.v"
	
	//Pull in API definitions for external servers
	`include "NOCNameServer_constants.v"
	`include "NetworkedDDR2Controller_opcodes_constants.v"
	
	//Event-queue status flags
	reg rpc_message_pending = 0;
	reg dma_message_pending = 0;
	reg rx_frame_pending = 0;
	
	reg rpc_tx_busy = 0;
	
	//Address of the RAM
	reg[15:0] ram_address = 0;
	
	//Pointer to the currently available DRAM buffer for DMAing data to
	reg[31:0] ram_write_ptr = 0;
	reg ram_write_ptr_valid = 0;
	
	//Saved source address for the current call
	reg[15:0] call_source_address = 0;
	
	//The node that reset us gets notified when the link state changes
	reg[15:0] reset_source = 0;
	
	reg reset_active = 0;
	
	//Ethertype of the frame about to be transmitted
	reg[15:0] tx_ethertype = 0;
	
	localparam NAMESRVR_ADDR = 16'h8000;
	
	//Asserted for one cycle when a RAM write is done
	reg ram_writedone = 0;
	
	//Asserted whenever a function call is in progress and no new calls can be accepted
	reg function_call_busy = 0;
	
	//Out-of-memory retry timer
	reg[23:0] oom_retry_count = 0;
	
	//Set if a message is ready to process and the transmitter is idle
	wire rpc_message_ready;
	assign rpc_message_ready = (rpc_fab_rx_en || rpc_message_pending) && !rpc_fab_tx_en && !rpc_tx_busy;
	
	reg[5:0] state = STATE_BOOT_FREEZE;
	always @(posedge clk) begin
	
		//Clear one-cycle flags
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		ethertype_table_wr_en <= 0;
		mac_reset_raw <= 0;
		rx_buffer_done <= 0;
		dtx_en <= 0;
		tx_buffer_ready <= 0;
		clear_link_state_changed <= 0;
		ram_writedone <= 0;
		
		//Save status when a new function call or interrupt arrives
		if(rpc_fab_rx_en)
			rpc_message_pending <= 1;
			
		if(rpc_message_ready) begin
		
			//Interrupt
			if(rpc_fab_rx_type == RPC_TYPE_INTERRUPT) begin
		
				//Handle interrupts immediately
				rpc_message_pending <= 0;
		
				//RAM write done interrupt
				if(rpc_fab_rx_src_addr == ram_address) begin
					ram_writedone <= 1;
					rpc_fab_rx_done <= 1;
				end
				
				//TODO: Handle access-denied interrupts?
				
				//No other interrupts implemented, drop it
				else begin
					rpc_fab_rx_done <= 1;
				end
				
			end
			
			//Function call
			else if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
				
				if(function_call_busy) begin
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_type <= RPC_TYPE_RETURN_RETRY;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					
					rpc_fab_rx_done <= 1;
					rpc_message_pending <= 0;
				end
				
				else begin
					rpc_message_pending <= 1;
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
				end
								
			end

		end
		
		if(rx_buffer_ready_sync)
			rx_frame_pending <= 1;
		if(drx_en)
			dma_message_pending <= 1;
			
		if(rpc_fab_tx_en)
			rpc_tx_busy <= 1;
		if(rpc_fab_tx_done)
			rpc_tx_busy <= 0;
	
		//Main state machine
		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Reset logic
		
			//Sit around and wait for a reset
			STATE_BOOT_FREEZE: begin
				if(rpc_message_ready) begin
					rpc_message_pending <= 0;
					
					//Function calls need a response
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						
						//Reset? Execute it
						if(rpc_fab_rx_callnum == ETH_RESET) begin
							mac_reset_raw		<= 1;
							state				<= STATE_RESET_0;
							reset_source		<= rpc_fab_rx_src_addr;
						end
						
						//Anything else? NAK it
						else begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_RETRY;
							rpc_fab_tx_d0 <= 0;
							rpc_fab_tx_d1 <= 0;
							rpc_fab_tx_d2 <= 0;
							rpc_fab_tx_en <= 1;
							
							rpc_fab_rx_done <= 1;
						end
						
					end
					
					//otherwise ignore it
					else begin
						rpc_fab_rx_done <= 1;
						state <= STATE_RESET_1;
					end
					
				end
			end	//end STATE_BOOT_FREEZE
			
			//Wait for the MAC to finish resetting
			STATE_RESET_0: begin
				if(mac_reset_done_sync || AUTO_POR) begin
					
					//Save source address
					call_source_address <= rpc_fab_rx_src_addr;
					rpc_fab_rx_done <= 1;
					reset_active <= 1;
					
					//Continue
					state <= STATE_RESET_1;

				end
			end	//end STATE_RESET_0
			
			//Look up the address of the RAM
			STATE_RESET_1: begin
				if(!rpc_fab_tx_en && !rpc_tx_busy) begin
					
					//Look up the address of RAM
					rpc_fab_tx_type <= RPC_TYPE_CALL;
					rpc_fab_tx_dst_addr <= NAMESRVR_ADDR;
					rpc_fab_tx_callnum <= NAMESERVER_FQUERY;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= {"ram", 8'h00};
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					
					state <= STATE_RESET_2;
				end
			end	//end STATE_RESET_1
			
			STATE_RESET_2: begin
				
				//Wait for a response
				if(rpc_message_ready) begin
					
					case(rpc_fab_rx_type)
						//Ignore interrupts etc, none of them have any meaning yet
						
						//Call during the reset? Request a retry
						RPC_TYPE_CALL: begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_RETRY;
							rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
							rpc_fab_tx_d0 <= 0;
							rpc_fab_tx_d1 <= 0;
							rpc_fab_tx_d2 <= 0;
							rpc_fab_tx_en <= 1;
						end
						
						//Success from the name server? We got it
						RPC_TYPE_RETURN_SUCCESS: begin
							ram_address <= rpc_fab_rx_d0[15:0];
							
							//Now that we know the address, go and allocate a new page of RAM for buffering
							//Allocate a new page for DMA
							//If we already have a valid page use it rather than leaking
							if(ram_write_ptr_valid) begin
							
								//Send response
								rpc_fab_tx_dst_addr <= call_source_address;
								rpc_fab_tx_callnum <= ETH_RESET;
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								
								state <= STATE_RPC_TXHOLD;
								
							end
							else
								state <= STATE_ALLOC_0;
						end
						
						//Retry? Send the request again
						RPC_TYPE_RETURN_RETRY: begin
							state <= STATE_RESET_1;
						end
						
						//If we get a fail from the name server, something is wrong - reset.
						//From anyone else, ignore.
						RPC_TYPE_RETURN_FAIL: begin
							if(rpc_fab_rx_src_addr == NAMESRVR_ADDR)
								state <= STATE_BOOT_FREEZE;
						end
						
					endcase
					
					rpc_message_pending <= 0;
					rpc_fab_rx_done <= 1;
					
				end				

			end	//end STATE_RESET_2

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Memory allocation
			
			//Try to allocate some RAM
			STATE_ALLOC_0: begin
				if(!rpc_fab_tx_en && !rpc_tx_busy) begin
					rpc_fab_tx_type <= RPC_TYPE_CALL;
					rpc_fab_tx_callnum <= RAM_ALLOCATE;
					rpc_fab_tx_dst_addr <= ram_address;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_ALLOC_1;
				end
			end	//end STATE_ALLOC_0
			
			//Wait for the RAM to respond, then save the pointer
			STATE_ALLOC_1: begin
			
				if(rpc_message_ready) begin
					
					case(rpc_fab_rx_type)
					
						//Calls are rejected by above logic
					
						RPC_TYPE_RETURN_SUCCESS: begin
							ram_write_ptr <= rpc_fab_rx_d1;
							ram_write_ptr_valid <= 1;
							
							if(reset_active) begin
								reset_active <= 0;

								//Send response
								rpc_fab_tx_dst_addr <= call_source_address;
								rpc_fab_tx_callnum <= ETH_RESET;
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								
								state <= STATE_RPC_TXHOLD;
							end
							else begin
								state <= STATE_IDLE;
							end
						end
						RPC_TYPE_RETURN_RETRY: begin
							state <= STATE_ALLOC_0;
						end
						
						//If we're out of memory, we can't receive any more frames for a while
						RPC_TYPE_RETURN_FAIL: begin	
							if(rpc_fab_rx_src_addr == ram_address) begin
								ram_write_ptr_valid <= 0;
								ram_write_ptr <= 0;
								oom_retry_count <= 32'h00ffffff;
								state <= STATE_IDLE;		
							end
						end
					endcase
					
					rpc_message_pending <= 0;
					rpc_fab_rx_done <= 1;
				end				
				
			end	//end STATE_ALLOC_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Idle, wait for commands
			
			STATE_IDLE: begin
			
				function_call_busy <= 0;
			
				if(!drx_en)
					drx_ready <= 1;
			
				//See if we should retry a failed allocation
				if(!ram_write_ptr_valid) begin
					oom_retry_count <= oom_retry_count - 24'h1;
					if(oom_retry_count == 1)
						state <= STATE_ALLOC_0;
				end
			
				//Process incoming frames (top priority)
				if(rx_buffer_ready_sync || rx_frame_pending) begin
				
					rx_frame_pending <= 0;
				
					if(ram_write_ptr_valid) begin
						function_call_busy <= 1;
						
						ethertype_table_bucket <= process_ethertype[3:0];
						ethertype_table_row <= 0;
						state <= STATE_RX_TYPELOOKUP;
					end
					
					else begin
						//Out of memory, nowhere to put the packet
						//We have no choice but to drop it
						rx_buffer_done <= 1;
					end
					
				end
			
				//Process RPC commands
				else if(rpc_message_ready) begin
					
					rpc_message_pending <= 0;
					
					case(rpc_fab_rx_type)
					
						//Ignore
						RPC_TYPE_RETURN_FAIL: begin
							rpc_fab_rx_done <= 1;
						end
						
						//Ignore
						RPC_TYPE_RETURN_SUCCESS: begin
							rpc_fab_rx_done <= 1;
						end
						
						//Remote procedure call - deal with it
						RPC_TYPE_CALL: begin
						
							//Currently processing a function call
							function_call_busy <= 1;
						
							case(rpc_fab_rx_callnum)
					
								//Reset the MAC
								ETH_RESET: begin
									mac_reset_raw <= 1;
									state <= STATE_RESET_0;
								end	//end ETH_RESET
								
								//Register a new ethertype
								ETH_REGISTER_TYPE: begin
									
									//Read all four rows of the table in sequence to see if this value is already in use
									ethertype_table_bucket <= rpc_fab_rx_d0[3:0];
									ethertype_table_row <= 0;
									
									//Load all of the values in case a write is necessary
									ethertype_table_wr_valid <= 1;
									ethertype_table_wr_owner <= rpc_fab_rx_src_addr;
									ethertype_table_wr_tag <= rpc_fab_rx_d0[15:4];
									
									//Default to all sets free
									ethertype_table_free_sets <= 4'b1111;
									
									state <= STATE_REGISTER_0;
									
								end	//end ETH_REGISTER_TYPE
								
								//Set our MAC address
								ETH_SET_MAC: begin
									client_mac_address[47:32] <= rpc_fab_rx_d0[15:0];
									client_mac_address[31:0] <= rpc_fab_rx_d1;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
									state <= STATE_RPC_TXHOLD;
								end	//end ETH_SET_MAC
								
								//Set the destination MAC address
								ETH_SET_DSTMAC: begin
									dst_mac_address[47:32] <= rpc_fab_rx_d0[15:0];
									dst_mac_address[31:0] <= rpc_fab_rx_d1;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
									state <= STATE_RPC_TXHOLD;
								end	//end ETH_SET_DSTMAC
								
								//Get NIC status
								ETH_GET_STATUS: begin
								
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_d0 <= {28'h0, link_speed, duplex_state_sync, link_state_sync};
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
									state <= STATE_RPC_TXHOLD;

								end	//end ETH_GET_STATUS
								
								//Send a frame
								ETH_SEND_FRAME: begin
									
									//Issue the DMA read
									//Round the DMA read up to the nearest multiple of 4 words
									dtx_dst_addr <= rpc_fab_rx_d0[15:0];
									dtx_addr <= rpc_fab_rx_d1;
									dtx_len <= rpc_fab_rx_d2[9:0];
									if(rpc_fab_rx_d2[1:0] != 0)
										dtx_len <= {rpc_fab_rx_d2[9:2] + 8'h1, 2'b00};
									dtx_op <= DMA_OP_READ_REQUEST;
									dtx_en <= 1;
									state <= STATE_READ_PENDING;
									
									//Save stuff for return
									call_source_address <= rpc_fab_rx_src_addr;
									tx_ethertype <= rpc_fab_rx_d2[31:16];
									
									//Save frame length
									tx_frame_wordsize <= rpc_fab_rx_d2[9:0];
									
									//Done with the call request, we need to be able to get interrupts
									rpc_fab_rx_done <= 1;
									
								end	//end ETH_SEND_FRAME
								
								//Anything else? NAK it
								default: begin
									rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
									rpc_fab_tx_d0 <= {rpc_fab_rx_en, rpc_message_pending};
									rpc_fab_tx_d1 <= 'hbaadbaad;
									rpc_fab_tx_d2 <= rpc_fab_rx_callnum;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
									state <= STATE_RPC_TXHOLD;
								end
							endcase
						end	//end RPC_TYPE_CALL
						
						//Ignore
						default: begin
							rpc_fab_rx_done <= 1;
						end
					
					endcase					
				end
				
				//TODO: Process inbound DMA commands (if any)
				
				//Link state changed, send interrupt
				else if(link_state_changed) begin
					rpc_fab_tx_dst_addr <= reset_source;
					rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_callnum <= ETH_LINK_STATE;
					rpc_fab_tx_d0 <= {link_speed, duplex_state_sync, link_state_sync};
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					
					clear_link_state_changed <= 1;
									
					state <= STATE_RPC_TXHOLD;
				end
				
			end //end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// ETH_REGISTER_TYPE RPC call
			
			STATE_REGISTER_0: begin
			
				//If the table row is used, mark it as such
				if(ethertype_table_rd_valid) begin
				
					//Cache hit? Someone else owns our type, report failure
					if(ethertype_table_rd_tag == ethertype_table_wr_tag) begin
						rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
						rpc_fab_tx_d0 <= 1;
						rpc_fab_tx_d1 <= 0;
						rpc_fab_tx_d2 <= 0;
						rpc_fab_tx_en <= 1;
						
						rpc_fab_rx_done <= 1;
					
						state <= STATE_RPC_TXHOLD;
					end
					
					//Used, but not by this type - mark it as used
					else
						ethertype_table_free_sets[ethertype_table_row] <= 0;
				
				end

				//If we have more rows to read, do them
				if(ethertype_table_row != 3)
					ethertype_table_row <= ethertype_table_row + 2'h1;
					
				//Last row, process it
				else
					state <= STATE_REGISTER_1;
				
			end	//end STATE_REGISTER_0
			
			STATE_REGISTER_1: begin
			
				//If all sets are used we can't fit this ethertype, sorry :(
				if(ethertype_table_free_sets == 0) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
					rpc_fab_tx_d0 <= 2;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					
					rpc_fab_rx_done <= 1;
				
					state <= STATE_RPC_TXHOLD;
				end
				
				//Nope, writeback time :)
				else begin
				
					//Do the actual writeback, selecting the next free set
					ethertype_table_wr_en <= 1;
					if(ethertype_table_free_sets[0])
						ethertype_table_row <= 0;
					else if(ethertype_table_free_sets[1])
						ethertype_table_row <= 1;
					else if(ethertype_table_free_sets[2])
						ethertype_table_row <= 2;
					else
						ethertype_table_row <= 3;
						
					//Report success
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;						
					rpc_fab_rx_done <= 1;
				
					//We're done
					state <= STATE_RPC_TXHOLD;
				
				end
			
			end	//end STATE_REGISTER_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Frame receive logic
			
			//Look up which PID owns this ethertype
			STATE_RX_TYPELOOKUP: begin
				
				//Hit! Process the frame
				if(ethertype_table_rd_valid && (ethertype_table_rd_tag == process_ethertype[15:4]) ) begin
					state <= STATE_RX_NOTIFY_0;
				end
				
				//Miss
				else begin
				
					//If we just read the last set, nobody is registered as handling this ethertype. Drop the frame.
					if(ethertype_table_row == 3) begin

						//Tell rx logic we're done with this frame
						rx_buffer_done <= 1;
						
						state <= STATE_IDLE;
					end
						
					//If not, try reading the next one.
					else
						ethertype_table_row <= ethertype_table_row + 2'h1;
				
				end
				
			end	//end STATE_RX_TYPELOOKUP
			
			//DMA the frame to DRAM
			STATE_RX_NOTIFY_0: begin
				dtx_dst_addr <= ram_address;
				dtx_addr <= ram_write_ptr;
				dtx_len <= 512;	//rx_process_frame_len;
								//TODO: This value is WRONG at this time - why?
				dtx_op <= DMA_OP_WRITE_REQUEST;
				dtx_en <= 1;			
				state <= STATE_RX_NOTIFY_1;
			end	//end STATE_RX_NOTIFY_0
			
			//DMA write done, block until the write has committed
			STATE_RX_NOTIFY_1: begin

				if(ram_writedone)
					state <= STATE_RX_NOTIFY_2;

			end	//end STATE_RX_NOTIFY_1
			
			//Chown the page to the new owner
			STATE_RX_NOTIFY_2: begin
				if(!rpc_fab_tx_en && !rpc_tx_busy) begin
				
					//Tell rx logic we're done with this frame
					rx_buffer_done <= 1;
				
					//Do the chown
					rpc_fab_tx_type <= RPC_TYPE_CALL;
					rpc_fab_tx_callnum <= RAM_CHOWN;
					rpc_fab_tx_dst_addr <= ram_address;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= ram_write_ptr;
					rpc_fab_tx_d2 <= ethertype_table_rd_owner;
					rpc_fab_tx_en <= 1;
					state <= STATE_RX_NOTIFY_3;
				end				
			end	//end STATE_RX_NOTIFY_2
			STATE_RX_NOTIFY_3: begin
			
				if(rpc_message_ready) begin
					
					case(rpc_fab_rx_type)
						RPC_TYPE_RETURN_SUCCESS: begin
							state <= STATE_RX_NOTIFY_4;
						end
						RPC_TYPE_RETURN_RETRY: begin
							state <= STATE_RX_NOTIFY_2;
						end
						RPC_TYPE_RETURN_FAIL: begin
							if(rpc_fab_rx_src_addr == ethertype_table_rd_owner)	//TODO: if chown failed, decide what to do
								state <= STATE_IDLE;							//This should never happen
						end
						
					endcase
					
					rpc_message_pending <= 0;
					rpc_fab_rx_done <= 1;
				end				
			end	//end STATE_RX_NOTIFY_3
			
			//Send the interrupt to the new page owner
			//Then allocate a new page of RAM for us to store the next packet into
			STATE_RX_NOTIFY_4: begin
				if(!rpc_fab_tx_en && !rpc_tx_busy) begin
					rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_callnum <= ETH_FRAME_READY;
					rpc_fab_tx_dst_addr <= ethertype_table_rd_owner;
					rpc_fab_tx_d0 <= rx_process_frame_len;
					rpc_fab_tx_d1 <= ram_write_ptr;
					rpc_fab_tx_d2 <= {process_ethertype, ram_address};
					rpc_fab_tx_en <= 1;	
					
					ram_write_ptr_valid <= 0;
					
					state <= STATE_ALLOC_0;
				end								
			end	//end STATE_RX_NOTIFY_4
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Transmit control logic
		
			STATE_READ_PENDING: begin
				
				//RPC messages - ignore everything but interrupts
				if(rpc_message_ready) begin
					rpc_message_pending <= 0;

					case(rpc_fab_rx_type)
						
						//Interrupt might be a fail alert from the RAM
						RPC_TYPE_INTERRUPT: begin
							if( (rpc_fab_rx_src_addr == ram_address) && (rpc_fab_rx_callnum == RAM_OP_FAILED)) begin
							
								//Return fail to the caller
								rpc_fab_tx_dst_addr <= call_source_address;
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								rpc_fab_tx_callnum <= ETH_SEND_FRAME;
								rpc_fab_tx_d0 <= {4'hC, rpc_fab_rx_src_addr};
								rpc_fab_tx_d1 <= rpc_fab_rx_d1;
								rpc_fab_tx_d2 <= rpc_fab_rx_d2;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
								//can't free, we weren't able to do the read
								
							end
						end
						
						//Ignore everything else
						default: begin
						end
						
					endcase

				end
			
				//DMA message - should be data
				else if(drx_en || dma_message_pending) begin

					dma_message_pending <= 0;
				
					//If it's not from the ram, ignore it
					if( (drx_src_addr != ram_address) || (drx_op != DMA_OP_READ_DATA) ) begin
						//nothing to do
					end
					
					//Data from the RAM
					else begin
		
						//We're busy... don't want any more DMA traffic coming in
						drx_ready <= 0;
						
						//Tell the transmit logic we're ready to send
						tx_buffer_ready <= 1;
						state <= STATE_TX_ACTIVE;
						
					end

				end
				
			end	//end STATE_READ_PENDING
			
			//Wait for the transmit clock domain to finish doing stuff
			STATE_TX_ACTIVE: begin
			
				//Ignore incoming RPC messages, let the idle state handle them when we return
			
				//TODO: handle failures coming back from tx logic (if this is even possible)
				//If link is down, return error
				if(tx_buffer_done_sync) begin
					rpc_fab_tx_dst_addr <= call_source_address;
					if(!link_state_sync)
						rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
					else
						rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
					rpc_fab_tx_callnum <= ETH_SEND_FRAME;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_FREE;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for the RPC network to be clear, then free() the current page
			
			STATE_FREE: begin
			
				if(rpc_fab_tx_done) begin
					
					rpc_fab_tx_dst_addr <= ram_address;		//send to the RAM, which is presuambly where we DMA'd from
					rpc_fab_tx_type <= RPC_TYPE_CALL;
					rpc_fab_tx_callnum <= RAM_FREE;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= dtx_addr;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					//state <= STATE_RPC_TXHOLD;
					
					state <= STATE_FREE_WAIT;
					
				end
				
			end	//end STATE_FREE
			
			STATE_FREE_WAIT: begin
			
				if(rpc_message_ready) begin
				
					rpc_message_pending <= 0;
					rpc_fab_rx_done <= 1;
				
					//Successful free? We're done
					if( (rpc_fab_rx_type == RPC_TYPE_RETURN_SUCCESS) && (rpc_fab_rx_src_addr == dtx_dst_addr) )
						state <= STATE_IDLE;
					
					//Failed free? Nothing we can do
					else if( (rpc_fab_rx_type == RPC_TYPE_RETURN_FAIL) && (rpc_fab_rx_src_addr == dtx_dst_addr) )
						state <= STATE_IDLE;
					
					//Retry? Send it again
					else if( (rpc_fab_rx_type == RPC_TYPE_RETURN_RETRY) && (rpc_fab_rx_src_addr == dtx_dst_addr) )
						state <= STATE_FREE;
					
					//Pending function call? Return retry
					else if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						rpc_fab_tx_type <= RPC_TYPE_RETURN_RETRY;
						rpc_fab_tx_d0 <= 0;
						rpc_fab_tx_d1 <= 0;
						rpc_fab_tx_d2 <= 0;
						rpc_fab_tx_en <= 1;
					end
					
					//Ignore anything else
				
				end
			
			end	//end STATE_FREE_WAIT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Transmit delay
			STATE_RPC_TXHOLD: begin
				if(rpc_fab_tx_done)
					state <= STATE_IDLE;
			end	//end STATE_RPC_TXHOLD

		endcase
		
	end
	
endmodule
