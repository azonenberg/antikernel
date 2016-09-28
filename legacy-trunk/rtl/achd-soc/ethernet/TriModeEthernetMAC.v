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
	@brief 10/100/1000 Ethernet MAC core
 */
module TriModeEthernetMAC(
	clk_25mhz, clk_125mhz,
	
	//MAC control
	mac_reset, mac_reset_done,
	
	//[R]GMII signals
	xmii_rxc, xmii_rxd, xmii_rx_ctl,
	xmii_txc, xmii_txd, xmii_tx_ctl,
	
	//Management and interrupt signals
	mgmt_mdio, mgmt_mdc, clkout, phy_reset_n,
	
	//Receiver data outputs (gmii_rxc domain)
	rx_frame_start, rx_frame_data_valid, rx_frame_data, rx_frame_done, rx_frame_drop,
	
	//Transmitter data inputs (gmii_rxc domain)
	tx_frame_data, tx_frame_data_valid, tx_frame_done,
	
	//Status outputs
	link_state, duplex_state, link_speed,
	
	//Link clock after buffer
	gmii_rxc
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk_25mhz;
	input wire clk_125mhz;
	
	//MAC control (clk_125mhz domain)
	input wire mac_reset;
	output reg mac_reset_done	= 0;
	
	//Set this to "GMII" or "RGMII"
	parameter PHY_INTERFACE = 0;
	localparam PHY_INTERFACE_RGMII = (PHY_INTERFACE == "RGMII");
	
	//Sanity check
	initial begin
		if( (PHY_INTERFACE != "RGMII") && (PHY_INTERFACE != "GMII") ) begin
			$display("ERROR: TriModeEthernetMAC interface can only be RGMII or GMII, \"%s\" is illegal", PHY_INTERFACE);
			$finish;
		end
	end
	
	//Width of data/control buses
	localparam DATA_WIDTH = PHY_INTERFACE_RGMII ? 4 : 8;
	localparam CTRL_WIDTH = PHY_INTERFACE_RGMII ? 1 : 2;
	
	//[R]GMII signals
	input wire xmii_rxc;
	input wire[DATA_WIDTH-1:0] xmii_rxd;
	input wire[CTRL_WIDTH-1:0] xmii_rx_ctl;
	output wire xmii_txc;
	output wire[DATA_WIDTH-1:0] xmii_txd;
	output wire[CTRL_WIDTH-1:0] xmii_tx_ctl;
	
	//Management and interrupt signals
	inout wire mgmt_mdio;
	output wire mgmt_mdc;
	output wire clkout;
	output reg phy_reset_n		= 0;		//default to being in reset
	
	parameter PHY_CHIPSET			= "INVALID";
	parameter AUTO_POR				= 0;
	parameter OUTPUT_PHASE_SHIFT	= "DELAY";
	parameter CLOCK_BUF_TYPE 		= "GLOBAL";
	
	/*
		Receiver data outputs (gmii_rxc domain)
		
		When a frame arrives, rx_frame_start is asserted for one cycle.
		rx_frame_valid will be asserted every 4 cycles with data on rx_frame_data.
		rx_frame_done will be asserted at the end of the frame.
		
		If an error occurs, rx_frame_drop will be asserted. This should reset the receiver's frame-processing
		state machine and prepare for processing of a new frame.
		
		It is possible for rx_frame_drop to be asserted at any time, including before or while rx_frame_start
		is asserted.
	 */
	output reg rx_frame_start = 0;
	output reg rx_frame_data_valid = 0;
	output reg[31:0] rx_frame_data = 0;
	output reg rx_frame_done = 0;
	output reg rx_frame_drop = 0;
	
	input wire[31:0] tx_frame_data;
	input wire tx_frame_data_valid;
	output reg tx_frame_done = 0;
	
	`include "TriModeEthernetMAC_linkspeeds_constants.v";
	
	//Status outputs (clk_125mhz domain)
	output reg link_state = 0;		//1 = connected
	output reg duplex_state = 0;	//1 = full duplex
	output reg[1:0] link_speed = LINK_SPEED_NONE;
	
	//Link clock after buffer
	output wire gmii_rxc;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GMII-to-RGMII bridge
	
	//GMII signals
	wire[7:0] gmii_rxd;
	wire gmii_rx_dv;
	wire gmii_rx_er;
	wire gmii_txc;
	reg[7:0] gmii_txd	= 0;
	reg gmii_tx_en		= 0;
	
	EthernetBusWidthConverter #(
		.PHY_INTERFACE_RGMII(PHY_INTERFACE_RGMII),
		.OUTPUT_PHASE_SHIFT(OUTPUT_PHASE_SHIFT),
		.CLOCK_BUF_TYPE(CLOCK_BUF_TYPE)
	) cvt (
		.xmii_rxc(xmii_rxc),
		.xmii_rxd(xmii_rxd),
		.xmii_rx_ctl(xmii_rx_ctl),
		
		.xmii_txc(xmii_txc),
		.xmii_txd(xmii_txd),
		.xmii_tx_ctl(xmii_tx_ctl),
	
		.gmii_rxc(gmii_rxc),
		.gmii_rxd(gmii_rxd),
		.gmii_rx_dv(gmii_rx_dv),
		.gmii_rx_er(gmii_rx_er),
	
		.gmii_txc(gmii_txc),
		.gmii_txd(gmii_txd),
		.gmii_tx_en(gmii_tx_en),
		.gmii_tx_er(1'b0)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock output buffers
	
	//25 MHz PHY clock
	DDROutputBuffer #
	(
		.WIDTH(1)
	) phy_clock_output
	(
		.clk_p(clk_25mhz),
		.clk_n(~clk_25mhz),
		.dout(clkout),
		.din0(1'b1),
		.din1(1'b0)
	);
	
	//Transmit clock (loopback from PHY-supplied received clock)
	//TODO: Don't do this!!!
	//Instead, we should run everything at clk_125mhz and gate as needed
	assign gmii_txc = gmii_rxc;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MDIO interface
	
	`include "EthernetPhyRegisterIDs_constants.v"
	`include "EthernetPhyRegisterBits_constants.v"
	
	wire mgmt_busy_fwd;
	reg[4:0] phy_reg_addr = 0;
	reg[15:0] phy_wr_data = 0;
	wire[15:0] phy_rd_data;
	reg phy_reg_wr = 0;
	reg phy_reg_rd = 0;
	
	parameter PHY_MD_ADDR = 5'b00001;
	
	EthernetMDIOTransceiver #(
		.PHY_MD_ADDR(PHY_MD_ADDR)
	) mdio_txvr (
		.clk_125mhz(clk_125mhz),
		.mdio(mgmt_mdio),
		.mdc(mgmt_mdc),
		.mgmt_busy_fwd(mgmt_busy_fwd),
		.phy_reg_addr(phy_reg_addr),
		.phy_wr_data(phy_wr_data),
		.phy_rd_data(phy_rd_data),
		.phy_reg_wr(phy_reg_wr),
		.phy_reg_rd(phy_reg_rd)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register writes to do during boot for configuring the PHY
	
	/*
		Microcode table needs to allow unconditional read-modify-write for poking single bits in 88E1111 registers
		
		36:32 = regid
		31:16 = rmask
		15:0  = wdata
		
		Operation is as follows:
			Read regid
			AND with rmask
			OR with wdata
			Write to regid
	 */
	
	reg[36:0] boot_reg_write_microcode[15:0];
	
	//The PHY ID register is specified to be read-only.
	//Use a write to this as the "end of microcode" indicator.
	localparam REGISTER_ID_INVALID		= REGISTER_ID_PHYID_1;
	
	//Load the microcoded list of register writes
	integer i;
	initial begin
	
		//Wipe the microcode table to all zeroes
		for(i=0; i<16; i=i+1)
			boot_reg_write_microcode[i] <= 37'h0;
		
		//First command is the same for all supported PHYs
		//Write to IEEE standard CONTROL register, set autonegotiate on and full duplex
		boot_reg_write_microcode[0][36:32] <= REGISTER_ID_CONTROL;
		boot_reg_write_microcode[0][BIT_CONTROL_AUTONEG] <= 1;
		boot_reg_write_microcode[0][BIT_CONTROL_DUPLEX] <= 1;
		
		//Everything from here on out is chipset-specific
		
		//Micrel KSZ9021 and 9031 are interface-compatible in general
		if( (PHY_CHIPSET == "KSZ9021") || (PHY_CHIPSET == "KSZ9031") ) begin
			
			//U-boot claims the KSZ9021 requires master mode due to errata (see http://pastebin.com/g2Km1CeM)
			//however no errata document is readily available to check.
			//This was tried but didn't seem to make a difference so it's been omitted.
			
			//Enable in-band status with an extended register write. This requires two transactions:
			//one to specify the register to write to, then another one to write the actual data.
			
			boot_reg_write_microcode[1][36:32]						<= REGISTER_ID_EXT_CTL;
			boot_reg_write_microcode[1][BIT_KSZ_EXT_WRITE]			<= 1;
			boot_reg_write_microcode[1][8:0]						<= REGISTER_ID_KSZ_EXT_CCTL;
			
			boot_reg_write_microcode[2][36:32]						<= REGISTER_ID_EXT_WRITE;
			boot_reg_write_microcode[2][BIT_KSZ_EXT_CCTL_INBAND]	<= 1;
			
			//Done
			boot_reg_write_microcode[3][36:32]						<= REGISTER_ID_INVALID;
			/*
			//DEBUG: Enable gig loopback for testing
			boot_reg_write_microcode[3][36:32]						<= 0;
			boot_reg_write_microcode[3][14]							<= 1;
			boot_reg_write_microcode[3][6]							<= 1;
			boot_reg_write_microcode[3][8]							<= 1;
			
			boot_reg_write_microcode[4][36:32]						<= 9;
			boot_reg_write_microcode[4][12]							<= 1;
			boot_reg_write_microcode[4][9]							<= 1;
			
			boot_reg_write_microcode[5][36:32]						<= REGISTER_ID_INVALID;
			*/
			
		end
		
		//Marvell 88E1111
		else if(PHY_CHIPSET == "88E1111") begin
		
			//Write to HWCFG_MODE to select RGMII mode
			//This can be avoided by proper pin strapping, but the Atlys board is strapped to run in GMII mode.
			//There's no harm in doing a mode switch if we're already in RGMII mode anyway, so just do it.
			boot_reg_write_microcode[1][36:32]						<= REGISTER_ID_88E1111_PHYCON;
			boot_reg_write_microcode[1][31:20]						<= 12'hfff;	//Preserve all bits other than mode
			boot_reg_write_microcode[1][3:0]						<= 4'b1011;	//Select RGMII mode
			
			//Do a software reset to make the mode switch take effect
			boot_reg_write_microcode[2][36:32]						<= REGISTER_ID_CONTROL;
			boot_reg_write_microcode[2][BIT_CONTROL_RESET]			<= 1;
			boot_reg_write_microcode[2][BIT_CONTROL_AUTONEG]		<= 1;
			boot_reg_write_microcode[2][BIT_CONTROL_DUPLEX]			<= 1;
		
			//Done
			boot_reg_write_microcode[3][36:32]						<= REGISTER_ID_INVALID;
		
		end
		
		//Add new chipsets here
		
		//Invalid if we get here
		else begin
			$display(
				"ERROR: Unrecognized PHY chipset '%s' specified to TriModeEthernetMAC, please select a supported PHY",
				PHY_CHIPSET);
			$finish;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main control state machine (125 MHz clock domain)
		
	`include "TriModeEthernetMAC_states_constants.v"
	
	//Read out the microcode
	reg[3:0]	microcode_raddr		= 0;
	wire[36:0]	microcode_line		= boot_reg_write_microcode[microcode_raddr];
	wire[4:0]	microcode_regaddr	= microcode_line[36:32];
	wire[15:0]	microcode_andmask	= microcode_line[31:16];
	wire[15:0]	microcode_data		= microcode_line[15:0];
	
	reg[14:0]	reset_count			= 0;
	
	reg[2:0]	state				= STATE_BOOT_FREEZE;
	
	always @(posedge clk_125mhz) begin
	
		mac_reset_done <= 0;
		
		phy_reg_wr <= 0;
		phy_reg_rd <= 0;
	
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Initialization
			
			//Boot up in a frozen state and wait for a reset
			STATE_BOOT_FREEZE: begin
				if(AUTO_POR)
					state		<= STATE_RESET_0;
			end	//end STATE_BOOT_FREEZE

			//Leave reset active for ~100us, then deassert.
			STATE_RESET_0: begin
				microcode_raddr <= 0;
				reset_count <= reset_count + 15'h1;	
				
				if(reset_count[14]) begin
					reset_count <= 0;
					
					if(phy_reset_n == 0) begin
						phy_reset_n		<= 1;
						state			<= STATE_WAIT_FOR_RESET;
					end
					
				end
			end	//end STATE_RESET_0
			
			//Do the register read
			STATE_BOOT_REGREAD: begin
				if(!mgmt_busy_fwd) begin
				
					//Stop if we just did the last one
					if( microcode_regaddr == REGISTER_ID_INVALID ) begin
						state			<= STATE_IDLE;
						mac_reset_done	<= 1;
					end
				
					//Do the read
					else begin
						phy_reg_rd		<= 1;
						phy_reg_addr	<= microcode_regaddr;
						state			<= STATE_BOOT_REGWRITE;
					end
					
				end
			end
			
			//Do the register write and bump the pointer
			STATE_BOOT_REGWRITE: begin
				if(!mgmt_busy_fwd) begin
					phy_wr_data			<= microcode_data | (phy_rd_data & microcode_andmask);
					phy_reg_wr			<= 1;
					microcode_raddr		<= microcode_raddr + 4'h1;				
					state				<= STATE_BOOT_REGREAD;
					
					//If we're triggering a software reset, wait 100us for that to finish
					if( (microcode_regaddr == REGISTER_ID_CONTROL) && (microcode_data[BIT_CONTROL_RESET]) ) begin
						reset_count <= 0;
						state <= STATE_WAIT_FOR_RESET;
					end
					
				end			
			end
			
			STATE_WAIT_FOR_RESET: begin
				reset_count <= reset_count + 15'h1;	
				if(reset_count[14]) begin
					reset_count <= 0;
					state <= STATE_BOOT_REGREAD;
				end
			end
				
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Idle, nothing going on
			
			STATE_IDLE: begin						
				
			end	//end STATE_IDLE

		endcase
		
		//If a reset was requested, do it
		if(mac_reset) begin
			phy_reset_n <= 0;
			reset_count <= 0;
			state <= STATE_RESET_0;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GMII receive logic (gmii_rxc domain)
	
	localparam PREAMBLE_BYTE	= 8'b01010101;
	localparam SFD_BYTE			= 8'b11010101;
	
	localparam RX_STATE_IDLE		=	0;
	localparam RX_STATE_DATA		=	1;
	localparam RX_STATE_DROP_FRAME	=	2;
	
	reg[3:0] rx_state = RX_STATE_IDLE;
	
	reg[31:0] rx_frame_data_raw = 0;		//Current half-calculated frame data
	reg[3:0] rx_frame_nibble_pos = 0;		//Index in the current word (nibbles)
	
	//CRC calculation
	reg rx_crc_update = 0;
	reg[7:0] rx_crc_din = 0;
	wire[31:0] rx_crc;
	reg rx_crc_reset = 0;
	EthernetCRC32 rx_crc_calc(.clk(gmii_rxc), .reset(rx_crc_reset), .update(rx_crc_update), .din(rx_crc_din), .crc_flipped(rx_crc));
	always @(*) begin
		rx_crc_din <= 0;
		rx_crc_update <= 0;
		rx_crc_reset <= 0;
			
		case(rx_state)
			RX_STATE_IDLE: begin
				if(gmii_rx_dv && (gmii_rxd == SFD_BYTE))
					rx_crc_reset <= 1;
			end
			RX_STATE_DATA: begin
				if( gmii_rx_dv ) begin
				
					//Update every cycle, inverting the first 32 bits
					if(link_speed == LINK_SPEED_GIGABIT) begin
						rx_crc_update <= 1;
						rx_crc_din <= gmii_rxd;
					end
					
					//Update every other cycle
					else begin
						if(rx_frame_nibble_pos[0]) begin
							rx_crc_update <= 1;
							rx_crc_din <= {rx_frame_data_raw[3:0], gmii_rxd[3:0]};
						end
					end
				end
			end	//end RX_STATE_DATA
		endcase
		
	end
	
	//CRC verification
	//TODO: verify offsets work for MII as well as GMII
	reg[31:0] rx_crc_buf = 0;
	reg[31:0] rx_crc_buf2 = 0;
	reg[31:0] rx_crc_buf3 = 0;
	reg[31:0] rx_crc_buf4 = 0;
	always @(posedge gmii_rxc) begin
		rx_crc_buf <= rx_crc;
		rx_crc_buf2 <= rx_crc_buf;
		rx_crc_buf3 <= rx_crc_buf2;
		if(gmii_rx_dv)
			rx_crc_buf4 <= rx_crc_buf3;
	end	
	wire rx_crc_match = (rx_crc_buf4 == rx_frame_data_raw);
	
	//Forwarding registers for frame outputs
	reg			rx_frame_data_valid_fwd		= 0;
	reg			rx_frame_data_valid_fwd2	= 0;
	reg			rx_frame_data_valid_fwd3	= 0;
	reg			rx_frame_data_valid_fwd4	= 0;
	reg[31:0]	rx_frame_data_fwd			= 0;
	reg[31:0]	rx_frame_data_fwd1			= 0;
	reg[31:0]	rx_frame_data_fwd2			= 0;
	reg[31:0]	rx_frame_data_fwd3			= 0;
	reg[31:0]	rx_frame_data_fwd4			= 0;
	reg			rx_frame_done_fwd			= 0;
	reg			rx_frame_done_fwd2			= 0;
	reg			rx_frame_done_fwd3			= 0;
	reg			rx_frame_done_fwd4			= 0;
	reg			rx_frame_drop_fwd			= 0;
	reg			rx_frame_drop_fwd2			= 0;
	reg			rx_frame_drop_fwd3			= 0;
	reg			rx_frame_drop_fwd4			= 0;
	
	//Main state machine	
	always @(posedge gmii_rxc) begin
		
		rx_frame_start <= 0;
		
		//Clear internal flags
		rx_frame_done_fwd		<= 0;
		rx_frame_data_valid_fwd	<= 0;
		rx_frame_data_fwd		<= 0;
		rx_frame_drop_fwd		<= 0;
		
		//Push stuff down the pipeline
		rx_frame_data_valid_fwd2	<= rx_frame_data_valid_fwd;
		rx_frame_data_valid_fwd3	<= rx_frame_data_valid_fwd2;
		rx_frame_data_valid_fwd4	<= rx_frame_data_valid_fwd3;
		rx_frame_data_valid			<= rx_frame_data_valid_fwd4;
		
		rx_frame_data_fwd2	<= rx_frame_data_fwd;
		rx_frame_data_fwd3	<= rx_frame_data_fwd2;
		rx_frame_data_fwd4	<= rx_frame_data_fwd3;
		rx_frame_data		<= rx_frame_data_fwd4;
		
		rx_frame_drop_fwd2	<= rx_frame_drop_fwd;
		rx_frame_drop_fwd3	<= rx_frame_drop_fwd2;
		rx_frame_drop_fwd4	<= rx_frame_drop_fwd3;
		rx_frame_drop		<= rx_frame_drop_fwd4;
		
		rx_frame_done_fwd2	<= rx_frame_done_fwd;
		rx_frame_done_fwd3	<= rx_frame_done_fwd2;
		rx_frame_done_fwd4	<= rx_frame_done_fwd3;
		rx_frame_done		<= rx_frame_done_fwd4;
		
		case(rx_state)

			RX_STATE_IDLE: begin
			
				//Data coming in, process it
				if(gmii_rx_dv) begin
				
					//Only valid inputs are preamble and SFD
					if(gmii_rxd == SFD_BYTE) begin
						rx_frame_start		<= 1;
						rx_frame_nibble_pos <= 0;
						rx_state			<= RX_STATE_DATA;
					end
					else if(gmii_rxd == PREAMBLE_BYTE) begin
					end
					else begin
						rx_state 			<= RX_STATE_DROP_FRAME;
						rx_frame_drop_fwd 	<= 1;
					end
					
				end
				
				//Not a frame? Should be in-band status
				else begin
				
					//Error indicator
					//TODO: Keep count of these
					if(gmii_rx_er) begin
						//0e = false carrier
					end
				
					//Nope, link state/speed flag
					else begin
						duplex_state <= gmii_rxd[3];
						
						case(gmii_rxd[2:1])
							0: link_speed <= LINK_SPEED_10MBIT;
							1: link_speed <= LINK_SPEED_100MBIT;
							2: link_speed <= LINK_SPEED_GIGABIT;
							
							default: begin
							end
						endcase
						
						link_state <= gmii_rxd[0];
						
						//If link is down, set speed to none
						if(!gmii_rxd[0])
							link_speed	<= LINK_SPEED_NONE;
						
					end
					
				end
				
			end 	//end RX_STATE_IDLE
			
			//Reading data
			RX_STATE_DATA: begin
	
				//End of frame? Push the half-finished codeword
				if(!gmii_rx_dv) begin
					
					//Take appropriate action depending on CRC match
					if(rx_crc_match)
						rx_frame_done_fwd	<= 1;
					else
						rx_frame_drop_fwd	<= 1;
					
					rx_state				<= RX_STATE_IDLE;
					
					//Default to assuming valid codeword
					rx_frame_data_valid_fwd <= 1;
					
					case(rx_frame_nibble_pos)
						0: begin
							//No action needed, frame is an integer number of words in size
							rx_frame_data_valid_fwd		<= 0;
							rx_frame_data_valid_fwd2	<= 0;
							rx_frame_data_fwd2			<= 0;
						end
						
						2: begin
							rx_frame_data_valid_fwd		<= 0;
							rx_frame_data_valid_fwd2	<= 0;
							rx_frame_data_fwd3[23:0]	<= 0;
						end
						
						4: begin
							rx_frame_data_valid_fwd		<= 0;
							rx_frame_data_valid_fwd2	<= 0;
							rx_frame_data_valid_fwd3	<= 0;
							rx_frame_data_fwd4[15:0]	<= 0;
						end
						
						6: begin
							rx_frame_data_valid_fwd		<= 0;
							rx_frame_data_valid_fwd2	<= 0;
							rx_frame_data_valid_fwd3	<= 0;
							rx_frame_data_valid_fwd4	<= 0;
							rx_frame_data[7:0]			<= 0;
						end
						
						//TODO: 10/100 support
					endcase
					
				end
				
				//Error - drop the frame
				else if(gmii_rx_er) begin
					rx_frame_drop_fwd	<= 1;
					rx_state			<= RX_STATE_DROP_FRAME;
				end
				
				//Continue reading data
				else begin
				
					//GMII is two nibbles at a time
					if(link_speed == LINK_SPEED_GIGABIT) begin					
					
						if(rx_frame_nibble_pos == 6) begin
							rx_frame_data_valid_fwd <= 1;
							rx_frame_data_fwd		<= {rx_frame_data_raw[23:0], gmii_rxd};
							rx_frame_nibble_pos		<= 0;
						end
						
						else
							rx_frame_nibble_pos 	<= rx_frame_nibble_pos + 4'h2;
						
						rx_frame_data_raw 			<= {rx_frame_data_raw[23:0], gmii_rxd};
						
					end
					
					//MII is one nibble at a time
					else begin
					
						if(rx_frame_nibble_pos == 7) begin
							rx_frame_data_valid_fwd <= 1;
							rx_frame_data_fwd		<= {rx_frame_data_raw[27:0], gmii_rxd[3:0]};
							rx_frame_nibble_pos		<= 0;
						end
						
						else
							rx_frame_nibble_pos		<= rx_frame_nibble_pos + 4'h1;
						
						rx_frame_data_raw 			<= {rx_frame_data_raw[27:0], gmii_rxd[3:0]};
						
					end
						
				end
				
			end	//end RX_STATE_DATA
			
			//Dropping a malformed frame
			RX_STATE_DROP_FRAME: begin
			
				if(!gmii_rx_dv)
					rx_state <= RX_STATE_IDLE;
					
			end	//end RX_STATE_DROP_FRAME			
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// GMII transmit logic (gmii_rxc domain)
	
	reg tx_fifo_rd = 0;
	wire[31:0] tx_fifo_rdata;
	wire tx_fifo_empty;
	
	SingleClockFifo #(
		.WIDTH(32),
		.DEPTH(512),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) tx_fifo (
		.clk(gmii_rxc),
		.reset(1'b0),
		
		.wr(tx_frame_data_valid),
		.din(tx_frame_data),
		
		.rd(tx_fifo_rd),
		.dout(tx_fifo_rdata),
		
		.overflow(),
		.underflow(),
		.empty(tx_fifo_empty),
		.full(),
		.rsize(),
		.wsize()
    );

	localparam TX_STATE_IDLE	= 0;
	localparam TX_STATE_RD_WAIT = 1;
	localparam TX_STATE_DATA 	= 2;
	localparam TX_STATE_FCS_0	= 3;
	localparam TX_STATE_FCS_1	= 4;
	localparam TX_STATE_FCS_2	= 5;
	localparam TX_STATE_FCS_3	= 6;
	
	reg[3:0] tx_state = TX_STATE_IDLE;
	reg[3:0] tx_state_buf = TX_STATE_IDLE;
	
	reg[2:0] tx_frame_nibble_pos = 0;
	
	reg tx_started = 0;
	
	//Combinatorial calculation of transmit data
	reg[7:0] gmii_txd_fwd = 0;
	always @(*) begin
		gmii_txd_fwd <= 0;
	
		//Gigabit transmit, 8 bits at a time
		if(link_speed == LINK_SPEED_GIGABIT) begin
			case(tx_frame_nibble_pos[2:1])
				0:	gmii_txd_fwd <= tx_fifo_rdata[31:24];
				1:	gmii_txd_fwd <= tx_fifo_rdata[23:16];
				2:	gmii_txd_fwd <= tx_fifo_rdata[15:8];
				3:	gmii_txd_fwd <= tx_fifo_rdata[7:0];
			endcase
		end
		
		//10/100 transmit, 4 bits at a time
		else begin
			case(tx_frame_nibble_pos[2:0])
				0:	gmii_txd_fwd <= {tx_fifo_rdata[31:28], tx_fifo_rdata[31:28]};
				1:	gmii_txd_fwd <= {tx_fifo_rdata[27:24], tx_fifo_rdata[27:24]};
				2:	gmii_txd_fwd <= {tx_fifo_rdata[23:20], tx_fifo_rdata[23:20]};
				3:	gmii_txd_fwd <= {tx_fifo_rdata[19:16], tx_fifo_rdata[19:16]};
				4:	gmii_txd_fwd <= {tx_fifo_rdata[15:12], tx_fifo_rdata[15:12]};
				5:	gmii_txd_fwd <= {tx_fifo_rdata[11:8], tx_fifo_rdata[11:8]};
				6:	gmii_txd_fwd <= {tx_fifo_rdata[7:4], tx_fifo_rdata[7:4]};
				7:	gmii_txd_fwd <= {tx_fifo_rdata[3:0], tx_fifo_rdata[3:0]};
			endcase
		end
	end
	
	//Combinatorial forwarding of transmit read enable
	
	reg tx_found_sfd = 0;
	reg tx_crc_reset = 0;
	reg tx_crc_update = 0;
	wire[31:0] tx_crc;
	EthernetCRC32 tx_crc_calc(
		.clk(gmii_rxc),
		.reset(tx_crc_reset),
		.update(tx_crc_update),
		.din(gmii_txd_fwd),
		.crc_flipped(tx_crc)
		);
		
	//Transmit logic
	reg[7:0] gmii_txd_adv = 0;
	reg gmii_tx_en_adv = 0;
	always @(posedge gmii_rxc) begin
		
		case(tx_state_buf)
			TX_STATE_FCS_0: begin
				gmii_tx_en <= 1;
				gmii_txd <= tx_crc[31:24];
			end	//end TX_STATE_FCS_0
			
			TX_STATE_FCS_1: begin
				gmii_tx_en <= 1;
				gmii_txd <= tx_crc[23:16];
			end	//end TX_STATE_FCS_1
			
			TX_STATE_FCS_2: begin
				gmii_tx_en <= 1;
				gmii_txd <= tx_crc[15:8];
			end	//end TX_STATE_FCS_2
			
			TX_STATE_FCS_3: begin			
				gmii_tx_en <= 1;
				gmii_txd <= tx_crc[7:0];
			end	//end TX_STATE_FCS_3
			
			default: begin
				gmii_txd <= gmii_txd_adv;
				gmii_tx_en <= gmii_tx_en_adv;
			end
			
		endcase
		
	end
	
	always @(posedge gmii_rxc) begin
		
		tx_frame_done <= 0;
		
		gmii_tx_en_adv <= 0;
		gmii_txd_adv <= 0;
		
		tx_fifo_rd <= 0;
		tx_crc_reset <= 0;
		tx_crc_update <= 0;
		
		tx_state_buf <= tx_state;
		
		case(tx_state)
			
			TX_STATE_IDLE: begin
			
				tx_crc_update <= 0;
				tx_found_sfd <= 0;
			
				//Start doing stuff
				if(!tx_fifo_empty) begin
					tx_fifo_rd <= 1;
					tx_started <= 0;
					tx_state <= TX_STATE_RD_WAIT;
				end
			
			end	//end TX_STATE_IDLE
			
			TX_STATE_RD_WAIT: begin
				//wait for read
				
				//We have a full word ready to read
				tx_frame_nibble_pos <= 0;
				tx_state <= TX_STATE_DATA;
				
				tx_crc_reset <= 1;
				
			end	//end TX_STATE_RD_WAIT
			
			TX_STATE_DATA: begin
			
				//Update CRC
				//Speed optimization: preamble and padding do not have MSB set, SFD does;
				//Checking only the MSB saves one LUT on the critical path
				//TODO: Need to handle 10/100 mode properly
				if(gmii_txd_fwd[7]) begin
					tx_found_sfd <= 1;
					tx_crc_update <= 1;
				end
				if(tx_found_sfd)
					tx_crc_update <= 1;
				
				//Data is ready, output it
				if(tx_started)
					gmii_tx_en_adv <= 1;
				else if(tx_frame_nibble_pos[2]) begin
					tx_started <= 1;
					gmii_tx_en_adv <= 1;
				end
				
				//Gigabit transmit, 8 bits at a time
				gmii_txd_adv <= gmii_txd_fwd;
				if(link_speed == LINK_SPEED_GIGABIT)
					tx_frame_nibble_pos <= tx_frame_nibble_pos + 3'h2;
				else
					tx_frame_nibble_pos <= tx_frame_nibble_pos + 3'h1;
					
				//If we just sent the second-to-last nibble/byte in the word,
				//issue a read request for the next word (unless we're done)
				if(!tx_fifo_empty) begin
					if( (link_speed == LINK_SPEED_GIGABIT) && (tx_frame_nibble_pos[2:1] == 'h2))
						tx_fifo_rd <= 1;
					else if( (link_speed != LINK_SPEED_GIGABIT) && (tx_frame_nibble_pos[2:0] == 'h6) )
						tx_fifo_rd <= 1;
				end
				
				//If we just sent the last word and the FIFO is empty, stop
				if( (tx_frame_nibble_pos[2:1] == 'h3) && tx_fifo_empty) begin
					tx_state <= TX_STATE_FCS_0;
					tx_crc_update <= 0;
				end
				
			end	//end TX_STATE_DATA
			
			TX_STATE_FCS_0: begin			
				tx_state <= TX_STATE_FCS_1;
			end	//end TX_STATE_FCS_0
			
			TX_STATE_FCS_1: begin			
				tx_state <= TX_STATE_FCS_2;
			end	//end TX_STATE_FCS_1
			
			TX_STATE_FCS_2: begin
				tx_state <= TX_STATE_FCS_3;
			end	//end TX_STATE_FCS_2
			
			TX_STATE_FCS_3: begin
				tx_state <= TX_STATE_IDLE;
				tx_frame_done <= 1;
			end	//end TX_STATE_FCS_3
			
			
		endcase
		
	end
	
endmodule
