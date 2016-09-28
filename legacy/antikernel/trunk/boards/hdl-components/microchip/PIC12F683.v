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
	@brief Microchip PIC12F683 8-bit MCU
 */
module PIC12F683(vdd, gnd, gpio0_pgd, gpio1_pgc, gpio2, gpio3_mclr, gpio4, gpio5);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter PACKAGE	= "DIP";			//legal values are DIP only for now
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	(* MIN_POWER_VOLTAGE = 2000 *)
	(* MAX_POWER_VOLTAGE = 5500 *)
	input wire	vdd;
	
	(* MIN_POWER_VOLTAGE = 0 *)
	(* MAX_POWER_VOLTAGE = 0 *)
	input wire	gnd;
	
	//TODO: add thresholds etc?
	inout wire	gpio0_pgd;
	inout wire	gpio1_pgc;
	inout wire	gpio2;
	inout wire	gpio3_mclr;
	inout wire	gpio4;
	inout wire	gpio5;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Support components
	
	//Decoupling cap
	Cap_100nF_0402 dc(.p1(vdd), .p2(gnd));
	
	//Reset RC circuit including ICSP disconnect
	wire mclr_rc;
	Cap_100nF_0402 reset(.p1(mclr_rc), .p2(gnd));
	Resistor_10k_0402 pull(.p1(vdd), .p2(mclr_rc));
	Resistor_470_0402 iso(.p1(mclr_rc), .p2(gpio3_mclr));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DRC rules
	
	initial begin
		if(PACKAGE != "DIP") begin
			$display("ERROR: Only implemented package for PIC12F683 is DIP");
			$finish;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The MCU itself
	
	(* value = "PIC12F683-I/P" *)
	(* distributor = "digikey" *)
	(* distributor_part = "PIC12F683-I/P-ND" *)
	DIP_8 u (
		.p1(vdd),
		.p2(gpio5),
		.p3(gpio4),
		.p4(gpio3_mclr),
		.p5(gpio2),
		.p6(gpio1_pgc),
		.p7(gpio0_pgd),
		.p8(gnd)
	);
			
endmodule
