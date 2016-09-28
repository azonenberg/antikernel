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
	@brief Transceiver group support block (PLLs and support logic)
	
	For now, we configure both PLLs identically and assume the reference clock comes from channel 0.
	TODO: Support different configs for them
	
	Legal TARGET_INTERFACE values:
	
		Interface		Data rate		FPGA family			Reference clock frequency
		1000BASEX		1000 Mbps		XILINX_ARTIX7		125 MHz
 */
module TransceiverPLL(clk_reset, reset, refclk, pll_clk, pll_refclk, pll_lock);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	//Interface clock (usually NoC)
	input wire			clk_reset;
	
	//Reset input (clk domain)
	input wire			reset;
	
	//Reference input clocks for the PLL
	input wire[1:0]		refclk;
	
	//PLL outputs
	output wire[1:0]	pll_clk;
	output wire[1:0]	pll_refclk;
	output wire[1:0]	pll_lock;
	
	parameter TARGET_INTERFACE = "INVALID";
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pull in chip-specific configuration tables
	
	`include "TransceiverPLL_config_artix7.vh";
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceiver block
	
	//GTP PLL signals
	wire		pll0_clk;
	wire		pll1_clk;
	wire		pll0_refclk;
	wire		pll1_refclk;
	
	`ifdef XILINX_ARTIX7

		localparam PLL_FBDIV 		= artix7_gtp_pll_fbdiv(TARGET_INTERFACE);
		localparam PLL_FBDIV_45		= artix7_gtp_pll_fbdiv_45(TARGET_INTERFACE);
		localparam PLL_CFG			= artix7_gtp_pll_config(TARGET_INTERFACE);
		localparam PLL_LOCK_CFG		= artix7_gtp_pll_lock_config(TARGET_INTERFACE);
		localparam PLL_INIT_CFG		= artix7_gtp_pll_init_config(TARGET_INTERFACE);
		localparam PLL_DMON_CFG		= artix7_gtp_pll_dmon_config(TARGET_INTERFACE);
		localparam PLL_RESERVED		= artix7_gtp_pll_reserved_attr(TARGET_INTERFACE);

		GTPE2_COMMON #(
			
			//Simulation stuff - unused
			.SIM_RESET_SPEEDUP(1'b0),
			.SIM_VERSION("1.0"),
			.SIM_PLL0REFCLK_SEL(3'b001),
			.SIM_PLL1REFCLK_SEL(3'b001),
			
			//PLL 0 configuration
			.PLL0_REFCLK_DIV(1),
			.PLL0_FBDIV(PLL_FBDIV),
			.PLL0_FBDIV_45(PLL_FBDIV_45),
			.PLL0_CFG(PLL_CFG),					//magic value from transceiver wizard
			.PLL0_LOCK_CFG(PLL_LOCK_CFG),		//magic value from transceiver wizard
			.PLL0_INIT_CFG(PLL_INIT_CFG),		//magic value from transceiver wizard
			.PLL0_DMON_CFG(PLL_DMON_CFG),		//magic value from transceiver wizard
			.RSVD_ATTR0(PLL_RESERVED),			//magic value from transceiver wizard
			
			//PLL 1 configuration
			.PLL1_REFCLK_DIV(1),
			.PLL1_FBDIV(PLL_FBDIV),
			.PLL1_FBDIV_45(PLL_FBDIV_45),
			.PLL1_CFG(PLL_CFG),
			.PLL1_LOCK_CFG(PLL_LOCK_CFG),
			.PLL1_INIT_CFG(PLL_INIT_CFG),
			.PLL1_DMON_CFG(PLL_DMON_CFG),
			.RSVD_ATTR1(PLL_RESERVED)
			
		) gtp_common (
					
			//Input clocks
			.GTREFCLK0(refclk[0]),			//reference clock
			.GTREFCLK1(refclk[1]),			//second reference clock
			.GTWESTREFCLK0(),				//adjacent reference clock, not used
			.GTWESTREFCLK1(),				//adjacent reference clock, not used
			.GTEASTREFCLK0(),				//adjacent reference clock, not used
			.GTEASTREFCLK1(),				//adjacent reference clock, not used
		
			//PLL 0
			.PLL0REFCLKSEL(3'b001),			//reference clock selector (TODO make configurable)
			.PLL0OUTCLK(pll_clk[0]),		//output clock to GTP channels
			.PLL0OUTREFCLK(pll_refclk[0]),
			.PLL0LOCKDETCLK(clk_reset),		//clock for lock detector
			.PLL0LOCKEN(1'b1),				//always must be high
			.PLL0PD(1'b0),					//not powering down PLL
			.PLL0RESET(reset),
			.PLL0FBCLKLOST(),				//lock detector
			.PLL0LOCK(pll_lock[0]),			//lock status
			.PLL0REFCLKLOST(),				//lock detector
			
			//PLL 1
			.PLL1REFCLKSEL(3'b001),
			.PLL1OUTCLK(pll_clk[1]),
			.PLL1OUTREFCLK(pll_refclk[1]),
			.PLL1LOCKDETCLK(clk_reset),
			.PLL1LOCKEN(1'b1),
			.PLL1PD(1'b1),					//power down PLL1 since we dont use it yet
			.PLL1RESET(reset),
			.PLL1FBCLKLOST(),
			.PLL1LOCK(pll_lock[1]),
			.PLL1REFCLKLOST(),

			//Reserved stuff
			.GTGREFCLK0(),					//internal reference clock, reserved for die test
			.GTGREFCLK1(),					//internal reference clock, reserved for die test
			.REFCLKOUTMONITOR0(),			//undocumented? xst complains about not being used
			.REFCLKOUTMONITOR1(),			//undocumented? xst complains about not being used
			.PMARSVD(),						//undocumented? xst complains about not being used
			.PMARSVDOUT(),					//undocumented? xst complains about not being used
			.PLLRSVD1(),					//undocumented? xst complains about not being used
			.PLLRSVD2(),					//undocumented? xst complains about not being used
			.DMONITOROUT(),					//undocumented? xst complains about not being used
			.BGBYPASSB(1'b1),				//magic value from UG482 table 2-8
			.BGMONITORENB(1'b1),			//magic value from UG482 table 2-8
			.BGPDB(1'b1),					//magic value from UG482 table 2-8
			.BGRCALOVRD(5'b11111),			//magic value from UG482 table 2-8
			.BGRCALOVRDENB(1'b1),			//magic value from UG482 table 2-8
			.RCALENB(1'b1),					//magic value from UG482 table 2-8
			
			//Runtime reconfiguration (not currently hooked up)
			.DRPADDR(8'h0),					//DRP address bus
			.DRPCLK(clk_reset),				//DRP clock
			.DRPEN(1'b0),					//DRP activity strobe
			.DRPDI(16'h0),					//DRP write bus
			.DRPRDY(),						//DRP ready flag
			.DRPDO(),						//DRP read bus
			.DRPWE(1'b0)					//DRP write enable
		);
		
	`endif

endmodule
