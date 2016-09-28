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
	@brief Basic TCP offload engine for server applications
	
	TODO: Support client stuff
	
	Supports a power-of-two number (SOCKET_COUNT) of consecutive listening ports, starting at BASE_PORT,
	with one concurrent connection to each. Initiating outbound connections is not supported.
	
	Incoming packets are expected to arrive in order; we lack buffer space to store future packets so out-of-order
	packets are dropped and we wait for a retransmit. This should not be a major concern in LAN deployments.
	
	Receive buffer is RX_FIFO_DEPTH 32-bit words per socket.
	To read the receive buffer, issue a DMA read to {full port number, 16'h0000}. Only the registered owner
	of a port can read its data.
	
	To read N bytes of data, the read request must be for ceil(N/4) + 1 words. The first word of the received
	message is used as a length field to specify how many bytes were actually read (in case the last word does not
	contain four valid bytes).
	
	Note that if W words are requested, the actual data size returned may range from 0 (if the FIFO is empty)
	to 4*W bytes. The caller should be prepared to handle any amount of data in this range. The size returned may
	be larger (if new data has just arrived) or smaller (if data was read since) the size specified in the last
	TCP_INT_NEW_DATA interrupt.
	
	TODO: Describe transmit buffer
	
	@module
	@brief			TCP protocol offload
	@opcodefile		TCPOffloadEngine_opcodes.constants
	
	@rpcfn			TCP_OP_GET_PORTRANGE
	@brief			Returns the base port number and port count of this TCP offload engine
	
	@rpcfn_ok		TCP_OP_GET_PORTRANGE
	@brief			Port range info retrieved
	@param			nports		d0[15:0]:dec			Number of ports supported
	@param			baseport	d1[15:0]:dec			Base port number
	
	@rpcfn			TCP_OP_OPEN_SOCKET
	@brief			Binds a server socket
	@param			nport		d0[15:0]:dec			Port number to bind
	
	@rpcfn_ok		TCP_OP_OPEN_SOCKET
	@brief			Socket bound successfully
	
	@rpcfn_fail		TCP_OP_OPEN_SOCKET
	@brief			Socket could not be bound. Port number out of range or already bound
	
	@rpcfn			TCP_OP_CLOSE_SOCKET
	@brief			Closes a server socket
	@param			nport		d0[15:0]:dec			Port number to close
	
	@rpcfn_ok		TCP_OP_CLOSE_SOCKET
	@brief			Socket closed successfully
	
	@rpcfn_fail		TCP_OP_CLOSE_SOCKET
	@brief			Socket could not be closed. Port number out of range or already closed
	
	@rpcint			TCP_INT_NEW_DATA
	@brief			New data available
	@param			nport		d0[15:0]:dec			Port number of socket
	@param			nbytes		d1[31:0]:dec			Total number of bytes available to read
	
	@rpcint			TCP_INT_ACCESS_DENIED
	@brief			Access denied. An attempt was made to access a socket that the caller did not own.
	
	@rpcint			TCP_INT_SEND_DONE
	@brief			Indicates that the most recent DMA send has been processed
	
	@rpcint			TCP_INT_NO_DATA
	@brief			No data available for reading
	@param			nport		d0[15:0]:dec			Port number of socket
	
	@rpcint			TCP_INT_CONN_CLOSED
	@brief			Connection closed
	@param			nport		d0[15:0]:dec			Port number of socket
	
	@rpcint			TCP_INT_CONN_OPENED
	@brief			Connection opened
	@param			nport		d0[15:0]:dec			Port number of socket
 */
module TCPOffloadEngine(

	//Clocks
	clk,
	
	//NoC interfaces
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//Base port number (we listen on SOCKET_COUNT consecutive ports starting here)
	parameter BASE_PORT		= 16'h0;
	
	//Number of sockets we support
	parameter SOCKET_COUNT	= 16;
	
	//Depth of receive FIFO, in words
	parameter RX_FIFO_DEPTH = 1024;
	
	//Depth of transmit FIFO, in words
	parameter TX_FIFO_DEPTH = 1024;
	
	//number of bits in the address bus
	`include "../util/clog2.vh"
	localparam RX_ADDR_BITS = clog2(RX_FIFO_DEPTH);
	
	//Enable this to randomly drop ACK packets, simulating dropped packets
	parameter TEST_RETRANSMITS	= 0;
	
	//Configuration
	parameter IPV6_HOST				= 16'h0000;		//Address of IPv6 stack (TODO use name server?)
	parameter SOCKET_TIMEOUT_MS		= 15000;		//Time before a socket with no activity is closed
													//Default is 15 sec											
	parameter RETRANSMIT_TIMEOUT_MS	= 250;			//Time before a packet is declared "lost" and re-sent

	//Set to nonzero to delay transmit checks to 1 kHz to reduce spam on state variable
	parameter DEBUG_SLOW_TX			= 0;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers

	`include "DMARouter_constants.v"
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"

	reg			rpc_master_tx_en 		= 0;
	reg[15:0]	rpc_master_tx_dst_addr	= 0;
	reg[7:0]	rpc_master_tx_callnum	= 0;
	reg[2:0]	rpc_master_tx_type		= 0;
	reg[20:0]	rpc_master_tx_d0		= 0;
	reg[31:0]	rpc_master_tx_d1		= 0;
	reg[31:0]	rpc_master_tx_d2		= 0;
	wire		rpc_master_tx_done;
	
	wire		rpc_master_rx_en;
	wire[15:0]	rpc_master_rx_src_addr;
	wire[15:0]	rpc_master_rx_dst_addr;
	wire[7:0]	rpc_master_rx_callnum;
	wire[2:0]	rpc_master_rx_type;
	wire[20:0]	rpc_master_rx_d0;
	wire[31:0]	rpc_master_rx_d1;
	wire[31:0]	rpc_master_rx_d2;
	reg			rpc_master_rx_done		= 0;
	wire		rpc_master_inbox_full;
	
	reg			rpc_slave_tx_en 		= 0;
	reg[15:0]	rpc_slave_tx_dst_addr	= 0;
	reg[7:0]	rpc_slave_tx_callnum	= 0;
	reg[2:0]	rpc_slave_tx_type		= 0;
	reg[20:0]	rpc_slave_tx_d0			= 0;
	reg[31:0]	rpc_slave_tx_d1			= 0;
	reg[31:0]	rpc_slave_tx_d2			= 0;
	wire		rpc_slave_tx_done;
	
	wire		rpc_slave_rx_en;
	wire[15:0]	rpc_slave_rx_src_addr;
	wire[15:0]	rpc_slave_rx_dst_addr;
	wire[7:0]	rpc_slave_rx_callnum;
	//slave rx type is always RPC_TYPE_CALL
	wire[20:0]	rpc_slave_rx_d0;
	wire[31:0]	rpc_slave_rx_d1;
	wire[31:0]	rpc_slave_rx_d2;
	reg			rpc_slave_rx_done		= 0;
	wire		rpc_slave_inbox_full;
	
	RPCv2MasterSlave #(
		.LEAF_ADDR(NOC_ADDR),
		.DROP_MISMATCH_CALLS(1'b1)
	) rpc_txvr (
		//NoC interface
		.clk(clk),
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		//Master interface
		.rpc_master_tx_en(rpc_master_tx_en),
		.rpc_master_tx_dst_addr(rpc_master_tx_dst_addr),
		.rpc_master_tx_callnum(rpc_master_tx_callnum),
		.rpc_master_tx_type(rpc_master_tx_type),
		.rpc_master_tx_d0(rpc_master_tx_d0),
		.rpc_master_tx_d1(rpc_master_tx_d1),
		.rpc_master_tx_d2(rpc_master_tx_d2),
		.rpc_master_tx_done(rpc_master_tx_done),
		
		.rpc_master_rx_en(rpc_master_rx_en),
		.rpc_master_rx_src_addr(rpc_master_rx_src_addr),
		.rpc_master_rx_dst_addr(rpc_master_rx_dst_addr),
		.rpc_master_rx_callnum(rpc_master_rx_callnum),
		.rpc_master_rx_type(rpc_master_rx_type),
		.rpc_master_rx_d0(rpc_master_rx_d0),
		.rpc_master_rx_d1(rpc_master_rx_d1),
		.rpc_master_rx_d2(rpc_master_rx_d2),
		.rpc_master_rx_done(rpc_master_rx_done),
		.rpc_master_inbox_full(rpc_master_inbox_full),
		
		//Slave interface
		.rpc_slave_tx_en(rpc_slave_tx_en),
		.rpc_slave_tx_dst_addr(rpc_slave_tx_dst_addr),
		.rpc_slave_tx_callnum(rpc_slave_tx_callnum),
		.rpc_slave_tx_type(rpc_slave_tx_type),
		.rpc_slave_tx_d0(rpc_slave_tx_d0),
		.rpc_slave_tx_d1(rpc_slave_tx_d1),
		.rpc_slave_tx_d2(rpc_slave_tx_d2),
		.rpc_slave_tx_done(rpc_slave_tx_done),
		
		.rpc_slave_rx_en(rpc_slave_rx_en),
		.rpc_slave_rx_src_addr(rpc_slave_rx_src_addr),
		.rpc_slave_rx_dst_addr(rpc_slave_rx_dst_addr),
		.rpc_slave_rx_callnum(rpc_slave_rx_callnum),
		.rpc_slave_rx_d0(rpc_slave_rx_d0),
		.rpc_slave_rx_d1(rpc_slave_rx_d1),
		.rpc_slave_rx_d2(rpc_slave_rx_d2),
		.rpc_slave_rx_done(rpc_slave_rx_done),
		.rpc_slave_inbox_full(rpc_slave_inbox_full)
	);
	
	//DMA transmit signals
	wire		dtx_busy;
	reg[15:0]	dtx_dst_addr	= 0;
	reg[1:0]	dtx_op			= 0;
	reg[9:0]	dtx_len			= 0;
	reg[31:0]	dtx_addr		= 0;
	reg			dtx_en			= 0;
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
	
	wire[9:0]	drx_buf_addr_next	= drx_buf_addr + 10'h1;
	
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
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(clk)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transmit buffer for outbound packets
	
	reg[31:0] dma_txbuf[511:0];
	
	//Init
	integer i;
	initial begin
		for(i=0; i<512; i=i+1)
			dma_txbuf[i] <= 0;
	end
	
	//Write logic
	reg			dma_txbuf_we		= 0;
	reg[8:0]	dma_txbuf_waddr		= 0;
	reg[31:0]	dma_txbuf_wdata		= 0;
	always @(posedge clk) begin
		if(dma_txbuf_we)
			dma_txbuf[dma_txbuf_waddr] <= dma_txbuf_wdata;
	end
	
	//Read logic
	reg[31:0]	dma_txbuf_out	= 0;
	always @(posedge clk) begin
		if(dtx_rd)
			dma_txbuf_out <= dma_txbuf[dtx_raddr];
	end
	
	reg			dtx_rd_ff		= 0;
	reg[9:0]	dtx_raddr_ff	= 0;
	always @(posedge clk) begin
		dtx_rd_ff		<= dtx_rd;
		dtx_raddr_ff	<= dtx_raddr;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Mask off extra bits in the last word
	
	reg[15:0]	incoming_len			= 0;
	reg[31:0]	drx_buf_data_masked		= 0;
	
	always @(*) begin
		
		//If this is the last word, and the length isn't a multiple of 4, mask it off
		if(drx_buf_addr == drx_len) begin
			case(incoming_len[1:0])
				3:	drx_buf_data_masked		<= {drx_buf_data[31:8], 8'h0};
				2:	drx_buf_data_masked		<= {drx_buf_data[31:16], 16'h0};
				1:	drx_buf_data_masked		<= {drx_buf_data[31:24], 24'h0};
				0:	drx_buf_data_masked		<= drx_buf_data;
			endcase
		end
		
		//No masking
		else
			drx_buf_data_masked	<= drx_buf_data;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Inbound checksum calculation
	
	`include "IPProtocols_constants.v"
	
	reg			drx_buf_rd_ff		= 0;
	reg[9:0]	drx_buf_addr_ff	= 0;
	always @(posedge clk) begin
		drx_buf_rd_ff			<= drx_buf_rd;
		drx_buf_addr_ff		<= drx_buf_addr;
	end
	
	reg			rx_checksum_load;
	reg			rx_checksum_process;
	reg[31:0]	rx_checksum_din;
	wire[15:0]	rx_checksum_dout;
	reg			rx_checksum_match;
	InternetChecksum32bit rx_checksum_calc(
		.clk(clk),
		.load(rx_checksum_load),
		.process(rx_checksum_process),
		.din(rx_checksum_din),
		.sumout(rx_checksum_dout),
		.csumout()
	);
	
	always @(posedge clk) begin
		rx_checksum_load	<= 0;
		rx_checksum_process	<= 0;
		rx_checksum_din		<= 0;
		
		//When the packet first gets here, preload the checksum with zeroes
		if(drx_en) begin
			rx_checksum_load	<= 1;
			rx_checksum_din		<= 0;
		end
		
		//Feed the checksum when we get new data
		if(drx_buf_rd_ff) begin
		
			//Skip the MAC address
			rx_checksum_process	<= (drx_buf_addr_ff != 1);
		
			//During the first cycle, before we've read any data, append the next-header value
			if(drx_buf_addr_ff == 0)
				rx_checksum_din		<= IP_PROTOCOL_TCP;
			
			//Actual packet data or IP layer pseudo-headers
			if(drx_buf_addr_ff >= 2)
				rx_checksum_din		<= drx_buf_data_masked;
			
		end
		
		
	end
	
	always @(*) begin
		rx_checksum_match <= (rx_checksum_dout == 16'hffff);
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Outbound checksum calculation
	
	reg			tx_checksum_load		= 0;
	reg			tx_checksum_process		= 0;
	reg[31:0]	tx_checksum_din_fwd		= 0;
	reg[31:0]	dma_txbuf_wdata_ff		= 0;
	wire[15:0]	tx_checksum_dout;
	
	InternetChecksum32bit tx_checksum_calc(
		.clk(clk),
		.load(tx_checksum_load),
		.process(tx_checksum_process),
		.din(tx_checksum_din_fwd),
		.sumout(tx_checksum_dout),
		.csumout()
	);
	
	always @(posedge clk) begin
		
		tx_checksum_process				<= 0;
		if(dma_txbuf_we && (dma_txbuf_waddr >= 3) )
			tx_checksum_process			<= 1;
			
		dma_txbuf_wdata_ff				<= dma_txbuf_wdata;
	end
	
	always @(*) begin
	
		//Use special data for load (the next-header value since we always include that in our checksums)
		if(tx_checksum_load)
			tx_checksum_din_fwd			<= IP_PROTOCOL_TCP;
			
		//nope, just load whatever we just wrote to the packet
		else
			tx_checksum_din_fwd			<= dma_txbuf_wdata_ff;
			
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sequence number generation
	
	//This is the sequence number we will use to start a new connection
	reg[31:0]	next_sequence_num		= 1;
	
	//Run it through a LFSR to make a new random value
	always @(posedge clk) begin
		next_sequence_num <=
		{
			next_sequence_num[30:0],
			next_sequence_num[31] ^
				next_sequence_num[6] ^
				next_sequence_num[4] ^
				next_sequence_num[2] ^
				next_sequence_num[1] ^
				next_sequence_num[0]
		};
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Retransmit / shutdown timer 
	
	reg[31:0]	delay_count	= 0;
	reg[31:0]	delay_limit	= 32'h00020000;
	
	reg			delay_limit_update	= 0;
	
	//1 kHz timer
	reg			delay_wrap	= 0;
	
	always @(posedge clk) begin
		
		//Bump the counter
		delay_count	<= delay_count + 1;
		
		//If we updated the delay, reset the counter
		if(delay_limit_update)
			delay_count		<= 0;
		
		//If we hit the limit, wrap around
		delay_wrap	<= 0;
		if(delay_count == delay_limit) begin
			delay_count		<= 1;
			delay_wrap		<= 1;
		end
		
	end
	
	//Timer (milliseconds, wraps every 49.7 days)
	reg[31:0]	time_ms		= 0;
	always @(posedge clk) begin
		if(delay_wrap)
			time_ms		<= time_ms + 32'h1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Socket state tables
	
	//Forward declaration of main state stuff so we can look up things depending on state
	`include "TCPOffloadEngine_states_constants.v"
	reg[4:0]	state					= TCP_STATE_BOOT_0;
	
	localparam SOCKET_BITS	= clog2(SOCKET_COUNT);
	
	//16-bit versions of these temp values so we can explicitly truncate
	//(since xst doesn't like (foobar)[3:0]
	wire[15:0]				rx_dport1	= drx_buf_data[15:0] - BASE_PORT;
	wire[15:0]				rx_dport2	= drx_addr[31:16] - BASE_PORT;
	
	//Round-robin selector for upcoming transmits
	reg[SOCKET_BITS-1 : 0]	next_tx_sock	= 0;
	
	//Read control logic
	wire					socket_rd	= 
		((state == TCP_STATE_RX_READ) && (drx_buf_addr_ff == 11)) ||
		(state == TCP_STATE_IDLE) ||
		(state == TCP_STATE_FIFO_READ_0);
	reg[SOCKET_BITS-1:0]	dport_fwd	= 0;
	reg[SOCKET_BITS-1:0]	dport		= 0;
	always @(*) begin
		dport_fwd		<= 0;
		
		//Read the ownership table when a new packet comes in from the IP stack
		//but only after we know the port number
		if( (state == TCP_STATE_RX_READ) && (drx_buf_addr_ff == 11) )
			dport_fwd	<= rx_dport1[SOCKET_BITS-1:0];

		//May have two different reads in the idle state
		if(state == TCP_STATE_IDLE) begin
		
			//Read the ownership table when a new DMA write comes in
			if(dma_inbox_full || drx_en)
				dport_fwd	<= rx_dport2[SOCKET_BITS-1:0];
			
			//Check the ownership records from the next round-robin socket
			else
				dport_fwd	<= next_tx_sock;
				
		end

		//Read the ownership table when a FIFO read request comes in from the application layer
		if(state == TCP_STATE_FIFO_READ_0)
			dport_fwd	<= rx_dport2[SOCKET_BITS-1:0];
		
	end
	always @(posedge clk) begin
		if(socket_rd)
			dport			<= dport_fwd;
	end
	
	//Cross connection state for the server socket
	wire		socket_open_out;					//Indicates if we have an associated server
	wire[15:0]	socket_owner_out;					//Indicates the NoC address of our associated server
	
	//New state to be written
	reg[SOCKET_BITS-1 : 0]		handle_id			= 0;
	reg							handle_rd			= 0;
	reg							handle_update		= 0;
	reg							socket_open_next	= 0;
	reg[15:0]					socket_owner_next	= 0;
	
	//loopback for handle allocation tests
	wire						handle_open;
	wire[15:0]					handle_owner;
	
	wire[15:0]	rpc_dport_fwd			= rpc_slave_rx_d0 - BASE_PORT;
	
	//16		socket_open
	//15:0		socket_owner
	MemoryMacro #(
		.WIDTH(17),
		.DEPTH(SOCKET_COUNT),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) server_state_mem (
		
		.porta_clk(clk),
		.porta_en(handle_rd || handle_update),
		.porta_addr(handle_id),
		.porta_we(handle_update),
		.porta_din({socket_open_next, socket_owner_next}),		
		.porta_dout({handle_open, handle_owner}),
		
		.portb_clk(clk),
		.portb_en(socket_rd),
		.portb_addr(dport_fwd),
		.portb_we(1'b0),
		.portb_din(17'b0),
		.portb_dout({socket_open_out, socket_owner_out})
	);
	
	//Per-connection state for the client socket
	wire		socket_connected_out;				//Indicates if the socket is currently connected
	wire[15:0]	expected_source_port;				//Port number of the client (local is always dport + BASE_PORT)
	wire[31:0]	tx_seq_num_out;						//Next outbound sequence number
	wire[31:0]	expected_incoming_seq;				//Last inbound sequence number
	wire[31:0]	last_event;							//Time of the last event on this socket (in ms since boot)
	
	//New state to be written
	reg			socket_update			= 0;
	reg			socket_connected_next	= 0;
	reg[31:0]	tx_seq_num_next			= 0;
	reg[31:0]	expected_incoming_seq_next	= 0;
	
	//Observed fields for the current incoming segment
	reg[15:0]	tcp_len					= 0;
	reg[31:0]	incoming_seq			= 0;
	reg[31:0]	incoming_ack			= 0;
	reg[15:0]	packet_source_port		= 0;
	reg[15:0]	packet_dest_port		= 0;
	reg			flag_syn				= 0;
	reg			flag_ack				= 0;
	reg			flag_fin				= 0;
	reg			flag_rst				= 0;
	reg[4:0]	data_offset				= 0;		//This includes the pseudo header length
													//and is greater than the TCP header length
	
	reg			sending_rst				= 0;
	reg			good_packet				= 0;
	
	//Helper fields to determine if the incoming segment is for the active session
	reg			rx_sequence_match		= 0;
	reg			src_port_match			= 0;
	
	//Age of the current socket
	wire[31:0]	socket_age				= time_ms - last_event;
	
	//112:81	time_ms
	//80		socket_connected
	//79:64		remote_port
	//63:32		tx_seq_num
	//31:0		rx_seq_num
	MemoryMacro #(
		.WIDTH(113),
		.DEPTH(SOCKET_COUNT),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) client_state_mem (
		
		.porta_clk(clk),
		.porta_en(socket_update),
		.porta_addr(dport),
		.porta_we(socket_update),
		.porta_din(
			{
				time_ms,
				socket_connected_next,
				packet_source_port,
				tx_seq_num_next,
				expected_incoming_seq_next
			}),		
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(socket_rd),
		.portb_addr(dport_fwd),
		.portb_we(1'b0),
		.portb_din(113'b0),
		.portb_dout(
			{
				last_event,
				socket_connected_out,
				expected_source_port,
				tx_seq_num_out,
				expected_incoming_seq
			})
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RAM for storing client IP/MAC address associated with each socket
	
	//Need to store a total of six words (2 MAC + 4 IP) per socket
	//Allocate 8 words so we have room to expand in the future (plus nice power of two)
	//With 16 sockets that's 128 element depth, probably best to still use LUT RAM since we
	//will be using a lot of BRAM for packet buffers
	localparam IP_RAM_DEPTH = SOCKET_COUNT * 8;
	
	reg			client_addr_we		= 0;
	wire[31:0]	client_addr_wdata;
	reg[2:0]	client_addr_waddr	= 0;
	
	reg			client_addr_rd		= 0;
	reg[2:0]	client_addr_raddr	= 0;
	wire[31:0]	client_addr_rdata;
	
	//TODO: Small area gain from doing single port memory here?
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(IP_RAM_DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) client_addr_mem (
		
		.porta_clk(clk),
		.porta_en(client_addr_we),
		.porta_addr({dport, client_addr_waddr}),
		.porta_we(client_addr_we),
		.porta_din(client_addr_wdata),		
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(client_addr_rd),
		.portb_addr({dport, client_addr_raddr}),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(client_addr_rdata)
	);
	
	reg			client_addr_push		= 0;
	reg[31:0]	client_addr_pushdata	= 0;
	reg			client_addr_commit		= 0;
	
	reg			client_addr_pop			= 0;
	reg			client_addr_reset		= 0;
	
	wire[3:0]	client_addr_rsize;
	
	SingleClockFifo #(
		.WIDTH(32),
		.DEPTH(8),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_FULL(0)
	) client_addr_fifo (
		.clk(clk),
		.wr(client_addr_push),
		.din(client_addr_pushdata),
		.rd(client_addr_pop),
		.dout(client_addr_wdata),
		.overflow(),
		.underflow(),
		.empty(),
		.full(),
		.rsize(client_addr_rsize),
		.wsize(),
		.reset(client_addr_reset)
		);	
	
	reg		client_addr_updating	= 0;
	always @(posedge clk) begin
	
		client_addr_pop	<= 0;
		client_addr_we	<= 0;
	
		//Write popped data
		if(client_addr_pop) begin
			client_addr_waddr	<= client_addr_waddr + 1'h1;
			client_addr_we		<= 1;
		end
	
		if(client_addr_updating) begin
		
			//If we're popping and there's more data, pop it too
			if(client_addr_rsize > 1)
				client_addr_pop		<= 1;
				
			//nope, done
			else
				client_addr_updating	<= 0;
				
		end
	
		//If a commit request comes in, process it
		if(client_addr_commit) begin
			client_addr_updating	<= 1;
			client_addr_pop			<= 1;
			client_addr_waddr		<= 7;	//need to overflow to get 0
		end
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFOs for incoming data
	
	genvar j;
	
	//Input write data
	reg[SOCKET_COUNT-1:0]	rx_fifo_wr_en		= 0;
	reg[31:0]				rx_fifo_wr_data		= 0;
	reg[1:0]				rx_fifo_wr_count	= 0;
	reg						rx_fifo_wr_commit	= 0;
	reg						rx_fifo_wr_rollback	= 0;
	wire[SOCKET_COUNT-1:0]	rx_fifo_wr_overflow;
	reg[SOCKET_COUNT-1:0]	fifo_reset	= 0;
	
	//Read stuff
	reg[SOCKET_COUNT-1:0]	rx_fifo_rd_en		= 0;
	wire[31:0]				rx_fifo_rd_data[SOCKET_COUNT-1 : 0];
	wire[RX_ADDR_BITS+2:0]	rx_fifo_rd_avail[SOCKET_COUNT-1 : 0];
	
	wire[RX_ADDR_BITS+2:0]	rx_fifo_ready		= rx_fifo_rd_avail[dport];
	
	//Number of *words* ready to read (rounded up)
	reg[RX_ADDR_BITS:0]		rx_fifo_words_ready	= 0;
	reg[RX_ADDR_BITS:0]		rx_fifo_words_ready_ff	= 0;
	always @(*) begin
		if(rx_fifo_ready[1:0])
			rx_fifo_words_ready	<= rx_fifo_ready[2 +: RX_ADDR_BITS] + 1'd1;
		else
			rx_fifo_words_ready	<= rx_fifo_ready[2 +: RX_ADDR_BITS];
	end
	always @(posedge clk) begin
		rx_fifo_words_ready_ff	<= rx_fifo_words_ready;
	end
	
	generate
	
		for(j=0; j<SOCKET_COUNT; j=j+1) begin : rxfifos

			ByteStreamFifo #(
				.DEPTH(RX_FIFO_DEPTH)
			) rx_fifo ( 
				.clk(clk),
				.reset(fifo_reset[j]),
				
				//Enable is specific per FIFO, but we share all the other control signals
				//since we can only be processing one inbound packet at any one time
				.wr_en(rx_fifo_wr_en[j]),
				.wr_data(rx_fifo_wr_data),
				.wr_count(rx_fifo_wr_count),
				.wr_commit(rx_fifo_wr_commit),
				.wr_rollback(rx_fifo_wr_rollback),
				.wr_overflow(rx_fifo_wr_overflow[j]),
				
				//Read stuff is obviously separate for every fifo
				.rd_en(rx_fifo_rd_en[j]),
				.rd_data(rx_fifo_rd_data[j]),
				.rd_avail(rx_fifo_rd_avail[j])
			);
		end
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFOs for outbound data
	
	//write 
	reg[SOCKET_COUNT-1:0]	tx_wr_start		= 0;
	reg[10:0]				tx_wr_len		= 0;
	reg[SOCKET_COUNT-1:0]	tx_wr_en		= 0;
	reg[31:0]				tx_wr_data		= 0;
	reg[SOCKET_COUNT-1:0]	tx_wr_commit	= 0;
	reg[SOCKET_COUNT-1:0]	tx_wr_rollback	= 0;
	wire[SOCKET_COUNT-1:0]	tx_wr_overflow;
	wire[SOCKET_COUNT-1:0]	tx_wr_mdfull;
	
	//read
	wire[10:0]				tx_rd_len[SOCKET_COUNT-1:0];
	wire[SOCKET_COUNT-1:0]	tx_rd_ready;
	reg[SOCKET_COUNT-1:0]	tx_rd_retransmit	= 0;
	reg[SOCKET_COUNT-1:0]	tx_rd_next			= 0;
	reg[SOCKET_COUNT-1:0]	tx_rd_en			= 0;
	wire[31:0]				tx_rd_data[SOCKET_COUNT-1:0];
	reg[SOCKET_COUNT-1:0]	tx_rd_ack			= 0;
	
	//read stuff muxed down
	wire[10:0]				tx_current_rd_len			= tx_rd_len[dport];
	wire					tx_current_rd_ready			= tx_rd_ready[dport];
	wire[31:0]				tx_current_rd_data			= tx_rd_data[dport];
	
	reg[10:0]				tx_current_wordlen			= 0;
	
	reg[SOCKET_COUNT-1:0]	tx_seq_push					= 0;
	
	//max packets in the window, regardless of size
	localparam				MAX_PACKETS					= 64;
	
	//This is the ACK number we expect.
	//If the incoming ACK is less than this, it's a duplicate ACK.
	//If equal, the packet just got ACKed.
	//If greater, multiple packets are being ACKed.
	wire[31:0]				tx_expected_ack;
	wire					tx_ack_empty;
	
	//Determine how long ago the not-yet-ACKed packet was sent
	wire[31:0]				tx_ack_from;
	wire[31:0]				tx_ack_age	= time_ms - tx_ack_from;
	
	//The sequence number that the not-yet-ACKed packet was sent with
	wire[31:0]				tx_seq_base;
	
	//The expected ACK number to the not-yet-ACKed packet
	wire[31:0]				retransmit_incoming_seq;
	
	//Check if the incoming ACK number is good (as in, ACKing a not-yet-ACKed packet)
	reg						tx_current_ack_valid	= 0;
	reg[31:0]				tx_relative_ack			= 0;
	always @(*) begin
		
		//Difference between incoming ACK number and expected ACK number
		tx_relative_ack		<= incoming_ack - tx_expected_ack;
		
		//Empty FIFO = nothing to ACK
		if(tx_ack_empty)
			tx_current_ack_valid	<= 0;
			
		//If the relative ACK number is bigger than the window size, this is an old (negative) ACK
		else if(tx_relative_ack	> TX_FIFO_DEPTH*4)
			tx_current_ack_valid	<= 0;
			
		//Good ACK. May be valid for one (or more) segments
		else
			tx_current_ack_valid	<= 1;
			
		//Randomly drop 3/4 of ACKs to test the retransmit mode
		if(TEST_RETRANSMITS) begin
			if(next_sequence_num[1:0] != 0)
				tx_current_ack_valid	<= 0;
		end
		
	end
		
	//Sequence number FIFO
	//Use MultithreadedSingleClockFifo to get more effective use of the available RAM and avoid needing external muxes
	reg		tx_rd_peek	= 0;
	MultithreadedSingleClockFifo #(
		.WIDTH(128),
		.MAX_THREADS(SOCKET_COUNT),
		.WORDS_PER_THREAD(MAX_PACKETS),
		.USE_BLOCK(1),
		.OUT_REG(1)
	) ack_num_fifo (
		.clk(clk),
		.peek(tx_rd_peek),
			
		.wr_tid(dport),
		.rd_tid(dport),
		.reset(tx_rd_retransmit[dport] || fifo_reset[dport]),
		
		//Write side
		.wr(tx_seq_push[dport]),
		.din({expected_incoming_seq, tx_seq_num_out, time_ms, tx_seq_num_next}),
		.overflow(),
		.overflow_r(),
		
		//Read side
		.rd(tx_rd_ack[dport]),
		.dout({retransmit_incoming_seq, tx_seq_base, tx_ack_from, tx_expected_ack}),
		.underflow(),
		.underflow_r(),
	
		.empty(tx_ack_empty),
		.full()
	);
	
	generate
	
		for(j=0; j<SOCKET_COUNT; j=j+1) begin : txfifos

			//Packet data FIFO
			ByteStreamPacketFifo #(
				.DEPTH(TX_FIFO_DEPTH),
				.MAX_PACKETS(MAX_PACKETS)
			) tx_fifo (
				.clk(clk),
				.reset(fifo_reset[j]),
				.wr_start(tx_wr_start[j]),
				.wr_len(tx_wr_len),
				.wr_en(tx_wr_en[j]),
				.wr_data(tx_wr_data),
				.wr_commit(tx_wr_commit[j]),
				.wr_rollback(tx_wr_rollback[j]),
				.wr_overflow(tx_wr_overflow[j]),
				.wr_mdfull(tx_wr_mdfull[j]),
				.rd_len(tx_rd_len[j]),
				.rd_ready(tx_rd_ready[j]),
				.rd_retransmit(tx_rd_retransmit[j]),
				.rd_next(tx_rd_next[j]),
				.rd_en(tx_rd_en[j]),
				.rd_data(tx_rd_data[j]),
				.rd_ack(tx_rd_ack[j])
				);
			
		end
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Processing of outbound DMA data
	
	//Save the FIFO capacity as of the start of the transmit
	reg[RX_ADDR_BITS+2:0]	rx_fifo_ready_ff			= 0;
	reg[RX_ADDR_BITS:0]		rx_fifo_words_ready_inc_ff	= 0;
	always @(posedge clk) begin
		if(dtx_en) begin
			rx_fifo_ready_ff			<= rx_fifo_ready;
			rx_fifo_words_ready_inc_ff	<= rx_fifo_words_ready + 1'h1;
		end
	end
	
	//Pop the FIFO if needed
	//Do *not* pop the FIFO for the 0th word, since that's the length
	always @(*) begin
		rx_fifo_rd_en				<= 0;
		
		if( (state == TCP_STATE_FIFO_READ_2) && dtx_rd && (dtx_raddr != 0) )
			rx_fifo_rd_en[dport]	<= 1;
		
	end
	
	//The actual muxing
	always @(*) begin
	
		//Mux to select which stuff we read from
		if(state == TCP_STATE_FIFO_READ_2) begin
			
			//0th word = length
			if(dtx_raddr_ff == 0) begin
				
				//If we requested LESS than the amount of available data, return that
				if(drx_len < rx_fifo_words_ready_inc_ff)
					dtx_buf_out	<= {dtx_len - 1'b1, 2'b00};
					
				//No, return the actual size
				else
					dtx_buf_out	<= rx_fifo_ready_ff;
				
			end
			
			//Other words = data
			else
				dtx_buf_out	<= rx_fifo_rd_data[dport];
		end
		
		else
			dtx_buf_out		<= dma_txbuf_out;
	
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC state machine

	localparam	RPC_STATE_IDLE				= 4'h0;
	localparam	RPC_STATE_SLAVE_TXHOLD		= 4'h1;
	localparam	RPC_STATE_HANDLE_LOOKUP		= 4'h2;

	`include "TCPOffloadEngine_opcodes_constants.v"
	`include "NOCSysinfo_constants.v"
	`include "NOCNameServer_constants.v"

	reg[3:0]	rpc_state				= RPC_STATE_IDLE;
	reg[15:0]	sysinfo_addr			= 0;

	always @(posedge clk) begin
		
		rpc_slave_rx_done		<= 0;
		rpc_master_rx_done		<= 0;
		rpc_slave_tx_en			<= 0;
		handle_update			<= 0;
		handle_rd				<= 0;
		
		//Check if the sequence number of the incoming packet is good
		//If not set, this means we have a reordered or missing packet
		rx_sequence_match		<= (incoming_seq == expected_incoming_seq);
		src_port_match			<= (packet_source_port == expected_source_port);
		
		//DEBUG: Wipe status flags when idle (simplifies LA view)
		if(state == TCP_STATE_IDLE) begin
			rx_sequence_match	<= 0;
			src_port_match		<= 0;
		end
		
		case(rpc_state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// IDLE - sit around and wait for traffic
			
			RPC_STATE_IDLE: begin
			
				//Process incoming master traffic (usually interrupts)
				if(rpc_master_inbox_full) begin
				
					//Single cycle, whatever it is
					rpc_master_rx_done	<= 1;
					
					//Handle interrupts from IPv6 stack
					if( (rpc_master_rx_type == RPC_TYPE_INTERRUPT) && (rpc_master_rx_src_addr == IPV6_HOST) ) begin
						case(rpc_master_rx_callnum)
							
							IPV6_OP_NOTIFY_MAC: begin
								client_mac_address	<= { rpc_master_rx_d0[15:0], rpc_master_rx_d1 };
							end	//IPV6_OP_NOTIFY_MAC
							
							IPV6_OP_NOTIFY_PREFIX: begin
								subnet_prefix		<= { rpc_master_rx_d1, rpc_master_rx_d2 };
							end	//IPV6_OP_NOTIFY_PREFIX
							
						endcase
					end
					
					//ignore function return values, RPC state machine handles those
				
				end
				
				//Process incoming slave traffic (function calls from servers)
				else if(rpc_slave_inbox_full) begin
					
					//Default slave to returning from the call
					rpc_slave_tx_dst_addr	<= rpc_slave_rx_src_addr;
					rpc_slave_tx_callnum	<= rpc_slave_rx_callnum;
					rpc_slave_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
					rpc_slave_tx_d0			<= rpc_slave_rx_d0;
					rpc_slave_tx_d1			<= rpc_slave_rx_d1;
					rpc_slave_tx_d2			<= rpc_slave_rx_d2;
					
					case(rpc_slave_rx_callnum)
					
						//Get port range
						TCP_OP_GET_PORTRANGE: begin
							rpc_slave_tx_d0[15:0]	<= SOCKET_COUNT[15:0];
							rpc_slave_tx_d1[15:0]	<= BASE_PORT[15:0];
							
							rpc_slave_rx_done		<= 1;
							rpc_slave_tx_en			<= 1;
							rpc_state				<= RPC_STATE_SLAVE_TXHOLD;
						end	//end TCP_OP_GET_PORTRANGE
						
						//Open a socket
						TCP_OP_OPEN_SOCKET: begin
						
							//If the port number isn't between 0 and nports, it's bad
							if(rpc_dport_fwd >= SOCKET_COUNT) begin
								rpc_slave_rx_done	<= 1;
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
								
								rpc_slave_tx_en		<= 1;
								rpc_state			<= RPC_STATE_SLAVE_TXHOLD;
							end
							
							//It's a valid port number, look it up
							else begin
								handle_id				<= rpc_dport_fwd[SOCKET_BITS-1 : 0];
								handle_rd				<= 1;
								
								rpc_state				<= RPC_STATE_HANDLE_LOOKUP;
								
								//Prepare to write assuming it was good
								socket_open_next		<= 1;
								socket_owner_next		<= rpc_slave_rx_src_addr;

							end

						end	//end TCP_OP_OPEN_SOCKET
						
						//Close a socket
						TCP_OP_CLOSE_SOCKET: begin
						
							//If the port number isn't between 0 and nports, it's bad
							if(rpc_dport_fwd >= SOCKET_COUNT) begin
								rpc_slave_rx_done	<= 1;
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
								
								rpc_slave_tx_en		<= 1;
								rpc_state			<= RPC_STATE_SLAVE_TXHOLD;
							end
							
							//It's a valid port number, look it up
							else begin
								handle_id				<= rpc_dport_fwd[SOCKET_BITS-1 : 0];
								handle_rd				<= 1;
								
								rpc_state				<= RPC_STATE_HANDLE_LOOKUP;
								
								//Prepare to write assuming it was good
								socket_open_next		<= 0;
								socket_owner_next		<= 0;

							end

						end	//end TCP_OP_CLOSE_SOCKET
						
						//Unknown operation, return error
						default: begin
							rpc_slave_rx_done	<= 1;
							rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							
							rpc_slave_tx_en		<= 1;
							rpc_state			<= RPC_STATE_SLAVE_TXHOLD;
						end
						
					endcase
					
				end
			
			end	//end RPC_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for handle lookup to complete
			
			RPC_STATE_HANDLE_LOOKUP: begin
				if(!handle_rd) begin
				
					//No matter what, we're returning to the caller
					rpc_slave_rx_done	<= 1;				
					rpc_slave_tx_en		<= 1;
					rpc_state			<= RPC_STATE_SLAVE_TXHOLD;
				
					case(rpc_slave_rx_callnum)
						
						//Opening the socket? We're good if it's currently closed
						TCP_OP_OPEN_SOCKET: begin
							
							//Open? Return fail
							if(handle_open)
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							
							//We're good, update the handle table
							else
								handle_update			<= 1;
						
						end	//end TCP_OP_OPEN_SOCKET
						
						//Opening the socket? We're good if it's currently open by us
						TCP_OP_CLOSE_SOCKET: begin
							
							//Not open, or open by somebody else? Return fail
							if( (!handle_open) || (handle_owner != rpc_slave_rx_src_addr) )
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							
							//We're good, update the handle table
							else
								handle_update					<= 1;
						
						end	//end TCP_OP_CLOSE_SOCKET
					
					endcase
				
				end
			end	// RPC_STATE_HANDLE_LOOKUP
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for transmits to complete
			
			RPC_STATE_SLAVE_TXHOLD: begin
				if(rpc_slave_tx_done)
					rpc_state		<= RPC_STATE_IDLE;
			end	//end RPC_STATE_SLAVE_TXHOLD
			
		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main DMA state machine
	
	//Our address info
	reg[63:0]	subnet_prefix			= 0;
	reg[47:0]	client_mac_address		= 0;

	`include "IPv6OffloadEngine_opcodes_constants.v"

	reg			dma_inbox_full			= 0;
	reg			rx_bad_port				= 0;
	reg			sending_response		= 0;
	reg			out_of_order			= 0;
	reg			new_data				= 0;
	
	wire[3:0]	data_offset_fwd			= drx_buf_data[31:28];

	reg			sending_fin				= 0;
	reg			tx_rd_peek_ff			= 0;
	wire		tx_poll					= tx_rd_peek_ff && socket_connected_out && socket_open_out;

	always @(posedge clk) begin
		
		dtx_en				<= 0;
		drx_buf_rd			<= 0;
		dma_txbuf_we		<= 0;
		tx_checksum_load	<= 0;
		socket_update		<= 0;
		
		rx_fifo_wr_commit	<= 0;
		rx_fifo_wr_rollback	<= 0;
		rx_fifo_wr_en		<= 0;
		
		tx_wr_start			<= 0;
		tx_wr_en			<= 0;
		tx_wr_commit		<= 0;
		tx_wr_rollback		<= 0;
		
		rpc_master_tx_en	<= 0;
		
		client_addr_push	<= 0;
		client_addr_commit	<= 0;
		client_addr_rd		<= 0;
		client_addr_reset	<= 0;
		
		tx_rd_en			<= 0;
		tx_rd_next			<= 0;
		tx_rd_ack			<= 0;
		tx_rd_retransmit	<= 0;
		
		tx_seq_push			<= 0;
		tx_rd_peek			<= 0;
		
		tx_rd_peek_ff		<= tx_rd_peek;
		
		delay_limit_update	<= 0;
		
		fifo_reset	<= 0;
		
		if(drx_en) begin
			dma_inbox_full	<= 1;
			drx_ready		<= 0;
		end
		
		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// BOOT - query clock ticks per 1 kHz
		
			//Find sysinfo
			TCP_STATE_BOOT_0: begin
				rpc_master_tx_en		<= 1;
				rpc_master_tx_dst_addr	<= NAMESERVER_ADDR;
				rpc_master_tx_type		<= RPC_TYPE_CALL;
				rpc_master_tx_callnum	<= NAMESERVER_FQUERY;
				rpc_master_tx_d0		<= 0;
				rpc_master_tx_d1		<= "sysi";
				rpc_master_tx_d2		<= {"nfo", 8'h0};
				state					<= TCP_STATE_BOOT_1;
			end	//end RPC_STATE_BOOT_0
			
			//Wait for response from name server
			TCP_STATE_BOOT_1: begin		
				if(rpc_master_inbox_full) begin
					case(rpc_master_rx_type)
						
						RPC_TYPE_RETURN_FAIL: 
							state				<= TCP_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							sysinfo_addr		<= rpc_master_rx_d0[15:0];
							state 				<= TCP_STATE_BOOT_2;								
						end
						
						RPC_TYPE_RETURN_RETRY:
							rpc_master_tx_en	<= 1;
						
					endcase
					
				end	
			end	//end TCP_STATE_BOOT_1
			
			//Send query to sysinfo (cycles per 1 kHz)
			TCP_STATE_BOOT_2: begin
				rpc_master_tx_en		<= 1;
				rpc_master_tx_dst_addr	<= sysinfo_addr;
				rpc_master_tx_callnum	<= SYSINFO_GET_CYCFREQ;
				rpc_master_tx_type		<= RPC_TYPE_CALL;
				rpc_master_tx_d0		<= 0;
				rpc_master_tx_d1		<= 1000;
				rpc_master_tx_d2		<= 0;
				state					<= TCP_STATE_BOOT_3;
			end	//end TCP_STATE_BOOT_3
			
			//Wait for sysinfo to respond
			TCP_STATE_BOOT_3: begin
				if(rpc_master_inbox_full) begin
					case(rpc_master_rx_type)
							
						RPC_TYPE_RETURN_FAIL:
							state				<= TCP_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							delay_limit			<= rpc_master_rx_d1;
							delay_limit_update	<= 1;
							state 				<= TCP_STATE_IDLE;	
						end
						
						RPC_TYPE_RETURN_RETRY: begin
							state				<= TCP_STATE_BOOT_4;
						end
						
					endcase
				end
				
			end	//end TCP_STATE_BOOT_3
			
			//Wait for inbox to be cleared, then move on
			TCP_STATE_BOOT_4: begin
				if(!rpc_master_inbox_full)
					state				<= TCP_STATE_BOOT_5;
			end	//end TCP_STATE_BOOT_4
			
			//Wait for timer to expire before retransmitting (to reduce network spam)
			TCP_STATE_BOOT_5: begin
				if(delay_wrap) begin
					rpc_master_tx_en	<= 1;
					state				<= TCP_STATE_BOOT_3;
				end
			end	//end TCP_STATE_BOOT_5
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for something to happen
			TCP_STATE_IDLE: begin
				
				//Clear state to blank
				sending_response	<= 0;
				flag_syn			<= 0;
				flag_ack			<= 0;
				flag_fin			<= 0;
				flag_rst			<= 0;
				sending_rst			<= 0;
				good_packet			<= 1;
				out_of_order		<= 0;
				drx_buf_addr		<= 0;
				new_data			<= 0;
				tx_current_wordlen	<= 0;
				sending_fin			<= 0;
				
				//Process new DMA packets
				if(dma_inbox_full || drx_en) begin
				
					//Inbox is now empty
					dma_inbox_full		<= 0;
					
					//Prepare to send interrupt if this is necessary
					rpc_master_tx_type			<= RPC_TYPE_INTERRUPT;
					rpc_master_tx_d0			<= 0;
					rpc_master_tx_d1			<= 0;
					rpc_master_tx_d2			<= 0;
					rpc_master_tx_dst_addr		<= drx_src_addr;
				
					//New packet (not sure which way it's going yet)
					if(drx_op == DMA_OP_WRITE_REQUEST) begin
					
						//New inbound packet from the IP stack
						if(drx_src_addr == IPV6_HOST) begin
							
							//Prepare to read the entire packet and do various things as each data word comes
							drx_buf_rd				<= 1;
							state					<= TCP_STATE_RX_READ;
							
							//Prepare to send an interrupt if necessary
							rpc_master_tx_callnum	<= TCP_INT_NEW_DATA;
							
							//Clear checksum
							tx_checksum_load		<= 1;
						end
						
						//Nope, it's coming from an application
						else begin
							
							//Read the packet length
							drx_buf_rd				<= 1;
							state					<= TCP_STATE_TX_LOOKUP;
							
							//Prepare to send an interrupt if necessary
							rpc_master_tx_callnum	<= TCP_INT_SEND_DONE;

						end
						
					end
					
					//Read request from the application layer
					else if(drx_op == DMA_OP_READ_REQUEST) begin
						state					<= TCP_STATE_FIFO_READ_0;
						
						//Prepare to send an interrupt if necessary
						rpc_master_tx_callnum	<= TCP_INT_ACCESS_DENIED;
						
					end

					//Drop the packet, stay in idle state
					else
						drx_ready				<= 1;
	
				end
				
				//If we just did a socket read, process it here to avoid a state transition
				else if(client_addr_rd)
					tx_rd_peek		<= 1;
				else if(tx_rd_peek) begin
				end
				
				//If we have a valid connected session, check it out
				else if(tx_poll) begin
					
					//Prepare to write the first word of the outbound MAC
					dma_txbuf_waddr		<= 511;
						
					//Read the second half of the MAC
					client_addr_rd		<= 1;
					client_addr_raddr	<= 1;
					
					//Get length, in words, of the outbound segment
					if(tx_current_rd_len[1:0])
						tx_current_wordlen	<= tx_current_rd_len[10:2] + 1'h1;
					else
						tx_current_wordlen	<= tx_current_rd_len[10:2];
						
					//Clear checksum
					tx_checksum_load		<= 1;
					
					//Update next sequence number so that we send the new packet with the right SN
					//Set inputs regardless of actual need for a retransmit, just gate the write enable flag
					socket_connected_next		<= 1;
					packet_source_port			<= expected_source_port;
					tx_seq_num_next				<= tx_seq_base;
					expected_incoming_seq_next	<= retransmit_incoming_seq;

					//If we're expecting an ACK and the packet was sent at least RETRANSMIT_TIMEOUT_MS ago
					//then assume the message was lost and retransmit
					if(!tx_ack_empty && (tx_ack_age > RETRANSMIT_TIMEOUT_MS)) begin
						tx_rd_retransmit[dport]		<= 1;
						
						socket_update				<= 1;
						state						<= TCP_STATE_IDLE;
						
					end

					//If we have a valid session, and data ready to send, prepare to do that
					else if(tx_current_rd_ready)
						state				<= TCP_STATE_TX_SEND;
				
					//If the socket has been open for more than the timeout period, close it and send a FIN
					else if(socket_age > SOCKET_TIMEOUT_MS) begin
						sending_fin			<= 1;
						tx_current_wordlen	<= 0;
						state				<= TCP_STATE_TX_SEND;
						
						fifo_reset[dport]	<= 1;
					end

				end
				
				//Nothing to send from this socket? Try the next one
				else if(tx_rd_peek_ff) begin
					next_tx_sock			<= next_tx_sock + 1'h1;
				end
				
				//No DMA packets to deal with. Send any pending messages from various sockets.
				//If an update is in progress, hold off until it finishes.
				else if(!socket_update && (!DEBUG_SLOW_TX || delay_wrap) ) begin
					
					//Look up the associated MAC for the packet
					client_addr_rd				<= 1;
					client_addr_raddr			<= 0;
					
				end
				
			end //end TCP_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Outbound transmit data
			
			//Send the actual packet
			TCP_STATE_TX_SEND: begin
			
				//Give the next port number priority when we're done
				next_tx_sock				<= next_tx_sock + 1'h1;
			
				//Get ready to write the next address
				dma_txbuf_we		<= 1;
				dma_txbuf_waddr		<= dma_txbuf_waddr + 9'h1;
				
				//Store the full packet length
				//Update this every clock to remove muxes from the critical path
				dtx_len				<= dma_txbuf_waddr + 1'd1;
			
				//Special processing for headers
				case(dma_txbuf_waddr)
					
					//Write the next-hop MAC address
					511: dma_txbuf_wdata	<= client_addr_rdata;
					0: 	dma_txbuf_wdata		<= client_addr_rdata;
					
					//Write the length of the segment
					1:  dma_txbuf_wdata		<= tx_current_rd_len + 32'd20;
					
					//Write our source IP address
					2: dma_txbuf_wdata		<= subnet_prefix[63:32];
					3: dma_txbuf_wdata		<= subnet_prefix[31:0];
					4: begin
						dma_txbuf_wdata		<= { client_mac_address[47:24], 8'hff };
						
						client_addr_rd		<= 1;
						client_addr_raddr	<= 2;
					end
					5: begin
						dma_txbuf_wdata		<= {8'hfe, client_mac_address[23:0] };
						
						client_addr_rd		<= 1;
						client_addr_raddr	<= 3;
					end
					
					//Write the destination IP
					6: begin
						dma_txbuf_wdata		<= client_addr_rdata;
						
						client_addr_rd		<= 1;
						client_addr_raddr	<= 4;
					end
					7: begin
						dma_txbuf_wdata		<= client_addr_rdata;
						
						client_addr_rd		<= 1;
						client_addr_raddr	<= 5;
					end
					8:	dma_txbuf_wdata		<= client_addr_rdata;
					9: 	dma_txbuf_wdata		<= client_addr_rdata;
					
					//Port number
					10: begin
						dma_txbuf_wdata[31:16]	<= dport + BASE_PORT;
						dma_txbuf_wdata[15:0]	<= expected_source_port;
					end
					
					//Sequence number
					11: dma_txbuf_wdata			<= tx_seq_num_out;
					
					//ACK number (ACK the previous packet)
					12: dma_txbuf_wdata			<= expected_incoming_seq;
					
					//Flags etc
					13: begin
						dma_txbuf_wdata		<=
						{
							4'h5,			//Data offset
							3'b0,			//Reserved
							1'b0,			//NS
							1'b0,			//CWR
							1'b0,			//ECE
							1'b0,			//URG
							1'b1,			//ACK
							1'b1,			//PSH set (we have data)
							1'b0,			//RST	18
							1'b0,			//SYN	17
							1'b0,			//FIN	16
							
							RX_FIFO_DEPTH[13:0], 2'b0	//RX window size
						};
						
						//If we're sending a FIN, change the flags a bit
						if(sending_fin) begin
							dma_txbuf_wdata[19]		<= 0;
							dma_txbuf_wdata[16]		<= 1;
						end
						
						//Start reading data
						else
							tx_rd_en[dport]			<= 1;
						
					end
					
					//Checksum (zero for now)
					14: begin
						dma_txbuf_wdata			<= 0;
						
						//Read the second data word, if we have one)
						if( (tx_current_wordlen > 1) && !sending_fin)
							tx_rd_en[dport]		<= 1;
						
					end
					
					//The actual data
					default: begin
					
						//Read additional data words if necessary
						if(tx_current_wordlen > (dma_txbuf_waddr - 13))
							tx_rd_en[dport]		<= 1;
					
						dma_txbuf_wdata			<= tx_current_rd_data;
					end
					
				endcase
				
				//Send packet data
				if( dma_txbuf_waddr == (tx_current_wordlen + 'd15)) begin
				
					//Prepare to send response packet
					dtx_dst_addr		<= IPV6_HOST;
					dtx_op				<= DMA_OP_WRITE_REQUEST;
					dtx_addr			<= 0;
					
					//Write TCP length to a bogus address of the packet (beyond end of the ethernet frame),
					//just so it's included in the checksum.
					//TCP length is DMA length minus pseudo-header, converted from words to bytes
					dma_txbuf_we		<= 1;
					dma_txbuf_waddr		<= 9'd500;
					dma_txbuf_wdata		<= tx_current_rd_len + 'd20;	//header + data
					state				<= TCP_STATE_SEND_PACKET;
					
					//Normal processing
					if(!sending_fin) begin
					
						//Done reading, pop the transmit fifo
						tx_rd_next[dport]	<= 1;

						//Bump transmit sequence number by tx_current_rd_len
						socket_connected_next		<= 1;
						packet_source_port			<= expected_source_port;
						tx_seq_num_next				<= tx_seq_num_out + tx_current_rd_len;
						expected_incoming_seq_next	<= expected_incoming_seq;
						socket_update				<= 1;
						
						//Add this sequence number to the FIFO
						tx_seq_push					<= 1;
						
					end
					
					//Sending a FIN
					else begin
						socket_connected_next		<= 0;
						packet_source_port			<= 0;
						tx_seq_num_next				<= tx_seq_num_out;
						expected_incoming_seq_next	<= 0;
						socket_update				<= 1;
						fifo_reset[dport]	<= 1;
					end
					
				end
				
			end	//end TCP_STATE_TX_SEND
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Inbound transmit data
			
			//Ownership check
			TCP_STATE_TX_LOOKUP: begin
				
				//Wait for read to complete
				if(!drx_buf_rd) begin
					
					//We own the socket! Go ahead and start a new packet with this length
					if(socket_open_out && socket_connected_out && (socket_owner_out == drx_src_addr) ) begin
						
						//If the metadata FIFO is full, stop
						if(tx_wr_mdfull[dport]) begin
							rpc_master_tx_callnum	<= TCP_INT_TXBUF_FULL;
							drx_ready				<= 1;
							rpc_master_tx_en		<= 1;
							state					<= TCP_STATE_RPC_TXHOLD;
						end
						
						//Nope, we've got room
						else begin
							//Create the new packet
							tx_wr_start[dport]		<= 1;
							tx_wr_len				<= drx_buf_data[10:0];
							
							//Read the next word
							drx_buf_rd				<= 1;
							drx_buf_addr			<= 1;
							state					<= TCP_STATE_TX_PUSH;
						end
						
					end
					
					//Bad owner, drop it
					else begin
						drx_ready				<= 1;
						rpc_master_tx_callnum	<= TCP_INT_ACCESS_DENIED;
						rpc_master_tx_en		<= 1;
						state					<= TCP_STATE_RPC_TXHOLD;
					end
					
				end
				
			end	//end TCP_STATE_TX_LOOKUP
			
			//Read the actual data and push into the FIFO
			TCP_STATE_TX_PUSH: begin
			
				//Read the next word
				drx_buf_rd						<= 1;
				drx_buf_addr					<= drx_buf_addr + 1'h1;
				
				//If we just read the last word, stop.
				//Also, since we're not reading anymore, clear the inbox for future incoming packets
				if( drx_buf_addr_ff == drx_len) begin
					
					//Commit to the FIFO
					tx_wr_commit[dport]		<= 1;
					
					//ACK the packet
					drx_ready				<= 1;
					rpc_master_tx_en		<= 1;
					state					<= TCP_STATE_RPC_TXHOLD;
					
				end
			
				//Push the data into the FIFO if we are reading
				else if(drx_buf_rd_ff) begin
					tx_wr_en[dport]			<= 1;
					tx_wr_data				<= drx_buf_data;					
				end
				
				//If we have an overflow, abort
				if(tx_wr_overflow[dport]) begin
					
					//Don't commit the packet
					tx_wr_commit			<= 0;
					
					//Send alert and drop the packet
					rpc_master_tx_callnum	<= TCP_INT_TXBUF_FULL;
					drx_ready				<= 1;
					rpc_master_tx_en		<= 1;
					state					<= TCP_STATE_RPC_TXHOLD;
					
				end
			
			end	//end TCP_STATE_TX_PUSH
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Inbound packet handling - host side
			
			//Wait for socket read to take place
			TCP_STATE_FIFO_READ_0: begin
				state	<= TCP_STATE_FIFO_READ_1;
				
				//Default dtx_len to drx_len
				dtx_len				<= drx_len;
				
			end	//end TCP_STATE_FIFO_READ_0
			
			//Socket read is done, check the status
			TCP_STATE_FIFO_READ_1: begin
			
				//Set RPC up TX dest address for interrupts regardless of state
				//to take the FIFO out of the critical path
				rpc_master_tx_dst_addr	<= drx_src_addr;
				
				//Cap at smaller of requested size and actual size
				//Remember to allocate one more word for the length header.
				//Update regardless of conditionals to reduce critical paths.
				if((rx_fifo_words_ready_ff+1) < drx_len)
					dtx_len				<= rx_fifo_words_ready_ff[9:0] + 1'd1;
			
				//If we don't own the socket, drop the packet and send a failure interrupt
				if( (drx_src_addr != socket_owner_out) || !socket_open_out ) begin
					drx_ready				<= 1;
					rpc_master_tx_en		<= 1;
					state					<= TCP_STATE_RPC_TXHOLD;
				end
				
				//No data? Send an interrupt
				else if(rx_fifo_words_ready == 0) begin
					drx_ready				<= 1;
					rpc_master_tx_en		<= 1;
					rpc_master_tx_d0		<= BASE_PORT + dport;
					rpc_master_tx_callnum	<= TCP_INT_NO_DATA;
					state					<= TCP_STATE_RPC_TXHOLD;
				end
				
				//We own the socket! Start sending data
				else begin
					
					dtx_en					<= 1;
					dtx_dst_addr			<= drx_src_addr;
					dtx_addr				<= drx_addr;
					dtx_op					<= DMA_OP_READ_DATA;

					state				<= TCP_STATE_FIFO_READ_2;
					
				end
				
			end	//end TCP_STATE_FIFO_READ_1
			
			//Wait for read to finish
			TCP_STATE_FIFO_READ_2: begin
				if(!dtx_en && !dtx_busy) begin
					drx_ready			<= 1;
					state				<= TCP_STATE_IDLE;
				end
			end	//end TCP_STATE_FIFO_READ_2
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Inbound packet handling - LAN side
			
			//Read a new incoming packet from the IP stack
			TCP_STATE_RX_READ: begin
			
				//Read next word
				drx_buf_rd		<= 1;
				drx_buf_addr	<= drx_buf_addr_next;
				
				//If we just read the last word, stop.
				//Also, since we're not reading anymore, clear the inbox for future incoming packets
				if( drx_buf_addr == drx_len) begin
					state				<= TCP_STATE_RX_COMMIT_0;
					drx_ready			<= 1;
				end
				
				case(drx_buf_addr_ff)

					//Write MAC address pseudo-header back to transmit buffer in case a response packet is required
					//Loop back source MAC to dest
					0: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 0;
						dma_txbuf_wdata		<= drx_buf_data;
						
						client_addr_push		<= drx_buf_rd_ff;	//don't push first cycle
						client_addr_pushdata	<= drx_buf_data;
					end
					1: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 1;
						dma_txbuf_wdata		<= drx_buf_data;
						
						client_addr_push		<= 1;
						client_addr_pushdata	<= drx_buf_data;
					end
					
					//Save length of the incoming frame
					//and write back a default length (empty segment)
					2: begin
						incoming_len		<= drx_buf_data[15:0];
						
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 2;
						dma_txbuf_wdata		<= 32'd20;	//TODO: Actual IP length (20 + payload length)
					end

					//Write address pseudo-header back to transmit buffer in case a response packet is required
					//Source address becomes dest address
					3: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 7;
						dma_txbuf_wdata		<= drx_buf_data;
						
						client_addr_push		<= 1;
						client_addr_pushdata	<= drx_buf_data;
					end
					
					4: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 8;
						dma_txbuf_wdata		<= drx_buf_data;
						
						client_addr_push		<= 1;
						client_addr_pushdata	<= drx_buf_data;
					end
					
					5: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 9;
						dma_txbuf_wdata		<= drx_buf_data;
						
						client_addr_push		<= 1;
						client_addr_pushdata	<= drx_buf_data;
					end
					
					6: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 10;
						dma_txbuf_wdata		<= drx_buf_data;
						
						client_addr_push		<= 1;
						client_addr_pushdata	<= drx_buf_data;
					end
					
					//Send our source address
					7: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 3;
						dma_txbuf_wdata		<= subnet_prefix[63:32];
					end
					8: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 4;
						dma_txbuf_wdata		<= subnet_prefix[31:0];
					end
					9: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 5;
						dma_txbuf_wdata		<= { client_mac_address[47:24], 8'hff };
					end
					10: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 6;
						dma_txbuf_wdata		<= {8'hfe, client_mac_address[23:0] };
					end
					
					//Source/dest port numbers (flip and prepare to send back)
					11: begin
					
						packet_source_port	<= drx_buf_data[31:16];
						packet_dest_port	<= drx_buf_data[15:0];
						
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 11;
						dma_txbuf_wdata		<= { drx_buf_data[15:0], drx_buf_data[31:16] };
						
						//Now that we have the port numbers...
						//Look up the state for the socket and see what's going on
						if( (drx_buf_data[15:0] < BASE_PORT) || (drx_buf_data[15:0] >= BASE_PORT + SOCKET_COUNT) )
							rx_bad_port		<= 1;
						else
							rx_bad_port		<= 0;
						
					end
					
					//Sequence number
					12: begin

						//Save incoming sequence number
						incoming_seq		<= drx_buf_data;
						
						//dport is now updated, read the other stuff
						tx_rd_peek			<= 1;
						
					end
					
					//Acknowledgement number
					13: begin
					
						//Save incoming ACK number
						incoming_ack		<= drx_buf_data;

					end
					
					//Flags and window size
					//Minimum packet length is:
					// two words MAC
					// one word length
					// four word source address
					// four word dest address
					// 11 word pseudo-header
					// 5 word minimum TCP packet size
					14: begin
						
						tcp_len 			<= incoming_len - {data_offset_fwd, 2'b00};
						
						data_offset			<= data_offset_fwd + 10'd11;
						
						//Always writing to flags
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 14;
						
						//Send the default flags
						dma_txbuf_wdata		<=
						{
							4'h5,			//Data offset
							3'b0,			//Reserved
							1'b0,			//NS
							1'b0,			//CWR
							1'b0,			//ECE
							1'b0,			//URG
							1'b1,			//ACK (always set, since we never initiate connections)
							1'b0,			//PSH
							1'b0,			//RST	18
							1'b0,			//SYN	17
							1'b0,			//FIN	16
							
							RX_FIFO_DEPTH[13:0], 2'b0	//RX window size
						};
						
						//Save the ACK bit
						flag_ack				<= drx_buf_data[20];
						
						//If we have a bad port, set the RST bit and don't do anything else
						if(rx_bad_port) begin
							dma_txbuf_wdata[18]		<= 1;	//RST
							sending_rst				<= 1;
							sending_response		<= 1;
							good_packet				<= 0;
						end
						
						//If the incoming packet is a SYN, we need to respond with a SYN+ACK
						else if(drx_buf_data[17]) begin
	
							//Send a RST in case of closed port, or already connected
							if(!socket_open_out || socket_connected_out ) begin
								sending_rst				<= 1;
								good_packet				<= 0;
								dma_txbuf_wdata[18]		<= 1;
							end
							
							//Nope, it's good - open the port
							else begin
								dma_txbuf_wdata[17]		<= 1;
								flag_syn				<= 1;
								socket_connected_next	<= 1;
							end
							
							sending_response			<= 1;
							
						end
						
						//If it's not a SYN, and not going to the active session's port, reject with a RST
						else if(!src_port_match) begin
							dma_txbuf_wdata[18]		<= 1;
							sending_rst				<= 1;
							sending_response		<= 1;
							good_packet				<= 0;
						end
						
						//If the incoming packet is data, we need to respond with an ACK.
						//Do not send ACKs to empty segments (no data)
						else if(drx_len > (10'd11 + data_offset_fwd) ) begin	
												
							//Sequence number is wrong? Just drop the packet w/o acknowledging
							//TODO: Send an ACK for the previous sequence number
							if(!rx_sequence_match)
								out_of_order		<= 1;
								
							//In order? Send a response
							else
								sending_response	<= 1;
								
						end
						
						//If the incoming packet is a FIN, we need to respond with one final ACK.
						//TODO: Don't ACK if we are missing data
						else if(drx_buf_data[16]) begin
						
							socket_connected_next	<= 0;
						
							flag_fin				<= 1;
							sending_response		<= 1;
						end
						
						//Incoming empty TCP segment (probably just an ACK but might be a RST/FIN)
						//TODO: Handle incoming ACKs for data we sent
						else begin
						end
						
					end
					
					//Checksum (zero for now) and urgent pointer
					15: begin
						
						//Incoming checksum validated at end of packet
						//Ignore urgent pointer
						
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 15;
						dma_txbuf_wdata		<= 0;
						
					end
					
					//TODO: Do stuff with data
					//Ignore incoming option headers
					default: begin
					
						//If we're in the data area, push it
						if(drx_buf_addr_ff >= data_offset) begin
						
							//We have data coming in
							new_data				<= 1;
						
							rx_fifo_wr_en[dport]	<= 1;
							rx_fifo_wr_data			<= drx_buf_data;
							
							//Last word? Might not push everything
							if(drx_buf_addr == drx_len) begin
								case(incoming_len[1:0])
									3:	rx_fifo_wr_count	<= 2;
									2:	rx_fifo_wr_count	<= 1;
									1:	rx_fifo_wr_count	<= 0;
									0:	rx_fifo_wr_count	<= 3;
								endcase
							end
							
							//Push everything
							else
								rx_fifo_wr_count	<= 3;
							
						end

					end
					
				endcase
			
			end	//end TCP_STATE_RX_READ
			
			//Wait for checksum calculation to complete.
			TCP_STATE_RX_COMMIT_0: begin
				
				//Move on to checksum validation
				state	<= TCP_STATE_RX_COMMIT_1;
				
			end	//end TCP_STATE_RX_COMMIT_0
			
			//Done reading the packet. By now, the checksum should be valid. See if it is
			TCP_STATE_RX_COMMIT_1: begin
			
				//Prepare to send response packet
				dtx_dst_addr		<= IPV6_HOST;
				dtx_op				<= DMA_OP_WRITE_REQUEST;
				dtx_addr			<= 0;
			
				//Good checksum? Go on and process it.
				//Assign the outbound sequence number now
				if(rx_checksum_match) begin
					state	<= TCP_STATE_RX_COMMIT_2;
					
					//Store the address in memory
					client_addr_commit	<= 1;
					
					//Prepare to write new sequence number to outbound packet
					dma_txbuf_we		<= 1;
					dma_txbuf_waddr		<= 12;
					
					//If this is a SYN allocate a new sequence number
					if(flag_syn) begin
						dma_txbuf_wdata		<= next_sequence_num;
						tx_seq_num_next		<= next_sequence_num + 1;
					end
					
					//Nope, it's not a new segment. Send the saved sequence number.
					//TODO: If we're sending data, bump the next sequence number
					else begin
						dma_txbuf_wdata		<= tx_seq_num_out;
						tx_seq_num_next		<= tx_seq_num_out;
					end
					
				end
					
				//Bad checksum? Drop it
				else begin
					client_addr_reset	<= 1;
					state				<= TCP_STATE_IDLE;
				end
					
			end	//end TCP_STATE_RX_COMMIT_1
			
			//Store the ACK number and execute incoming ACKs
			//Bump ACK number by size of TCP payload (size of IP payload - size of TCP headers)
			TCP_STATE_RX_COMMIT_2: begin

				//If we have a good ACK, and didn't just pop the window, pop it
				if(tx_current_ack_valid && !tx_rd_ack)
					tx_rd_ack[dport]	<= 1;
				
				//If we are popping, wait a cycle for it to finish
				else if(tx_rd_ack) begin
				end
				
				//By default, go on to the next step and commit the packet
				else
					state					<= TCP_STATE_RX_COMMIT_3;
				
				//Outbound ACK processing (only do this the first time around)
				if(dma_txbuf_waddr == 12) begin
					dma_txbuf_we		<= 1;
					dma_txbuf_waddr		<= 13;
						
					//Respond with seq+1 for SYNs, FINs, and RSTs
					if(flag_syn || flag_fin || flag_rst || sending_rst)
						dma_txbuf_wdata		<= incoming_seq + 32'h1;
						
					//Respond with seq+datalen
					else
						dma_txbuf_wdata		<= incoming_seq + tcp_len;
				end
				
			end	//end TCP_STATE_RX_COMMIT_2
			
			//Checksum is OK, execute the queued operations
			TCP_STATE_RX_COMMIT_3: begin
			
				//Default to silently dropping the packet
				state		<= TCP_STATE_IDLE;
			
				//Update the socket state in memory if we have a good packet
				socket_update		<= good_packet;
				
				//Commit changes to the RX fifo if we have a good packet
				rx_fifo_wr_commit	<= good_packet;
				
				//SYN or FIN? Next sequence number should be bumped by one
				if(flag_syn || flag_fin || flag_rst)
					expected_incoming_seq_next	<= incoming_seq + 1;
					
				//Data? Next sequence number should be bumped by that
				else if(tcp_len > 0)
					expected_incoming_seq_next	<= incoming_seq + tcp_len;
					
				//Empty segment with no special flags (just an ACK)? Expect the same sequence number
				else
					expected_incoming_seq_next	<= incoming_seq;
					
				//Reset the FIFO if we have a new socket
				if(flag_syn)
					fifo_reset[dport]	<= 1;
					
				//Update length regardless to shorten critical paths
				dtx_len				<= 16;
			
				//Send the response packet if we need to ACK
				if(sending_response) begin
					
					//Write TCP length to a bogus address of the packet (beyond end of the ethernet frame),
					//just so it's included in the checksum.
					//TCP length is DMA length minus pseudo-header, converted from words to bytes
					dma_txbuf_we		<= 1;
					dma_txbuf_waddr		<= 9'd500;
					/*if(dtx_len != 10'd16)
						dma_txbuf_wdata		<= tcp_len + 20;	//header + data
					else*/
						dma_txbuf_wdata		<= 20;				//header only
					state				<= TCP_STATE_SEND_PACKET;
					
				end
					
			end	//TCP_STATE_RX_COMMIT_3
			
			//Send an outbound packet
			TCP_STATE_SEND_PACKET: begin
				
				//Use the address to determine where to write next
				case(dma_txbuf_waddr)
				
					//Just wrote TCP length. Wait two cycles for checksum computation to finish
					500: begin
						dma_txbuf_waddr		<= 501;
					end
					501: begin
						dma_txbuf_waddr		<= 502;
					end	
					
					//Checksum computation should be done, write updated packet header
					502: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 15;
						dma_txbuf_wdata		<= { ~tx_checksum_dout, 16'h0000 };
					end
					
					//Just wrote last word of packet header, send the packet
					15: begin
						dtx_en				<= 1;
						state				<= TCP_STATE_DMA_TXHOLD;
					end
				
				endcase
				
			end	//TCP_STATE_SEND_PACKET
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Helper states
			
			//Wait for DMA transfer
			TCP_STATE_DMA_TXHOLD: begin
			
				rpc_master_tx_dst_addr			<= socket_owner_out;
			
				if(!dtx_en && !dtx_busy) begin
				
					//If we have new data, send an interrupt to the host
					//TODO: Do this in parallel with the DMA transfer
					if(new_data && (rx_fifo_ready != 0) ) begin
						rpc_master_tx_en		<= 1;
						rpc_master_tx_d0		<= packet_dest_port;
						rpc_master_tx_d1		<= rx_fifo_ready;
						state					<= TCP_STATE_RPC_TXHOLD;
					end
					
					//If we got a FIN or RST, send an interrupt to the host
					else if(flag_fin || flag_rst || sending_fin ) begin
						rpc_master_tx_en		<= 1;
						rpc_master_tx_callnum	<= TCP_INT_CONN_CLOSED;
						rpc_master_tx_d0		<= packet_dest_port;
						state					<= TCP_STATE_RPC_TXHOLD;
					end
					
					//If we got a SYN, send an interrupt to the host
					else if(flag_syn) begin
						rpc_master_tx_en		<= 1;
						rpc_master_tx_callnum	<= TCP_INT_CONN_OPENED;
						rpc_master_tx_d0		<= packet_dest_port;
						state					<= TCP_STATE_RPC_TXHOLD;
					end
					
					else				
						state 				<= TCP_STATE_IDLE;
						
				end
			end	//TCP_STATE_DMA_TXHOLD
			
			//Wait for RPC transfer
			TCP_STATE_RPC_TXHOLD: begin
				if(rpc_master_tx_done)
					state	<= TCP_STATE_IDLE;
			end	//end TCP_STATE_RPC_TXHOLD
			
		endcase
		
		//In any state, if we overflowed any of the FIFOs we must have pushed too much data
		//Immediately abort the current packet and roll back changes
		//TODO: Keep going and send an ACK with the previous sequence number?
		if(rx_fifo_wr_overflow) begin
			drx_ready			<= 1;
			rx_fifo_wr_rollback	<= 1;
			state				<= TCP_STATE_IDLE;
		end
		
	end

endmodule
