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
	@brief Gigabit Ethernet MAC with SFP interface
	
	refclk must be 125 MHz on a dedicated SERDES pin.
	
	Note that clk_fabric is 62.5 MHz, not 125 MHz as in NetworkedEthernetMAC.
 */
module GigabitEthernetMAC_SFP(
	
	//Clocks
	clk_125mhz, refclk,
	
	//MAC control
	mac_reset, mac_reset_done,

	//SFP interface
	sfp_tx_p, sfp_tx_n, sfp_rx_p, sfp_rx_n,
	
	//Receiver data outputs (gmii_rxc domain)
	rx_frame_start, rx_frame_data_valid, rx_frame_data, rx_frame_done, rx_frame_drop,
	
	//Transmitter data inputs (gmii_rxc domain)
	tx_frame_data, tx_frame_data_valid, tx_frame_done,
	
	//Status outputs
	link_state, duplex_state, link_speed,
	
	//Link clock after buffer
	clk_fabric
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk_125mhz;	//Reset clock domain
	input wire refclk;		//125 MHz reference clock for GTP
	output wire clk_fabric;	//62.5 MHz fabric clock coming off GTP
	
	//SFP interface
	output wire sfp_tx_p;
	output wire sfp_tx_n;
	
	input wire	sfp_rx_p;
	input wire	sfp_rx_n;
	
	//MAC control (clk_125mhz domain)
	input wire mac_reset;
	output reg mac_reset_done		= 0;
	
	/*
		Receiver data outputs (gmii_rxc domain)
		
		When a frame arrives, rx_frame_start is asserted for one cycle.
		rx_frame_valid will be asserted every 4 cycles with data on rx_frame_data.
		rx_frame_done will be asserted at the end of the frame.
	 */
	output reg rx_frame_start		= 0;
	output reg rx_frame_data_valid	= 0;
	output reg[31:0] rx_frame_data	= 0;
	output reg rx_frame_done 		= 0;
	output reg rx_frame_drop		= 0;
	
	input wire[31:0] tx_frame_data;
	input wire tx_frame_data_valid;
	output reg tx_frame_done = 0;
	
	`include "TriModeEthernetMAC_linkspeeds_constants.v";
	
	//Status outputs (clk_125mhz domain)
	output reg link_state 			= 0;						//1 = connected
	output wire duplex_state;
	output wire[1:0] link_speed;
	
	assign duplex_state 			= 1;						//We are always gig/full so hard wire this
	assign link_speed				= LINK_SPEED_GIGABIT;
	
	parameter AUTO_POR				= 0;						//set to 1 to automatically reset on power up
	parameter CLOCK_BUF_TYPE 		= "GLOBAL";
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Common clocking stuff for the GTP quad
	
	wire		quad_reset;
	wire[1:0]	pll_clk;
	wire[1:0]	pll_refclk;
	wire[1:0]	pll_lock;
	
	TransceiverPLL #(
		.TARGET_INTERFACE("1000BASEX")
	) quad_pll (
		.clk_reset(clk_125mhz),
		.refclk({1'b0, refclk}),
		.reset(quad_reset),
		.pll_clk(pll_clk),
		.pll_refclk(pll_refclk),
		.pll_lock(pll_lock)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The GTP channel
	
	reg			startup_reset		= 0;
	
	reg[15:0]	serdes_tx_data		= 0;
	reg[1:0]	serdes_tx_kchars	= 0;
	
	reg[1:0]	serdes_tx_forcedisp_en	= 0;
	
	wire[15:0]	serdes_rx_data;
	wire[1:0]	serdes_rx_kchars;
	wire[1:0]	serdes_rx_data_valid;
	wire[1:0]	serdes_rx_commas;
	
	wire		serdes_ready;
		
	TransceiverChannel #(
		.TARGET_INTERFACE("1000BASEX")
	) serdes_channel (
	
		//Top-level pads
		.serdes_tx_p(sfp_tx_p),
		.serdes_tx_n(sfp_tx_n),
		.serdes_rx_p(sfp_rx_p),
		.serdes_rx_n(sfp_rx_n),

		//Clocks
		.clk_reset(clk_125mhz),
		.pll_lock(pll_lock),
		.pll_clk(pll_clk),
		.pll_refclk(pll_refclk),
		.clk_fabric_bufg(clk_fabric),
		
		//Resets
		.quad_reset(quad_reset),				//Drive the quad reset since we are only using one channel
		.startup_reset(startup_reset),
		.serdes_ready(serdes_ready),
		
		//Parallel data
		.serdes_tx_data(serdes_tx_data),
		.serdes_tx_kchars(serdes_tx_kchars),

		.serdes_tx_forcedisp_en(serdes_tx_forcedisp_en),
		.serdes_tx_forcedisp(2'b00),			//if we force disparity, it's always to negative
		
		.serdes_rx_data(serdes_rx_data),
		.serdes_rx_data_valid(serdes_rx_data_valid),
		.serdes_rx_kchars(serdes_rx_kchars),
		.serdes_rx_commas(serdes_rx_commas)
	);
	
	//Reset logic
	reg auto_reset				= 0;
	reg post_done				= 0;
	
	always @(posedge clk_125mhz) begin

		startup_reset			<= 0;
		
		mac_reset_done			<= 0;
		
		//Wait for MAC reset to come in
		//unless AUTO_POR is set
		if(mac_reset || (auto_reset && AUTO_POR)) begin

			//Do the reset
			startup_reset	<= 1;

		end
		
		if(serdes_ready && !post_done) begin
			post_done		<= 1;
			mac_reset_done	<= 1;
		end
		
	end

	//Internal power-on reset generator
	//Wait 2^15 cycles (~525 us) to reset after powerup so everything initializes OK.
	//Don't start the timer until the transceiver PLL has locked so we have stable clocks to work with!
	reg[14:0]	por_count	= 1;
	always @(posedge clk_125mhz) begin
		auto_reset		<= 0;
		if(!post_done && pll_lock[0]) begin
			por_count		<= por_count + 1'h1;
			if(por_count == 0)
				auto_reset	<= 1;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receiver helpers
	
	//We want to have commas LEFT aligned, but the SERDES tries to *right* align them!
	//Fix that by adding 2 cycles of latency.
	
	reg[7:0]	serdes_rx_data_ff	= 0;
	reg			serdes_rx_kchars_ff	= 0;
	
	//Byte-swap 16-bit words since it looks like base-X sends config words in a strange endianness
	reg[15:0]	serdes_rx_data_aligned			= 0;
	wire[15:0]	serdes_rx_data_aligned_swapped	= {serdes_rx_data_aligned[7:0], serdes_rx_data_aligned[15:8]};
	reg[1:0]	serdes_rx_kchars_aligned	= 0;
	
	always @(posedge clk_fabric) begin
	
		//Save old data
		serdes_rx_data_ff	<= serdes_rx_data[7:0];
		serdes_rx_kchars_ff	<= serdes_rx_kchars[0];
		
		//Do the half-word shift
		serdes_rx_data_aligned		<= {serdes_rx_data_ff, serdes_rx_data[15:8]};
		serdes_rx_kchars_aligned	<= {serdes_rx_kchars_ff, serdes_rx_kchars[1]};
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit FIFO
	
	reg			tx_fifo_rd		= 0;
	reg			tx_fifo_rd_ff	= 0;
	wire[31:0]	tx_fifo_rdata;
	
	always @(posedge clk_fabric) begin
		tx_fifo_rd_ff	<= tx_fifo_rd;
	end
	
	wire		tx_fifo_empty;
	
	SingleClockFifo #(
		.WIDTH(32),
		.DEPTH(512),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) tx_fifo (
		.clk(clk_fabric),
		.reset(startup_reset),
		
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
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Transmit CRC calculation
    
    reg			tx_crc_reset	= 0;
    reg			tx_crc_update	= 0;
    reg[15:0]	tx_crc_din		= 0;
    wire[31:0]	tx_crc;
    
    EthernetCRC32_x16 tx_crc_calc(
		.clk(clk_fabric),
		.reset(tx_crc_reset),
		.update(tx_crc_update),
		.din(tx_crc_din),
		.crc_flipped(tx_crc),
		.crc_x8_flipped()
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit running disparity calculation
	
	wire[1:0] tx_raw_disparity;
	
	DisparityCalculator8b10b dispcalc_hi(
		.isk(serdes_tx_kchars[1]),
		.din(serdes_tx_data[15:8]),
		.disp(tx_raw_disparity[1])
		);
		
	DisparityCalculator8b10b dispcalc_lo(
		.isk(serdes_tx_kchars[0]),
		.din(serdes_tx_data[7:0]),
		.disp(tx_raw_disparity[0])
		);

	//Start out as negative
	reg	tx_running_disparity_fwd	= 0;
	reg	tx_running_disparity		= 0;
	reg link_state_ff				= 0;
	always @(*) begin
		
		//Reset disparity to negative when link comes up
		if(link_state && !link_state_ff)
			tx_running_disparity_fwd	<= 0;
			
		//Mix in the new data
		else
			tx_running_disparity_fwd	<= tx_running_disparity ^ tx_raw_disparity[0] ^ tx_raw_disparity[1];
			
	end
	always @(posedge clk_fabric) begin
		link_state_ff				<= link_state;
		tx_running_disparity		<= tx_running_disparity_fwd;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit / autonegotiation logic
	
	`include "GigabitEthernetMAC_SFP_autoneg_states_constants.v"
	
	reg[3:0]	autoneg_state	= STATE_BOOT;
	reg[2:0]	autoneg_count	= 0;
	
	reg[1:0]	autoneg_tx_count		= 0;
	
	//Status flags from 802.3-2008 37.3.1.1
	reg[15:0]	tx_config_reg		= 0;
	reg			ability_match		= 0;
	reg[15:0]	rx_config_reg		= 0;
	reg			acknowledge_match	= 0;
	reg			consistency_match	= 0;
	reg			idle_match			= 0;
	
	//Config register as of when we entered the current state
	reg[15:0]	rx_enter_reg		= 0;
	
	//Helpers for ability_match
	reg			rx_last_was_c1			= 0;
	reg			rx_last_was_c2			= 0;
	reg			rx_config_reg_new		= 0;
	reg[15:0]	rx_config_reg_ff		= 0;
	reg[15:0]	rx_config_reg_ff2		= 0;
	reg			rx_last_was_idle		= 0;
	reg			rx_last_was_idle_ff		= 0;
	reg			rx_last_was_idle_ff2	= 0;
	
	//Link timer
	reg			link_timer_active	= 0;
	reg[19:0]	link_timer			= 0;
	reg			link_timer_wrap		= 0;
	
	//Transmit states
	reg			tx_active			= 0;
	reg[2:0]	tx_finish_state		= 0;
	reg			tx_got_sfd			= 0;
	
	//Transmit pipeline registers (need to add a cycle of latency for inserting the CRC)
	reg[1:0]	serdes_tx_kchars_adv	= 0;
	reg[15:0]	serdes_tx_data_adv		= 0;
	
	always @(posedge clk_fabric) begin
		
		serdes_tx_kchars_adv	<= 2'b00;
		serdes_tx_data_adv		<= 16'h0000;
		
		tx_frame_done			<= 0;
		tx_fifo_rd				<= 0;
		tx_crc_reset			<= 0;
		tx_crc_din				<= 0;
		tx_crc_update			<= 0;
		
		//Push tx data down the pipe
		serdes_tx_kchars		<= serdes_tx_kchars_adv;
		serdes_tx_data			<= serdes_tx_data_adv;
		serdes_tx_forcedisp_en	<= 0;
		
		//If sending /C1/ during configuration, force disparity negative
		//TODO: why does this not work?
		//if(!link_state && serdes_tx_data_adv == 16'hbcb5)
		//	serdes_tx_forcedisp_en	<= 2'b10;

		//Bump link timer if needed
		link_timer_wrap			<= 0;
		if(link_timer_active) begin
			if(link_timer == 0) begin
				link_timer_wrap 	<= 1;
				link_timer_active	<= 0;
			end
			else
				link_timer		<= link_timer + 1'd1;
		end
		
		//If in autonegotiation mode, send the status register
		//Need to byte-swap here!
		if(!link_state) begin
		
			autoneg_tx_count	<= autoneg_tx_count + 1'h1;
		
			//Send idle words (I2 ordered set)
			if(autoneg_state == STATE_IDLE_DETECT) begin
				serdes_tx_kchars_adv                <= 2'b10;
				serdes_tx_data_adv                  <= {8'hbc, 8'h50};              //K28.5 D16.2 = I2
			end
			
			//Send configuration words
			else begin
				case(autoneg_tx_count)
					
					//C1 ordered set
					0: begin
						serdes_tx_kchars_adv	<= 2'b10;
						serdes_tx_data_adv		<= {8'hbc, 8'hb5};		//K28.5 D21.5
					end
					
					//Status register
					1: begin
						serdes_tx_data_adv		<= {tx_config_reg[7:0], tx_config_reg[15:8]};
					end
					
					//C2 ordered set
					2: begin
						serdes_tx_kchars_adv	<= 2'b10;
						serdes_tx_data_adv		<= {8'hbc, 8'h42};		//K28.5 D2.2
					end
					
					//Status register
					3: begin
						serdes_tx_data_adv		<= {tx_config_reg[7:0], tx_config_reg[15:8]};
					end
					
				endcase
			end
			
		end
		
		//Nope, send data or idles
		else begin
			
			//If we have data to read, but didn't already start the read process, pop the next word
			if(!tx_active && !tx_fifo_empty && !tx_fifo_rd && !tx_fifo_rd_ff)
				tx_fifo_rd	<= 1;

			//We're sending data
			else if(tx_fifo_rd_ff || tx_active) begin
				
				//Sending first half of word
				if(tx_fifo_rd_ff) begin
				
					//We haven't kicked off the send yet.
					//Send a SPD (K27.7) followed by a 0x55 to align the packet to a 16-bit boundary
					if(!tx_active) begin
						
						tx_active				<= 1;
						serdes_tx_kchars_adv	<= 2'b10;
						serdes_tx_data_adv		<= {8'hfb, 8'h55};
					
						tx_crc_reset			<= 1;
						tx_got_sfd				<= 0;
					
					end
				
					//No, just send data
					else begin
					
						serdes_tx_kchars_adv	<= 0;
						serdes_tx_data_adv		<= tx_fifo_rdata[31:16];
					
						if(tx_got_sfd) begin
							tx_crc_update		<= 1;
							tx_crc_din			<= tx_fifo_rdata[31:16];
						end
						
						else if(tx_fifo_rdata[31:16] == 16'h55d5)
							tx_got_sfd		<= 1;
							
					end
						
					//Data to read? get the next word
					if(!tx_fifo_empty)
						tx_fifo_rd		<= 1;
					
				end
				
				//Sending second half of word.
				//Read next word if available
				else begin
					serdes_tx_kchars_adv	<= 0;
					serdes_tx_data_adv		<= tx_fifo_rdata[15:0];
					
					if(tx_got_sfd) begin
						tx_crc_update		<= 1;
						tx_crc_din			<= tx_fifo_rdata[15:0];
					end
					
					//If no more data to read, go into the end sequence
					if(tx_fifo_empty) begin
						tx_finish_state	<= 1;
						tx_active		<= 0;
					end
					
				end
			
			end
			
			//Send the end of the packet
			else if(tx_finish_state != 0) begin
				
				tx_finish_state	<= tx_finish_state + 1'd1;
				
				case(tx_finish_state)
				
					//wait for CRC
					1: begin
					end
				
					//Send first half of CRC
					2: begin
						serdes_tx_kchars		<= 0;
						serdes_tx_data			<= tx_crc[31:16];
					end
					
					//Send second half of CRC
					3: begin
						serdes_tx_kchars		<= 0;
						serdes_tx_data			<= tx_crc[15:0];
					end
					
					//Send EPD + EPD2 (/T/ /R/) = K29.7 K23.7
					//These codes do not change the disparity
					4: begin
						serdes_tx_kchars		<= 2'b11;
						serdes_tx_data			<= {8'hfd, 8'hf7};						
					end
					
					//Done, send a normal idle code
					5: begin
					
						//Disparity is positive, flip it
						if(tx_running_disparity_fwd)
							serdes_tx_data		<= {8'hbc, 8'hc5};				//K28.5 D5.6 = I1
							
						//Disparity is already negative, leave it
						else
							serdes_tx_data      <= {8'hbc, 8'h50};              //K28.5 D16.2 = I2
						
						serdes_tx_kchars		<= 2'b10;
						
						//Next send is a comma
						serdes_tx_kchars_adv    <= 2'b10;
						serdes_tx_data_adv      <= {8'hbc, 8'h50};              //K28.5 D16.2 = I2
						
						tx_frame_done			<= 1;
						tx_finish_state			<= 0;
					end
				
				endcase
				
			end
			
			//Send idles if nothing else to send
			else begin
				serdes_tx_kchars_adv                <= 2'b10;
				serdes_tx_data_adv                  <= {8'hbc, 8'h50};          //K28.5 D16.2 = I2
			end
			
		end
		
		//Detect inbound configuration registers
		rx_config_reg_new		<= 0;
		rx_last_was_c1			<= 0;
		rx_last_was_c2			<= 0;
		if( (serdes_rx_data_aligned == 16'hbcb5) && (serdes_rx_kchars_aligned == 2'b10) )
			rx_last_was_c1		<= 1;
		if( (serdes_rx_data_aligned == 16'hbc42) && (serdes_rx_kchars_aligned == 2'b10) )
			rx_last_was_c2		<= 1;

		if(rx_last_was_c1 || rx_last_was_c2) begin
			rx_config_reg_ff2	<= rx_config_reg_ff;
			rx_config_reg_ff	<= rx_config_reg;
			rx_config_reg		<= serdes_rx_data_aligned_swapped;
			rx_config_reg_new	<= 1;
			ability_match		<=	(serdes_rx_data_aligned_swapped == rx_config_reg) &&
									(serdes_rx_data_aligned_swapped == rx_config_reg_ff);
		end
		
		acknowledge_match		<= ability_match && rx_config_reg[14];
		consistency_match		<=	(rx_enter_reg[15] == rx_config_reg[15]) &&
									(rx_enter_reg[13:0] == rx_config_reg[13:0]);

		//Detect inbound idle frames
		rx_last_was_idle		<= 0;
		if( (serdes_rx_data_aligned == 16'hbc50) && (serdes_rx_kchars_aligned == 2'b10) )
			rx_last_was_idle	<= 1;
		rx_last_was_idle_ff		<= rx_last_was_idle;
		rx_last_was_idle_ff2	<= rx_last_was_idle_ff;
		idle_match				<= rx_last_was_idle && rx_last_was_idle_ff && rx_last_was_idle_ff2;
		
		//Main autonegotiation state machine
		case(autoneg_state)
		
			//Wait for reset to finish
			STATE_BOOT: begin
				if(serdes_ready)
					autoneg_state	<= STATE_AN_ENABLE;
			end	//end STATE_BOOT
			
			//Setup for autonegotiation
			STATE_AN_ENABLE: begin
				link_state			<= 0;
				tx_config_reg		<= 0;
				
				link_timer			<= 1;
				link_timer_active	<= 1;
				
				autoneg_state		<= STATE_AN_RESTART;
			end	//end STATE_AN_ENABLE
			
			//Restart autonegotiation process
			STATE_AN_RESTART: begin
				if(link_timer_wrap)
					autoneg_state	<= STATE_ABILITY_DETECT;
			end	//end STATE_AN_RESTART
			
			//Detect compatible link partner
			STATE_ABILITY_DETECT: begin
				tx_config_reg[15]	<= 0;		//no next page
				tx_config_reg[13:0]	<= 14'h20;	//full duplex only
				
				//Go on if we get a good config register (supports full duplex)
				if(ability_match && (rx_config_reg != 0) && rx_config_reg[5] ) begin
					rx_enter_reg	<= rx_config_reg;
					autoneg_state	<= STATE_ACKNOWLEDGE_DETECT;
				end
				
			end	//end STATE_ABILITY_DETECT
			
			//Set our ACK bit and wait for the other end to do the same
			STATE_ACKNOWLEDGE_DETECT: begin
				tx_config_reg[14]	<= 1;
				
				//If we get good results, move on
				if(acknowledge_match && consistency_match) begin
					autoneg_state		<= STATE_COMPLETE_ACKNOWLEDGE;
					link_timer			<= 1;
					link_timer_active	<= 1;
				end
				
				//Abort if we lose contact
				if(acknowledge_match && !consistency_match)
					autoneg_state	<= STATE_AN_ENABLE;
				
			end	//end STATE_ACKNOWLEDGE_DETECT
			
			//Complete the acknowledgement process
			STATE_COMPLETE_ACKNOWLEDGE: begin
					
				if(link_timer_wrap) begin
				
					//If the timer elapses and we have stable state, we're good to go
					if(consistency_match && acknowledge_match) begin
						autoneg_state		<= STATE_IDLE_DETECT;
						link_timer			<= 1;
						link_timer_active	<= 1;
					end
					
					//If state changed, restart autonegotiation
					else
						autoneg_state		<= STATE_AN_ENABLE;
					
				end
			
			end	//end STATE_COMPLETE_ACKNOWLEDGE
			
			//Wait for the remote end to start sending igle bits
			STATE_IDLE_DETECT: begin
			
				//Abort if we lose contact
				if(ability_match && (rx_config_reg == 0) )
					autoneg_state	<= STATE_AN_ENABLE;
					
				//If we get idles, good to go
				if(link_timer_wrap && idle_match) begin
					autoneg_state	<= STATE_LINK_OK;
					link_state		<= 1;
				end
			
			end	//end STATE_IDLE_DETECT
			
			//Link is OK
			STATE_LINK_OK: begin
			
				//Restart the link timer every time we get a valid triple of idle words
				if(idle_match) begin
					link_timer			<= 1;
					link_timer_active	<= 1;
				end
				
				//If the timer wraps, the link has gone down
				//(this means that we have to get at least 3 idles in a row every 10 ms to stay up)
				if(link_timer_wrap) begin
					link_state			<= 0;
					autoneg_state		<= STATE_AN_ENABLE;
				end
				
				//If we get a configuration word the link has gone down so restart autonegotiation
				if(rx_last_was_c1 || rx_last_was_c2) begin
					link_state			<= 0;
					autoneg_state		<= STATE_AN_ENABLE;
				end
			
			end	//end STATE_LINK_OK
		
		endcase
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive state
	
	//Phase of data, in bytes
	//0 = next data word goes at [31:16]
	//1 = next data word goes at [23:8]
	//2 = next data word goes at [15:0]
	//3 = next data word goes at [7:0] and [31:23] of next
	reg[1:0]	data_phase			= 0;
	
	reg			rx_frame_active		= 0;
	reg			rx_preamble_found	= 0;
	reg[31:0]	rx_pending_word		= 0;

	localparam PREAMBLE_BYTE	= 8'b01010101;
	localparam SFD_BYTE			= 8'b11010101;
	
	//Preamble detection
	reg[1:0]	sfd_found			= 0;
	
	always @(*) begin
		sfd_found[1]		<= (serdes_rx_data[15:8] == SFD_BYTE);
		sfd_found[0]		<= (serdes_rx_data[7:0] == SFD_BYTE);
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive CRC calculation
	
	reg rx_crc_update		= 0;
	reg[15:0] rx_crc_din 	= 0;
	wire[31:0] rx_crc;
	wire[31:0] rx_crc_x8;
	reg rx_crc_reset 		= 0;
	EthernetCRC32_x16 rx_crc_calc(
		.clk(clk_fabric),
		.reset(rx_crc_reset),
		.update(rx_crc_update),
		.din(rx_crc_din),
		.crc_flipped(rx_crc),
		.crc_x8_flipped(rx_crc_x8)
		);
		
		
	always @(*) begin
		rx_crc_din		<= 0;
		rx_crc_update	<= 0;
		
		//Reset CRC when a new frame begins
		rx_crc_reset <= rx_frame_start;
		
		//Feed data in if we're looking at data
		if(rx_preamble_found) begin
						
			case(data_phase)
			
				//0 deg: checksum the entire incoming message
				0: 	rx_crc_din		<= serdes_rx_data;
				
				//90 deg: checksum the saved byte and half of the incoming message
				1: 	rx_crc_din		<= {rx_pending_word[31:24], serdes_rx_data[15:8]};
				
				//180 deg: checksum the entire incoming message
				2: 	rx_crc_din		<= serdes_rx_data;
				
				//270 deg:checksum the saved byte and half of the incoming message
				3: 	rx_crc_din		<= {rx_pending_word[15:8], serdes_rx_data[15:8]};
			
			endcase
			
			//Update the CRC
			rx_crc_update			<= 1;

		end
		
	end
	
	//Save last rx_frame_data low nibble
	reg[7:0]	rx_frame_data_hi_ff	= 0;
	reg[7:0]	rx_frame_data_low_ff	= 0;
	always @(posedge clk_fabric) begin
		if(rx_frame_data_valid_fwd) begin
			rx_frame_data_low_ff	<= rx_frame_data_fwd[7:0];
			rx_frame_data_hi_ff		<= rx_frame_data_fwd[15:8];
		end
	end
	
	reg[31:0]	rx_crc_compare	= 0;
	always @(*) begin
		
		rx_crc_compare				<= 0;
	
		//Even/odd packet lengths need different phase offsets
		if( (data_phase[0] == serdes_rx_kchars[1])  ) begin
			case(data_phase)
				0:	rx_crc_compare		<= {rx_frame_data_fwd[23:0], serdes_rx_data[15:8]  };
				1:	rx_crc_compare		<= {rx_frame_data_fwd[23:0], rx_pending_word[31:24]};
				2:	rx_crc_compare		<= {rx_frame_data_low_ff, rx_pending_word[31:16], serdes_rx_data[15:8]};
				3:	rx_crc_compare		<= {rx_frame_data_low_ff, rx_pending_word[31:8]};
			endcase
		end
		
		else begin
			case(data_phase)
				0:	rx_crc_compare		<= rx_frame_data_fwd;
				1:	rx_crc_compare		<= {rx_frame_data_fwd[15:0], rx_pending_word[31:24], serdes_rx_data[15:8]};
				2:	rx_crc_compare		<= {rx_frame_data_hi_ff, rx_frame_data_low_ff, rx_pending_word[31:16]};
				3:	rx_crc_compare		<= {rx_pending_word[31:8], serdes_rx_data[15:8]};
			endcase
		end
		
	end
	
	//Delay old CRCs by a cycle so we can read the value we are comparing against
	reg[31:0] rx_crc_ff 	= 0;
	reg[31:0] rx_crc_ff2 	= 0;
	reg[31:0] rx_crc_x8_ff	= 0;
	reg[31:0] rx_crc_x8_ff2	= 0;
	always @(posedge clk_fabric) begin
		rx_crc_ff 		<= rx_crc;
		rx_crc_ff2		<= rx_crc_ff;
		rx_crc_x8_ff	<= rx_crc_x8;
		rx_crc_x8_ff2	<= rx_crc_x8_ff;
	end	
	
	//CRC verification
	reg rx_crc_match		= 0;
	always @(*) begin
	
		rx_crc_match	<= 0;
		
		//ODD starting phase
		if(data_phase[0]) begin
		
			//Even length
			if(!serdes_rx_kchars[1])
				rx_crc_match	<= (rx_crc_ff == rx_crc_compare);
				
			//Odd length
			else
				rx_crc_match	<= (rx_crc_x8_ff == rx_crc_compare);
		
		end
		
		//EVEN starting phase
		else begin
		
			//Even length
			if(serdes_rx_kchars[1])
				rx_crc_match	<= (rx_crc_ff2 == rx_crc_compare);
				
			//Odd length
			else
				rx_crc_match	<= (rx_crc_x8_ff == rx_crc_compare);
		
		end
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main receive logic

	//Indicates we saw a valid frame or idle code this cycle
	reg		link_valid		= 0;
	
	//Forwarded versions of data
	reg			rx_frame_data_valid_fwd	= 0;
	reg			rx_frame_done_fwd		= 0;
	reg[31:0]	rx_frame_data_fwd		= 0;
	
	reg			rx_frame_data_valid_fwd2	= 0;
	reg			rx_frame_done_fwd2			= 0;
	reg[31:0]	rx_frame_data_fwd2			= 0;
	
	always @(posedge clk_fabric) begin
	
		rx_frame_start			<= 0;
		rx_frame_drop			<= 0;
		
		rx_frame_done_fwd			<= 0;
		rx_frame_data_valid_fwd		<= 0;
		
		//Default: push status down the pipe
		rx_frame_done_fwd2			<= rx_frame_done_fwd;
		rx_frame_data_fwd2			<= rx_frame_data_fwd;
		rx_frame_data_valid_fwd2	<= rx_frame_data_valid_fwd;
		
		rx_frame_done				<= rx_frame_done_fwd2;
		rx_frame_data				<= rx_frame_data_fwd2;
		rx_frame_data_valid			<= rx_frame_data_valid_fwd2;
				
		//Look for special symbols
		if((link_state == 1) && serdes_rx_data_valid) begin
			
			//Look for K27.7 start-of-packet
			if(serdes_rx_kchars[1] && serdes_rx_data[15:8] == 8'hfb) begin
				rx_frame_start		<= 1;
				rx_frame_active		<= 1;				
				rx_preamble_found	<= 0;
				rx_pending_word		<= 0;
			end
			else if(serdes_rx_kchars[0] && serdes_rx_data[7:0] == 8'hfb) begin
				rx_frame_start		<= 1;
				rx_frame_active		<= 1;
				rx_preamble_found	<= 0;
				rx_pending_word		<= 0;
			end
			
			//Look for K29.7 end-of-packet
			else if(
				(serdes_rx_kchars[1] && serdes_rx_data[15:8] == 8'hfd) ||
				(serdes_rx_kchars[0] && serdes_rx_data[7:0] == 8'hfd) ) begin

				rx_frame_active		<= 0;
				rx_preamble_found	<= 0;
				rx_pending_word		<= 0;
				
				//Assert data-ready if we have any data ready to send
				//Zero out the CRC so we have a nice clean data field
				
				//Even/odd packet lengths need different phase offsets
				if( (data_phase[0] == serdes_rx_kchars[1])  ) begin
					case(data_phase)
						0:	rx_frame_data_fwd			<= 0;
						1:	rx_frame_data_fwd2[23:0]	<= 0;
						2:	rx_frame_data[7:0]			<= 0;
						3:	rx_frame_data[7:0]			<= 0;
					endcase
				end
				
				else begin
					case(data_phase)
						0:	rx_frame_data_fwd			<= 0;
						1:	rx_frame_data_fwd2[15:0]	<= 0;
						2:	rx_frame_data[15:0]			<= 0;
						//3 = full word, no action needed
					endcase
				end

				//Check CRC and report status
				rx_frame_drop			<= !rx_crc_match;
				rx_frame_done_fwd		<= rx_crc_match;
				
			end
			
			//Data and/or preamble
			else if(rx_frame_active) begin
				
				//Look for the 5555...d5
				if(!rx_preamble_found) begin
					
					//SFD in first byte, second is data
					if(sfd_found[1]) begin
						rx_preamble_found		<= 1;
						data_phase				<= 1;
						rx_pending_word[31:24]	<= serdes_rx_data[7:0];
					end
					
					//SFD in second byte, no data
					else if(sfd_found[0]) begin
						rx_preamble_found		<= 1;
						data_phase				<= 0;
					end
					
				end
				
				//We have data, deal with it
				else begin
				
					//Phase shift by 2 bytes
					data_phase	<= data_phase + 2'd2;
				
					//Crunch data as needed
					case(data_phase)
					
						//0 deg offset... load into left half
						0: begin
							rx_pending_word[31:16]	<= serdes_rx_data;
						end
						
						//90 deg offset... load into middle
						1: begin
							rx_pending_word[23:8]	<= serdes_rx_data;
						end
						
						//180 deg offset... load into right half and then send it
						2: begin
							rx_frame_data_fwd		<= {rx_pending_word[31:16], serdes_rx_data};
							rx_frame_data_valid_fwd	<= 1;
							rx_pending_word			<= 0;
						end
						
						//270 deg offset... load into right quarter, send it, then load into left quarter
						3: begin
							rx_frame_data_fwd		<= {rx_pending_word[31:8], serdes_rx_data[15:8]};
							rx_frame_data_valid_fwd	<= 1;
							rx_pending_word			<= {serdes_rx_data[7:0], 24'h0};
						end
					
					endcase
				
				end
				
			end
			
		end
		
	end
	
endmodule
