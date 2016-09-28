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
	@brief I2C transceiver with NoC interface
	
	Note that this core uses active-high ACKs, not active-low as seen on the wire!
	
	@module
	@brief		I2C transceiver
	@opcodefile NetworkedI2CTransceiver_opcodes.constants
	
	@rpcfn		I2C_SET_CLKDIV
	@param		clkdiv	d0[15:0]:dec		Clock divisor
	@brief		Set clock divisor
	
	@rpcfn_ok	I2C_SET_CLKDIV
	@brief		Clock divisor updated
	
	@rpcfn		I2C_SEND_START
	@brief		Send start bit
	
	@rpcfn_ok	I2C_SEND_START
	@brief		Start bit sent
	
	@rpcfn		I2C_SEND_RESTART
	@brief		Send restart bit
	
	@rpcfn_ok	I2C_SEND_RESTART
	@brief		Restart bit sent
	
	@rpcfn		I2C_SEND_STOP
	@brief		Send stop bit
	
	@rpcfn_ok	I2C_SEND_STOP
	@brief		Stop bit sent
	
	@rpcfn		I2C_SEND_BYTE
	@param		data	d0[7:0]:hex			Data to send
	@brief		Send data byte
	
	@rpcfn_ok	I2C_SEND_START
	@param		ack		d0[0]:dec			Acknowledge flag (active-high)
	@brief		Start bit sent
	
	@rpcfn		I2C_RECV_BYTE
	@param		ack		d0[0]:dec			Acknowledge flag (active-high)
	@brief		Send data byte
	
	@rpcfn_ok	I2C_SEND_START
	@param		data	d0[7:0]:hex			Data from slave
	@brief		Start bit sent
 */
module NetworkedI2CTransceiver(
	
	//Clocks
	clk,
	
	//I2C interface
	i2c_sda, i2c_scl,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;

	//The I2C interface
	inout wire i2c_sda;
	output wire i2c_scl;
	
	//NoC interface
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR = 16'h0000;
	
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
		
		.rpc_fab_inbox_full(),
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The I2C transceiver
	
	reg i2c_tx_en = 0;
	reg[7:0] i2c_tx_data = 0;
	wire i2c_tx_ack;
	wire i2c_tx_rdy;
	reg i2c_rx_en = 0;
	wire i2c_rx_rdy;
	wire[7:0] i2c_rx_out;
	reg i2c_rx_ack = 0;
	reg i2c_start_en = 0;
	reg i2c_restart_en = 0;
	reg i2c_stop_en = 0;
	wire i2c_busy;
	
	reg[15:0] clkdiv = 1;
	
	I2CTransceiver txvr_i2c(
		.clk(clk),
		.clkdiv(clkdiv),
		.i2c_scl(i2c_scl),
		.i2c_sda(i2c_sda),
		.tx_en(i2c_tx_en),
		.tx_ack(i2c_tx_ack),
		.tx_data(i2c_tx_data),
		.rx_en(i2c_rx_en),
		.rx_rdy(i2c_rx_rdy),
		.rx_out(i2c_rx_out),
		.rx_ack(i2c_rx_ack),
		.start_en(i2c_start_en),
		.restart_en(i2c_restart_en),
		.stop_en(i2c_stop_en),
		.busy(i2c_busy)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "NetworkedI2CTransceiver_opcodes_constants.v"
	
	localparam STATE_IDLE		= 4'h0;
	localparam STATE_RPC_TXHOLD	= 4'h1;
	localparam STATE_I2C_BUSY	= 4'h2;
	localparam STATE_I2C_RECV	= 4'h3;
	
	reg[3:0] state = STATE_IDLE;
	
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		
		i2c_start_en <= 0;
		i2c_restart_en <= 0;
		i2c_stop_en <= 0;
		i2c_tx_en <= 0;
		i2c_rx_en <= 0;
		
		case(state)
		
			//Wait for messages to show up
			STATE_IDLE: begin
				if(rpc_fab_rx_en) begin
				
					//Save header info
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
				
					//Process it
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						
						//It's a function call
						case(rpc_fab_rx_callnum)
							
							//Set baud rate
							I2C_SET_CLKDIV: begin

								clkdiv <= rpc_fab_rx_d0[15:0];

								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end	//end I2C_SET_CLKDIV
							
							//Send start bit
							I2C_SEND_START: begin
								i2c_start_en <= 1;
								state <= STATE_I2C_BUSY;								
							end	//end I2C_SEND_START
							
							//Send restart bit
							I2C_SEND_RESTART: begin
								i2c_restart_en <= 1;
								state <= STATE_I2C_BUSY;								
							end	//end I2C_SEND_RESTART
							
							//Send stop bit
							I2C_SEND_STOP: begin
								i2c_stop_en <= 1;
								state <= STATE_I2C_BUSY;
							end	//end I2C_SEND_STOP
							
							//Send a data byte
							I2C_SEND_BYTE: begin
								i2c_tx_en <= 1;
								i2c_tx_data <= rpc_fab_rx_d0[7:0];
								state <= STATE_I2C_BUSY;
							end	//end I2C_SEND_BYTE
							
							//Receive a data byte
							I2C_RECV_BYTE: begin
								i2c_rx_en <= 1;
								i2c_rx_ack <= rpc_fab_rx_d0[0];
								state <= STATE_I2C_RECV;
							end	//end I2C_RECV_BYTE
							
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
			
			//Wait for RPC transmits to finish
			STATE_RPC_TXHOLD: begin
				if(rpc_fab_tx_done) begin
					rpc_fab_rx_done <= 1;
					state <= STATE_IDLE;
				end
			end	//end STATE_RPC_TXHOLD
			
			//Wait for I2C transmits to finish, then send success
			STATE_I2C_BUSY: begin
				if(!i2c_busy) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
					rpc_fab_tx_d0 <= {20'h0, i2c_tx_ack};
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
				end
			end	//end STATE_I2C_BUSY
			
			//Wait for I2C receives to finish
			STATE_I2C_RECV: begin
				if(i2c_rx_rdy) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
					rpc_fab_tx_d0 <= {13'h0, i2c_rx_out};
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
				end
			end	//end STATE_I2C_RECV
			
		endcase	
	end
	
endmodule
