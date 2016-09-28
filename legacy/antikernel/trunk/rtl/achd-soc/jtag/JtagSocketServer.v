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
	@brief JTAG-to-socket bridge
	
	@module
	@brief		JTAG-to-socket bridge
	@opcodefile NetworkedJtagMaster_opcodes.constants
	
	TODO: Do we have any opcodes?
 */
module JtagSocketServer(
	
	//Clocks
	clk,
	
	//JTAG interface
	jtag_tdi, jtag_tdo, jtag_tms, jtag_tck,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire			clk;

	//The JTAG interface
	output wire[CHANNEL_COUNT-1:0]		jtag_tdi;
	input wire[CHANNEL_COUNT-1:0]		jtag_tdo;
	output wire[CHANNEL_COUNT-1:0]		jtag_tms;
	output wire[CHANNEL_COUNT-1:0]		jtag_tck;
	
	//NoC interface
	output wire			rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0]	rpc_rx_ack;	
	
	output wire			dma_tx_en;
	output wire[31:0] 	dma_tx_data;
	input wire 			dma_tx_ack;
	input wire 			dma_rx_en;
	input wire[31:0] 	dma_rx_data;
	output wire 		dma_rx_ack;
	
	//TCP port number we listen on
	parameter			BASE_PORT 		= 50100;
	
	//Number of channels we have
	parameter			CHANNEL_COUNT	= 1;
	
	//Number of bits in a channel ID
	`include "../util/clog2.vh"
	localparam			CHANNEL_BITS	= clog2(CHANNEL_COUNT);
	
	//Number of 32-bit words in a single channel's FIFO
	parameter			CHANNEL_FIFO_DEPTH	= 512;
	localparam			CHANNEL_FIFO_BITS	= clog2(CHANNEL_FIFO_DEPTH);
	
	//Maximum time to wait before flushing the transmit buffer (in us)
	parameter			TX_FLUSH_TIME		= 500;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	`include "DMARouter_constants.v"
	
	parameter NOC_ADDR = 16'h0000;
	
	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;
	
	wire		rpc_fab_rx_inbox_full;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	reg			rpc_fab_rx_done		= 0;
	
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
		
		.rpc_fab_inbox_full(rpc_fab_rx_inbox_full),
		.rpc_fab_rx_en(),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done)
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
	wire[31:0]	dtx_buf_out;
	
	//DMA receive signals
	reg 		drx_ready		= 1;
	wire		drx_en;
	wire[15:0]	drx_src_addr;
	wire[1:0]	drx_op;
	wire[31:0]	drx_addr;
	wire[9:0]	drx_len;	
	reg			drx_buf_rd		= 0;
	reg[9:0]	drx_buf_addr	= 0;
	wire[31:0]	drx_buf_data;
	
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
		
		.rx_ready(drx_ready), .rx_en(drx_en), .rx_src_addr(drx_src_addr), .rx_dst_addr(),
		.rx_op(drx_op), .rx_addr(drx_addr), .rx_len(drx_len),
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(clk)
		);
		
	reg			drx_buf_rd_ff	= 0;
	reg[9:0]	drx_buf_addr_ff	= 0;
	always @(posedge clk) begin
		drx_buf_rd_ff	<= drx_buf_rd;
		drx_buf_addr_ff	<= drx_buf_addr;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DMA transmit buffer

	reg			dma_txbuf_we	= 0;
	reg[8:0]	dma_txbuf_waddr	= 0;
	reg[31:0]	dma_txbuf_wdata	= 0;
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(512),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) dma_txbuf (
		
		//Transmit stuff
		.porta_clk(clk),
		.porta_en(dma_txbuf_we),
		.porta_addr(dma_txbuf_waddr),
		.porta_we(dma_txbuf_we),
		.porta_din(dma_txbuf_wdata),
		
		//Read during DMA transmit cycles
		.porta_dout(),
		.portb_clk(clk),
		.portb_en(dtx_rd),
		.portb_addr(dtx_raddr[8:0]),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(dtx_buf_out)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Per-channel stuff

	//JTAG channel status
	reg[CHANNEL_COUNT-1:0]	jtag_state_en	= 0;
	reg[CHANNEL_COUNT-1:0]	jtag_shift_en	= 0;
	reg[CHANNEL_COUNT-1:0]	jtag_last_tms	= 0;
	wire[CHANNEL_COUNT-1:0]	jtag_done;
	reg[2:0]				jtag_next_state[CHANNEL_COUNT-1:0];
	reg[5:0]				jtag_len[CHANNEL_COUNT-1:0];
	reg[31:0]				jtag_din[CHANNEL_COUNT-1:0];
	wire[31:0]				jtag_dout[CHANNEL_COUNT-1:0];
	
	//Timestamp that we last sent
	reg[31:0]				jtag_last_send[CHANNEL_COUNT-1:0];

	//FIFO inputs
	reg[CHANNEL_COUNT-1:0]	tx_fifo_wr_en		= 0;
	reg[5:0]				tx_fifo_wr_len		= 0;
	reg[3:0]				tx_fifo_wr_cmd		= 0;
	reg[31:0]				tx_fifo_wr_data		= 0;
	
	reg							rx_fifo_wr_en[CHANNEL_COUNT-1:0];
	reg[1:0]					rx_fifo_wr_count[CHANNEL_COUNT-1:0];
	reg[31:0]					rx_fifo_wr_data[CHANNEL_COUNT-1:0];
	reg[31:0]					jtag_dout_shifted[CHANNEL_COUNT-1:0];
	wire[CHANNEL_FIFO_BITS+2:0]	rx_fifo_wr_size[CHANNEL_COUNT-1:0];
	wire						rx_fifo_wr_overflow[CHANNEL_COUNT-1:0];

	//Current channel being processed by the JTAG state machine
	reg[CHANNEL_BITS-1:0]		current_channel		= 0;
	
	//Write size for the FIFO
	wire[CHANNEL_FIFO_BITS:0]	tx_fifo_wr_size[CHANNEL_COUNT-1:0];
	wire[CHANNEL_FIFO_BITS:0]	current_fifo_wr_size = tx_fifo_wr_size[current_channel];

	//Indicates if we're currently executing a command
	reg[CHANNEL_COUNT-1:0]	channel_busy		= 0;
	
	//FIFO outputs
	wire[CHANNEL_COUNT-1:0]	tx_fifo_rd_empty;
	reg[CHANNEL_COUNT-1:0]	tx_fifo_rd_en		= 0;
	reg[CHANNEL_COUNT-1:0]	tx_fifo_rd_en_ff	= 0;
	wire[41:0]				tx_fifo_rd_dout[CHANNEL_COUNT-1:0];
	
	reg[CHANNEL_COUNT-1:0]		rx_fifo_rd_en		= 0;
	wire[CHANNEL_FIFO_BITS+2:0]	rx_fifo_rd_avail[CHANNEL_COUNT-1:0];
	wire[31:0]					rx_fifo_rd_data[CHANNEL_COUNT-1:0];
	wire[1:0]					rx_fifo_rd_size[CHANNEL_COUNT-1:0];
	
	//Indicates if we need a return value from this shift command
	reg[CHANNEL_COUNT-1:0]	want_return	= 0;

	genvar g;
	generate
	
		for(g=0; g<CHANNEL_COUNT; g=g+1) begin:channels
		
			initial begin
				jtag_next_state[g]	<= 0;
				jtag_len[g]			<= 0;
				jtag_din[g]			<= 0;
				rx_fifo_wr_en[g]	<= 0;
				rx_fifo_wr_count[g]	<= 0;
				rx_fifo_wr_data[g]	<= 0;
				jtag_last_send[g]	<= 0;
			end
			
			//Shift jtag_dout to right alignment
			always @(*) begin
				jtag_dout_shifted[g]	<= jtag_dout[g] >> (32 - jtag_len[g]);
			end
		
			//FIFO of data to be shifted
			//42 bits wide
			//41:36 = bitlen
			//35:32 = cmd
			//31:0  = data
			SingleClockFifo #(
				.WIDTH(42),
				.DEPTH(CHANNEL_FIFO_DEPTH),
				.USE_BLOCK(1),
				.OUT_REG(1),
				.INIT_ADDR(0),
				.INIT_FILE(""),
				.INIT_FULL(0)
			) jtag_tx_fifo (
				.clk(clk),
				.reset(1'b0),
				
				.wr(tx_fifo_wr_en[g]),
				.din({tx_fifo_wr_len, tx_fifo_wr_cmd, tx_fifo_wr_data}),
				.wsize(tx_fifo_wr_size[g]),
				.overflow(),
				.full(),
				
				.rd(tx_fifo_rd_en[g]),
				.dout(tx_fifo_rd_dout[g]),
				.empty(tx_fifo_rd_empty[g]),
				.underflow(),
				.rsize()
				);
		
			//The JTAG adapter
			JtagMaster master(
				.clk(clk),
				.clkdiv(8'd1),		//100 / (4*(div+1) ) = 12.5 MHz (TODO: make dynamic)
				.tck(jtag_tck[g]),
				.tdi(jtag_tdi[g]),
				.tms(jtag_tms[g]),
				.tdo(jtag_tdo[g]),
				
				.state_en(jtag_state_en[g]),
				.next_state(jtag_next_state[g]),
				.len(jtag_len[g]),
				.shift_en(jtag_shift_en[g]),
				.last_tms(jtag_last_tms[g]),
				.din(jtag_din[g]),
				.dout(jtag_dout[g]),
				.done(jtag_done[g])
			);
			
			ByteStreamFifoNoRevert #(
				.DEPTH(CHANNEL_FIFO_DEPTH)
			) jtag_rx_fifo (
				.clk(clk),
				.wr_en(rx_fifo_wr_en[g]),
				.wr_data(rx_fifo_wr_data[g]),
				.wr_count(rx_fifo_wr_count[g]),
				.wr_size(rx_fifo_wr_size[g]),
				.wr_overflow(rx_fifo_wr_overflow[g]),
				
				.rd_en(rx_fifo_rd_en[g]),
				.rd_avail(rx_fifo_rd_avail[g]),
				.rd_data(rx_fifo_rd_data[g]),
				.rd_size(rx_fifo_rd_size[g])
			);	
		
			//Feed commands to the FIFO
			always @(posedge clk) begin
				
				//Clear flags
				tx_fifo_rd_en[g]	<= 0;
				jtag_state_en[g]	<= 0;
				jtag_shift_en[g]	<= 0;
				rx_fifo_wr_en[g]	<= 0;
				
				//Remember previous state
				tx_fifo_rd_en_ff[g]	<= tx_fifo_rd_en[g];
				
				//Idle, but have data? Wake up and start doing stuff.
				//Don't pop data if we don't have room in the output fifo!
				if(!channel_busy[g] && !tx_fifo_rd_empty[g] && (rx_fifo_wr_size[g] >= 4) ) begin
					tx_fifo_rd_en[g]	<= 1;
					channel_busy[g]		<= 1;				
				end
				
				//Doing stuff? See what needs doing
				else if(channel_busy[g]) begin
				
					//If we just finished popping a command, pass it on
					if(tx_fifo_rd_en_ff[g]) begin
						
						//If bit 35 is set, it's a shift op
						if(tx_fifo_rd_dout[g][35]) begin
							jtag_shift_en[g]	<= 1;

							//Set TMS depending on the selected command
							if( (tx_fifo_rd_dout[g][35:32] == OP_SHIFT_TMS) ||
								(tx_fifo_rd_dout[g][35:32] == OP_SHIFT_TMS_WO) ) begin
								jtag_last_tms[g]	<= 1;
							end
							else
								jtag_last_tms[g]	<= 0;
								
							//See if we need a return value
							if( (tx_fifo_rd_dout[g][35:32] == OP_SHIFT_WO) ||
								(tx_fifo_rd_dout[g][35:32] == OP_SHIFT_TMS_WO) ) begin
								want_return[g]		<= 0;
							end
							else
								want_return[g]		<= 1;
								
							//Extract length and data							
							jtag_len[g]			<= tx_fifo_rd_dout[g][41:36];
							jtag_din[g]			<= tx_fifo_rd_dout[g][31:0];
						end
						
						//Nope, it's a state change
						else begin
							jtag_state_en[g]	<= 1;
							jtag_next_state[g]	<= tx_fifo_rd_dout[g][34:32];
							
							//BUGFIX: Need to clear want_return so we don't try writing garbage data into the tx fifo
							want_return[g]		<= 0;
							jtag_len[g]			<= 0;
						end
						
					end
					
					//If we just finished the shift, do something with the output data
					if(jtag_done[g]) begin
					
						//If we want a response, push into the output FIFO
						//Need to endian swap here!
						//TODO: Make protocol network byte order to avoid this hassle
						if(want_return[g]) begin
							rx_fifo_wr_en[g]	<= 1;
							
							if(jtag_len[g] > 24) begin
								rx_fifo_wr_count[g]	<= 3;
								rx_fifo_wr_data[g]	<= 
								{
									jtag_dout_shifted[g][7:0],
									jtag_dout_shifted[g][15:8],
									jtag_dout_shifted[g][23:16],
									jtag_dout_shifted[g][31:24]
								};
							end
							else if(jtag_len[g] > 16) begin
								rx_fifo_wr_count[g]	<= 2;
								rx_fifo_wr_data[g]	<= 
								{
									jtag_dout_shifted[g][7:0],
									jtag_dout_shifted[g][15:8],
									jtag_dout_shifted[g][23:16],
									8'h0
								};
							end
							else if(jtag_len[g] > 8) begin
								rx_fifo_wr_count[g]	<= 1;
								rx_fifo_wr_data[g]	<= 
								{
									jtag_dout_shifted[g][7:0],
									jtag_dout_shifted[g][15:8],
									8'h0,
									8'h0
								};
							end
							else begin
								rx_fifo_wr_count[g]	<= 0;
								rx_fifo_wr_data[g]	<= 
								{
									jtag_dout_shifted[g][7:0],
									8'h0,
									8'h0,
									8'h0
								};
							end
						end
					
						//Done processing it
						channel_busy[g]			<= 0;
						
					end
				
				end
				
			end
		
		end
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Retransmit timer for retries on sysinfo
	
	reg[31:0]	delay_count	= 0;
	reg[31:0]	delay_limit	= 32'h00020000;
	reg			delay_limit_update	= 0;
	
	//1 MHz timer
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
	
	//Timer (microseconds)
	reg[31:0]	time_us		= 0;
	always @(posedge clk) begin
		if(delay_wrap)
			time_us		<= time_us + 32'h1;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Die serial number update logic
	
	reg				serial_update	= 0;
	wire[127:0]		serial_raw;
	reg[127:0]		die_serial		= 0;
	
	BinToHexArray #(
		.NIBBLE_WIDTH(16)
	) hex_table (
		.binary_in({rpc_fab_rx_d2, rpc_fab_rx_d1}),
		.ascii_out(serial_raw)
	);
	
	always @(posedge clk) begin
		if(serial_update)
			die_serial	<= serial_raw;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main RPC state machine
	
	`include "JtagSocketServer_rpc_states_constants.v"
	`include "NOCNameServer_constants.v"
	`include "NOCSysinfo_constants.v"
	`include "TCPOffloadEngine_opcodes_constants.v"
	
	reg			dma_inbox_full	= 0;
	
	reg[3:0] 	rpc_state 		= RPC_STATE_BOOT_0;
	
	//Addresses of various interesting devices
	reg[15:0]	tcp_addr		= 0;
	reg[15:0]	sysinfo_addr	= 0;
	
	//Indicates that the socket rx buffer has data to read
	reg[CHANNEL_COUNT-1:0]	has_data	= 0;
	
	//RPC channel number
	wire[15:0]				rpc_channel_raw	= rpc_fab_rx_d0[15:0] - BASE_PORT[15:0];
	wire[CHANNEL_BITS-1:0]	rpc_channel_fwd	= rpc_channel_raw[CHANNEL_BITS-1:0];
	
	//The channel associated with whatever the main rpc_state machine is currently handling in boot
	//allow n=CHANNEL_COUNT for easier looping
	reg[CHANNEL_BITS:0]		boot_channel			= 0;

	always @(posedge clk) begin
	
		rpc_fab_tx_en		<= 0;
		rpc_fab_rx_done 	<= 0;
		serial_update		<= 0;
		delay_limit_update	<= 0;
		
		case(rpc_state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// BOOT: Register all of our sockets
			
			//Search for TCP stack
			RPC_STATE_BOOT_0: begin
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= NAMESERVER_ADDR;
				rpc_fab_tx_type		<= RPC_TYPE_CALL;
				rpc_fab_tx_callnum	<= NAMESERVER_FQUERY;
				rpc_fab_tx_d0		<= 0;
				rpc_fab_tx_d1		<= {"tcp", 8'h0};
				rpc_fab_tx_d2		<= 0;
				rpc_state				<= RPC_STATE_BOOT_1;
			end	//end RPC_STATE_BOOT_0
			
			//Wait for response from name server
			RPC_STATE_BOOT_1: begin		
				if(rpc_fab_rx_inbox_full) begin
				
					rpc_fab_rx_done				<= 1;
				
					case(rpc_fab_rx_type)
						
						RPC_TYPE_RETURN_FAIL: 
							rpc_state				<= RPC_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							tcp_addr			<= rpc_fab_rx_d0[15:0];
							rpc_state 				<= RPC_STATE_BOOT_2;								
						end
						
						RPC_TYPE_RETURN_RETRY:
							rpc_fab_tx_en	<= 1;
						
					endcase
					
				end	
				
				
			end	//end RPC_STATE_BOOT_1
			
			//Search for sysinfo
			RPC_STATE_BOOT_2: begin
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= NAMESERVER_ADDR;
				rpc_fab_tx_type		<= RPC_TYPE_CALL;
				rpc_fab_tx_callnum	<= NAMESERVER_FQUERY;
				rpc_fab_tx_d0		<= 0;
				rpc_fab_tx_d1		<= "sysi";
				rpc_fab_tx_d2		<= {"nfo", 8'h0};
				rpc_state			<= RPC_STATE_BOOT_3;
			end	//end RPC_STATE_BOOT_0
			
			//Wait for response from name server
			RPC_STATE_BOOT_3: begin		
				if(rpc_fab_rx_inbox_full) begin
				
					rpc_fab_rx_done				<= 1;
				
					case(rpc_fab_rx_type)
						
						RPC_TYPE_RETURN_FAIL: 
							rpc_state				<= RPC_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							sysinfo_addr			<= rpc_fab_rx_d0[15:0];
							rpc_state 				<= RPC_STATE_BOOT_4;								
						end
						
						RPC_TYPE_RETURN_RETRY:
							rpc_fab_tx_en	<= 1;
						
					endcase
					
				end	
			end	//end RPC_STATE_BOOT_3
			
			//Ask for our serial number
			RPC_STATE_BOOT_4: begin
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= sysinfo_addr;
				rpc_fab_tx_type		<= RPC_TYPE_CALL;
				rpc_fab_tx_callnum	<= SYSINFO_CHIP_SERIAL;
				rpc_fab_tx_d0		<= 0;
				rpc_fab_tx_d1		<= 0;
				rpc_fab_tx_d2		<= 0;
				rpc_state			<= RPC_STATE_BOOT_5;
			end	//end RPC_STATE_BOOT_4
			
			//Wait for sysinfo to respond
			RPC_STATE_BOOT_5: begin
				if(rpc_fab_rx_inbox_full) begin
				
					rpc_fab_rx_done		<= 1;
				
					case(rpc_fab_rx_type)
							
						RPC_TYPE_RETURN_FAIL:
							rpc_state			<= RPC_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							serial_update		<= 1;
							rpc_state 			<= RPC_STATE_BOOT_7;
						end
						
						RPC_TYPE_RETURN_RETRY:
							rpc_state			<= RPC_STATE_BOOT_6;
						
					endcase
				end
				
			end	//end RPC_STATE_BOOT_5
			
			RPC_STATE_BOOT_6: begin
				if(delay_wrap) begin
					rpc_fab_tx_en		<= 1;
					rpc_state			<= RPC_STATE_BOOT_5;
				end
			end	//end RPC_STATE_BOOT_6
			
			//Send query to sysinfo (cycles per 1 MHz)
			RPC_STATE_BOOT_7: begin
				rpc_fab_tx_en			<= 1;
				rpc_fab_tx_dst_addr		<= sysinfo_addr;
				rpc_fab_tx_callnum		<= SYSINFO_GET_CYCFREQ;
				rpc_fab_tx_type			<= RPC_TYPE_CALL;
				rpc_fab_tx_d0			<= 0;
				rpc_fab_tx_d1			<= 1000000;
				rpc_fab_tx_d2			<= 0;
				rpc_state				<= RPC_STATE_BOOT_8;
			end	//end RPC_STATE_BOOT_7
			
			//Wait for sysinfo to respond
			RPC_STATE_BOOT_8: begin
				if(rpc_fab_rx_inbox_full) begin
					
					rpc_fab_rx_done		<= 1;
					
					case(rpc_fab_rx_type)
							
						RPC_TYPE_RETURN_FAIL:
							rpc_state			<= RPC_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							delay_limit			<= rpc_fab_rx_d1;
							delay_limit_update	<= 1;
							rpc_state 			<= RPC_STATE_BOOT_9;	
						end
						
						RPC_TYPE_RETURN_RETRY:
							rpc_state			<= RPC_STATE_BOOT_7;
						
					endcase
				end
				
			end	//end TCP_STATE_BOOT_8
			
			//Open each of our sockets
			RPC_STATE_BOOT_9: begin
			
				//Clear out the sysinfo data now that we've processed it
				if(serial_update)
					rpc_fab_rx_done				<= 1;
			
				//Request opening the socket
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= tcp_addr;
				rpc_fab_tx_type		<= RPC_TYPE_CALL;
				rpc_fab_tx_callnum	<= TCP_OP_OPEN_SOCKET;
				rpc_fab_tx_d0		<= BASE_PORT + boot_channel;
				rpc_fab_tx_d1		<= 0;
				rpc_fab_tx_d2		<= 0;
				rpc_state			<= RPC_STATE_BOOT_10;
				
				//Go on to the next channel
				boot_channel		<= boot_channel + 1'h1;
			
			end	//end RPC_STATE_BOOT_9
			
			//Wait for the open call to complete
			RPC_STATE_BOOT_10: begin
			
				if(rpc_fab_rx_inbox_full && !rpc_fab_rx_done) begin
				
					rpc_fab_rx_done					<= 1;
				
					case(rpc_fab_rx_type)
						
						RPC_TYPE_RETURN_FAIL: 
							rpc_state				<= RPC_STATE_HANG;
					
						RPC_TYPE_RETURN_SUCCESS: begin
							
							//If we just finished sending the last request, stop
							if(boot_channel == CHANNEL_COUNT)
								rpc_state			<= RPC_STATE_IDLE;
								
							//nope, open the next channel
							else
								rpc_state 			<= RPC_STATE_BOOT_9;
								
						end
						
						RPC_TYPE_RETURN_RETRY:
							rpc_fab_tx_en	<= 1;
						
					endcase
					
				end	
			
			end	//end RPC_STATE_BOOT_10
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for messages to show up
			
			RPC_STATE_IDLE: begin
			
				//New RPC message!
				if(rpc_fab_rx_inbox_full) begin

					//Return fail to all calls (we don't support any, but still have to say no)
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
						rpc_fab_tx_d0 	<= 0;
						rpc_fab_tx_d1	<= 0;
						rpc_fab_tx_d2 	<= 0;
						rpc_fab_tx_en 	<= 1;
						rpc_state		<= RPC_STATE_TXHOLD;
					end
					
					//Interrupt? Those might be interesting
					else if(rpc_fab_rx_type == RPC_TYPE_INTERRUPT) begin
					
						//We only care about data ready/gone interrupts coming from the TCP stack for now
						if(rpc_fab_rx_src_addr == tcp_addr) begin
						
							if(rpc_fab_rx_callnum == TCP_INT_NEW_DATA)
								has_data[rpc_channel_fwd]	<= 1;
								
							else if(rpc_fab_rx_callnum == TCP_INT_NO_DATA)
								has_data[rpc_channel_fwd]	<= 0;

							//TODO: other interrupts
							else begin
							end
								
						end
						
					end
					
					//All processing is single cycle
					rpc_fab_rx_done	<= 1;

				end
				
			end	//end RPC_STATE_IDLE
			
			//Wait for a transmit to finish
			RPC_STATE_TXHOLD: begin
				if(rpc_fab_tx_done)
					rpc_state	<= RPC_STATE_IDLE;
			end	//end RPC_STATE_TXHOLD
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Debug helpers (should never be used)
			
			RPC_STATE_HANG: begin
				if(rpc_fab_rx_inbox_full)
					rpc_fab_rx_done				<= 1;
			end	//end RPC_STATE_HANG
			
		endcase	
		
	end	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Datapath logic
	
	`include "JtagSocketServer_jtag_states_constants.v"
	`include "jtagd_opcodes_constants.v"
	`include "JtagMaster_opcodes_constants.v"
	
	reg[4:0]	jtag_state			= JTAG_STATE_IDLE;
	reg[4:0]	return_state		= JTAG_STATE_IDLE;
	reg[4:0]	flush_return_state	= JTAG_STATE_IDLE;
	wire[15:0]	current_portnum		= current_channel + BASE_PORT;
	
	//Number of valid bytes in the LAST word of the DMA message
	reg[2:0]	last_bytelen		= 0;
	
	//The opcode currently executing
	reg[7:0]	current_opcode		= 0;
	
	localparam MIN_FIFO_DEPTH		= 8;
	
	//If we consume part of a word, save the remainder of it here (left justified)
	reg[31:0]	saved_word			= 0;
	reg[2:0]	saved_word_len		= 0;
	wire[5:0]	saved_word_bitlen	= {saved_word_len, 3'd0};
	
	//Headers for the upcoming (not yet pushed) shift operation
	reg			last_tms			= 0;
	reg[31:0]	shift_bitlen		= 0;
	
	//Number of BYTES that need to be shifted
	reg[28:0]	shift_bytelen		= 0;
	always @(*) begin
		if(shift_bitlen[2:0])
			shift_bytelen <= shift_bitlen[31:3] + 1'h1;
		else
			shift_bytelen <= shift_bitlen[31:3];
	end
	
	//Number of valid bytes in the current word
	reg[2:0]	word_bytelen		= 0;
	wire[2:0]	word_bytesleft		= 4 - word_bytelen;
	
	//True if there's unread data in the DMA inbox
	wire		rx_data_avail		= dma_inbox_full && (drx_buf_addr != drx_len);
	
	//Number of microseconds since the current channel FIFO was last flushed
	wire[31:0]	jtag_last_send_current	= jtag_last_send[current_channel];
	wire[31:0]	current_channel_age		= time_us - jtag_last_send_current;
	wire		current_channel_old		= current_channel_age > TX_FLUSH_TIME;
	wire		current_channel_rx_empty	= (rx_fifo_rd_avail[current_channel] == 0);
	wire		current_channel_tx_empty	= tx_fifo_rd_empty[current_channel];
	
	reg[CHANNEL_COUNT-1:0]	rx_fifo_rd_en_ff	= 0;
	
	integer i;
	always @(posedge clk) begin
	
		//Clear flags
		drx_buf_rd			<= 0;
		dma_txbuf_we		<= 0;
		tx_fifo_wr_en		<= 0;
		rx_fifo_rd_en		<= 0;
		
		//Save read enable state
		rx_fifo_rd_en_ff	<= rx_fifo_rd_en;
	
		//Store inbox state
		dtx_en				<= 0;
		if(drx_en) begin
			drx_ready		<= 0;
			dma_inbox_full	<= 1;
		end
		
		//If we are currently reading a word of data, by default, increment the pointer
		//This means that drx_buf_addr should always point to the next word of data (if one is there)
		if(drx_buf_rd)
			drx_buf_addr	<= drx_buf_addr + 1'd1;
		
		//Update last-send counters to "now" if there is no data in the FIFO
		for(i=0; i<CHANNEL_COUNT; i=i+1) begin
			if(rx_fifo_rd_avail[i] == 0)
				jtag_last_send[i]	<= time_us;
		end
	
		case(jtag_state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// IDLE - wait for stuff to happen
			
			JTAG_STATE_IDLE: begin
			
				//If we have data ready to read, go on
				//Only move on if we have MIN_FIFO_DEPTH words available for storing stuff in
				if(
					has_data[current_channel] &&
					(current_fifo_wr_size > MIN_FIFO_DEPTH)) begin
					
					//Go fetch the next word, then execute the first command in it
					jtag_state		<= JTAG_STATE_FETCH_0;
					return_state	<= JTAG_STATE_NEXT;

				end
			
				//TODO: If the output FIFO is at least half full
				
				//If the last send was at least X time ago, send it.
				//Also send immediately if we've got data ready to send and there's nothing more pending.
				else if(
					current_channel_old ||
					(current_channel_tx_empty && !current_channel_rx_empty)
					) begin
					jtag_state			<= JTAG_STATE_FLUSH_0;				
					flush_return_state	<= JTAG_STATE_IDLE;	
				end				
			
				//Go on to the next one
				else
					current_channel	<= current_channel + 1'h1;
			
			end	//end JTAG_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// FLUSH - send pending data in the transmit buffer
			
			//Prep for flush, set up headers
			JTAG_STATE_FLUSH_0: begin
			
				//Set up header info
				dtx_addr		<= {current_portnum, 16'h0};	//d0[15:0] = port number
				dtx_dst_addr	<= tcp_addr;
				dtx_op			<= DMA_OP_WRITE_REQUEST;
				
				//Get ready to write the first data location
				//(note that we increment waddr before each write)
				dma_txbuf_waddr	<= 0;
				
				//Set frame length to 1 (byte length header word only)
				dtx_len			<= 1;
				
				//Start popping data
				rx_fifo_rd_en[current_channel]	<= 1;
				jtag_state						<= JTAG_STATE_FLUSH_1;
			
			end	//end JTAG_STATE_FLUSH_0
			
			//Pop data as long as we've got stuff to pop
			JTAG_STATE_FLUSH_1: begin
				
				//If this is the first cycle, don't push anything.
				if(!rx_fifo_rd_en_ff[current_channel]) begin
				
					//Pop more data, if available
					if(rx_fifo_rd_avail[current_channel] > 4)
						rx_fifo_rd_en[current_channel]	<= 1;
				
				end
				
				//No, data is ready to go
				else begin
					
					//Push the most recently popped data into the buffer
					dma_txbuf_we	<= 1;
					dma_txbuf_waddr	<= dma_txbuf_waddr + 1'h1;
					dma_txbuf_wdata	<= rx_fifo_rd_data[current_channel];
					
					//Bump length by one full word
					dtx_len			<= dtx_len + 1'h1;
					
					//If we have no more data to read, stop
					if(rx_fifo_rd_avail[current_channel] <= 4)
						jtag_state	<= JTAG_STATE_FLUSH_2;
						
					//Go read another word
					else
						rx_fifo_rd_en[current_channel]	<= 1;
						
				end
				
			end	//end JTAG_STATE_FLUSH_1
			
			//Write last data word
			JTAG_STATE_FLUSH_2: begin
			
				//Push the last data word (but only if total length was >1 word)
				if(rx_fifo_rd_en_ff[current_channel]) begin
					dma_txbuf_we	<= 1;
					dma_txbuf_waddr	<= dma_txbuf_waddr + 1'h1;
					dma_txbuf_wdata	<= rx_fifo_rd_data[current_channel];
					dtx_len			<= dtx_len + 1'h1;
				end
				
				jtag_state		<= JTAG_STATE_FLUSH_3;
			end
			
			//Write byte length header, then send
			JTAG_STATE_FLUSH_3: begin
			
				//Update the last-send timer to now
				jtag_last_send[current_channel]		<= time_us;
			
				//Write the length field
				dma_txbuf_we	<= 1;
				dma_txbuf_waddr	<= 0;
				
				//Nope, length is 4*(wordlen-1) + size. Simplifying, 4*wordlen - 4 + realsize
				//or 4*wordlen - 3 + rdsize
				dma_txbuf_wdata	<= {dma_txbuf_waddr, 2'h0} - 2'h3 + rx_fifo_rd_size[current_channel];
				
				//Send the message
				dtx_en			<= 1;
				jtag_state		<= JTAG_STATE_FLUSH_4;
				
			end	//end JTAG_STATE_FLUSH_3
			
			//Wait for DMA send, then go back to the previous state.
			//TODO: handle transmit buffer full interrupt?
			JTAG_STATE_FLUSH_4: begin
				if(!dtx_en && !dtx_busy)
					jtag_state		<= flush_return_state;
			end	//end JTAG_STATE_FLUSH_4
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// FETCH - grab the next word of data, whatever it takes
			
			//If we have data ready, process it. Otherwise go and send a DMA read
			JTAG_STATE_FETCH_0: begin
			
				//TODO: If the output FIFO is at least half full, or the last send was at least X time ago, send it
			
				//If we already have data in the DMA buffer, just read the next word
				if(rx_data_avail) begin
					drx_buf_rd	<= 1;
					jtag_state	<= JTAG_STATE_FETCH_3;
				end
				
				//If there's data waiting in the TCP stack, ask for as much as we can get
				else if(has_data[current_channel]) begin
				
					//clear the inbox
					drx_ready		<= 1;
					dma_inbox_full	<= 0;
				
					dtx_en			<= 1;
					dtx_addr		<= {current_portnum, 16'h0};	//d0[15:0] = port number
					dtx_dst_addr	<= tcp_addr;
					dtx_len			<= 512;		//fetch as much as we can find
					dtx_op			<= DMA_OP_READ_REQUEST;
					jtag_state		<= JTAG_STATE_FETCH_1;
					drx_buf_addr	<= 0;
				end
				
				//if neither, block until data-ready interrupt comes in via RPC
				//TODO: go process events from another port in the meantime rather than blocking
				
				//TODO: if client disconnects, abort and break out of this state
			
			end	//end JTAG_STATE_FETCH_0
			
			//Wait for TCP stack to respond.
			JTAG_STATE_FETCH_1: begin
				
				//If has_data goes low, then there was actually nothing to read
				if(!has_data[current_channel]) begin
				
					//If we are not in the middle of a command, go process events from the next port
					if(return_state == JTAG_STATE_NEXT)
						jtag_state	<= JTAG_STATE_IDLE;
						
					//In the middle of a command, we have to block
					else
						jtag_state		<= JTAG_STATE_FETCH_0;
				end
					
				//If the data came in, read the length
				if(rx_data_avail) begin
					drx_buf_rd		<= 1;
					jtag_state		<= JTAG_STATE_FETCH_2;
				end
				
			end	//end JTAG_STATE_FETCH_1
			
			//Read byte length
			JTAG_STATE_FETCH_2: begin
				
				if(drx_buf_rd_ff) begin
				
					//Save the length
					last_bytelen		<= drx_buf_data[1:0];
					if(drx_buf_data[1:0] == 0)
						last_bytelen	<= 4;
					
					//Go back and fetch the data itself
					jtag_state		<= JTAG_STATE_FETCH_0;
					
				end
				
			end	//end JTAG_STATE_FETCH_2
			
			//Finally have data ready to crunch
			JTAG_STATE_FETCH_3: begin
				
				if(drx_buf_rd_ff) begin
					saved_word		<= drx_buf_data;
					jtag_state		<= return_state;
					
					//If we just read the last word, use that length
					if(drx_buf_addr == drx_len)
						saved_word_len	<= last_bytelen;
					
					//Otherwise all 4 words are valid
					else
						saved_word_len	<= 4;
					
				end
				
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Incoming command - read headers and find out what it is

			//Read and prepare to execute the next command in the buffer
			JTAG_STATE_NEXT: begin

				//If there's no data left, go fetch another word
				if(saved_word_len == 0) begin
					jtag_state		<= JTAG_STATE_FETCH_0;
					return_state	<= JTAG_STATE_NEXT;
				end
				
				//If there's no room in the FIFO, stop until we have space
				else if(current_fifo_wr_size <= MIN_FIFO_DEPTH) begin
				end
				
				//We have data, process it
				else begin

					//We consumed one byte, the opcode
					saved_word_len	<= saved_word_len - 1'h1;
					
					//Save the opcode and shift the word left
					current_opcode	<= saved_word[31:24];
					saved_word		<= {saved_word[23:0], 8'h0};
					
					//Go dispatch the command
					jtag_state		<= JTAG_STATE_DISPATCH;
					
				end
			
			end	//end JTAG_STATE_NEXT
			
			//Dispatch the command (see if we need more data, etc)
			JTAG_STATE_DISPATCH: begin
			
				//Immediately respond to commands that don't take arguments
				case(current_opcode)
				
					////////////////////////////////////////////////////////////////////////////////////////////////////
					// These  operations require a buffer flush before we can proceed
					
					JTAGD_OP_COMMIT: 		jtag_state	<= JTAG_STATE_DRAIN;
					JTAGD_OP_HAS_GPIO:		jtag_state	<= JTAG_STATE_DRAIN;
					JTAGD_OP_GET_NAME:		jtag_state	<= JTAG_STATE_DRAIN;
					JTAGD_OP_GET_SERIAL:	jtag_state	<= JTAG_STATE_DRAIN;
					JTAGD_OP_GET_USERID: 	jtag_state	<= JTAG_STATE_DRAIN;
					JTAGD_OP_GET_FREQ: 		jtag_state	<= JTAG_STATE_DRAIN;
					
					////////////////////////////////////////////////////////////////////////////////////////////////////
					// Chain status commands
					
					//Reset the chain to idle
					JTAGD_OP_RESET_IDLE: begin
					
						//Push the command to the FIFO for later processing
						tx_fifo_wr_en[current_channel]		<= 1;
						tx_fifo_wr_cmd						<= OP_RESET_IDLE;
						tx_fifo_wr_data						<= 32'h0;	//no data
						tx_fifo_wr_len						<= 0;		//no length
						
						//Done processing this command socket-side, no response needed
						jtag_state		<= JTAG_STATE_NEXT;
						
					end	//end JTAGD_OP_RESET_IDLE
					
					//Go to test-logic-reset state
					JTAGD_OP_TLR: begin
					
						//Push the command to the FIFO for later processing
						tx_fifo_wr_en[current_channel]		<= 1;
						tx_fifo_wr_cmd						<= OP_TEST_RESET;
						tx_fifo_wr_data						<= 32'h0;	//no data
						tx_fifo_wr_len						<= 0;		//no length
						
						//Done processing this command socket-side, no response needed
						jtag_state		<= JTAG_STATE_NEXT;
					
					end	//end JTAGD_OP_TLR
					
					//Go to Shift-IR state
					JTAGD_OP_ENTER_SIR: begin
					
						//Push the command to the FIFO for later processing
						tx_fifo_wr_en[current_channel]		<= 1;
						tx_fifo_wr_cmd						<= OP_SELECT_IR;
						tx_fifo_wr_data						<= 32'h0;	//no data
						tx_fifo_wr_len						<= 0;		//no length
						
						//Done processing this command socket-side, no response needed
						jtag_state		<= JTAG_STATE_NEXT;
					
					end	//end JTAGD_OP_ENTER_SIR
					
					//Leave Shift-IR state
					JTAGD_OP_LEAVE_E1IR: begin
					
						//Push the command to the FIFO for later processing
						tx_fifo_wr_en[current_channel]		<= 1;
						tx_fifo_wr_cmd						<= OP_LEAVE_IR;
						tx_fifo_wr_data						<= 32'h0;	//no data
						tx_fifo_wr_len						<= 0;		//no length
						
						//Done processing this command socket-side, no response needed
						jtag_state		<= JTAG_STATE_NEXT;
					
					end	//end JTAGD_OP_LEAVE_E1IR
					
					//Go to Shift-DR state
					JTAGD_OP_ENTER_SDR: begin
					
						//Push the command to the FIFO for later processing
						tx_fifo_wr_en[current_channel]		<= 1;
						tx_fifo_wr_cmd						<= OP_SELECT_DR;
						tx_fifo_wr_data						<= 32'h0;	//no data
						tx_fifo_wr_len						<= 0;		//no length
						
						//Done processing this command socket-side, no response needed
						jtag_state		<= JTAG_STATE_NEXT;
					
					end	//end JTAGD_OP_ENTER_SDR
					
					//Leave Shift-DR state
					JTAGD_OP_LEAVE_E1DR: begin
					
						//Push the command to the FIFO for later processing
						tx_fifo_wr_en[current_channel]		<= 1;
						tx_fifo_wr_cmd						<= OP_LEAVE_DR;
						tx_fifo_wr_data						<= 32'h0;	//no data
						tx_fifo_wr_len						<= 0;		//no length
						
						//Done processing this command socket-side, no response needed
						jtag_state		<= JTAG_STATE_NEXT;
					
					end	//end JTAGD_OP_LEAVE_E1DR
					
					//	More commands to do
					//	JTAGD_OP_DUMMY_CLOCK 		8'h08	//Send dummy clocks
					//	JTAGD_OP_PERF_SHIFT 		8'h09	//Gets number of shift operations
					//	JTAGD_OP_PERF_RECOV 		8'h0a	//Gets number of recoverable errors
					//	JTAGD_OP_PERF_DATA 			8'h0b	//Gets number of data bits shifted
					//	JTAGD_OP_PERF_MODE 			8'h0c	//Gets number of mode bits shifted
					//	JTAGD_OP_PERF_DUMMY 		8'h0d	//Gets number of dummy clocks sent
					//	JTAGD_OP_SPLIT_SUPPORTED	8'h10	//Checks if split scan is supported
					//	JTAGD_OP_SHIFT_DATA_WRITE_ONLY 	8'h11	//Shift data
					//	JTAGD_OP_SHIFT_DATA_READ_ONLY 	8'h12	//Shift data
					//	JTAGD_OP_DUMMY_CLOCK_DEFERRED	8'h13	//Send dummy clocks without flushing the pipeline
					
					// On hold since we don't have GPIO support for now
					//	JTAGD_OP_GET_GPIO_PIN_COUNT	8'h15	//Gets the number of GPIO pins the adapter has
					//	JTAGD_OP_READ_GPIO_STATE 	8'h16	//Read GPIO pin state
					//	JTAGD_OP_WRITE_GPIO_STATE 	8'h17	//Write GPIO pin state
					
					////////////////////////////////////////////////////////////////////////////////////////////////////
					// Data shifting
					
					JTAGD_OP_SHIFT_DATA: begin
						jtag_state		<= JTAG_STATE_SHIFT_0;
						tx_fifo_wr_cmd	<= OP_SHIFT;			//always OP_SHIFT or OP_SHIFT_WO at this point
					end	//end JTAGD_OP_SHIFT_DATA
					
					JTAGD_OP_SHIFT_DATA_WO: begin
						jtag_state		<= JTAG_STATE_SHIFT_0;
						tx_fifo_wr_cmd	<= OP_SHIFT_WO;			//always OP_SHIFT or OP_SHIFT_WO at this point
					end	//end JTAGD_OP_SHIFT_DATA_WO

					////////////////////////////////////////////////////////////////////////////////////////////////////
					// Control commands
					
					//Quit
					JTAGD_OP_QUIT: begin
						
						//Just let the client disconnect
						//This should always be the last command we get
						drx_ready		<= 1;
						dma_inbox_full	<= 0;
						
						//Go back to the idle state
						jtag_state		<= JTAG_STATE_IDLE;
						
					end	//end JTAGD_OP_QUIT
				
					//TODO: If we get a bad opcode close the connection
					//and fully empty the buffer so we have a clean start for the rest of the 
					default: begin
						jtag_state	<= JTAG_STATE_HANG;
					end
				
				endcase
			
			end	//end JTAG_STATE_DISPATCH
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Drain the buffers before doing various operations that require sync
			
			JTAG_STATE_DRAIN: begin
				
				//Send data if we need to, then return to here
				if(current_channel_old ||
					(current_channel_tx_empty && !current_channel_rx_empty)
					) begin
					jtag_state			<= JTAG_STATE_FLUSH_0;				
					flush_return_state	<= JTAG_STATE_DRAIN;	
				end
				
				//If both FIFOs are empty, and the JTAG transceiver isn't busy, there is nothing pending.
				//Flush complete.
				else if(current_channel_tx_empty && current_channel_rx_empty && !channel_busy[current_channel])
					jtag_state	<= JTAG_STATE_POSTDRAIN;
			
			end	//end JTAG_STATE_DRAIN
			
			//Pipeline is drained, go execute the commands
			JTAG_STATE_POSTDRAIN: begin
			
				case(current_opcode)
				
					//Forces all pending operations to complete, return a dummy word to confirm barrier was reached
					//Since we don't batch command before sending them to the adapter, this does nothing
					JTAGD_OP_COMMIT: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 1;
						dma_txbuf_wdata		<= {8'h0, 24'h0};
						jtag_state			<= JTAG_STATE_SEND;
					end	//end JTAGD_OP_COMMIT
				
					//Ask if we have GPIO (for now, the answer is no)
					JTAGD_OP_HAS_GPIO: begin
						dma_txbuf_we		<= 1;
						dma_txbuf_waddr		<= 1;
						dma_txbuf_wdata		<= {8'h0, 24'h0};
						jtag_state			<= JTAG_STATE_SEND;
					end	//end JTAGD_OP_HAS_GPIO
					
					//Get the name of the adapter
					JTAGD_OP_GET_NAME: begin
						dma_txbuf_waddr		<= 0;
						jtag_state			<= JTAG_STATE_GET_STRING;
					end	//end JTAGD_OP_GET_NAME
					
					//Get the serial number of the adapter
					JTAGD_OP_GET_SERIAL: begin
						dma_txbuf_waddr		<= 0;
						jtag_state			<= JTAG_STATE_GET_STRING;
					end	//end JTAGD_OP_GET_SERIAL
					
					//Get the user ID of the adapter
					JTAGD_OP_GET_USERID: begin
						dma_txbuf_waddr		<= 0;
						jtag_state			<= JTAG_STATE_GET_STRING;
					end	//end JTAGD_OP_GET_USERID
					
					//Gets the frequency of TCK
					JTAGD_OP_GET_FREQ: begin
						dma_txbuf_waddr		<= 0;
						jtag_state			<= JTAG_STATE_GET_FREQ;
					end	//end JTAGD_OP_GET_FREQ
				
				endcase
			
			end	//end JTAG_STATE_POSTDRAIN
			
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Shifting data
			
			//We're processing a shift command. Read the headers
			JTAG_STATE_SHIFT_0: begin
							
				//If we have at least one byte left, that's the last_tms value
				if(saved_word_len > 0) begin
					saved_word_len	<= saved_word_len - 1'h1;
					last_tms		<= saved_word[24];						
					saved_word		<= {saved_word[23:0], 8'h0};
					shift_bitlen	<= 0;
					word_bytelen	<= 0;
					jtag_state		<= JTAG_STATE_SHIFT_1;
				end
				
				//Get more data
				else begin
					jtag_state		<= JTAG_STATE_FETCH_0;
					return_state	<= JTAG_STATE_SHIFT_0;
				end

			end	//end JTAG_STATE_SHIFT_0
			
			//Read as much of the count as we can get
			JTAG_STATE_SHIFT_1: begin
				
				//If we've read the full count, convert endianness and stop
				if(word_bytesleft == 0) begin
					jtag_state		<= JTAG_STATE_SHIFT_2;
					shift_bitlen	<= {shift_bitlen[7:0], shift_bitlen[15:8], shift_bitlen[23:16], shift_bitlen[31:24]};
				end
					
				//If we have enough bytes left to complete the word, do so
				else if(word_bytesleft <= saved_word_len) begin
					
					//Shift the data into the result field and remove it from the saved word
					case(word_bytesleft)
						
						1: begin
							shift_bitlen	<= {shift_bitlen[23:0], saved_word[31:24]};
							saved_word		<= {saved_word[23:0], 8'h0};
						end
						2:	begin
							shift_bitlen	<= {shift_bitlen[15:0], saved_word[31:16]};
							saved_word		<= {saved_word[15:0], 16'h0};
						end
						3:	begin
							shift_bitlen	<= {shift_bitlen[7:0], saved_word[31:8]};
							saved_word		<= {saved_word[7:0], 24'h0};
						end
						4:	begin
							shift_bitlen	<= saved_word;
							saved_word		<= 0;
						end
						
					endcase
					
					//Record how many bytes we consumed
					saved_word_len			<= saved_word_len - word_bytesleft;
					word_bytelen			<= 4;
					
				end
				
				//Not enough left to complete the word.
				//Save as much as we can get
				else begin
					
					//Shift the data into the result field
					case(saved_word_len)
						
						1: 	shift_bitlen	<= {shift_bitlen[23:0], saved_word[31:24]};
						2:	shift_bitlen	<= {shift_bitlen[15:0], saved_word[31:16]};
						3:	shift_bitlen	<= {shift_bitlen[7:0], saved_word[31:8]};
						
					endcase
					
					//Saved word is now empty, go get another
					saved_word_len	<= 0;
					jtag_state		<= JTAG_STATE_FETCH_0;
					return_state	<= JTAG_STATE_SHIFT_1;
					
					//Record how many we got
					word_bytelen	<= word_bytelen + saved_word_len;
					
				end
	
			end	//end JTAG_STATE_SHIFT_1
			
			//We have the full count, go start pushing data.
			//Need to shuffle bit ordering around:
			// * JtagMaster shifts [0] first and [31] last.
			// * jtagd protocol shifts [24...31], [16...23], [8...15], [0...7]
			JTAG_STATE_SHIFT_2: begin
			
				//If nothing left to shift, go on to the next command
				if(shift_bitlen == 0)
					jtag_state		<= JTAG_STATE_NEXT;
				
				//If there's no room in the FIFO, stop until we have space
				else if(current_fifo_wr_size <= MIN_FIFO_DEPTH) begin
					
				end
				
				//If we can finish the entire message with the current word, do so
				else if(shift_bytelen <= saved_word_len) begin
					
					//We're pushing the entire rest of the message
					tx_fifo_wr_en	<= 1;
					tx_fifo_wr_len	<= shift_bitlen[5:0];
					shift_bitlen	<= 0;
					
					//Consume however many bytes we got
					saved_word_len	<= saved_word_len - shift_bytelen[2:0];
					
					//Shift the saved word
					case(shift_bytelen)
						1:			saved_word	<= {saved_word[23:0], 8'h0};
						2:			saved_word	<= {saved_word[15:0], 16'h0};
						3:			saved_word	<= {saved_word[7:0], 24'h0};
						default:	saved_word	<= 0;
					endcase
					
					//Change the opcode if needed to toggle TMS
					if(last_tms) begin
						if(tx_fifo_wr_cmd == OP_SHIFT_WO)
							tx_fifo_wr_cmd <= OP_SHIFT_TMS_WO;
						else if(tx_fifo_wr_cmd == OP_SHIFT)
							tx_fifo_wr_cmd <= OP_SHIFT_TMS;
					end
					
					//Grab however many bytes we need
					case(shift_bytelen)
						1: 	tx_fifo_wr_data	<= {24'h0, saved_word[31:24]};
						2:	tx_fifo_wr_data	<= {16'h0, saved_word[23:16], saved_word[31:24]};
						3:	tx_fifo_wr_data	<= {8'h0, saved_word[15:8], saved_word[23:16], saved_word[31:24]};
						4:	tx_fifo_wr_data	<=
							{
								saved_word[7:0],
								saved_word[15:8],
								saved_word[23:16],
								saved_word[31:24]
							};
					endcase
					
					//Once we're done, go process the next command in the queue
					jtag_state		<= JTAG_STATE_NEXT;
					
				end
				
				//We cannot finish the whole message, but we have some data.
				//Take as many bytes as we have in this word.
				else if(saved_word_len != 0) begin
					
					//We're pushing some integer number of bytes
					tx_fifo_wr_en	<= 1;
					tx_fifo_wr_len	<= saved_word_bitlen;
					
					//Consume however many bytes we got
					saved_word_len	<= 0;
					shift_bitlen	<= shift_bitlen - saved_word_bitlen;
					
					//Push however much data we got
					case(saved_word_len)
						1: 	tx_fifo_wr_data	<= {24'h0, saved_word[31:24]};
						2:	tx_fifo_wr_data	<= {16'h0, saved_word[23:16], saved_word[31:24]};
						3:	tx_fifo_wr_data	<= {8'h0, saved_word[15:8], saved_word[23:16], saved_word[31:24]};
						4:	tx_fifo_wr_data	<=
							{
								saved_word[7:0],
								saved_word[15:8],
								saved_word[23:16],
								saved_word[31:24]
							};
					endcase
					
					//Go fetch more data
					jtag_state		<= JTAG_STATE_FETCH_0;
					return_state	<= JTAG_STATE_SHIFT_2;
					
				end
				
				//Nothing in the inbox, go read more data
				else begin
					jtag_state		<= JTAG_STATE_FETCH_0;
					return_state	<= JTAG_STATE_SHIFT_2;
				end
			
			end	//end JTAG_STATE_SHIFT_2
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Informational querying
			
			JTAG_STATE_GET_STRING: begin
			
				//Writing a new word by default
				dma_txbuf_waddr	<= dma_txbuf_waddr	+ 1'h1;
				dma_txbuf_we	<= 1;
			
				//Send the string: "MARBLEWALRUS JTAG server v0.1"
				//(29 bytes text + 2 length = 31 bytes)
				//Note that current jtaghal protocol has *little* endian length!
				if(current_opcode == JTAGD_OP_GET_NAME) begin
					case(dma_txbuf_waddr)
						0:	dma_txbuf_wdata	<= {16'h1d00, "MA"};
						1:	dma_txbuf_wdata	<= "RBLE";
						2:	dma_txbuf_wdata	<= "WALR";
						3:	dma_txbuf_wdata	<= "US J";
						4:	dma_txbuf_wdata	<= "TAG ";
						5:	dma_txbuf_wdata	<= "serv";
						6:	dma_txbuf_wdata	<= "er v";
						7: begin
							dma_txbuf_wdata	<= {"0.1", 8'h00};
							jtag_state		<= JTAG_STATE_SEND;
						end
					endcase
				end
				
				//Send the serial number (64 bits hex = 8 bytes = 16 characters of actual data)
				if(current_opcode == JTAGD_OP_GET_SERIAL) begin
					case(dma_txbuf_waddr)
						0:	dma_txbuf_wdata	<= {16'h1000, die_serial[127:112]};
						1:	dma_txbuf_wdata	<= die_serial[111:80];
						2:	dma_txbuf_wdata	<= die_serial[79:48];
						3:	dma_txbuf_wdata	<= die_serial[47:16];
						4: begin
							dma_txbuf_wdata	<= {die_serial[15:0], 8'h00};
							jtag_state		<= JTAG_STATE_SEND;
						end
					endcase
				end
				
				//Send the user ID. We don't support this so just send "none"
				if(current_opcode == JTAGD_OP_GET_USERID) begin
					case(dma_txbuf_waddr)
						0:	dma_txbuf_wdata	<= {16'h0400, "no"};
						1: begin
							dma_txbuf_wdata	<= {"ne", 16'h00};
							jtag_state		<= JTAG_STATE_SEND;
						end
					endcase
				end
			
			end	//end JTAG_STATE_GET_STRING
			
			JTAG_STATE_GET_FREQ: begin
				
				//Writing one word of data
				dma_txbuf_waddr	<= dma_txbuf_waddr	+ 1'h1;
				dma_txbuf_we	<= 1;
				
				//Frequency is in Hz as a 32-bit little endian integer
				//For now, send constant 12.5 MHz = 0x00BEBC20
				dma_txbuf_wdata	<= 32'h20BCBE00;
				
				jtag_state		<= JTAG_STATE_SEND;
				
			end	//end JTAG_STATE_GET_FREQ
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Transmit helper states
			
			//Write the length and go to the transmit state
			JTAG_STATE_SEND: begin
			
				//Write the length
				dma_txbuf_we	<= 1;
				dma_txbuf_waddr	<= 0;
				
				//Start the send
				dtx_en			<= 1;
				dtx_dst_addr	<= tcp_addr;
				dtx_op			<= DMA_OP_WRITE_REQUEST;
				dtx_addr		<= {current_portnum, 16'h0};
				
				//Wait for send to complete
				jtag_state		<= JTAG_STATE_TX_HOLD;
				
				//Calculate length
				case(current_opcode)
					
					//Single-byte status queries
					JTAGD_OP_HAS_GPIO: begin
						dma_txbuf_wdata	<= 1;
						dtx_len			<= 2;
					end
					JTAGD_OP_COMMIT: begin
						dma_txbuf_wdata	<= 1;
						dtx_len			<= 2;
					end
					
					//String ID queries
					JTAGD_OP_GET_NAME: begin
						dma_txbuf_wdata	<= 31;
						dtx_len			<= 9;
					end
					JTAGD_OP_GET_SERIAL: begin
						dma_txbuf_wdata	<= 18;
						dtx_len			<= 5;
					end
					JTAGD_OP_GET_USERID: begin
						dma_txbuf_wdata	<= 6;
						dtx_len			<= 3;
					end
					
					//Single-word status queries
					JTAGD_OP_GET_FREQ: begin
						dma_txbuf_wdata	<= 4;
						dtx_len			<= 2;
					end
					
					//invalid, ignore them
					default: begin
						dma_txbuf_wdata	<= 0;
						dtx_len			<= 1;
						dtx_en			<= 0;
					end
					
				endcase
			
			end	//end JTAG_STATE_SEND
			
			JTAG_STATE_TX_HOLD: begin
				
				if(!dtx_en && !dtx_busy) begin
					
					//If there's more data to send, move on
					if( (rx_data_avail > 0) || (saved_word_len != 0) )
						jtag_state	<= JTAG_STATE_NEXT;
					
					//Nope, we're done
					else
						jtag_state	<= JTAG_STATE_IDLE;
					
				end
				
				//TODO: Wait for transmit-done interrupt? or flow control somehow?
				
			end	//end JTAG_STATE_TX_HOLD
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Debug states - should never be entered
			
			JTAG_STATE_HANG: begin
				drx_ready	 	<= 1;
				dma_inbox_full	<= 0;
			end	//end JTAG_STATE_HANG
			
		endcase
	
	end
	
endmodule
