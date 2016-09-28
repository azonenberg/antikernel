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
	@brief A single transceiver channel
	
	Legal TARGET_INTERFACE values:
	
		Interface	Data rate	Data width	Line code	FPGA family		Reference clock frequency
		1000BASEX	1000 Mbps	16			8b10b		XILINX_ARTIX7	125 MHz
		
	To initialize, bring startup_reset high for one clk_reset cycle and wait for serdes_ready to go high.
	
	Transmit and receive data buses are synchronous to the rising edges of clk_fabric_bufg.
 */
module TransceiverChannel(
	startup_reset, quad_reset, serdes_ready,
	clk_reset,
	pll_clk, pll_refclk, pll_lock,
	serdes_tx_p, serdes_tx_n,
	serdes_rx_p, serdes_rx_n,
	serdes_tx_data, serdes_tx_kchars, serdes_tx_forcedisp_en, serdes_tx_forcedisp,
	serdes_rx_data, serdes_rx_data_valid, serdes_rx_kchars, serdes_rx_commas,
	clk_fabric_bufg
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	input wire			startup_reset;
	output reg			quad_reset			= 0;
	output reg			serdes_ready		= 0;
	
	input wire			clk_reset;
	
	input wire[1:0]		pll_clk;
	input wire[1:0]		pll_refclk;
	input wire[1:0]		pll_lock;
	
	output wire			serdes_tx_p;
	output wire			serdes_tx_n;
	
	input wire			serdes_rx_p;
	input wire			serdes_rx_n;
	
	input wire[15:0]	serdes_tx_data;
	input wire[1:0]		serdes_tx_kchars;
	input wire[1:0]		serdes_tx_forcedisp_en;
	input wire[1:0]		serdes_tx_forcedisp;
	
	output wire[1:0]	serdes_rx_data_valid;
	output wire[15:0]	serdes_rx_data;
	output wire[1:0]	serdes_rx_kchars;
	output wire[1:0]	serdes_rx_commas;
	
	output wire			clk_fabric_bufg;
		
	parameter TARGET_INTERFACE = "INVALID";
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pull in chip-specific configuration tables
	
	`include "TransceiverChannel_config_artix7.vh";
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceiver block
	
	//Buffer the transceiver clock as needed
	wire		clk_fabric;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) bufg_tx_clk (
		.clkin(clk_fabric),
		.clkout(clk_fabric_bufg),
		.ce(1'b1)
	);
	
	`ifdef XILINX_ARTIX7
	
		localparam TXPMARESET_TIME		= artix7_gtp_tx_pmareset_time(TARGET_INTERFACE);
		localparam TXPCSRESET_TIME		= artix7_gtp_tx_pcsreset_time(TARGET_INTERFACE);
		localparam RXPMARESET_TIME		= artix7_gtp_rx_pmareset_time(TARGET_INTERFACE);
		localparam RXOSCALRESET_TIME	= artix7_gtp_rx_oscalreset_time(TARGET_INTERFACE);
		localparam RXOSCALRESET_TIMEOUT	= artix7_gtp_rx_oscalreset_timeout(TARGET_INTERFACE);
		localparam RXCDRPHRESET_TIME	= artix7_gtp_rx_cdr_phreset_time(TARGET_INTERFACE);
		localparam RXCDRFREQRESET_TIME	= artix7_gtp_rx_cdr_freqreset_time(TARGET_INTERFACE);
		localparam CFOK_CFG				= artix7_gtp_cfok_cfg(TARGET_INTERFACE);
		
		localparam LOOPBACK_CFG			= artix7_gtp_loopback_cfg(TARGET_INTERFACE);
		localparam PMA_LOOPBACK_CFG		= artix7_gtp_pma_loopback_cfg(TARGET_INTERFACE);

		localparam DATA_WIDTH			= artix7_gtp_data_width(TARGET_INTERFACE);
		localparam OUT_DIV				= artix7_gtp_out_div(TARGET_INTERFACE);
		
		reg			gtp_tx_reset	= 0;
		reg			user_ready		= 0;
		wire		gtp_tx_rsdone;
		wire		gtp_tx_pmarsdone;
		
		reg			gtp_rx_reset	= 0;
		wire		gtp_rx_rsdone;
		wire		gtp_rx_pmarsdone;
		
		reg[8:0]	gtp_drp_addr	= 0;
		reg			gtp_drp_en		= 0;
		reg[15:0]	gtp_drp_wdata	= 0;
		wire		gtp_drp_ready;
		wire[15:0]	gtp_drp_rdata;
		reg			gtp_drp_we		= 0;
		
		wire[14:0]	gtp_monbus;
		
		wire[1:0]	gtp_tx_bufstat;
		
		wire		gtp_rx_align;
		wire		gtp_rx_realign;
		wire		gtp_rx_comma;
		wire[1:0]	gtp_rx_disperr;
		wire[1:0]	gtp_rx_notintbl;
		wire[2:0]	gtp_rx_bufstat;
		
		wire[32:0]	gtp_rx_unused;	//unused flags

		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// SERDES unit
		
		GTPE2_CHANNEL #(
		
			//Reset counters
			//All values undocumented, use settings from transceiver wizard.
			//These probably don't change from protocol to protocol, but put in table just in case
			.TXPCSRESET_TIME(TXPCSRESET_TIME),
			.TXPMARESET_TIME(TXPMARESET_TIME),
			.RXCDRPHRESET_TIME(RXCDRPHRESET_TIME),
			.RXOSCALRESET_TIME(RXOSCALRESET_TIME),
			.RXOSCALRESET_TIMEOUT(RXOSCALRESET_TIMEOUT),
			.RXPMARESET_TIME(RXPMARESET_TIME),
			.RXCDRFREQRESET_TIME(RXCDRFREQRESET_TIME),
			
			//TODO: Make these parameterizable
			.RXLPMRESET_TIME(7'b0001111),
			.RXISCANRESET_TIME(5'b00001),
			.RXPCSRESET_TIME(5'b00001),
			.RXBUFRESET_TIME(5'b00001),
			
			//General transceiver settings
			.TX_DATA_WIDTH(DATA_WIDTH),
			.RX_DATA_WIDTH(DATA_WIDTH),
			.TXOUT_DIV(OUT_DIV),
			.RXOUT_DIV(OUT_DIV),
			
			//Transmit de-emphasis configuration
			.TX_DEEMPH0(5'b10100),				//magic value from UG482
			.TX_DEEMPH1(5'b01101),				//magic value from UG482
			
			//Transmit buffer configuration
			.TXBUF_RESET_ON_RATE_CHANGE("TRUE"),//reset buffer when we change rates
			
			//Loopback configuration
			.LOOPBACK_CFG(LOOPBACK_CFG),
			.PMA_LOOPBACK_CFG(PMA_LOOPBACK_CFG),
			
			//8b/10b coding block
			
			//64b/6xb gearbox
			//TODO: Make these parameterizable
			.GEARBOX_MODE(3'b0),				//not using 64b66/67b gearbox
			.TXGEARBOX_EN("FALSE"),			//not using 64b66/67b gearbox
			
			//PCIe specific configuration
			//Unknown if these change between protocols
			.PD_TRANS_TIME_FROM_P2(12'h03c),	//reserved, use value from transceiver wizard
			.PD_TRANS_TIME_NONE_P2(8'h19),		//reserved, use value from transceiver wizard
			.PD_TRANS_TIME_TO_P2(8'h64),		//reserved, use value from transceiver wizard
			.TRANS_TIME_RATE(8'h0E),			//reserved, use value from transceiver wizard
			
			//SAS/SATA specific configuration
			//Unknown if these change between protocols
			.RXOOB_CFG(7'b0000110),				//magic value from transceiver wizard
			.RXOOB_CLK_CFG("PMA"),				//magic value from transceiver wizard
			.SATA_PLL_CFG("VCO_3000MHZ"),		//magic value from transceiver wizard
			.SATA_BURST_SEQ_LEN(4'b1111),		//length of SATA COM sequence
			.SATA_BURST_VAL(3'b100),			//number of bursts to declare COM match
			.SATA_EIDLE_VAL(3'b100),			//number of idles to declare COM match
			.SATA_MIN_INIT(12),					//lower bound on idle count during COMSAS
			.SATA_MIN_WAKE(4),					//lower bound on idle count during COMINIT/COMRESET
			.SATA_MAX_BURST(8),					//upper bound on activity burst for COM FSM
			.SATA_MAX_INIT(21),					//upper bound on idle count during COMINIT/COMRESET
			.SATA_MAX_WAKE(7),					//upper bound on idle count during COMWAKE
			.SAS_MIN_COM(36),					//lower bound on SATA/SAS activity burst
			.SAS_MAX_COM(64),					//upper bound on idle count during COMSAS			
			
			//Channel bonding - not implemented for now
			.CHAN_BOND_MAX_SKEW(1),				//dont correct inter-channel skew
			.CHAN_BOND_KEEP_ALIGN("FALSE"),		//dont keep alignment
			.CHAN_BOND_SEQ_1_1(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_1_2(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_1_3(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_1_4(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_1_ENABLE(4'b1111),	//not using channel bonding
			.CHAN_BOND_SEQ_2_1(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_2_2(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_2_3(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_2_4(10'h000),		//not using channel bonding
			.CHAN_BOND_SEQ_2_ENABLE(4'b1111),	//not using channel bonding
			.CHAN_BOND_SEQ_2_USE("FALSE"),		//not using channel bonding
			.CHAN_BOND_SEQ_LEN(1),				//bond sequence is 1 byte long
			.FTS_DESKEW_SEQ_ENABLE(4'b1111),	//enable mask for deskew cfg		
			.FTS_LANE_DESKEW_CFG(4'b1111),		//magic value from transceiver wizard
			.FTS_LANE_DESKEW_EN("FALSE"),		//not using channel bonding
			.PCS_PCIE_EN("FALSE"),				//not using PCIe
			
			//Debug configuration
			.RX_DEBUG_CFG(14'h0002),			//low 5 bits select monitor target
												//5'd2 = LPMOS
												//5'd3 = LPMHF
												//5'd4 = LPMLF
												//other values reserved
			
			//PRBS configuration - not implemented for now
			.RXPRBS_ERR_LOOPBACK(1'b0),
			
			//Eye scan - not implemented for now
			.ES_VERT_OFFSET(9'b000000000),		//default eye scan offset
			.ES_HORZ_OFFSET(12'h010),			//default eye scan offset
			.ES_PRESCALE(5'h0),					//prescaler for eye scan sample count
			.ES_SDATA_MASK(80'h0),				//masks eyescan sdata
			.ES_QUALIFIER(80'h0),				//qualifier for eye scan based on data patterns
			.ES_QUAL_MASK(80'h0),				//bitmask for qualifier
			.ES_EYE_SCAN_EN(1'b0),				//disable eye scan
			.ES_ERRDET_EN(1'b0),				//enable statistical eye view
			.ES_CONTROL(6'h00),					//not using eye scan
			.ES_CLK_PHASE_SEL(1'b0),			//default phase
												
			//Unknown/reserved settings - just use whatever value the wizard emitted.
			//These don't seem to change between protocols but it never hurts to check to make sure
			//when adding a new protocol
			.RX_CLKMUX_EN(1'b1),
			.TX_CLKMUX_EN(1'b1),
			.TST_RSV(32'h00000000),				//reserved
												//bit 0 = override DDI delay with RX_DDI_SEL
			.PMA_RSV5(1'b0),					//magic value from transceiver wizard
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// TODO: Make these parameterizable
			
			.CFOK_CFG(CFOK_CFG),				//magic value from transceiver wizard
			.CFOK_CFG2(7'b0100000),				//magic value from transceiver wizard
			.CFOK_CFG3(7'b0100000),				//magic value from transceiver wizard
			
			.RXCDR_CFG(83'h0000107FE106001041010),	//magic value from UG482 table 4-15
													//for divider of 4, refclk 200ppm, 8b10b coded
			.RXCDR_LOCK_CFG(6'b001001),			//magic value from transceiver wizard
			.RXCDR_HOLD_DURING_EIDLE(1'b0),		//used for pcie, must be 0
			.RXCDR_FR_RESET_ON_EIDLE(1'b0),		//used for pcie, must be 0
			.RXCDR_PH_RESET_ON_EIDLE(1'b0),		//used for pcie, must be 0
			.RX_OS_CFG(13'b0000010000000),		//magic value from transceiver wizard
			
			.TXBUF_EN("TRUE"),					//enable transmit buffer
			.TX_XCLK_SEL("TXOUT"),				//use TXOUTCLK as XCLK
			.TXPH_CFG(16'h0780),				//magic value from transceiver wizard
			.TXPH_MONITOR_SEL(5'b00000),		//magic value from transceiver wizard
			.TXPHDLY_CFG(24'h084020),			//magic value from transceiver wizard
			.TXDLY_CFG(16'h001F),				//magic value from transceiver wizard
			.TXDLY_LCFG(9'h030),				//magic value from transceiver wizard
			.TXDLY_TAP_CFG(16'h0000),			//magic value from transceiver wizard
			.TXSYNC_MULTILANE(1'b0),			//reserved, must be 0
			.TXSYNC_SKIP_DA(1'b0),				//reserved, must be 0
			.TXSYNC_OVRD(1'b0),					//reserved, must be 0
			
			.TXPI_SYNFREQ_PPM(3'b000),			//magic value from transceiver wizard
			.TXPI_PPM_CFG(8'h00),				//magic value from transceiver wizard
			.TXPI_INVSTROBE_SEL(1'b0),			//reserved, must be 0
			.TXPI_GREY_SEL(1'b0),				//binary coded
			.TXPI_PPMCLK_SEL("TXUSRCLK2"),		//PPM config from USERCLK2			
			
			.TX_DRIVE_MODE("DIRECT"),			//direct control over driver (not using PIPE)
			.TX_MAINCURSOR_SEL(1'b0),			//auto control of main cursor
			.TX_MARGIN_FULL_0(7'b1001110),		//magic value from transceiver wizard
			.TX_MARGIN_FULL_1(7'b1001001),		//magic value from transceiver wizard
			.TX_MARGIN_FULL_2(7'b1000101),		//magic value from transceiver wizard
			.TX_MARGIN_FULL_3(7'b1000010),		//magic value from transceiver wizard
			.TX_MARGIN_FULL_4(7'b1000000),		//magic value from transceiver wizard
			.TX_MARGIN_LOW_0(7'b1000110),		//magic value from transceiver wizard
			.TX_MARGIN_LOW_1(7'b1000100),		//magic value from transceiver wizard
			.TX_MARGIN_LOW_2(7'b1000010),		//magic value from transceiver wizard
			.TX_MARGIN_LOW_3(7'b1000000),		//magic value from transceiver wizard
			.TX_MARGIN_LOW_4(7'b1000000),		//magic value from transceiver wizard
			.TX_PREDRIVER_MODE(1'b0),			//reserved, must be 0
			
			.TX_RXDETECT_CFG(14'h1832),			//magic value from transceiver wizard
			.TX_RXDETECT_REF(3'b100),			//magic value from transceiver wizard
			
			.TXOOB_CFG(1'b0),					//magic value from transceiver wizard
			.PCS_RSVD_ATTR(48'h0),				//magic value from transceiver wizard
												//bit 8 enables OoB for SATA/SAS
												
			.TERM_RCAL_CFG(15'b100001000010000),//magic value from transceiver wizard
			.TERM_RCAL_OVRD(3'b000),			//magic value from transceiver wizard
			
			//following values recommended for GbE in UG482 table 4-5
			.RX_CM_SEL(2'b11),					//programmable termination
			.RX_CM_TRIM(4'b1010),				//common mode = 800 mV
			.RXLPM_INCM_CFG(1'b1),				//enable high common mode operation
			.RXLPM_IPCM_CFG(1'b0),				//disable low common mode operation
			
			.ADAPT_CFG0(20'h00000),				//magic value from transceiver wizard
			.RXLPM_HOLD_DURING_EIDLE(1'b0),		//do not clear eq during idle
			.RXLPM_CFG(4'b0110),				//magic value from transceiver wizard
			.RXLPM_CFG1(1'b0),					//magic value from transceiver wizard
			.RXLPM_HF_CFG2(5'b01010),			//magic value from transceiver wizard
			.RXLPM_HF_CFG(14'b00001111110000),	//magic value from transceiver wizard
			.RXLPM_BIAS_STARTUP_DISABLE(1'b0),	//magic value from transceiver wizard
			.RXLPM_LF_CFG(18'b000000001111110000),	//magic value from transceiver wizard
			
			.RXBUF_RESET_ON_RATE_CHANGE("TRUE"),//reset rx buffer on rate change
			
			.ALIGN_COMMA_WORD(2),				//align comma to even words
			.ALIGN_COMMA_ENABLE(10'b0001111111),//comma bitmask for 1000base-X
			.ALIGN_COMMA_DOUBLE("FALSE"),		//align to PCOMMA or MCOMMA separately
			.ALIGN_MCOMMA_VALUE(10'b1010000011),//minus comma (K28.5)
			.ALIGN_MCOMMA_DET("TRUE"),			//detect minus commas
			.ALIGN_PCOMMA_VALUE(10'b0101111100),//plus comma (K28.5)
			.ALIGN_PCOMMA_DET("TRUE"),			//detect plus commas
			.SHOW_REALIGN_COMMA("TRUE"),		//include commas in parallel data stream
			.RXSLIDE_MODE("OFF"),				//do not use RXSLIDE
			.RXSLIDE_AUTO_WAIT(7),				//magic value from transceiver wizard
			.RX_SIG_VALID_DLY(10),				//magic value from transceiver wizard

			.USE_PCS_CLK_PHASE_SEL(1'b0),		//use deserializer phase
			
			.RX_DISPERR_SEQ_MATCH("TRUE"),		//sanity check disparity
			.DEC_MCOMMA_DETECT("TRUE"),			//detect negative commas
			.DEC_PCOMMA_DETECT("TRUE"),			//detect positive commas
			.DEC_VALID_COMMA_ONLY("FALSE"),		//detect all commas, not just 802.3 ones
			
			.RXBUF_EN("TRUE"),					//use rx elastic buffer
			.RX_XCLK_SEL("RXREC"),				//use recovered clock
			.RXPH_CFG(24'hC00002),				//magic value from transceiver wizard
			.RXPH_MONITOR_SEL(5'b00000),		//magic value from transceiver wizard
			.RXPHDLY_CFG(24'h084020),			//magic value from transceiver wizard
			.RXDLY_CFG(16'h001F),				//magic value from transceiver wizard
			.RXDLY_LCFG(9'h030),				//magic value from transceiver wizard
			.RXDLY_TAP_CFG(16'h0000),			//magic value from transceiver wizard
			.RX_DDI_SEL(6'b000000),				//magic value from transceiver wizard
			.RXSYNC_MULTILANE(1'b0),			//single lane
			.RXSYNC_SKIP_DA(1'b0),				//not using delay alignment
			.RXSYNC_OVRD(1'b0),					//not using delay alignment
			
			.RX_BUFFER_CFG(6'b000000),			//magic value from transceiver wizard
			.RX_DEFER_RESET_BUF_EN("TRUE"),		//defer reset for comma align
			.RXBUF_ADDR_MODE("FULL"),			//use full buffer mode
			.RXBUF_EIDLE_HI_CNT(4'b1000),		//magic value from transceiver wizard
			.RXBUF_EIDLE_LO_CNT(4'b0000),		//magic value from transceiver wizard
			.RXBUF_RESET_ON_CB_CHANGE("TRUE"),	//reset on channel bonding change
			.RXBUF_RESET_ON_COMMAALIGN("FALSE"),//do not reset on comma align
			.RXBUF_RESET_ON_EIDLE("FALSE"),		//do not reset on electrical idle
			.RXBUF_THRESH_OVRD("FALSE"),		//use auto threshlds
			.RXBUF_THRESH_OVFLW(61),			//magic value from transceiver wizard
			.RXBUF_THRESH_UNDFLW(8),			//magic value from transceiver wizard

			.RXGEARBOX_EN("FALSE"),				//not using rx gearbox
			
			.CBCC_DATA_SOURCE_SEL("DECODED"),	//do clock correction after 8b10b
			.CLK_CORRECT_USE("TRUE"),			//use clock correction
			.CLK_COR_KEEP_IDLE("FALSE"),		//remove as many clock correction sequences as necessary
			.CLK_COR_MAX_LAT(36),				//max buffer latency
			.CLK_COR_MIN_LAT(33),				//min buffer latency
			.CLK_COR_PRECEDENCE("TRUE"),		//Clock correction wins over channel bonding
			.CLK_COR_REPEAT_WAIT(0),			//no limit on clock correction
			.CLK_COR_SEQ_LEN(2),				//length of clock correction sequence
			.CLK_COR_SEQ_1_ENABLE(4'b1111),		//Mask enable for clock correction sequence
			.CLK_COR_SEQ_1_1(10'b0110111100),	//clock correction sequence 1
			.CLK_COR_SEQ_1_2(10'b0001010000),	//clock correction sequence 2
			.CLK_COR_SEQ_1_3(10'b0000000000),	//clock correction sequence 3
			.CLK_COR_SEQ_1_4(10'b0000000000),	//clock correction sequence 4
			.CLK_COR_SEQ_2_USE("TRUE"),			//Enable second clock correction sequence
			.CLK_COR_SEQ_2_ENABLE(4'b1111),		//Mask enable for clock correction sequence
			.CLK_COR_SEQ_2_1(10'b0110111100),	//clock correction sequence 1
			.CLK_COR_SEQ_2_2(10'b0010110101),	//clock correction sequence 2
			.CLK_COR_SEQ_2_3(10'b0000000000),	//clock correction sequence 3
			.CLK_COR_SEQ_2_4(10'b0000000000)	//clock correction sequence 4		
			
		) gtp_channel (
		
			//Top level pads
			.GTPTXP(serdes_tx_p),
			.GTPTXN(serdes_tx_n),
			
			.GTPRXP(serdes_rx_p),
			.GTPRXN(serdes_rx_n),
			
			//Clock inputs from PLL
			.RXSYSCLKSEL(2'b00),				//use PLL0
			.TXSYSCLKSEL(2'b00),				//use PLL0
			.PLL0CLK(pll_clk[0]),
			.PLL1CLK(pll_clk[1]),
			.PLL0REFCLK(pll_refclk[0]),
			.PLL1REFCLK(pll_refclk[1]),
			
			//Polarity inversion for easier PCB routing
			.TXPOLARITY(1'b0),					//not inverting tx data polarity
			.RXPOLARITY(1'b0),					//not inverting polarity
			
			//Power saving
			.TXPD(2'b0),						//not powering down tx
			.RXPD(2'b0),						//not powering down rx
			
			//Loopback (turned off)
			.LOOPBACK(3'b000),					//loopback disabled
			
			//Fabric-side clocks
			.TXOUTCLKSEL(3'b100),				//output clock selector: TXPLLREFCLK_DIV2
			.TXOUTCLK(clk_fabric),				//Output clock to fabric (62.5 MHz for 1gbaseX)
			.TXOUTCLKFABRIC(),					//reserved, ignore
			.TXOUTCLKPCS(),						//reserved, ignore
			.TXUSRCLK(clk_fabric_bufg),			//PCS clock
			.TXUSRCLK2(clk_fabric_bufg),		//Parallel data clock
			
			.RXOUTCLKSEL(3'b100),				//RXPLLREFCLK_DIV2
			.RXOUTCLK(),						//output clock to FPGA fabric (ignored)
			.RXOUTCLKFABRIC(),					//reserved, ignore
			.RXOUTCLKPCS(),						//reserved, ignore
			.RXUSRCLK(clk_fabric_bufg),			//clock for rx PCS
			.RXUSRCLK2(clk_fabric_bufg),		//clock for rx interface
			
			//Reset stuff
			.GTTXRESET(gtp_tx_reset),			//transmit port reset
			.GTRXRESET(gtp_rx_reset),			//receive port reset
			.TXUSERRDY(user_ready),				//indicates user clocks are ready
			.TXRESETDONE(gtp_tx_rsdone),		//successful completion of transmit-side reset (TXUSRCLK2)
			.TXPMARESETDONE(gtp_tx_pmarsdone),	//successful completion of PMA reset
			.RXUSERRDY(user_ready),				//indicates user clocks are ready
			.RXRESETDONE(gtp_rx_rsdone),		//successful completion of receive-side reset (RXUSERCLK2)
			.RXPMARESETDONE(gtp_rx_pmarsdone),	//successful completion of PMA reset
			
			//Transceiver data
			.TXDATA({16'h0, serdes_tx_data[7:0], serdes_tx_data[15:8]}),			//Transmit data bus (bswapped)
			.RXDATA({gtp_rx_unused[31:16], serdes_rx_data[7:0], serdes_rx_data[15:8]}),	//receive data
			.RXDATAVALID(serdes_rx_data_valid),										//indicates read data is valid
			
			//8b/10b coder
			//TODO: make this parameterizable
			.TXCHARISK({2'b00, serdes_tx_kchars[0], serdes_tx_kchars[1]}),		//K-characters (bswapped)
			.TX8B10BBYPASS(4'b0000),			//do not bypass 8b10b encoder
			.TX8B10BEN(1'b1),					//enable 8b10b coding
			.TXCHARDISPMODE({2'b00, serdes_tx_forcedisp_en}),			//allow disparity override
			.TXCHARDISPVAL({2'b00, serdes_tx_forcedisp}),
			.RX8B10BEN(1'b1),					//enable 8b10b
			.RXCOMMADETEN(1'b1),				//use comma detector
			.RXBYTEISALIGNED(gtp_rx_align),		//successful alignment
			.RXBYTEREALIGN(gtp_rx_realign),		//alignment changed
			.RXCOMMADET(gtp_rx_comma),			//found a comma
			.RXPCOMMAALIGNEN(1'b1),				//align to positive commas
			.RXMCOMMAALIGNEN(1'b1),				//align to negative commas
			.RXSLIDE(1'b0),						//not overriding comma detector
			.RXCHARISCOMMA({gtp_rx_unused[1:0], serdes_rx_commas}),							//list of commas
			.RXCHARISK({gtp_rx_unused[3:2], serdes_rx_kchars[0], serdes_rx_kchars[1]}),		//list of k chars
			.RXDISPERR({gtp_rx_unused[5:4], gtp_rx_disperr}),								//list of disparity errors
			.RXNOTINTABLE({gtp_rx_unused[7:6], gtp_rx_notintbl}),							//list of invalid 8b10b chars
			
			//64b/6xb coder (not used for now)
			//TODO: Make this parameterizable
			.TXGEARBOXREADY(),
			.TXHEADER(3'h0),
			.TXSEQUENCE(7'h0),
			.TXSTARTSEQ(1'b0),
			.RXGEARBOXSLIP(1'b0),
			.RXHEADER(),
			.RXHEADERVALID(),
			.RXSTARTOFSEQ(),
			
			//Transceiver buffer status outputs
			.TXBUFSTATUS(gtp_tx_bufstat),		//Transmit buffer status
												//1 = over/underflow
												//0 = half-full
			.RXBUFSTATUS(gtp_rx_bufstat),		//buffer status
												
			//Transmit drive strength (use defaults for 1000gbaseX for now)
			.TXBUFDIFFCTRL(3'b100),				//nominal pre-driver swing
			.TXDEEMPH(1'b0),					//6 dB de-emphasis
			.TXDIFFCTRL(4'b1010),				//857 mV Vdiff amplitude (default from wizard)
			.TXPDELECIDLEMODE(1'b0),			//synchronous flag
			.TXELECIDLE(1'b0),					//not sending electrical idle
			.TXINHIBIT(1'b0),					//do not block transmitter
			.TXMAINCURSOR(7'h0),				//not modifying cursor coefficients
			.TXMARGIN(3'b000),					//not using pcie stuff
			.PMARSVDIN1(1'b0),					//reserved, must be 0
			.PMARSVDIN0(1'b0),					//reserved, must be 0
			.TXPOSTCURSOR(5'h0),				//0 dB pre-emphasis
			.TXPOSTCURSORINV(1'b0),				//not inverting postcursor
			.TXPRECURSOR(5'b0),					//0 dB pre-emphasis
			.TXPRECURSORINV(1'b0),				//not inverting precursor
			.TXSWING(1'b0),						//full swing outputs
			
			//Variable data rate support (not used for now)
			.TXRATE(3'b000),					//fixed divider set at synthesis time
			.TXRATEMODE(1'b0),					//synchronous (doesn't matter, it's a constant anyway)
			.TXRATEDONE(),						//not changing rate, ignore
			.RXRATEDONE(),						//indicates completion of rate change, ignore
			.RXRATEMODE(1'b0),					//RXRATE is synchronous
			
			//Transmit phase aligner (not used for now)
			.TXPHDLYRESET(1'b0),
			.TXPHALIGN(1'b0),
			.TXPHALIGNEN(1'b0),
			.TXPHDLYPD(1'b0),					//leave phase aligner powered on
			.TXPHINIT(1'b0),
			.TXPHOVRDEN(1'b0),
			.TXDLYSRESET(),
			.TXDLYBYPASS(1'b1),					//bypass phase aligner
			.TXDLYEN(1'b0),
			.TXPHDLYTSTCLK(1'b0),
			.TXDLYHOLD(1'b0),
			.TXDLYUPDOWN(1'b0),
			.TXPHALIGNDONE(),
			.TXPHINITDONE(),
			.TXDLYSRESETDONE(),
			.TXSYNCMODE(1'b0),					//reserved. must be 0
			.TXSYNCALLIN(1'b0),					//reserved. must be 0
			.TXSYNCIN(1'b0),					//reserved. must be 0
			.TXSYNCOUT(),
			.TXSYNCDONE(),
			
			//Transmit phase interpolator (not used for now)
			.TXPIPPMEN(1'b0),					//not using phase interpolator
			.TXPIPPMOVRDEN(1'b0),				//normal operation
			.TXPIPPMSEL(1'b1),					//reserved, must be 1
			.TXPIPPMPD(1'b1),					//power down phase interpolator
			.TXPIPPMSTEPSIZE(5'h0),				//do not change phase
			
			//Receive phase aligner (not used for now)
			.RXPHDLYRESET(1'b0),				//do not reset phase aligner
			.RXPHALIGN(1'b0),					//auto align
			.RXPHALIGNEN(1'b0),					//auto align
			.RXPHDLYPD(1'b0),					//leave it powered up
			.RXPHOVRDEN(1'b0),
			.RXDLYSRESET(1'b0),					//disable soft reset
			.RXDLYEN(1'b0),						//do not use delay aligner
			.RXDLYOVRDEN(1'b0),
			.RXDDIEN(1'b0),
			.RXPHALIGNDONE(),
			.RXPHMONITOR(),
			.RXPHSLIPMONITOR(),
			.RXDLYSRESETDONE(),
			.RXSYNCMODE(1'b0),
			.RXSYNCALLIN(1'b0),
			.RXSYNCIN(1'b0),
			.RXSYNCOUT(),
			.RXSYNCDONE(),
			.RXDLYBYPASS(1'b1),					//bypass delay aligner, use buffer
			
			//Receiver equalizer
			.RXLPMHFHOLD(1'b0),					//adaptive HF boost
			.RXLPMHFOVRDEN(1'b1),				//use static boost config
			.RXLPMLFHOLD(1'b0),					//adaptive LF boost
			.RXLPMLFOVRDEN(1'b1),				//use static boost config
			
			//Receiver clock recovery (use defaults from 1000baseX for now)
			.RXCDRHOLD(1'b0),					//do not freeze clock recovery block
			.RXCDROVRDEN(1'b0),					//reserved, must be 0
			.RXCDRRESETRSV(1'b0),				//reserved, must be 0
			.RXRATE(3'b000),					//use RXOUT_DIV divider
			.RXCDRLOCK(),						//reserved, ignore
			.RXOSHOLD(1'b0),					//do not freeze offset cancellation
			.RXOSOVRDEN(1'b0),					//do not use RX_OS_CFG
			.RXOSINTPD(1'b0),					//do not power down clock recovery block
			.RXOSINTCFG(4'b0010),				//magic value from transceiver wizard
			.RXOSINTOVRDEN(1'b0),				//reserved, must be 0
			.RXOSINTSTROBE(1'b0),				//reserved, must be 0
			.RXOSINTHOLD(1'b0),					//reserved, must be 0
			.RXOSINTTESTOVRDEN(1'b0),			//reserved, must be 0
			.RXOSINTSTARTED(),					//reserved, ignore
			.RXOSINTSTROBESTARTED(),			//reserved. ignore		
			.RXCLKCORCNT(),						//ignore clock correction status for now
			.RXOSINTDONE(),						//reserved, ignore
			
			//Channel bonding (not used for now)
			.RXCHANBONDSEQ(),					//not doing channel bonding
			.RXCHANISALIGNED(),					//not doing channel bonding
			.RXCHANREALIGN(),
			.RXCHBONDI(4'b0000),
			.RXCHBONDO(),
			.RXCHBONDLEVEL(3'b000),
			.RXCHBONDMASTER(1'b0),
			.RXCHBONDSLAVE(1'b0),
			.RXCHBONDEN(1'b0),
			
			//Unused subsystem resets
			.GTRESETSEL(1'b0),					//sequential reset
			.TXPMARESET(1'b0),
			.TXPCSRESET(1'b0),
			.RXOSCALRESET(1'b0),
			.RXLPMRESET(1'b0),
			.RXPMARESET(1'b0),
			.RXCDRRESET(1'b0),
			.RXCDRFREQRESET(1'b0),
			.RXPCSRESET(1'b0),					//PCS reset
			.RXBUFRESET(1'b0),					//elastic buffer reset
			
			//SATA OoB (not implemented for now)
			.TXCOMFINISH(),						//ignore sata signals
			.TXCOMINIT(1'b0),					//not sending SATA OoB signals
			.TXCOMSAS(1'b0),					//not sending SATA OoB signals
			.TXCOMWAKE(1'b0),					//not sending SATA OoB signals
			
			.RXOOBRESET(1'b0),
			.RXCOMINITDET(),
			.RXCOMSASDET(),
			.RXCOMWAKEDET(),
			.RXELECIDLE(),
			.RXELECIDLEMODE(2'b11),
			
			//PCIe (not implemented for now)
			.PHYSTATUS(),
			.RXSTATUS(),
			.TXDETECTRX(1'b0),
			
			//Eye scan (not used for now)
			.EYESCANRESET(1'b0),				//eye scan reset
			.EYESCANMODE(1'b0),
			.EYESCANDATAERROR(),				//indicates eye scan data error
			.EYESCANTRIGGER(1'b0),				//Trigger for eye scan
			
			//Digital monitor (not used for now)
			.DMONITOROUT(),						//digital monitor output bus
			.DMONFIFORESET(1'b0),				//reserved, must be zero
			.DMONITORCLK(clk_reset),				//give this some kind of clock
			
			//PRBS generator
			.RXPRBSCNTRESET(1'b0),				//not resetting PRBS counter
			.RXPRBSSEL(3'b000),					//not using PRBS
			.RXPRBSERR(),						//PRBS status (ignored)
			.TXPRBSSEL(3'b0),					//not using PRBS generator
			.TXPRBSFORCEERR(1'b0),				//not using error injector
			
			//Dynamic reconfiguration port
			.DRPADDR(gtp_drp_addr),				//DRP address bus
			.DRPCLK(clk_reset),					//DRP clock
			.DRPEN(gtp_drp_en),					//DRP activity strobe
			.DRPDI(gtp_drp_wdata),				//DRP write bus
			.DRPRDY(gtp_drp_ready),				//DRP ready flag
			.DRPDO(gtp_drp_rdata),				//DRP read bus
			.DRPWE(gtp_drp_we),					//DRP write enable
			
			//Reserved stuff
			.RESETOVRD(1'b0),					//reserved, must be 0
			.CFGRESET(1'b0),					//reserved, must be 0
			.PMARSVDOUT1(),						//reserved, ignore
			.PMARSVDOUT0(),						//reserved, ignore
			.PMARSVDIN2(1'b0),					//reserved, must be zero
			.PCSRSVDOUT(),						//reserved, ignore
			
			//undocumented? xst complains about not being used
			.GTRSVD(),
			.RXOSINTSTROBEDONE(),
			.RXOSINTEN(1'b0),
			.RXOSINTID0(4'b0),
			.RXOSINTNTRLEN(1'b0),
			.RXVALID(),
			.CLKRSVD0(),
			.CLKRSVD1(),
			.PCSRSVDIN(16'b0),
			.PMARSVDIN3(1'b0),
			.PMARSVDIN4(1'b0),
			.RXDFEXYDEN(1'b0),
			.RXLPMOSINTNTRLEN(1'b0),
			.SETERRSTATUS(),
			.SIGVALIDCLK(),
			.TSTIN(20'b0),
			.TXDIFFPD(1'b0),
			.TXPISOPD(1'b0),
			.TXDLYOVRDEN(1'b0),
			.RXADAPTSELTEST(14'b0)
		);
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Reset logic

		reg[7:0]	count	= 0;
		reg[3:0]	gtp_reset_state	= 0;
		
		reg[15:0]	drp_savedval	= 0;
		
		wire		gtp_rx_pmarsdone_sync;
		ThreeStageSynchronizer sync_pma_rdone(
			.clk_in(clk_reset), 	.din(gtp_rx_pmarsdone),
			.clk_out(clk_reset), 	.dout(gtp_rx_pmarsdone_sync)	);
			
		wire		pll0_lock_sync;
		ThreeStageSynchronizer sync_pll0_lock(
			.clk_in(clk_reset), 	.din(pll_lock[0]),
			.clk_out(clk_reset),	.dout(pll0_lock_sync)			);
			
		wire		gtp_tx_rsdone_sync;
		ThreeStageSynchronizer sync_tx_rsdone(
			.clk_in(clk_fabric_bufg), 	.din(gtp_tx_rsdone),
			.clk_out(clk_reset),		.dout(gtp_tx_rsdone_sync)		);
			
		wire		gtp_rx_rsdone_sync;
		ThreeStageSynchronizer sync_rx_rsdone(
			.clk_in(clk_fabric_bufg), 	.din(gtp_rx_rsdone),
			.clk_out(clk_reset),		.dout(gtp_rx_rsdone_sync)		);
		
		always @(posedge clk_reset) begin
		
			gtp_drp_addr			<= 0;
			gtp_drp_en				<= 0;
			gtp_drp_wdata			<= 0;
			gtp_drp_we				<= 0;
			
			case(gtp_reset_state)
				
				//Start the PLL reset
				0: begin
				
					if(startup_reset) begin

						//Start resets of PLL and transmit datapath simultaneously
						quad_reset		<= 1;
						gtp_tx_reset	<= 1;
						gtp_rx_reset	<= 1;
						
						count			<= 0;
						gtp_reset_state	<= gtp_reset_state + 1'h1;

					end
					
				end
				
				//Hold reset high for a little whlie
				1: begin
					count			<= count + 8'h1;
					if(count == 255) begin
						quad_reset		<= 0;
						gtp_reset_state	<= gtp_reset_state + 1'h1;
					end
				end
				
				//Need to do a DRP read-modify-write here
				//(see "GTP Transceiver RX Reset in Response to Completion of Configuration" in UG482)
				//Read the address
				2: begin
					gtp_drp_en		<= 1;
					gtp_drp_addr	<= 9'h011;
					gtp_reset_state	<= gtp_reset_state + 1'h1;
				end
				
				//Wait for DRP read to complete, then issue DRP write
				//Set bit 11 of address 9‘h011 to zero
				3: begin
					if(gtp_drp_ready) begin
						drp_savedval		<= gtp_drp_rdata;
						
						gtp_drp_en			<= 1;
						gtp_drp_addr		<= 9'h011;
						gtp_drp_we			<= 1;
						gtp_drp_wdata		<= gtp_drp_rdata;
						gtp_drp_wdata[11]	<= 1'b0;
						gtp_reset_state		<= gtp_reset_state + 1'h1;
					end
				end
				
				4: begin
					if(gtp_drp_ready)
						gtp_reset_state	<= gtp_reset_state + 1'h1;
				end
				
				//Wait for GTP PLL to lock, then clear RX reset
				5: begin
					if(pll0_lock_sync) begin
					
						//User stuff is ready once PLL is locked
						user_ready		<= 1;
					
						gtp_reset_state	<= gtp_reset_state + 1'h1;
						count			<= 0;
						
						gtp_rx_reset	<= 0;
					end
				end
				
				//Wait for falling edge of RXPMARESETDONE
				6: begin
					if(gtp_rx_pmarsdone_sync == 0)
						gtp_reset_state	<= gtp_reset_state + 1'h1;
				end
				
				//Need to do a DRP read-modify-write here before RXPMARESETDONE goes high
				//DRPADDR 9‘h011, set bit[11] to its original value
				7: begin
					gtp_drp_en		<= 1;
					gtp_drp_addr	<= 9'h011;
					gtp_reset_state	<= gtp_reset_state + 1'h1;
				end
				
				8: begin
					if(gtp_drp_ready) begin
						gtp_drp_en			<= 1;
						gtp_drp_addr		<= 9'h011;
						gtp_drp_we			<= 1;
						gtp_drp_wdata		<= gtp_drp_rdata;
						gtp_drp_wdata[11]	<= drp_savedval[11];
					
						gtp_reset_state		<= gtp_reset_state + 1'h1;
					end
				end
				
				//Wait for a little while, then clear TX reset
				9: begin
					count				<= count + 8'h1;
					if(count == 255) begin
						gtp_tx_reset	<= 0;
						gtp_reset_state	<= gtp_reset_state + 1'h1;
					end
				end
				
				//Done with resets
				10: begin
					if(gtp_tx_rsdone_sync && gtp_rx_rsdone_sync) begin
						serdes_ready		<= 1;
						gtp_reset_state	<= gtp_reset_state + 1'h1;
					end
				end
				
				//Rest state, stay here forever
				11: begin
				end
				
			endcase
			
		end

	`endif

endmodule

