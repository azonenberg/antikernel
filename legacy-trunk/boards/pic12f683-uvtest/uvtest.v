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
	@brief PIC12F683 UV test board
 */
module uvtest();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Power supply
	
	//USB connector for power
	//(other signals not used)
	wire	v5p0;
	wire	gnd;
	wire	usb_otg;
	wire	usb_data_p;
	wire	usb_data_n;
	USB_Device_Connector #(
		.CONNECTOR_STYLE("MINI_B")
	) usb (
		.vbus(v5p0),
		.gnd(gnd),
		.otg(usb_otg),
		.data_p(usb_data_p),
		.data_n(usb_data_n)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Programming header
	
	//ICSP signals
	wire	icsp_pgd;
	wire	icsp_pgc;
	wire	icsp_mclr;
	
	ICSP_Header icsp(
		.vdd(v5p0),
		.vss(gnd),
		.mclr(icsp_mclr),
		.pgd(icsp_pgd),
		.pgc(icsp_pgc)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The MCU

	//GPIOs
	wire	gpio2;
	wire	gpio4;
	wire	gpio5;

	//The (socketed) MCU and support component
	PIC12F683 #(
		.PACKAGE("DIP")
	) mcu (
		.vdd(v5p0),
		.gnd(gnd),
		.gpio0_pgd(icsp_pgd),
		.gpio1_pgc(icsp_pgc),
		.gpio2(gpio2),
		.gpio3_mclr(icsp_mclr),
		.gpio4(gpio4),
		.gpio5(gpio5)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Peripherals
	
	LED_Green_5V led_a(.vdd(gpio2), .gnd(gnd));
	LED_Green_5V led_b(.vdd(gpio4), .gnd(gnd));

endmodule
