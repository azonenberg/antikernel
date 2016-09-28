`timescale 1ns / 1ps
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
	@brief GMII to [R]GMII converter
 */
module EthernetBusWidthConverter(

	//[R]GMII signals
	xmii_rxc, xmii_rxd, xmii_rx_ctl,
	xmii_txc, xmii_txd, xmii_tx_ctl,
	
	//GMII signals
	gmii_rxc, gmii_rxd, gmii_rx_dv, gmii_rx_er,
	gmii_txc, gmii_txd, gmii_tx_en, gmii_tx_er
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Set this to 1 for RGMII, 0 for GMII
	parameter	PHY_INTERFACE_RGMII = 0;
	
	//Width of data/control buses
	localparam	DATA_WIDTH			= PHY_INTERFACE_RGMII ? 4 : 8;
	localparam	CTRL_WIDTH 			= PHY_INTERFACE_RGMII ? 1 : 2;
	
	//Output phase shift selection
	//Must be DELAY or PLL
	parameter	OUTPUT_PHASE_SHIFT	= "DELAY";
	
	parameter CLOCK_BUF_TYPE = "GLOBAL";
	
	//[R]GMII signals
	input wire 					xmii_rxc;
	input wire[DATA_WIDTH-1:0]	xmii_rxd;
	input wire[CTRL_WIDTH-1:0]	xmii_rx_ctl;
	output wire					xmii_txc;
	output wire[DATA_WIDTH-1:0] xmii_txd;
	output wire[CTRL_WIDTH-1:0] xmii_tx_ctl;
	
	//GMII signals
	output wire			gmii_rxc;
	output wire[7:0]	gmii_rxd;
	output wire			gmii_rx_dv;
	output wire			gmii_rx_er;
	input wire			gmii_txc;
	input wire [7:0]	gmii_txd;
	input wire			gmii_tx_en;
	input wire			gmii_tx_er;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Bus width conversion
	
	genvar i;
	generate
	
		//Use local clock buffer so we dont run out of global clocks
		//TODO: need to create BUFH at top level?
		assign gmii_rxc = xmii_rxc;
		/*
		ClockBuffer #(
			.TYPE("LOCAL"),
			.CE("NO")
		) gmii_rxc_bufh (
			.clkin(xmii_rxc),
			.clkout(gmii_rxc),
			.ce(1'b1)
		);
		*/
	
		//Fancy stuff if RGMII
		if(PHY_INTERFACE_RGMII) begin

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// GMII-to-RGMII bridge, rx side
			
			//Delay the GMII data to add additional skew as required by RGMII
			//UI is 4000 ps (250 MT/s).
			//Skew at the sender is +/- 500 ps so our valid eye ignoring rise time is from +500 to +3500 ps
			//We need at least 10 ps setup and 340ps hold for Kintex-7, sampling eye is now now +510 to +3160 ps
			//Assuming equal rise/fall time we want to center in this window so use phase offset of 1835 ps.
			//We want the clock moved forward by +1835 ps, so move the data back by (4000 - 1835) = 2165 ps
			
			wire[3:0]	rgmii_rxd_delayed;
			wire		rgmii_rx_ctl_delayed;
			IODelayBlock #(
				.WIDTH(4),
				.INPUT_DELAY(2165),
				.OUTPUT_DELAY(0),
				.DIRECTION("IN")
			) rgmii_rxd_idelay (
				.i_pad(xmii_rxd),
				.i_fabric(),							//not using direct fabric link
				.i_fabric_serdes(rgmii_rxd_delayed),	//goes to DDR serdes
				.o_pad(),								//not using output datapath
				.o_fabric(4'h0),
				.input_en(1'b1)
			);
			
			IODelayBlock #(
				.WIDTH(1),
				.INPUT_DELAY(2165),
				.OUTPUT_DELAY(0),
				.DIRECTION("IN")
			) rgmii_rxe_idelay (
				.i_pad(xmii_rx_ctl),
				.i_fabric(),							//not using direct fabric link
				.i_fabric_serdes(rgmii_rx_ctl_delayed),	//goes to DDR serdes
				.o_pad(),								//not using output datapath
				.o_fabric(1'h0),
				.input_en(1'b1)
			);
						
			//Receive side
			//Note that since data was delayed with respect to clock, we need to phase-shift
			DDRInputBuffer #(.WIDTH(4)) rgmii_rxd_iddr2(
				.clk_p(gmii_rxc),
				.clk_n(~gmii_rxc),
				.din(rgmii_rxd_delayed),
				.dout0(gmii_rxd[7:4]),
				.dout1(gmii_rxd[3:0])
				);

			wire gmii_rx_er_raw;
			DDRInputBuffer #(.WIDTH(1)) rgmii_rxe_iddr2(
				.clk_p(gmii_rxc),
				.clk_n(~gmii_rxc),
				.din(rgmii_rx_ctl_delayed),
				.dout0(gmii_rx_er_raw),
				.dout1(gmii_rx_dv)
				);
				
			//rx_er flag is encoded specially to reduce transitions (see RGMII spec section 3.4)
			assign gmii_rx_er = gmii_rx_dv ^ gmii_rx_er_raw;
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// GMII-to-RGMII bridge, tx side
			
			//Transmit clock needs to be delayed to center it in the data eye
			//We can use either an IODELAY or a PLL for this
			//PLLs are a scarce resource, but 7-series 3.3V banks do not support ODELAYs
			//so we have to support both
			if(OUTPUT_PHASE_SHIFT == "DELAY") begin
			
				wire	gmii_txc_buf;
			
				//DDR buffer has to be BEFORE the delay line
				DDROutputBuffer #
				(
					.WIDTH(1)
				) txc_output
				(
					.clk_p(gmii_txc),
					.clk_n(~gmii_txc),
					.dout(gmii_txc_buf),
					.din0(1'b1),
					.din1(1'b0)
				);
			
				IODelayBlock #(
					.WIDTH(1),
					.INPUT_DELAY(0),
					.OUTPUT_DELAY(2000),
					.DIRECTION("OUT")
				) rgmii_txc_odelay (
					.i_pad(1'b0),
					.i_fabric(),			//not using direct fabric link
					.i_fabric_serdes(),		//not using input serdes
					.o_pad(xmii_txc),
					.o_fabric(gmii_txc_buf),
					.input_en(1'b0)			//output only
				);
			end
			
			else if(OUTPUT_PHASE_SHIFT == "PLL") begin
			
				wire	xmii_txc_fb;
				wire	xmii_txc_raw;
				wire	xmii_txc_buf;
				wire	xmii_txc_pll_locked;
			
				`ifdef XILINX_SPARTAN6
					PLL_BASE #(
						.BANDWIDTH("OPTIMIZED"),
						.CLKFBOUT_MULT(8),				//125 MHz * 8 = 1 GHz
						.CLKFBOUT_PHASE(0),
						.CLKIN_PERIOD(8),				//8 ns = 125 MHz
						.CLKOUT0_DIVIDE(8),				//1 GHz / 8 = 125 MHz
						.CLKOUT1_DIVIDE(1),
						.CLKOUT2_DIVIDE(1),
						.CLKOUT3_DIVIDE(1),
						.CLKOUT4_DIVIDE(1),
						.CLKOUT5_DIVIDE(1),
						.CLKOUT0_DUTY_CYCLE(0.5),
						.CLKOUT1_DUTY_CYCLE(0.5),
						.CLKOUT2_DUTY_CYCLE(0.5),
						.CLKOUT3_DUTY_CYCLE(0.5),
						.CLKOUT4_DUTY_CYCLE(0.5),
						.CLKOUT5_DUTY_CYCLE(0.5),
						.CLKOUT0_PHASE(270),			//clock lags data by 90 deg
						.CLKOUT1_PHASE(0.0),
						.CLKOUT2_PHASE(0.0),
						.CLKOUT3_PHASE(0.0),
						.CLKOUT4_PHASE(0.0),
						.CLKOUT5_PHASE(0.0),
						.DIVCLK_DIVIDE(1),
						.REF_JITTER(0.01)
					) rgmii_txc_phaseshiftpll (
						.CLKFBIN(xmii_txc_fb),
						.CLKFBOUT(xmii_txc_fb),
						.CLKIN(gmii_txc),
						.CLKOUT0(xmii_txc_raw),
						.CLKOUT1(),
						.CLKOUT2(),
						.CLKOUT3(),
						.CLKOUT4(),
						.CLKOUT5(),
						.LOCKED(xmii_txc_pll_locked),
						.RST(1'b0)						//TODO: Need to reset when link toggles?
					);
				`endif
				
				`ifdef XILINX_7SERIES
					PLLE2_BASE #(
						.BANDWIDTH("OPTIMIZED"),
						.CLKFBOUT_MULT(8),				//125 MHz * 8 = 1 GHz
						.CLKFBOUT_PHASE(0),
						.CLKIN1_PERIOD(8),				//8 ns = 125 MHz
						.CLKOUT0_DIVIDE(8),				//1 GHz / 8 = 125 MHz
						.CLKOUT1_DIVIDE(1),
						.CLKOUT2_DIVIDE(1),
						.CLKOUT3_DIVIDE(1),
						.CLKOUT4_DIVIDE(1),
						.CLKOUT5_DIVIDE(1),
						.CLKOUT0_DUTY_CYCLE(0.5),
						.CLKOUT1_DUTY_CYCLE(0.5),
						.CLKOUT2_DUTY_CYCLE(0.5),
						.CLKOUT3_DUTY_CYCLE(0.5),
						.CLKOUT4_DUTY_CYCLE(0.5),
						.CLKOUT5_DUTY_CYCLE(0.5),
						.CLKOUT0_PHASE(270),			//clock lags data by 90 deg
						.CLKOUT1_PHASE(0.0),
						.CLKOUT2_PHASE(0.0),
						.CLKOUT3_PHASE(0.0),
						.CLKOUT4_PHASE(0.0),
						.CLKOUT5_PHASE(0.0),
						.DIVCLK_DIVIDE(1),
						.REF_JITTER1(0.01)
					) rgmii_txc_phaseshiftpll (
						.CLKFBIN(xmii_txc_fb),
						.CLKFBOUT(xmii_txc_fb),
						.CLKIN1(gmii_txc),
						.CLKOUT0(xmii_txc_raw),
						.CLKOUT1(),
						.CLKOUT2(),
						.CLKOUT3(),
						.CLKOUT4(),
						.CLKOUT5(),
						.LOCKED(xmii_txc_pll_locked),
						.PWRDWN(1'b0),
						.RST(1'b0)						//TODO: Need to reset when link toggles?
					);
				`endif
					
				//Buffer the clock
				ClockBuffer #(
					.TYPE(CLOCK_BUF_TYPE),
					.CE("YES")
				) rgmii_txc_phaseshiftbuf (
					.clkin(xmii_txc_raw),
					.clkout(xmii_txc_buf),
					.ce(xmii_txc_pll_locked)
				);
				
				//DDR buffer has to be AFTER the delay line
				//For some reason we have to invert the transmit clock on 7 series.
				//No idea why this is necessary.
				`ifdef XILINX_7SERIES
					DDROutputBuffer #
					(
						.WIDTH(1)
					) txc_output
					(
						.clk_p(xmii_txc_buf),
						.clk_n(~xmii_txc_buf),
						.dout(xmii_txc),
						.din0(1'b0),
						.din1(1'b1)
					);

				`else
					DDROutputBuffer #
					(
						.WIDTH(1)
					) txc_output
					(
						.clk_p(xmii_txc_buf),
						.clk_n(~xmii_txc_buf),
						.dout(xmii_txc),
						.din0(1'b1),
						.din1(1'b0)
					);
				`endif
				

			end
			
			//sanity check
			else begin
				initial begin
					$display("ERROR: OUTPUT_PHASE_SHIFT must be PLL or DELAY");
					$finish;
				end
			end
			
			DDROutputBuffer #(.WIDTH(4)) rgmii_txd_oddr2(
				.clk_p(gmii_rxc),
				.clk_n(~gmii_rxc),
				.dout(xmii_txd),
				.din0(gmii_txd[3:0]),
				.din1(gmii_txd[7:4])
				);
				
			DDROutputBuffer #(.WIDTH(1)) rgmii_txe_oddr2(
				.clk_p(gmii_rxc),
				.clk_n(~gmii_rxc),
				.dout(xmii_tx_ctl),
				.din0(gmii_tx_en),
				.din1(gmii_tx_en ^ gmii_tx_er)
				);
		end
		
		//No, just copy the lines without changing anything
		else begin
			
			assign gmii_rxd		= xmii_rxd;
			assign gmii_rx_dv	= xmii_rx_ctl[0];
			assign gmii_rx_er	= xmii_rx_ctl[1];
			
			assign xmii_txc		= gmii_txc;
			assign xmii_txd		= gmii_txd;
			assign xmii_tx_ctl	= { gmii_tx_er, gmii_tx_en };
			
		end
	
	endgenerate
	
endmodule
