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

module TragicLaserPHY_iobufs(

	//Clocking
	input wire			clk_125mhz,
	input wire			clk_500mhz_bufpll,
	input wire			serdes_strobe,

	//Wire-side transmit interface
	output wire			tx_p_b,
    output wire[1:0]	tx_p_a,
    output wire			tx_n_b,
    output wire[1:0]	tx_n_a,

	//Wire-side receive interface
    input wire			rx_p_signal_hi,
	input wire			rx_p_vref_hi,
	input wire			rx_p_signal_lo,
	input wire			rx_p_vref_lo,

	//Optional negative side RX interface (not currently implemented)
	/*
	input wire			rx_n_signal_hi,
	input wire			rx_n_vref_hi,
	input wire			rx_n_signal_lo,
	input wire			rx_n_vref_lo,
	*/

	//100M drivers
	input wire[3:0]		tx_d_100m_p,
	input wire[3:0]		tx_t_100m_p,

	input wire[3:0]		tx_d_100m_n,
	input wire[3:0]		tx_t_100m_n,

	//weak pre-emphasis drivers
	input wire[3:0]		tx_d_10m_p,
	input wire[3:0]		tx_t_10m_p,

	input wire[3:0]		tx_d_10m_n,
	input wire[3:0]		tx_t_10m_n,

	//Full strength drivers (no serialization)
	input wire			tx_d_10m_p_full,
	input wire			tx_t_10m_p_full,

	input wire			tx_d_10m_n_full,
	input wire			tx_t_10m_n_full,

	output reg[3:0]		rx_p_hi_arr	= 0,
	output reg[3:0]		rx_p_lo_arr	= 0
);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Differential input buffers

	wire	rx_p_hi;
	wire	rx_p_lo;

	wire	rx_n_hi;
	wire	rx_n_lo;

	IBUFDS #(
		.DIFF_TERM("FALSE"),
		.IOSTANDARD("LVDS_33")
	) ibuf_rx_p_hi(
		.I(rx_p_signal_hi),
		.IB(rx_p_vref_hi),
		.O(rx_p_hi)
	);

	IBUFDS #(
		.DIFF_TERM("FALSE"),
		.IOSTANDARD("LVDS_33")
	) ibuf_rx_p_lo(
		.I(rx_p_signal_lo),
		.IB(rx_p_vref_lo),
		.O(rx_p_lo)
	);

	/*
	IBUFDS #(
		.DIFF_TERM("FALSE"),
		.IOSTANDARD("LVDS_33")
	) ibuf_rx_n_hi(
		.I(rx_n_signal_hi),
		.IB(rx_n_vref_hi),
		.O(rx_n_hi)
	);

	IBUFDS #(
		.DIFF_TERM("FALSE"),
		.IOSTANDARD("LVDS_33")
	) ibuf_rx_n_lo(
		.I(rx_n_signal_lo),
		.IB(rx_n_vref_lo),
		.O(rx_n_lo)
	);
	*/

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// 4x input oversampling

	wire[3:0]	rx_p_hi_arr_raw;
	wire[3:0]	rx_p_lo_arr_raw;

	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("RETIMED")
	) rx_p_hi_serdes (
		.CLK0(clk_500mhz_bufpll),
		.CLKDIV(clk_125mhz),
		.CE0(1'b1),
		.CFB0(),
		.CFB1(),
		.CLK1(),
		.DFB(),
		.INCDEC(),
		.SHIFTIN(),
		.SHIFTOUT(),
		.FABRICOUT(),
		.VALID(),
		.BITSLIP(1'b0),
		.D(rx_p_hi),
		.RST(1'b0),
		.IOCE(serdes_strobe),
		.Q1(rx_p_hi_arr_raw[3]),
		.Q2(rx_p_hi_arr_raw[2]),
		.Q3(rx_p_hi_arr_raw[1]),
		.Q4(rx_p_hi_arr_raw[0])
	);

	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("RETIMED")
	) rx_p_lo_serdes (
		.CLK0(clk_500mhz_bufpll),
		.CLKDIV(clk_125mhz),
		.CE0(1'b1),
		.CFB0(),
		.CFB1(),
		.CLK1(),
		.DFB(),
		.INCDEC(),
		.SHIFTIN(),
		.SHIFTOUT(),
		.FABRICOUT(),
		.VALID(),
		.BITSLIP(1'b0),
		.D(rx_p_lo),
		.RST(1'b0),
		.IOCE(serdes_strobe),
		.Q1(rx_p_lo_arr_raw[3]),
		.Q2(rx_p_lo_arr_raw[2]),
		.Q3(rx_p_lo_arr_raw[1]),
		.Q4(rx_p_lo_arr_raw[0])
	);

	/*
	wire[3:0]	rx_n_hi_arr;
	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("RETIMED")
	) rx_n_hi_serdes (
		.CLK0(clk_500mhz_bufpll),
		.CLKDIV(clk_125mhz),
		.CE0(1'b1),
		.BITSLIP(1'b0),
		.D(rx_n_hi),
		.RST(1'b0),
		.IOCE(serdes_strobe),
		.Q1(rx_n_hi_arr[3]),
		.Q2(rx_n_hi_arr[2]),
		.Q3(rx_n_hi_arr[1]),
		.Q4(rx_n_hi_arr[0])
	);

	wire[3:0]	rx_n_lo_arr;
	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("RETIMED")
	) rx_n_lo_serdes (
		.CLK0(clk_500mhz_bufpll),
		.CLKDIV(clk_125mhz),
		.CE0(1'b1),
		.BITSLIP(1'b0),
		.D(rx_n_lo),
		.RST(1'b0),
		.IOCE(serdes_strobe),
		.Q1(rx_n_lo_arr[3]),
		.Q2(rx_n_lo_arr[2]),
		.Q3(rx_n_lo_arr[1]),
		.Q4(rx_n_lo_arr[0])
	);
	*/

	//Register the inputs to improve setup timing
	always @(posedge clk_125mhz) begin
		rx_p_hi_arr		<= rx_p_hi_arr_raw;
		rx_p_lo_arr		<= rx_p_lo_arr_raw;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output buffers for 10Mbps lines

	wire			tx_p_a0_raw;
	wire			tx_p_a0_t;

	wire			tx_n_a0_raw;
	wire			tx_n_a0_t;

	//Actual 10M
	OBUFT #(
		.DRIVE(24),
		.SLEW("FAST")
	) obuf_10m_p1(
		.I(tx_d_10m_p_full),
		.T(tx_t_10m_p_full),
		.O(tx_p_a[1])
	);

	OBUFT #(
		.DRIVE(24),
		.SLEW("FAST")
	)  obuf_10m_n1(
		.I(tx_d_10m_n_full),
		.T(tx_t_10m_n_full),
		.O(tx_n_a[1])
	);

	//Pre-emphasis
	OBUFT #(
		.DRIVE(2),
		.SLEW("SLOW")
	)  obuf_10m_p0(
		.I(tx_p_a0_raw),
		.T(tx_p_a0_t),
		.O(tx_p_a[0])
	);

	OBUFT #(
		.DRIVE(2),
		.SLEW("SLOW")
	)  obuf_10m_n0(
		.I(tx_n_a0_raw),
		.T(tx_n_a0_t),
		.O(tx_n_a[0])
	);

	OSERDES2 #(
		.DATA_RATE_OQ("SDR"),
		.DATA_RATE_OT("SDR"),
		.DATA_WIDTH(4),
		.OUTPUT_MODE("SINGLE_ENDED"),
		.SERDES_MODE("MASTER"),
		.TRAIN_PATTERN(16'h0)
	) serdes_10m_p (
		.CLKDIV(clk_125mhz),
		.CLK0(clk_500mhz_bufpll),
		.CLK1(),
		.D1(tx_d_10m_p[0]),
		.D2(tx_d_10m_p[1]),
		.D3(tx_d_10m_p[2]),
		.D4(tx_d_10m_p[3]),
		.IOCE(serdes_strobe),
		.OCE(1'b1),
		.OQ(tx_p_a0_raw),
		.RST(1'b0),
		.TCE(1'b1),
		.TQ(tx_p_a0_t),
		.TRAIN(1'b0),
		.T1(tx_t_10m_p[0]),
		.T2(tx_t_10m_p[1]),
		.T3(tx_t_10m_p[2]),
		.T4(tx_t_10m_p[3]),

		.SHIFTOUT1(),
		.SHIFTOUT2(),
		.SHIFTOUT3(),
		.SHIFTOUT4(),
		.SHIFTIN1(1'b0),
		.SHIFTIN2(1'b0),
		.SHIFTIN3(1'b0),
		.SHIFTIN4(1'b0)
	);

	OSERDES2 #(
		.DATA_RATE_OQ("SDR"),
		.DATA_RATE_OT("SDR"),
		.DATA_WIDTH(4),
		.OUTPUT_MODE("SINGLE_ENDED"),
		.SERDES_MODE("MASTER"),
		.TRAIN_PATTERN(16'h0)
	) serdes_10m_n (
		.CLKDIV(clk_125mhz),
		.CLK0(clk_500mhz_bufpll),
		.CLK1(),
		.D1(tx_d_10m_n[0]),
		.D2(tx_d_10m_n[1]),
		.D3(tx_d_10m_n[2]),
		.D4(tx_d_10m_n[3]),
		.IOCE(serdes_strobe),
		.OCE(1'b1),
		.OQ(tx_n_a0_raw),
		.RST(1'b0),
		.TCE(1'b1),
		.TQ(tx_n_a0_t),
		.TRAIN(1'b0),
		.T1(tx_t_10m_n[0]),
		.T2(tx_t_10m_n[1]),
		.T3(tx_t_10m_n[2]),
		.T4(tx_t_10m_n[3]),

		.SHIFTOUT1(),
		.SHIFTOUT2(),
		.SHIFTOUT3(),
		.SHIFTOUT4(),
		.SHIFTIN1(1'b0),
		.SHIFTIN2(1'b0),
		.SHIFTIN3(1'b0),
		.SHIFTIN4(1'b0)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output buffers for 100Mbps lines

	wire			tx_p_b_raw;
	wire			tx_p_b_t;

	wire			tx_n_b_raw;
	wire			tx_n_b_t;

	OBUFT #(
		.DRIVE(24),
		.SLEW("FAST")
	) obuf_100m_p(
		.I(tx_p_b_raw),
		.T(tx_p_b_t),
		.O(tx_p_b)
	);

	OBUFT #(
		.DRIVE(24),
		.SLEW("FAST")
	) obuf_100m_n(
		.I(tx_n_b_raw),
		.T(tx_n_b_t),
		.O(tx_n_b)
	);

	OSERDES2 #(
		.DATA_RATE_OQ("SDR"),
		.DATA_RATE_OT("SDR"),
		.DATA_WIDTH(4),
		.OUTPUT_MODE("SINGLE_ENDED"),
		.SERDES_MODE("MASTER"),
		.TRAIN_PATTERN(16'h0)
	) serdes_100m_p (
		.CLKDIV(clk_125mhz),
		.CLK0(clk_500mhz_bufpll),
		.CLK1(),
		.D1(tx_d_100m_p[0]),
		.D2(tx_d_100m_p[1]),
		.D3(tx_d_100m_p[2]),
		.D4(tx_d_100m_p[3]),
		.IOCE(serdes_strobe),
		.OCE(1'b1),
		.OQ(tx_p_b_raw),
		.RST(1'b0),
		.TCE(1'b1),
		.TQ(tx_p_b_t),
		.TRAIN(1'b0),
		.T1(tx_t_100m_p[0]),
		.T2(tx_t_100m_p[1]),
		.T3(tx_t_100m_p[2]),
		.T4(tx_t_100m_p[3]),

		.SHIFTOUT1(),
		.SHIFTOUT2(),
		.SHIFTOUT3(),
		.SHIFTOUT4(),
		.SHIFTIN1(1'b0),
		.SHIFTIN2(1'b0),
		.SHIFTIN3(1'b0),
		.SHIFTIN4(1'b0)
	);

	OSERDES2 #(
		.DATA_RATE_OQ("SDR"),
		.DATA_RATE_OT("SDR"),
		.DATA_WIDTH(4),
		.OUTPUT_MODE("SINGLE_ENDED"),
		.SERDES_MODE("MASTER"),
		.TRAIN_PATTERN(16'h0)
	) serdes_100m_n (
		.CLKDIV(clk_125mhz),
		.CLK0(clk_500mhz_bufpll),
		.CLK1(),
		.D1(tx_d_100m_n[0]),
		.D2(tx_d_100m_n[1]),
		.D3(tx_d_100m_n[2]),
		.D4(tx_d_100m_n[3]),
		.IOCE(serdes_strobe),
		.OCE(1'b1),
		.OQ(tx_n_b_raw),
		.RST(1'b0),
		.TCE(1'b1),
		.TQ(tx_n_b_t),
		.TRAIN(1'b0),
		.T1(tx_t_100m_n[0]),
		.T2(tx_t_100m_n[1]),
		.T3(tx_t_100m_n[2]),
		.T4(tx_t_100m_n[3]),

		.SHIFTOUT1(),
		.SHIFTOUT2(),
		.SHIFTOUT3(),
		.SHIFTOUT4(),
		.SHIFTIN1(1'b0),
		.SHIFTIN2(1'b0),
		.SHIFTIN3(1'b0),
		.SHIFTIN4(1'b0)
	);

endmodule
