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
	// The DUTs: four transceivers with a different bus width for each (TODO test non-quiet ones)

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

	//Receiver should never be blocked for too long
	reg[3:0] rx_timeout = 0;
	always @(posedge clk) begin
		rx_timeout <= rx_timeout + 1;

		//Reset timeout if we're no longer busy
		if(!rpc_fab_rx_ready)
			rx_timeout <= 0;

		assume(rx_timeout != 15);
	end

	//Counter of cycles since we began the transmit
	reg[2:0] word_count = 0;
	always @(posedge clk) begin
		if(rpc_tx_en_128)
			word_count	<= 1;
		if(word_count)
			word_count	<= word_count + 1'h1;
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
	reg[3:0] tx_timeout = 0;
	always @(posedge clk) begin
		tx_timeout <= tx_timeout + 1;

		//Reset timeout if we're no longer busy
		if(!somebody_busy)
			tx_timeout <= 0;

		assert(tx_timeout != 15);
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verified properties: 128-bit datapath

	always @(posedge clk) begin

		//If not sending, bus should be idle
		//TODO: dontcare for non-QUIET_WHEN_IDLE
		if(!rpc_tx_en_128) begin
			assert(rpc_tx_data_128 == 128'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_128);

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
	// Verified properties: 64-bit datapath

	always @(posedge clk) begin

		//If not sending, bus should be idle
		//TODO: dontcare for non-QUIET_WHEN_IDLE
		if(!rpc_tx_en_64 && !rpc_fab_tx_busy_64) begin
			assert(rpc_tx_data_64 == 64'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_64);

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
	// Verified properties: 32-bit datapath

	always @(posedge clk) begin

		//If not sending, bus should be idle
		//TODO: dontcare for non-QUIET_WHEN_IDLE
		if(!rpc_tx_en_32 && !rpc_fab_tx_busy_32) begin
			assert(rpc_tx_data_32 == 32'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_32);

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
	// Verified properties: 16-bit datapath

	always @(posedge clk) begin

		//If not sending, bus should be idle
		//TODO: dontcare for non-QUIET_WHEN_IDLE
		if(!rpc_tx_en_16 && !rpc_fab_tx_busy_16) begin
			assert(rpc_tx_data_16 == 16'h0);
		end

		//We're sending, must be correct data
		else begin

			//Should never try to transmit when receiver isn't ready
			assert (rpc_tx_ready_16);

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
				7: assert (rpc_tx_data_16 == /*rpc_fab_tx_d2[15:0]*/ 16'h55AA);	//should fail

			endcase
		end

	end

endmodule
