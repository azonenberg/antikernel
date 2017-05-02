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

	//Source address of all messages
	parameter NODE_ADDR = 16'h4141;

	//Number of clocks it takes to send/receive a message
	localparam MESSAGE_CYCLES = 128 / IN_DATA_WIDTH;

	//Width conversion, if any
	localparam EXPANDING = (IN_DATA_WIDTH < OUT_DATA_WIDTH);
	localparam COLLAPSING = (IN_DATA_WIDTH > OUT_DATA_WIDTH);
	localparam BUFFERING = (IN_DATA_WIDTH == OUT_DATA_WIDTH);

	`include "../../../antikernel-ipcores/proof_helpers/implies.vh"

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Constraints on inputs

	//Don't start sending a packet if we don't have enough space for it
	assume property( implies(rpc_fab_tx_packet_start, rpc_fab_tx_fifo_size > 3) );

	//Go simple to start: don't start if the fifo isn't empty
	assume property( implies(rpc_fab_tx_packet_start, rpc_fab_tx_fifo_size == 32));

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	wire					rpc_tx_en;
	wire[IN_DATA_WIDTH-1:0]	rpc_tx_data;
	wire					rpc_tx_ready;

	wire[5:0]				rpc_fab_tx_fifo_size;
	wire					rpc_fab_tx_packet_done;

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
				.rpc_fab_tx_packet_done(rpc_fab_tx_packet_done)
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

		.rpc_rx_en(1'b0),
		.rpc_rx_data({IN_DATA_WIDTH{1'b0}}),
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
	// State machine for processing outbound data

	//The message we're sending
	reg[127:0] tx_message = 0;

	always @(posedge clk) begin
	end


	/*
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification helpers

	//Keep track of whether messages are waiting to be sent
	reg tx_pending = 0;
	always @(posedge clk) begin

		//No longer have a message pending once this one gets sent
		if(rpc_tx_en)
			tx_pending		<= 0;

		//If we try to send and the link is busy, send it later
		if(rpc_fab_tx_en && !rpc_tx_ready)
			tx_pending		<= 1;

		//We can't have a pending message if we're still sending the last one
		if(word_count != 0)
			tx_pending		<= 0;

	end

	//True if a message is waiting to be sent, but not being sent this cycle
	wire tx_pending_unfulfilled = tx_pending && !rpc_tx_en;

	//Indicates a full tx-rx transaction is in progress
	reg transaction_active		= 0;
	always @(posedge clk) begin

		if(rpc_fab_rx_packet_done )
			transaction_active	<= 0;

		if(rpc_tx_en)
			transaction_active	<= 1;

	end

	//Constrain the initial state: if we have a pending transmit, a transaction must be active
	assume property(!tx_pending || transaction_active);

	//Counter of cycles since we actually began the transmit (position in the packet)
	reg[3:0]	word_count = 0;
	always @(posedge clk) begin
		if(rpc_tx_en)
			word_count	<= 1;
		if(word_count)
			word_count	<= word_count + 1'h1;

		if(rpc_fab_tx_done)
			word_count	<= 0;
	end

	//Word_count value where we are expected to complete sending the packet
	reg[3:0]	expected_finish_cycle;
	always @(*) begin
		expected_finish_cycle				<= 0;
		case(IN_DATA_WIDTH)
			64:		expected_finish_cycle	<= 1;
			32:		expected_finish_cycle	<= 3;
			16:		expected_finish_cycle	<= 7;
		endcase
	end

	//We should be done when word_count is equal to expected_finish_cycle.
	reg			tx_done_expected;
	always @(*) begin
		tx_done_expected		<=	(expected_finish_cycle == word_count);
	end

	//Keep track of if a transmit just started or finished
	reg		tx_en_ff	= 0;
	reg		tx_done_ff	= 0;
	always @(posedge clk) begin
		tx_en_ff	<= rpc_tx_en;
		tx_done_ff	<= rpc_fab_tx_done;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Save transmit data when we begin sending

	reg[15:0]	tx_dst_addr_saved	= 0;
	reg[7:0]	tx_callnum_saved	= 0;
	reg[2:0]	tx_type_saved		= 0;
	reg[20:0]	tx_d0_saved			= 0;
	reg[31:0]	tx_d1_saved			= 0;
	reg[31:0]	tx_d2_saved			= 0;

	always @(posedge clk) begin
		if(rpc_tx_en) begin
			tx_dst_addr_saved	<= rpc_fab_tx_dst_addr;
			tx_callnum_saved	<= rpc_fab_tx_callnum;
			tx_type_saved		<= rpc_fab_tx_type;
			tx_d0_saved			<= rpc_fab_tx_d0;
			tx_d1_saved			<= rpc_fab_tx_d1;
			tx_d2_saved			<= rpc_fab_tx_d2;
		end
	end

	//Verification helper: Don't allow send when the link is busy
	//We already verified correct flow control for this elsewhere, no need to re-test
	//and it makes our verification nasty if we have two messages in the pipe at once
	assume property(! (rpc_fab_tx_en && rpc_fab_rx_data_valid) );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Preconditions

	//External test logic should not block receiving for too many cycles
	reg[3:0] rx_timeout = 0;
	always @(posedge clk) begin

		//Keep counting up for as long as we're busy, reset when available
		if(rpc_fab_rx_ready)
			rx_timeout <= 0;
		if(!rpc_fab_rx_ready)
			rx_timeout <= rx_timeout + 1;

		assume(rx_timeout <= 10);
	end

	always @(posedge clk) begin

		if(transaction_active) begin

			//Result of changing inputs when sending is undefined. Don't do it.
			assume (rpc_fab_tx_dst_addr	== tx_dst_addr_saved);
			assume (rpc_fab_tx_callnum	== tx_callnum_saved);
			assume (rpc_fab_tx_type		== tx_type_saved);
			assume (rpc_fab_tx_d0		== tx_d0_saved);
			assume (rpc_fab_tx_d1		== tx_d1_saved);
			assume (rpc_fab_tx_d2		== tx_d2_saved);
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: receive datapath

	//Can't use x_saved b/c they haven't been set yet
	wire[127:0] expected_message =
	{
		rpc_fab_tx_dst_addr,
		NODE_ADDR,
		rpc_fab_tx_callnum,
		rpc_fab_tx_type,
		rpc_fab_tx_d0,
		rpc_fab_tx_d1,
		rpc_fab_tx_d2
	};

	//High OUT_DATA_WIDTH bits should be the next block of our message
	reg[127:0] message_shreg = 0;

	wire[OUT_DATA_WIDTH-1:0] expected_word = message_shreg[127: (128 - OUT_DATA_WIDTH)];

	//When we hit this count value, we should be writing the last message word
	wire expected_done = ( (out_count + 1) * OUT_DATA_WIDTH == 128 ) && rpc_fab_rx_data_valid;

	reg[3:0] out_count = 0;
	always @(posedge clk) begin

		//At the end, we should have seen a full 128 bits.
		//Note that rx_packet_done and rx_data_valid are asserted concurrently on the last message word
		assert(rpc_fab_rx_packet_done == expected_done);

		//Each time we assert rpc_fab_rx_data_valid we should get another OUT_DATA_WIDTH bits of the message
		if(rpc_fab_rx_data_valid) begin
			assert(rpc_fab_rx_data == expected_word);
			message_shreg	<= {message_shreg[128 - OUT_DATA_WIDTH : 0], {OUT_DATA_WIDTH{1'b0}}};
		end

		//Keep track of how many output words we've seen so far
		//We have to check for packet_start after data_valid since we can start and stop packets simultaneously
		//if two packets are sent back to back.
		//Same thing applies to writing message_shreg after we do the shift
		if(rpc_fab_rx_data_valid)
			out_count		<= out_count + 1'h1;
		if(rpc_fab_rx_packet_start) begin
			out_count		<= 0;
			message_shreg	<= expected_message;
		end

		//Clear state when the message finishes
		if(rpc_fab_rx_packet_done)
			out_count		<= 0;

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: timing and sync

	//Receiver should start the packet as soon as the transmit begins
	assert property(rpc_fab_rx_packet_start == rpc_tx_en);

	generate

		//If expanding, outbound packet is shorter than inbound.
		//Receiver should be done one cycle after transmit finishes.
		if(EXPANDING)
			assert property(rpc_fab_rx_packet_done == tx_done_ff);

		//If collapsing, outbound packet is longer - we need more time
		else if(COLLAPSING) begin

			//Add a delay to the start flag for determining when the output begins
			reg rpc_fab_rx_packet_start_ff	= 0;
			reg rpc_fab_rx_packet_start_ff2	= 0;
			always @(posedge clk) begin
				rpc_fab_rx_packet_start_ff	<= rpc_fab_rx_packet_start;
				rpc_fab_rx_packet_start_ff2	<= rpc_fab_rx_packet_start_ff;
			end

			//Packet should be output starting two clocks later than the send began
			assert property(implies(rpc_fab_rx_packet_start_ff2, rpc_fab_rx_data_valid));

			//Packet should be output constantly until the end, with no delays
			assert property(implies( (out_count != 0), rpc_fab_rx_data_valid) );

		end

	endgenerate
	*/

endmodule
