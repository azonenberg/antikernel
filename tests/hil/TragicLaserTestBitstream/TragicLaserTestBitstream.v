`default_nettype none
/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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

module TragicLaserTestBitstream(
	input wire 			clk_100mhz,

    output reg[1:0] 	led = 0,
    inout wire[9:0] 	gpio,

    output wire			tx_p_b,
    output wire[1:0]	tx_p_a,
    output wire			tx_n_b,
    output wire[1:0]	tx_n_a,

    input wire			rx_p_signal_hi,
	input wire			rx_p_vref_hi,
	input wire			rx_p_signal_lo,
	input wire			rx_p_vref_lo,

	input wire			rx_n_signal_hi,
	input wire			rx_n_vref_hi,
	input wire			rx_n_signal_lo,
	input wire			rx_n_vref_lo
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Buffer the main system clock

	wire clk_100mhz_bufg;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) sysclk_clkbuf (
		.clkin(clk_100mhz),
		.clkout(clk_100mhz_bufg),
		.ce(1'b1)
	);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock generation

	wire		clk_fb;
	wire		clk_25mhz_raw;
	wire		clk_125mhz_raw;
	wire		clk_500mhz_raw;

	wire		pll_locked;

	PLL_BASE #(
		.CLKIN_PERIOD(10.0),						//100 MHz input
		.DIVCLK_DIVIDE(1),							//Divide to get 100 MHz at the PFD
		.CLKFBOUT_MULT(10),							//Multiply by 10 for 1 GHz VCO
		.CLKFBOUT_PHASE(0.0),
		.CLKOUT0_DIVIDE(2),							//negative version of 500 MHz oversampling clock
		.CLKOUT1_DIVIDE(40),						//25 MHz MII clock
		.CLKOUT2_DIVIDE(8),							//125 MHz Ethernet clock
		.CLKOUT3_DIVIDE(8),
		.CLKOUT4_DIVIDE(8),
		.CLKOUT5_DIVIDE(8),
		.CLKOUT0_DUTY_CYCLE(0.50),
		.CLKOUT1_DUTY_CYCLE(0.50),
		.CLKOUT2_DUTY_CYCLE(0.50),
		.CLKOUT3_DUTY_CYCLE(0.50),
		.CLKOUT4_DUTY_CYCLE(0.50),
		.CLKOUT5_DUTY_CYCLE(0.50),
		.CLKOUT0_PHASE(0.0),
		.CLKOUT1_PHASE(0.0),
		.CLKOUT2_PHASE(0.0),
		.CLKOUT3_PHASE(0.0),
		.CLKOUT4_PHASE(0.0),
		.CLKOUT5_PHASE(0.0),
		.BANDWIDTH("OPTIMIZED"),
		.CLK_FEEDBACK("CLKFBOUT"),
		.COMPENSATION("SYSTEM_SYNCHRONOUS"),
		.REF_JITTER(0.1),
		.RESET_ON_LOSS_OF_LOCK("FALSE")
	)
	clkgen
	(
		.CLKFBOUT(clk_fb),
		.CLKOUT0(clk_500mhz_raw),
		.CLKOUT1(clk_25mhz_raw),
		.CLKOUT2(clk_125mhz_raw),
		.CLKOUT3(),
		.CLKOUT4(),
		.CLKOUT5(),
		.LOCKED(pll_locked),
		.CLKFBIN(clk_fb),
		.CLKIN(clk_100mhz),
		.RST(1'b0)
	);

	wire clk_125mhz_bufg;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) ethclk_clkbuf (
		.clkin(clk_125mhz_raw),
		.clkout(clk_125mhz_bufg),
		.ce(1'b1)
	);

	wire clk_25mhz_bufg;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) miiclk_clkbuf (
		.clkin(clk_25mhz_raw),
		.clkout(clk_25mhz_bufg),
		.ce(1'b1)
	);

	wire clk_500mhz_bufpll;
	wire serdes_strobe;

	BUFPLL #(
		.DIVIDE(4),
		.ENABLE_SYNC("TRUE")
	) bufpll_p (
		.PLLIN(clk_500mhz_raw),
		.GCLK(clk_125mhz_bufg),
		.LOCKED(pll_locked),
		.IOCLK(clk_500mhz_bufpll),
		.SERDESSTROBE(serdes_strobe),
		.LOCK()	//indicates BUFPLL has locked the strobe
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The actual PHY

    wire		mii_tx_clk;
    reg			mii_tx_en	= 0;
    reg			mii_tx_er	= 0;
    reg[3:0]	mii_txd		= 0;

    TragicLaserPHY phy(
		.clk_25mhz(clk_25mhz_bufg),
		.clk_125mhz(clk_125mhz_bufg),
		.clk_500mhz_bufpll(clk_500mhz_bufpll),
		.serdes_strobe(serdes_strobe),

		.tx_p_a(tx_p_a),
		.tx_p_b(tx_p_b),
		.tx_n_a(tx_n_a),
		.tx_n_b(tx_n_b),

		.rx_p_signal_hi(rx_p_signal_hi),
		.rx_p_vref_hi(rx_p_vref_hi),
		.rx_p_signal_lo(rx_p_signal_lo),
		.rx_p_vref_lo(rx_p_vref_lo),

		.rx_n_signal_hi(rx_n_signal_hi),
		.rx_n_vref_hi(rx_n_vref_hi),
		.rx_n_signal_lo(rx_n_signal_lo),
		.rx_n_vref_lo(rx_n_vref_lo),

		.mii_tx_clk(mii_tx_clk),
		.mii_tx_en(mii_tx_en),
		.mii_tx_er(mii_tx_er),
		.mii_txd(mii_txd),

		.gpio(gpio)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MII bus

    reg[7:0]	mcount	= 0;
    reg[7:0]	mstate = 0;

    always @(posedge mii_tx_clk) begin

		mii_tx_er			<= 0;

		case(mstate)

			//Wait, then start the frame
			0: begin
				mcount		<= mcount + 1'h1;
				if(mcount == 255) begin
					mii_tx_en	<= 1;
					mstate		<= 1;
				end
			end

			//Preamble
			1: begin
				mii_txd			<= 4'h5;
				mcount			<= mcount + 1'h1;
				if(mcount == 15) begin
					mii_txd		<= 4'hd;
					mstate		<= 2;
					mcount		<= 0;
				end
			end

			//64 dummy bytes
			2: begin
				mii_txd			<= 4'hc;
				mcount			<= mcount + 1'h1;

				if(mcount == 63) begin
					mii_tx_en	<= 0;
					mcount		<= 0;
					mstate		<= 0;
				end
			end

		endcase
    end

endmodule
