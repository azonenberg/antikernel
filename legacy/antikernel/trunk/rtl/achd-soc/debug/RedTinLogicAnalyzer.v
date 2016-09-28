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
	@brief Top level module of the Red Tin logic analyzer
 */
module RedTinLogicAnalyzer(
	capture_clk, din,
	
	reconfig_clk, reconfig_din, reconfig_ce, reconfig_finish,
	
	done, reset,
	read_en, read_clk, read_addr, read_data, read_timestamp
    );
	
	///////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations

	//Clocks
	input wire 					capture_clk;
	input wire 					reconfig_clk;
	input wire 					read_clk;
	
	//Parameterizable depth
	`include "../util/clog2.vh"
	parameter					DEPTH = 512;
	localparam 					ADDR_BITS = clog2(DEPTH);

	//Capture data width (must be a multiple of 64)
	parameter 					DATA_WIDTH = 128;
	input wire[DATA_WIDTH-1:0]	din;
	
	//Reconfiguration data for loading trigger settings
	input wire[31:0]			reconfig_din;
	input wire					reconfig_ce;
	input wire					reconfig_finish;

	//We capture DEPTH samples in a circular buffer starting 16 clocks before the trigger condition holds.
	//TODO: Make this offset configurable
	input wire[ADDR_BITS-1:0]	read_addr;
	output wire[DATA_WIDTH-1:0]	read_data;
	output wire[31:0]			read_timestamp;
	input wire					read_en;

	input wire					reset;
	output wire					done;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Trigger logic
		
	//Save the old value (used for edge detection)
	//We register a couple of times in order to ensure that we don't lengthen any critical paths.
	//Old SHREG_EXTRACT constraint changed to KEEP in case we're sniffing a signal used as part of a shreg elsewhere.
	//We don't want to get merged with it.
	(* KEEP = "true" *) reg[DATA_WIDTH-1:0] din_buf = 0;
	(* KEEP = "true" *) reg[DATA_WIDTH-1:0] din_buf2 = 0;
	(* KEEP = "true" *) reg[DATA_WIDTH-1:0] din_buf3 = 0;
	always @(posedge capture_clk) begin
		din_buf <= din;
		din_buf2 <= din_buf;
		din_buf3 <= din_buf2;
	end
	
	//The actual reconfigurable trigger logic (refactored into a separate module)
	wire	trigger;
	RedTinLogicAnalyzer_trigger #(
		.DATA_WIDTH(DATA_WIDTH)
	) trigger_system (
		.capture_clk(capture_clk),
		.din_buf2(din_buf2),
		.din_buf3(din_buf3),
		.reset(reset),
		.reconfig_clk(reconfig_clk),
		.reconfig_din(reconfig_din),
		.reconfig_ce(reconfig_ce),
		.reconfig_finish(reconfig_finish),
		.trigger(trigger)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Shared state used by everything
	
	reg[1:0] state = 2'b11;			//00 = idle
									//01 = capturing
									//10 = done, wait for reset
									//11 = uninitialized, wait for reset
	assign done = (state == 2'b10);
	
	//Time since the last sample took place
	reg[31:0] timestamp_offset = 0;
	
	//True if an edge was found
	//TODO: re-use high half of trigger logic to do this
	wire sample_edge;
	assign sample_edge = (din_buf2 != din_buf3) ||			//sample has changed
						(timestamp_offset > 'h00080000) ||	//limit depth of capture to avoid hanging on short pulses
						(state == 2'b00);					//capture all the time in the idle state
						
	//Registered write stuff
	reg					sample_we_ff		= 0;
	reg[31:0]			timestamp_offset_ff	= 0;
	reg[ADDR_BITS-1:0]	capture_waddr_ff	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Capture memory
	
	//Timestamp buffer
	//Each entry is a 32-bit counter storing the time, in clock cycles, since the last write occurred.
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(DEPTH),
		.USE_BLOCK(1),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.INIT_VALUE(32'h0)
	) timestamp_buf (
		.porta_clk(capture_clk),
		.porta_en(sample_we_ff),
		.porta_addr(capture_waddr_ff),
		.porta_we(1'b1),
		.porta_din(timestamp_offset_ff),
		.porta_dout(),
		
		.portb_clk(read_clk),
		.portb_en(read_en),
		.portb_addr(real_read_addr),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(read_timestamp)
	);
	
	//Capture buffer - the actual LA signal data
	MemoryMacro #(
		.WIDTH(DATA_WIDTH),
		.DEPTH(DEPTH),
		.USE_BLOCK(1),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.INIT_VALUE(32'h0)
	) capture_buf (
		.porta_clk(capture_clk),
		.porta_en(sample_we_ff),
		.porta_addr(capture_waddr_ff),
		.porta_we(1'b1),
		.porta_din(din_buf3),
		.porta_dout(),
		
		.portb_clk(read_clk),
		.portb_en(read_en),
		.portb_addr(real_read_addr),
		.portb_we(1'b0),
		.portb_din({DATA_WIDTH{1'h0}}),
		.portb_dout(read_data)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Capture logic
	
	//Capture buffer is a circular ring buffer. Start at address X and end at X-1.
	//We are always capturing until triggered. Until the trigger signal is received
	//we increment the start and end addresses every clock and write to the 16th position
	//in the buffer; once triggered we stop incrementing them and record until the buffer
	//is full. From then until reset, capturing is halted and data can be dumped.
	reg[ADDR_BITS-1:0] capture_start	= 0;
	reg[ADDR_BITS-1:0] capture_end		= {ADDR_BITS{1'b1}};
	reg[ADDR_BITS-1:0] capture_waddr	= 8'h10;
	
	//We're actually reading offsets in the circular buffer, not raw memory addresses.
	//Keep that in mind!
	wire[ADDR_BITS-1:0] real_read_addr;
	assign real_read_addr = read_addr + capture_start;
	
	//True if writing to the buffer
	wire sample_we;
	assign sample_we = !state[1] && sample_edge;
	
	//Reset comes in the reconfig clock domain.
	//Shift to the capture domain (might be a few cycles but that's fine since reconfig takes time anyway)
	wire reset_sync;
	reg reset_ack = 0;
	HandshakeSynchronizer sync_reset
		(.clk_a(reconfig_clk),		.en_a(reset), 		.ack_a(), .busy_a(),
		 .clk_b(capture_clk), 		.en_b(reset_sync),	.ack_b(reset_ack));
	
	always @(posedge capture_clk) begin
		
		timestamp_offset <= timestamp_offset + 32'h1;	
		reset_ack <= 0;
		
		//Register timestamp write data
		sample_we_ff		<= sample_we;
		timestamp_offset_ff	<= timestamp_offset;
		capture_waddr_ff	<= capture_waddr;
		
		//If in idle or capture state, write to the buffer
		//Register all write signals to improve timing
		if(sample_we)
			timestamp_offset <= 1;					//next sample will be at least one cycle later
		
		case(state)
			
			//Idle - capture data anyway so we can grab stuff before the trigger event
			//and then bump pointers
			2'b00: begin
				
				//If triggering, go on (but don't move window)
				if(trigger) begin
					state <= 2'b01;
				end
					
				//otherwise move the window
				else begin
					capture_start <= capture_start + 1'h1;
					capture_end <= capture_end + 1'h1;
				end
				
				//In any case move our write address
				//Always write in idle mode since we don't know when the edge will show up
				capture_waddr <= capture_waddr + 1'h1;
				timestamp_offset <= 1;
				
			end
			
			//Capturing - bump write pointer and stop if we're at the end, otherwise keep going
			2'b01: begin			
				if(capture_waddr == capture_end)
					state <= 2'b10;
				else if(sample_edge)
					capture_waddr <= capture_waddr + 1'h1;
			end
			
			//Read stuff and wait for reset
			2'b10: begin
				if(reset_sync) begin
					state <= 2'b00;
					
					capture_start	<= 8'h0;
					capture_end		<= {ADDR_BITS{1'b1}};
					capture_waddr	<= 8'h10;
					
					reset_ack <= 1;
					
				end
			end
			
			2'b11: begin
				if(reset_sync) begin
					state <= 2'b00;
					
					capture_start	<= 8'h0;
					capture_end		<= {ADDR_BITS{1'b1}};
					capture_waddr	<= 8'h10;
					
					reset_ack <= 1;
				end
			end
			
		endcase
		
	end
	
endmodule
