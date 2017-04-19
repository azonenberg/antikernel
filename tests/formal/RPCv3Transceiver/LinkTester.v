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
	@brief Formal validation test harness for RPCv3Transceiver - single node wrapper
 */
module LinkTester(
	input wire					clk,

	input wire					rpc_fab_tx_en,
	input wire[15:0]			rpc_fab_tx_dst_addr,
	input wire[7:0]				rpc_fab_tx_callnum,
	input wire[2:0]				rpc_fab_tx_type,
	input wire[20:0]			rpc_fab_tx_d0,
	input wire[31:0]			rpc_fab_tx_d1,
	input wire[31:0]			rpc_fab_tx_d2,

	input wire					rpc_fab_rx_ready
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Proof configuration

	//Source address of all messages
	parameter NODE_ADDR = 16'h4141;

	//Width of the data bus being tested
	parameter DATA_WIDTH = 128;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DUT: Quiet version (tx_data held zero when not sending)

	wire					rpc_tx_en;
	wire[DATA_WIDTH-1:0]	rpc_tx_data;
	wire					rpc_tx_ready;

	wire					rpc_fab_tx_done;
	wire					rpc_fab_tx_busy;

	wire					rpc_fab_rx_en;
	wire					rpc_fab_rx_busy;
	wire[15:0]				rpc_fab_rx_src_addr;
	wire[15:0]				rpc_fab_rx_dst_addr;
	wire[7:0]				rpc_fab_rx_callnum;
	wire[2:0]				rpc_fab_rx_type;
	wire[20:0]				rpc_fab_rx_d0;
	wire[31:0]				rpc_fab_rx_d1;
	wire[31:0]				rpc_fab_rx_d2;

	RPCv3Transceiver #(
		.DATA_WIDTH(DATA_WIDTH),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(NODE_ADDR)
	) dut (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ready(rpc_tx_ready),

		.rpc_rx_en(rpc_tx_en),
		.rpc_rx_data(rpc_tx_data),
		.rpc_rx_ready(rpc_tx_ready),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),

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
	// Noisy versions (less gates, can inject arbitrary noise from rpc_fab_* on rpc_tx_data when not sending)

	wire					rpc_tx_en_noisy;
	wire[DATA_WIDTH-1:0]	rpc_tx_data_noisy;

	wire					rpc_fab_tx_done_noisy;
	wire					rpc_fab_tx_busy_noisy;

	wire					rpc_tx_ready_noisy;

	wire					rpc_fab_rx_busy_noisy;
	wire					rpc_fab_rx_en_noisy;
	wire[15:0]				rpc_fab_rx_src_addr_noisy;
	wire[15:0]				rpc_fab_rx_dst_addr_noisy;
	wire[7:0]				rpc_fab_rx_callnum_noisy;
	wire[2:0]				rpc_fab_rx_type_noisy;
	wire[20:0]				rpc_fab_rx_d0_noisy;
	wire[31:0]				rpc_fab_rx_d1_noisy;
	wire[31:0]				rpc_fab_rx_d2_noisy;

	RPCv3Transceiver #(
		.DATA_WIDTH(DATA_WIDTH),
		.QUIET_WHEN_IDLE(0),
		.NODE_ADDR(NODE_ADDR)
	) dut_noisy (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_noisy),
		.rpc_tx_data(rpc_tx_data_noisy),
		.rpc_tx_ready(rpc_tx_ready),

		.rpc_rx_en(rpc_tx_en),
		.rpc_rx_data(rpc_tx_data),
		.rpc_rx_ready(rpc_tx_ready_noisy),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_noisy),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_noisy),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy_noisy),
		.rpc_fab_rx_en(rpc_fab_rx_en_noisy),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr_noisy),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr_noisy),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum_noisy),
		.rpc_fab_rx_type(rpc_fab_rx_type_noisy),
		.rpc_fab_rx_d0(rpc_fab_rx_d0_noisy),
		.rpc_fab_rx_d1(rpc_fab_rx_d1_noisy),
		.rpc_fab_rx_d2(rpc_fab_rx_d2_noisy)
	);

	//Assert that _noisy outputs are identical to normal stuff
	assert property(rpc_fab_tx_busy == rpc_fab_tx_busy_noisy);
	assert property(rpc_fab_tx_done == rpc_fab_tx_done_noisy);

	assert property(rpc_fab_rx_busy == rpc_fab_rx_busy_noisy);
	assert property(rpc_fab_rx_en == rpc_fab_rx_en_noisy);
	assert property(rpc_fab_rx_src_addr == rpc_fab_rx_src_addr_noisy);
	assert property(rpc_fab_rx_dst_addr == rpc_fab_rx_dst_addr_noisy);
	assert property(rpc_fab_rx_callnum == rpc_fab_rx_callnum_noisy);
	assert property(rpc_fab_rx_type == rpc_fab_rx_type_noisy);
	assert property(rpc_fab_rx_d0 == rpc_fab_rx_d0_noisy);
	assert property(rpc_fab_rx_d1 == rpc_fab_rx_d1_noisy);
	assert property(rpc_fab_rx_d2 == rpc_fab_rx_d2_noisy);

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

		if(rpc_fab_rx_en)
			transaction_active	<= 0;

		if(rpc_fab_tx_en)
			transaction_active	<= 1;

	end

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

	//word_count value where we are expected to complete sending the packet
	reg[3:0]	expected_finish_cycle;
	always @(*) begin
		case(DATA_WIDTH)
			128:	expected_finish_cycle	<= 0;
			64:		expected_finish_cycle	<= 1;
			32:		expected_finish_cycle	<= 3;
			16:		expected_finish_cycle	<= 7;
		endcase
	end

	//We should be done when word_count is equal to expected_finish_cycle.
	//But if we're a 128-bit datapath, tx_en has to be asserted too.
	reg			tx_done_expected;
	always @(*) begin
		tx_done_expected		<=	(expected_finish_cycle == word_count);

		if( (DATA_WIDTH == 128) &&  !rpc_tx_en )
			tx_done_expected	<= 0;
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
		if(rpc_fab_tx_en && !transaction_active) begin
			tx_dst_addr_saved	<= rpc_fab_tx_dst_addr;
			tx_callnum_saved	<= rpc_fab_tx_callnum;
			tx_type_saved		<= rpc_fab_tx_type;
			tx_d0_saved			<= rpc_fab_tx_d0;
			tx_d1_saved			<= rpc_fab_tx_d1;
			tx_d2_saved			<= rpc_fab_tx_d2;
		end
	end

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
	// Verified properties: timing and sync

	//Transmitter should never be busy for too long
	assert property(word_count <= 8);

	//We should never send if the receiver isn't ready
	assert property(! (rpc_tx_en && !rpc_tx_ready) );

	//If there is a message waiting to be sent, we should send as soon as possible.
	//Do not send if there are no messages to send, or if we already have a message in progress
	wire ready_to_send		= tx_pending || rpc_fab_tx_en;
	wire should_be_sending	= (ready_to_send && rpc_tx_ready) && (word_count == 0);
	assert property(should_be_sending == rpc_tx_en);

	//Make sure we finished (128 / DATA_WIDTH) cycles after we started sending
	assert property(rpc_fab_tx_done == tx_done_expected);

	//TX should be busy if we have a pending transmit, or a message is currently on the wire
	wire message_on_wire = rpc_tx_en || (word_count >= 1) && (word_count <= expected_finish_cycle);
	assert property(rpc_fab_tx_busy == (message_on_wire || tx_pending));

	//Receiver should be done one cycle after transmit finishes
	assert property(rpc_fab_rx_en == tx_done_ff);

	//If datapath is not 128 bits wide, we should never have two transmits back to back
	always @(posedge clk) begin
		if(DATA_WIDTH != 128)
			assert(!tx_en_ff || !rpc_tx_en);
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: Noisy transmitters

	//All status flags should be identical to non-noisy ones
	assert property(rpc_tx_en == rpc_tx_en_noisy);
	assert property(rpc_fab_tx_done == rpc_fab_tx_done_noisy);
	assert property(rpc_fab_tx_busy == rpc_fab_tx_busy_noisy);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: transmit datapath

	always @(posedge clk) begin

		//If not sending, quiet bus should be idle (noisy bus is a don't care)
		if(!message_on_wire) begin
			assert(rpc_tx_data == {DATA_WIDTH{1'b0}});
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			//Protocol change - tx_ready will go low after we start sending
			if(word_count == 0)
				assert (rpc_tx_ready);

			//Quiet transmitter should be same as noisy one here
			assert(rpc_tx_data == rpc_tx_data_noisy);

			//Verify we get the correct data
			case(DATA_WIDTH)

				128: begin
					if(word_count == 0) begin
						assert (rpc_tx_data ==
						{
							rpc_fab_tx_dst_addr,
							NODE_ADDR,
							rpc_fab_tx_callnum,
							rpc_fab_tx_type,
							rpc_fab_tx_d0,
							rpc_fab_tx_d1,
							rpc_fab_tx_d2
						});
					end
				end	//end 128

				64: begin

					case(word_count)

						0: begin
							assert (rpc_tx_data ==
							{
								rpc_fab_tx_dst_addr,
								NODE_ADDR,
								rpc_fab_tx_callnum,
								rpc_fab_tx_type,
								rpc_fab_tx_d0
							});
						end

						1: begin
							assert (rpc_tx_data ==
							{
								rpc_fab_tx_d1,
								rpc_fab_tx_d2
							});
						end

					endcase

				end	//end 64

				32: begin
					case(word_count)

						0: begin
							assert (rpc_tx_data ==
							{
								rpc_fab_tx_dst_addr,
								NODE_ADDR
							});
						end

						1: begin
							assert (rpc_tx_data ==
							{
								rpc_fab_tx_callnum,
								rpc_fab_tx_type,
								rpc_fab_tx_d0
							});
						end

						2: assert (rpc_tx_data == rpc_fab_tx_d1);
						3: assert (rpc_tx_data == rpc_fab_tx_d2);

					endcase
				end	//end 32

				16: begin
					case(word_count)

						0: assert (rpc_tx_data == rpc_fab_tx_dst_addr);
						1: assert (rpc_tx_data == NODE_ADDR);

						2: begin
							assert (rpc_tx_data ==
							{
								rpc_fab_tx_callnum,
								rpc_fab_tx_type,
								rpc_fab_tx_d0[20:16]
							});
						end

						3: assert (rpc_tx_data == rpc_fab_tx_d0[15:0]);
						4: assert (rpc_tx_data == rpc_fab_tx_d1[31:16]);
						5: assert (rpc_tx_data == rpc_fab_tx_d1[15:0]);
						6: assert (rpc_tx_data == rpc_fab_tx_d2[31:16]);
						7: assert (rpc_tx_data == rpc_fab_tx_d2[15:0]);

					endcase
				end	//end 16
			endcase

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: receive datapath

	always @(posedge clk) begin

		//The data we receive should be the same as what was transmitted
		if(rpc_fab_rx_en) begin
			assert(rpc_fab_rx_src_addr	== NODE_ADDR);
			assert(rpc_fab_rx_dst_addr	== tx_dst_addr_saved);
			assert(rpc_fab_rx_callnum	== tx_callnum_saved);
			assert(rpc_fab_rx_type		== tx_type_saved);
			assert(rpc_fab_rx_d0		== tx_d0_saved);
			assert(rpc_fab_rx_d1		== tx_d1_saved);
			assert(rpc_fab_rx_d2		== tx_d2_saved);
		end

		//TODO: Receive data won't change if rx_ready is low

	end

endmodule
