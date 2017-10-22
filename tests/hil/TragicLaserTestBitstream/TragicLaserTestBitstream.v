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
    output reg[1:0]		tx_p_a = 2'bz,
    output wire			tx_n_b,
    output reg[1:0]		tx_n_a = 2'bz
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
	// Output SERDES for 100Mbps lines

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

	localparam USE_OSERDES = 0;

	generate

		if(!USE_OSERDES) begin
			assign tx_n_b_raw = tx_d_100m_n[3];
			assign tx_n_b_t = tx_t_100m_n[3];

			assign tx_p_b_raw = tx_d_100m_p[3];
			assign tx_p_b_t = tx_t_100m_p[3];
		end

		else begin
			OSERDES2 #(
				.DATA_RATE_OQ("SDR"),
				.DATA_RATE_OT("SDR"),
				.DATA_WIDTH(4),
				.OUTPUT_MODE("SINGLE_ENDED"),
				.SERDES_MODE("MASTER"),
				.TRAIN_PATTERN(16'h0)
			) serdes_100m_p (
				.CLKDIV(clk_125mhz_bufg),
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
				.CLKDIV(clk_125mhz_bufg),
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
		end
	endgenerate

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

	always @(posedge clk_125mhz_bufg) begin

		//Tristate all drivers by default
		tx_p_a				<= 2'bzz;
		tx_n_a				<= 2'bzz;

		tx_t_100m_p			<= 4'b1111;
		tx_t_100m_n			<= 4'b1111;

		tx_symbol_ff		<= tx_symbol;

		case(tx_symbol)

			//10baseT -2.5V
			TX_SYMBOL_N2: begin
				tx_p_a		<= 2'b00;
				tx_n_a		<= 2'b11;
			end

			//100baseTX -1V
			TX_SYMBOL_N1: begin
				tx_t_100m_p		<= 4'b0000;
				tx_t_100m_n		<= 4'b0000;

				tx_d_100m_p		<= 4'b0000;
				tx_d_100m_n		<= 4'b1111;

				//tx_p_b		<= 1'b0;
				//tx_n_b		<= 1'b1;
			end

			//100baseTX 0 or 10baseT differential idle - leave all drivers tristated
			TX_SYMBOL_0: begin

				/*
				//If we're coming from a 100baseTX -1 state, drive +1 briefly
				if(tx_symbol_ff == TX_SYMBOL_N1) begin
					tx_t_100m_p		<= 4'b1110;
					tx_t_100m_n		<= 4'b1110;

					tx_d_100m_p		<= 4'b1111;
					tx_d_100m_n		<= 4'b0000;
				end

				//If we're coming from a 100baseTX +1 state, drive -1 briefly
				else if(tx_symbol_ff == TX_SYMBOL_1) begin
					tx_t_100m_p		<= 4'b1110;
					tx_t_100m_n		<= 4'b1110;

					tx_d_100m_p		<= 4'b0000;
					tx_d_100m_n		<= 4'b1111;
				end
				*/

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
				tx_p_a		<= 2'b11;
				tx_n_a		<= 2'b00;
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

	always @(posedge clk_25mhz_bufg) begin
		tx_toggle			<= !tx_toggle;
	end
	always @(posedge clk_125mhz_bufg) begin
		tx_toggle_ff		<= tx_toggle;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX 4B/5B coder

	localparam TX_CTL_IDLE	= 0;
	localparam TX_CTL_SSD_J	= 1;
	localparam TX_CTL_SSD_K	= 2;
	localparam TX_CTL_END_T = 3;
	localparam TX_CTL_END_R = 4;

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

	always @(posedge clk_125mhz_bufg) begin

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

	always @(posedge clk_125mhz_bufg) begin
		tx_lfsr		<= { tx_lfsr[9:0], tx_lfsr[8] ^ tx_lfsr[10] };

		tx_mlt3_din	<= tx_lfsr[0] ^ tx_unscrambled_bit;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX MLT-3 coder

	reg[1:0]	tx_mlt3_state	= 0;
	always @(posedge clk_125mhz_bufg) begin

		//Only proceed if din is 1
		if(tx_mlt3_din) begin
			tx_mlt3_state	<= tx_mlt3_state + 1'h1;
		end

		case(tx_mlt3_state)
			0:	tx_symbol	<= TX_SYMBOL_0;
			1:	tx_symbol	<= TX_SYMBOL_N1;
			2:	tx_symbol	<= TX_SYMBOL_0;
			3:	tx_symbol	<= TX_SYMBOL_1;
		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MII bus

    reg[7:0]	mcount	= 0;
    reg[7:0]	mstate = 0;
    reg			framestart = 0;

    always @(posedge clk_25mhz_bufg) begin

		tx_ctl_char			<= 1;
		tx_4b_code			<= TX_CTL_IDLE;
		framestart			<= 0;

		case(mstate)

			//Wait, then SSD
			0: begin
				mcount		<= mcount + 1'h1;
				if(mcount == 255) begin
					framestart	<= 1;
					tx_ctl_char	<= 1;
					tx_4b_code	<= TX_CTL_SSD_J;
					mstate		<= 1;
				end
			end

			1: begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_SSD_K;
				mstate			<= 2;
				mcount			<= 0;
			end

			//Preamble
			2: begin
				tx_ctl_char		<= 0;
				tx_4b_code		<= 4'h5;
				mcount			<= mcount + 1'h1;
				if(mcount == 7) begin
					tx_ctl_char	<= 0;
					tx_4b_code	<= 4'hd;
					mstate		<= 3;
					mcount		<= 0;
				end
			end

			//64 dummy bytes
			3: begin
				tx_ctl_char		<= 0;
				tx_4b_code		<= 4'hc;
				mcount			<= mcount + 1'h1;

				if(mcount == 63) begin
					mstate		<= 4;
				end
			end

			//Done
			4: begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_END_T;
				mstate			<= 5;
			end

			5: begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= TX_CTL_END_R;
				mstate			<= 0;
				mcount			<= 0;
			end

		endcase
    end

	/*
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PRBS generator

    reg[6:0]	prbs_shreg		= 1;

    wire[6:0]	prbs_shreg_next = { prbs_shreg[5:0], prbs_shreg[6] ^ prbs_shreg[5] };
    //wire[6:0]	prbs_shreg_next2 = { prbs_shreg_next[5:0], prbs_shreg_next[6] ^ prbs_shreg_next[5] };

    always @(posedge clk_125mhz_bufg) begin
		prbs_shreg	<= prbs_shreg_next;

		tx_mlt3_din	<= prbs_shreg[0];
    end
    */
    //1100010001 0110100111111111111111

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GPIOs

	//Output clock for the LA
	DDROutputBuffer #(
		.WIDTH(1)
	) clkoutbuf(
		.clk_p(clk_125mhz_bufg),
		.clk_n(!clk_125mhz_bufg),
		.dout(gpio[9]),
		.din0(1'b0),
		.din1(1'b1)
	);

	//MII clock
	DDROutputBuffer #(
		.WIDTH(1)
	) clkoutbuf2(
		.clk_p(clk_25mhz_bufg),
		.clk_n(!clk_25mhz_bufg),
		.dout(gpio[7]),
		.din0(1'b0),
		.din1(1'b1)
	);

	assign gpio[8]		= 1'b0;				//unused for now
	assign gpio[6]		= tx_mii_sync;
	assign gpio[5]		= tx_unscrambled_bit;

	assign gpio[4]		= 0;
	assign gpio[3]		= framestart;

	assign gpio[2:0]	= tx_4b_bitcount;

endmodule
