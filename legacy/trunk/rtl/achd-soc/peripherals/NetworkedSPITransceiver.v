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
	@brief SPI transceiver with NoC interface
	
	A single chip select pin is provided in the module, additional chip selects (if required) must be controlled
	through external GPIO.
	
	The following RPC operations are available:
		-------------------------------------------------------
		SPI_SET_CLKDIV 		Set clock divisor
		-------------------------------------------------------
			Parameters:		d0[15:0] = clock divisor
			Returns:		Success
			
		-------------------------------------------------------
		SPI_ASSERT_CS 		Assert chip select
		-------------------------------------------------------
			Parameters:		None
			Returns:		Success
			
		-------------------------------------------------------
		SPI_SEND_BYTE 		Sends a data byte
		-------------------------------------------------------
			Parameters:		d0[7:0] = byte to send
			Returns:		Success
			
		-------------------------------------------------------
		SPI_RECV_BYTE 		Reads a data byte
		-------------------------------------------------------
			Parameters:		None
			Returns:		Success
							d0[7:0] = byte to send
			
		-------------------------------------------------------
		SPI_DEASSERT_CS 	Deassert chip select
		-------------------------------------------------------
			Parameters:		None
			Returns:		Success
 */
module NetworkedSPITransceiver(
	
	//Clocks
	clk,
	
	//SPI interface
	spi_cs_n, spi_mosi, spi_miso, spi_sck,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;

	//The SPI interface
	output reg spi_cs_n = 1;
	output wire spi_mosi;
	output wire spi_sck;
	input wire spi_miso;
	
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
	wire		rpc_fab_tx_timeout;
	
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
		.rpc_fab_tx_timeout(rpc_fab_tx_timeout),
		
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
	// The SPI transceiver
	
	reg[15:0] clkdiv = 0;
	
	reg shift_en = 0;
	wire shift_done;
	reg[7:0] tx_data = 0;
	wire[7:0] rx_data;
	
	SPITransceiver spi_txvr(
		.clk(clk),
		.clkdiv(clkdiv),
		.spi_sck(spi_sck),
		.spi_mosi(spi_mosi),
		.spi_miso(spi_miso),
		.shift_en(shift_en),
		.shift_done(shift_done),
		.tx_data(tx_data),
		.rx_data(rx_data)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "NetworkedSPITransceiver_opcodes_constants.v"
	
	localparam STATE_IDLE		= 4'h0;
	localparam STATE_RPC_TXHOLD	= 4'h1;
	localparam STATE_SPI_WAIT	= 4'h2;
	
	reg[3:0] state = STATE_IDLE;
	
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
			
		shift_en <= 0;
			
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
							SPI_SET_CLKDIV: begin

								clkdiv <= rpc_fab_rx_d0[15:0];

								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end	//end SPI_SET_CLKDIV
							
							SPI_ASSERT_CS: begin
							
								spi_cs_n <= 0;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end	//end SPI_ASSERT_CS
							
							SPI_DEASSERT_CS: begin
							
								spi_cs_n <= 1;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end	//end SPI_DEASSERT_CS
							
							SPI_SEND_BYTE: begin
								shift_en <= 1;
								tx_data <= rpc_fab_rx_d0[7:0];
								state <= STATE_SPI_WAIT;
							end	//end SPI_SEND_BYTE
							
							SPI_RECV_BYTE: begin
								shift_en <= 1;
								tx_data <= 0;
								state <= STATE_SPI_WAIT;
							end	//end SPI_RECV_BYTE
							
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
			
			//Wait for SPI transmission to finish
			STATE_SPI_WAIT: begin
			
				if(shift_done) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
					rpc_fab_tx_d0 <= {13'h0, rx_data};
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
				end
			
			end	//end STATE_SPI_WAIT
		
		endcase	
	end
	
endmodule
