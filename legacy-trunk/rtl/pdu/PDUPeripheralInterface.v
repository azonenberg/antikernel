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
	@brief Peripheral controller for PDU. Several peripherals share one RPC port.
	
	Contains the following peripherals:
		* One I2C channel
		* Three SPI channels
		* One 32-bit timer
		* Ten bidirectional GPIOs
		* One fault LED
		* Two one-hot voltage-select inputs
	
	TODO: Inputs from temp sensor alerts etc?
	
	The following RPC operations are available:
		TODO: Document
 */
module PDUPeripheralInterface(
	
	//Clocks
	clk,
	
	//I2C interface
	i2c_sda, i2c_scl,
	
	//SPI interface (3 channels)
	spi_cs_n, spi_mosi, spi_sck, spi_miso,
	
	//GPIO interface
	gpio,
	
	//Fault LED
	fault_led,
	
	//Voltage select inputs
	voltage_mode_5, voltage_mode_12,
	
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
	
	//The SPI interface
	output reg[2:0] spi_cs_n = 3'b111;
	output wire[2:0] spi_mosi;
	output wire[2:0] spi_sck;
	input wire[2:0] spi_miso;
	
	//The GPIO interface
	inout wire[9:0] gpio;
	
	//Indicator LEDs
	output reg fault_led = 0;
	
	//Voltage selectors
	input wire voltage_mode_5;
	input wire voltage_mode_12;
	
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
	wire		rpc_fab_inbox_full;
	
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
				
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
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
	
	reg[15:0] i2c_clkdiv = 1;
	
	I2CTransceiver txvr_i2c(
		.clk(clk),
		.clkdiv(i2c_clkdiv),
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
	// The SPI transceivers
		
	reg[15:0] spi_clkdiv[2:0];
	reg[2:0] shift_en;
	wire[2:0] shift_done;
	reg[7:0] tx_data[2:0];
	wire[7:0] rx_data[2:0];
	
	integer j;
	initial begin
		for(j=0; j<3; j=j+1) begin
			spi_clkdiv[j] <= 0;
			shift_en[j] <= 0;
			tx_data[j] <= 0;
		end
	end
		
	genvar i;
	generate
		for(i=0; i<3; i = i+1) begin: spiblock
			SPITransceiver txvr_spi(
				.clk(clk),
				.clkdiv(spi_clkdiv[i]),
				.spi_sck(spi_sck[i]),
				.spi_mosi(spi_mosi[i]),
				.spi_miso(spi_miso[i]),
				.shift_en(shift_en[i]),
				.shift_done(shift_done[i]),
				.tx_data(tx_data[i]),
				.rx_data(rx_data[i])
				);
		end
	endgenerate
	
	wire[1:0] spi_chnum = rpc_fab_rx_d1[1:0];
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GPIO interface

	wire[9:0] gpio_in;
	reg[9:0] gpio_out = 0;
	reg[9:0] gpio_oe = 0;

	generate
		for(i=0; i<10; i = i+1) begin: gpio_iobuf
			IOBUF iobuf(.I(gpio_out[i]), .IO(gpio[i]), .O(gpio_in[i]), .T(!gpio_oe[i]));
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Timer
	
	reg timer_active = 0;
	reg[31:0] timer_max = 0;
	reg[31:0] timer_count = 0;
	reg[15:0] timer_notify_host = 0;
	
	reg timer_reset = 0;
	reg timer_notify_flag = 0;
	
	always @(posedge clk) begin
	
		//Count up if we haven't tripped yet
		if(!timer_notify_flag && timer_active) begin
			timer_count <= timer_count + 32'h1;
			
			if(timer_count == timer_max)
				timer_notify_flag <= 1;
		end
	
		//Reset
		if(timer_reset) begin
			timer_notify_flag <= 0;
			timer_count <= 0;
		end
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main module logic
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "PDUPeripheralInterface_opcodes_constants.v"
	`include "PDUPeripheralInterface_states_constants.v"

	reg[3:0] state = STATE_IDLE;
	
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		
		i2c_start_en <= 0;
		i2c_restart_en <= 0;
		i2c_stop_en <= 0;
		i2c_tx_en <= 0;
		i2c_rx_en <= 0;
		
		shift_en[0] <= 0;
		shift_en[1] <= 0;
		shift_en[2] <= 0;
		
		timer_reset <= 0;

		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for messages to show up
			STATE_IDLE: begin
			
				//Timer tick
				if(timer_notify_flag) begin
					
					rpc_fab_tx_dst_addr <= timer_notify_host;
					rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_callnum <= PERIPH_INT_TIMER;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
					
					timer_reset <= 1;
					
				end
			
				else if(rpc_fab_inbox_full) begin
				
					//Save header info
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
				
					//Process it
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						
						//It's a function call
						case(rpc_fab_rx_callnum)
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// I2C
							
							//Set baud rate
							PERIPH_I2C_SET_CLKDIV: begin

								i2c_clkdiv <= rpc_fab_rx_d0[15:0];

								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
								
								
							end	//end I2C_SET_CLKDIV
							
							//Send start bit
							PERIPH_I2C_SEND_START: begin
								i2c_start_en <= 1;
								state <= STATE_I2C_BUSY;
							end	//end I2C_SEND_START
							
							//Send restart bit
							PERIPH_I2C_SEND_RESTART: begin
								i2c_restart_en <= 1;
								state <= STATE_I2C_BUSY;
							end	//end I2C_SEND_RESTART
							
							//Send stop bit
							PERIPH_I2C_SEND_STOP: begin
								i2c_stop_en <= 1;
								state <= STATE_I2C_BUSY;
							end	//end I2C_SEND_STOP
							
							//Send a data byte
							PERIPH_I2C_SEND_BYTE: begin
								i2c_tx_en <= 1;
								i2c_tx_data <= rpc_fab_rx_d0[7:0];
								state <= STATE_I2C_BUSY;
							end	//end I2C_SEND_BYTE
							
							//Receive a data byte
							PERIPH_I2C_RECV_BYTE: begin
								i2c_rx_en <= 1;
								i2c_rx_ack <= rpc_fab_rx_d0[0];
								state <= STATE_I2C_RECV;
							end	//end I2C_RECV_BYTE
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// SPI
							
							//Set baud rate
							PERIPH_SPI_SET_CLKDIV: begin

								spi_clkdiv[spi_chnum] <= rpc_fab_rx_d0[15:0];

								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
								
							end	//end PERIPH_SPI_SET_CLKDIV
							
							PERIPH_SPI_ASSERT_CS: begin
							
								spi_cs_n[spi_chnum] <= 0;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
								
							end	//end PERIPH_SPI_ASSERT_CS
							
							PERIPH_SPI_DEASSERT_CS: begin
							
								spi_cs_n[spi_chnum] <= 1;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
								
							end	//end PERIPH_SPI_DEASSERT_CS
							
							PERIPH_SPI_SEND_BYTE: begin
								shift_en[spi_chnum] <= 1;
								tx_data[spi_chnum] <= rpc_fab_rx_d0[7:0];
								state <= STATE_SPI_WAIT;
							end	//end PERIPH_SPI_SEND_BYTE
							
							PERIPH_SPI_RECV_BYTE: begin
								shift_en[spi_chnum] <= 1;
								tx_data[spi_chnum] <= 0;
								state <= STATE_SPI_WAIT;
							end	//end PERIPH_SPI_RECV_BYTE
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// Board fault
							
							PERIPH_SET_BOARD_FAULT: begin
								fault_led <= rpc_fab_rx_d0[0];
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
								
							end	//end PERIPH_SET_BOARD_FAULT
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// GPIO
							
							PERIPH_GPIO_RDWR: begin
								
								gpio_oe <= rpc_fab_rx_d0[9:0];
								gpio_out <= rpc_fab_rx_d1[9:0];
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= gpio_in;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
							
							end	//end PERIPH_GPIO_RDWR
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// Timer
							
							PERIPH_TIMER_SET_COUNT: begin
								
								timer_max <= rpc_fab_rx_d1;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
							
							end	//end PERIPH_TIMER_SET_COUNT
							
							PERIPH_TIMER_START: begin
							
								timer_reset <= 1;
								timer_notify_host <= rpc_fab_rx_src_addr;
								
								timer_active <= 1;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
							
							end	//end PERIPH_TIMER_START
							
							PERIPH_TIMER_STOP: begin
							
								timer_reset <= 1;
								timer_active <= 0;
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
							
							end	//end PERIPH_TIMER_START
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// Query the voltage mode
							
							PERIPH_VOLTAGE_MODE: begin
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;	
								rpc_fab_tx_d0 <= 0;
								if(voltage_mode_5)
									rpc_fab_tx_d0 <= 5000;
								else if(voltage_mode_12)
									rpc_fab_tx_d0 <= 12000;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
								
							end
							
							////////////////////////////////////////////////////////////////////////////////////////////
							// Default
							
							//Unrecognized call, fail
							default: begin
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								rpc_fab_rx_done <= 1;
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
			//General RPC stuff
			
			//Wait for RPC transmits to finish
			STATE_RPC_TXHOLD: begin
				if(rpc_fab_tx_done)
					state <= STATE_IDLE;
			end	//end STATE_RPC_TXHOLD
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// I2C stuff
			
			//Wait for I2C transmits to finish, then send success
			STATE_I2C_BUSY: begin
				if(!i2c_busy) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
					rpc_fab_tx_d0 <= {20'h0, i2c_tx_ack};
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
					rpc_fab_rx_done <= 1;
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
					rpc_fab_rx_done <= 1;
				end
			end	//end STATE_I2C_RECV
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// SPI stuff
			
			//Wait for SPI transmission to finish
			STATE_SPI_WAIT: begin
			
				if(shift_done[spi_chnum]) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;						
					rpc_fab_tx_d0 <= {13'h0, rx_data[spi_chnum]};
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
					rpc_fab_rx_done <= 1;
				end
			
			end	//end STATE_SPI_WAIT
			
		endcase	
	end
	
endmodule
	
