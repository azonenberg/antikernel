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
	@brief Test PCB top-level file
 */
module test();

	(* POWER_VOLTAGE = 5000 *) wire pwr_5v0;
	(* POWER_VOLTAGE = 0    *) wire gnd;

	wire pwr_3v3;
	wire pwr_2v5;
	wire pwr_1v8;
	wire pwr_1v0;

	wire en_3v3;
	wire en_2v5;
	wire en_1v8;
	wire en_1v0;
	
	//Open-drain power-good output (TODO: Bring up to the top level)
	wire pgood;
	
	//The main buck converter
	LTC3374 #(
		
		.NUM_OUTPUTS(4),
		
		.PWM_MODE("CONTINUOUS"),
		
		.CURRENT_3(1),
		.VOLTAGE_3(3300),
		
		.CURRENT_2(1),
		.VOLTAGE_2(2500),
		
		.CURRENT_1(2),
		.VOLTAGE_1(1800),
		
		.CURRENT_0(4),
		.VOLTAGE_0(1000)
		
	) buck (
		.vin(pwr_5v0),
		.gnd(gnd),
		.en({en_3v3, en_2v5, en_1v8, en_1v0}),
		.vout({pwr_3v3, pwr_2v5, pwr_1v8, pwr_1v0}),
		.tempraw(),
		.pgood(pgood)
	);

endmodule
