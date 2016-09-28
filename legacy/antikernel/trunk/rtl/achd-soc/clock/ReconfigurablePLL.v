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
	@brief Reconfigurable PLL core with native interface.
	
	Supports least-common-denominator features only for now.
	
	Only supports 7 series MMCM for now.
	
	BOOT TIME CONFIGURATION
		
		The maximum legal frequency for each output must be selected statically at boot time so that static timing will
		give proper results.
		
		Need to start up in reset until an actual output frequency is selected
	
	RECONFIGURATION PROCESS
	
		All control inputs are synchronous to reconfig_clk.
		reconfig_clk must be no faster than the max DRP frequency (200 MHz for Artix-7)
		
		To reset without changing configuration, strobe reset high for one cycle.
		
		To change the configuration:
			Strobe reconfig_start high for one cycle. The PLL will lose lock.
			Send reconfiguration commands as necessary.
			Bring reconfig_finish high for one cycle.
			Wait for PLL to re-lock.
			
		To change VCO configuration (must be in reconfigure mode)
			Set reconfig_vco_*
				indiv = input divider
				mult = VCO multiplier
				bandwidth = 1 for high or optimized BW, or 0 for low BW
			Strobe reconfig_vco_en high for one cycle
			Wait for reconfig_cmd_done to go high. Do not change reconfig_vco_*
				during this time.
				
		To change output configuration (must be in reconfigure mode)
			Set reconfig_output_*
				idx = index of output (0...5 are legal)
				div = divisor
				Phase shifting and duty cycle changing not currently supported
			Strobe reconfig_output_en high for one cycle
			Wait for reconfig_cmd_done to go high. Do not change reconfig_output_*
				during this time.
 */
module ReconfigurablePLL(
	clkin, clksel,
	clkout,
	reset, locked,
	busy,
	reconfig_clk,
	reconfig_start, reconfig_finish, reconfig_cmd_done,
	reconfig_vco_en, reconfig_vco_mult, reconfig_vco_indiv, reconfig_vco_bandwidth,
	reconfig_output_en, reconfig_output_idx, reconfig_output_div
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Input clock
	input wire[1:0]		clkin;
	input wire			clksel;
	
	//Output clocks
	output wire[5:0]	clkout;
	
	//Control I/O
	input wire			reset;
	output wire			locked;
	
	//Reconfiguration commands
	output reg			busy				= 1;
	input wire			reconfig_clk;
	input wire			reconfig_start;
	input wire			reconfig_finish;
	output reg			reconfig_cmd_done	= 0;
	input wire			reconfig_vco_en;
	input wire[6:0]		reconfig_vco_mult;
	input wire[6:0]		reconfig_vco_indiv;
	input wire			reconfig_vco_bandwidth;
	input wire			reconfig_output_en;
	input wire[2:0]		reconfig_output_idx;
	input wire[7:0]		reconfig_output_div;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//Set the corresponding bit high to gate the output when the PLL is not locked
	//Requires OUTPUT_BUF_GLOBAL or OUTPUT_BUF_LOCAL
	parameter			OUTPUT_GATE			= 6'b111111;
	
	//Set the corresponding bit high to use a global clock buffer on the output
	parameter			OUTPUT_BUF_GLOBAL	= 6'b111111;
	
	//Set the corresponding bit high to use a local clock buffer on the output
	parameter			OUTPUT_BUF_LOCAL	= 6'b000000;
	
	//INPUT clock periods
	parameter			IN0_PERIOD			= 50.0;		//50 ns = 20 MHz
	parameter			IN1_PERIOD			= 50.0;
	
	//MINIMUM clock periods for the outputs, used for static timing.
	//Attempts to change below this will give an error.
	parameter			OUT0_MIN_PERIOD		= 10.000;
	parameter			OUT1_MIN_PERIOD		= 10.000;
	parameter			OUT2_MIN_PERIOD		= 10.000;
	parameter			OUT3_MIN_PERIOD		= 10.000;
	parameter			OUT4_MIN_PERIOD		= 10.000;
	parameter			OUT5_MIN_PERIOD		= 10.000;
	
	//Set true to automatically start in Fmax state
	parameter			ACTIVE_ON_START			= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sanity checks for timing analysis

	`include "ReconfigurablePLL_limits.vh"
	
	//Sanity checks for target parameters
	integer speed;
	integer miniperiod;
	integer maxiperiod;
	integer minoperiod;
	integer maxoperiod;
	
	initial begin
		speed		= `XILINX_SPEEDGRADE;
		miniperiod	= pll_input_min_period(speed);
		maxiperiod	= pll_input_max_period(speed);
		minoperiod	= pll_output_min_period(speed);
		maxoperiod	= pll_output_max_period(speed);
		
		//Sanity check inputs against the min/max legal frequencies
		if( (IN0_PERIOD * 1000 < miniperiod) || (IN0_PERIOD * 1000 > maxiperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Input 0 period out of range");
			$finish;
		end
		if( (IN1_PERIOD * 1000 < miniperiod) || (IN1_PERIOD * 1000 > maxiperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Input 1 period out of range");
			$finish;
		end
		
		//Sanity check outputs against min/max legal frequencies
		if( (OUT0_MIN_PERIOD * 1000 < minoperiod) || (OUT0_MIN_PERIOD * 1000 > maxoperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Output 0 period out of range");
			$finish;
		end
		if( (OUT1_MIN_PERIOD * 1000 < minoperiod) || (OUT1_MIN_PERIOD * 1000 > maxoperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Output 1 period out of range");
			$finish;
		end
		if( (OUT2_MIN_PERIOD * 1000 < minoperiod) || (OUT2_MIN_PERIOD * 1000 > maxoperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Output 2 period out of range");
			$finish;
		end
		if( (OUT3_MIN_PERIOD * 1000 < minoperiod) || (OUT3_MIN_PERIOD * 1000 > maxoperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Output 3 period out of range");
			$finish;
		end
		if( (OUT4_MIN_PERIOD * 1000 < minoperiod) || (OUT4_MIN_PERIOD * 1000 > maxoperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Output 4 period out of range");
			$finish;
		end
		if( (OUT5_MIN_PERIOD * 1000 < minoperiod) || (OUT5_MIN_PERIOD * 1000 > maxoperiod) ) begin
			$display("ERROR: ReconfigurablePLL: Output 5 period out of range");
			$finish;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output buffers
	
	wire[5:0]			clkout_raw;
	
	genvar i;
	generate
		for(i=0; i<6; i=i+1) begin:clkbufs
			
			//Do a global clock buffer if needed
			if(OUTPUT_BUF_GLOBAL[i]) begin
				ClockBuffer #(
					.CE(OUTPUT_GATE[i]? "YES" : "NO"),
					.TYPE("GLOBAL")
				) output_buf (
					.clkin(clkout_raw[i]),
					.ce(locked),
					.clkout(clkout[i])
				);
			end
			
			//Do a local clock buffer if needed
			else if(OUTPUT_BUF_LOCAL[i]) begin
				ClockBuffer #(
					.CE(OUTPUT_GATE[i]? "YES" : "NO"),
					.TYPE("LOCAL")
				) output_buf (
					.clkin(clkout_raw[i]),
					.ce(locked),
					.clkout(clkout[i])
				);
			end
			
			//No buffer, just assign it
			else begin
				
				assign clkout[i] = clkout_raw[i];
				
				//Must not be gating if we don't have a buffer
				if(OUTPUT_GATE[i]) begin
					initial begin
						$display("ERROR: ReconfigurablePLL OUTPUT_GATE is only legal if OUTPUT_BUF_GLOBAL or OUTPUT_BUF_LOCAL is set");
						$finish;
					end
				end
				
			end
			
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual PLL core
	
	reg			drp_en			= 0;
	reg			drp_we			= 0;
	reg[6:0]	drp_daddr		= 0;
	reg[15:0]	drp_din			= 0;
	wire[15:0]	drp_dout;
	wire		drp_ready;
	
	reg			reset_int		= 1;
	
	`ifndef XILINX_7SERIES
		initial begin
			$display("ReconfigurablePLL only implemented for 7 series at the moment");
			$finish;
		end
	`endif
	
	//Internal feedback net
	wire		clk_feedback;
	
	genvar multiplier;
	genvar indiv;
	genvar ok;
		
	`include "ReconfigurablePLL_helpers.vh"
	
	generate

		//Always use input #0 for now
		localparam pllconfig = find_pll_config(
			IN0_PERIOD * 1000, `XILINX_SPEEDGRADE,
			OUT0_MIN_PERIOD * 1000, OUT1_MIN_PERIOD * 1000, OUT2_MIN_PERIOD * 1000,
			OUT3_MIN_PERIOD * 1000,	OUT4_MIN_PERIOD * 1000,	OUT5_MIN_PERIOD * 1000);
		localparam pll_mult	= pllconfig[15:8];
		localparam pll_div	= pllconfig[7:0];
		localparam outdiv0	= pll_vco_outdivcheck(IN0_PERIOD * 1000, pll_mult, pll_div, OUT0_MIN_PERIOD * 1000);
		localparam outdiv1	= pll_vco_outdivcheck(IN0_PERIOD * 1000, pll_mult, pll_div, OUT1_MIN_PERIOD * 1000);
		localparam outdiv2	= pll_vco_outdivcheck(IN0_PERIOD * 1000, pll_mult, pll_div, OUT2_MIN_PERIOD * 1000);
		localparam outdiv3	= pll_vco_outdivcheck(IN0_PERIOD * 1000, pll_mult, pll_div, OUT3_MIN_PERIOD * 1000);
		localparam outdiv4	= pll_vco_outdivcheck(IN0_PERIOD * 1000, pll_mult, pll_div, OUT4_MIN_PERIOD * 1000);
		localparam outdiv5	= pll_vco_outdivcheck(IN0_PERIOD * 1000, pll_mult, pll_div, OUT5_MIN_PERIOD * 1000);
		
		//If we found a good configuration, use it
		if(pllconfig) begin
			
			//Debug print
			initial begin
				$display("ReconfigurablePLL: Found legal default config: indiv=%d, mult=%d", pll_div, pll_mult);
				
				$display("    outdiv[0] = %d", outdiv0);
				$display("    outdiv[1] = %d", outdiv1);
				$display("    outdiv[2] = %d", outdiv2);
				$display("    outdiv[3] = %d", outdiv3);
				$display("    outdiv[4] = %d", outdiv4);
				$display("    outdiv[5] = %d", outdiv5);
			end
			
			//Instantiate the actual PLL
			MMCME2_ADV #(
		
				//Generic settings
				.BANDWIDTH("OPTIMIZED"),
				
				//TODO: Set dividers
				.CLKOUT0_DIVIDE_F($itor(outdiv0)),
				.CLKOUT1_DIVIDE(outdiv1),
				.CLKOUT2_DIVIDE(outdiv2),
				.CLKOUT3_DIVIDE(outdiv3),
				.CLKOUT4_DIVIDE(outdiv4),
				.CLKOUT5_DIVIDE(outdiv5),
				
				//Set default phases to 0
				.CLKOUT0_PHASE(0.0),
				.CLKOUT1_PHASE(0.0),
				.CLKOUT2_PHASE(0.0),
				.CLKOUT3_PHASE(0.0),
				.CLKOUT4_PHASE(0.0),
				.CLKOUT5_PHASE(0.0),
				
				//Set default duty cycle to 0.5
				.CLKOUT0_DUTY_CYCLE(0.5),
				.CLKOUT1_DUTY_CYCLE(0.5),
				.CLKOUT2_DUTY_CYCLE(0.5),
				.CLKOUT3_DUTY_CYCLE(0.5),
				.CLKOUT4_DUTY_CYCLE(0.5),
				.CLKOUT5_DUTY_CYCLE(0.5),
				
				//Not used
				.CLKOUT6_DIVIDE(1),
				.CLKOUT6_PHASE(0.0),
				.CLKOUT6_DUTY_CYCLE(0.5),
				
				//Default VCO configuration
				.CLKFBOUT_MULT_F($itor(pll_mult)),
				.DIVCLK_DIVIDE(pll_div),
				
				//No feedback clock phase shift
				.CLKFBOUT_PHASE(0),
				
				//Simulation jitter
				.REF_JITTER1(0.01),
				.REF_JITTER2(0.01),
				
				//Input clock periods
				.CLKIN1_PERIOD(IN0_PERIOD),
				.CLKIN2_PERIOD(IN1_PERIOD),
				
				//Fine phase not supported
				.CLKFBOUT_USE_FINE_PS("FALSE"),
				.CLKOUT0_USE_FINE_PS("FALSE"),
				.CLKOUT1_USE_FINE_PS("FALSE"),
				.CLKOUT2_USE_FINE_PS("FALSE"),
				.CLKOUT3_USE_FINE_PS("FALSE"),
				.CLKOUT4_USE_FINE_PS("FALSE"),
				.CLKOUT5_USE_FINE_PS("FALSE"),
				.CLKOUT6_USE_FINE_PS("FALSE"),
				
				//Don't wait for PLL lock during boot
				.STARTUP_WAIT("FALSE"),
				
				//Don't cascade the output
				.CLKOUT4_CASCADE("FALSE"),
				
				//Datasheet says to use this value
				.COMPENSATION("ZHOLD"),
				
				//No spread spectrum
				.SS_EN("FALSE"),
				.SS_MODE("CENTER_HIGH"),
				.SS_MOD_PERIOD(10000)
				
			) mmcm (
				
				//Input clock
				.CLKIN1(clkin[0]),
				.CLKIN2(clkin[1]),
				.CLKINSEL(!clksel),		//HIGH selects CLKIN1 so we need to invert
				
				//Control
				.RST(reset_int),
				.PWRDWN(1'b0),			//TODO: allow using this
				
				//Status
				.LOCKED(locked),
				.CLKINSTOPPED(),
				.CLKFBSTOPPED(),
				
				//Feedback
				.CLKFBIN(clk_feedback),
				.CLKFBOUT(clk_feedback),
				.CLKFBOUTB(),
				
				//Outputs
				.CLKOUT0(clkout_raw[0]),
				.CLKOUT1(clkout_raw[1]),
				.CLKOUT2(clkout_raw[2]),
				.CLKOUT3(clkout_raw[3]),
				.CLKOUT4(clkout_raw[4]),
				.CLKOUT5(clkout_raw[5]),
				
				//Extra outputs (not supported in all chips so we ignore them for now)
				.CLKOUT6(),
				.CLKOUT0B(),
				.CLKOUT1B(),
				.CLKOUT2B(),
				.CLKOUT3B(),
				
				//DRP
				.DCLK(reconfig_clk),
				.DEN(drp_en),
				.DWE(drp_we),
				.DADDR(drp_daddr),
				.DI(drp_din),
				.DO(drp_dout),
				.DRDY(drp_ready),
				
				//Fine phase shift (not implemented)
				.PSCLK(1'b0),
				.PSEN(1'b0),
				.PSINCDEC(1'b0),
				.PSDONE()
			);
			
		end

		//If no valid PLL configurations were found, give up
		else begin
			initial begin
				$display("ReconfigurablePLL: No good PLL settings found");
				$finish;
			end		
		end
		
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helper for read-modify-write operations
	
	localparam	DRP_STATE_IDLE		= 2'h0;
	localparam	DRP_STATE_READ		= 2'h1;
	localparam	DRP_STATE_WRITE		= 2'h2;
	
	reg[1:0]	drp_state	= DRP_STATE_IDLE;
	
	reg			reg_wr				= 0;
	reg			reg_wr_done			= 0;
	reg[6:0]	reg_addr			= 0;
	reg[15:0]	reg_wdata			= 0;
	reg[15:0]	reg_wmask			= 0;
	
	always @(posedge reconfig_clk) begin
		
		//Clear DRP state
		drp_daddr			<= 0;
		drp_en				<= 0;
		drp_we				<= 0;
		drp_din				<= 0;
		
		reg_wr_done			<= 0;
		
		case(drp_state)
			
			//Wait for write request to come in. When it does, read the register
			DRP_STATE_IDLE: begin
				if(reg_wr) begin
					drp_daddr	<= reg_addr;
					drp_en		<= 1;
					drp_state	<= DRP_STATE_READ;
				end
			end
			
			//Wait for read request to finish. When it does, do the write
			DRP_STATE_READ: begin
				if(drp_ready) begin
					drp_en		<= 1;
					drp_we		<= 1;
					drp_daddr	<= reg_addr;
					drp_din		<= (drp_dout & reg_wmask) | (reg_wdata & ~reg_wmask);
					drp_state	<= DRP_STATE_WRITE;
				end
			end
			
			//Wait for write to finish
			DRP_STATE_WRITE: begin
				if(drp_ready) begin
					reg_wr_done	<= 1;
					drp_state	<= DRP_STATE_IDLE;
				end
			end
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Table of ROM entries for PLL lock configuration
	
	//Values from XAPP888
	//TODO: portable paths
	reg[9:0]	pll_lockcnt_rom[63:0];
	reg[4:0]	pll_lockrefdly_rom[63:0];
	reg[7:0]	pll_filter_lowbw[63:0];
	reg[7:0]	pll_filter_highbw[63:0];
	initial begin
		$readmemb("../../../rtl/achd-soc/clock/ReconfigurablePLL_rom_7series_lockcnt.bin", pll_lockcnt_rom);
		$readmemb("../../../rtl/achd-soc/clock/ReconfigurablePLL_rom_7series_lockrefdly.bin", pll_lockrefdly_rom);
		$readmemb("../../../rtl/achd-soc/clock/ReconfigurablePLL_rom_7series_filter_lowbw.bin", pll_filter_lowbw);
		$readmemb("../../../rtl/achd-soc/clock/ReconfigurablePLL_rom_7series_filter_highbw.bin", pll_filter_highbw);
	end
	
	//ROM addresses
	reg[5:0]	vco_romaddr		= 0;
	reg[6:0]	vco_mult_dec	= 0;
	always @(*) begin
		vco_mult_dec	<= reconfig_vco_mult - 6'b1;
		vco_romaddr		<= vco_mult_dec[5:0];
	end
	
	//Filter selection
	reg[7:0]	pll_filter_out_highbw	= 0;
	reg[7:0]	pll_filter_out_lowbw	= 0;
	reg[9:0]	pll_filter_out			= 0;
	always @(*) begin
		pll_filter_out_highbw	<= pll_filter_highbw[vco_romaddr];
		pll_filter_out_lowbw	<= pll_filter_lowbw[vco_romaddr];
		
		if(reconfig_vco_bandwidth)
			pll_filter_out			<= pll_filter_out_highbw;
		else
			pll_filter_out			<= pll_filter_out_lowbw;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Reconfiguration states
	
	localparam	STATE_BOOT_HOLD_0	= 4'h0;			//Waiting for initial configuration to be selected
	localparam	STATE_BOOT_HOLD_1	= 4'h1;			//Still waiting, initial DRP write sent
	localparam	STATE_IDLE			= 4'h2;			//Not reconfiguring
	localparam	STATE_READY			= 4'h3;			//In reconfiguration mode, nothing happening
	localparam	STATE_VCO_0			= 4'h4;			//Do VCO configuration
	localparam	STATE_VCO_1			= 4'h5;
	localparam	STATE_VCO_2			= 4'h6;
	localparam	STATE_VCO_3			= 4'h7;
	localparam	STATE_VCO_4			= 4'h8;
	localparam	STATE_VCO_5			= 4'h9;
	localparam	STATE_VCO_6			= 4'ha;
	localparam	STATE_RDONE			= 4'hb;
	localparam	STATE_OUTDIV_0		= 4'hc;
	
	//Start out waiting for intial reconfiguration	
	reg[3:0]	state		= STATE_BOOT_HOLD_0;
	
	//Register IDs
	localparam	REG_CLKOUT5_CLKREG1		= 7'h06;
	localparam	REG_CLKOUT5_CLKREG2		= 7'h07;
	localparam	REG_CLKOUT0_CLKREG1		= 7'h08;
	localparam	REG_CLKOUT0_CLKREG2		= 7'h09;
	localparam	REG_CLKOUT1_CLKREG1		= 7'h0a;
	localparam	REG_CLKOUT1_CLKREG2		= 7'h0b;
	localparam	REG_CLKOUT2_CLKREG1		= 7'h0c;
	localparam	REG_CLKOUT2_CLKREG2		= 7'h0d;
	localparam	REG_CLKOUT3_CLKREG1		= 7'h0e;
	localparam	REG_CLKOUT3_CLKREG2		= 7'h0f;
	localparam	REG_CLKOUT4_CLKREG1		= 7'h10;
	localparam	REG_CLKOUT4_CLKREG2		= 7'h11;
	localparam	REG_CLKOUT6_CLKREG1		= 7'h12;
	localparam	REG_CLKOUT6_CLKREG2		= 7'h13;
	localparam	REG_CLKFBOUT_CLKREG1	= 7'h14;
	localparam	REG_CLKFBOUT_CLKREG2	= 7'h15;
	localparam	REG_INDIV				= 7'h16;
	localparam	REG_LOCK_1				= 7'h18;
	localparam	REG_LOCK_2				= 7'h19;
	localparam	REG_LOCK_3				= 7'h1a;
	localparam	REG_POWER_CONFIG		= 7'h28;
	localparam	REG_VCO_FILTREG1		= 7'h4e;
	localparam	REG_VCO_FILTREG2		= 7'h4f;
	
	always @(posedge reconfig_clk) begin
		
		//Clear output status flags
		reconfig_cmd_done	<= 0;
	
		//Clear reset flag if we're idle and it's set
		if(state == STATE_IDLE)
			reset_int		<= 0;
		
		//TODO: Consider queueing resets if we're reset during a reconfiguration event?
		
		//Clear write flags
		reg_wr				<= 0;
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Initialization and idle states
			
			//Turn on all power bits
			STATE_BOOT_HOLD_0: begin
				reg_wr			<= 1;
				reg_addr		<= REG_POWER_CONFIG;
				reg_wmask		<= 0;
				reg_wdata		<= 16'hffff;
				state			<= STATE_BOOT_HOLD_1;
			end
			
			//Do nothing until reset or entering reconfig mode
			STATE_BOOT_HOLD_1: begin
				
				//Clear busy flag once DRP write finishes
				if(reg_wr_done)
					busy		<= 0;
				
				//Reset? Jump into default (Fmax on all outputs) state
				if(reset || (ACTIVE_ON_START && !busy))
					state		<= STATE_IDLE;
					
				//Enter reconfig mode if requested
				if(reconfig_start) begin
					state		<= STATE_READY;
					reset_int	<= 1;
				end
				
			end
		
			//Idle, not in reconfig mode
			STATE_IDLE: begin
			
				//External reset just turns into one internal reset cycle
				if(reset)
					reset_int	<= 1;
					
				//Enter reconfig mode if requested
				if(reconfig_start) begin
					state		<= STATE_READY;
					reset_int	<= 1;
				end

			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Main reconfiguration path
			
			//Idle, in reconfig mode
			STATE_READY: begin
			
				//Leave reconfig mode if requested
				if(reconfig_finish)
					state		<= STATE_IDLE;
				
				//Write to the first feedback clock configuration register
				if(reconfig_vco_en) begin
					reg_wr				<= 1;
					reg_addr			<= REG_CLKFBOUT_CLKREG1;

					reg_wmask			<= 16'h1000;				//preserve reserved state
					reg_wdata			<= 0;
					
					reg_wdata[15:13]	<= 0;						//not phase shifting
					reg_wdata[11:6]		<= reconfig_vco_mult[6:1];	//High time (half the multiplier)
					reg_wdata[5:0]		<= reconfig_vco_mult[6:1];	//Low time
					
					//Bump low time by one VCO cycle if multiplier is odd
					//(we'll use the edge flag to true it up to 50% duty cycle)
					if(reconfig_vco_mult[0])
						reg_wdata[5:0]	<= reconfig_vco_mult[6:1] + 6'h1;
					
					state				<= STATE_VCO_0;
					
				end
				
				//Write to the CLKOUT configuration register
				//Writing to channels 6 or 7 is illegal since we don't support channel 6 and there is no channel 7.
				//Writing a divisor outside the legal range is also not checked for here.
				//These tests are the responsibility of the parent module.
				if(reconfig_output_en) begin
				
					//Need a different register ID for each output
					reg_wr				<= 1;
					case(reconfig_output_idx)
						0:				reg_addr	<= REG_CLKOUT0_CLKREG1;
						1:				reg_addr	<= REG_CLKOUT1_CLKREG1;
						2:				reg_addr	<= REG_CLKOUT2_CLKREG1;
						3:				reg_addr	<= REG_CLKOUT3_CLKREG1;
						4:				reg_addr	<= REG_CLKOUT4_CLKREG1;
						5:				reg_addr	<= REG_CLKOUT5_CLKREG1;
					endcase
					
					reg_wmask			<= 16'h1000;					//preserve reserved state
					reg_wdata			<= 0;
					
					//ClkReg1 has the same bit pattern for all of the channels (whew)
					reg_wdata[15:13]	<= 0;							//not phase shifting
					reg_wdata[11:6]		<= reconfig_output_div[6:1];	//High time (half the multiplier)
					reg_wdata[5:0]		<= reconfig_output_div[6:1];	//Low time
					
					//Bump low time by one VCO cycle if multiplier is odd
					//(we'll use the edge flag to true it up to 50% duty cycle)
					if(reconfig_output_div[0])
						reg_wdata[5:0]	<= reconfig_output_div[6:1] + 6'h1;
					
					state				<= STATE_OUTDIV_0;					
				
				end
				
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// VCO reconfiguration
			
			//Write to the second feedback clock configuration register
			STATE_VCO_0: begin
				if(reg_wr_done) begin
					reg_wr				<= 1;
					reg_addr			<= REG_CLKFBOUT_CLKREG2;					
					reg_wmask			<= 16'h8000;					//preserve reserved state
					reg_wdata			<= 0;
					
					reg_wdata[14:12]	<= 0;							//not using fractional divide
					reg_wdata[11]		<= 0;							//Not using fractional divide
					reg_wdata[10]		<= 0;							//Fractional WF_R (ignore)
					reg_wdata[9:8]		<= 0;							//MX, reserved - must be zero
					reg_wdata[7]		<= reconfig_vco_mult[0];		//flip VCO clock edge for odd duty cycles
					reg_wdata[6]		<= (reconfig_vco_mult == 1);	//Skip counters if multiplying by 1
					reg_wdata[5:0]		<= 0;							//No phase offset in feedback
					
					state				<= STATE_VCO_1;
				end
			end
			
			//Write to the input divide register
			STATE_VCO_1: begin
				if(reg_wr_done) begin
					reg_wr				<= 1;
					reg_addr			<= REG_INDIV;
					reg_wmask			<= 16'hc000;					//preserve reserved state
					reg_wdata			<= 0;
					
					reg_wdata[13]		<= reconfig_vco_indiv[0];		//toggle edge
					reg_wdata[12]		<= (reconfig_vco_indiv == 1);	//Skip counters if dividing by 1
					reg_wdata[11:6]		<= reconfig_vco_indiv[6:1];		//High time (half the divider)
					reg_wdata[5:0]		<= reconfig_vco_indiv[6:1];		//Low time (half the divider)
					
					//Bump low time by one VCO cycle if divider is odd
					//(we'll use the edge flag to true it up to 50% duty cycle)
					if(reconfig_vco_indiv[0])
						reg_wdata[5:0]	<= reconfig_vco_indiv[6:1] + 6'h1;	
					
					state				<= STATE_VCO_2;
				end
			end
			
			//Write to the first lock register
			STATE_VCO_2: begin
				if(reg_wr_done) begin
					reg_wr				<= 1;
					reg_addr			<= REG_LOCK_1;
					reg_wmask			<= 16'hfc00;						//preserve reserved state
					reg_wdata			<= 0;
					
					reg_wdata[9:0]		<= pll_lockcnt_rom[vco_romaddr];	//magic LockCnt values from XAPP888
					
					state				<= STATE_VCO_3;
				end
			end
			
			//Write to the second lock register
			STATE_VCO_3: begin
				if(reg_wr_done) begin
					reg_wr				<= 1;
					reg_addr			<= REG_LOCK_2;
					reg_wmask			<= 16'h8000;						//preserve reserved state
					reg_wdata			<= 0;
					
					reg_wdata[14:10]	<= pll_lockrefdly_rom[vco_romaddr];	//magic LockFBDly value from XAPP888
																			//LockFBDly and LockRefDly are same data
					reg_wdata[9:0]		<= 10'd1;							//magic UnlockCnt value from XAPP888
					
					state				<= STATE_VCO_4;
				end
			end
			
			//Write to the third lock register
			STATE_VCO_4: begin
				if(reg_wr_done) begin
					reg_wr				<= 1;
					reg_addr			<= REG_LOCK_3;
					reg_wmask			<= 16'h8000;						//preserve reserved state
					reg_wdata			<= 0;
					
					reg_wdata[14:10]	<= pll_lockrefdly_rom[vco_romaddr];	//magic LockRefDly value from XAPP888
					reg_wdata[9:0]		<= 10'b1111101001;					//magic LockSatHigh value from XAPP888
					
					state				<= STATE_VCO_5;
				end
			end
			
			//Write to the first filter register
			STATE_VCO_5: begin
				if(reg_wr_done) begin	
					reg_wr				<= 1;
					reg_addr			<= REG_VCO_FILTREG1;
					reg_wmask			<= 16'h66ff;						//preserve reserved state
					reg_wdata			<= 0;
				
					reg_wdata[15]		<= pll_filter_out[7];				//Magic CP value from XAPP888
					reg_wdata[12:11]	<= pll_filter_out[6:5];
					reg_wdata[8]		<= pll_filter_out[4];

					state				<= STATE_VCO_6;
				end
			end
			
			//Write to the second filter register
			STATE_VCO_6: begin
				if(reg_wr_done) begin
					reg_wr				<= 1;
					reg_addr			<= REG_VCO_FILTREG2;
					reg_wmask			<= 16'h666f;						//preserve reserved state
					reg_wdata			<= 0;
				
					reg_wdata[15]		<= pll_filter_out[3];				//Magic RES value from XAPP888
					reg_wdata[12:11]	<= pll_filter_out[2:1];
					reg_wdata[8]		<= pll_filter_out[0];
					
					//LFHF bits are always zero regardless so no ROM needed

					state				<= STATE_RDONE;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Output divisor reconfiguration
			
			STATE_OUTDIV_0: begin
				
				if(reg_wr_done) begin
			
					//Always writing to a register, default it to empty
					reg_wr					<= 1;
					reg_wdata				<= 0;

					//These bits are the same in all registers
					reg_wdata[9:8]			<= 0;							//reserved, must be zero
					reg_wdata[7]			<= reconfig_output_div[0];		//flip VCO clock edge for odd duty cycles
					reg_wdata[6]			<= (reconfig_output_div == 1);	//disable counter for divide-by-1
					reg_wdata[5:0]			<= 0;							//no phase offset
				
					//Sadly, Xilinx decided to screw with us and make the registers not all the same layout!
					case(reconfig_output_idx)
					
						0: begin
							reg_addr			<= REG_CLKOUT0_CLKREG2;
							reg_wmask			<= 16'h8000;
							reg_wdata[14:12]	<= 0;							//not using fractional divide				
							reg_wdata[11]		<= 0;							//not using fractional divide
							reg_wdata[10]		<= 0;							//not using fractional divide
						end
						
						1: begin
							reg_addr			<= REG_CLKOUT1_CLKREG2;
							reg_wmask			<= 16'hfc00;
						end
						
						2: begin
							reg_addr			<= REG_CLKOUT2_CLKREG2;
							reg_wmask			<= 16'hfc00;
						end
						
						3: begin
							reg_addr			<= REG_CLKOUT3_CLKREG2;
							reg_wmask			<= 16'hfc00;
						end
						
						4: begin
							reg_addr			<= REG_CLKOUT4_CLKREG2;
							reg_wmask			<= 16'hfc00;
						end
						
						5: begin
							reg_addr			<= REG_CLKOUT5_CLKREG2;
							reg_wmask			<= 16'hc000;
							reg_wdata[13:11]	<= 0;							//no initial phase offset
							reg_wdata[10]		<= 0;							//not using fractional for CLKOUT0
						end
					
					endcase

					//Either way, we're done after this
					state					<= STATE_RDONE;
					
				end
				
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Helper states
			
			//Wait for the current reconfig op to complete, then tell the host
			STATE_RDONE: begin
				if(reg_wr_done) begin
					state					<= STATE_READY;
					reconfig_cmd_done		<= 1;
				end
			end
		
		endcase
	
	end
	
endmodule

