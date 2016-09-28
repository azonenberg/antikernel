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
	@brief More comprehensive UART loopback test, deserializes and reserializes to verify correct protocol
 */

module UARTSerdesLoopbackTestBitstream(clk_20mhz, uart_tx, uart_rx);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire clk_20mhz;
	
	output wire uart_tx;
	input wire uart_rx;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Global clock buffer (no PLL)
	
	wire clk;
	BUFG bufg_clk_20mhz(.I(clk_20mhz), .O(clk));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The UART
	
	reg[7:0] uart_txdata = 0;
	reg uart_txen = 0;
	wire uart_txactive;
	
	wire[7:0] uart_rxdata;
	wire uart_rxen;
	
	UART uart(
		.clk(clk),
		.clkdiv(16'd174),		//115200 @ 20 MHz
		.tx(uart_tx),
		.txin(uart_txdata),
		.txrdy(uart_txen),
		.txactive(uart_txactive),
		.rx(uart_rx),
		.rxout(uart_rxdata),
		.rxrdy(uart_rxen),
		.rxactive(),
		.overflow()
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Loopback logic
	
	reg tx_waiting = 0;
	always @(posedge clk) begin
		uart_txen <= 0;
		
		if(uart_rxen) begin
			tx_waiting <= 1;
			uart_txdata <= uart_rxdata;
		end
		
		if(tx_waiting && !uart_txen && !uart_txactive) begin
			uart_txen <= 1;
			tx_waiting <= 0;
		end
	end
	
endmodule
