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
	@brief Formal validation test harness for RPCv3Transceiver

	The goal of this test is to prove that a MemoryMacro actually functions like memory and has the correct latency.

	This test only covers a single clock domain; multi-domain behavior is not tested.
 */
module main(
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
	localparam NODE_ADDR = 16'h4141;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUTs: four transceivers with a different bus width for each
	// Quiet version (tx_data held zero when not sending)

	wire		rpc_tx_en_128;
	wire[127:0]	rpc_tx_data_128;
	wire		rpc_tx_ready_128;

	wire		rpc_fab_tx_done_128;
	wire		rpc_fab_tx_busy_128;

	wire		rpc_fab_rx_en_128;
	wire		rpc_fab_rx_busy_128;
	wire[15:0]	rpc_fab_rx_src_addr_128;
	wire[7:0]	rpc_fab_rx_callnum_128;
	wire[2:0]	rpc_fab_rx_type_128;
	wire[20:0]	rpc_fab_rx_d0_128;
	wire[31:0]	rpc_fab_rx_d1_128;
	wire[31:0]	rpc_fab_rx_d2_128;

	RPCv3Transceiver #(
		.DATA_WIDTH(128),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(NODE_ADDR)
	) dut_128 (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_128),
		.rpc_tx_data(rpc_tx_data_128),
		.rpc_tx_ready(rpc_tx_ready_128),

		.rpc_rx_en(rpc_tx_en_128),
		.rpc_rx_data(rpc_tx_data_128),
		.rpc_rx_ready(rpc_tx_ready_128),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_128),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_128),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy_128),
		.rpc_fab_rx_en(rpc_fab_rx_en_128),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr_128),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum_128),
		.rpc_fab_rx_type(rpc_fab_rx_type_128),
		.rpc_fab_rx_d0(rpc_fab_rx_d0_128),
		.rpc_fab_rx_d1(rpc_fab_rx_d1_128),
		.rpc_fab_rx_d2(rpc_fab_rx_d2_128),
	);

	wire		rpc_tx_en_64;
	wire[63:0]	rpc_tx_data_64;
	wire		rpc_tx_ready_64;

	wire		rpc_fab_tx_done_64;
	wire		rpc_fab_tx_busy_64;

	wire		rpc_fab_rx_en_64;
	wire		rpc_fab_rx_busy_64;
	wire[15:0]	rpc_fab_rx_src_addr_64;
	wire[7:0]	rpc_fab_rx_callnum_64;
	wire[2:0]	rpc_fab_rx_type_64;
	wire[20:0]	rpc_fab_rx_d0_64;
	wire[31:0]	rpc_fab_rx_d1_64;
	wire[31:0]	rpc_fab_rx_d2_64;

	RPCv3Transceiver #(
		.DATA_WIDTH(64),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(NODE_ADDR)
	) dut_64 (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_64),
		.rpc_tx_data(rpc_tx_data_64),
		.rpc_tx_ready(rpc_tx_ready_64),

		.rpc_rx_en(rpc_tx_en_64),
		.rpc_rx_data(rpc_tx_data_64),
		.rpc_rx_ready(rpc_tx_ready_64),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_64),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_64),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy_64),
		.rpc_fab_rx_en(rpc_fab_rx_en_64),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr_64),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum_64),
		.rpc_fab_rx_type(rpc_fab_rx_type_64),
		.rpc_fab_rx_d0(rpc_fab_rx_d0_64),
		.rpc_fab_rx_d1(rpc_fab_rx_d1_64),
		.rpc_fab_rx_d2(rpc_fab_rx_d2_64),
	);

	wire		rpc_tx_en_32;
	wire[31:0]	rpc_tx_data_32;
	wire		rpc_tx_ready_32;

	wire		rpc_fab_tx_done_32;
	wire		rpc_fab_tx_busy_32;

	wire		rpc_fab_rx_en_32;
	wire		rpc_fab_rx_busy_32;
	wire[15:0]	rpc_fab_rx_src_addr_32;
	wire[7:0]	rpc_fab_rx_callnum_32;
	wire[2:0]	rpc_fab_rx_type_32;
	wire[20:0]	rpc_fab_rx_d0_32;
	wire[31:0]	rpc_fab_rx_d1_32;
	wire[31:0]	rpc_fab_rx_d2_32;

	RPCv3Transceiver #(
		.DATA_WIDTH(32),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(NODE_ADDR)
	) dut_32 (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_32),
		.rpc_tx_data(rpc_tx_data_32),
		.rpc_tx_ready(rpc_tx_ready_32),

		.rpc_rx_en(rpc_tx_en_32),
		.rpc_rx_data(rpc_tx_data_32),
		.rpc_rx_ready(rpc_tx_ready_32),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_32),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_32),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy_32),
		.rpc_fab_rx_en(rpc_fab_rx_en_32),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr_32),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum_32),
		.rpc_fab_rx_type(rpc_fab_rx_type_32),
		.rpc_fab_rx_d0(rpc_fab_rx_d0_32),
		.rpc_fab_rx_d1(rpc_fab_rx_d1_32),
		.rpc_fab_rx_d2(rpc_fab_rx_d2_32),
	);

	wire		rpc_tx_en_16;
	wire[15:0]	rpc_tx_data_16;
	wire		rpc_tx_ready_16;

	wire		rpc_fab_tx_done_16;
	wire		rpc_fab_tx_busy_16;

	wire		rpc_fab_rx_en_16;
	wire		rpc_fab_rx_busy_16;
	wire[15:0]	rpc_fab_rx_src_addr_16;
	wire[7:0]	rpc_fab_rx_callnum_16;
	wire[2:0]	rpc_fab_rx_type_16;
	wire[20:0]	rpc_fab_rx_d0_16;
	wire[31:0]	rpc_fab_rx_d1_16;
	wire[31:0]	rpc_fab_rx_d2_16;

	RPCv3Transceiver #(
		.DATA_WIDTH(16),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(NODE_ADDR)
	) dut_16 (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_16),
		.rpc_tx_data(rpc_tx_data_16),
		.rpc_tx_ready(rpc_tx_ready_16),

		.rpc_rx_en(rpc_tx_en_16),
		.rpc_rx_data(rpc_tx_data_16),
		.rpc_rx_ready(rpc_tx_ready_16),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_16),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_16),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy_16),
		.rpc_fab_rx_en(rpc_fab_rx_en_16),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr_16),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum_16),
		.rpc_fab_rx_type(rpc_fab_rx_type_16),
		.rpc_fab_rx_d0(rpc_fab_rx_d0_16),
		.rpc_fab_rx_d1(rpc_fab_rx_d1_16),
		.rpc_fab_rx_d2(rpc_fab_rx_d2_16),
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Noisy versions of the DUTs (less gates, can inject arbitrary noise on tx_data when not sending)

	wire		rpc_tx_en_128_noisy;
	wire[127:0]	rpc_tx_data_128_noisy;

	wire		rpc_fab_tx_done_128_noisy;
	wire		rpc_fab_tx_busy_128_noisy;

	RPCv3Transceiver #(
		.DATA_WIDTH(128),
		.QUIET_WHEN_IDLE(0),
		.NODE_ADDR(NODE_ADDR)
	) dut_128_noisy (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_128_noisy),
		.rpc_tx_data(rpc_tx_data_128_noisy),
		.rpc_tx_ready(rpc_tx_ready_128),

		.rpc_rx_en(),
		.rpc_rx_data(),
		.rpc_rx_ready(),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_128_noisy),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_128_noisy),

		.rpc_fab_rx_ready(),
		.rpc_fab_rx_busy(),
		.rpc_fab_rx_en(),
		.rpc_fab_rx_src_addr(),
		.rpc_fab_rx_callnum(),
		.rpc_fab_rx_type(),
		.rpc_fab_rx_d0(),
		.rpc_fab_rx_d1(),
		.rpc_fab_rx_d2(),
	);

	wire		rpc_tx_en_64_noisy;
	wire[63:0]	rpc_tx_data_64_noisy;

	wire		rpc_fab_tx_done_64_noisy;
	wire		rpc_fab_tx_busy_64_noisy;

	RPCv3Transceiver #(
		.DATA_WIDTH(64),
		.QUIET_WHEN_IDLE(0),
		.NODE_ADDR(NODE_ADDR)
	) dut_64_noisy (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_64_noisy),
		.rpc_tx_data(rpc_tx_data_64_noisy),
		.rpc_tx_ready(rpc_tx_ready_64),

		.rpc_rx_en(),
		.rpc_rx_data(),
		.rpc_rx_ready(),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_64_noisy),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_64_noisy),

		.rpc_fab_rx_ready(),
		.rpc_fab_rx_busy(),
		.rpc_fab_rx_en(),
		.rpc_fab_rx_src_addr(),
		.rpc_fab_rx_callnum(),
		.rpc_fab_rx_type(),
		.rpc_fab_rx_d0(),
		.rpc_fab_rx_d1(),
		.rpc_fab_rx_d2(),
	);

	wire		rpc_tx_en_32_noisy;
	wire[31:0]	rpc_tx_data_32_noisy;

	wire		rpc_fab_tx_done_32_noisy;
	wire		rpc_fab_tx_busy_32_noisy;

	RPCv3Transceiver #(
		.DATA_WIDTH(32),
		.QUIET_WHEN_IDLE(0),
		.NODE_ADDR(NODE_ADDR)
	) dut_32_noisy (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_32_noisy),
		.rpc_tx_data(rpc_tx_data_32_noisy),
		.rpc_tx_ready(rpc_tx_ready_32),

		.rpc_rx_en(),
		.rpc_rx_data(),
		.rpc_rx_ready(),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_32_noisy),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_32_noisy),

		.rpc_fab_rx_ready(),
		.rpc_fab_rx_busy(),
		.rpc_fab_rx_en(),
		.rpc_fab_rx_src_addr(),
		.rpc_fab_rx_callnum(),
		.rpc_fab_rx_type(),
		.rpc_fab_rx_d0(),
		.rpc_fab_rx_d1(),
		.rpc_fab_rx_d2(),
	);

	wire		rpc_tx_en_16_noisy;
	wire[15:0]	rpc_tx_data_16_noisy;

	wire		rpc_fab_tx_done_16_noisy;
	wire		rpc_fab_tx_busy_16_noisy;

	RPCv3Transceiver #(
		.DATA_WIDTH(16),
		.QUIET_WHEN_IDLE(0),
		.NODE_ADDR(NODE_ADDR)
	) dut_16_noisy (
		.clk(clk),

		.rpc_tx_en(rpc_tx_en_16_noisy),
		.rpc_tx_data(rpc_tx_data_16_noisy),
		.rpc_tx_ready(rpc_tx_ready_16),

		.rpc_rx_en(),
		.rpc_rx_data(),
		.rpc_rx_ready(),

		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy_16_noisy),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done_16_noisy),

		.rpc_fab_rx_ready(),
		.rpc_fab_rx_busy(),
		.rpc_fab_rx_en(),
		.rpc_fab_rx_src_addr(),
		.rpc_fab_rx_callnum(),
		.rpc_fab_rx_type(),
		.rpc_fab_rx_d0(),
		.rpc_fab_rx_d1(),
		.rpc_fab_rx_d2(),
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Save transmit data when we begin sending

	reg[15:0]	tx_dst_addr_saved	= 0;
	reg[7:0]	tx_callnum_saved	= 0;
	reg[2:0]	tx_type_saved		= 0;
	reg[20:0]	tx_d0_saved			= 0;
	reg[31:0]	tx_d1_saved			= 0;
	reg[31:0]	tx_d2_saved			= 0;

	always @(posedge clk) begin
		if(rpc_fab_tx_en) begin
			tx_dst_addr_saved	<= rpc_fab_tx_dst_addr;
			tx_callnum_saved	<= rpc_fab_tx_callnum;
			tx_type_saved		<= rpc_fab_tx_type;
			tx_d0_saved			<= rpc_fab_tx_d0;
			tx_d1_saved			<= rpc_fab_tx_d1;
			tx_d2_saved			<= rpc_fab_tx_d2;
		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification helpers

	//Keep track of whether messages are waiting to be sent
	reg tx_pending = 0;
	always @(posedge clk) begin

		//No longer have a message pending once this one gets sent
		if(rpc_tx_en_128)
			tx_pending		<= 0;

		//If we try to send and the link is busy, send it later
		if(rpc_fab_tx_en && !rpc_tx_ready_128)
			tx_pending		<= 1;

	end

	//True if a message is waiting to be sent, but not being sent this cycle
	wire tx_pending_unfulfilled = tx_pending && !rpc_tx_en_128;

	//Set busy flag as soon as a transmit comes in, clear when the last transmit is done
	reg[3:0] busy_mask		= 0;
	always @(posedge clk) begin

		if(rpc_fab_tx_en)
			busy_mask		<= 4'b1111;

		if(rpc_fab_rx_en_128)
			busy_mask[3]	<= 0;
		if(rpc_fab_rx_en_64)
			busy_mask[2]	<= 0;
		if(rpc_fab_rx_en_32)
			busy_mask[1]	<= 0;
		if(rpc_fab_rx_en_16)
			busy_mask[0]	<= 0;

	end
	wire somebody_busy		= (busy_mask != 0);

	//External test logic should not block receiving for too many cycles
	reg[3:0] rx_timeout = 0;
	always @(posedge clk) begin
		rx_timeout <= rx_timeout + 1;

		//Reset timeout if we're still busy
		if(!rpc_tx_ready_128)
			rx_timeout <= 0;

		assume(rx_timeout != 15);
	end

	//Counter of cycles since we actually began the transmit (position in the packet)
	reg[3:0] word_count = 0;
	always @(posedge clk) begin
		if(rpc_tx_en_128)
			word_count	<= 1;
		if(word_count)
			word_count	<= word_count + 1'h1;

		if(rpc_fab_tx_done_16)
			word_count	<= 0;
	end

	//Keep track of if a transmit just finished
	reg		rpc_fab_tx_done_128_ff	= 0;
	reg		rpc_fab_tx_done_64_ff	= 0;
	reg		rpc_fab_tx_done_32_ff	= 0;
	reg		rpc_fab_tx_done_16_ff	= 0;
	always @(posedge clk) begin
		rpc_fab_tx_done_128_ff	<= rpc_fab_tx_done_128;
		rpc_fab_tx_done_64_ff	<= rpc_fab_tx_done_64;
		rpc_fab_tx_done_32_ff	<= rpc_fab_tx_done_32;
		rpc_fab_tx_done_16_ff	<= rpc_fab_tx_done_16;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Preconditions

	always @(posedge clk) begin

		if(somebody_busy) begin

			//For initial verification, don't try to transmit if we're already sending.
			//TODO: verify this doesn't trigger a new send or anything derpy?
			assume(!rpc_fab_tx_en);

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

	//Shorter packets should always finish sending before longer ones
	always @(posedge clk) begin
		if(busy_mask[3])
			assert(busy_mask[2:0] == 3'b111);
		if(busy_mask[2])
			assert(busy_mask[1:0] == 2'b11);
		if(busy_mask[1])
			assert(busy_mask[0] == 1'b1);
	end

	//Nobody should be doing anything if we're not busy.
	//This ensures everyone starts in a clean state when tx_en is asserted.
	always @(posedge clk) begin
		if(!somebody_busy) begin
			assert(!rpc_fab_tx_busy_128);
			assert(!rpc_fab_tx_busy_64);
			assert(!rpc_fab_tx_busy_32);
			assert(!rpc_fab_tx_busy_16);

			assert(!rpc_fab_rx_busy_128);
			assert(!rpc_fab_rx_busy_64);
			assert(!rpc_fab_rx_busy_32);
			assert(!rpc_fab_rx_busy_16);
		end

	end

	//Transmitter should never be busy for too long
	assert property(word_count <= 8);

	//All transceivers should start sending at the same time
	assert property(rpc_tx_en_128 == rpc_tx_en_64);
	assert property(rpc_tx_en_128 == rpc_tx_en_32);
	assert property(rpc_tx_en_128 == rpc_tx_en_16);

	//We should never send if the receiver isn't ready
	assert property(! (rpc_tx_en_128 && !rpc_tx_ready_128) );
	assert property(! (rpc_tx_en_64 && !rpc_tx_ready_64) );
	assert property(! (rpc_tx_en_32 && !rpc_tx_ready_32) );
	assert property(! (rpc_tx_en_16 && !rpc_tx_ready_16) );

	//If there is a message waiting to be sent, we should send as soon as possible.
	//Do not send if there are no messages to send, though.
	wire ready_to_send		= tx_pending || rpc_fab_tx_en;
	wire should_be_sending	= ready_to_send && rpc_tx_ready_128;
	assert property(should_be_sending == rpc_tx_en_128);

	//128-bit transmitter should finish combinatorially the same cycle the packet goes out.
	//Should never be busy unless RX is blocking.
	assert property(rpc_tx_en_128 == rpc_fab_tx_done_128);
	assert property(rpc_fab_tx_busy_128 == tx_pending_unfulfilled);

	//64-bit transmitter should finish one cycle after packet begins.
	//Busy during that cycle only.
	//If transmitter blocks, we're busy before that too.
	wire is_cycle_1 = (word_count == 1);
	assert property(rpc_fab_tx_done_64 == is_cycle_1);
	assert property(rpc_fab_tx_busy_64 == (is_cycle_1 || tx_pending) );

	//32-bit transmitter should finish three cycles after packet begins.
	//Busy during that time, or if bus isn't ready yet
	wire is_cycle_3 = (word_count == 3);
	wire is_cycle_1to3 = (word_count >= 1) && (word_count <= 3);
	assert property(rpc_fab_tx_done_32 == is_cycle_3);
	assert property(rpc_fab_tx_busy_32 == (is_cycle_1to3 || tx_pending) );

	//16-bit transmitter should finish seven cycles after packet begins.
	//Busy during that time.
	wire is_cycle_7 = (word_count == 7);
	wire is_cycle_1to7 = (word_count >= 1) && (word_count <= 7);
	assert property(rpc_fab_tx_done_16 == is_cycle_7);
	assert property(rpc_fab_tx_busy_16 == (is_cycle_1to7 || tx_pending) );

	//Receiver should be done one cycle after transmit finishes
	assert property(rpc_fab_rx_en_128 == rpc_fab_tx_done_128_ff);
	assert property(rpc_fab_rx_en_64  == rpc_fab_tx_done_64_ff);
	assert property(rpc_fab_rx_en_32  == rpc_fab_tx_done_32_ff);
	assert property(rpc_fab_rx_en_16  == rpc_fab_tx_done_16_ff);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: Noisy transmitters

	//All status flags should be identical to non-noisy ones
	assert property(rpc_tx_en_128 == rpc_tx_en_128_noisy);
	assert property(rpc_tx_en_64  == rpc_tx_en_64_noisy);
	assert property(rpc_tx_en_32  == rpc_tx_en_32_noisy);
	assert property(rpc_tx_en_16  == rpc_tx_en_16_noisy);

	assert property(rpc_fab_tx_done_128 == rpc_fab_tx_done_128_noisy);
	assert property(rpc_fab_tx_done_64  == rpc_fab_tx_done_64_noisy);
	assert property(rpc_fab_tx_done_32  == rpc_fab_tx_done_32_noisy);
	assert property(rpc_fab_tx_done_16  == rpc_fab_tx_done_16_noisy);

	assert property(rpc_fab_tx_busy_128 == rpc_fab_tx_busy_128_noisy);
	assert property(rpc_fab_tx_busy_64  == rpc_fab_tx_busy_64_noisy);
	assert property(rpc_fab_tx_busy_32  == rpc_fab_tx_busy_32_noisy);
	assert property(rpc_fab_tx_busy_16  == rpc_fab_tx_busy_16_noisy);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 128-bit transmit datapath

	always @(posedge clk) begin

		//If not sending, quiet bus should be idle, noisy bus is a don't care
		if(!rpc_tx_en_128) begin
			assert(rpc_tx_data_128 == 128'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_128);

			//Quiet transmitter should be same as noisy one here
			assert(rpc_tx_data_128 == rpc_tx_data_128_noisy);

			//If we're transmitting, we should have the correct data
			assert (rpc_tx_data_128 ==
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

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 128-bit receive datapath

	always @(posedge clk) begin

		//The data we receive should be the same as what was transmitted
		if(rpc_fab_rx_en_128) begin
			assert(rpc_fab_rx_src_addr_128	== NODE_ADDR);
			assert(rpc_fab_rx_callnum_128	== tx_callnum_saved);
			assert(rpc_fab_rx_type_128		== tx_type_saved);
			assert(rpc_fab_rx_d0_128		== tx_d0_saved);
			assert(rpc_fab_rx_d1_128		== tx_d1_saved);
			assert(rpc_fab_rx_d2_128		== tx_d2_saved);
		end

		//TODO: Receive data won't change if rx_ready is low

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 64-bit transmit datapath

	always @(posedge clk) begin

		//If not sending, quiet bus should be idle, noisy bus is a don't care
		if(!rpc_tx_en_64 && (word_count == 0)) begin
			assert(rpc_tx_data_64 == 64'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_64);

			//Quiet transmitter should be same as noisy one here
			if(word_count <= 1)
				assert(rpc_tx_data_64 == rpc_tx_data_64_noisy);

			//If we're transmitting, we should have the correct data
			case(word_count)

				0: begin
					assert (rpc_tx_data_64 ==
					{
						rpc_fab_tx_dst_addr,
						NODE_ADDR,
						rpc_fab_tx_callnum,
						rpc_fab_tx_type,
						rpc_fab_tx_d0
					});
				end

				1: begin
					assert (rpc_tx_data_64 ==
					{
						rpc_fab_tx_d1,
						rpc_fab_tx_d2
					});
				end

			endcase

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 64-bit receive datapath

	always @(posedge clk) begin

		//The data we receive should be the same as what was transmitted
		if(rpc_fab_rx_en_64) begin
			assert(rpc_fab_rx_src_addr_64	== NODE_ADDR);
			assert(rpc_fab_rx_callnum_64	== tx_callnum_saved);
			assert(rpc_fab_rx_type_64		== tx_type_saved);
			assert(rpc_fab_rx_d0_64			== tx_d0_saved);
			assert(rpc_fab_rx_d1_64			== tx_d1_saved);
			assert(rpc_fab_rx_d2_64			== tx_d2_saved);
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 32-bit transmit datapath

	always @(posedge clk) begin

		//If not sending, quiet bus should be idle, noisy bus is a don't care
		if(!rpc_tx_en_32 && (word_count == 0)) begin
			assert(rpc_tx_data_32 == 32'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_32);

			//Quiet transmitter should be same as noisy one here
			if(word_count <= 3)
				assert(rpc_tx_data_32 == rpc_tx_data_32_noisy);

			//If we're transmitting, we should have the correct data
			case(word_count)

				0: begin
					assert (rpc_tx_data_32 ==
					{
						rpc_fab_tx_dst_addr,
						NODE_ADDR
					});
				end

				1: begin
					assert (rpc_tx_data_32 ==
					{
						rpc_fab_tx_callnum,
						rpc_fab_tx_type,
						rpc_fab_tx_d0
					});
				end

				2: assert (rpc_tx_data_32 == rpc_fab_tx_d1);

				3: assert (rpc_tx_data_32 == rpc_fab_tx_d2);

			endcase

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 32-bit receive datapath

	always @(posedge clk) begin

		//The data we receive should be the same as what was transmitted
		if(rpc_fab_rx_en_32) begin
			assert(rpc_fab_rx_src_addr_32	== NODE_ADDR);
			assert(rpc_fab_rx_callnum_32	== tx_callnum_saved);
			assert(rpc_fab_rx_type_32		== tx_type_saved);
			assert(rpc_fab_rx_d0_32			== tx_d0_saved);
			assert(rpc_fab_rx_d1_32			== tx_d1_saved);
			assert(rpc_fab_rx_d2_32			== tx_d2_saved);
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 16-bit transmit datapath

	always @(posedge clk) begin

		//If not sending, quiet bus should be idle, noisy bus is a don't care
		if(!rpc_tx_en_16 && (word_count == 0)) begin
			assert(rpc_tx_data_16 == 16'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_16);

			//Quiet transmitter should be same as noisy one here
			if(word_count <= 7)
				assert(rpc_tx_data_16 == rpc_tx_data_16_noisy);

			//If we're transmitting, we should have the correct data
			case(word_count)

				0: assert (rpc_tx_data_16 == rpc_fab_tx_dst_addr);
				1: assert (rpc_tx_data_16 == NODE_ADDR);

				2: begin
					assert (rpc_tx_data_16 ==
					{
						rpc_fab_tx_callnum,
						rpc_fab_tx_type,
						rpc_fab_tx_d0[20:16]
					});
				end

				3: assert (rpc_tx_data_16 == rpc_fab_tx_d0[15:0]);

				4: assert (rpc_tx_data_16 == rpc_fab_tx_d1[31:16]);
				5: assert (rpc_tx_data_16 == rpc_fab_tx_d1[15:0]);

				6: assert (rpc_tx_data_16 == rpc_fab_tx_d2[31:16]);
				7: assert (rpc_tx_data_16 == rpc_fab_tx_d2[15:0]);

			endcase
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 16-bit receive datapath

	always @(posedge clk) begin

		//The data we receive should be the same as what was transmitted
		if(rpc_fab_rx_en_16) begin
			assert(rpc_fab_rx_src_addr_16	== NODE_ADDR);
			assert(rpc_fab_rx_callnum_16	== tx_callnum_saved);
			assert(rpc_fab_rx_type_16		== tx_type_saved);
			assert(rpc_fab_rx_d0_16			== tx_d0_saved);
			assert(rpc_fab_rx_d1_16			== tx_d1_saved);
			assert(rpc_fab_rx_d2_16			== tx_d2_saved);
		end

	end

endmodule
