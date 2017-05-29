`default_nettype none
`timescale 1ns / 1ps
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Formal verification test harness for RPCv3RouterTransmitter_*
 */
module TxRouterLinkTester #(
	parameter IN_DATA_WIDTH = 32,
	parameter OUT_DATA_WIDTH = 32
)(
	input wire						clk,

	input wire						rpc_fab_tx_packet_start,
	input wire						rpc_fab_tx_wr_en,
	input wire[IN_DATA_WIDTH-1:0]	rpc_fab_tx_wr_data,

	input wire						rpc_fab_rx_ready
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Proof configuration

	`include "../../../antikernel-ipcores/proof_helpers/implies.vh"
	`include "../../../antikernel-ipcores/synth_helpers/clog2.vh"

	//Source address of all messages
	parameter NODE_ADDR = 16'h4141;

	//Number of clocks it takes to send/receive a message
	localparam MESSAGE_CYCLES	= 128 / IN_DATA_WIDTH;
	localparam MESSAGE_MAX		= MESSAGE_CYCLES - 1'h1;
	localparam PHASE_BITS_RAW	= clog2(MESSAGE_CYCLES);
	localparam PHASE_BITS		= (PHASE_BITS_RAW == 0) ? 1 : PHASE_BITS;

	//Number of 16-bit words in the input bus
	localparam IN_MESSAGE_WORDS = IN_DATA_WIDTH / 16;
	localparam IN_WORD_SHIFT	= clog2(IN_MESSAGE_WORDS);

	//Width conversion, if any
	localparam EXPANDING = (IN_DATA_WIDTH < OUT_DATA_WIDTH);
	localparam COLLAPSING = (IN_DATA_WIDTH > OUT_DATA_WIDTH);
	localparam BUFFERING = (IN_DATA_WIDTH == OUT_DATA_WIDTH);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	wire					rpc_tx_en;
	wire[IN_DATA_WIDTH-1:0]	rpc_tx_data;
	wire					rpc_tx_ready;

	wire[5:0]				rpc_fab_tx_fifo_size;
	wire					rpc_fab_tx_packet_done;

	wire					fifo_rdata_valid;

	generate

		if(BUFFERING) begin
			RPCv3RouterTransmitter_buffering #(
				.IN_DATA_WIDTH(IN_DATA_WIDTH),
				.OUT_DATA_WIDTH(OUT_DATA_WIDTH)
			) dut (
				.rpc_tx_en(rpc_tx_en),
				.rpc_tx_data(rpc_tx_data),
				.rpc_tx_ready(rpc_tx_ready),

				.rpc_fab_tx_fifo_size(rpc_fab_tx_fifo_size),
				.rpc_fab_tx_packet_start(rpc_fab_tx_packet_start),
				.rpc_fab_tx_wr_en(rpc_fab_tx_wr_en),
				.rpc_fab_tx_wr_data(rpc_fab_tx_wr_data),
				.rpc_fab_tx_packet_done(rpc_fab_tx_packet_done),

				.fifo_rdata_valid(fifo_rdata_valid)
			);
		end

		else begin
			initial begin
				$display("ERROR: Dont know what to do with data widths %d, %d", IN_DATA_WIDTH, OUT_DATA_WIDTH);
				$finish;
			end
		end

	endgenerate

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receiver (for sanity checking generated traffic)

	wire						rpc_tx_en_unused;
	wire[OUT_DATA_WIDTH-1:0]	rpc_tx_data_unused;
	wire						rpc_fab_tx_busy_unused;
	wire						rpc_fab_tx_done_unused;

	wire						rpc_tx_ready;
	wire						rpc_fab_rx_en;
	wire						rpc_fab_rx_busy;
	wire[15:0]					rpc_fab_rx_src_addr;
	wire[15:0]					rpc_fab_rx_dst_addr;
	wire[7:0]					rpc_fab_rx_callnum;
	wire[2:0]					rpc_fab_rx_type;
	wire[20:0]					rpc_fab_rx_d0;
	wire[31:0]					rpc_fab_rx_d1;
	wire[31:0]					rpc_fab_rx_d2;

	RPCv3Transceiver #(
		.DATA_WIDTH(OUT_DATA_WIDTH),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(NODE_ADDR)
	) sender (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_unused),
		.rpc_tx_data(rpc_tx_data_unused),
		.rpc_tx_ready(1'b0),

		.rpc_rx_en(rpc_tx_en),
		.rpc_rx_data(rpc_tx_data),
		.rpc_rx_ready(rpc_tx_ready),

		.rpc_fab_tx_en(1'b0),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_unused),
		.rpc_fab_tx_dst_addr(16'h0),
		.rpc_fab_tx_src_addr(16'h0),
		.rpc_fab_tx_callnum(8'h0),
		.rpc_fab_tx_type(3'h0),
		.rpc_fab_tx_d0(21'h0),
		.rpc_fab_tx_d1(32'h0),
		.rpc_fab_tx_d2(32'h0),
		.rpc_fab_tx_done(rpc_fab_tx_done_unused),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy),
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO of messages in line waiting to be sent

	//The message we're sending
	reg[127:0]			tx_message 			= 0;
	reg[PHASE_BITS-1:0]	txbuf_phase			= 0;
	reg					write_in_progress	= 0;

	wire[127:0]	tx_message_next		= {tx_message[128 - IN_DATA_WIDTH +: IN_DATA_WIDTH], rpc_fab_tx_wr_data};

	always @(posedge clk) begin

		if(rpc_fab_tx_wr_en) begin

			//Beginning of the message
			if(rpc_fab_tx_packet_start) begin
				txbuf_phase			<= 1;
				write_in_progress	<= 1;
			end

			//Move through the message
			else
				txbuf_phase			<= txbuf_phase + 1'h1;

			//Either way, shift the input
			tx_message				<= tx_message_next;
		end

	end

	//Write to the FIFO when we've assembled a full message
	reg		txbuf_wr_en;
	always @(*) begin
		if(IN_DATA_WIDTH == 128)
			txbuf_wr_en		<= rpc_fab_tx_wr_en;
		else
			txbuf_wr_en		<= rpc_fab_tx_wr_en && (txbuf_phase == MESSAGE_MAX)
	end

	//The set of messages in the queue
	wire[5:0]			vfifo_message_count;
	SingleClockShiftRegisterFifo #(
		.WIDTH(128),
		.DEPTH(32),
		.OUT_REG(1)
	) pending_messages (
		.clk(clk),
		.wr(txbuf_wr_en),
		.din(tx_message_next),

		.rd(),
		.dout(),
		.overflow(),
		.underflow(),
		.empty(),
		.full(),
		.rsize(vfifo_message_count),
		.wsize(),

		.reset(1'b0)		//never reset the fifo
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Make sure the FIFO sizes line up

	//Number of words of free space
	wire[10:0]		txvr_words_free		= { rpc_fab_tx_fifo_size, {IN_WORD_SHIFT{1'h0}} };

	//Don't send anything if we lack a full message worth of FIFO space
	//TODO: allow partial writes when the fifo is full?
	assume property( implies(rpc_fab_tx_wr_en, (txvr_words_free >= 8)) );

	//Number of valid entries / words in the transceiver FIFO
	wire[5:0]	txvr_lines_used		= (32 - rpc_fab_tx_fifo_size + fifo_rdata_valid);
	wire[10:0]	txvr_words_used		= { txvr_lines_used, {IN_WORD_SHIFT{1'h0}} };

	//Number of valid entries / words in the verification FIFO
	wire[5:0]	vfifo_lines_used	= vfifo_message_count;
	wire[10:0]	vfifo_words_used	= {vfifo_lines_used, 3'h0};

	//Verify that we always have the same number of messages in each FIFO.
	//Actual size can vary due to width variations, we only care about *packets*
	//assert property(txvr_words_used[10:3] == vfifo_words_used[10:3]);

	/*
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Keep track of overall transceiver state

	reg			busy						= 0;
	reg[7:0]	bits_valid					= 0;
	reg			rpc_fab_tx_packet_start_ff	= 0;
	reg			rpc_fab_tx_packet_start_ff2	= 0;

	reg[3:0]	tx_words_valid				= 0;

	wire		full_message_in_txbuf	= (txbuf_words_valid == MESSAGE_CYCLES);
	wire		message_in_txbuf		= (txbuf_words_valid != 0);
	wire		full_message_sent		= (tx_words_valid == MESSAGE_CYCLES);
	wire		message_being_sent		= (tx_words_valid != 0) && (tx_words_valid != MESSAGE_CYCLES);

	always @(posedge clk) begin

		//Start a new packet
		if(rpc_fab_tx_packet_start)
			busy		<= 1;

		//Finish the packet
		if(rpc_fab_rx_en)
			busy		<= 0;

		//Keep track of how many bits have been sent
		if(rpc_tx_en)
			tx_words_valid	<= 1;
		else if(busy && message_being_sent )
			tx_words_valid	<= tx_words_valid + 1'h1;
		if(rpc_fab_tx_packet_done)
			tx_words_valid	<= 0;

		//Keep track of iu
		rpc_fab_tx_packet_start_ff	<= rpc_fab_tx_packet_start;
		rpc_fab_tx_packet_start_ff2	<= rpc_fab_tx_packet_start_ff;

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Constraints on inputs

	//We should never have more than 128 valid bits in a message as that's the whole packet size
	assert property(txbuf_words_valid <= MESSAGE_CYCLES);
	assert property(tx_words_valid <= MESSAGE_CYCLES);

	//Don't start sending a packet if we don't have enough space for it
	assume property( implies(rpc_fab_tx_packet_start, rpc_fab_tx_fifo_size > 3) );

	//Simplify initial testing: don't start if the TX buffer isn't empty
	assume property( implies(rpc_fab_tx_packet_start, txbuf_words_valid == 0));

	//Simplify initial testing: don't start if an RX is in progress
	assume property( implies(rpc_fab_tx_packet_start, !rpc_fab_rx_en));

	//Simplify initial testing: don't start if we're busy
	assume property( implies(rpc_fab_tx_packet_start, !busy));

	//Always assert wr_en at start of a packet.
	//Continue to assert wr_en until we have the entire message
	wire		should_be_writing = rpc_fab_tx_packet_start || ( message_in_txbuf && !full_message_in_txbuf );
	assume property(should_be_writing == rpc_fab_tx_wr_en );

	//Do not write if we have the whole message, unless we're starting a new one
	assume property( implies((busy && full_message_in_txbuf), !rpc_fab_tx_wr_en) );

	//Only write if we're busy or starting a message
	assume property( implies(rpc_fab_tx_wr_en, busy || rpc_fab_tx_packet_start) );

	//Do not write if there's already a full message in the fifo
	assume property( implies(rpc_fab_tx_packet_start, (tx_words_valid == 0) ) );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity checks

	//We should always be busy if we have a half-written message
	assert property( implies( (tx_words_valid != 0) && !full_message_in_txbuf, busy) );

	//FIFO should never have more than 32 words of space in it, since that's the total capacity
	assert property( rpc_fab_tx_fifo_size <= 32 );

	//FIFO should never have more than N words of space used, since we don't allow pushing until another is popped
	assert property( rpc_fab_tx_fifo_size >= (32 - MESSAGE_CYCLES) );

	//FIFO should be empty if we are not busy
	assert property( implies( rpc_fab_tx_fifo_size != 32, busy) );
	assert property( implies( fifo_rdata_valid, busy) );

	//If we have a message in the transmit buffer, or being sent, we should be busy
	assert property( implies(message_in_txbuf, busy) );
	assert property( implies(message_being_sent, busy) );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verify the outbound message

	//If we're busy and the receiver is ready, we should send.
	//Don't send one cycle after we started the packet, though! There's latency in the transmitter.
	wire	should_be_sending	= busy && rpc_tx_ready && !rpc_fab_tx_packet_start_ff &&
									message_in_txbuf && !message_being_sent;
	assert property( rpc_tx_en == should_be_sending);
	*/

endmodule
