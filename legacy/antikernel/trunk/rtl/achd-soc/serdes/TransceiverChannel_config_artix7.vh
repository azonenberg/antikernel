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
	@brief Tables of configuration values for Artix-7 GTPE2_CHANNEL
	
	Black-box configurations extracted from transceiver wizard
 */

//Reset time for Physical Medium Attachment (units unknown.. .cycles of some clock?)
function [4:0] artix7_gtp_tx_pmareset_time;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_tx_pmareset_time = 5'b00001;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Reset time for Physical Medium Attachment (units unknown.. .cycles of some clock?)
function [4:0] artix7_gtp_rx_pmareset_time;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_rx_pmareset_time = 5'b00011;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Reset time for Physical Coding Sublayer (units unknown.. .cycles of some clock?)
function [4:0] artix7_gtp_tx_pcsreset_time;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_tx_pcsreset_time = 5'b00001;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//No idea what this does
function [4:0] artix7_gtp_rx_oscalreset_time;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_rx_oscalreset_time = 5'b00011;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//No idea what this does
function [4:0] artix7_gtp_rx_oscalreset_timeout;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_rx_oscalreset_timeout = 5'b00000;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Reset time for something to do with clock recovery
function [4:0] artix7_gtp_rx_cdr_phreset_time;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_rx_cdr_phreset_time = 5'b00001;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Something to do with loopback
function artix7_gtp_loopback_cfg;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_loopback_cfg = 1'b0;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Something to do with loopback
function artix7_gtp_pma_loopback_cfg;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_pma_loopback_cfg = 1'b0;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Width (after line coding) of the datapath
function [4:0] artix7_gtp_data_width;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_data_width = 20;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Divider from PLL clock to serial clock
function [2:0] artix7_gtp_out_div;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_out_div = 3'd4;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Reset time for something to do with clock recovery
function [4:0] artix7_gtp_rx_cdr_freqreset_time;
	input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_rx_cdr_freqreset_time = 5'b00001;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction

//Some kind of clock recovery configuration
//Low bit enables digital monitor
function [42:0] artix7_gtp_cfok_cfg;
input [71:0] iface;
	
	case(iface)
		"1000BASEX":	artix7_gtp_cfok_cfg = 43'h49000040E81;
		
		default: begin
			$display("Unsupported target interface");
			$finish;
		end
	endcase
	
endfunction
