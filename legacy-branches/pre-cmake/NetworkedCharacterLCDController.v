`timescale 1ns / 1ps
`default_nettype none
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
	@brief NoC-integrated character LCD controller (for dual Sitronix ST7066U)
	
	Never sends messages.
	
	Inbound message format:
		Word 1	padding[7:0], opcode[3:0], len[3:0], data[79:64]
		Word 2	data[63:32]
		Word 3	data[31:0]
					
	Since we have a total of 160 characters (4*40) and up to 10 chars per write,
	we need a total of 4 writes per line or 16 writes to update the entire display.
 */
module NetworkedCharacterLCDController(
	clk,
	noc_tx_en, noc_tx_data, noc_tx_ack, noc_rx_en, noc_rx_data, noc_rx_ack,
	cs, we_n, cmd_n, data, oe
    );
	 
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	//160 MHz NoC clock
	input wire clk;
	
	//NoC port
	output reg noc_tx_en = 0;
	output reg[31:0] noc_tx_data = 0;
	input wire noc_tx_ack;
	input wire noc_rx_en;
	input wire[31:0] noc_rx_data;
	output reg noc_rx_ack;
	
	output reg[1:0] cs = 0;
	output reg we_n = 0;
	output reg cmd_n = 0;
	inout wire[3:0] data;
	output reg oe = 0;

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO tristates
	
	reg[3:0] dout = 0;
	wire[3:0] din;
	
	IobufMacro #(.WIDTH(4)) iobuf_inst (
		.din(din), 
		.dout(dout), 
		.oe(oe), 
		.io(data)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Opcode definitions
	
	/*
	Opcodes
		0x00		Clear screen (data ignored)
		0x01		Write data at current cursor position. Max of 10 bytes per write.
					Data is left aligned (so writing one byte would be data[79:72]).
		0x02		Set current cursor position.
					data[79:72] = X coord, data[71:64] = Y coord. Rest ignored.
					*/
					
	localparam OP_CLEAR_SCREEN					= 4'h0;
	localparam OP_WRITE							= 4'h1;
	localparam OP_CURSOR_POS					= 4'h2;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock edge generation
	
	// 160 MHz / 1024 = 156.25 KHz (6.4us per clock)
	//reg[9:0] clk_count = 0;
	reg[7:0] clk_count = 0;
	reg clk_slow_edge = 0;
	always @(posedge clk) begin
		clk_count <= clk_count + 7'h1;
		
		clk_slow_edge <= 0;
		if(clk_count == 0)
			clk_slow_edge <= 1;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Transceiver
	
	localparam TX_STATE_IDLE	 		= 4'h0;
	localparam TX_STATE_INIT_1 		= 4'h1;
	localparam TX_STATE_INIT_2 		= 4'h2;
	localparam TX_STATE_INIT_3 		= 4'h3;
	localparam TX_STATE_INIT_4 		= 4'h4;
	localparam TX_STATE_INIT_5 		= 4'h5;
	localparam TX_STATE_TX_1			= 4'h6;
	localparam TX_STATE_TX_2			= 4'h7;
	localparam TX_STATE_TX_3			= 4'h8;
	localparam TX_STATE_TX_4			= 4'h9;
	localparam TX_STATE_TX_5			= 4'ha;
	localparam TX_STATE_TX_6			= 4'hb;
	
	reg[3:0] tx_state = TX_STATE_INIT_1;
	
	reg[13:0] tx_postcount = 1;
	reg[3:0] tx_waitcount = 1;
	
	//Transmit mode
	reg tx_en = 0;
	reg[7:0] tx_data = 0;
	reg tx_cmd_n = 0;
	reg[7:0] tx_data_buf = 0;
	
	//Receive mode
	reg rx_en = 0;
	
	//Busy flag
	wire tx_busy_fwd;
	reg tx_busy = 1;
	assign tx_busy_fwd = tx_busy | tx_en | rx_en;
	
	reg[1:0] channel_selector = 2'b11;
	
	//Wait 16 clocks between operations	
	always @(posedge clk) begin
		if(clk_slow_edge) begin
			case(tx_state)
				
				///////////////////////////////////////////////////////////////////////////////////////
				// Initialization code (datasheet page 25)
				
				//Wait >40ms 
				TX_STATE_INIT_1: begin
					tx_postcount <= tx_postcount + 14'h1;
					if(tx_postcount == 0)
						tx_state <= TX_STATE_INIT_2;
				end
				
				//Function set
				TX_STATE_INIT_2: begin
					oe <= 1;
					dout <= 4'b0011;	//datasheet says 0011 but this doesnt make sense?
					we_n <= 0;
					cmd_n <= 0;
					tx_state <= TX_STATE_INIT_3;
				end
				TX_STATE_INIT_3: begin
					cs[0] <= 1;
					cs[1] <= 1;
					tx_state <= TX_STATE_INIT_4;
				end
				TX_STATE_INIT_4: begin
					cs[0] <= 0;
					cs[1] <= 0;
					tx_waitcount <= 1;
					tx_state <= TX_STATE_INIT_5;
				end
				
				//Wait >37us
				TX_STATE_INIT_5: begin
					oe <= 0;
					tx_waitcount <= tx_waitcount + 4'd1;
					if(tx_waitcount == 0)
						tx_state <= TX_STATE_IDLE;
				end
				
				///////////////////////////////////////////////////////////////////////////////////////
				// Transmit mode
				TX_STATE_TX_1: begin
					cs[0] <= channel_selector[0];
					cs[1] <= channel_selector[1];
					tx_state <= TX_STATE_TX_2;
				end
				TX_STATE_TX_2: begin
					cs[0] <= 0;
					cs[1] <= 0;
					tx_state <= TX_STATE_TX_3;
				end
				TX_STATE_TX_3: begin
					dout <= tx_data_buf[3:0];
					tx_state <= TX_STATE_TX_4;
				end
				TX_STATE_TX_4: begin
					cs[0] <= channel_selector[0];
					cs[1] <= channel_selector[1];
					tx_state <= TX_STATE_TX_5;
				end
				TX_STATE_TX_5: begin
					cs[0] <= 0;
					cs[1] <= 0;
					tx_state <= TX_STATE_TX_6;
					tx_waitcount <= 1;
				end
				
				//Wait >37us
				TX_STATE_TX_6: begin
					oe <= 0;
					tx_waitcount <= tx_waitcount + 4'd1;
					if(tx_waitcount == 0)
						tx_state <= TX_STATE_IDLE;
				end				
				
				///////////////////////////////////////////////////////////////////////////////////////
				// Idle - wait for commands
				TX_STATE_IDLE: begin
					tx_busy <= 0;
					
					if(tx_en) begin
						oe <= 1;
						cmd_n <= tx_cmd_n;
						tx_data_buf <= tx_data;
						dout <= tx_data[7:4];
						tx_state <= TX_STATE_TX_1;
						
						tx_busy <= 1;
					end
				end
				
			endcase
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Acknowledgement generation
	
	reg lcd_done = 0;
	reg[3:0] lcd_done_count = 0;					//Number of ACKs we need to send
	
	reg[15:0] source_address = 0;					//Source address of the last packet sent to us.
															//This is the address we send to when
															//acknowledging a message.
	reg[1:0] ack_state = 0;											
	always @(posedge clk) begin
	
		noc_tx_en <= 0;
		noc_tx_data <= 0;
	
		if(lcd_done && ack_state != 3)
			lcd_done_count <= lcd_done_count + 4'd1;
		else if(lcd_done && ack_state == 3) begin
			//no change
		end
		else if(!lcd_done && ack_state == 3)
			lcd_done_count <= lcd_done_count - 4'd1;
	
		case(ack_state)
			0: begin
				if(lcd_done_count != 0) begin
					noc_tx_en <= 1;
					noc_tx_data <= {16'h0, source_address};
					ack_state <= 1;
				end
			end
			
			1: begin
				if(noc_tx_ack) begin
					noc_tx_data <= 1;
					ack_state <= 2;
				end
				else begin
					noc_tx_data <= {16'h0, source_address};
					noc_tx_en <= 1;
				end
			end
			
			//No payload data in the rest of the ack
			2: begin
				ack_state <= 3;
			end
			3: begin
				ack_state <= 0;
			end
			
		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
		
	reg[8:0] op_delay = 0;
		
	localparam STATE_INIT_1				= 4'h0;
	localparam STATE_INIT_2				= 4'h1;
	localparam STATE_INIT_3				= 4'h2;
	localparam STATE_INIT_4				= 4'h3;
	localparam STATE_INIT_5				= 4'h4;
	localparam STATE_INIT_6				= 4'h5;
	localparam STATE_IDLE				= 4'h6;
	localparam STATE_RX_1				= 4'h7;
	localparam STATE_RX_2				= 4'h8;
	localparam STATE_RX_3				= 4'h9;
	localparam STATE_RX_4				= 4'ha;
	localparam STATE_CLEAR_SCREEN		= 4'hb;
	localparam STATE_WRITE				= 4'hc;
		
	reg[4:0] state = STATE_INIT_1;
	
	reg[3:0] opcode = 0;
	reg[3:0] len = 0;
	reg[79:0] packet_data = 0;
	
	//hex-to-ascii table
	reg[7:0] hex_rom[15:0];
	initial begin
		hex_rom['h0] = "0";
		hex_rom['h1] = "1";
		hex_rom['h2] = "2";
		hex_rom['h3] = "3";
		hex_rom['h4] = "4";
		hex_rom['h5] = "5";
		hex_rom['h6] = "6";
		hex_rom['h7] = "7";
		hex_rom['h8] = "8";
		hex_rom['h9] = "9";
		hex_rom['ha] = "a";
		hex_rom['hb] = "b";
		hex_rom['hc] = "c";
		hex_rom['hd] = "d";
		hex_rom['he] = "e";
		hex_rom['hf] = "f";
	end
	
	//0...159
	reg[7:0] cursorpos = 0;
	
	always @(posedge clk) begin
	
		noc_rx_ack <= 0;
		
		lcd_done <= 0;
	
		if(clk_slow_edge) begin
			tx_en <= 0;
			tx_cmd_n <= 0;
			tx_data <= 0;
		end

		case(state)
			///////////////////////////////////////////////////////////////////////////////////////
			// Initialization
	
			//Mode set
			STATE_INIT_1: begin
				if(clk_slow_edge && !tx_busy_fwd) begin
					
					//Broadcast to both controllers
					channel_selector <= 2'b11;
					
					//Function set - 4 bit mode, 5x8, 2 lines
					tx_en <= 1;
					tx_cmd_n <= 0;
					tx_data <= 8'b00101000;
					state <= STATE_INIT_2;
				end
			end
			
			//Datasheets says we should repeat mode set for some reason/
			//It's not stated, but it's most likely that this is to handle the case
			//where the LCD is already powered up and in 4-bit mode
			STATE_INIT_2: begin
				if(clk_slow_edge && !tx_busy_fwd) begin
					
					//Function set - 4 bit mode, 5x8, 2 lines
					tx_en <= 1;
					tx_cmd_n <= 0;
					tx_data <= 8'b00101000;
					state <= STATE_INIT_3;
				end
			end
			
			//Turn display on
			STATE_INIT_3: begin
				if(clk_slow_edge && !tx_busy_fwd) begin
					
					//Display on, cursor off, cursor blink off
					tx_en <= 1;
					tx_cmd_n <= 0;
					tx_data <= 8'b00001100;	//change 00 to 11 for cursor on
					state <= STATE_INIT_4;
				end
			end
			
			//Clear display
			STATE_INIT_4: begin
				if(clk_slow_edge && !tx_busy_fwd) begin
					tx_en <= 1;
					tx_cmd_n <= 0;
					tx_data <= 8'b00000001;
					op_delay <= 1;
					state <= STATE_INIT_5;
				end
			end
			
			//Wait 1.52ms
			//6.4us per clock so 255 clocks works out nicely
			STATE_INIT_5: begin
				if(clk_slow_edge) begin
					op_delay <= op_delay + 8'd1;
					if(op_delay == 0)
						state <= STATE_INIT_6;
				end
			end
			
			//Entry mode set
			STATE_INIT_6: begin
				if(clk_slow_edge && !tx_busy_fwd) begin
					
					//Left to right reading, no shift
					tx_en <= 1;
					tx_cmd_n <= 0;
					tx_data <= 8'b00000110;
					state <= STATE_IDLE;
					op_delay <= 1;
					lcd_done <= 1;
				end
			end
			
			///////////////////////////////////////////////////////////////////////////////////////
			// Receive commands
			STATE_IDLE: begin
				if(noc_rx_en && !tx_busy_fwd) begin
					noc_rx_ack <= 1;
					state <= STATE_RX_1;
				end
			end
			
			STATE_RX_1: begin
				//Save source address in header
				source_address <= noc_rx_data[31:16];
				state <= STATE_RX_2;
			end
			
			STATE_RX_2: begin
				opcode <= noc_rx_data[23:20];
				len <= noc_rx_data[19:16];
				packet_data[79:64] <= noc_rx_data[15:0];
				state <= STATE_RX_3;
			end
			
			STATE_RX_3: begin
				packet_data[63:32] <= noc_rx_data;
				state <= STATE_RX_4;
			end

			STATE_RX_4: begin
				packet_data[31:0] <= noc_rx_data;
				
				//Broadcast to both controllers
				channel_selector <= 2'b11;
				
				//See what the opcode is
				case(opcode)
					OP_CLEAR_SCREEN: begin
						op_delay <= 1;
						cursorpos <= 0;
						state <= STATE_CLEAR_SCREEN;
					end
					
					OP_WRITE: begin
						state <= STATE_WRITE;
					end
				endcase					

			end
	
			///////////////////////////////////////////////////////////////////////////////////////
			// Clear screen
			
			//Wait 1.52ms
			//6.4us per clock so 255 clocks works out nicely
			STATE_CLEAR_SCREEN: begin
				if(clk_slow_edge) begin
					if(op_delay == 1) begin
						tx_en <= 1;
						tx_cmd_n <= 0;
						tx_data <= 8'b00000001;
					end
				
					op_delay <= op_delay + 9'h1;
					if(op_delay == 0) begin
						lcd_done <= 1;
						state <= STATE_IDLE;
					end
				end
			end
			
			///////////////////////////////////////////////////////////////////////////////////////
			// Write stuff
			STATE_WRITE: begin
				if(clk_slow_edge) begin
					
					if(!tx_busy_fwd) begin
						
						//Bump cursor position
						cursorpos <= cursorpos + 8'd1;
						if(cursorpos == 8'd159)
							cursorpos <= 0;
					
						//Write to the appropriate controller
						if(cursorpos < 8'd80)
							channel_selector <= 2'b01;
						else
							channel_selector <= 2'b10;
						
						//Send the character
						tx_en <= 1;
						tx_cmd_n <= 1;
						tx_data <= packet_data[79:72];
						
						//Shift buffer left
						packet_data <= {packet_data[71:0], 8'h00};
						
						//Keep track of how many characters are left
						len <= len - 4'd1;
						if(len == 1) begin
							lcd_done <= 1;
							state <= STATE_IDLE;
						end
					end
				end
			end
			
		endcase
	end
	
endmodule
