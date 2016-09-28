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
module SaratogaCPUInstructionDecoder(
	
	clk,
	
	//Incoming instruction
	decode0_thread_active, decode0_insn, decode0_iside_hit,
	
	//Register fetch outputs
	decode0_unit0_rs_id, decode0_unit0_rt_id,
	decode0_unit1_rs_id, decode0_unit1_rt_id,
	
	//Outputs to execution units
	exec0_unit0_rd_id, exec0_unit0_en, exec0_unit0_rtype,
		exec0_unit0_itype, exec0_unit0_jtype, exec0_unit0_opcode, exec0_unit0_func, exec0_unit0_immval,
		exec0_unit0_jtype_addr, exec0_unit0_shamt, exec0_unit0_syscall, exec0_unit0_mem, exec0_unit0_branch_op,
		exec0_unit0_div, exec0_unit0_div_sign,
	exec0_unit1_rd_id, exec0_unit1_en, exec0_unit1_rtype,
		exec0_unit1_itype, exec0_unit1_jtype, exec0_unit1_opcode, exec0_unit1_func, exec0_unit1_immval,
		exec0_unit1_jtype_addr, exec0_unit1_shamt, exec0_unit1_syscall,  exec0_unit1_mem, exec0_unit1_branch_op,
		exec0_unit1_div, exec0_unit1_div_sign
	
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk;
	
	//The raw encoded instruction
	input wire			decode0_thread_active;
	input wire[63:0]	decode0_insn;
	input wire[1:0]		decode0_iside_hit;
	
	//Register fetch occurs in parallel with main decode stuff.
	//Output register IDs combinatorially
	output reg[4:0]		decode0_unit0_rs_id	= 0;
	output reg[4:0]		decode0_unit0_rt_id	= 0;
	output reg[4:0]		decode0_unit1_rs_id	= 0;
	output reg[4:0]		decode0_unit1_rt_id	= 0;
	
	//Outputs to execution unit 0
	//KEEP constraints used to prevent stuff from being merged.
	//Different interpretations of the same opcode bits go different spots
	//so we want them to be separate FFs in separate places
	output reg[4:0]		exec0_unit0_rd_id		= 0;
	output reg 			exec0_unit0_en			= 0;
	output reg			exec0_unit0_rtype		= 0;
	output reg			exec0_unit0_itype		= 0;
	output reg			exec0_unit0_jtype		= 0;
	output reg[5:0]		exec0_unit0_opcode		= 0;
	(* KEEP = "yes" *)
	output reg[5:0]		exec0_unit0_func		= 0;
	output reg[15:0]	exec0_unit0_immval		= 0;
	(* KEEP = "yes" *)
	output reg[25:0]	exec0_unit0_jtype_addr	= 0;
	output reg[4:0]		exec0_unit0_shamt		= 0;
	output reg			exec0_unit0_syscall		= 0;
	output reg			exec0_unit0_mem			= 0;
	output reg[4:0]		exec0_unit0_branch_op	= 0;
	output reg			exec0_unit0_div			= 0;
	output reg			exec0_unit0_div_sign	= 0;
	
	//Outputs to execution unit 1
	output reg[4:0]		exec0_unit1_rd_id		= 0;
	output reg 			exec0_unit1_en			= 0;
	output reg			exec0_unit1_rtype		= 0;
	output reg			exec0_unit1_itype		= 0;
	output reg			exec0_unit1_jtype		= 0;
	output reg[5:0]		exec0_unit1_opcode		= 0;
	output reg[5:0]		exec0_unit1_func		= 0;
	output reg[15:0]	exec0_unit1_immval		= 0;
	output reg[25:0]	exec0_unit1_jtype_addr	= 0;
	output reg[4:0]		exec0_unit1_shamt		= 0;
	output reg			exec0_unit1_syscall		= 0;
	output reg			exec0_unit1_mem			= 0;
	output reg[4:0]		exec0_unit1_branch_op	= 0;
	output reg			exec0_unit1_div			= 0;
	output reg			exec0_unit1_div_sign	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Split up the instructions
	
	reg[31:0]			decode0_unit0_insn	= 0;
	reg[31:0]			decode0_unit1_insn	= 0;
	
	always @(*) begin
		decode0_unit0_insn		<= decode0_insn[63:32];
		decode0_unit1_insn		<= decode0_insn[31:0];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Initial combinatorial instruction parsing

	wire[5:0]	decode0_unit0_opcode;
	wire[5:0]	decode0_unit0_rtype_func;
	wire[4:0]	decode0_unit0_rtype_shamt;
	wire[4:0]	decode0_unit0_rtype_rd_id;
	wire[15:0]	decode0_unit0_itype_imm;			//raw value, not yet sign/zero extended
	wire[25:0]	decode0_unit0_jtype_addr;
	wire[4:0]	decode0_unit0_rs_id_raw;
	wire[4:0]	decode0_unit0_rt_id_raw;
	wire[4:0]	decode0_unit0_branch_op;
	
	wire		decode0_unit0_rtype;
	wire		decode0_unit0_itype;
	wire		decode0_unit0_jtype;
	wire		decode0_unit0_jump;
	wire		decode0_unit0_mem;
	
	wire		decode0_unit0_div;
	wire		decode0_unit0_div_sign;

	SaratogaCPUInstructionDecoder_Parsing unit0_decoding(
		.decode0_insn(decode0_unit0_insn),
		.decode0_opcode(decode0_unit0_opcode),
		.decode0_rtype_func(decode0_unit0_rtype_func),
		.decode0_rtype_shamt(decode0_unit0_rtype_shamt),
		.decode0_rtype_rd_id(decode0_unit0_rtype_rd_id),
		.decode0_itype_imm(decode0_unit0_itype_imm),
		.decode0_jtype_addr(decode0_unit0_jtype_addr),
		.decode0_rs_id(decode0_unit0_rs_id_raw),
		.decode0_rt_id(decode0_unit0_rt_id_raw),
		.decode0_rtype(decode0_unit0_rtype),
		.decode0_itype(decode0_unit0_itype),
		.decode0_jtype(decode0_unit0_jtype),
		.decode0_jump(decode0_unit0_jump),
		.decode0_mem(decode0_unit0_mem),
		.decode0_branch_op(decode0_unit0_branch_op),
		.decode0_div(decode0_unit0_div),
		.decode0_div_sign(decode0_unit0_div_sign)
		);
		
	wire[5:0]	decode0_unit1_opcode;
	wire[5:0]	decode0_unit1_rtype_func;
	wire[4:0]	decode0_unit1_rtype_shamt;
	wire[4:0]	decode0_unit1_rtype_rd_id;
	wire[15:0]	decode0_unit1_itype_imm;			//raw value, not yet sign/zero extended
	wire[25:0]	decode0_unit1_jtype_addr;
	wire[4:0]	decode0_unit1_rs_id_raw;
	wire[4:0]	decode0_unit1_rt_id_raw;
	wire[4:0]	decode0_unit1_branch_op;
	
	wire		decode0_unit1_rtype;
	wire		decode0_unit1_itype;
	wire		decode0_unit1_jtype;
	wire		decode0_unit1_jump;
	wire		decode0_unit1_mem;
	
	wire		decode0_unit1_div;
	wire		decode0_unit1_div_sign;

	SaratogaCPUInstructionDecoder_Parsing unit1_decoding(
		.decode0_insn(decode0_unit1_insn),
		.decode0_opcode(decode0_unit1_opcode),
		.decode0_rtype_func(decode0_unit1_rtype_func),
		.decode0_rtype_shamt(decode0_unit1_rtype_shamt),
		.decode0_rtype_rd_id(decode0_unit1_rtype_rd_id),
		.decode0_itype_imm(decode0_unit1_itype_imm),
		.decode0_jtype_addr(decode0_unit1_jtype_addr),
		.decode0_rs_id(decode0_unit1_rs_id_raw),
		.decode0_rt_id(decode0_unit1_rt_id_raw),
		.decode0_rtype(decode0_unit1_rtype),
		.decode0_itype(decode0_unit1_itype),
		.decode0_jtype(decode0_unit1_jtype),
		.decode0_jump(decode0_unit1_jump),
		.decode0_mem(decode0_unit1_mem),
		.decode0_branch_op(decode0_unit1_branch_op),
		.decode0_div(decode0_unit1_div),
		.decode0_div_sign(decode0_unit1_div_sign)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Figure out final registers to use
	
	`include "SaratogaCPUInstructionFunctions_constants.v"
	`include "SaratogaCPUInstructionOpcodes_constants.v"
	`include "SaratogaCPURegisterIDs_constants.v"
	
	reg[4:0]	decode0_unit0_rd_id			= 0;
	reg[4:0]	decode0_unit1_rd_id			= 0;

	always @(*) begin
	
		//If the instruction in unit 0 is a SYSCALL instruction, fetch $a0...a3 instead
		if(decode0_unit0_rtype && (decode0_unit0_rtype_func == FUNC_SYSCALL) ) begin
			decode0_unit0_rs_id		<= a0;
			decode0_unit0_rt_id		<= a1;
			decode0_unit1_rs_id		<= a2;
			decode0_unit1_rt_id		<= a3;
		end
		
		else begin
			//Copy rs/rt IDs by default
			decode0_unit0_rs_id			<= decode0_unit0_rs_id_raw;
			decode0_unit0_rt_id			<= decode0_unit0_rt_id_raw;
			decode0_unit1_rs_id			<= decode0_unit1_rs_id_raw;
			decode0_unit1_rt_id			<= decode0_unit1_rt_id_raw;
		end
	
		//Figure out the destination register ID
		if( (decode0_unit0_opcode == OP_JAL) || (decode0_unit0_rtype && (decode0_unit0_rtype_func == FUNC_JALR)) )
			decode0_unit0_rd_id		<= ra;
		else if(decode0_unit0_rtype)
			decode0_unit0_rd_id		<= decode0_unit0_rtype_rd_id;			
		else
			decode0_unit0_rd_id		<= decode0_unit0_rt_id;
			
		if( (decode0_unit1_opcode == OP_JAL) || (decode0_unit1_rtype && (decode0_unit1_rtype_func == FUNC_JALR)) )
			decode0_unit1_rd_id		<= ra;
		else if(decode0_unit1_rtype)
			decode0_unit1_rd_id		<= decode0_unit1_rtype_rd_id;
		else
			decode0_unit1_rd_id		<= decode0_unit1_rt_id;
			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Decide whether to issue one, both, or neither
	
	(* REGISTER_BALANCING = "yes" *)
	reg decode1_unit0_en		= 0;
	
	(* REGISTER_BALANCING = "yes" *)
	reg decode1_unit1_en		= 0;
	
	always @(posedge clk) begin
		
		decode1_unit0_en		<= 0;
		decode1_unit1_en		<= 0;
		
		//If we're not actually executing, do nothing
		//If first instruction is a cache miss, there's nothing to do
		if(!decode0_thread_active || !decode0_iside_hit[1]) begin
		end
		
		//We're executing SOMETHING... but what?
		else begin
		
			//Issue the first instruction regardless
			decode1_unit0_en		<= 1;
			
			//Default to issuing the second if it was in the cache
			decode1_unit1_en		<= decode0_iside_hit[0];
		
			//Do not issue the second if the first is a jump
			//SARATOGA doesn't have delay slots, so we just skip the second instruction and mandate fno-delayed-branch
			if(decode0_unit0_jump)
				decode1_unit1_en		<= 0;
				
			//Can only issue memory instructions to unit 0 for now
			if(decode0_unit1_mem)
				decode1_unit1_en		<= 0;
				
			//If the first one is a memory instruction, do not issue the SECOND so that we won't repeat it
			//in the case of a cache miss.
			//(TODO: Issue it, but cancel writeback?)
			if(decode0_unit0_mem)
				decode1_unit1_en		<= 0;
				
			//Can only issue multiply/divide instructions to unit 0 for now
			if(decode0_unit1_rtype &&
				(
					(decode0_unit1_rtype_func == FUNC_MULT) ||
					(decode0_unit1_rtype_func == FUNC_MULTU) ||
					(decode0_unit1_rtype_func == FUNC_MTLO) ||
					(decode0_unit1_rtype_func == FUNC_MTHI) ||
					(decode0_unit1_rtype_func == FUNC_DIV) ||
					(decode0_unit1_rtype_func == FUNC_DIVU)
				)
			) begin
				decode1_unit1_en		<= 0;
			end
			
			//BUGFIX: Cannot issue mflo/mfhi to unit 1 until we implement stalling from both execution units
			if(decode0_unit1_rtype &&
				(decode0_unit1_rtype_func == FUNC_MFLO) ||
				(decode0_unit1_rtype_func == FUNC_MFHI)
				) begin
				decode1_unit1_en		<= 0;
			end
				
			//If either input of the second instruction is the output of the first, skip the second
			//TODO: See if this is too broad a net - are we catching instructions that arent actually colliding?
			if( (decode0_unit0_rd_id == decode0_unit1_rs_id) || (decode0_unit0_rd_id == decode0_unit1_rt_id) )
				decode1_unit1_en		<= 0;
				
			//If both write to the same register, only issue the first to avoid double-write conflicts.
			//TODO: Only issue the second and optimize out the first?
			if(decode0_unit0_rd_id == decode0_unit1_rd_id)
				decode1_unit1_en		<= 0;
				
			//If the second is a syscall, disable it
			if(decode0_unit1_rtype && (decode0_unit1_rtype_func == FUNC_SYSCALL))
				decode1_unit1_en		<= 0;
				
			//If the first is a syscall, enable the second execution unit in slave mode regardless!
			if(decode0_unit0_rtype && (decode0_unit0_rtype_func == FUNC_SYSCALL))
				decode1_unit1_en		<= 1;
		
		end
		
		//Push down the pipeline
		exec0_unit0_en		<= 	decode1_unit0_en;
		exec0_unit1_en		<= 	decode1_unit1_en;

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push decoded instruction outputs down the pipeline
	
	reg			decode1_unit0_rtype			= 0;
	reg			decode1_unit0_itype			= 0;
	reg			decode1_unit0_jtype			= 0;
	reg[5:0]	decode1_unit0_opcode		= 0;
	reg[5:0]	decode1_unit0_func			= 0;
	reg[15:0]	decode1_unit0_immval		= 0;
	reg[25:0]	decode1_unit0_jtype_addr	= 0;
	reg[4:0]	decode1_unit0_shamt			= 0;
	reg			decode1_unit0_mem			= 0;
	reg[4:0]	decode1_unit0_branch_op		= 0;
	reg			decode1_unit0_div			= 0;
	reg			decode1_unit0_div_sign		= 0;
	
	reg			decode1_unit1_rtype			= 0;
	reg			decode1_unit1_itype			= 0;
	reg			decode1_unit1_jtype			= 0;
	reg[5:0]	decode1_unit1_opcode		= 0;
	reg[5:0]	decode1_unit1_func			= 0;
	reg[15:0]	decode1_unit1_immval		= 0;
	reg[25:0]	decode1_unit1_jtype_addr	= 0;
	reg[4:0]	decode1_unit1_shamt			= 0;
	reg			decode1_unit1_mem			= 0;
	reg[4:0]	decode1_unit1_branch_op		= 0;
	reg			decode1_unit1_div			= 0;
	reg			decode1_unit1_div_sign		= 0;
	
	always @(posedge clk) begin
	
		decode1_unit0_rtype				<= decode0_unit0_rtype;
		decode1_unit0_itype				<= decode0_unit0_itype;
		decode1_unit0_jtype				<= decode0_unit0_jtype;
		decode1_unit0_opcode			<= decode0_unit0_opcode;
		decode1_unit0_func				<= decode0_unit0_rtype_func;
		decode1_unit0_immval			<= decode0_unit0_itype_imm;
		decode1_unit0_jtype_addr		<= decode0_unit0_jtype_addr;
		decode1_unit0_shamt				<= decode0_unit0_rtype_shamt;
		decode1_unit0_mem				<= decode0_unit0_mem;
		decode1_unit0_branch_op			<= decode0_unit0_branch_op;
		decode1_unit0_div				<= decode0_unit0_div;
		decode1_unit0_div_sign			<= decode0_unit0_div_sign;
		
		decode1_unit1_rtype				<= decode0_unit1_rtype;
		decode1_unit1_itype				<= decode0_unit1_itype;
		decode1_unit1_jtype				<= decode0_unit1_jtype;
		decode1_unit1_opcode			<= decode0_unit1_opcode;
		decode1_unit1_func				<= decode0_unit1_rtype_func;
		decode1_unit1_immval			<= decode0_unit1_itype_imm;
		decode1_unit1_jtype_addr		<= decode0_unit1_jtype_addr;
		decode1_unit1_shamt				<= decode0_unit1_rtype_shamt;
		decode1_unit1_mem				<= decode0_unit1_mem;
		decode1_unit1_branch_op			<= decode0_unit1_branch_op;
		decode1_unit1_div				<= decode0_unit1_div;
		decode1_unit1_div_sign			<= decode0_unit1_div_sign;
		
		exec0_unit0_rtype				<= decode1_unit0_rtype;
		exec0_unit0_itype				<= decode1_unit0_itype;
		exec0_unit0_jtype				<= decode1_unit0_jtype;
		exec0_unit0_opcode				<= decode1_unit0_opcode;
		exec0_unit0_func				<= decode1_unit0_func;
		exec0_unit0_immval				<= decode1_unit0_immval;
		exec0_unit0_jtype_addr			<= decode1_unit0_jtype_addr;
		exec0_unit0_shamt				<= decode1_unit0_shamt;
		exec0_unit0_mem					<= decode1_unit0_mem;
		exec0_unit0_branch_op			<= decode1_unit0_branch_op;
		exec0_unit0_div					<= decode1_unit0_div;
		exec0_unit0_div_sign			<= decode1_unit0_div_sign;
		
		exec0_unit1_rtype				<= decode1_unit1_rtype;
		exec0_unit1_itype				<= decode1_unit1_itype;
		exec0_unit1_jtype				<= decode1_unit1_jtype;
		exec0_unit1_opcode				<= decode1_unit1_opcode;
		exec0_unit1_func				<= decode1_unit1_func;
		exec0_unit1_immval				<= decode1_unit1_immval;
		exec0_unit1_jtype_addr			<= decode1_unit1_jtype_addr;
		exec0_unit1_shamt				<= decode1_unit1_shamt;
		exec0_unit1_mem					<= decode1_unit1_mem;
		exec0_unit1_branch_op			<= decode1_unit1_branch_op;
		exec0_unit1_div					<= decode1_unit1_div;
		exec0_unit1_div_sign			<= decode1_unit1_div_sign;
		
		exec0_unit0_syscall				<= 0;
		exec0_unit1_syscall				<= 0;
		
		//Trigger syscall processing on BOTH execution units if unit 0 is processing a syscall
		if(decode1_unit0_rtype && (decode1_unit0_func == FUNC_SYSCALL)) begin
			exec0_unit0_syscall				<= 1;
			exec0_unit1_syscall				<= 1;
			
			exec0_unit1_rtype				<= 1;
			exec0_unit1_itype				<= 0;
			exec0_unit1_jtype				<= 0;
			exec0_unit1_opcode				<= OP_RTYPE;
			exec0_unit1_func				<= FUNC_SYSCALL;
		end
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push destination register IDs down the pipeline
	
	reg[4:0]	decode1_unit0_rd_id		= 0;
	reg[4:0]	decode1_unit1_rd_id		= 0;
	
	always @(posedge clk) begin
		decode1_unit0_rd_id				<= decode0_unit0_rd_id;
		decode1_unit1_rd_id				<= decode0_unit1_rd_id;
		exec0_unit0_rd_id				<= decode1_unit0_rd_id;
		exec0_unit1_rd_id				<= decode1_unit1_rd_id;
	end
	
endmodule
