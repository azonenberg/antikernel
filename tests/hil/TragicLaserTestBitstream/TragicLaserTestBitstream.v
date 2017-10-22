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

    output reg			tx_p_b = 1'bz,
    output reg[1:0]		tx_p_a = 2'bz,
    output reg			tx_n_b = 1'bz,
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
	wire		clk_125mhz_raw;

	PLL_BASE #(
		.CLKIN_PERIOD(10.0),						//100 MHz input
		.DIVCLK_DIVIDE(1),							//Divide to get 100 MHz at the PFD
		.CLKFBOUT_MULT(10),							//Multiply by 10 for 1 GHz VCO
		.CLKFBOUT_PHASE(0.0),
		.CLKOUT0_DIVIDE(8),							//125 MHz Ethernet clock
		.CLKOUT1_DIVIDE(4),							//250 MHz oversampling clock (TODO)
		.CLKOUT2_DIVIDE(8),
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
		.CLKOUT0(clk_125mhz_raw),
		.CLKOUT1(),
		.CLKOUT2(),
		.CLKOUT3(),
		.CLKOUT4(),
		.CLKOUT5(),
		.LOCKED(),
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

	reg[2:0]	tx_symbol			= TX_SYMBOL_N2; //TX_SYMBOL_0;

	always @(posedge clk_125mhz_bufg) begin

		//Tristate all drivers by default
		tx_p_a				<= 2'bzz;
		tx_p_b				<= 1'bz;
		tx_n_a				<= 2'bzz;
		tx_n_b				<= 1'bz;

		case(tx_symbol)

			//10baseT -2.5V
			TX_SYMBOL_N2: begin
				tx_p_a		<= 2'b00;
				tx_n_a		<= 2'b11;
			end

			//100baseTX -1V
			TX_SYMBOL_N1: begin
				tx_p_b		<= 1'b0;
				tx_n_b		<= 1'b1;
			end

			//100baseT 0 or 10baseT differential idle - leave all drivers tristated
			TX_SYMBOL_0: begin
			end

			//100baseTX 1V
			TX_SYMBOL_1: begin
				tx_p_b		<= 1'b1;
				tx_n_b		<= 1'b0;
			end

			//10baseT +2.5V
			TX_SYMBOL_2: begin
				tx_p_a		<= 2'b11;
				tx_n_a		<= 2'b00;
			end

		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX 4B/5B coder

	/*
	reg[3:0] tx_4b_code = 0;
	reg[4:0] tx_5b_code;
	always @(*) begin
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
	*/

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX serial bitstream generator
	/*
	reg[2:0] count = 0;
	reg txbit = 0;
	always @(posedge clk_125mhz_bufg) begin
		count	<= count + 1'h1;
		case(count)
			0:	txbit <= tx_5b_code[0];
			1:	txbit <= tx_5b_code[1];
			2:	txbit <= tx_5b_code[2];
			3:	txbit <= tx_5b_code[3];
			default: begin
				txbit <= tx_5b_code[4];
				code <= code + 1'h1;
				count <= 0;
			end
		endcase
	end
	*/

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TODO: TX scrambler

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX MLT-3 coder

	reg			tx_mlt3_din		= 0;

	reg[1:0]	tx_mlt3_state	= 0;
	always @(posedge clk_125mhz_bufg) begin

		//Only proceed if din is 1
		if(tx_mlt3_din)
			tx_mlt3_state	<= tx_mlt3_state + 1'h1;

		case(tx_mlt3_state)
			0:	tx_symbol	<= TX_SYMBOL_0;
			1:	tx_symbol	<= TX_SYMBOL_N1;
			2:	tx_symbol	<= TX_SYMBOL_0;
			3:	tx_symbol	<= TX_SYMBOL_1;
		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PRBS generator

    reg[6:0]	prbs_shreg		= 1;

    wire[6:0]	prbs_shreg_next = { prbs_shreg[5:0], prbs_shreg[6] ^ prbs_shreg[5] };
    //wire[6:0]	prbs_shreg_next2 = { prbs_shreg_next[5:0], prbs_shreg_next[6] ^ prbs_shreg_next[5] };

    always @(posedge clk_125mhz_bufg) begin
		prbs_shreg	<= prbs_shreg_next;

		tx_mlt3_din	<= prbs_shreg[0];
    end

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

	assign gpio[8]		= 1'b0;				//unused for now
	assign gpio[7:3]	= 5'h0;
	assign gpio[2:0]	= tx_symbol;

endmodule
