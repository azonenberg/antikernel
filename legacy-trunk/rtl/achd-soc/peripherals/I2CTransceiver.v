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
	@brief I2C transceiver
	
	Note that this core uses active-high ACKs, not active-low as seen on the wire!
 */
module I2CTransceiver(
	clk,
	clkdiv,
	i2c_scl, i2c_sda,
	tx_en, tx_ack, tx_data,
	rx_en, rx_rdy, rx_out, rx_ack,
	start_en, restart_en, stop_en, busy
    );
	 
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	input wire clk;
	input wire[15:0] clkdiv;
	
	//I2C bus
	output reg i2c_scl = 1;
	inout wire i2c_sda;
	
	//Control bus
	input wire tx_en;
	output reg tx_ack = 0;
	input wire[7:0] tx_data;
	input wire rx_en;
	output reg rx_rdy = 0;
	output reg[7:0] rx_out = 0;
	input wire rx_ack;
	
	input wire start_en;
	input wire restart_en;
	input wire stop_en;
	output wire busy;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// I2C tristate processing
	
	reg sda_out = 0;
	reg sda_tx = 0;
	
	assign i2c_sda = sda_tx ? sda_out : 1'bz;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Transceiver logic
	
	reg[14:0] clk_count = 0;
	
	localparam STATE_IDLE =			4'b0000;
	localparam STATE_START =		4'b0001;
	localparam STATE_TX =			4'b0010;
	localparam STATE_TX_2 =			4'b0011;
	localparam STATE_READ_ACK =		4'b0100;
	localparam STATE_RX =			4'b0101;
	localparam STATE_SEND_ACK =		4'b0110;
	localparam STATE_STOP = 		4'b0111;
	localparam STATE_STOP_2 =		4'b1000;
	localparam STATE_RESTART =		4'b1001;
	localparam STATE_RESTART_2 =	4'b1010;
	
	reg[3:0] state = STATE_IDLE;
	assign busy = (state != STATE_IDLE) | start_en | restart_en | stop_en | tx_en | rx_en ;
	
	reg[7:0] tx_buf = 0;
	reg rx_ackbuf = 0;
	reg[3:0] bitcount = 0;
	
	always @(posedge clk) begin

		rx_rdy <= 0;
		
		case(state)
		
			//Ready to do stuff
			STATE_IDLE: begin
				
				//Send start bit
				//Data and clock should be high
				if(start_en) begin
					sda_tx <= 1;
					sda_out <= 0;
					clk_count <= 0;
					state <= STATE_START;
				end
				
				//Send a byte of data
				//Clock should be low at this point.
				else if(tx_en) begin
					tx_buf <= tx_data;
					clk_count <= 0;
					bitcount <= 0;
					state <= STATE_TX;
					i2c_scl <= 0;
				end
				
				//Read a byte of data
				//Clock should be low at this point.
				else if(rx_en) begin
					clk_count <= 0;
					bitcount <= 0;
					state <= STATE_RX;
					i2c_scl <= 0;
					rx_ackbuf <= rx_ack;
					
					rx_out <= 8'h00;
				end
				
				//Send stop bit
				//Clock should be low at this point
				else if(stop_en) begin
					
					//Make data low
					sda_tx <= 1;
					sda_out <= 0;
					i2c_scl <= 0;
					
					clk_count <= 0;
					state <= STATE_STOP;
				end
				
				//Send restart bit
				//Clock should be low at this point
				else if(restart_en) begin
					
					//Make data high
					sda_tx <= 1;
					sda_out <= 1;
					i2c_scl <= 0;
					clk_count <= 0;
					state <= STATE_RESTART;
					
				end
				
			end
			
			//Sending start bit
			STATE_START: begin
				//Keep track of time, clock goes low at clkdiv/2
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count)
					i2c_scl <= 0;
				
				if(clk_count == clkdiv)
					state <= STATE_IDLE;
			end
			
			//Sending data
			STATE_TX: begin
			
				sda_tx <= 1;
				
				//Send the next data bit
				if(clk_count == 0) begin
					sda_out <= tx_buf[7];
					tx_buf <= {tx_buf[6:0], 1'b0};
				end
				
				//Keep track of time, clock goes high at clkdiv/2
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count)
					i2c_scl <= 1;
					
				//End of this bit? Go on to the next
				if(clkdiv[14:0] == clk_count) begin
					i2c_scl <= 0;
					clk_count <= 0;
					bitcount <= bitcount + 4'd1;
					
					//stop at end of byte
					if(bitcount == 7)
						state <= STATE_READ_ACK;
				end
				
			end
			
			//Read the acknowledgement bit
			STATE_READ_ACK: begin
				
				//set SDA to read mode
				sda_tx <= 0;
				
				//Keep track of time, clock goes high at clkdiv/2
				//Read ACK on rising edge
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count) begin
					i2c_scl <= 1;
					tx_ack <= !i2c_sda;
				end

				//End of this bit? Go on to the next
				if(clkdiv[14:0] == clk_count) begin
					i2c_scl <= 0;
					clk_count <= 0;
					
					state <= STATE_IDLE;
				end
				
			end
			
			//Read a byte of data
			STATE_RX: begin
			
				//read mode
				sda_tx <= 0;
								
				//Keep track of time, clock goes high at clkdiv/2
				//Read data on rising edge (high order bit is sent first)
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count) begin
					i2c_scl <= 1;
					
					rx_out <= {rx_out[6:0], i2c_sda};
				end
					
				//End of this bit? Go on to the next
				if(clkdiv[14:0] == clk_count) begin
				
					i2c_scl <= 0;
					clk_count <= 0;
					bitcount <= bitcount + 4'd1;
					
					//stop at end of byte
					if(bitcount == 7)
						state <= STATE_SEND_ACK;
				end
			
			end
			
			//Send the ACK
			STATE_SEND_ACK: begin
				
				//set SDA to write mode and send the ack (invert ack to nack)
				sda_tx <= 1;
				sda_out <= !rx_ackbuf;
				
				//Keep track of time, clock goes high at clkdiv/2
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count)
					i2c_scl <= 1;
				
				//End of this bit? Finished
				if(clkdiv[14:0] == clk_count) begin
					i2c_scl <= 0;
					clk_count <= 0;
					
					rx_rdy <= 1;
					
					state <= STATE_IDLE;
				end
				
			end
			
			//Sending stop bit
			STATE_STOP: begin
				
				//Keep track of time, clock goes high at clkdiv/2
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count)
					i2c_scl <= 1;
				
				//End of the stop bit? Let SDA float high
				if(clkdiv[14:0] == clk_count) begin
					sda_tx <= 0;
					clk_count <= 0;
					
					state <= STATE_STOP_2;
				end
				
			end
			
			//Wait one additional bit period after the stop bit
			STATE_STOP_2: begin
				clk_count <= clk_count + 15'd1;
				if(clk_count == clkdiv)
					state <= STATE_IDLE;
			end
			
			//Sending repeated start bit
			STATE_RESTART: begin
				
				//Keep track of time, clock goes high at clkdiv/2
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count)
					i2c_scl <= 1;
				
				//End of the start bit? SDA goes low
				if(clkdiv[14:0] == clk_count) begin
					sda_out <= 0;
					clk_count <= 0;
					state <= STATE_RESTART_2;
				end
				
			end
			
			STATE_RESTART_2: begin
			
				//Keep track of time, clock goes low at clkdiv/2
				clk_count <= clk_count + 15'd1;
				if(clkdiv[15:1] == clk_count)
					i2c_scl <= 0;
					
				//End of restart bit? Go idle
				if(clkdiv[14:0] == clk_count) begin
					state <= STATE_IDLE;
				end
				
			end
			
		endcase
		
	end


endmodule
