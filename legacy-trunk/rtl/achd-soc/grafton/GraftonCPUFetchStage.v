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
	@brief FETCH stage of GRAFTON pipeline
 */
module GraftonCPUFetchStage(
	
	//Clocks
	clk,
	
	//I-side L1 cache interface
	iside_rd_en, iside_rd_addr, iside_rd_valid,
	
	//Global control signals
	freeze,
	
	//Jump inputs from execute stage
	execute_jumping, execute_jump_address,
	
	//Jump inputs from bootloader
	bootloader_pc_wr, bootloader_pc_out,
	
	//Stall input from decode stage
	stall_in,
	
	//Single-step enable
	step_en, step_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//I-side L1 cache interface
	output reg			iside_rd_en = 0;
	output reg[31:0]	iside_rd_addr;
	input wire			iside_rd_valid;
	
	input wire			freeze;
	
	input wire			execute_jumping;
	input wire[31:0]	execute_jump_address;
	
	input wire			bootloader_pc_wr;
	input wire[31:0]	bootloader_pc_out;
	
	input wire			stall_in;
	
	input wire			step_en;
	output reg			step_done	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Combinatorial fetch logic
	
	reg freeze_buf = 0;
	reg stall_buf = 0;
	
	reg[31:0] iside_rd_addr_buf = 32'h40000000;	//Reset vector
	reg iside_rd_en_buf = 0;
	
	reg jump_pending = 0;
	reg[31:0] saved_jump_address = 0;
	reg fetch_jumping = 0;
	reg missing = 0;
	
	always @(*) begin
		
		iside_rd_en		<= 0;
		iside_rd_addr	<= iside_rd_addr_buf;
		fetch_jumping	<= 0;
		step_done		<= 0;
		
		//Freezing or stalling? Do nothing
		if(freeze || stall_in) begin
		end
		
		//Just un-froze? or un-stalled? Issue a read request
		else if(freeze_buf || stall_buf) begin
			iside_rd_en <= 1;
		end
		
		//Fetch is done, see how it turned out
		else if(iside_rd_en_buf) begin
		
			//Hit! Go on and fetch the next instruction
			if(iside_rd_valid) begin
			
				//If we're single stepping, we just loaded a new instruction so stop!
				if(step_en)
					step_done	<= 1;
			
				iside_rd_en <= 1;
			
				//Normal jump handling
				if(execute_jumping) begin
					fetch_jumping <= 1;
					iside_rd_addr <= execute_jump_address;
				end
				else if(jump_pending) begin
					fetch_jumping <= 1;
					iside_rd_addr <= saved_jump_address;
				end
				
				//Not jumping
				else
					iside_rd_addr <= iside_rd_addr_buf + 32'h4;	
			end
			
			//Miss! Sit back and do nothing
			else begin
			end
		
		end
		
		//Fetch the next instruction
		else if(iside_rd_valid || !missing) begin
			iside_rd_en <= 1;
			
			//Normal jump handling
			if(execute_jumping) begin
				fetch_jumping <= 1;
				iside_rd_addr <= execute_jump_address;
			end
			else if(jump_pending) begin
				fetch_jumping <= 1;
				iside_rd_addr <= saved_jump_address;
			end
			
			//Not jumping
			else
				iside_rd_addr <= iside_rd_addr_buf + 32'h4;
			
		end
		
		if(bootloader_pc_wr) begin
			iside_rd_en <= 1;
			fetch_jumping <= 1;
			iside_rd_addr <= bootloader_pc_out;
		end

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sequential logic for state saving
	
	always @(posedge clk) begin
	
		freeze_buf <= freeze;
		stall_buf <= stall_in;
	
		//Save the old address
		if(!(freeze || stall_in) || bootloader_pc_wr) begin
			if(iside_rd_en)
				iside_rd_addr_buf <= iside_rd_addr;
			iside_rd_en_buf <= iside_rd_en;
		end
			
		//Save pending jump address
		if(execute_jumping) begin
			jump_pending <= 1;
			saved_jump_address <= execute_jump_address;
		end
		
		if(fetch_jumping)
			jump_pending <= 0;
			
		if(iside_rd_valid)
			missing <= 0;
		if(iside_rd_en_buf && !iside_rd_valid)
			missing <= 1;
			
	end
	
endmodule
