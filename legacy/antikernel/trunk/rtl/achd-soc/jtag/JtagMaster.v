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
	@brief Low-level JTAG master
	
	TCK frequency is Fin / 4*(clkdiv + 1)
	
	State changes:
		Bring state_en high for one cycle with next_state set, then wait for done to go high
		
	Shifting data through TDI/TDO:
		Write 1-32 bits of data to din and set len to the number of bits to shift.
		Bring shift_en high for one cycle, then wait for done to go high
		When done is high, dout is valid and contains the data from TDO
		
	Bit alignment
		din/dout are 32-bit big endian words. The LSB is shifted in and out first.
		
		Dout is left aligned.
 */
module JtagMaster(
	clk,
	clkdiv,
	tck, tdi, tms, tdo,
	state_en, next_state,
	len, shift_en, last_tms, din, dout,
	done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	//Clocking
	input wire			clk;
	input wire[7:0]		clkdiv;
	
	//The actual JTAG bus
	output reg			tck	= 0;
	output reg			tdi = 0;
	output reg			tms = 0;
	input wire			tdo;
	
	//State transitions
	input wire			state_en;
	input wire[2:0]		next_state;
	
	//Register scanning
	input wire[5:0]		len;
	input wire			shift_en;
	input wire			last_tms;
	input wire[31:0]	din;
	output reg[31:0]	dout			= 0;
	
	//Status oututs
	output reg			done = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Internal state flags
	
	localparam STATE_IDLE		= 2'h0;
	localparam STATE_SHIFT_TMS	= 2'h1;
	localparam STATE_SHIFT_DATA	= 2'h2;
	localparam STATE_SHIFT_DONE	= 2'h3;
	
	reg[1:0]	state			= STATE_IDLE;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Slow clock generation
	
	reg[7:0]	count		= 0;
	
	reg			tck_mid_high	= 0;			//Indicates TCK is going low soon
	reg			tck_mid_low		= 0;			//Indicates TCK is going high soon
												//Drive new data out TDI/TMS
	reg			tck_rising		= 0;
	reg			tck_falling		= 0;
	
	reg[1:0]	tck_phase	= 0;
	
	always @(posedge clk) begin
	
		//Clear flags
		tck_mid_high	<= 0;
		tck_mid_low		<= 0;
		tck_rising		<= 0;
		tck_falling		<= 0;
		
		//Drive the clock out
		if(tck_rising)
			tck			<= 1;
		if(tck_falling)
			tck			<= 0;
	
		//Only advance if we're not in the idle state.
		//When in idle, TCK is held at zero and doesn't toggle.
		if(state == STATE_IDLE) begin
			count		<= 0;
			tck			<= 0;
			tck_phase	<= 0;
		end
		else
			count		<= count + 8'h1;
		
		//If we overflowed, move TCK to the next 90 degree phase offset
		if(count == clkdiv) begin
			count		<= 0;
			tck_phase	<= tck_phase + 2'h1;

			case(tck_phase)
				0:	tck_mid_low		<= 1;
				1:	tck_rising		<= 1;
				2:	tck_mid_high	<= 1;
				3:	tck_falling		<= 1;
			endcase
			
		end
		
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "JtagMaster_opcodes_constants.v"
	
	//TMS data to shift
	reg[6:0]	tms_shift_data	= 0;
	reg[2:0]	tms_shift_count	= 0;
	reg[31:0]	tdi_shift_data	= 0;
	reg[5:0]	tdi_shift_count	= 0;
	reg[31:0]	tdo_shift_data	= 0;
	
	always @(posedge clk) begin
	
		done	<= 0;
	
		//Get ready to stop when a shift finishes
		if(tck_falling) begin
			case(state)
				STATE_SHIFT_DATA: begin
					if(tdi_shift_count == 0)
						state	<= STATE_SHIFT_DONE;
				end
				
				STATE_SHIFT_TMS: begin
					if(tms_shift_count == 0)
						state	<= STATE_SHIFT_DONE;
				end
			endcase
		end
		
		//but don't actually clear the outputs until the last falling edge
		//Don't touch TDI when doing shift operations
		if(tck_mid_low && (state == STATE_SHIFT_DONE)) begin
			//tdi				<= 0;
			tms				<= 0;
			state			<= STATE_IDLE;
			
			done			<= 1;
			
			dout			<= tdo_shift_data;
		end
		
		//Translate state transition requests to raw TMS shift requests.
		//TDI is always zero during these states
		if(state_en) begin
			state	<= STATE_SHIFT_TMS;
			tdi		<= 0;
			
			case(next_state)
			
				OP_TEST_RESET: begin
					tms_shift_data	<= 7'h3f;
					tms_shift_count	<= 6;
				end
				
				OP_RESET_IDLE: begin
					tms_shift_data	<= 7'h3f;
					tms_shift_count	<= 7;
				end
				
				OP_SELECT_IR: begin
					tms_shift_data	<= 7'h03;
					tms_shift_count	<= 4;
				end
				
				OP_LEAVE_IR: begin
					tms_shift_data	<= 7'h01;
					tms_shift_count	<= 2;
				end
				
				OP_SELECT_DR: begin
					tms_shift_data	<= 7'h01;
					tms_shift_count	<= 3;
				end
				
				OP_LEAVE_DR: begin
					tms_shift_data	<= 7'h01;
					tms_shift_count	<= 2;
				end

				//invalid opcode is a no-op
				default: begin
					tms_shift_data	<= 0;
					tms_shift_count	<= 0;
					state			<= STATE_IDLE;
				end
				
			endcase
			
		end
		
		//Save incoming TDI shift requests
		if(shift_en) begin
			dout			<= 0;
			tdi_shift_data	<= din;
			tdi_shift_count	<= len;
			tdo_shift_data	<= 0;
			state			<= STATE_SHIFT_DATA;
		end
		
		//Clock rising? Read TDO
		if(tck_rising)
			tdo_shift_data			<= {tdo, tdo_shift_data[31:1]};
		
		//Clock about to rise? Drive data out TDI/TMS
		if(tck_mid_low) begin
			
			case(state)
				
				//Shift TMS stuff
				STATE_SHIFT_TMS: begin
					tms_shift_count	<= tms_shift_count - 3'h1;
					tms_shift_data	<= {1'b0, tms_shift_data[6:1]};
					tms				<= tms_shift_data[0];
				end
				
				//Shift TDI stuff
				STATE_SHIFT_DATA: begin
					tdi_shift_count	<= tdi_shift_count - 6'h1;
					tdi_shift_data	<= {1'b0, tdi_shift_data[31:1]};
					tdi				<= tdi_shift_data[0];
					
					//Strobe TMS on the last pulse if needed
					if( (tdi_shift_count == 1) )
						tms			<= last_tms;
					else
						tms			<= 0;
				end
				
			endcase
			
		end
	
	end
	
endmodule
