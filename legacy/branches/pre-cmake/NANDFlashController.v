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
	@brief Controller for ONFI NAND flash.
 */
module NANDFlashController(
	clk,
	onfi_ale, onfi_ce_n, onfi_cle, onfi_re_n, onfi_we_n, onfi_wp_n, onfi_io, onfi_busy_n,
	start, leds,
	uart_tx, uart_rx
    );
	 
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	input wire clk;
	
	//ONFI interface
	output reg onfi_ale = 0;
	output reg onfi_ce_n = 1;
	output reg onfi_cle = 0;
	output reg onfi_re_n = 1;
	output reg onfi_we_n = 1;
	output reg onfi_wp_n = 1;		//don't use write protect
	inout wire[7:0] onfi_io;
	input wire onfi_busy_n;
	
	//Interface to host
	input wire start;
	output reg[7:0] leds = 0;
	
	output wire uart_tx;
	input wire uart_rx;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Tri-state transceiver logic
	
	reg onfi_tx_active = 0;
	reg[7:0] onfi_dout = 0;
	wire[7:0] onfi_din;
	
	IobufMacro #(.WIDTH(8)) onfi_iobus(
		.din(onfi_din), .dout(onfi_dout), .oe(onfi_tx_active), .io(onfi_io));
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Control logic
	
	localparam COMMAND_READ_ID	= 8'h90;
	localparam COMMAND_RESET 	= 8'hFF;
	
	localparam STATE_INIT = 4'h0;
	localparam STATE_IDLE = 4'h1;
	
	reg[3:0] state = STATE_INIT;
	reg[4:0] substate = 0;
	
	reg[15:0] count = 1;
	
	always @(posedge clk) begin
	
		case(state)
		
			//Reset the flash device
			STATE_INIT: begin
				
				case(substate)
					
					//Hold in default state for a while
					0: begin
						count <= count + 1;
						if(count == 0)
							substate <= 1;
					end
					
					//Select the chip (needs 1.5 clocks setup time)
					1: begin
						if(onfi_busy_n && start) begin
							onfi_ce_n <= 0;
							substate <= 2;
						end
					end
					
					//Put reset command on the bus
					2: begin
						onfi_cle <= 1;
							
						//Send the reset command
						onfi_tx_active <= 1;
						onfi_dout <= COMMAND_RESET;
							
						//Write enable goes low immediately, command is latched in on rising edge
						onfi_we_n <= 0;
						
						substate <= 3;
					end
					
					//Dispatch the command
					3: begin
						onfi_we_n <= 1;
						substate <= 4;
					end
					
					//Hold time is past, release the bus
					4: begin
						onfi_ce_n <= 1;
						onfi_tx_active <= 0;
						onfi_dout <= 0;
						onfi_cle <= 0;
						substate <= 5;
					end
					
					//Wait for chip to become busy, then return
					5: begin
						if(!onfi_busy_n) begin
							substate <= 6;
						end
					end
					6: begin
						if(onfi_busy_n) begin
							substate <= 7;
						end
					end
					
					//Request device ID code
					7: begin
						if(onfi_busy_n) begin
							onfi_ce_n <= 0;
							substate <= 8;
						end
					end
					8: begin							//read-ID command
						onfi_cle <= 1;
						onfi_tx_active <= 1;
						onfi_dout <= COMMAND_READ_ID;
						onfi_we_n <= 0;				
						substate <= 9;
					end
					9: begin
						onfi_we_n <= 1;
						substate <= 10;
					end
					10: begin						//send address 00 (ID code)
						onfi_cle <= 0;
						onfi_ale <= 1;
						onfi_tx_active <= 1;
						onfi_dout <= 8'h00;
						onfi_we_n <= 0;
						substate <= 11;
					end
					11: begin						//strobe in address
						onfi_we_n <= 1;
						substate <= 12;
						count <= 0;
					end
					
					//Read it
					12: begin						//wait 60ns (5 clocks) of read latency
						onfi_ale <= 0;					
						onfi_tx_active <= 0;		//release bus and get ready to read
										
						count <= count + 1;
						if(count == 4)
							substate <= 13;
					end
					13: begin
						onfi_re_n <= 0;
						substate <= 14;
					end
					14: begin						//wait for data to become valid
						substate <= 15;
					end
					
					//output to LEDs
					15: begin
						leds <= onfi_din;
						onfi_re_n <= 1;
						substate <= 16;
					end
					16: begin
						//TODO
					end
					
					//TODO: turn on internal ECC
					
				endcase
			end	//end STATE_RESET
		
		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	//Logic analyzer
	
	RedTinUARTWrapper la(
		.clk(clk), 
		.din({
				state,				//4		124
				substate,			//5		119
				start,				//1		118
				onfi_ale,			//1		117
				onfi_cle,			//1		116
				onfi_ce_n,			//1		115
				onfi_tx_active,	//1		114
				onfi_dout,			//8		106
				onfi_din,			//8		98
				onfi_busy_n,		//1		97
				onfi_re_n,			//1		96
				onfi_we_n,			//1		95
				onfi_wp_n,			//1		94		
				94'b0
				}), 
				
		.uart_tx(uart_tx), 
		.uart_rx(uart_rx)
		);

endmodule
