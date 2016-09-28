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
	@brief Controller for the output stages
	
	The following RPC operations are available:
		-------------------------------------------------------
		OUTSTAGE_POWER_STATE	Set channel power state.
								Setting a channel to "off" when it's in "error-disable" state clears the error bit.
		-------------------------------------------------------
			Parameters:			d0[3:0] = channel number
								d1[0] = enable bit
			Returns:			Success
		
		-------------------------------------------------------	
		OUTSTAGE_INRUSH_TIME	Sets the inrush timer.
								For X clock cycles after a channel is switched to the "on" state,
								soft overcurrent protection is disabled.
		-------------------------------------------------------
			Parameters:			d0[3:0] = channel number
								d1[23:0] = timer value
			Returns:			Success
			
		-------------------------------------------------------	
		OUTSTAGE_GET_STATUS		Gets the status of an output channel
		-------------------------------------------------------
			Parameters:			d0[3:0] = channel number
			Returns:			d0[0] = enable bit
								d0[1] = overcurrent bit
 */
module OutputStageController(
	
	//Clocks
	clk,
	
	//Output enables
	pwr_oe,
	
	//Overcurrent inputs
	oc_alert,
	
	//Indicator LEDs
	pwr_leds, error_leds,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//Power enables and overcurrent inputs
	output reg[9:0] pwr_oe = 0;
	input wire[9:0] oc_alert;
	
	//Indicator LEDs
	output wire[9:0] pwr_leds;
	output reg[9:0] error_leds = 0;
	assign pwr_leds = pwr_oe;
	
	//NoC interface
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR = 16'h0000;
	
	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;
	
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	reg			rpc_fab_rx_done		= 0;
	
	RPCv2Transceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(NOC_ADDR)
	) txvr(
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(16'h0000),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full()
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Synchronizers for overcurrent alerts
		
	wire[9:0] oc_alert_sync;
		
	//oc_alert
	genvar j;
	generate
		for(j=0; j<10; j = j+1) begin: syncblock
			ThreeStageSynchronizer sync(
				.clk_in(clk),
				.din(oc_alert[j]),
				.clk_out(clk),
				.dout(oc_alert_sync[j])
				);
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "OutputStageController_opcodes_constants.v"
	
	localparam STATE_IDLE 			= 0;
	localparam STATE_RPC_TXHOLD		= 1;
	
	integer i;
	
	//The channel number of an incoming message
	wire[3:0] chnum = rpc_fab_rx_d0[3:0];
	
	//Inrush timer max values
	(* RAM_STYLE = "block" *) reg[23:0] inrush_timer_max[15:0];
	(* RAM_STYLE = "block" *) reg[23:0] inrush_timer_count[15:0];
	initial begin
		for(i=0; i<10; i=i+1) begin
			inrush_timer_max[i] <= 0;
			inrush_timer_count[i] <= 0;
		end
		
		//do not initialize or use inrush_timer_max/count [15:10], they'll be optimized out
		//but are necessary to avoid a compiler warning about non-power-of-two memories.
	end
	
	reg[3:0] overcurrent_check_index		= 0;
	reg[3:0] overcurrent_check_index_buf	= 0;
	reg[23:0] inrush_timer_count_out		= 0;
	
	//Write logic for inrush timer
	reg[3:0]	inrush_timer_count_waddr	= 0;
	reg[23:0]	inrush_timer_count_wdata	= 0;
	reg			inrush_timer_count_we		= 0;
	always @(posedge clk) begin
		if(inrush_timer_count_we)
			inrush_timer_count[inrush_timer_count_waddr] <= inrush_timer_count_wdata;
	end
	
	//Read logic for inrush timer
	always @(posedge clk) begin
		overcurrent_check_index_buf <= overcurrent_check_index;
		inrush_timer_count_out <= inrush_timer_count[overcurrent_check_index];
	end
	
	reg[3:0] state = STATE_IDLE;
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		
		//Inrush processing and overcurrent detection.
		inrush_timer_count_we <= 0;
		
		//TODO: do 16 "ports" so we can count in clean binary and ignore the four LSBs of the counters
		//Round-robin all ten ports and check one per cycle - we lose a tiny bit of speed,
		//but we're still an OOM or two faster than the MOSFET switching delay so it's no big deal.
		overcurrent_check_index <= overcurrent_check_index + 4'h1;
		if(overcurrent_check_index == 9)
			overcurrent_check_index <= 0;
		
		//If the inrush timer is still counting, keep counting down
		if(inrush_timer_count_out != 0) begin
			inrush_timer_count_we <= 1;
			inrush_timer_count_waddr <= overcurrent_check_index_buf;
			if(inrush_timer_count_out < 10)
				inrush_timer_count_wdata <= 0;
			else
				inrush_timer_count_wdata <= inrush_timer_count_out - 24'h10;
		end
		
		//If the channel is turned on and triggering the overcurrent signal, and the inrush timer
		//has hit zero, something is wrong... shut down.
		else if(oc_alert_sync[overcurrent_check_index_buf] && pwr_oe[overcurrent_check_index_buf]) begin
			pwr_oe[overcurrent_check_index_buf] <= 0;
			error_leds[overcurrent_check_index_buf] <= 1;
		end
		
		//Main state machine
		case(state)
		
			//Wait for messages to show up
			STATE_IDLE: begin
				if(rpc_fab_rx_en) begin
				
					//Save header info
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
				
					//Process it
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						
						//It's a function call
						case(rpc_fab_rx_callnum)
							
							//Toggle power state
							//d0 = channel, d1[0] = state
							OUTSTAGE_POWER_STATE: begin
							
								//Turning off?
								if(!rpc_fab_rx_d1[0]) begin
									//Turn channel off
									pwr_oe[chnum] <= 0;
									
									//Clear overcurrent flag
									error_leds[chnum] <= 0;
								end

								//If trying to turn on, but overcurrent alert is set, keep the channel off
								else if(error_leds[chnum])
									pwr_oe[chnum] <= 0;
									
								//Turn on and start the inrush timer
								else begin
									inrush_timer_count_we <= 1;
									inrush_timer_count_waddr <= chnum;
									inrush_timer_count_wdata <= inrush_timer_max[chnum];
									pwr_oe[chnum] <= 1;
								end
									
								
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end	//end OUTSTAGE_POWER_STATE
							
							OUTSTAGE_INRUSH_TIME: begin
							
								//Write to the inrush max counter
								inrush_timer_max[chnum] = rpc_fab_rx_d1[23:0];
								
								//We're good
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end	//end OUTSTAGE_INRUSH_TIME
							
							OUTSTAGE_GET_STATUS: begin
								rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								rpc_fab_tx_d0 <= {19'h0, error_leds[chnum], pwr_oe[chnum]};
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
							end	//end OUTSTAGE_GET_STATUS
							
							//Unrecognize call, fail
							default: begin
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								rpc_fab_tx_d0 <= 0;
								rpc_fab_tx_d1 <= 0;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								state <= STATE_RPC_TXHOLD;
							end
							
						endcase
						
					end
					
					else begin
						//Ignore it
						rpc_fab_rx_done <= 1;
					end
					
				end
			end	//end STATE_IDLE
			
			//Wait for transmits to finish
			STATE_RPC_TXHOLD: begin
				if(rpc_fab_tx_done) begin
					rpc_fab_rx_done <= 1;
					state <= STATE_IDLE;
				end
			end	//end STATE_RPC_TXHOLD
		
		endcase
	
	end
	
endmodule
