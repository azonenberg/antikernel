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
	@brief JTAG
	
	@module
	@brief		JTAG master
	@opcodefile NetworkedJtagMaster_opcodes.constants
	
	@rpcfn		JTAG_OP_TEST_RESET
	@brief		Enters Test-Logic-Reset state
	
	@rpcfn_ok	JTAG_OP_TEST_RESET
	@brief		TAP state updated
	
	@rpcfn		JTAG_OP_RESET_IDLE
	@brief		Enters Run-Test-Idle state
	
	@rpcfn_ok	JTAG_OP_RESET_IDLE
	@brief		TAP state updated
	
	@rpcfn		JTAG_OP_SHIFT_DATA
	@brief		Shifts up to 32 bits of data through the scan chain
	@param		len			d0[5:0]:dec		Number of bits to shift
	@param		data		d1[31:0]:hex	The data to shift (right aligned, LSB first)
	@param		last_tms	d0[6]:dec		The TMS value to use for the last shift
	
	@rpcfn_ok	JTAG_OP_SHIFT_DATA
	@param		dout	d1[31:0]:hex	The shifted data (left aligned, LSB first)
	@brief		Shift complete
	
	@rpcfn		JTAG_OP_SELECT_IR
	@brief		Enters Shift-IR state
	
	@rpcfn_ok	JTAG_OP_SELECT_IR
	@brief		TAP state updated
	
	@rpcfn		JTAG_OP_LEAVE_IR
	@brief		Exits Shift-IR state and returns to run-test-idle
	
	@rpcfn_ok	JTAG_OP_LEAVE_IR
	@brief		TAP state updated
	
	@rpcfn		JTAG_OP_SELECT_DR
	@brief		Enters Shift-DR state
	
	@rpcfn_ok	JTAG_OP_SELECT_DR
	@brief		TAP state updated
	
	@rpcfn		JTAG_OP_LEAVE_DR
	@brief		Exits Shift-DR state and returns to run-test-idle
	
	@rpcfn_ok	JTAG_OP_LEAVE_DR
	@brief		TAP state updated
	
	DMA writes
		0x0000_0000 to scan data without touching TMS
		0x0000_0800 to scan data and toggle TMS on last bit
		First word of DMA message is length, in bits, of the data being scanned
 */
module NetworkedJtagMaster(
	
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
	output wire			jtag_tdi;
	input wire			jtag_tdo;
	output wire			jtag_tms;
	output wire			jtag_tck;
	
	//NoC interface
	output wire			rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0]	rpc_rx_ack;	
	
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The JTAG master core
	
	`include "JtagMaster_opcodes_constants.v"
	
	reg			state_en	= 0;
	reg[2:0]	next_state	= OP_TEST_RESET;
	reg[5:0]	len			= 0;
	reg			shift_en	= 0;
	reg			last_tms	= 0;
	reg[31:0]	din			= 0;
	wire[31:0]	dout;
	wire		done;
	
	//TODO: Programmable clock rates
	
	JtagMaster master(
		.clk(clk),			//200 MHz in unit test
		.clkdiv(8'd4),		//200 / (4*(div+1) ) = 10 MHz
		.tck(jtag_tck),
		.tdi(jtag_tdi),
		.tms(jtag_tms),
		.tdo(jtag_tdo),
		.state_en(state_en),
		.next_state(next_state),
		.len(len),
		.shift_en(shift_en),
		.last_tms(last_tms),
		.din(din),
		.dout(dout),
		.done(done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DMA transmit buffer
	
	reg[8:0]	dma_txbuf_waddr	= 0;
	
	reg[31:0]	dout_fwd	= 0;
	always @(*) begin
		dout_fwd	<= dout >> (32 - len);
	end
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(512),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) mem (
		
		//Write whenever a scan operation completes
		.porta_clk(clk),
		.porta_en(done),
		.porta_addr(dma_txbuf_waddr),
		.porta_we(done),
		.porta_din(dout_fwd),
		
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
	// Main state machine
	
	`include "NetworkedJtagMaster_opcodes_constants.v"
	`include "NetworkedJtagMaster_states_constants.v"
	
	reg[3:0] state = STATE_IDLE;
	
	reg			dma_inbox_full	= 0;
	reg[11:0]	dma_scan_len	= 0;
	
	always @(posedge clk) begin
	
		rpc_fab_tx_en	<= 0;
		rpc_fab_rx_done <= 0;
		dtx_en			<= 0;
		drx_buf_rd		<= 0;
		
		state_en		<= 0;
		shift_en		<= 0;
		
		if(drx_en) begin
			drx_ready		<= 0;
			dma_inbox_full	<= 1;
		end
		
		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for messages to show up
			STATE_IDLE: begin
			
				//Got a DMA message? Get ready to scan it (and prepare to respond)
				if(dma_inbox_full) begin
					dtx_dst_addr	<= drx_src_addr;
					dtx_addr		<= 0;
					dtx_op			<= DMA_OP_READ_DATA;
					dtx_len			<= drx_len - 10'h1;		//don't need a length field on the response data
					
					drx_buf_rd		<= 1;
					drx_buf_addr	<= 0;
					dma_txbuf_waddr	<= 0;
					state			<= STATE_DMA_LEN;
				end
				
				else if(rpc_fab_rx_inbox_full) begin
				
					//Save header info
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum	<= rpc_fab_rx_callnum;
					
					//Default to successful return
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					
					//Always flush the inbox
					rpc_fab_rx_done	<= 1;
				
					//Process it
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						
						//It's a function call
						case(rpc_fab_rx_callnum)
							
							//Go to test-logic-reset
							JTAG_OP_TEST_RESET: begin
								state_en		<= 1;
								next_state		<= OP_TEST_RESET;

								state			<= STATE_WAIT;
							end	//end JTAG_OP_TEST_RESET
							
							//Reset the scan chain to idle
							JTAG_OP_RESET_IDLE: begin
								state_en		<= 1;
								next_state		<= OP_RESET_IDLE;

								state			<= STATE_WAIT;
							end	//end JTAG_OP_RESET_IDLE
							
							//Enter Shift-IR state
							JTAG_OP_SELECT_IR: begin
								state_en		<= 1;
								next_state		<= OP_SELECT_IR;

								state			<= STATE_WAIT;
							end	//end JTAG_OP_SELECT_IR
							
							//Exit Shift-IR state and return to run-test-idle
							JTAG_OP_LEAVE_IR: begin
								state_en		<= 1;
								next_state		<= OP_LEAVE_IR;

								state			<= STATE_WAIT;
							end	//end JTAG_OP_LEAVE_IR
							
							//Enter Shift-DR state
							JTAG_OP_SELECT_DR: begin
								state_en		<= 1;
								next_state		<= OP_SELECT_DR;

								state			<= STATE_WAIT;
							end	//end JTAG_OP_SELECT_DR
							
							//Exit Shift-DR state and return to run-test-idle
							JTAG_OP_LEAVE_DR: begin
								state_en		<= 1;
								next_state		<= OP_LEAVE_DR;

								state			<= STATE_WAIT;
							end	//end JTAG_OP_LEAVE_DR
							
							//Shift data through the TAP
							JTAG_OP_SHIFT_DATA: begin
								shift_en		<= 1;
								din				<= rpc_fab_rx_d1;
								len				<= rpc_fab_rx_d0[5:0];
								last_tms		<= rpc_fab_rx_d0[6];
								
								state			<= STATE_WAIT;
							end	//end JTAG_OP_SHIFT_DATA
							
							//Unrecognized call, fail
							default: begin
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_IDLE;
							end
							
						endcase
						
					end
					
					else begin
						//Ignore it
						rpc_fab_rx_done <= 1;
					end
					
				end

			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for a scan operation to finish
		
			STATE_WAIT: begin
				if(done) begin
					rpc_fab_tx_d1	<= dout >> (32 - len);	//right align output data
					rpc_fab_tx_en	<= 1;
					state			<= STATE_RPC_TXHOLD;
				end
			end	//end STATE_WAIT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for RPC transmits to finish
			
			STATE_RPC_TXHOLD: begin
				if(rpc_fab_tx_done) begin
					rpc_fab_rx_done <= 1;
					state <= STATE_IDLE;
				end
			end	//end STATE_RPC_TXHOLD
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// DMA packet processing
			
			//Read the length field
			STATE_DMA_LEN: begin
				if(!drx_buf_rd) begin
					dma_scan_len	<= drx_buf_data[11:0];
					drx_buf_rd		<= 1;
					drx_buf_addr	<= 1;
					state			<= STATE_DMA_READ;
				end
			end	//end STATE_DMA_LEN
			
			//Read the next 32 bits of packet data, then scan them
			STATE_DMA_READ: begin
				if(!drx_buf_rd) begin
					shift_en		<= 1;
					din				<= drx_buf_data;
					
					//Last word? Send fractional word if needed. May also have special TMS handling
					if(dma_scan_len 	<= 32) begin
						last_tms		<= drx_addr[11];
						len				<= dma_scan_len[5:0];
						dma_scan_len	<= 0;
					end
					
					//Nope, send full word with nothing fancy for TMS
					else begin
						len				<= 32;
						last_tms		<= 0;
						dma_scan_len	<= dma_scan_len - 12'd32;
					end
					
					//Either way, wait for it to finish
					state	<= STATE_DMA_SCAN;
					
				end

			end	//end STATE_DMA_READ
			
			//Wait for the scan to complete
			STATE_DMA_SCAN: begin
				
				if(done) begin
				
					dma_txbuf_waddr	<= dma_txbuf_waddr + 9'h1;
					
					//If we just sent the last word, we're done - send the response
					if(dma_scan_len == 0) begin
						dtx_en		<= 1;
						state		<= STATE_DMA_TXHOLD;
					end
					
					//Nope, go to the next word
					else begin
						drx_buf_rd		<= 1;
						drx_buf_addr	<= drx_buf_addr + 10'h1;
						state			<= STATE_DMA_READ;
					end
				
				end
				
			end	//end STATE_DMA_SCAN
			
			//Wait for the DMA transmit to finish
			STATE_DMA_TXHOLD: begin
				if(!dtx_busy && !dtx_en) begin
					drx_ready		<= 1;
					dma_inbox_full	<= 0;
					state			<= STATE_IDLE;
				end
			end	//end STATE_DMA_TXHOLD
			
		endcase	
	end
	
endmodule
