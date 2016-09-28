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
	@brief Instruction decode logic
 */
module SaratogaCPUInstructionDecoder_Parsing(
	decode0_insn,
	decode0_opcode, decode0_rtype_func,
	decode0_rs_id, decode0_rt_id,
	decode0_rtype_shamt, decode0_rtype_rd_id, decode0_itype_imm, decode0_jtype_addr,
	decode0_rtype, decode0_itype, decode0_jtype, decode0_jump, decode0_mem, decode0_branch_op,
	decode0_div, decode0_div_sign
	);
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire[31:0]	decode0_insn;
	
	output reg[5:0]		decode0_opcode		= 0;
	output reg[5:0]		decode0_rtype_func	= 0;
	output reg[4:0]		decode0_rtype_shamt	= 0;
	output reg[4:0]		decode0_rtype_rd_id	= 0;
	output reg[15:0]	decode0_itype_imm	= 0;	//raw value, not yet sign/zero extended
	output reg[25:0]	decode0_jtype_addr	= 0;
	
	output reg			decode0_rtype		= 0;
	output reg			decode0_itype		= 0;
	output reg			decode0_jtype		= 0;
	
	output reg			decode0_jump		= 0;
	output reg			decode0_mem			= 0;
	
	output reg[4:0]		decode0_rs_id		= 0;
	output reg[4:0]		decode0_rt_id		= 0;
	output reg[4:0]		decode0_branch_op	= 0;
	
	output reg			decode0_div			= 0;
	output reg			decode0_div_sign	= 0;
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Initial combinatorial instruction parsing

	`include "SaratogaCPUInstructionFunctions_constants.v"
	`include "SaratogaCPUInstructionOpcodes_constants.v"
	`include "SaratogaCPURegisterIDs_constants.v"

	always @(*) begin
	
		//Pull out standard opcode fields
		decode0_opcode		<= decode0_insn[31:26];
		decode0_rs_id		<= decode0_insn[25:21];
		decode0_rt_id		<= decode0_insn[20:16];
		
		//Pull out R-type fields
		decode0_rtype_rd_id	<= decode0_insn[15:11];
		decode0_rtype_shamt	<= decode0_insn[10:6];
		decode0_rtype_func	<= decode0_insn[5:0];
		
		//Pull out I- and J-type fields
		decode0_itype_imm	<= decode0_insn[15:0];
		decode0_jtype_addr	<= decode0_insn[25:0];
		decode0_branch_op	<= decode0_insn[20:16];
		
		//Figure out the type of each instruction
		decode0_rtype		<= (decode0_opcode == OP_RTYPE);
		decode0_jtype		<= (decode0_opcode == OP_J) || (decode0_opcode == OP_JAL);
		decode0_itype		<= !decode0_rtype && !decode0_jtype;
		
		//See if it's a jump (special processing needed)
		decode0_jump		<=
			decode0_jtype ||
			(decode0_opcode == OP_BEQ) ||
			(decode0_opcode == OP_BGTZ) ||
			(decode0_opcode == OP_BLEZ) ||
			(decode0_opcode == OP_BNE) ||
			(decode0_opcode == OP_BRANCH) ||
			(decode0_rtype && (decode0_rtype_func == FUNC_JALR)) ||
			(decode0_rtype && (decode0_rtype_func == FUNC_JR));

		//See if it's a memory instruction (special processing needed)
		decode0_mem			<=
			(decode0_opcode == OP_LB) ||
			(decode0_opcode == OP_LBU) ||
			(decode0_opcode == OP_LH) ||
			(decode0_opcode == OP_LHU) ||
			(decode0_opcode == OP_LW) ||
			(decode0_opcode == OP_SB) ||
			(decode0_opcode == OP_SH) ||
			(decode0_opcode == OP_SW);
			
		decode0_div			<= decode0_rtype &&
								( (decode0_rtype_func == FUNC_DIV) || (decode0_rtype_func == FUNC_DIVU) );
		decode0_div_sign	<= (decode0_rtype_func == FUNC_DIV);
		
	end
	
endmodule

