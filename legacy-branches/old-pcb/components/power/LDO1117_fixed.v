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
	@brief 1117-series low-dropout linear regulator with fixed output voltage
 */
module LDO1117_fixed(vin, vout, gnd);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	(* drc_type = "power_in" *)  input wire vin;
	(* drc_type = "power_out" *) output wire vout;
	(* drc_type = "power_in" *)  input wire gnd;
	
	parameter package		= "SOT223";
	parameter output_mv		= 3300;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DRC logic
	
	parameter dropout_mv = 1200;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Create the black-box cell
	
	generate
	
		case(output_mv)
			
			5000: begin
				SOT223 #(
					.distributor("digikey"),
					.distributor_part("ZLDO1117G50DICT-ND"),
					.value("ZLDO1117G50DICT-ND")
				) dcell (
					.p4(vout),
					.p3(vin),
					.p2(vout),
					.p1(gnd)
				);
			end
			
			3300: begin		
				SOT223 #(
					.distributor("digikey"),
					.distributor_part("ZLDO1117G33DICT-ND"),
					.value("ZLDO1117G33DICT-ND")
				) dcell (
					.p4(vout),
					.p3(vin),
					.p2(vout),
					.p1(gnd)
				);
			end
			
			2500: begin		
				SOT223 #(
					.distributor("digikey"),
					.distributor_part("ZLDO1117G25DICT-ND"),
					.value("ZLDO1117G25DICT-ND")
				) dcell (
					.p4(vout),
					.p3(vin),
					.p2(vout),
					.p1(gnd)
				);
			end
			
			1800: begin		
				SOT223 #(
					.distributor("digikey"),
					.distributor_part("ZLDO1117G18DICT-ND"),
					.value("ZLDO1117G18DICT-ND")
				) dcell (
					.p4(vout),
					.p3(vin),
					.p2(vout),
					.p1(gnd)
				);
			end
			
			1500: begin		
				SOT223 #(
					.distributor("digikey"),
					.distributor_part("ZLDO1117G15DICT-ND"),
					.value("ZLDO1117G15DICT-ND")
				) dcell (
					.p4(vout),
					.p3(vin),
					.p2(vout),
					.p1(gnd)
				);
			end
			
			1200: begin	
				SOT223 #(
					.distributor("digikey"),
					.distributor_part("ZLDO1117G12DICT-ND"),
					.value("ZLDO1117G12DICT-ND")
				) dcell (
					.p4(vout),
					.p3(vin),
					.p2(vout),
					.p1(gnd)
				);
			end
			
			default: begin
				assert property (1 == 0);
			end
			
		endcase
			
	endgenerate
	
endmodule

