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
	@brief Helper functions for Artix-7 GTPE2_COMMON
	
	Black-box configurations extracted from transceiver wizard
 */
 
//TODO: Automatic PLL configurations based on reference clock?
 
 /*
	1000BASEX config:
		PLL reference clock is 125 MHz
		Need to be 1.6 - 3.3 GHz
		Output is 1.25 GHz
		
		(125 MHz * 20) = 2.5 GHz
		(/4)*2 = 1.25 GHz
		
		(N1*N2 / M) = 20
		M=1, N1 = 5, N2 = 4
		D = 4
 */

//PLL feedback divisor (N2)
function [4:0] artix7_gtp_pll_fbdiv;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_fbdiv = 4;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Secondary PLL feedback divisor (N1)
function [2:0] artix7_gtp_pll_fbdiv_45;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_fbdiv_45 = 5;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Black-box PLL configuration settings
//Magic value from transceiver wizard
function [26:0] artix7_gtp_pll_config;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_config = 27'h01F03DC;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Black-box PLL configuration settings
//Magic value from transceiver wizard
function [8:0] artix7_gtp_pll_lock_config;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_lock_config = 9'h1E8;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Black-box PLL configuration settings
//Magic value from transceiver wizard
function [23:0] artix7_gtp_pll_init_config;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_init_config = 24'h00001E;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Black-box PLL configuration settings
//Magic value from transceiver wizard
function artix7_gtp_pll_dmon_config;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_dmon_config = 1'b0;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Black-box PLL configuration settings
//Magic value from transceiver wizard
function [15:0] artix7_gtp_pll_reserved_attr;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pll_reserved_attr = 16'h0000;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

