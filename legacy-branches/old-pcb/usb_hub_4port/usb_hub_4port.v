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
	@brief 4-port USB hub
 */
(* top *)
module usb_hub_4port();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// USB device port
	
	//USB input
	wire vbus_unfiltered;
	(* impedance_diff = 90 *) (* length_match = "150 mil" *) (* clearance = "20 mil" *) wire[1:0] usb_dev;
	wire usb_shield;
	USBDeviceConnector #(
		.conntype("MINI_B_JACK")
	) usb_device_jack (
		.vbus(vbus_unfiltered),
		.usb_p(usb_dev[0]),
		.usb_n(usb_dev[1]),
		.gnd(gnd),
		.otg(),
		.shield(usb_shield)
	);

	//EMI filtering for USB power input
	wire vbus_filtered;
	PowerFilterFerrite #(
		.package("SM0805"),
		.distributor_part("587-1902-1-ND"),
		.impedance("600"),
		.frequency("100M")
	) usb_rail_ferrite (
		.vin(vbus_unfiltered),
		.vout(vbus_filtered)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Power stuff
	
	//Top-level power nets
	wire vdd_5v0;
	wire vdd_3v3;
	wire gnd;
	
	//TODO: Barrel jack to operate hub in self-powered mode
	
	//TODO: Jumper or circuitry for power-ORing
	//For the initial feasibility study, just be bus-powered
	assign vdd_5v0 = vbus_filtered;
	
	//3.3V LDO
	LDO1117_fixed #(
		.package("SOT223"),
		.output_mv(3300)
	) ldo_3v3 (
		.vin(vdd_5v0),
		.vout(vdd_3v3),
		.gnd(gnd)
	);
	
	//TODO: Input/output caps on LDO

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Indicator LEDs

	//Power indicator
	wire pwr_3v3_led_hi;
	Resistor #( .package("SM0603"), .resistance(470), .distributor_part("RMCF0603JT470RCT-ND") )
		pwr_3v3_led_rs( .a(vdd_3v3), .b(pwr_3v3_led_hi) );
	LED #(.package("SM0603"), .color("green"), .distributor_part("160-1183-1-ND") )
		pwr_3v3_led( .p(pwr_3v3_led_hi), .n(gnd) );
	
	//Indicators for downstream ports
	wire[3:0] port_error_n;
	wire[3:0] port_ok_n;
	wire[3:0] port_error_led_n;
	wire[3:0] port_ok_led_n;
	genvar i;
	generate
		for(i=0; i<4; i=i+1) begin
			
			//Green LEDs
			Resistor #(.package("SM0603"), .resistance(470), .distributor_part("RMCF0603JT470RCT-ND") )
				port_ok_led_rs( .a(port_ok_n[i]), .b(port_ok_led_n[i]) );
			LED #(.package("SM0603"), .color("green"), .distributor_part("160-1183-1-ND") )
				port_ok_led( .p(vdd_3v3), .n(port_ok_led_n[i]) );
			
			//Red LEDs
			Resistor #(.package("SM0603"), .resistance(470), .distributor_part("RMCF0603JT470RCT-ND") )
				port_error_led_rs( .a(port_error_n[i]), .b(port_error_led_n[i]) );
			LED #(.package("SM0603"), .color("red"), .distributor_part("160-1436-1-ND") )
				port_error_led( .p(vdd_3v3), .n(port_error_led_n[i]) );
			
		end
	endgenerate

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Hub controller
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Power logic for host ports
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Host ports

endmodule
