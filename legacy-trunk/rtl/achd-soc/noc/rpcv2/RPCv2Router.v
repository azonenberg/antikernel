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
	@brief 4-port (plus upstream) NoC router for the RPC network, protocol version 2.

	Consists of 5 modules per channel:
		
		* Transceiver
		  Serializes/deserializes packets to/from buffer SRAM and controls retransmit/acknowledgement stuff.
	
		  Properties proven:
			* Follows RPC protocol specification on both input and output.
			* Writes packets to SRAM properly when they arrive
			* Reads packets from SRAM properly during send
		
		* Packet buffer SRAM
		    * Hard IP in FPGA, assumed correct.
		    
		* Crossbar mux
		  Just a 32-bit 5:1 mux. Takes output data from each SRAM buffer and picks one word to send to the transceiver.
	
		  Properties proven:
		    * Output is zero if muxsel is not in [0, 4]
		    * Output is corresponding input if muxsel is valid
		
		* Arbiter
		  Given the inbox-full flags and destination addresses for each port, determine a) whether we should start
		  sending a packet and b) if so, which buffer to read from.

		  Properties proven:
		    * Tie-breaking is fair: no matter what the network load is, every port gets a chance to send eventually.
		    * When not transmitting, tx_en is 0 and selected_sender is 5
		    * tx_en goes true for one cycle when all of the below are true:
				* We're idle
				* At least one port has a full inbox
				* Their destination address matches us
		    * selected_sender is the index of a port that was sending to us. Make no assumptions about tie-breaking if
		      multiple packets are destined to us.
		    * While packet is being transmitted, selected_sender does not change and tx_en stays low
		    * When tx_done goes high, return to idle state
		
		* Read tracking
		  Sets the "rx done" flag when the destination of our current packet sets its "tx done" flag.
		  Check arbiter output for each port, if they're trying to read from us then set SRAM address input to their
		  transceiver's read address.
		  Properties proven:
		    * port_fab_rx_done is asserted for one, and only one, cycle if any port_fab_tx_done[x] is asserted and
			  port_selected_sender[x] is equal to the current port number
		    * If a port is reading, and their selected sender is us, port_rdbuf_addr will be set to that port's tx_raddr		
 */
module RPCv2Router(
	clk,
	port_rx_en, port_rx_data, port_rx_ack,
	port_tx_en, port_tx_data, port_tx_ack
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations

	//System-synchronous clock
	input wire clk;
	
	//Number of downstream ports (upstream not included in total)
	parameter PORT_COUNT				= 4;
	
	//Number of total ports including upstream
	localparam TOTAL_PORT_COUNT			= PORT_COUNT + 1;
	
	//Inbound port
	output wire[TOTAL_PORT_COUNT-1:0]		port_tx_en;
	output wire[TOTAL_PORT_COUNT*32 - 1:0]	port_tx_data;
	input wire[TOTAL_PORT_COUNT*2 - 1:0]	port_tx_ack;
	
	//Outbound port
	input wire[TOTAL_PORT_COUNT-1:0]		port_rx_en;
	input wire[TOTAL_PORT_COUNT*32 - 1:0]	port_rx_data;
	output wire[TOTAL_PORT_COUNT*2 - 1:0]	port_rx_ack;
	
	//Bitmap of disabled ports
	parameter PORT_DISABLE = 5'h0;
	
	//Addressing
	parameter SUBNET_MASK = 16'hFFFC;	//default to /14 subnet
	parameter SUBNET_ADDR = 16'h8000;	//first valid subnet address
	parameter HOST_BIT_HIGH = 1;		//host bits
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Internal ports on transceivers
	
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_tx_en;
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_tx_done;
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_tx_rd_en;
	wire[TOTAL_PORT_COUNT*2 - 1 : 0]	port_fab_tx_raddr;
	wire[TOTAL_PORT_COUNT*32 - 1 : 0] 	port_fab_tx_rdata;
	
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_rx_en;
	wire[TOTAL_PORT_COUNT*16 - 1 : 0]	rpc_fab_rx_dst_addr;
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_rx_we;
	wire[TOTAL_PORT_COUNT*2 - 1 : 0] 	port_fab_rx_waddr;
	wire[TOTAL_PORT_COUNT*32 - 1 : 0]	port_fab_rx_wdata;
	wire[TOTAL_PORT_COUNT-1:0]			port_fab_rx_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Actual port logic
	
	//port_selected_sender[3*x +: 3] is the port that should be sending to port x
	wire[3*TOTAL_PORT_COUNT - 1 : 0]	port_selected_sender;
	
	//Read addresses and data for each port
	wire[1:0]							port_rdbuf_addr[TOTAL_PORT_COUNT-1:0];
	wire[TOTAL_PORT_COUNT*32 - 1:0]		port_rdbuf_out;
	
	//Indicates which ports currently have messages sitting in their buffers
	wire[TOTAL_PORT_COUNT-1:0]	port_inbox_full;
	
	//Unused, but need to loop stuff back on the SDP sram in order to keep the compiler from warning for no reason
	wire[3:0] unused[TOTAL_PORT_COUNT-1:0];
	
	genvar i;
	generate
		
		//Port logic
		for(i=0; i<TOTAL_PORT_COUNT; i = i+1) begin : ports
				
			//If port is unused, set all the lines to default state (zero)
			if(PORT_DISABLE[i]) begin
			
				assign port_inbox_full[i]				= 0;
			
				assign port_selected_sender[i*3 +: 3]	= 0;
				assign port_fab_tx_en[i]				= 0;
				assign port_fab_tx_rdata[i*32 +: 32]	= 0;
				assign port_rdbuf_out[i*32 +: 32]		= 0;
				assign unused[i]						= 0;
			
				assign port_fab_tx_done[i]				= 1'h0;
				assign port_fab_tx_rd_en[i]				= 1'h0;
				assign port_fab_tx_raddr[i*2 +: 2]		= 2'h0;
				
				assign port_tx_en[i]					= 1'h0;
				assign port_tx_data[i*32 +: 32]			= 32'h0;
				assign port_rx_ack[i*2 +: 2]			= 2'h0;
				
				assign port_fab_rx_en[i]				= 1'h0;
				assign rpc_fab_rx_dst_addr[i*16 +: 16]	= 32'h0;
				assign port_fab_rx_we[i]				= 1'h0;
				
				assign port_fab_rx_waddr[i*2 +: 2]		= 2'h0;
				assign port_fab_rx_wdata[i*32 +: 32]	= 32'h0;
				
				assign port_fab_rx_done[i]				= 1'b0;
			
			end
			
			//Otherwise have actual logic
			else begin
			
				//Transceiver
				RPCv2RouterTransceiver #(
					.LEAF_PORT(0),
					.LEAF_ADDR(0)
				) txvr (
					
					.clk(clk),
					
					.rpc_tx_en(port_tx_en[i]),
					.rpc_tx_data(port_tx_data[i*32 +: 32]),
					.rpc_tx_ack(port_tx_ack[i*2 +: 2]),
					
					.rpc_rx_en(port_rx_en[i]),
					.rpc_rx_data(port_rx_data[i*32 +: 32]),
					.rpc_rx_ack(port_rx_ack[i*2 +: 2 ]),
					
					.rpc_fab_tx_en(port_fab_tx_en[i]),
					.rpc_fab_tx_rd_en(port_fab_tx_rd_en[i]),
					.rpc_fab_tx_raddr(port_fab_tx_raddr[i*2 +: 2]),
					.rpc_fab_tx_rdata(port_fab_tx_rdata[i*32 +: 32]),
					.rpc_fab_tx_done(port_fab_tx_done[i]),
					
					.rpc_fab_rx_en(port_fab_rx_en[i]),
					.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr[i*16 +: 16]),
					.rpc_fab_rx_we(port_fab_rx_we[i]),
					.rpc_fab_rx_waddr(port_fab_rx_waddr[i*2 +: 2]),
					.rpc_fab_rx_wdata(port_fab_rx_wdata[i*32 +: 32]),
					.rpc_fab_rx_done(port_fab_rx_done[i]),
					.rpc_fab_inbox_full(port_inbox_full[i])
				);
				
				//Packet buffer SRAM
				LutramMacroSDP #(
					.WIDTH(36),
					.DEPTH(32),
					.OUTREG(1)
				) inbox (
					.clk(clk),
					.porta_we(port_fab_rx_we[i]),
					.porta_addr({3'b0, port_fab_rx_waddr[i*2 +: 2]}),
					.porta_din({unused[i], port_fab_rx_wdata[i*32 +: 32]}),
					
					.portb_addr({3'b0, port_rdbuf_addr[i]}),
					.portb_dout({unused[i], port_rdbuf_out[i*32 +: 32]})
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
					.port_dst_addr(rpc_fab_rx_dst_addr),
					.tx_en(port_fab_tx_en[i]),
					.tx_done(port_fab_tx_done[i]),
					.selected_sender(port_selected_sender[3*i +: 3])
				);
				
				//Keep track of inbox state
				RPCv2RouterInboxTracking #(
					.PORT_COUNT(PORT_COUNT),
					.THIS_PORT(i)
				) inbox_tracker (
					.clk(clk),
					.port_selected_sender(port_selected_sender),
					.port_fab_tx_rd_en(port_fab_tx_rd_en),
					.port_fab_tx_raddr(port_fab_tx_raddr),
					.port_fab_tx_done(port_fab_tx_done),
					.port_fab_rx_done(port_fab_rx_done[i]),
					.port_rdbuf_addr(port_rdbuf_addr[i])
				);
				
				//The actual crossbar mux
				NOCMux #(
					.WIDTH(32),
					.PORT_COUNT(PORT_COUNT)
				) txmux (
					.sel(port_selected_sender[3*i +: 3]),
					.din(port_rdbuf_out),
					.dout(port_fab_tx_rdata[i*32 +: 32])
				);
				
			end
			
		end
	
	endgenerate
	
endmodule
