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
	@brief Table of PLL timing / configuration values
	
	Use MMCMs, not PLLs, for 7 series
 */
 
 //Maximum legal period, in picoseconds, at input to the PLL
 function integer pll_input_max_period;
 
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_input_max_period = 52630;
			2:	pll_input_max_period = 52630;
			3:	pll_input_max_period = 52630;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_input_max_period = 100000;
			2:	pll_input_max_period = 100000;
			3:	pll_input_max_period = 100000;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_input_max_period = 100000;
			2:	pll_input_max_period = 100000;
			3:	pll_input_max_period = 100000;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Minimum legal period, in picoseconds, at input to the PLL
function integer pll_input_min_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_input_min_period = 3333;
			2:	pll_input_min_period = 2222;
			3:	pll_input_min_period = 1852;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_input_min_period = 1250;
			2:	pll_input_min_period = 1250;
			3:	pll_input_min_period = 1250;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_input_min_period = 1250;
			2:	pll_input_min_period = 1072;
			3:	pll_input_min_period =  938;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Maximum legal period, in picoseconds, at input to the phase-frequency detector
function integer pll_pfd_max_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_pfd_max_period = 52630;
			2:	pll_pfd_max_period = 52630;
			3:	pll_pfd_max_period = 52630;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_pfd_max_period = 100000;
			2:	pll_pfd_max_period = 100000;
			3:	pll_pfd_max_period = 100000;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_pfd_max_period = 100000;
			2:	pll_pfd_max_period = 100000;
			3:	pll_pfd_max_period = 100000;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Minimum legal period, in picoseconds, at input to the phase-frequency detector
function integer pll_pfd_min_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_pfd_min_period = 3333;
			2:	pll_pfd_min_period = 2500;
			3:	pll_pfd_min_period = 2000;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_pfd_min_period = 2222;
			2:	pll_pfd_min_period = 2000;
			3:	pll_pfd_min_period = 1818;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_pfd_min_period = 2222;
			2:	pll_pfd_min_period = 2000;
			3:	pll_pfd_min_period = 1818;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Maximum legal period, in picoseconds, of the VCO
function integer pll_vco_max_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_vco_max_period = 2500;
			2:	pll_vco_max_period = 2500;
			3:	pll_vco_max_period = 2500;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_vco_max_period = 1667;
			2:	pll_vco_max_period = 1667;
			3:	pll_vco_max_period = 1667;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_vco_max_period = 1667;
			2:	pll_vco_max_period = 1667;
			3:	pll_vco_max_period = 1667;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Minimum legal period, in picoseconds, of the VCO
function integer pll_vco_min_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_vco_min_period = 1000;
			2:	pll_vco_min_period = 1000;
			3:	pll_vco_min_period =  926;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_vco_min_period =  833;
			2:	pll_vco_min_period =  694;
			3:	pll_vco_min_period =  625;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_vco_min_period =  833;
			2:	pll_vco_min_period =  694;
			3:	pll_vco_min_period =  625;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Maximum legal period, in picoseconds, of a PLL output
function integer pll_output_max_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_output_max_period = 320000;
			2:	pll_output_max_period = 320000;
			3:	pll_output_max_period = 320000;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_output_max_period = 213220;
			2:	pll_output_max_period = 213220;
			3:	pll_output_max_period = 213220;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_output_max_period = 213220;
			2:	pll_output_max_period = 213220;
			3:	pll_output_max_period = 213220;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Minimum legal period, in picoseconds, of a PLL output
function integer pll_output_min_period;
	
	input integer speed;
	
	//from DS162
	`ifdef XILINX_SPARTAN6
		case(speed)
			1:	pll_output_min_period = 2000;
			2:	pll_output_min_period = 1053;
			3:	pll_output_min_period =  926;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS181
	`ifdef XILINX_ARTIX7
		case(speed)
			1:	pll_output_min_period = 1250;
			2:	pll_output_min_period = 1250;
			3:	pll_output_min_period = 1250;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
	//from DS182
	`ifdef XILINX_KINTEX7
		case(speed)
			1:	pll_output_min_period = 1250;
			2:	pll_output_min_period = 1072;
			3:	pll_output_min_period =  938;
			default: begin
				$display("Unrecognized speed grade");
				$finish;
			end
		endcase
	`endif
	
endfunction

//Maximum legal input divider
function integer pll_indiv_max;
	
	input integer speed;
	
	`ifdef XILINX_SPARTAN6
		pll_indiv_max	= 52;
	`endif
	
	`ifdef XILINX_ARTIX7
		pll_indiv_max	= 106;
	`endif
	
	`ifdef XILINX_KINTEX7
		pll_indiv_max	= 106;
	`endif
	
endfunction

//Maximum legal multiplier
function integer pll_mult_max;
	
	input integer speed;
	
	`ifdef XILINX_SPARTAN6
		pll_mult_max	= 64;
	`endif
	
	`ifdef XILINX_ARTIX7
		pll_mult_max	= 64;
	`endif
	
	`ifdef XILINX_KINTEX7
		pll_mult_max	= 64;
	`endif
	
endfunction

//Maximum legal output divider
function integer pll_outdiv_max;

	input integer speed;
	
	`ifdef XILINX_SPARTAN6
		pll_outdiv_max	= 128;
	`endif
	
	`ifdef XILINX_ARTIX7
		pll_outdiv_max	= 128;
	`endif
	
	`ifdef XILINX_KINTEX7
		pll_outdiv_max	= 128;
	`endif
	
endfunction
