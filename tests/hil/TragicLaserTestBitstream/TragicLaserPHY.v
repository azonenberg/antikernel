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

/**
	@brief The TRAGICLASER Ethernet PHY

	This is a 10/100 Ethernet PHY IP core for FPGA which uses only external passives (no PHY IC).

	Theory of operation (transmit):
		To transmit in 10M mode (or autonegotiation), we need to drive +/- 2.5V into a 100 ohm impedance.
		We use a push-pull FPGA output at either side of the TX magnetics in an H-bridge configuration to drive
		a bidirectional current. Discrete 16-ohm resistors are used at either side of the H-bridge to provide our
		target 25 mA output current. Two FPGA outputs are paired at either side of the H-bridge to provide increased
		drive strength.

		To transmit in 100M mode, we need to drive +/- 1V or 0V into a 100 ohm impedance.
		We use a similar H-bridge to 10M mode, but with lower drive current by using 115 ohm series resistors.

	Required external connections:
		Signal			IOSTANDARD		Description / external connection
		----------------------------------------------------------------------------------------------------------------
		tx_p_a[1:0]		LVCMOS33		High side of 10M/autonegotiation TX H-bridge.
										Connect both bits together for increase drive current.
										Connect a 16 ohm resistor from tx_p_a to TX_P input of magnetics

		tx_n_a[1:0]		LVCMOS33		Low side of 10M/autonegotiation TX H-bridge.
										Connect both bits together for increase drive current.
										Connect a 16 ohm resistor from tx_n_a to TX_N input of magnetics

		tx_p_b			LVCMOS33		High side of 100M TX H-bridge.
										Connect a 115 ohm resistor from tx_p_b to TX_P input of magnetics

		tx_n_b			LVCMOS33		Low side of 100M TX H-bridge.
										Connect a 115 ohm resistor from tx_n_b to TX_N input of magnetics
 */
module TragicLaserPHY(
	//Clocks
	input wire			clk_25mhz,		//MII clock (must be phase aligned to 125 MHz core clock)
	input wire			clk_125mhz,		//125 MHz data clock
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

	input wire			rx_n_signal_hi,
	input wire			rx_n_vref_hi,
	input wire			rx_n_signal_lo,
	input wire			rx_n_vref_lo,

    //MII interface
    output wire			mii_tx_clk,
    input wire			mii_tx_en,
    input wire			mii_tx_er,
    input wire[3:0]		mii_txd,

	//Debug GPIOs
    inout wire[9:0]		gpio
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX-side clock generation

	//TODO: BUFGMUX or something?
	assign			mii_tx_clk	= clk_25mhz;

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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// 4x input oversampling

	wire[3:0]	rx_p_hi_arr;
	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("NETWORKING")
	) rx_p_hi_serdes (
		.CLK0(clk_500mhz_bufpll),
		.CLKDIV(clk_125mhz),
		.CE0(1'b1),
		.BITSLIP(1'b0),
		.D(rx_p_hi),
		.RST(1'b0),
		.IOCE(serdes_strobe),
		.Q1(rx_p_hi_arr[3]),
		.Q2(rx_p_hi_arr[2]),
		.Q3(rx_p_hi_arr[1]),
		.Q4(rx_p_hi_arr[0])
	);

	wire[3:0]	rx_p_lo_arr;
	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("NETWORKING")
	) rx_p_lo_serdes (
		.CLK0(clk_500mhz_bufpll),
		.CLKDIV(clk_125mhz),
		.CE0(1'b1),
		.BITSLIP(1'b0),
		.D(rx_p_lo),
		.RST(1'b0),
		.IOCE(serdes_strobe),
		.Q1(rx_p_lo_arr[3]),
		.Q2(rx_p_lo_arr[2]),
		.Q3(rx_p_lo_arr[1]),
		.Q4(rx_p_lo_arr[0])
	);

	wire[3:0]	rx_n_hi_arr;
	ISERDES2 #(
		.DATA_RATE("SDR"),
		.DATA_WIDTH(4),
		.BITSLIP_ENABLE("FALSE"),
		.SERDES_MODE("NONE"),
		.INTERFACE_TYPE("NETWORKING")
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
		.INTERFACE_TYPE("NETWORKING")
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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output buffers for 10Mbps lines

	reg[3:0]		tx_d_10m_p	= 4'h0;
	reg[3:0]		tx_t_10m_p	= 4'hf;

	reg[3:0]		tx_d_10m_n	= 4'h0;
	reg[3:0]		tx_t_10m_n	= 4'hf;

	wire			tx_p_a0_raw;
	wire			tx_p_a0_t;

	wire			tx_n_a0_raw;
	wire			tx_n_a0_t;

	assign tx_n_a[1] = 1'bz;
	assign tx_p_a[1] = 1'bz;

	OBUFT #(
		.DRIVE(2),
		.SLEW("FAST")
	) obuf_10m_p0(
		.I(tx_p_a0_raw),
		.T(tx_p_a0_t),
		.O(tx_p_a[0])
	);

	OBUFT #(
		.DRIVE(2),
		.SLEW("FAST")
	) obuf_10m_n0(
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

	reg[3:0]		tx_d_100m_p	= 4'h0;
	reg[3:0]		tx_t_100m_p	= 4'hf;

	reg[3:0]		tx_d_100m_n	= 4'h0;
	reg[3:0]		tx_t_100m_n	= 4'hf;

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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// PMA layer: drive the H-bridge outputs depending on the chosen line rate and output waveform

	localparam LINK_SPEED_10		= 0;	//also used for "link down"
	localparam LINK_SPEED_100		= 1;

	reg			link_speed			= LINK_SPEED_10;

	localparam TX_SYMBOL_N2			= 0;	//-2.5V
	localparam TX_SYMBOL_N1			= 1;	//-1V
	localparam TX_SYMBOL_0			= 2;	// 0V
	localparam TX_SYMBOL_1			= 3;	//+1V
	localparam TX_SYMBOL_2			= 4;	//+2.5V

	//localparam TX_SYMBOL_WEAK_N2	= 5;	//-2.5V, weak drive
	//localparam TX_SYMBOL_WEAK_2		= 6;	//+2.5V, weak drive

	reg[2:0]	tx_symbol			= TX_SYMBOL_0;

	reg[2:0]	tx_symbol_ff		= TX_SYMBOL_0;

	always @(posedge clk_125mhz) begin

		//Tristate all drivers by default
		tx_t_100m_p			<= 4'b1111;
		tx_t_100m_n			<= 4'b1111;

		tx_t_10m_p			<= 4'b1111;
		tx_t_10m_n			<= 4'b1111;

		tx_symbol_ff		<= tx_symbol;

		case(tx_symbol)

			//10baseT -2.5V
			TX_SYMBOL_N2: begin
				//tx_p_a		<= 2'b00;
				//tx_n_a		<= 2'b11;
			end

			//100baseTX -1V
			TX_SYMBOL_N1: begin
				tx_t_100m_p		<= 4'b0000;
				tx_t_100m_n		<= 4'b0000;

				tx_d_100m_p		<= 4'b0000;
				tx_d_100m_n		<= 4'b1111;
			end

			//100baseTX 0 or 10baseT differential idle - leave all drivers tristated
			TX_SYMBOL_0: begin

				//If we're coming from a 100baseTX -1 state, drive +1 briefly
				if(tx_symbol_ff == TX_SYMBOL_N1) begin
					tx_t_10m_p		<= 4'b1110;
					tx_t_10m_n		<= 4'b1110;

					tx_d_10m_p		<= 4'b1111;
					tx_d_10m_n		<= 4'b0000;
				end

				//If we're coming from a 100baseTX +1 state, drive -1 briefly
				else if(tx_symbol_ff == TX_SYMBOL_1) begin
					tx_t_10m_p		<= 4'b1110;
					tx_t_10m_n		<= 4'b1110;

					tx_d_10m_p		<= 4'b0000;
					tx_d_10m_n		<= 4'b1111;
				end

			end

			//100baseTX 1V
			TX_SYMBOL_1: begin

				tx_t_100m_p		<= 4'b0000;
				tx_t_100m_n		<= 4'b0000;

				tx_d_100m_p		<= 4'b1111;
				tx_d_100m_n		<= 4'b0000;

				//tx_p_b		<= 1'b1;
				//tx_n_b		<= 1'b0;
			end

			//10baseT +2.5V
			TX_SYMBOL_2: begin
				//tx_p_a		<= 2'b11;
				//tx_n_a		<= 2'b00;
			end

			/*
			//Weak -2.5V (pre-emphasis for 100base-TX -1V)
			TX_SYMBOL_WEAK_N2: begin
				tx_p_a		<= 2'bz0;
				tx_n_a		<= 2'bz1;
			end

			//Weak 2.5V (pre-emphasis for 100base-TX +1V)
			TX_SYMBOL_WEAK_2: begin
				tx_p_a		<= 2'bz1;
				tx_n_a		<= 2'bz0;
			end
			*/

		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sync from MII clock to TX clock domain

	reg		tx_toggle 		= 0;
	reg		tx_toggle_ff 	= 0;
	wire	tx_mii_sync		= (tx_toggle != tx_toggle_ff);

	always @(posedge mii_tx_clk) begin
		tx_toggle			<= !tx_toggle;
	end
	always @(posedge clk_125mhz) begin
		tx_toggle_ff		<= tx_toggle;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX 4B/5B coder

	localparam TX_CTL_IDLE	= 0;
	localparam TX_CTL_SSD_J	= 1;
	localparam TX_CTL_SSD_K	= 2;
	localparam TX_CTL_END_T = 3;
	localparam TX_CTL_END_R = 4;
	localparam TX_CTL_ERR_H = 5;

	reg			tx_ctl_char = 1;
	reg[3:0]	tx_4b_code = TX_CTL_IDLE;

	reg[4:0] tx_5b_code;

	always @(*) begin

		if(tx_ctl_char) begin

			case(tx_4b_code)
				TX_CTL_IDLE:	tx_5b_code <= 5'b11111;
				TX_CTL_SSD_J:	tx_5b_code <= 5'b11000;
				TX_CTL_SSD_K:	tx_5b_code <= 5'b10001;
				TX_CTL_END_T:	tx_5b_code <= 5'b01101;
				TX_CTL_END_R:	tx_5b_code <= 5'b00111;
				TX_CTL_ERR_H:	tx_5b_code <= 5'b00100;

				//send idles for unknown/invalid control chars
				default:		tx_5b_code <= 5'b11111;
			endcase

		end

		else begin
			case(tx_4b_code)
				0:	tx_5b_code <= 5'b11110;
				1:	tx_5b_code <= 5'b01001;
				2:  tx_5b_code <= 5'b10100;
				3:	tx_5b_code <= 5'b10101;
				4:	tx_5b_code <= 5'b01010;
				5:	tx_5b_code <= 5'b01011;
				6:	tx_5b_code <= 5'b01110;
				7:	tx_5b_code <= 5'b01111;
				8:	tx_5b_code <= 5'b10010;
				9:	tx_5b_code <= 5'b10011;
				10: tx_5b_code <= 5'b10110;
				11: tx_5b_code <= 5'b10111;
				12: tx_5b_code <= 5'b11010;
				13: tx_5b_code <= 5'b11011;
				14: tx_5b_code <= 5'b11100;
				15: tx_5b_code <= 5'b11101;
			endcase
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX serial bitstream generator

	reg[2:0] tx_4b_bitcount = 0;
	reg[4:0] tx_5b_code_ff	= 0;
	reg tx_unscrambled_bit	= 0;

	always @(posedge clk_125mhz) begin

		//Sync to the MII clock and update when it does
		if(tx_mii_sync) begin
			tx_4b_bitcount			<= 1;
			tx_unscrambled_bit		<= tx_5b_code[4];
			tx_5b_code_ff			<= tx_5b_code;
		end

		//Nope, push out the next bit (send L-R)
		else begin
			tx_4b_bitcount				<= tx_4b_bitcount + 1'h1;
			case(tx_4b_bitcount)
				0:	tx_unscrambled_bit	<= tx_5b_code_ff[4];
				1:	tx_unscrambled_bit	<= tx_5b_code_ff[3];
				2:	tx_unscrambled_bit	<= tx_5b_code_ff[2];
				3:	tx_unscrambled_bit	<= tx_5b_code_ff[1];
				default: begin
					tx_unscrambled_bit	<= tx_5b_code_ff[0];
					tx_4b_bitcount		<= 0;
				end
			endcase
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX scrambler

	reg			tx_mlt3_din		= 0;

	reg[10:0]	tx_lfsr = 1;

	always @(posedge clk_125mhz) begin
		tx_lfsr		<= { tx_lfsr[9:0], tx_lfsr[8] ^ tx_lfsr[10] };

		tx_mlt3_din	<= tx_lfsr[0] ^ tx_unscrambled_bit;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX MLT-3 coder

	reg[1:0]	tx_mlt3_state	= 0;
	always @(posedge clk_125mhz) begin

		//Only proceed if din is 1
		if(tx_mlt3_din) begin
			tx_mlt3_state	<= tx_mlt3_state + 1'h1;
		end

	end

	//do this combinatorially to save a cycle of latency
	always @(*) begin
		case(tx_mlt3_state)
			0:	tx_symbol	<= TX_SYMBOL_0;
			1:	tx_symbol	<= TX_SYMBOL_N1;
			2:	tx_symbol	<= TX_SYMBOL_0;
			3:	tx_symbol	<= TX_SYMBOL_1;
		endcase
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX MII interface

	reg			mii_tx_en_ff		= 0;
	reg			frame_active		= 0;
	reg[3:0]	mii_txd_ff			= 0;

	always @(posedge mii_tx_clk) begin

		mii_tx_en_ff			<= mii_tx_en;
		mii_txd_ff				<= mii_txd;

		//Sending a frame
		if(frame_active) begin

			//Default to sending payload data
			tx_ctl_char			<= 0;
			tx_4b_code			<= mii_txd_ff;

			//If we just sent the first half of the SSD, send the second half
			if( tx_ctl_char && (tx_4b_code == TX_CTL_SSD_J) ) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_SSD_K;
			end

			//When mii_tx_en goes low, send the first half of the end-of-stream delimiter
			if(!mii_tx_en && mii_tx_en_ff) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_END_T;
				frame_active	<= 0;
			end

			//If an error occurs, send an error character
			if(mii_tx_er) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_ERR_H;
				frame_active	<= 0;
			end

		end

		//Not sending a frame
		else begin

			//Default to sending idles
			tx_ctl_char			<= 1;
			tx_4b_code			<= TX_CTL_IDLE;

			//When mii_tx_en goes high, send the first half of the start-of-stream delimiter
			if(mii_tx_en && !mii_tx_en_ff) begin
				frame_active	<= 1;
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_SSD_J;
			end

			//If we just sent the first half of the ESD, send the second half
			if( tx_ctl_char && (tx_4b_code == TX_CTL_END_T) ) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_END_R;
			end

		end

	end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Compute the RX MLT-3 state

	//leftmost bits are first chronologically
	reg[15:0]	rx_p_state;
	reg[15:0]	rx_n_state;

	integer i;
	always @(*) begin

		for(i=0; i<4; i=i+1) begin
			if(rx_p_hi_arr[i] && rx_p_lo_arr[i])
				rx_p_state[i*4 +: 4]	<= 3;
			else if(rx_p_lo_arr[i])
				rx_p_state[i*4 +: 4]	<= 2;
			else
				rx_p_state[i*4 +: 4]	<= 1;

			if(rx_n_hi_arr[i] && rx_n_lo_arr[i])
				rx_n_state[i*4 +: 4]	<= 3;
			else if(rx_n_lo_arr[i])
				rx_n_state[i*4 +: 4]	<= 2;
			else
				rx_n_state[i*4 +: 4]	<= 1;
		end

	end

	//debug: tx side too
	reg[1:0] tx_p_state;
	reg[1:0] tx_n_state;
	always @(*) begin

		//tristate
		if(tx_t_100m_p[3])
			tx_p_state	<= 2;

		//high
		else if(tx_d_100m_p[3])
			tx_p_state	<= 3;

		//low
		else
			tx_p_state	<= 1;

		//tristate
		if(tx_t_100m_n[3])
			tx_n_state	<= 2;

		//high
		else if(tx_d_100m_n[3])
			tx_n_state	<= 1;

		//low
		else
			tx_n_state	<= 3;

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Find MLT-3 state transitions

	//Bitslip for debug to phase align us to the outgoing signal
	reg[15:0]	rx_p_state_ff;
	wire[15:0]	rx_p_state_bitslip = { rx_p_state_ff[7:0], rx_p_state[15:8] };
	always @(posedge clk_125mhz) begin
		rx_p_state_ff	<= rx_p_state;
	end

	//TODO: examine the actual state ordering (-1 to +1 should never happen)
	//TODO: sanity checking by using both _P and _N legs of the RX

	reg[1:0]	last_mlt3_state	= 0;

	//Find changes
	reg[3:0]	mlt3_state_changes = 0;
	always @(*) begin
		mlt3_state_changes[3]	<= (last_mlt3_state   != rx_p_state_bitslip[15:12]);
		mlt3_state_changes[2]	<= (rx_p_state_bitslip[15:12] != rx_p_state_bitslip[11:8]);
		mlt3_state_changes[1]	<= (rx_p_state_bitslip[11:8]  != rx_p_state_bitslip[7:4]);
		mlt3_state_changes[0]	<= (rx_p_state_bitslip[7:4]   != rx_p_state_bitslip[3:0]);
	end

	always @(posedge clk_125mhz) begin
		last_mlt3_state	<= rx_p_state_bitslip[1:0];
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// We have state transitions, now convert this to a stream of bits

	reg[1:0]	rx_bits					= 0;
	reg[1:0]	rx_bits_valid			= 0;
	reg[7:0]	time_since_last_edge 	= 0;	//in sub-clocks

	always @(posedge clk_125mhz) begin

		//Loop over the edge list and process potential edges
		//May be 1 or 2 due to eye narrowing etc, but should never be >2
		rx_bits_valid	= 0;
		rx_bits			= 0;
		for(i = 0; i < 4; i = i+1) begin

			//If we had an edge, make a note of that.
			if(mlt3_state_changes[3-i]) begin
				time_since_last_edge	= 0;
				rx_bits					= {rx_bits[0], 1'b1};
				rx_bits_valid			= rx_bits_valid + 1'h1;
			end

			//Nope, increment timer
			else begin
				time_since_last_edge	= time_since_last_edge + 1'h1;

				//If last edge was >= 5 cycles ago, emit a "0" bit
				if(time_since_last_edge >= 5) begin
					rx_bits					= {rx_bits[0], 1'b0};
					rx_bits_valid			= rx_bits_valid + 1'h1;
					time_since_last_edge	= time_since_last_edge - 8'h4;	//round to 1 clock
				end

			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// We have an irregular stream of bits, turn this back into 5-bit scrambled code groups

	reg[2:0]	rx_5b_buf_valid			= 0;
	reg[5:0]	rx_5b_buf				= 0;

	reg			rx_5b_valid				= 0;
	reg[4:0]	rx_5b_code				= 0;

	always @(posedge clk_125mhz) begin

		rx_5b_valid			<= 0;

		//Push new stuff in
		if(rx_bits_valid == 1) begin
			rx_5b_buf		= {rx_5b_buf[4:0], rx_bits[0]};
			rx_5b_buf_valid	= rx_5b_buf_valid + 1'h1;
		end

		else if(rx_bits_valid == 2) begin
			rx_5b_buf		= {rx_5b_buf[3:0], rx_bits[1:0]};
			rx_5b_buf_valid	= rx_5b_buf_valid + 2'h2;
		end

		//Pop words out once we have five valid bits
		if(rx_5b_buf_valid == 5) begin
			rx_5b_code		<= rx_5b_buf[4:0];
			rx_5b_valid		<= 1;
			rx_5b_buf_valid	= 0;
			rx_5b_buf		= 0;
		end
		else if(rx_5b_buf_valid == 6) begin
			rx_5b_code		<= rx_5b_buf[5:1];
			rx_5b_valid		<= 1;
			rx_5b_buf_valid	= 1;
			rx_5b_buf[5:1]	= 0;
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RX LFSR

	reg[10:0]	rx_lfsr = 1;

	reg[4:0]	rx_lfsr_dout;

	reg			rx_lfsr_synced		= 0;
	reg[3:0]	rx_lfsr_wordcount	= 0;

	reg[10:0]	rx_last_11_bits		= 0;
	reg[15:0]	rx_last_16_bits		= 0;

	always @(posedge clk_125mhz) begin

		if(rx_5b_valid) begin

			//FIFO of the last 11 bits to come off the wire
			rx_last_11_bits			<= {rx_last_11_bits[5:0], rx_5b_code[4:0]};

			//FIFO of the last 16 bits to come off the wire (DEBUG ONLY)
			rx_last_16_bits			<= {rx_last_16_bits[10:0], rx_5b_code[4:0]};

			//Every time we get a new data word shift the LFSR by 5 bits and save them as we go.
			//First bit on the wire is [4]
			for(i=0; i<5; i=i+1) begin
				rx_lfsr_dout[4-i]	= rx_lfsr[0];
				rx_lfsr				= { rx_lfsr[9:0], rx_lfsr[8] ^ rx_lfsr[10] };
			end

			//If we are NOT synced, try using the complement of the last few words as the LFSR sequence.
			if(!rx_lfsr_synced) begin

				rx_lfsr_wordcount		<= rx_lfsr_wordcount + 1'h1;

				//Every 16th message word (80 bits) re-sync if we didn't lock.
				//(16, 11, and 5 are relatively prime so we should align eventually)
				if(rx_lfsr_wordcount == 0)
					rx_lfsr				= ~rx_last_11_bits;

			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Debug GPIOs

	reg[1:0]	tx_p_state_ff  = 0;
	reg[1:0]	tx_p_state_ff1 = 0;
	reg[1:0]	tx_p_state_ff2 = 0;
	reg[1:0]	tx_p_state_ff3 = 0;
	reg[1:0]	tx_p_state_ff4 = 0;

	reg			tx_mlt3_din_ff	= 0;
	reg			tx_mlt3_din_ff2	= 0;
	reg			tx_mlt3_din_ff3	= 0;
	reg			tx_mlt3_din_ff4	= 0;
	reg			tx_mlt3_din_ff5	= 0;
	reg			tx_mlt3_din_ff6	= 0;
	reg			tx_mlt3_din_ff7	= 0;
	reg			tx_mlt3_din_ff8	= 0;
	reg			tx_mlt3_din_ff9	= 0;

	always @(posedge clk_125mhz) begin
		tx_p_state_ff	<= tx_p_state;
		tx_p_state_ff2	<= tx_p_state_ff;
		tx_p_state_ff3	<= tx_p_state_ff2;
		tx_p_state_ff4	<= tx_p_state_ff3;

		tx_mlt3_din_ff	<= tx_mlt3_din;
		tx_mlt3_din_ff2	<= tx_mlt3_din_ff;
		tx_mlt3_din_ff3	<= tx_mlt3_din_ff2;
		tx_mlt3_din_ff4	<= tx_mlt3_din_ff3;
		tx_mlt3_din_ff5	<= tx_mlt3_din_ff4;
		tx_mlt3_din_ff6	<= tx_mlt3_din_ff5;
		tx_mlt3_din_ff7	<= tx_mlt3_din_ff6;
		tx_mlt3_din_ff8	<= tx_mlt3_din_ff7;
		tx_mlt3_din_ff9	<= tx_mlt3_din_ff8;
	end

	wire	la_ready;
	wire	trig_out;
	wire	capture_done;

	/*
		0	tx_unscrambled_bit
		1	tx_mlt3_din
		2	tx_mlt3_state				tx_symbol					tx_mlt3_din_ff
		3	tx_d_100m_p					tx_p_state					tx_mlt3_din_ff2
		4	tx_p_state_ff											tx_mlt3_din_ff3
		5	tx_p_state_ff2											tx_mlt3_din_ff4
		6	tx_p_state_ff3											tx_mlt3_din_ff5
		7	tx_p_state_ff4				rx_p_state_bitslip			tx_mlt3_din_ff6
		8	rx_bits
		9	rx_5b_buf					rx_5b_buf_valid
		10	rx_5b_code					rx_5b_valid
	 */

	RedTinUartWrapper #(
		.WIDTH(128),
		.DEPTH(1024),
		.UART_CLKDIV(16'd1085),	//115200 @ 125 MHz
		.USE_EXT_TRIG(0),
		.SYMBOL_ROM(
			{
				16384'h0,
				"DEBUGROM", 				8'h0, 8'h01, 8'h00,
				32'd8000,		//period of internal clock, in ps
				32'd1024,		//Capture depth (TODO auto-patch this?)
				32'd128,		//Capture width (TODO auto-patch this?)
				{ "tx_mlt3_din",		8'h0, 8'h1,  8'h0 },
				{ "tx_mlt3_din_ff6",	8'h0, 8'h1,  8'h0 },
				{ "tx_p_state_ff4",		8'h0, 8'h2,  8'h0 },
				{ "rx_p_state_bitslip",	8'h0, 8'h10,  8'h0 },
				{ "mlt3_state_changes",	8'h0, 8'h4,  8'h0 },
				{ "rx_bits",			8'h0, 8'h2,  8'h0 },
				{ "rx_bits_valid",		8'h0, 8'h2,  8'h0 },
				{ "time_since_last_edge",	8'h0, 8'h8,  8'h0 },
				{ "rx_5b_buf_valid",	8'h0, 8'h3,  8'h0 },
				{ "rx_5b_buf",			8'h0, 8'h6,  8'h0 },
				{ "rx_5b_valid",		8'h0, 8'h1,  8'h0 },
				{ "rx_5b_code",			8'h0, 8'h5,  8'h0 },
				{ "~rx_5b_code",		8'h0, 8'h5,  8'h0 },
				{ "rx_lfsr_dout",		8'h0, 8'h5,  8'h0 },
				{ "rx_lfsr_synced",		8'h0, 8'h1,  8'h0 },
				{ "rx_lfsr_wordcount",  8'h0, 8'h4,  8'h0 },
				{ "rx_last_11_bits", 	8'h0, 8'hb,  8'h0 },
				{ "rx_last_16_bits", 	8'h0, 8'h10,  8'h0 }
			}
		)
	) analyzer (
		.clk(clk_125mhz),
		.capture_clk(clk_125mhz),
		.din({
				tx_mlt3_din,		//1
				tx_mlt3_din_ff6,	//1
				tx_p_state_ff4,		//2
				rx_p_state_bitslip,	//16
				mlt3_state_changes,	//4
				rx_bits,			//2
				rx_bits_valid,		//2
				time_since_last_edge,	//8
				rx_5b_buf_valid,	//3
				rx_5b_buf,			//6
				rx_5b_valid,		//1
				rx_5b_code,			//5
				~rx_5b_code,		//5
				rx_lfsr_dout,		//5
				rx_lfsr_synced,		//1
				rx_lfsr_wordcount,	//4
				rx_last_11_bits,	//11
				rx_last_16_bits,	//16

				35'h0				//padding
			}),
		.uart_rx(gpio[9]),
		.uart_tx(gpio[7]),
		.la_ready(la_ready),
		.ext_trig(1'b0),
		.trig_out(trig_out),
		.capture_done(capture_done)
	);

	assign gpio[8] = 0;
	assign gpio[6:3] = 0;

	DDROutputBuffer #(.WIDTH(1))
		ddrbuf(.clk_p(clk_125mhz), .clk_n(!clk_125mhz), .dout(gpio[1]), .din0(1'b0), .din1(1'b1));

	assign gpio[0] = la_ready;			//d0
	assign gpio[2] = capture_done;		//d3

endmodule
