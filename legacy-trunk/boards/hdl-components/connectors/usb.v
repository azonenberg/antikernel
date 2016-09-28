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
	@brief USB connectors
 */

module USB_Device_Connector(vbus, gnd, otg, data_p, data_n);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter CONNECTOR_STYLE = "MINI_B";
	
	//TODO: parameter to enable/skip ferrite
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	(* POWER_VOLTAGE = 5000 *) 
	output wire		vbus;
	
	(* POWER_VOLTAGE = 0 *) 
	output wire		gnd;
	
	output wire		otg;
	
	inout wire		data_p;
	inout wire		data_n;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DRC logic
	
	initial begin
		if(CONNECTOR_STYLE != "MINI_B") begin
			$display("Only implemented style for USB_Device_Connector is MINI_B");
			$finish();
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual connector
	
	(* POWER_VOLTAGE = 5000 *) 
	wire	vbus_internal;
	
	generate
		
		if(CONNECTOR_STYLE == "MINI_B") begin
		
			(* value = "UX60SC-MB-5ST(80)" *)
			(* distributor = "digikey" *)
			(* distributor_part = "H11671CT-ND" *)
			HIROSE_UX60S_MB_5ST c(
				.p1(vbus_internal),
				.p2(data_n),
				.p3(data_p),
				.p4(otg),
				.p5(gnd),
				
				//shielding, tie to ground for now (TODO make separate chassis ground connection?)
				.p6(gnd),
				.p7(gnd)
			);
			
		end
		
	endgenerate

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Series ferrite for power noise isolation
	
	(* value = "MPZ1608S601ATA00" *)
	(* distributor = "digikey" *)
	(* distributor_part = "445-2205-1-ND" *)
	EIA_0603_INDUCTOR_NOSILK l(
		.p1(vbus_internal),
		.p2(vbus)
		);

endmodule
