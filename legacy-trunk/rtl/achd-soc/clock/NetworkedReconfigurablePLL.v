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
	@brief Implementation of NetworkedReconfigurablePLL
	
	At build time, we need to statically specify the worst-case timing performance of each output.
	This is necessary to both enforce runtime restrictions (disable overclocking) and allow accurate
	static timing analysis.
	
	The ACTIVE_ON_START parameter allows the PLL to start in the running state at maximum frequency (1) or the stopped
	state, waiting for a reconfiguration event (0). Note that ACTIVE_ON_START must be 1 if clk_noc is sourced by this
	PLL or the system will fail to boot.
	
	The basic reconfiguration flow is as follows:
		Call PLL_OP_RECONFIG to change configuration for one output at a time.
			Changes are deferred and do not take effect immediately.
		Call PLL_OP_RESTART to apply the new configuration and restart the PLL.
			If the reconfiguration fails due to invalid parameters (frequency out of range, or output frequency
			combination not satisfiable) the PLL will continue to operate using the old settings and not lose lock.
	
	@module
	@brief			Bridge between RAM-buffered and streaming DMA
	@opcodefile		NetworkedReconfigurablePLL_opcodes.constants
	
	@rpcfn			PLL_OP_NOP
	@brief			Do nothing
	
	@rpcfn			PLL_OP_RECONFIG
	@brief			Set the new configuration for an output.
	@param			channel		d0[12:10]:dec	The channel to reconfigure (0-5)
	@param			tolerance	d0[9:0]:dec		The tolerance, in picoseconds, allowed between the requested
													and actual clock periods.
	@param			period		d1[31:0]:time	The desired clock period, in picoseconds
	Control of duty cycle and phase are not currently implemented.
	
	@rpcfn_ok		PLL_OP_RECONFIG
	@brief			New settings saved and will be applied next restart
	
	@rpcfn_fail		PLL_OP_RECONFIG
	@param			errcode		d0[7:0]:enum	NetworkedReconfigurablePLL_errcodes.constants
	@brief			New settings are out of range and cannot be used
	
	@rpcfn			PLL_OP_RESTART
	@brief			Restarts the PLL using the new configuration
	
	@rpcfn_ok		PLL_OP_RESTART
	@brief			PLL successfully restarted using new configuration
	
	@rpcfn_fail		PLL_OP_RESTART
	@brief			PLL could not be reconfigured (settings are not satisfiable)
	
	TODO: Add option to read back VCO and output settings?
 */
module NetworkedReconfigurablePLL(
	clk,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	
	//Input clocks
	clk_in, clk_reconfig,
	
	//Output clocks
	clk_out0, clk_out1, clk_out2, clk_out3, clk_out4, clk_out5
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;				//NoC clock
	input wire clk_in;			//Input clock (only one supported for now)
	input wire clk_reconfig;	//Reconfiguration clock (must be stable and not sourced by this PLL, and <=200 MHz)
	
	//Output clocks
	output wire		clk_out0;
	output wire		clk_out1;
	output wire		clk_out2;
	output wire		clk_out3;
	output wire		clk_out4;
	output wire		clk_out5;
	
	//NoC interface
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;
	
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
	parameter			IN_PERIOD			= 50.0;		//50 ns = 20 MHz
	
	//MINIMUM clock periods for the outputs, used for static timing.
	//Attempts to change below this will give an error.
	parameter			OUT0_MIN_PERIOD		= 5.000;
	parameter			OUT1_MIN_PERIOD		= 5.000;
	parameter			OUT2_MIN_PERIOD		= 5.000;
	parameter			OUT3_MIN_PERIOD		= 5.000;
	parameter			OUT4_MIN_PERIOD		= 5.000;
	parameter			OUT5_MIN_PERIOD		= 5.000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR			= 16'h0000;
	
	reg			rpc_slave_tx_en 		= 0;
	reg[15:0]	rpc_slave_tx_dst_addr	= 0;
	reg[7:0]	rpc_slave_tx_callnum	= 0;
	reg[2:0]	rpc_slave_tx_type		= 0;
	reg[20:0]	rpc_slave_tx_d0			= 0;
	reg[31:0]	rpc_slave_tx_d1			= 0;
	reg[31:0]	rpc_slave_tx_d2			= 0;
	wire		rpc_slave_tx_done;
	
	wire		rpc_slave_rx_en;
	wire[15:0]	rpc_slave_rx_src_addr;
	wire[15:0]	rpc_slave_rx_dst_addr;
	wire[7:0]	rpc_slave_rx_callnum;
	//slave rx type is always RPC_TYPE_CALL
	wire[20:0]	rpc_slave_rx_d0;
	wire[31:0]	rpc_slave_rx_d1;
	wire[31:0]	rpc_slave_rx_d2;
	reg			rpc_slave_rx_done		= 0;
	wire		rpc_slave_inbox_full;
	
	RPCv2MasterSlave #(
		.LEAF_ADDR(NOC_ADDR),
		.DROP_MISMATCH_CALLS(1)
	) rpc_txvr (
		//NoC interface
		.clk(clk),
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		//Master interface (not used for now)
		.rpc_master_tx_en(1'b0),
		.rpc_master_tx_dst_addr(16'h0),
		.rpc_master_tx_callnum(8'h0),
		.rpc_master_tx_type(RPC_TYPE_CALL),
		.rpc_master_tx_d0(21'h0),
		.rpc_master_tx_d1(32'h0),
		.rpc_master_tx_d2(32'h0),
		.rpc_master_tx_done(),
		
		.rpc_master_rx_en(),
		.rpc_master_rx_src_addr(),
		.rpc_master_rx_dst_addr(),
		.rpc_master_rx_callnum(),
		.rpc_master_rx_type(),
		.rpc_master_rx_d0(),
		.rpc_master_rx_d1(),
		.rpc_master_rx_d2(),
		.rpc_master_rx_done(1'b1),
		.rpc_master_inbox_full(),
		
		//Slave interface
		.rpc_slave_tx_en(rpc_slave_tx_en),
		.rpc_slave_tx_dst_addr(rpc_slave_tx_dst_addr),
		.rpc_slave_tx_callnum(rpc_slave_tx_callnum),
		.rpc_slave_tx_type(rpc_slave_tx_type),
		.rpc_slave_tx_d0(rpc_slave_tx_d0),
		.rpc_slave_tx_d1(rpc_slave_tx_d1),
		.rpc_slave_tx_d2(rpc_slave_tx_d2),
		.rpc_slave_tx_done(rpc_slave_tx_done),
		
		.rpc_slave_rx_en(rpc_slave_rx_en),
		.rpc_slave_rx_src_addr(rpc_slave_rx_src_addr),
		.rpc_slave_rx_dst_addr(rpc_slave_rx_dst_addr),
		.rpc_slave_rx_callnum(rpc_slave_rx_callnum),
		.rpc_slave_rx_d0(rpc_slave_rx_d0),
		.rpc_slave_rx_d1(rpc_slave_rx_d1),
		.rpc_slave_rx_d2(rpc_slave_rx_d2),
		.rpc_slave_rx_done(rpc_slave_rx_done),
		.rpc_slave_inbox_full(rpc_slave_inbox_full)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual PLL core
	
	reg			pll_reset			= 1;
	wire		pll_locked;
	wire		reconfig_busy;
	reg			reconfig_start		= 0;
	reg			reconfig_finish		= 0;
	wire		reconfig_cmd_done;
	reg			reconfig_vco_en		= 0;
	reg[6:0]	reconfig_vco_mult	= 0;
	reg[6:0]	reconfig_vco_indiv	= 0;
	reg			reconfig_output_en	= 0;
	reg[2:0]	reconfig_output_idx	= 0;
	reg[7:0]	reconfig_output_div	= 0;
	
	//Set this to a nonzero value to make the PLL start automatically upon powerup.
	//Setting this to zero will cause the PLL to wait for a reconfiguration event.
	parameter ACTIVE_ON_START		= 1;
	
	ReconfigurablePLL #(
		.OUTPUT_GATE(6'b111111),		//gate all outputs until locked
		.OUTPUT_BUF_GLOBAL(6'b111111),	//use BUFGs
		.OUTPUT_BUF_LOCAL(6'b000000),	//do not use BUFHs
		.IN0_PERIOD(IN_PERIOD),
		.IN1_PERIOD(IN_PERIOD),
		.OUT0_MIN_PERIOD(OUT0_MIN_PERIOD),
		.OUT1_MIN_PERIOD(OUT1_MIN_PERIOD),
		.OUT2_MIN_PERIOD(OUT2_MIN_PERIOD),
		.OUT3_MIN_PERIOD(OUT3_MIN_PERIOD),
		.OUT4_MIN_PERIOD(OUT4_MIN_PERIOD),
		.OUT5_MIN_PERIOD(OUT5_MIN_PERIOD),
		.ACTIVE_ON_START(ACTIVE_ON_START)
	) pll (
		.clkin({1'b0, clk_in}),		//only one input clock supported for now
		.clksel(1'b0),				//use it
		.clkout({clk_out5, clk_out4, clk_out3, clk_out2, clk_out1, clk_out0}),	//Output clocks
		.reset(pll_reset),
		.locked(pll_locked),
		.busy(reconfig_busy),
		.reconfig_clk(clk_reconfig),
		.reconfig_start(reconfig_start),
		.reconfig_finish(reconfig_finish),
		.reconfig_cmd_done(reconfig_cmd_done),
		.reconfig_vco_en(reconfig_vco_en),
		.reconfig_vco_mult(reconfig_vco_mult),
		.reconfig_vco_indiv(reconfig_vco_indiv),
		.reconfig_vco_bandwidth(1'b1),						//Always use high/optimized bandwidth
		.reconfig_output_en(reconfig_output_en),
		.reconfig_output_idx(reconfig_output_idx),
		.reconfig_output_div(reconfig_output_div)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Internal state describing the next desired PLL configuration.
	// Note that this may not accurately describe the *current* PLL configuration.
	// As of now, there is no way to query the actual current configuration.
	
	//The target period for each output clock, in ps.
	//Default to 5 ns for now.
	reg[31:0] target_period[7:0];
	
	//The target tolerance for each output clock, in ps.
	//Default to 100ps (+/- 2%) for now
	reg[9:0] target_tolerance[7:0];
	
	//The minimum legal period for each output clock, in ps
	reg[63:0] min_legal_period[7:0];
	
	integer i;
	initial begin
		
		//Set defaults
		for(i=0; i<8; i=i+1) begin
			target_period[i]	<= 5000;
			target_tolerance[i]	<= 100;
		end
		
		//Min legal period is a constant and will be optimized out
		//Set it to a massive (above the PLL's max period) value for unused ports to error check
		min_legal_period[0]	<= OUT0_MIN_PERIOD * 1000;
		min_legal_period[1]	<= OUT1_MIN_PERIOD * 1000;
		min_legal_period[2]	<= OUT2_MIN_PERIOD * 1000;
		min_legal_period[3]	<= OUT3_MIN_PERIOD * 1000;
		min_legal_period[4]	<= OUT4_MIN_PERIOD * 1000;
		min_legal_period[5]	<= OUT5_MIN_PERIOD * 1000;
		min_legal_period[6]	<= 32'hffffffff;
		min_legal_period[7]	<= 32'hffffffff;
		
	end
	
	//Current settings being tested
	reg[6:0]	multiplier		= 0;
	reg[6:0]	indiv			= 0;
	reg[31:0]	vco_period		= 0;
	reg[2:0]	test_channel	= 0;
	reg[7:0]	outdiv[7:0];
	initial begin
		for(i=0; i<7; i=i+1)
			outdiv[i]	<= 1;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Synchronizers between the NoC and reconfiguration clock domains
	
	reg		do_reconfig		= 0;
	wire	do_reconfig_sync;
	reg		reconfig_done	= 0;
	wire	reconfig_done_sync;
	
	HandshakeSynchronizer sync_reconfig(
		.clk_a(clk),			.en_a(do_reconfig),			.ack_a(reconfig_done_sync),	.busy_a(),
		.clk_b(clk_reconfig),	.en_b(do_reconfig_sync),	.ack_b(reconfig_done));
		
	wire	pll_locked_sync;
	ThreeStageSynchronizer sync_pll_locked(
		.clk_in(clk_reconfig), .din(pll_locked),
		.clk_out(clk_reconfig), .dout(pll_locked_sync));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Core reconfiguration logic using separate clock
	
	`include "NetworkedReconfigurablePLL_rstates_constants.v"
	
	reg[3:0]	rstate		= RSTATE_BOOT_HOLD;
	
	always @(posedge clk_reconfig) begin
		
		reconfig_done		<= 0;
		reconfig_start		<= 0;
		reconfig_finish		<= 0;
		reconfig_vco_en		<= 0;
		reconfig_output_en	<= 0;
		
		case(rstate)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Hold in reset until we get reconfigured
		
			RSTATE_BOOT_HOLD: begin
				
				//stay in reset
			
				if(ACTIVE_ON_START) begin
					pll_reset	<= 0;
					rstate		<= RSTATE_IDLE;
				end
				
				if(do_reconfig_sync)
					rstate		<= RSTATE_START;
				
			end	//end RSTATE_BOOT_HOLD
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for reconfiguration requests
			
			RSTATE_IDLE: begin
			
				if(do_reconfig_sync)
					rstate		<= RSTATE_START;
				
			end	//end RSTATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Main reconfiguration path
			
			//Start the reconfiguration
			RSTATE_START: begin
				if(!reconfig_busy) begin
					reconfig_start	<= 1;
					rstate			<= RSTATE_VCO;
				end
			end	//end RSTATE_START
			
			//Reconfigure the VCO
			RSTATE_VCO: begin
				reconfig_vco_en		<= 1;
				reconfig_vco_indiv	<= indiv;
				reconfig_vco_mult	<= multiplier;
				rstate				<= RSTATE_OUTPUT_0;
			end	//end RSTATE_VCO
			
			//Prepare to reconfigure outputs
			RSTATE_OUTPUT_0: begin
				if(reconfig_cmd_done) begin
					reconfig_output_idx	<= 0;
					rstate				<= RSTATE_OUTPUT_1;
				end
			end	//end RSTATE_OUTPUT_0
			
			//Reconfigure the current output
			RSTATE_OUTPUT_1: begin
				reconfig_output_en		<= 1;
				reconfig_output_div		<= outdiv[reconfig_output_idx];
				rstate					<= RSTATE_OUTPUT_2;
			end	//end RSTATE_OUTPUT_1
			
			//Wait for reconfiguration to complete
			RSTATE_OUTPUT_2: begin
				if(reconfig_cmd_done) begin
					
					//Done? Finish up
					if(reconfig_output_idx == 3'd5) begin
						reconfig_finish	<= 1;
						rstate			<= RSTATE_WAIT_FOR_LOCK;
					end
					
					//Nope, do the next one
					else begin
						reconfig_output_idx	<= reconfig_output_idx + 3'h1;
						rstate				<= RSTATE_OUTPUT_1;
					end
					
				end
			end	//end RSTATE_OUTPUT_2
			
			//Wait for the PLL to lock before we return
			RSTATE_WAIT_FOR_LOCK: begin
				if(pll_locked_sync) begin
					reconfig_done	<= 1;
					rstate			<= RSTATE_IDLE;
				end
			end	//end RSTATE_WAIT_FOR_LOCK
		
		endcase

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multiplier and divider (used for calculating VCO settings)
	
	reg			divstart = 0;
	wire[31:0]	quot;
	wire[31:0]	rem;
	reg[31:0]	dend	= 0;
	reg[31:0]	dvsr	= 0;
	wire		divdone;
	
	UnsignedNonPipelinedDivider divider(
		.clk(clk),
		.start(divstart),
		.dend(dend),
		.dvsr(dvsr),
		.quot(quot),
		.rem(rem),
		.busy(),
		.done(divdone));
		
	reg			mult_start	= 0;
	reg[31:0]	mult_a		= 0;
	reg[31:0]	mult_b		= 0;
	(* MULT_STYLE = "PIPE_BLOCK" *)
	reg[31:0]	mult_out1	= 0;
	reg[31:0]	mult_out2	= 0;
	reg[31:0]	mult_out3	= 0;
	reg			mult_done1	= 0;
	reg			mult_done2	= 0;
	reg			mult_done3	= 0;
	
	always @(posedge clk) begin
		mult_done1	<= mult_start;
		mult_done2	<= mult_done1;
		mult_done3	<= mult_done2;
		mult_out1	<= mult_a * mult_b;
		mult_out2	<= mult_out1;
		mult_out3	<= mult_out2;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC bridge logic for reconfiguration
	
	//Initial setup stuff runs in the NoC clock domain.
	//This is OK even if we source clk_noc, since we still have the output toggling at this point.
	
	`include "ReconfigurablePLL_limits.vh"
	`include "NetworkedReconfigurablePLL_opcodes_constants.v"
	`include "NetworkedReconfigurablePLL_errcodes_constants.v"
	`include "NetworkedReconfigurablePLL_states_constants.v"
	
	reg[3:0]	state	= STATE_IDLE;
	
	//Shorthand names for a few bitfields
	wire[2:0]	rx_selected_channel		= rpc_slave_rx_d0[12:10];
	wire[63:0]	raw_selected_period		= min_legal_period[rx_selected_channel];
	wire[31:0]	min_selected_period		= raw_selected_period[31:0];
	wire[31:0]	test_tolerance			= target_tolerance[test_channel];
	
	//Saved input clock frequency
	parameter	in_period		= 5000;	//Period, in ps, of clk_in
	
	//VCO period minus remainder
	reg[31:0]	overshoot_delta			= 0;
	
	//Incremented quotients
	reg[31:0]	quotp1					= 0;
	wire[7:0]	quot_inc				= quotp1[7:0];
	
	always @(posedge clk) begin
		
		rpc_slave_tx_en		<= 0;
		rpc_slave_rx_done	<= 0;
		divstart			<= 0;
		mult_start			<= 0;
		do_reconfig			<= 0;
		
		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Main dispatch state, wait for stuff to happen
			
			STATE_IDLE: begin
			
				if(rpc_slave_inbox_full) begin
					
					//Default response
					rpc_slave_tx_callnum	<= rpc_slave_rx_callnum;
					rpc_slave_tx_dst_addr	<= rpc_slave_rx_src_addr;
					rpc_slave_tx_d0			<= 0;
					rpc_slave_tx_d1			<= 0;
					rpc_slave_tx_d2			<= 0;
					rpc_slave_tx_type		<= RPC_TYPE_RETURN_FAIL;
					
					//Look up what it is
					case(rpc_slave_rx_callnum)
						
						//just always succeed, do nothing
						PLL_OP_NOP: begin
							rpc_slave_rx_done		<= 1;
							rpc_slave_tx_en			<= 1;
							rpc_slave_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
							state					<= STATE_RPC_TXHOLD;
						end
						
						//Save new config settings
						PLL_OP_RECONFIG: begin
						
							//Assume success for now
							//Either way, we're sending a message
							rpc_slave_tx_en			<= 1;
							rpc_slave_rx_done		<= 1;
							state					<= STATE_RPC_TXHOLD;
						
							//Check periods to make sure they're valid
							if(rpc_slave_rx_d1 > pll_output_max_period(`XILINX_SPEEDGRADE)) begin
								rpc_slave_tx_d0		<= PLL_ERR_TOOSLOW;
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							end
							else if(rpc_slave_rx_d1 < pll_output_min_period(`XILINX_SPEEDGRADE)) begin
								rpc_slave_tx_d0		<= PLL_ERR_TOOFAST;
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							end
							else if(rpc_slave_rx_d1 < min_selected_period) begin
								rpc_slave_tx_d0		<= PLL_ERR_TOOFAST2;
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							end
							
							//Check that the channel number is valid
							else if(rx_selected_channel >= 6) begin
								rpc_slave_tx_d0		<= PLL_ERR_BADCHAN;
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							end
							
							//Everything is good, save these settings
							else begin
								target_period[rx_selected_channel]		<= rpc_slave_rx_d1;
								target_tolerance[rx_selected_channel]	<= rpc_slave_rx_d0[9:0];
								rpc_slave_tx_type						<= RPC_TYPE_RETURN_SUCCESS;
							end
							
						end
						
						//Go into restart mode
						PLL_OP_RESTART: begin
							rpc_slave_rx_done		<= 1;
							state					<= STATE_RESTART_0;
							multiplier				<= 1;
							indiv					<= 1;
						end
						
						//fail
						default: begin
							rpc_slave_rx_done		<= 1;
							rpc_slave_tx_en			<= 1;
							state					<= STATE_RPC_TXHOLD;
						end
						
					endcase
					
				end
			
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Main reconfiguration path

			//Compute the VCO period for the current settings
			//VCO period = input period * input divisor / multiplier
			STATE_RESTART_0: begin
				mult_a		<= in_period;
				mult_b		<= indiv;
				mult_start	<= 1;
				state		<= STATE_RESTART_1;
			end	//end STATE_RESTART_0
			
			STATE_RESTART_1: begin
				if(mult_done3) begin
					divstart	<= 1;
					dend		<= mult_out3;
					dvsr		<= multiplier;
					state		<= STATE_RESTART_2;
				end
			end	//end STATE_RESTART_1
			
			//When division completes, check the period.
			//If it's not legal, try the next setting.
			//If it is legal, compute the PFD frequency.
			STATE_RESTART_2: begin
				if(divdone) begin
					vco_period	<= quot;
					
					//VCO period out of range, try the next settings
					if( (quot > pll_vco_max_period(`XILINX_SPEEDGRADE)) ||
						(quot < pll_vco_min_period(`XILINX_SPEEDGRADE)) ) begin
						
						state		<= STATE_RESTART_NEXT;
						
					end
					
					//VCO period is good, compute PFD frequency
					else begin
						mult_a		<= quot;
						mult_b		<= multiplier;
						mult_start	<= 1;
						state		<= STATE_RESTART_3;
					end
					
				end
			end	//end STATE_RESTART_2
			
			//Check the PFD frequency
			STATE_RESTART_3: begin
				if(mult_done3) begin
					
					//Don't save PFD frequency as we don't need to do anything with it
					//other than verify it's good
					
					//PFD period out of range, try the next settings
					if( (mult_out3 > pll_pfd_max_period(`XILINX_SPEEDGRADE)) ||
						(mult_out3 < pll_pfd_min_period(`XILINX_SPEEDGRADE)) ) begin
						
						state			<= STATE_RESTART_NEXT;
						
					end
					
					//PFD period is good! Need to try testing the outputs and see if they're all usable		
					else begin
						test_channel	<= 0;
						state			<= STATE_RESTART_4;
					end
					
				end
			end	//end STATE_RESTART_3
			
			//Try the current output and see if we can generate a frequency within tolerance
			//using the current VCO frequency.
			//Start by finding the first-guess output divisor
			STATE_RESTART_4: begin
				divstart	<= 1;
				dend		<= target_period[test_channel];
				dvsr		<= vco_period;
				state		<= STATE_RESTART_5;
			end	//end STATE_RESTART_4
			
			//We now have the initial divisor and remainder.
			STATE_RESTART_5: begin
				if(divdone) begin
				
					//If it's too big, the target frequency is impossible to achieve.
					//Don't bother testing other outputs
					if(quot > pll_outdiv_max(`XILINX_SPEEDGRADE)) begin
						state		<= STATE_RESTART_NEXT;
					end
					
					//Divisor is plausible. Determine if the target frequency is within tolerance.
					//Save this value as our divisor for now
					else begin
						overshoot_delta			<= vco_period - rem;
						quotp1					<= quot + 32'h1;
						state					<= STATE_RESTART_6;
						outdiv[test_channel]	<= quot[7:0];
					end
				end
			end	//end STATE_RESTART_5
			
			STATE_RESTART_6: begin
			
				//If remainder is less than tolerance, this setting is good.
				//Save the quotient as our output divider and try the next output
				if(rem <= test_tolerance)
					state					<= STATE_RESTART_NOUT;	
				
				//If remainder is greater than tolerance, try to err high
				else if( (overshoot_delta <= test_tolerance) &&
						 (quot_inc <= pll_outdiv_max(`XILINX_SPEEDGRADE)) ) begin
					outdiv[test_channel]	<= quot_inc;
					state					<= STATE_RESTART_NOUT;
				end
				
				//Unsatisfiable, try the next VCO configuration
				else begin
					state		<= STATE_RESTART_NEXT;
				end
			end	//end STATE_RESTART_6
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for reconfiguration to finish. When it does, return success
			
			STATE_RESTART_WAIT: begin
				if(reconfig_done_sync) begin
					rpc_slave_tx_type	<= RPC_TYPE_RETURN_SUCCESS;
					rpc_slave_tx_en		<= 1;
					state				<= STATE_RPC_TXHOLD;
				end
			end	//end STATE_RESTART_WAIT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Incrementer helpers for reconfiguration
			
			//Current VCO configuration seems satisfiable. Try the next output
			STATE_RESTART_NOUT: begin
				
				//We've tried all outputs! Current settings work, do the reconfiguration
				if(test_channel == 5) begin
					state			<= STATE_RESTART_WAIT;
					do_reconfig		<= 1;
				end
				
				//Nope, try the next channel
				else begin
					test_channel	<= test_channel + 3'd1;
					state			<= STATE_RESTART_4;
				end
			end
			
			//Try the next VCO settings or quit if none are available
			STATE_RESTART_NEXT: begin
				//No wrap? Bump multiplier
				if(multiplier < pll_mult_max(`XILINX_SPEEDGRADE)) begin
					multiplier	<= multiplier + 7'd1;
					state		<= STATE_RESTART_0;
				end
				
				//Wrap multiplier and bump divisor
				else if(indiv < pll_indiv_max(`XILINX_SPEEDGRADE)) begin
					multiplier	<= 1;
					indiv		<= indiv + 7'd1;
					state		<= STATE_RESTART_0;
				end
				
				//Not satisfiable, we couldn't find any good settings
				//Already defaulted to a fail message, so just send it
				else begin
					rpc_slave_tx_en	<= 1;
					state			<= STATE_RPC_TXHOLD;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// NoC helpers
			
			STATE_RPC_TXHOLD: begin
				if(rpc_slave_tx_done)
					state		<= STATE_IDLE;
			end	//end STATE_RPC_TXHOLD
		
		endcase
		
	end
	
endmodule
