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
										[0] should be 2 mA drive, slow slew (pre-emphasis)
										[1] should be 24 mA drive, fast slew (main driver)

		tx_n_a[1:0]		LVCMOS33		Low side of 10M/autonegotiation TX H-bridge.
										Connect both bits together for increase drive current.
										Connect a 16 ohm resistor from tx_n_a to TX_N input of magnetics
										[0] should be 2 mA drive, slow slew (pre-emphasis)
										[1] should be 24 mA drive, fast slew (main driver)

		tx_p_b			LVCMOS33		High side of 100M TX H-bridge.
						24 mA / fast	Connect a 115 ohm resistor from tx_p_b to TX_P input of magnetics


		tx_n_b			LVCMOS33		Low side of 100M TX H-bridge.
						24 mA / fast	Connect a 115 ohm resistor from tx_n_b to TX_N input of magnetics
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

	//Optional negative side RX interface (not currently implemented)
	/*
	input wire			rx_n_signal_hi,
	input wire			rx_n_vref_hi,
	input wire			rx_n_signal_lo,
	input wire			rx_n_vref_lo,
	*/

    //MII interface
    output wire			mii_tx_clk,
    input wire			mii_tx_en,
    input wire			mii_tx_er,
    input wire[3:0]		mii_txd,

    output wire			mii_rx_clk,		//always same as mii_tx_clk for this PHY to simplify clocking
    output reg[3:0]		mii_rxd	= 0,
    output reg			mii_rx_dv	= 0,
    output reg			mii_rx_er	= 0,

	//Debug GPIOs
    inout wire[9:0]		gpio
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX-side clock generation

	//TODO: BUFGMUX or something?
	assign			mii_tx_clk	= clk_25mhz;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O buffers

	reg[3:0]		tx_d_100m_p	= 4'h0;
	reg[3:0]		tx_t_100m_p	= 4'hf;

	reg[3:0]		tx_d_100m_n	= 4'h0;
	reg[3:0]		tx_t_100m_n	= 4'hf;

	reg[3:0]		tx_d_10m_p	= 4'h0;
	reg[3:0]		tx_t_10m_p	= 4'hf;

	reg[3:0]		tx_d_10m_n	= 4'h0;
	reg[3:0]		tx_t_10m_n	= 4'hf;

	wire[3:0]		rx_p_hi_arr;
	wire[3:0]		rx_p_lo_arr;

	TragicLaserPHY_iobufs iobufs(
		.clk_125mhz(clk_125mhz),
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

		.tx_d_100m_p(tx_d_100m_p),
		.tx_t_100m_p(tx_t_100m_p),
		.tx_d_100m_n(tx_d_100m_n),
		.tx_t_100m_n(tx_t_100m_n),

		.tx_d_10m_p(tx_d_10m_p),
		.tx_t_10m_p(tx_t_10m_p),
		.tx_d_10m_n(tx_d_10m_n),
		.tx_t_10m_n(tx_t_10m_n),

		.rx_p_hi_arr(rx_p_hi_arr),
		.rx_p_lo_arr(rx_p_lo_arr)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// PMA layer: drive the H-bridge outputs depending on the chosen line rate and output waveform

	localparam LINK_SPEED_DOWN		= 0;	//autonegotiation etc
	localparam LINK_SPEED_10		= 1;
	localparam LINK_SPEED_100		= 2;

	reg[1:0]	link_speed			= LINK_SPEED_100;

	localparam TX_SYMBOL_N2			= 0;	//-2.5V
	localparam TX_SYMBOL_N1			= 1;	//-1V
	localparam TX_SYMBOL_0			= 2;	// 0V
	localparam TX_SYMBOL_1			= 3;	//+1V
	localparam TX_SYMBOL_2			= 4;	//+2.5V

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

	localparam CTL_IDLE		= 0;
	localparam CTL_SSD_J	= 1;
	localparam CTL_SSD_K	= 2;
	localparam CTL_END_T 	= 3;
	localparam CTL_END_R 	= 4;
	localparam CTL_ERR_H 	= 5;

	reg			tx_ctl_char = 1;
	reg[3:0]	tx_4b_code = CTL_IDLE;

	reg[4:0] tx_5b_code;

	always @(*) begin

		if(tx_ctl_char) begin

			case(tx_4b_code)
				CTL_IDLE:	tx_5b_code <= 5'b11111;
				CTL_SSD_J:	tx_5b_code <= 5'b11000;
				CTL_SSD_K:	tx_5b_code <= 5'b10001;
				CTL_END_T:	tx_5b_code <= 5'b01101;
				CTL_END_R:	tx_5b_code <= 5'b00111;
				CTL_ERR_H:	tx_5b_code <= 5'b00100;

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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// TX symbol generation

	//Do this combinatorially to save a cycle of latency
	always @(*) begin

		//Default: nothing happening
		tx_symbol		<= TX_SYMBOL_0;

		case(link_speed)

			LINK_SPEED_DOWN: begin
			end

			//10Base-T not implemented
			LINK_SPEED_10: begin
			end

			//100Base-TX
			LINK_SPEED_100: begin
				case(tx_mlt3_state)
					0:	tx_symbol	<= TX_SYMBOL_0;
					1:	tx_symbol	<= TX_SYMBOL_N1;
					2:	tx_symbol	<= TX_SYMBOL_0;
					3:	tx_symbol	<= TX_SYMBOL_1;
				endcase
			end

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
			if( tx_ctl_char && (tx_4b_code == CTL_SSD_J) ) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= CTL_SSD_K;
			end

			//When mii_tx_en goes low, send the first half of the end-of-stream delimiter
			if(!mii_tx_en && mii_tx_en_ff) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= CTL_END_T;
				frame_active	<= 0;
			end

			//If an error occurs, send an error character
			if(mii_tx_er) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= CTL_ERR_H;
				frame_active	<= 0;
			end

		end

		//Not sending a frame
		else begin

			//Default to sending idles
			tx_ctl_char			<= 1;
			tx_4b_code			<= CTL_IDLE;

			//When mii_tx_en goes high, send the first half of the start-of-stream delimiter
			if(mii_tx_en && !mii_tx_en_ff) begin
				frame_active	<= 1;
				tx_ctl_char		<= 1;
				tx_4b_code		<= CTL_SSD_J;
			end

			//If we just sent the first half of the ESD, send the second half
			if( tx_ctl_char && (tx_4b_code == CTL_END_T) ) begin
				tx_ctl_char		<= 1;
				tx_4b_code		<= CTL_END_R;
			end

		end

	end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RX MLT-3 decoder: find state transitions

	//leftmost bits are first chronologically
	reg[15:0]	rx_p_state;
	//reg[15:0]	rx_n_state;

	integer i;
	always @(*) begin

		for(i=0; i<4; i=i+1) begin
			if(rx_p_hi_arr[i] && rx_p_lo_arr[i])
				rx_p_state[i*4 +: 4]	<= 3;
			else if(rx_p_lo_arr[i])
				rx_p_state[i*4 +: 4]	<= 2;
			else
				rx_p_state[i*4 +: 4]	<= 1;
			/*
			if(rx_n_hi_arr[i] && rx_n_lo_arr[i])
				rx_n_state[i*4 +: 4]	<= 3;
			else if(rx_n_lo_arr[i])
				rx_n_state[i*4 +: 4]	<= 2;
			else
				rx_n_state[i*4 +: 4]	<= 1;
			*/
		end

	end

	//TODO: examine the actual state ordering (-1 to +1 should never happen)
	//TODO: sanity checking by using both _P and _N legs of the RX

	reg[1:0]	last_mlt3_state	= 0;

	//Find changes
	reg[3:0]	mlt3_state_changes = 0;
	always @(*) begin
		mlt3_state_changes[3]	<= (last_mlt3_state   != rx_p_state[15:12]);
		mlt3_state_changes[2]	<= (rx_p_state[15:12] != rx_p_state[11:8]);
		mlt3_state_changes[1]	<= (rx_p_state[11:8]  != rx_p_state[7:4]);
		mlt3_state_changes[0]	<= (rx_p_state[7:4]   != rx_p_state[3:0]);
	end

	always @(posedge clk_125mhz) begin
		last_mlt3_state	<= rx_p_state[1:0];
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RX MLT-3 decoder: We have state transitions, now convert this to a stream of bits

	reg[1:0]	rx_bits					= 0;
	reg[1:0]	rx_bits_valid			= 0;
	reg[7:0]	time_since_last_edge 	= 0;	//in sub-clocks

	always @(posedge clk_125mhz) begin

		//Loop over the edge list and process potential edges
		//May be 1 or 2 edges per clock due to eye narrowing etc, but should never be >2
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
	// RX deserializer

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
	// RX descrambler

	reg[10:0]	rx_lfsr = 1;

	//Request by the 4b/5b coder to re-synchronize
	reg			rx_resync			= 0;

	reg			rx_lfsr_synced		= 0;
	reg[4:0]	rx_lfsr_wordcount	= 0;

	reg[10:0]	rx_last_11_bits		= 0;

	//Number of consecutive idle characters we've seen
	reg[3:0]	rx_idle_runlen		= 0;

	//Time since we had a run of 9 idles
	reg[15:0]	rx_last_lock		= 0;

	//Unscramble the incoming data. Still not word aligned yet.
	reg[4:0]	rx_5b_code_ff		= 0;
	reg			rx_5b_valid_ff		= 0;
	wire[4:0]	rx_5b_code_unscrambled	= rx_5b_code_ff ^ rx_lfsr[4:0];
	wire		rx_5b_valid_unscrambled = rx_5b_valid_ff;
	always @(posedge clk_125mhz) begin
		rx_5b_valid_ff	<= rx_5b_valid;
		if(rx_5b_valid)
			rx_5b_code_ff	<= rx_5b_code;
	end

	//Advance the LFSR and check for lock
	always @(posedge clk_125mhz) begin

		if(rx_5b_valid) begin

			//Check for idle characters (0x1f descrambled).
			if(rx_5b_code_unscrambled == 5'h1f)
				rx_idle_runlen		<= rx_idle_runlen + 1'h1;
			else begin
				rx_last_lock		<= rx_last_lock + 1'h1;
				rx_idle_runlen		<= 0;
			end

			//FIFO of the last 11 bits to come off the wire
			rx_last_11_bits			<= {rx_last_11_bits[5:0], rx_5b_code[4:0]};

			//Every time we get a new data word shift the LFSR by 5 bits
			for(i=0; i<5; i=i+1)
				rx_lfsr				= { rx_lfsr[9:0], rx_lfsr[8] ^ rx_lfsr[10] };

			//9 idles in a row (45 bits)? We're locked to the LFSR
			//This is enough to allow lock if we tried locking at the start of a minimum IPG.
			if(rx_idle_runlen == 4'h9) begin
				rx_lfsr_synced	<= 1;
				rx_last_lock	<= 0;
			end

			//Four MTUs passed without an IPG? Definitely lost lock!
			//Also unlock if the 4b/5b decoder saw too many errors
			if( (rx_last_lock > 16'd12000) || rx_resync )begin
				rx_lfsr_synced			<= 0;
				rx_lfsr_wordcount		<= 0;
			end

			//If we are NOT synced, try using the complement of the last few words as the LFSR sequence.
			if(!rx_lfsr_synced) begin

				//Update count
				rx_lfsr_wordcount		<= rx_lfsr_wordcount + 1'h1;

				//Every 32ndth message word (160 bits), try re-syncing if we're not locked yet
				//(32, 11, and 5 are relatively prime so we should align eventually)
				if(rx_lfsr_wordcount == 0) begin
					rx_idle_runlen		<= 0;
					rx_last_lock		<= 0;

					//Load the old code value
					rx_lfsr				= ~rx_last_11_bits;

					//Iterate 5 times to calculate the state as of the next 5-bit block
					for(i=0; i<5; i=i+1)
						rx_lfsr			= { rx_lfsr[9:0], rx_lfsr[8] ^ rx_lfsr[10] };

				end

			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RX codeword alignment

	//Keep a sliding window of the last 15 unscrambled bits
	reg[14:0]	rx_last_15_unscrambled	= 0;
	always @(posedge clk_125mhz) begin
		if(rx_5b_valid_unscrambled)
			rx_last_15_unscrambled	<= {rx_last_15_unscrambled[9:0], rx_5b_code_unscrambled};
	end

	//Search the sliding window for the J-K sequence (start of stream) and update our sync when we see it
	reg			rx_stream_synced		= 0;
	reg[2:0]	rx_stream_phase			= 0;
	localparam RX_SSD_JK = 10'b1100010001;

	always @(posedge clk_125mhz) begin

		if(rx_5b_valid_unscrambled) begin

			//If we lose LFSR sync, we've also lost the stream sync
			if(!rx_lfsr_synced)
				rx_stream_synced			<= 0;

			//If not synced, attempt to resync
			if(!rx_stream_synced) begin
				for(i=0; i<5; i=i+1) begin
					if(rx_last_15_unscrambled[i +: 10] == RX_SSD_JK) begin
						rx_stream_synced		<= 1;
						rx_stream_phase			<= i[2:0];
					end
				end
			end

		end

	end

	//Get the unscrambled, aligned 5-bit code groups
	wire[4:0]	rx_5b_code_aligned		= rx_last_15_unscrambled[rx_stream_phase +: 5];

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RX 4b/5b decoder

	reg			rx_4b_invalid		= 0;
	reg			rx_4b_ctl			= 0;
	wire		rx_4b_code_valid	= rx_5b_valid_unscrambled;
	reg[3:0]	rx_4b_code			= 0;

	always @(*) begin

		//Default to valid non-control char
		rx_4b_ctl					<= 0;
		rx_4b_invalid				<= 0;

		case(rx_5b_code_aligned)

			//Control characters
			5'b11111: begin
				rx_4b_ctl				<= 1;
				rx_4b_code				<= CTL_IDLE;
			end
			5'b11000: begin
				rx_4b_ctl				<= 1;
				rx_4b_code				<= CTL_SSD_J;
			end
			5'b10001: begin
				rx_4b_ctl				<= 1;
				rx_4b_code				<= CTL_SSD_K;
			end
			5'b01101: begin
				rx_4b_ctl				<= 1;
				rx_4b_code				<= CTL_END_T;
			end
			5'b00111: begin
				rx_4b_ctl				<= 1;
				rx_4b_code				<= CTL_END_R;
			end
			5'b00100: begin
				rx_4b_ctl				<= 1;
				rx_4b_code				<= CTL_ERR_H;
			end

			//Data characters
			5'b11110:	rx_4b_code		<= 4'h0;
			5'b01001:	rx_4b_code		<= 4'h1;
			5'b10100:	rx_4b_code		<= 4'h2;
			5'b10101:	rx_4b_code		<= 4'h3;
			5'b01010:	rx_4b_code		<= 4'h4;
			5'b01011:	rx_4b_code		<= 4'h5;
			5'b01110:	rx_4b_code		<= 4'h6;
			5'b01111:	rx_4b_code		<= 4'h7;
			5'b10010:	rx_4b_code		<= 4'h8;
			5'b10011:	rx_4b_code		<= 4'h9;
			5'b10110:	rx_4b_code		<= 4'ha;
			5'b10111:	rx_4b_code		<= 4'hb;
			5'b11010:	rx_4b_code		<= 4'hc;
			5'b11011:	rx_4b_code		<= 4'hd;
			5'b11100:	rx_4b_code		<= 4'he;
			5'b11101:	rx_4b_code		<= 4'hf;

			//Bad codeword!
			default: begin
				rx_4b_invalid			<= 1;
				rx_4b_code				<= 0;
			end

		endcase

	end

	//Keep track of how many invalid characters we're seeing, re-sync the receiver if we see too many
	reg[7:0]	num_invalid_chars		= 0;
	reg[7:0]	valid_count				= 0;

	always @(posedge clk_125mhz) begin
		valid_count					<= valid_count + 1'h1;
		rx_resync					<= 0;

		if(rx_4b_code_valid && rx_4b_invalid)
			num_invalid_chars		<= num_invalid_chars + 1'h1;

		if(valid_count == 0) begin
			num_invalid_chars		<= 0;

			//16 invalid chars in 256? Something is way wrong, reset the link
			//TODO: decide thresholds
			if(num_invalid_chars > 'd16)
				rx_resync			<= 1;

		end
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RX elastic buffer and MII interface

	//Use the same divided clock for the RX
	assign				mii_rx_clk		= mii_tx_clk;

	reg					rx_fifo_wr		= 0;
	reg[4:0]			rx_fifo_wr_data	= 0;
	reg					rx_fifo_rd		= 0;
	wire[4:0]			rx_fifo_rd_data;
	wire[5:0]			rx_fifo_rsize;
	wire[5:0]			rx_fifo_wsize;
	wire				rx_fifo_empty;

	//FIFO of incoming data nibbles (pushed at the line rate)
	//Bit 4 is the "control character" bit
	SingleClockFifo #(
		.WIDTH(5),
		.DEPTH(32),
		.USE_BLOCK(0),
		.OUT_REG(0)
	) rx_elastic_fifo (
		.clk(clk_125mhz),

		.wr(rx_fifo_wr),
		.din(rx_fifo_wr_data),

		.rd(rx_fifo_rd),
		.dout(rx_fifo_rd_data),

		.rsize(rx_fifo_rsize),
		.wsize(rx_fifo_wsize),

		.empty(rx_fifo_empty),
		.full(),
		.underflow(),
		.overflow(),

		.reset(rx_resync || !rx_stream_synced || !rx_lfsr_synced)	//Reset the FIFO any time we lose lock
	);

	//Push data into the FIFO
	always @(*) begin

		//Default to not pushing
		rx_fifo_wr		<= 0;
		rx_fifo_wr_data	<= 0;

		if(rx_4b_code_valid) begin

			//If we get an invalid character, ignore it for now
			//TODO: push to tx_er
			if(rx_4b_invalid) begin
			end

			//Don't push idle characters into the FIFO, we'll generate idle states on our own as needed
			else if(rx_4b_ctl && (rx_4b_code == CTL_IDLE) ) begin
			end

			//It's a normal data/ctl character, push it
			else begin
				rx_fifo_wr		<= 1;
				rx_fifo_wr_data	<= {rx_4b_ctl, rx_4b_code};
			end

		end

	end

	//Pop data from the FIFO and feed it to the MII
	reg		starting_next_cycle	= 0;
	always @(posedge clk_125mhz) begin
		rx_fifo_rd			<= 0;

		//If the FIFO has less than 16 nibbles in it, and a frame isn't already in progress, let it fill up a bit more.
		//If we have plenty of data in the fifo, or we're already doing stuff, crunch the current word then pop it.
		if(tx_mii_sync && (mii_rx_dv || (rx_fifo_rsize > 16)) ) begin

			mii_rxd			<= 0;
			mii_rx_er			<= 0;
			starting_next_cycle	<= 0;

			//If FIFO is empty, we underran it. Send an error.
			//This shouldn't be possible unless the TX clock is WAY high.
			if(rx_fifo_empty) begin
				mii_rx_er		<= 1;
				mii_rx_dv		<= 0;
			end

			else begin

				//Control character
				if(rx_fifo_rd_data[4]) begin

					case(rx_fifo_rd_data[3:0])

						//J: first half of start-of-stream: ignore
						CTL_SSD_J: begin
						end

						//K: second half of start-of-stream, start the packet next cycle
						CTL_SSD_K:	starting_next_cycle	<= 1;

						//T: end of stream
						CTL_END_T:	mii_rx_dv			<= 0;

						//R: second half of end-of-stream, ignore
						CTL_END_R: begin
						end

						//H: Error, then drop the packet
						CTL_ERR_H: begin
							mii_rx_er					<= 1;
							mii_rx_dv					<= 0;
						end

						//Bad code: error, then drop the packet
						//(should not make it into the fifo but just in case...)
						default: begin
							mii_rx_er					<= 1;
							mii_rx_dv					<= 0;
						end

					endcase

				end

				//Data character. Ignore if we're not currently in a packet
				else if(mii_rx_dv || starting_next_cycle) begin
					mii_rx_dv		<= 1;
					mii_rxd		<= rx_fifo_rd_data[3:0];
				end

				//Advance the FIFO
				rx_fifo_rd			<= 1;
			end

		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Debug GPIOs

	wire	la_ready;
	wire	trig_out;
	wire	capture_done;

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
				{ "mii_tx_en", 					8'h0, 8'h1,  8'h0 },
				{ "mii_tx_er", 					8'h0, 8'h1,  8'h0 },
				{ "mii_txd", 					8'h0, 8'h4,  8'h0 },
				{ "rx_lfsr_synced", 			8'h0, 8'h1,  8'h0 },
				{ "rx_stream_synced", 			8'h0, 8'h1,  8'h0 },
				{ "rx_fifo_wr", 				8'h0, 8'h1,  8'h0 },
				{ "starting_next_cycle", 		8'h0, 8'h1,  8'h0 },
				{ "mii_rx_dv",					8'h0, 8'h1,  8'h0 },
				{ "mii_rx_er",					8'h0, 8'h1,  8'h0 },
				{ "mii_rxd",					8'h0, 8'h4,  8'h0 }
			}
		)
	) analyzer (
		.clk(clk_125mhz),
		.capture_clk(clk_125mhz),
		.din({
				mii_tx_en,					//1
				mii_tx_er,					//1
				mii_txd,					//4
				rx_lfsr_synced,				//1
				rx_stream_synced,			//1
				rx_fifo_wr,					//1
				starting_next_cycle,		//1
				mii_rx_dv,					//1
				mii_rx_er,					//1
				mii_rxd,					//4

				112'h0						//padding
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
