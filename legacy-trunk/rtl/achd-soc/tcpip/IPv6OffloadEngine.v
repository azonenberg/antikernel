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

`default_nettype none

/**
	@file
	@author Andrew D. Zonenberg
	@brief IPv6 offload engine with integrated MAC instance
	
	@module
	@brief			IPv6 protocol offload
	@opcodefile		IPv6OffloadEngine_opcodes.constants
	
	@rpcfn			IPV6_OP_SET_MAC
	@param			mac			{d0[15:0],d1[31:0]}:mac			MAC address
	@brief			Sets the host's MAC address
	
	@rpcfn_ok		IPV6_OP_SET_MAC
	@brief			MAC address updated
	
	@rpcfn			IPV6_OP_GET_SUBNET
	@brief			Query current subnet
	
	@rpcfn_ok		IPV6_OP_GET_SUBNET
	@brief			Current SLAAC subnet prefix
	@param			prefixlen	d0[7:0]:dec						Prefix length
	@param			prefix		{d1[31:0],d2[31:0]}:ipv6		Subnet prefix
	
	@rpcfn			IPV6_OP_GET_GATEWAY
	@brief			Query router MAC address
	
	@rpcfn_ok		IPV6_OP_GET_GATEWAY
	@brief			Current SLAAC router MAC address
	@param			mac			{d0[15:0],d1[31:0]}:mac			MAC address
	
	@rpcint			IPV6_OP_NOTIFY_MAC
	@brief			Host MAC address has changed
	@param			mac			{d0[15:0],d1[31:0]}:mac			MAC address
	
	@rpcint			IPV6_OP_NOTIFY_PREFIX
	@brief			Host subnet prefix has changed
	@param			prefixlen	d0[7:0]:dec						Prefix length
	@param			prefix		{d1[31:0],d2[31:0]}:ipv6		Subnet prefix
	
	DMA pseudo-header format:
		Source MAC for incoming packets, or dest MAC for outgoing packets (two words, left-padded with zeroes)
		Payload length in octets (one word).
		Source IP (four words)
		Dest IP (four words)
 */
module IPv6OffloadEngine(

	//Clocks
	clk, clk_25mhz, clk_125mhz, gmii_rxc,
	
	//NoC interfaces
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//[R]GMII signals
	xmii_rxc, xmii_rxd, xmii_rx_ctl, xmii_txc, xmii_txd, xmii_tx_ctl,
	
	//[R]GMII management and reset signals
	mgmt_mdio, mgmt_mdc, reset_n, clkout,
	
	//SFP signals
	sfp_refclk,
	sfp_tx_p, sfp_tx_n,
	sfp_rx_p, sfp_rx_n
	);
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	//Clocks
	input wire	clk;
	input wire	clk_25mhz;
	input wire	clk_125mhz;
	output wire	gmii_rxc;
	
	//RPC interface
	parameter NOC_ADDR				= 16'h0000;
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;
	
	//DMA interface
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	//Set this to "RGMII", "GMII", or "SFP"
	parameter PHY_INTERFACE			= "INVALID";
	
	//[R]GMII interface, plus associated config settings
	//(see TriModeEthernetMAC for full documentation)
	parameter PHY_MD_ADDR			= 5'b00001;
	localparam DATA_WIDTH			= (PHY_INTERFACE == "RGMII") ? 4 : 8;
	localparam CTRL_WIDTH			= (PHY_INTERFACE == "RGMII") ? 1 : 2;
	input wire						xmii_rxc;
	input wire[DATA_WIDTH-1:0]		xmii_rxd;
	input wire[CTRL_WIDTH-1:0]		xmii_rx_ctl;
	output wire						xmii_txc;
	output wire[DATA_WIDTH-1:0]		xmii_txd;
	output wire[CTRL_WIDTH-1:0]		xmii_tx_ctl;
	inout wire						mgmt_mdio;
	output wire						mgmt_mdc;
	output wire						clkout;
	output wire						reset_n;
	parameter PHY_CHIPSET			= "INVALID";
	
	//SFP-specific signals
	input wire	sfp_refclk;
	output wire sfp_tx_p;
	output wire sfp_tx_n;
	input wire	sfp_rx_p;
	input wire	sfp_rx_n;
	
	//Default for backward compatibility
	parameter OUTPUT_PHASE_SHIFT = "DELAY";
	
	//Clock buffer type
	//default required for backward compatibility
	parameter CLOCK_BUF_TYPE = "GLOBAL";
	
	//Upper-level protocol stuff
	//Set to zero to disable this protocol
	parameter						ICMP_HOST	= 0;
	parameter						TCP_HOST	= 0;
	parameter						UDP_HOST	= 0;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers

	`include "DMARouter_constants.v"
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"

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
	wire		dtx_busy;
	reg[15:0]	dtx_dst_addr	= 0;
	reg[1:0]	dtx_op			= 0;
	reg[9:0]	dtx_len			= 0;
	reg[31:0]	dtx_addr		= 0;
	wire		dtx_en;
	wire		dtx_rd;
	wire[9:0]	dtx_raddr;
	reg[31:0]	dtx_buf_out		= 0;
	
	//DMA receive signals
	reg			drx_ready		= 1;
	wire		drx_en;
	wire[15:0]	drx_src_addr;
	wire[15:0]	drx_dst_addr;
	wire[1:0]	drx_op;
	wire[31:0]	drx_addr;
	wire[9:0]	drx_len;	
	reg			drx_buf_rd		= 0;
	reg[9:0]	drx_buf_addr	= 0;
	wire[31:0]	drx_buf_data;
	
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
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(gmii_rxc)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual MAC

	//Real signals
	wire		mac_reset;
	wire		mac_reset_done;
	
	//Status outputs (gmii_rxc domain)
	wire		link_state;
	wire		duplex_state;
	wire[1:0]	link_speed;
	
	//Receiver data outputs (gmii_rxc domain)
	wire		rx_frame_start;
	wire		rx_frame_data_valid;
	wire[31:0]	rx_frame_data;
	wire		rx_frame_done;
	wire		rx_frame_drop;
	
	//Transmitter data inputs (gmii_rxc domain)
	//Must run at a minimum of 8 bits per gmii_txc cycle with no gaps
	//to prevent buffer underruns
	reg[31:0]	tx_frame_data = 0;
	reg			tx_frame_data_valid		= 0;
	wire		tx_frame_done;
	
	//Our MAC address
	reg[47:0]	client_mac_address		= 0;
	
	//MAC address of the next frame to be sent
	reg[47:0]	dst_mac_address			= 0;
	
	//MAC address of the router
	reg[47:0]	gateway_mac_address		= 0;
	
	//Our local subnet prefix
	reg[63:0]	subnet_prefix			= 0;
	reg[7:0]	subnet_prefix_len		= 0;
	
	generate
	
		if(PHY_INTERFACE == "SFP") begin
		
			assign mgmt_mdio = 1'b0;
		
			GigabitEthernetMAC_SFP #(
				.AUTO_POR(1'b1),
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
				.AUTO_POR(1'b1),
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC state logic
	// For now, just accept incoming commands and respond immediately
	
	`include "IPv6OffloadEngine_opcodes_constants.v"
	`include "ICMPv6OffloadEngine_opcodes_constants.v"
	`include "IPv6OffloadEngine_rpc_states_constants.v"
	
	reg[1:0]	rpc_rx_state			= RPC_STATE_IDLE;
	
	reg			newmac_icmp				= 0;
	reg			newmac_tcp				= 0;
	
	always @(posedge clk) begin
	
		rpc_fab_tx_en		<= 0;
		rpc_fab_rx_done		<= 0;
	
		case(rpc_rx_state)
			
			//Wait for stuff to happen
			RPC_STATE_IDLE: begin
			
				//If we have a new MAC address, propagate it
				if(newmac_icmp && (ICMP_HOST != 0)) begin
					rpc_fab_tx_dst_addr	<= ICMP_HOST;
					rpc_fab_tx_type		<= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_callnum	<= IPV6_OP_NOTIFY_MAC;
					rpc_fab_tx_d0		<= client_mac_address[47:32];
					rpc_fab_tx_d1		<= client_mac_address[31:0];
					rpc_fab_tx_d2		<= 0;
					rpc_fab_tx_en		<= 1;
					rpc_rx_state		<= RPC_STATE_TXHOLD;
					newmac_icmp			<= 0;
				end
				else if(newmac_tcp && (TCP_HOST != 0)) begin
					rpc_fab_tx_dst_addr	<= TCP_HOST;
					rpc_fab_tx_type		<= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_callnum	<= IPV6_OP_NOTIFY_MAC;
					rpc_fab_tx_d0		<= client_mac_address[47:32];
					rpc_fab_tx_d1		<= client_mac_address[31:0];
					rpc_fab_tx_d2		<= 0;
					rpc_fab_tx_en		<= 1;
					rpc_rx_state		<= RPC_STATE_TXHOLD;
					newmac_tcp			<= 0;
				end
			
				else if(rpc_fab_inbox_full && !rpc_fab_rx_done) begin
								
					//Default return headers
					rpc_fab_tx_dst_addr	<= rpc_fab_rx_src_addr;
					rpc_fab_tx_type		<= RPC_TYPE_RETURN_FAIL;
					rpc_fab_tx_callnum	<= rpc_fab_rx_callnum;
					rpc_fab_tx_d0		<= 0;
					rpc_fab_tx_d1		<= 0;
					rpc_fab_tx_d2		<= 0;
					
					//Ignore anything but function calls
					case(rpc_fab_rx_type)
					
						RPC_TYPE_CALL: begin
						
							//Calls are single cycle
							rpc_fab_rx_done		<= 1;
						
							//Always requires a response
							rpc_fab_tx_en	<= 1;
							rpc_rx_state	<= RPC_STATE_TXHOLD;
							
							case(rpc_fab_rx_callnum)
								
								//Set our MAC address
								IPV6_OP_SET_MAC: begin
									client_mac_address[47:32]	<= rpc_fab_rx_d0[15:0];
									client_mac_address[31:0]	<= rpc_fab_rx_d1;
									rpc_fab_tx_type				<= RPC_TYPE_RETURN_SUCCESS;
									newmac_icmp					<= 1;
									newmac_tcp					<= 1;
								end	//IPV6_OP_SET_MAC
								
								//Get subnet prefix and mask
								IPV6_OP_GET_SUBNET: begin
									rpc_fab_tx_d0				<= subnet_prefix_len;
									rpc_fab_tx_d1				<= subnet_prefix[63:32];
									rpc_fab_tx_d2				<= subnet_prefix[31:0];
									rpc_fab_tx_type				<= RPC_TYPE_RETURN_SUCCESS;
								end	//IPV6_OP_GET_SUBNET
								
								//Get router MAC address
								IPV6_OP_GET_GATEWAY: begin
									rpc_fab_tx_d0				<= gateway_mac_address[47:32];
									rpc_fab_tx_d1				<= gateway_mac_address[31:0];
									rpc_fab_tx_type				<= RPC_TYPE_RETURN_SUCCESS;
								end	//IPV6_OP_GET_GATEWAY
								
								//Unrecognized call? Just return fail
								default: begin
								end
								
							endcase
							
						end	//RPC_TYPE_CALL
						
						//Separate state to reduce nested conditionals
						RPC_TYPE_INTERRUPT: begin
							rpc_rx_state <= RPC_STATE_INTERRUPT;
						end	//RPC_TYPE_INTERRUPT
						
						//Ignore anything else
						default: begin
							rpc_fab_rx_done		<= 1;
						end
						
					endcase
				
				end			
			end	//RPC_RX_STATE_IDLE
			
			//Process an interrupt
			RPC_STATE_INTERRUPT: begin
			
				//Flush rx buffer, whatever it is
				rpc_fab_rx_done		<= 1;
				
				//Done after this cycle
				rpc_rx_state <= RPC_STATE_IDLE;
			
				case(rpc_fab_rx_callnum)
					
					//Apply the new subnet prefix iff it came from the ICMP module
					ICMP_NEW_PREFIX: begin
						if(rpc_fab_rx_src_addr == ICMP_HOST) begin
							subnet_prefix_len	<= rpc_fab_rx_d0[7:0];
							subnet_prefix		<= {rpc_fab_rx_d1, rpc_fab_rx_d2};
							
							//Send the new subnet on to the TCP stack
							if(TCP_HOST != 0) begin
								rpc_fab_tx_en		<= 1;
								rpc_fab_tx_dst_addr	<= TCP_HOST;
								rpc_fab_tx_callnum	<= IPV6_OP_NOTIFY_PREFIX;
								rpc_fab_tx_type		<= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0		<= rpc_fab_rx_d0;
								rpc_fab_tx_d1		<= rpc_fab_rx_d1;
								rpc_fab_tx_d2		<= rpc_fab_rx_d2;
								rpc_rx_state		<= RPC_STATE_TXHOLD;
							end
							
						end
					end	//ICMP_NEW_PREFIX
					
					//Apply the new MAC iff it came from the ICMP module
					ICMP_NEW_ROUTERMAC: begin
						if(rpc_fab_rx_src_addr == ICMP_HOST)
							gateway_mac_address	<= {rpc_fab_rx_d0[15:0], rpc_fab_rx_d1};
					end	//ICMP_NEW_ROUTERMAC
				
				endcase

			end
			
			//Wait for packet to send
			RPC_STATE_TXHOLD: begin
				if(rpc_fab_tx_done)
					rpc_rx_state <= RPC_STATE_IDLE;
			end	//RPC_RX_STATE_TXHOLD
			
		endcase
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//  Reset the MAC during startup
	
	generate
	
		//GigabitEthernetMAC_SFP has internal auto-reset so use that instead
		if(PHY_INTERFACE == "SFP") begin
			assign mac_reset = 0;
		end
		
		else begin
		
			reg		mac_reset_ff	= 0;
			assign	mac_reset		= mac_reset_ff;
			reg		reset_completed = 0;
			
			always @(posedge clk_125mhz) begin
				mac_reset_ff <= 0;
				if(!reset_completed) begin
					mac_reset_ff <= 1;
					reset_completed <= 1;
				end
			end
			
		end
			
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Layer-2 inbound packet processing
	
	`include "IPv6OffloadEngine_rx_states_constants.v"
	`include "Ethertypes_constants.v"
	
	reg[1:0]		rx_state			= RX_STATE_IDLE;
	reg[1:0]		rx_count			= 0;
	
	reg[47:0]		rx_dst_mac			= 0;
	reg[47:0]		rx_src_mac			= 0;
	
	reg[15:0]		rx_frame_ethertype	= 0;
	reg[15:0]		frame_temp_data		= 0;
	
	reg			rx_l3_start			= 0;
	reg			rx_l3_done			= 0;
	
	reg			rx_frame_done_ff	= 0;
	reg			rx_frame_done_ff2	= 0;
	
	always @(posedge gmii_rxc) begin
		
		rx_l3_start 		<= 0;
		
		rx_frame_done_ff	<= rx_frame_done;
		rx_frame_done_ff2	<= rx_frame_done_ff;
		
		case(rx_state)
			
			//Wait for a packet to start
			RX_STATE_IDLE: begin
				rx_count <= 0;
				if(rx_frame_start)
					rx_state <= RX_STATE_ETH_HEADER;
			end
			
			//Read the Ethernet header
			RX_STATE_ETH_HEADER: begin
				if(rx_frame_data_valid) begin
					rx_count <= rx_count + 2'h1;
					case(rx_count)
					
						//High 2/3 of dest MAC
						0: 	begin
							rx_dst_mac[47:16] <= rx_frame_data;
						end
						
						//Low 1/3 of dest MAC, high 1/3 of source MAC
						1: begin
							rx_dst_mac[15:0] <= rx_frame_data[31:16];
							rx_src_mac[47:32] <= rx_frame_data[15:0];
						end
						
						//Low 2/3 of src MAC
						2: begin
						
							//If frame isn't addressed to us, or a broadcast/multicast frame, drop it
							if( (rx_dst_mac != client_mac_address) && (rx_dst_mac[40] == 0) )
								rx_state <= RX_STATE_DROP;
						
							rx_src_mac[31:0] <= rx_frame_data;
						end
						
						//Assume no vlan tag for now
						
						//Ethertype or length
						3: begin
							
							//Save the ethertype
							rx_frame_ethertype <= rx_frame_data[31:16];
								
							//Small value means it's a size
							//We don't support anything that isn't Ethernet II so drop the packet
							if(rx_frame_data[31:16] < 16'd1536)
								rx_state <= RX_STATE_DROP;
							else begin
								rx_l3_start <= 1;
								rx_state <= RX_STATE_DATA;
							end
								
							frame_temp_data <= rx_frame_data[15:0];
						end
					
					endcase
				end
			end
			
			RX_STATE_DATA: begin
				if(rx_frame_data_valid)
					frame_temp_data <= rx_frame_data[15:0];
			end
			
			//Packet was corrupted or failed the checksum verification, drop it
			RX_STATE_DROP: begin
			end
			
		endcase
		
		//Stop if we're done
		if(rx_frame_done_ff2)
			rx_state <= RX_STATE_IDLE;
		
		//If something went wrong, drop the frame
		else if(rx_frame_drop)
			rx_state <= RX_STATE_DROP;
		
	end
	
	//Apply 16-bit phase shift to incoming data
	reg[31:0]	rx_l3_data			= 0;
	reg 		rx_l3_valid			= 0;
	reg			rx_l3_drop			= 0;
	always @(posedge gmii_rxc) begin
		rx_l3_valid <= 0;

		if((rx_frame_data_valid || rx_frame_done) && (rx_state == RX_STATE_DATA)) begin
			rx_l3_valid <= 1;
			rx_l3_data <= {frame_temp_data, rx_frame_data[31:16]};
		end
		
		rx_l3_done <= rx_frame_done;
		rx_l3_drop <= rx_frame_drop;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Layer-3 inbound packet processing
	
	`include "IPv6OffloadEngine_l3_rx_states_constants.v"
	
	//Transport layer data (need to write this into a buffer and send it to DMA)
	reg			rx_l4_start			= 0;
	reg			rx_l4_valid			= 0;
	reg[31:0]	rx_l4_data			= 0;
	reg			rx_l4_done			= 0;
	reg			rx_l4_drop			= 0;
	
	reg[2:0]	rx_l3_state			= L3_RX_STATE_IDLE;
	reg[3:0]	rx_l3_count			= 0;
	reg[15:0]	rx_l3_payload_len	= 0;
	reg[7:0]	rx_l3_next_header	= 0;
	
	always @(posedge gmii_rxc) begin
		rx_l4_start <= 0;
		rx_l4_valid <= 0;
		rx_l4_done	<= 0;
		
		rx_l4_drop	<= rx_l3_drop;
		
		case(rx_l3_state)
			
			//Nothing going on
			L3_RX_STATE_IDLE: begin
				rx_l3_count <= 0;
			
				if(rx_l3_start) begin
					if(rx_frame_ethertype == ETHERTYPE_IPV6)
						rx_l3_state <= L3_RX_STATE_FIXED_HEADER;
					else
						rx_l3_state <= L3_RX_STATE_DROP;	//drop anything not IPv6 for now
															//(TODO: convert IPv4 to v6?)
				end
			
			end
			
			//Reading headers
			L3_RX_STATE_FIXED_HEADER: begin
				if(rx_l3_valid) begin
				
					rx_l3_count <= rx_l3_count + 4'h1;
				
					case(rx_l3_count)
						
						//Version, traffic class, flow label
						0: begin
							if(rx_l3_data[31:28] != 4'h6)
								rx_l3_state <= L3_RX_STATE_DROP;
						end
						
						//Payload length, next header, hop limit (ignored)
						1: begin
							rx_l3_payload_len <= rx_l3_data[31:16];
							rx_l3_next_header <= rx_l3_data[15:8];
							rx_l4_start <= 1;
						end
						
						//Addresses
						//2-5 are source, 6-9 are dest
						default: begin
							rx_l4_valid <= 1;
							rx_l4_data <= rx_l3_data;
							if(rx_l3_count == 9)
								rx_l3_state <= L3_RX_STATE_DATA;
						end
						
						//TODO: Drop packets not destined for our IPv6 address
						
					endcase
				
				end					
			end
			
			//Application-layer data
			//TODO: Handle other IPV6 headers before we get here
			L3_RX_STATE_DATA: begin
				if(rx_l3_valid) begin
					rx_l4_valid <= 1;
					rx_l4_data <= rx_l3_data;
				end
			end
			
			//Packet was corrupted, invalid, or failed the checksum verification, drop it
			L3_RX_STATE_DROP: begin
			end
			
		endcase
		
		//Stop if we're done
		if(rx_l3_done) begin
			rx_l4_done <= 1;
			rx_l3_state <= L3_RX_STATE_IDLE;
		end
		
		//If something went wrong, drop the frame
		else if(rx_l3_drop)
			rx_l3_state <= L3_RX_STATE_DROP;
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	// The DMA transmit buffer
	
	//The source address of the current packet's MAC
	reg[47:0]	rx_l4_src_mac	= 0;
	
	//Bank pointers for double buffering
	reg			dma_txbuf_write_bank	= 0;
	reg			dma_txbuf_read_bank		= 0;
	
	reg[31:0]	dma_txbuf[1023:0];
	
	integer i;
	initial begin
		for(i=0; i<1024; i = i+1)
			dma_txbuf[i] <= 0;
	end
	
	//Write logic
	reg[8:0]	dma_txbuf_wptr			= 0;
	wire[9:0]	dma_txbuf_waddr			= { dma_txbuf_write_bank, dma_txbuf_wptr };
	always @(posedge gmii_rxc) begin
		if(rx_l4_valid)
			dma_txbuf[dma_txbuf_waddr] <= rx_l4_data;
	end
	
	//Read logic
	wire[9:0]	dma_txbuf_raddr			= { dma_txbuf_read_bank, dtx_raddr[8:0] - 9'h3 };
	reg[31:0]	dtx_buf_out_raw			= 0;
	reg[8:0]	dtx_raddr_buf			= 0;
	always @(posedge clk) begin
		if(dtx_rd) begin
			dtx_buf_out_raw 			<= dma_txbuf[dma_txbuf_raddr];
			dtx_raddr_buf				<= dtx_raddr[8:0];
		end
	end
	
	always @(*) begin
		if(dtx_raddr_buf == 0)
			dtx_buf_out					<= { 16'h0, rx_l4_src_mac[47:32] };
		else if(dtx_raddr_buf == 1)
			dtx_buf_out					<= rx_l4_src_mac[31:0];
		else if(dtx_raddr_buf == 2)
			dtx_buf_out					<= rx_l3_payload_len;
		else
			dtx_buf_out					<= dtx_buf_out_raw;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Layer-4 packet processing is done externally
	// Just buffer the packet, then send it out the DMA interface.
	// The data we send is the source address, then the destination address, then packet contents.
	
	`include "IPProtocols_constants.v"
	`include "IPv6OffloadEngine_l4_rx_states_constants.v"
	
	reg		dtx_en_raw		= 0;
	
	//Synchronize DMA transmits to NoC clock domain
	wire	dtx_done		= (!dtx_en && !dtx_busy);
	wire	dtx_done_sync;
	HandshakeSynchronizer sync_reset
		(.clk_a(gmii_rxc),	.en_a(dtx_en_raw), 	.ack_a(dtx_done_sync), .busy_a(),
		 .clk_b(clk),	 	.en_b(dtx_en),		.ack_b(dtx_done));
		 
	//Double-buffering logic.
	//Messy stuff is needed to make sure we properly handle impossible cases (simultaneous alloc/free)
	//without inferring extra logic
	reg[1:0]	rx_buffer_in_use	= 0;
	reg			rx_buffer_alloc		= 0;
	reg			rx_buffer_alloc_ptr	= 0;
	reg			rx_buffer_free		= 0;
	reg			rx_buffer_free_ptr	= 0;
	always @(posedge gmii_rxc) begin

		if(rx_buffer_alloc)
			rx_buffer_in_use[rx_buffer_alloc_ptr] <= 1;
		
		if(rx_buffer_free)
			rx_buffer_in_use[rx_buffer_free_ptr] <= 0;
		
	end
		
	//Receive state machine
	reg[3:0]	rx_l4_state			= L4_RX_STATE_IDLE;
	reg[47:0]	rx_l4_src_mac_tmp	= 0;
	always @(posedge gmii_rxc) begin
	
		dtx_en_raw			<= 0;
		rx_buffer_alloc		<= 0;
		rx_buffer_free		<= 0;
	
		//Bump the write pointer any time a new layer-4 codeword comes in
		if(rx_l4_valid)
			dma_txbuf_wptr <= dma_txbuf_wptr + 9'h1;
			
		//Clear the buffer when we finish sending
		rx_buffer_free		<= dtx_done_sync;
		rx_buffer_free_ptr	<= dma_txbuf_read_bank;
	
		case(rx_l4_state)
		
			//Wait for a packet to arrive
			L4_RX_STATE_IDLE: begin
				if(rx_l4_start) begin
					dma_txbuf_wptr		<= 0;
					rx_l4_state			<= L4_RX_STATE_DATA;
					
					//Save MAC address immediately but dont overwrite the buffer we're sending from
					rx_l4_src_mac_tmp	<= rx_src_mac;
					
					//If nowhere to write to, give up (should never happen, we'll block in STATE_SEND)
					if(rx_buffer_in_use[dma_txbuf_write_bank])
						rx_l4_state <= L4_RX_STATE_DROP;
						
				end				
			end	//L4_RX_STATE_IDLE
			
			//Read the packet data
			L4_RX_STATE_DATA: begin
				//Read the packet body (done in buffer write logic)
				
				//If we're told to drop the packet, do so
				if(rx_l4_drop) begin
					if(rx_l4_done)
						rx_l4_state <= L4_RX_STATE_IDLE;
					else
						rx_l4_state <= L4_RX_STATE_DROP;
				end
					
				//If we're done receiving, send it!
				else if(rx_l4_done) begin
					rx_l4_state			<= L4_RX_STATE_SEND;
				end
				
			end	//L4_RX_STATE_DATA
			
			//Actually send the packet
			L4_RX_STATE_SEND: begin
				//If the transmitter isn't done with the last buffer, block until it is.
				if(!rx_buffer_in_use[dma_txbuf_read_bank]) begin
				
					//Ready to send, use the saved MAC address
					rx_l4_src_mac							<= rx_l4_src_mac_tmp;
					
					//Update bank settings
					//Write to new bank, read from the one we just wrote to
					rx_buffer_alloc							<= 1;
					rx_buffer_alloc_ptr						<= dma_txbuf_write_bank;
					dma_txbuf_write_bank					<= !dma_txbuf_write_bank;
					dma_txbuf_read_bank						<= dma_txbuf_write_bank;
					
					//Actually send it
					rx_l4_state			<= L4_RX_STATE_IDLE;
					dtx_en_raw			<= 1;
					
					//Write to address 0 for all packets
					dtx_addr			<= 0;
					dtx_op				<= DMA_OP_WRITE_REQUEST;
					
					//Packet length (in words)
					//4 words of IPv6 source address, 4 words of IPv6 dest address, 1 of length, then payload.
					//Round payload length (in octets) up to next word boundary.
					//The transport layer is responsible for trimming off trailing bytes if necessary.
					//Add two extra words at the beginning for the MAC address.
					if(rx_l3_payload_len[1:0])
						dtx_len			<= rx_l3_payload_len[10:2] + 12;
					else
						dtx_len			<= rx_l3_payload_len[10:2] + 11;
					
					//Find the upper-level protocol handler
					if( (rx_l3_next_header == IP_PROTOCOL_ICMPV6) && (ICMP_HOST != 0) )
						dtx_dst_addr	<= ICMP_HOST;
					else if( (rx_l3_next_header == IP_PROTOCOL_TCP) && (TCP_HOST != 0) )
						dtx_dst_addr	<= TCP_HOST;
					else if( (rx_l3_next_header == IP_PROTOCOL_UDP) && (UDP_HOST != 0) )
						dtx_dst_addr	<= UDP_HOST;
						
					//Drop the packet, it's not a recognized protocol or one we're interested in
					else begin
						rx_buffer_alloc		<= 0;
						dtx_en_raw			<= 0;
					end
					
					//Drop the packet if the payload is more than 1500 bytes in size (we don't handle jumbo frames
					//or fragmented packets)
					if(rx_l3_payload_len > 1500) begin
						rx_buffer_alloc		<= 0;
						dtx_en_raw			<= 0;
					end
					
				end
			end	//end L4_RX_STATE_SEND
						
			//Wait for a dropped packet to end
			L4_RX_STATE_DROP: begin
				if(rx_l4_done)
					rx_l4_state <= L4_RX_STATE_IDLE;
			end	//L4_RX_STATE_DROP
		
		endcase
		
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Layer-3 outbound packet parsing
	
	wire	drx_done;
	wire	drx_en_sync;
	reg		drx_done_raw		= 0;
	wire	drx_sync_busy;
	HandshakeSynchronizer synx_dma_rx
		(.clk_a(clk),			.en_a(drx_en), 			.ack_a(drx_done),	 .busy_a(drx_sync_busy),
		.clk_b(gmii_rxc),	 	.en_b(drx_en_sync),		.ack_b(drx_done_raw)			);
	
	//When an incoming packet comes in, block until it's sent
	always @(posedge clk) begin
		
		if(drx_en)
			drx_ready		<= 0;
			
		if(drx_done)
			drx_ready		<= 1;

	end
	
	//Save read flags
	reg[10:0]	drx_buf_addr_ff		= 0;
	reg			drx_buf_rd_buf			= 0;
	always @(posedge gmii_rxc) begin
		drx_buf_rd_buf			<= drx_buf_rd;
		if(drx_buf_rd)
			drx_buf_addr_ff		<= drx_buf_addr;
	end
	
	//Compute some meta-info for header
	reg[7:0]	tx_next_header			= 0;
	always @(*) begin

		tx_next_header			<= IP_PROTOCOL_NONE_V6;
		if(drx_src_addr == ICMP_HOST)
			tx_next_header		<= IP_PROTOCOL_ICMPV6;
		if(drx_src_addr == TCP_HOST)
			tx_next_header		<= IP_PROTOCOL_TCP;
		if(drx_src_addr == UDP_HOST)
			tx_next_header		<= IP_PROTOCOL_UDP;
		
	end
	
	//Ethernet clock domain
	`include "IPv6OffloadEngine_l3_tx_states_constants.v"
	reg[3:0] tx_l3_state	= L3_TX_STATE_IDLE;
	always @(posedge gmii_rxc) begin
		drx_done_raw		<= 0;
		tx_frame_data_valid	<= 0;
		
		drx_buf_rd			<= 0;
		
		case(tx_l3_state)
		
			//Wait for packets to come in
			L3_TX_STATE_IDLE: begin
			
				//New packet! 
				if(drx_en_sync) begin
				
					//From a known protocol stack? Process it
					if( (drx_src_addr == ICMP_HOST) || (drx_src_addr == TCP_HOST) || (drx_src_addr == UDP_HOST) ) begin
					
						//Simplify code and avoid the phase shift
						//by sending two zero bytes before the preamble
						tx_frame_data_valid		<= 1;
						tx_frame_data			<= 32'h00005555;	//preamble 0, 1
						tx_l3_state				<= L3_TX_STATE_EHDR_1;
						
						//Start reading the destination MAC address
						drx_buf_rd			<= 1;
						drx_buf_addr		<= 0;
						
					end
					
					//Nope, drop it
					else
						drx_done_raw		<= 1;

				end
			
			end	//L3_TX_STATE_IDLE
			
			//Second word of frame preamble
			L3_TX_STATE_EHDR_1: begin
				tx_frame_data_valid		<= 1;				
				tx_frame_data			<= 32'h55555555;	//preamble 2, 3, 4, 5
				tx_l3_state				<= L3_TX_STATE_EHDR_2;
				
				//Read the next word of the MAC
				drx_buf_rd			<= 1;
				drx_buf_addr		<= 1;
				
			end	//L3_TX_STATE_EHDR_1
			
			//Third word of frame preamble and SFD
			L3_TX_STATE_EHDR_2: begin
				tx_frame_data_valid		<= 1;
				tx_frame_data			<= {16'h55d5, drx_buf_data[15:0]};
				tx_l3_state				<= L3_TX_STATE_EHDR_3;
			end	//L3_TX_STATE_EHDR_2
			
			//Rest of dest MAC address
			L3_TX_STATE_EHDR_3: begin
				tx_frame_data_valid		<= 1;
				tx_frame_data			<= drx_buf_data;
				tx_l3_state				<= L3_TX_STATE_EHDR_4;
				
				//Read the length header
				drx_buf_rd			<= 1;
				drx_buf_addr		<= 2;
				
			end	//L3_TX_STATE_EHDR_3
			
			//Our MAC address
			L3_TX_STATE_EHDR_4: begin
				tx_frame_data_valid		<= 1;
				tx_frame_data			<= client_mac_address[47:16];
				tx_l3_state				<= L3_TX_STATE_EHDR_5;
			end	//L3_TX_STATE_EHDR_4
			
			//Our MAC address, second half plus ethertype
			L3_TX_STATE_EHDR_5: begin
				tx_frame_data_valid		<= 1;
				tx_frame_data			<= { client_mac_address[15:0], ETHERTYPE_IPV6 };
				tx_l3_state				<= L3_TX_STATE_HEADER_1;
			end	//L3_TX_STATE_EHDR_5
			
			L3_TX_STATE_HEADER_1: begin
			
				//Push the first IPv6 header - generic IPv6 (same for all packets)
				tx_frame_data_valid	<= 1;
				tx_frame_data		<= {4'h6, 8'h0, 20'h0};
				
				//Read the first data word
				drx_buf_rd			<= 1;
				drx_buf_addr		<= 3;
				
				//Go on to the packet data
				tx_l3_state 		<= L3_TX_STATE_HEADER_2;
			
			end	//L3_TX_STATE_HEADER_1
			
			//Transmit the second IPv6 header word
			L3_TX_STATE_HEADER_2: begin
			
				//Push the second header word
				tx_frame_data_valid		<= 1;
				tx_frame_data			<= { drx_buf_data[15:0], tx_next_header,  8'hff };	//TTL
				
				//Read the next data word
				drx_buf_rd				<= 1;
				drx_buf_addr			<= drx_buf_addr	+ 10'h1;
				
				//Go on to the packet body
				tx_l3_state				<= L3_TX_STATE_DATA;
			
			end	//L3_TX_STATE_HEADER_2
			
			//Transmit the packet body
			L3_TX_STATE_DATA: begin
				
				//Push the data
				tx_frame_data_valid		<= 1;
				tx_frame_data			<= drx_buf_data;
				
				//Read the next data word
				drx_buf_rd				<= 1;
				drx_buf_addr			<= drx_buf_addr	+ 10'h1;
				
				//If we just read the last word, stop
				if(drx_buf_addr == drx_len)
					tx_l3_state			<= L3_TX_STATE_WAIT;
				
			end	//L3_TX_STATE_DATA
			
			//Wait for the MAC
			L3_TX_STATE_WAIT: begin
				if(tx_frame_done) begin
					tx_l3_state			<= L3_TX_STATE_IDLE;
					drx_done_raw		<= 1;
				end
			end	//L3_TX_STATE_WAIT
		
		endcase
		
	end

endmodule
