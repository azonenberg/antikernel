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
	@brief Top-level module of the CPLD
 */
module TopLevel(
	clk_20mhz,
	reset_in_n, uart_reset_n, prog_b_n, ethclken,
	cpld_cs_n, cpld_miso, cpld_mosi,
	gpio,
	fault_led
    );
	 
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	input wire clk_20mhz;
	
	input wire reset_in_n;
	
	output wire uart_reset_n;
	output wire prog_b_n;
	output wire ethclken;
	
	input wire cpld_cs_n;
	output reg cpld_miso = 0;
	input wire cpld_mosi;
	
	inout wire[9:0] gpio;
	
	output reg fault_led = 0;
	
	//TODO: cs_n, temp alerts
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Fillers for not-yet-used pins
	assign uart_reset_n = 1'b1;
	assign ethclken = 1'b1;
	
	assign gpio[9:8] = 2'bzz;
	//assign gpio[7:0] = 8'h55;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock division
	// Turn 20 Mhz into 20 KHz
	
	reg[9:0] clkdiv = 0;
	reg clk_20khz_edge = 0;							//asserted for one clk_20mhz cycle every 1024 cycles
	always @(posedge clk_20mhz) begin
		clkdiv <= clkdiv + 1;
		clk_20khz_edge <= 0;
		if(clkdiv == 0)
			clk_20khz_edge <= 1;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Switch debouncing for global reset
	
	SwitchDebouncer #(.INIT_VAL(1)) reset_debouncer (
		.clk(clk_20mhz), 
		.clken(clk_20khz_edge), 
		.din(reset_in_n), 
		.dout(prog_b_n)
		);

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Fault LED
	/*
	reg[11:0] clkdiv2 = 0;
	always @(posedge clk_20mhz) begin
		if(clk_20khz_edge) begin
			clkdiv2 <= clkdiv2 + 10'h1;
			
			if(clkdiv2 == 0)
				fault_led <= !fault_led;
		end
			
	end
	*/
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// SPI interface logic and LED output
	
	reg[7:0] leds = 8'hF0;
	assign gpio[7:0]  = leds;
	
	reg[9:0] spi_data_buf = 0;
	
	always @(posedge clk_20mhz) begin
		spi_data_buf <= {spi_data_buf[8:0], cpld_mosi};
		cpld_miso <= spi_data_buf[9];
		
		if(!cpld_cs_n)
			leds <= spi_data_buf[7:0];
			
		//TODO: UART
	end
	
endmodule
