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

module TragicLaserPHY_PMA(

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

	//The symbol being sent
	input wire[2:0]		tx_symbol,

	//Incoming data
	output wire[3:0]	rx_p_hi_arr,
	output wire[3:0]	rx_p_lo_arr
);

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

	reg				tx_d_10m_p_full = 0;
	reg				tx_t_10m_p_full = 1;

	reg				tx_d_10m_n_full	= 0;
	reg				tx_t_10m_n_full	= 1;

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

		.tx_d_10m_p_full(tx_d_10m_p_full),
		.tx_t_10m_p_full(tx_t_10m_p_full),

		.tx_d_10m_n_full(tx_d_10m_n_full),
		.tx_t_10m_n_full(tx_t_10m_n_full),

		.rx_p_hi_arr(rx_p_hi_arr),
		.rx_p_lo_arr(rx_p_lo_arr)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// PMA layer: drive the H-bridge outputs depending on the chosen line rate and output waveform

	`include "TragicLaserPHY_symbols.vh"

	reg[2:0]	tx_symbol_ff		= TX_SYMBOL_0;

	always @(posedge clk_125mhz) begin

		//Tristate all drivers by default
		tx_t_100m_p			<= 4'b1111;
		tx_t_100m_n			<= 4'b1111;

		tx_t_10m_p			<= 4'b1111;
		tx_t_10m_n			<= 4'b1111;

		tx_t_10m_p_full 	<= 1;
		tx_t_10m_n_full 	<= 1;

		tx_symbol_ff		<= tx_symbol;

		case(tx_symbol)

			//10baseT -2.5V
			TX_SYMBOL_N2: begin
				tx_d_10m_p_full		<= 0;
				tx_d_10m_n_full		<= 1;

				tx_t_10m_p_full		<= 0;
				tx_t_10m_n_full		<= 0;
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

			end

			//10baseT +2.5V
			TX_SYMBOL_2: begin
				tx_d_10m_p_full		<= 1;
				tx_d_10m_n_full		<= 0;

				tx_t_10m_p_full		<= 0;
				tx_t_10m_n_full		<= 0;
			end

		endcase

	end

endmodule
