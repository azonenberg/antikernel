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

    output wire[1:0] 	led,
    inout wire[9:0] 	gpio,

    output wire			tx_p_b,
    output wire[1:0]	tx_p_a,
    output wire			tx_n_b,
    output wire[1:0]	tx_n_a,

    input wire			rx_p_signal_hi,
	input wire			rx_p_vref_hi,
	input wire			rx_p_signal_lo,
	input wire			rx_p_vref_lo//,

	/*
	input wire			rx_n_signal_hi,
	input wire			rx_n_vref_hi,
	input wire			rx_n_signal_lo,
	input wire			rx_n_vref_lo
	*/
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
    wire		mii_tx_er 	= 0;
    reg[3:0]	mii_txd		= 0;

    wire		mii_rx_clk;
    wire		mii_rx_er;
    wire		mii_rx_dv;
    wire[3:0]	mii_rxd;

    reg[7:0]	mstate = 0;

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

		/*
		.rx_n_signal_hi(rx_n_signal_hi),
		.rx_n_vref_hi(rx_n_vref_hi),
		.rx_n_signal_lo(rx_n_signal_lo),
		.rx_n_vref_lo(rx_n_vref_lo),
		*/

		.mii_tx_clk(mii_tx_clk),
		.mii_tx_en(mii_tx_en),
		.mii_tx_er(mii_tx_er),
		.mii_txd(mii_txd),

		.mii_rx_clk(mii_rx_clk),
		.mii_rx_er(mii_rx_er),
		.mii_rx_dv(mii_rx_dv),
		.mii_rxd(mii_rxd),

		.led(led),
		.gpio(gpio),
		.mstate(mstate)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CRC calculation

	/*
    reg			mii_tx_en_adv	= 0;
    reg[3:0]	mii_txd_adv		= 0;

    reg			crc_reset		= 0;
    reg			crc_update		= 0;
    reg[7:0]	crc_din			= 8'hff;
    wire[31:0]	crc_dout;

	CRC32_Ethernet crc(
		.clk(mii_tx_clk),
		.reset(crc_reset),
		.update(crc_update),
		.din(crc_din),
		.crc_flipped(crc_dout)
	);

	reg[3:0]	frame_state		= 0;

	always @(posedge mii_tx_clk) begin

		case(frame_state)

			0: begin
				mii_tx_en	<= 0;
				mii_txd		<= 0;

				if(mii_tx_en_adv) begin
					mii_tx_en	<= 1;
					mii_txd		<= mii_txd_adv;
					if(mii_txd_adv == 4'hd)		//done with preamble
						frame_state	<= 1;
				end
			end

			1: begin

				//Default to pushing more frame data
				if(mii_tx_en_adv) begin
					mii_tx_en	<= 1;
					mii_txd		<= mii_txd_adv;
				end

				//Push first CRC word
				else begin
					mii_tx_en	<= 1;
					mii_txd		<= crc_dout[31:28];
					frame_state	<= 2;
				end

			end

			2: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[27:24];
				frame_state	<= 3;
			end

			3: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[23:20];
				frame_state	<= 4;
			end

			4: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[19:16];
				frame_state	<= 5;
			end

			5: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[15:12];
				frame_state	<= 6;
			end

			6: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[11:8];
				frame_state	<= 7;
			end

			7: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[7:4];
				frame_state	<= 8;
			end

			8: begin
				mii_tx_en	<= 1;
				mii_txd		<= crc_dout[3:0];
				frame_state	<= 0;
			end

		endcase

	end
	*/

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // MII bus

    reg[15:0]	mcount	= 0;

    reg[7:0]	packet_data[255:0];
    initial begin
		packet_data[0]	<= 8'hff;		//Dest MAC
		packet_data[1]	<= 8'hff;
		packet_data[2]	<= 8'hff;
		packet_data[3]	<= 8'hff;
		packet_data[4]	<= 8'hff;
		packet_data[5]	<= 8'hff;

		packet_data[6]	<= 8'hcc;		//Src MAC
		packet_data[7]	<= 8'hcc;
		packet_data[8]	<= 8'hcc;
		packet_data[9]	<= 8'hcc;
		packet_data[10]	<= 8'hcc;
		packet_data[11]	<= 8'hcc;

		packet_data[12]	<= 8'h08;		//IPv4
		packet_data[13]	<= 8'h00;

		packet_data[14]	<= 8'h45;		//IPv4, min header size
		packet_data[15]	<= 8'h00;		//no diffserv, no ECN
		packet_data[16]	<= 8'h00;		//length
		packet_data[17]	<= 8'h40;		//44 bytes payload, 20 bytes header = 64 total

		packet_data[18]	<= 8'h00;		//ID
		packet_data[19]	<= 8'h00;
		packet_data[20] <= 8'h40;		//Dont fragment, high fragoff
		packet_data[21]	<= 8'h00;		//low fragoff

		packet_data[22]	<= 8'hff;		//TTL
		packet_data[23]	<= 8'h11;		//UDP
		packet_data[24]	<= 8'hcc;		//Header checksum FIXME
		packet_data[25]	<= 8'hcc;

		packet_data[26]	<= 8'h00;		//Source IP
		packet_data[27]	<= 8'h00;
		packet_data[28]	<= 8'h00;
		packet_data[29]	<= 8'h00;

		packet_data[30]	<= 8'hff;		//Dest IP
		packet_data[31]	<= 8'hff;
		packet_data[32]	<= 8'hff;
		packet_data[33]	<= 8'hff;

		packet_data[34]	<= 8'h01;		//Source port
		packet_data[35]	<= 8'h00;
		packet_data[36]	<= 8'h01;		//Dest port
		packet_data[37]	<= 8'h00;

		packet_data[38]	<= 8'h00;		//44 bytes (36 of payload)
		packet_data[39] <= 8'h2c;
		packet_data[40]	<= 8'h00;		//Checksum (not set)
		packet_data[41]	<= 8'h00;

		packet_data[42]	<= 8'h00;		//Packet body
		packet_data[43]	<= 8'h00;
		packet_data[44]	<= 8'h00;
		packet_data[45]	<= 8'h00;

		packet_data[46]	<= 8'h00;
		packet_data[47]	<= 8'h00;
		packet_data[48]	<= 8'h00;
		packet_data[49]	<= 8'h00;

		packet_data[50]	<= 8'h00;
		packet_data[51]	<= 8'h00;
		packet_data[52]	<= 8'h00;
		packet_data[53]	<= 8'h00;

		packet_data[54]	<= 8'h00;
		packet_data[55]	<= 8'h00;
		packet_data[56]	<= 8'h00;
		packet_data[57]	<= 8'h00;

		packet_data[58]	<= 8'h00;
		packet_data[59]	<= 8'h00;
		packet_data[60]	<= 8'h00;
		packet_data[61]	<= 8'h00;

		packet_data[62]	<= 8'h00;
		packet_data[63]	<= 8'h00;
		packet_data[64]	<= 8'h00;
		packet_data[65]	<= 8'h00;

		packet_data[66]	<= 8'h00;
		packet_data[67]	<= 8'h00;
		packet_data[68]	<= 8'h00;
		packet_data[69]	<= 8'h00;

		packet_data[70]	<= 8'h00;
		packet_data[71]	<= 8'h00;
		packet_data[72]	<= 8'h00;
		packet_data[73]	<= 8'h00;

		packet_data[74]	<= 8'h00;
		packet_data[75]	<= 8'h00;
		packet_data[76]	<= 8'h00;
		packet_data[77]	<= 8'h00;

		packet_data[78]	<= 8'h21;		//CRC
		packet_data[79]	<= 8'hf4;
		packet_data[80]	<= 8'had;
		packet_data[81]	<= 8'hec;

    end

    always @(posedge mii_tx_clk) begin

		//crc_reset			<= 0;
		//crc_update			<= 0;

		mii_tx_en		<= 0;
		mii_txd			<= 0;

		case(mstate)

			//Wait, then start the frame
			0: begin
				mcount		<= mcount + 1'h1;
				//if(mcount == 65535) begin
				if(mcount == 1024) begin
					mcount			<= 0;
					mii_tx_en		<= 1;
					mstate			<= 1;
					//crc_reset		<= 1;
				end
			end

			//Preamble
			1: begin
				mii_tx_en			<= 1;
				mii_txd				<= 4'h5;
				mcount				<= mcount + 1'h1;
				if(mcount == 15) begin
					mii_txd			<= 4'hd;
					mstate			<= 2;
					mcount			<= 0;
				end
			end

			//Send a single hard-coded packet
			2: begin
				mii_tx_en			<= 1;
				mii_txd				<= packet_data[mcount][3:0];
				mstate				<= 3;

				//Done!
				if(mcount == 82) begin
					mii_tx_en		<= 0;
					mii_txd			<= 0;
					mcount			<= 0;
					mstate			<= 0;
				end
			end

			3: begin
				mii_tx_en			<= 1;
				mii_txd				<= packet_data[mcount][7:4];
				mstate				<= 2;

				mcount				<= mcount + 1'h1;

			end

		endcase
    end

endmodule
