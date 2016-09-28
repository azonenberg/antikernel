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
	@brief DECODE stage of GRAFTON CPU
 */
module GraftonCPUDecodeStage(
	clk,
	iside_rd_data, iside_rd_valid, iside_rd_addr,
	decode_regid_a, decode_regid_b, execute_regid_d,
	stall_out,
	execute_rtype, execute_bubble, execute_opcode, execute_func, execute_immval, execute_regid_a, execute_regid_b,
	execute_pc, execute_jump_offset, execute_shamt, execute_coproc_op, execute_branch_op,
	stall_in, freeze, bootloader_pc_out, bootloader_pc_wr
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//I-side data bus
	input wire[31:0] iside_rd_data;
	input wire iside_rd_valid;
	input wire[31:0] iside_rd_addr;
	
	//Cracked register ID outputs to register file
	output reg[4:0] decode_regid_a = 0;
	output reg[4:0] decode_regid_b = 0;
	output reg[4:0] execute_regid_d;
	
	//Outputs to fetch stage
	output reg stall_out = 0;
	
	//Inputs from bootloader
	input wire			bootloader_pc_wr;
	input wire[31:0]	bootloader_pc_out;
	
	//Outputs to execute stage
	output reg execute_bubble = 1;
	output reg execute_rtype = 0;
	output reg[5:0] execute_opcode = 0;
	output reg[5:0] execute_func = 0;
	output reg[15:0] execute_immval = 0;
	output reg[4:0] execute_regid_a = 0;
	output reg[4:0] execute_regid_b = 0;
	output reg[31:0] execute_pc = 32'h40000000;
	output reg[25:0] execute_jump_offset = 0;
	output reg[4:0] execute_shamt = 0;
	output reg[4:0] execute_coproc_op = 0;
	output reg[4:0] execute_branch_op = 0;
	
	//Inputs from execute stage
	input wire stall_in;
	input wire freeze;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Instruction cracking
	
	/*
		R-type
		25:21 = rs
		20:16 = rt
		15:11 = rd
		10:6 = shamt
		5:0 = func
	 */
	
	`include "GraftonCPUInstructionOpcodes_constants.v"
	`include "GraftonCPUInstructionFunctions_constants.v"
	`include "GraftonCPURegisterIDs_constants.v"
	`include "GraftonCPUCoprocessorOpcodes_constants.v"
	
	wire[5:0] opcode = iside_rd_data[31:26];
	wire[5:0] func = iside_rd_data[5:0];
	
	wire rtype;
	assign rtype = (opcode == OP_RTYPE);
	
	//Combinatorial calculation of source register IDs
	always @(*) begin
		decode_regid_a <= iside_rd_data[25:21];
		decode_regid_b <= iside_rd_data[20:16];
		
		if(rtype && (func == FUNC_SYSCALL)) begin
			decode_regid_a <= a0;
			decode_regid_b <= a1;
		end

		if(opcode == OP_COPROC) begin
			decode_regid_a <= zero;
		
			case(iside_rd_data[25:21])
				OP_MFC0: decode_regid_b <= iside_rd_data[15:11];
				OP_MTC0: decode_regid_b <= iside_rd_data[20:16];
				default: begin
				
				end
			endcase
		end

	end
	
	reg[31:0] decode_pc = 0;
	
	always @(posedge clk) begin
		if(freeze) begin
		
			//Report actual instruction location for debugger
			if(bootloader_pc_wr) begin
				decode_pc	<= bootloader_pc_out;
				execute_pc	<= bootloader_pc_out;
			end
		
		end
		
		else begin
			
			decode_pc <= iside_rd_addr;
			
			//Stalling? Freeze
			//This MUST take precedence over everything else
			if(stall_in) begin
				//do not change bubble state
			end
			
			//No instruction? Bubble out the execute stage
			else if(!iside_rd_valid) begin
				execute_bubble <= 1;
			end
			
			//No, do decode stuff (un-bubble)
			else begin
				execute_bubble <= 0;
				
				execute_pc <= decode_pc;
			
				execute_rtype <= rtype;
				execute_opcode <= opcode;
				execute_func <= func;
				execute_immval <= iside_rd_data[15:0];
				execute_regid_a <= decode_regid_a;
				execute_regid_b <= decode_regid_b;
				execute_shamt <= iside_rd_data[10:6];					
				execute_jump_offset <= iside_rd_data[25:0];
				execute_coproc_op <= iside_rd_data[25:21];
				execute_branch_op <= iside_rd_data[20:16];
				
				//Destination register ID
				if(rtype)
					execute_regid_d <= iside_rd_data[15:11];
				else if(opcode == OP_COPROC) begin
					case(iside_rd_data[25:21])
						OP_MFC0: execute_regid_d <= iside_rd_data[20:16];
						OP_MTC0: execute_regid_d <= iside_rd_data[15:11];
						default: begin
						
						end
					endcase
				end
				else
					execute_regid_d <= iside_rd_data[20:16];
				
			end
			
		end
	end
	
endmodule

