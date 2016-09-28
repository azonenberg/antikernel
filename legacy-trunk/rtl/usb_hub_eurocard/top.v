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
	@brief Firmware for usb-hub-eurocard CPLD
 */

module top(
	clk_24mhz,
	status_led_p, status_led_n, port_led_p, port_led_n,
	hub_status, hub_fault,
	port_status, port_fault,
	port_pwr_n, vbus_en_n,
	expansion_spi_miso, expansion_spi_mosi, expansion_spi_sck, expansion_spi_cs_n
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Global clock
	input wire		clk_24mhz;
	
	//General status LED
	output reg		status_led_p	= 0;		//High side
	output reg		status_led_n	= 0;		//Low side
	
	//Port indicator LEDs
	output reg[9:0]	port_led_p		= 0;		//High side
	output reg[9:0]	port_led_n		= 0;		//Low side
	
	//Port status flags from hub controller
	input wire[9:0] port_status;				//Port status LED
	input wire[9:0] port_fault;					//Port fault LED
	
	//Port power control (active low)
	input wire[9:0] port_pwr_n;					//Enable from hub controller
	output reg[9:0] vbus_en_n		= 10'h3F;	//Enable to PMIC
	
	//Internal hub signals
	input wire[1:0]	hub_status;					//Device-present indicator (should always be set)
	input wire[1:0]	hub_fault;					//Overcurrent indicator(should never be set)
	
	//Expansion header SPI bus
	output reg		expansion_spi_miso	= 0;
	input wire		expansion_spi_mosi;
	input wire		expansion_spi_sck;
	input wire		expansion_spi_cs_n;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Status LED and hub port control
	
	always @(posedge clk_24mhz) begin
	
		//Default to green
		status_led_p	<= 0;
		status_led_n	<= 1;
		
		//If either hub has a fault, turn red
		if(hub_fault != 0) begin
			status_led_p	<= 0;
			status_led_n	<= 0;
		end
		
		//If either hub has a fault, turn red
		if(hub_status != 3) begin
			status_led_p	<= 0;
			status_led_n	<= 0;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Expansion port control
	
	//Passthrough for now
	always @(posedge expansion_spi_sck) begin
		if(!expansion_spi_cs_n)
			expansion_spi_miso <= expansion_spi_mosi;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Port control logic
	
	integer i;
	
	always @(posedge clk_24mhz) begin
		
		//Forward port power enables from hub controller
		vbus_en_n	<= port_pwr_n;
		
		//Show port status
		for(i=0; i<10; i=i+1) begin
		
			//Default to off
			port_led_n[i] <= 0;
			port_led_p[i] <= 0;
			
			//If fault flag is set, turn on the red
			if(~port_fault[i])
				port_led_p[i] <= 1;
			
			//If status flag is set, turn on the green
			else if(~port_status[i])
				port_led_n[i] <= 1;
			
		end
		
	end
	
endmodule
