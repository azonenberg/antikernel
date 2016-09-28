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
	@brief A single execution unit
 */
module SaratogaCPUExecutionUnit(
	clk,
	exec0_tid, exec0_en,
	exec0_rs, exec0_rt,
	exec0_rd_id,
	exec0_rtype, exec0_itype, exec0_jtype, exec0_opcode, exec0_func, exec0_immval, exec0_mem, exec0_branch_op,
	exec0_jtype_addr, exec0_shamt, exec0_syscall, exec0_syscall_repeat, exec0_pc,
	exec0_div, exec0_div_sign,
	exec2_mem_stall,
	exec1_branch_en, exec1_branch_addr,
	exec3_wr_en, exec3_wr_id, exec3_wr_data,
	exec1_rpc_tx_fifo_wr, exec0_rpc_tx_fifo_wsize, exec1_stall,
	exec0_rpc_rx_en, exec1_rpc_rx_valid, exec2_rpc_rx_data, exec0_rpc_rx_en_master,
	exec0_div_busy, exec1_mdu_wr_lo, exec1_mdu_wr_hi, exec1_mdu_wdata,
	exec2_mdu_rdata_lo, exec2_mdu_rdata_hi,
	div_quot, div_rem, div_done, div_done_tid,
	decode1_mdu_wr, decode1_mdu_wdata_lo, decode1_mdu_wdata_hi,
	exec0_dside_rd, exec0_dside_wr, exec0_dside_wmask, exec0_dside_addr, exec0_dside_wdata, exec2_dside_rdata,
	exec2_dside_hit, exec1_bad_instruction, trace_flag
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of entries in the transmit fifo
	parameter					RPC_TX_FIFO_DEPTH = 512;
	
	//Number of bits in a thread ID
	localparam TX_FIFO_BITS		= clog2(RPC_TX_FIFO_DEPTH);
	
	//Execution unit number
	parameter					UNIT_NUM	= 0;
	
	//Our address
	parameter NOC_ADDR				= 16'h0;
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	//Inhibit input
	//Forces all operations to be NOP
	input wire			exec0_en;
	
	//Input data from register file
	input wire[31:0]	exec0_rs;
	input wire[31:0]	exec0_rt;
	
	//Destination register
	input wire[4:0]		exec0_rd_id;
	
	//Thread stuff
	input wire[TID_BITS-1 : 0]	exec0_tid;
	
	//Decoded instruction inputs
	input wire			exec0_rtype;
	input wire			exec0_itype;
	input wire			exec0_jtype;
	input wire[5:0]		exec0_opcode;
	input wire[5:0]		exec0_func;
	input wire[15:0]	exec0_immval;
	input wire[25:0]	exec0_jtype_addr;
	input wire[4:0]		exec0_shamt;
	input wire			exec0_syscall;
	input wire			exec0_syscall_repeat;
	input wire			exec0_mem;
	input wire[4:0]		exec0_branch_op;
	input wire			exec0_div;
	input wire			exec0_div_sign;
	
	//Jump stuff
	input wire[31:0]	exec0_pc;
	(* REGISTER_BALANCING = "yes" *)
	output reg			exec1_branch_en		= 0;
	output reg[31:0]	exec1_branch_addr	= 0;
	output reg			exec1_stall			= 0;
	
	//Outputs for register file writeback
	(* REGISTER_BALANCING = "yes" *)
	output reg			exec3_wr_en			= 0;
	output reg[4:0]		exec3_wr_id			= 0;
	(* REGISTER_BALANCING = "yes" *)
	output reg[31:0]	exec3_wr_data		= 0;
	
	//RPC transmit interface (unit 0 only)
	output reg						exec1_rpc_tx_fifo_wr = 0;
	input wire[TX_FIFO_BITS : 0]	exec0_rpc_tx_fifo_wsize;
	
	//RPC receive interface (master is unit 0)
	output reg			exec0_rpc_rx_en		= 0;
	input wire			exec0_rpc_rx_en_master;
	input wire			exec1_rpc_rx_valid;
	input wire[31:0]	exec2_rpc_rx_data;
	
	//Multiply/divide unit interface (only unit 0 can write, both can read)
	input wire					exec0_div_busy;
	output reg					exec1_mdu_wr_lo	= 0;
	output reg					exec1_mdu_wr_hi	= 0;
	output reg[31:0]			exec1_mdu_wdata	= 0;
	input wire[31:0]			exec2_mdu_rdata_lo;
	input wire[31:0]			exec2_mdu_rdata_hi;
	output wire					div_done;
	output wire[TID_BITS-1 : 0]	div_done_tid;
	output wire[31:0]			div_quot;
	output wire[31:0]			div_rem;
	
	output reg			decode1_mdu_wr			= 0;
	output reg[31:0]	decode1_mdu_wdata_lo	= 0;
	output reg[31:0]	decode1_mdu_wdata_hi	= 0;
	
	//D-side data bus (unit 0 only)
	output reg			exec0_dside_rd			= 0;
	output reg			exec0_dside_wr			= 0;
	output reg[3:0]		exec0_dside_wmask		= 0;
	output reg[31:0]	exec0_dside_addr		= 0;
	output reg[31:0]	exec0_dside_wdata		= 0;
	input wire[63:0]	exec2_dside_rdata;
	input wire[1:0]		exec2_dside_hit;
	output reg			exec2_mem_stall			= 0;
	
	//Status flags
	output reg			exec1_bad_instruction	= 0;
	output reg			trace_flag				= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push status down the pipeline
	
	reg					exec1_en		= 0;
	reg					exec2_en		= 0;
	reg					exec3_en		= 0;
	
	reg[4:0]			exec1_rd_id		= 0;
	reg[4:0]			exec2_rd_id		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Barrel shifter
	
	//Shifter inputs
	reg[63:0]	shift_in 	= 0;
	reg			shift_en	= 0;
	reg			shift_left	= 0;
	reg[4:0]	shift_amt	= 0;
	
	//The actual shifter
	reg[63:0]	shift_out_raw = 0;
	always @(*) begin
		if(shift_left)
			shift_out_raw <= {32'h0, shift_in[31:0] << shift_amt};
		else
			shift_out_raw <= shift_in >> shift_amt;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multiply/divide unit stuff
	
	//delayed enable flags
	reg			exec1_mdu_en_lo	= 0;
	reg			exec1_mdu_en_hi = 0;
	reg			exec2_mdu_en_lo	= 0; 
	reg			exec2_mdu_en_hi	= 0;
	
	always @(posedge clk) begin
		exec2_mdu_en_lo	<= exec1_mdu_en_lo;
		exec2_mdu_en_hi	<= exec1_mdu_en_hi;
	end
	
	wire		exec0_multiply		=  exec0_en && exec0_rtype && (
											(exec0_func == FUNC_MULT) ||
											(exec0_func == FUNC_MULTU)
											);
	wire		exec0_multiply_signed	= (exec0_func == FUNC_MULT);
	
	//The signed multiplier
	(* MULT_STYLE = "pipe_block" *)
	reg[63:0]	exec1_signed_multiplier_out	= 0;
	reg[63:0]	exec2_signed_multiplier_out	= 0;
	reg[63:0]	exec3_signed_multiplier_out	= 0;
	reg[63:0]	ifetch0_signed_multiplier_out	= 0;
	reg[63:0]	ifetch1_signed_multiplier_out	= 0;
	reg[63:0]	decode0_signed_multiplier_out	= 0;
	always @(posedge clk) begin
		exec1_signed_multiplier_out	<=  $signed(exec0_rs) * $signed(exec0_rt);
		exec2_signed_multiplier_out	<= exec1_signed_multiplier_out;
		exec3_signed_multiplier_out	<= exec2_signed_multiplier_out;
		ifetch0_signed_multiplier_out	<= exec3_signed_multiplier_out;
		ifetch1_signed_multiplier_out	<= ifetch0_signed_multiplier_out;
		decode0_signed_multiplier_out	<= ifetch1_signed_multiplier_out;
	end
	
	//The unsigned multiplier
	(* MULT_STYLE = "pipe_block" *)
	reg[63:0]	exec1_unsigned_multiplier_out	= 0;
	reg[63:0]	exec2_unsigned_multiplier_out	= 0;
	reg[63:0]	exec3_unsigned_multiplier_out	= 0;
	reg[63:0]	ifetch0_unsigned_multiplier_out	= 0;
	reg[63:0]	ifetch1_unsigned_multiplier_out	= 0;
	reg[63:0]	decode0_unsigned_multiplier_out	= 0;
	always @(posedge clk) begin
		exec1_unsigned_multiplier_out	<= exec0_rs * exec0_rt;
		exec2_unsigned_multiplier_out	<= exec1_unsigned_multiplier_out;
		exec3_unsigned_multiplier_out	<= exec2_unsigned_multiplier_out;
		ifetch0_unsigned_multiplier_out	<= exec3_unsigned_multiplier_out;
		ifetch1_unsigned_multiplier_out	<= ifetch0_unsigned_multiplier_out;
		decode0_unsigned_multiplier_out	<= ifetch1_unsigned_multiplier_out;
	end
	
	//The divider
	generate
	
		if(UNIT_NUM == 0) begin
			SaratogaCPUDivider #(
				.MAX_THREADS(MAX_THREADS)
			) divider (
				.clk(clk),
				.in_start(exec0_en && exec0_div),
				.in_sign(exec0_div_sign),
				.in_tid(exec0_tid),
				.in_dend(exec0_rs),
				.in_dvsr(exec0_rt),
				.out_done(div_done),
				.out_tid(div_done_tid),
				.out_quot(div_quot),
				.out_rem(div_rem)
				);
		end
		
		//disable if not in use to avoid warnings
		else begin
			assign div_done = 0;
			assign div_done_tid = 0;
			assign div_quot = 0;
			assign div_rem = 0;
		end				
				
	endgenerate
	
	
	//MDU state tracking
	reg			exec1_mult_en			= 0;
	reg			exec2_mult_en			= 0;
	reg			exec3_mult_en			= 0;
	reg			ifetch0_mult_en			= 0;
	reg			ifetch1_mult_en			= 0;
	reg			decode0_mult_en			= 0;
	reg			exec1_mult_signed		= 0;
	reg			exec2_mult_signed		= 0;
	reg			exec3_mult_signed		= 0;
	reg			ifetch0_mult_signed		= 0;
	reg			ifetch1_mult_signed		= 0;
	reg			decode0_mult_signed		= 0;
	always @(posedge clk) begin
		exec1_mult_en			<= exec0_multiply;
		exec2_mult_en			<= exec1_mult_en;
		exec3_mult_en			<= exec2_mult_en;
		ifetch0_mult_en			<= exec3_mult_en;
		ifetch1_mult_en			<= ifetch0_mult_en;
		decode0_mult_en			<= ifetch1_mult_en;
		exec1_mult_signed		<= exec0_multiply_signed;
		exec2_mult_signed		<= exec1_mult_signed;
		exec3_mult_signed		<= exec2_mult_signed;
		ifetch0_mult_signed		<= exec3_mult_signed;
		ifetch1_mult_signed		<= ifetch0_mult_signed;
		decode0_mult_signed		<= ifetch1_mult_signed;
	end
	
	//MDU outputs
	always @(posedge clk) begin
		decode1_mdu_wr			<= decode0_mult_en;					//TODO: divide
		
		if(decode0_mult_signed) begin
			decode1_mdu_wdata_lo	<= decode0_signed_multiplier_out[31:0];
			decode1_mdu_wdata_hi	<= decode0_signed_multiplier_out[63:32];
		end
		
		else begin
			decode1_mdu_wdata_lo	<= decode0_unsigned_multiplier_out[31:0];
			decode1_mdu_wdata_hi	<= decode0_unsigned_multiplier_out[63:32];
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main execution logic	
	
	`include "SaratogaCPUInstructionFunctions_constants.v"
	`include "SaratogaCPUInstructionOpcodes_constants.v"
	`include "SaratogaCPUBranchOpcodes_constants.v"
	`include "SaratogaCPURegisterIDs_constants.v"
	`include "SaratogaCPUSyscalls_constants.v"
	
	//Indicates that all calculation is done, no further work required
	reg			exec1_done		= 0;
	reg			exec2_done		= 0;
	
	reg			exec1_wr_en		= 0;
	reg			exec2_wr_en		= 0;
	
	//Write data
	(* REGISTER_BALANCING = "yes" *)
	reg[31:0]	exec1_wr_data	= 0;
	reg[31:0]	exec2_wr_data	= 0;
	
	//Blocking when an RPC transaction fails
	reg			exec1_rpc_block		= 0;
	
	//Waiting on an RPC receive
	reg			exec1_rpc_rx_en	= 0;
	reg			exec2_rpc_rx_en	= 0;
	
	//Remember if the RPC receive was successful
	reg			exec2_rpc_rx_valid	= 0;
	
	//Sign-extend the immediate value
	wire[31:0] exec0_immval_sx;
	assign exec0_immval_sx = { {16{exec0_immval[15]}}, exec0_immval };
	
	reg			exec1_syscall_repeat	= 0;
	reg			exec2_syscall_repeat	= 0;
	
	localparam WORDSIZE_NONE			= 0;
	localparam WORDSIZE_BYTE			= 1;
	localparam WORDSIZE_HALF			= 2;
	localparam WORDSIZE_WORD			= 3;
	
	//Memory read state	
	reg			exec1_mem				= 0;
	reg			exec2_mem				= 0;
	reg			exec1_memrd				= 0;
	reg			exec2_memrd				= 0;
	reg[1:0]	exec1_memsize			= WORDSIZE_NONE;
	reg[1:0]	exec2_memsize			= WORDSIZE_NONE;
	reg			exec1_mem_sx			= 0;
	reg			exec2_mem_sx			= 0;
	reg[1:0]	exec1_mem_bpos			= 0;
	reg[1:0]	exec2_mem_bpos			= 0;
	
	always @(*) begin
		
		//default to not receiving RPC
		exec0_rpc_rx_en		<= 0;
		
		if(exec0_en && exec0_syscall) begin
		
			case(exec0_rs[23:16])

				SYS_RECV_RPC_BLOCKING: begin
					exec0_rpc_rx_en			<= 1;
				end	//end SYS_RECV_RPC_BLOCKING
			
			endcase
		
		end
		
	end
	
	//Drive D-side commands to the L1 cache combinatorially
	reg[31:0]		exec0_dside_addr_raw		= 0;
	always @(*) begin
	
		//Address bus (valid even when not used, to improve timing
		exec0_dside_addr_raw		<= exec0_rs + exec0_immval_sx;
			
		//Address must always be word aligned
		exec0_dside_addr			<= {exec0_dside_addr_raw[31:2], 2'h0};
			
		//Byte write enables
		if(exec0_opcode == OP_SB) begin
			case(exec0_dside_addr_raw[1:0])
				0: exec0_dside_wmask	<= 4'b1000;
				1: exec0_dside_wmask	<= 4'b0100;
				2: exec0_dside_wmask	<= 4'b0010;
				3: exec0_dside_wmask	<= 4'b0001;
			endcase
		end
		else if(exec0_opcode == OP_SH) begin
			if(exec0_dside_addr_raw[1])	//second half
				exec0_dside_wmask	<= 4'b0011;
			else						//first half
				exec0_dside_wmask	<= 4'b1100;
		end
		else
			exec0_dside_wmask		<= 4'b1111;
				
		//Write enable
		exec0_dside_wr			<= exec0_en && exec0_mem && (
									(exec0_opcode == OP_SW) ||
									(exec0_opcode == OP_SB) ||
									(exec0_opcode == OP_SH)		);
										
		//Write data
		//Include some dontcare bits to avoid having register values in the mux control path
		if(exec0_opcode == OP_SB)
			exec0_dside_wdata	<= {exec0_rt[7:0], exec0_rt[7:0], exec0_rt[7:0], exec0_rt[7:0]};
		else if(exec0_opcode == OP_SH)
			exec0_dside_wdata	<= {exec0_rt[15:0], exec0_rt[15:0]};
		else
			exec0_dside_wdata	<= exec0_rt;
		
		//Read enable
		exec0_dside_rd			<= exec0_en && exec0_mem && (
									(exec0_opcode == OP_LW) ||
									(exec0_opcode == OP_LB) ||
									(exec0_opcode == OP_LBU) ||
									(exec0_opcode == OP_LH) ||
									(exec0_opcode == OP_LHU)	);
	end
	
	//Combinatorial processing of incoming memory bus data
	reg[31:0]		exec2_memdata					= 0;
	reg[31:0]		exec2_memdata_nx				= 0;
	reg[31:0]		exec2_memdata_offset			= 0;
	always @(*) begin
		
		//First, shift as needed based on the offset
		case(exec2_mem_bpos)
			0:		exec2_memdata_offset <= exec2_dside_rdata[63:32];
			1:		exec2_memdata_offset <= {exec2_dside_rdata[55:32], 8'h0};
			2:		exec2_memdata_offset <= {exec2_dside_rdata[47:32], 16'h0};
			3:		exec2_memdata_offset <= {exec2_dside_rdata[39:32], 24'h0};
		endcase
		
		//Second, extract however many words we need
		case(exec2_memsize)
			WORDSIZE_NONE:	exec2_memdata_nx		<= 0;
			WORDSIZE_BYTE:	exec2_memdata_nx		<= exec2_memdata_offset[31:24];
			WORDSIZE_HALF:	exec2_memdata_nx		<= exec2_memdata_offset[31:16];
			WORDSIZE_WORD:	exec2_memdata_nx		<= exec2_memdata_offset;
		endcase
		
		//Finally, sign extend
		if(exec2_mem_sx) begin
			case(exec2_memsize)
				WORDSIZE_NONE:	exec2_memdata		<= 0;
				WORDSIZE_BYTE:	exec2_memdata		<= { {24{exec2_memdata_nx[7]}}, exec2_memdata_nx[7:0] };
				WORDSIZE_HALF:	exec2_memdata		<= { {16{exec2_memdata_nx[15]}}, exec2_memdata_nx[15:0] };
				WORDSIZE_WORD:	exec2_memdata		<= exec2_memdata_nx;
			endcase
		end
		else	
			exec2_memdata		<= exec2_memdata_nx;
				
	end
	
	//default I-type and J-type branch target
	reg[31:0]		exec0_ibranch_target			= 0;
	reg[31:0]		exec0_jbranch_target			= 0;
	always @(*) begin
		exec0_ibranch_target	<= exec0_pc + {exec0_immval_sx[29:0], 2'h0} + 32'h4;
		exec0_jbranch_target	<= {exec0_pc[31:28], exec0_jtype_addr, 2'h0};
	end
	
	reg				exec1_div_stall					= 0;
			
	always @(posedge clk) begin
	
		//Default to passing status down the pipeline
		exec1_rd_id				<= exec0_rd_id;
		exec2_rd_id				<= exec1_rd_id;
		exec1_en				<= exec0_en;
		exec2_en				<= exec1_en;
		exec3_en				<= exec2_en;
		exec1_done				<= 0;
		exec2_done				<= exec1_done;
		exec1_wr_en				<= 0;
		exec2_wr_en				<= exec1_wr_en;
		exec3_wr_en				<= exec2_wr_en && (exec2_rd_id != zero);	//gate writes to $zero
		exec1_wr_data			<= 0;
		exec2_wr_data			<= exec1_wr_data;
		exec3_wr_data			<= exec2_wr_data;
		exec1_syscall_repeat	<= exec0_syscall_repeat;
		exec2_syscall_repeat	<= exec1_syscall_repeat;
		exec3_wr_id				<= exec2_rd_id;
		exec1_mem				<= exec0_mem && exec0_en;
		exec2_mem				<= exec1_mem;
		exec1_memrd				<= 0;
		exec2_memrd				<= exec1_memrd;
				
		//default to not shifting
		shift_en			<= 0;
		shift_in			<= 0;
		shift_left			<= 0;
		shift_amt			<= 0;
		
		//default to not touching MDU
		exec1_mdu_en_lo	<= 0; 
		exec1_mdu_en_hi	<= 0; 
		exec1_mdu_wr_lo	<= 0;
		exec1_mdu_wr_hi	<= 0;
		exec1_mdu_wdata	<= 0;
		exec1_div_stall	<= 0;
		
		//Keep track of byte position when doing byte/halfword loads
		exec1_mem_bpos	<= exec0_dside_addr_raw[1:0];
		
		//default to not doing memory
		exec1_memsize	<= WORDSIZE_NONE;
		exec2_memsize	<= exec1_memsize;
		exec1_mem_sx	<= 0;
		exec2_mem_sx	<= exec1_mem_sx;
		exec2_mem_bpos	<= exec1_mem_bpos;
		
		//default to not sending RPC
		exec1_rpc_tx_fifo_wr	<= 0;
		exec1_rpc_block			<= 0;
		
		//Keep track of whether an RPC receive is in progress
		exec1_rpc_rx_en		<= exec0_rpc_rx_en || exec0_rpc_rx_en_master;
		exec2_rpc_rx_en		<= exec1_rpc_rx_en;
		exec2_rpc_rx_valid	<= exec1_rpc_rx_valid;
		
		exec1_bad_instruction	<= 0;
		
		//default to not branching
		exec1_branch_en		<= 0;
		
		//Set branch destination address depending only on instruction format and not opcode
		//This takes most of the opcode out of the critical path for branches
		if(exec0_jtype)
			exec1_branch_addr	<= exec0_jbranch_target;
		else if(exec0_rtype)
			exec1_branch_addr	<= exec0_rs;
		else
			exec1_branch_addr	<= exec0_ibranch_target;
		
		//Not tracing
		trace_flag			<= 0;
		
		//do nothing if disabled
		if(!exec0_en) begin
		end
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Do simple ALU instructions the first cycle, then sit back and wait
		
		else if(exec0_syscall && !exec0_syscall_repeat) begin
			
			//Only process this if we are the master unit
			if(UNIT_NUM == 0) begin
			
				//System call (set things in motion, but don't compute result yet)
				case(exec0_rs[23:16])
					
					SYS_SEND_RPC_BLOCKING: begin
						//Send it if it fits (and we're actually executing)
						if(exec0_rpc_tx_fifo_wsize >= 8 )
							exec1_rpc_tx_fifo_wr <= exec0_en;
						
						//Block if we asked for it
						else if(exec0_rs[23:16] == SYS_SEND_RPC_BLOCKING)
							exec1_rpc_block		<= 1;
							
						exec1_done	<= 1;
							
					end	//end SYS_SEND_RPC_BLOCKING
					
					SYS_RECV_RPC_BLOCKING: begin
						//handled combinatorially
					end	//end SYS_RECV_RPC_BLOCKING
					
					SYS_GET_OOB: begin
						if(UNIT_NUM == 0)
							exec1_wr_en	<= 1;
						exec1_wr_data	<= NOC_ADDR;
						exec1_rd_id		<= v0;
						exec1_done		<= 1;
					end
					
					SYS_TRACE: begin
						trace_flag	<= 1;
						exec1_done	<= 1;
					end
					
					default: begin
						$display("Syscall (code %x) at T=%d", exec0_rs[23:16], $time());
					end
			
				endcase
				
			end	//unit_num == 0
			
		end
		
		else if(exec0_rtype) begin
			case(exec0_func)
			
				//Add signed (same as addu)
				FUNC_ADD: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs + exec0_rt;
				end
			
				//Add unsigned
				FUNC_ADDU: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs + exec0_rt;
				end
				
				//Bitwise AND
				FUNC_AND: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs & exec0_rt;
				end
				
				//gcc divide-by-zero checks, ignore
				FUNC_BREAK: begin
					//Generated by gcc after a divide for div-by-zero checks
					//Do nothing
				end
				
				//Signed divide
				FUNC_DIV: begin
					//handled by divider core, nothing to do here
				end
				
				//Unsigned divide
				FUNC_DIVU: begin
					//handled by divider core, nothing to do here
				end
				
				//Jump and link to register
				FUNC_JALR: begin
					exec1_done			<= 1;
					exec1_branch_en		<= 1;

					exec1_wr_en			<= 1;
					exec1_wr_data		<= exec0_pc + 32'h8;		//skip delay slot instruction
				end
				
				//Jump to register
				FUNC_JR: begin
					exec1_wr_en			<= 0;
					exec1_done			<= 1;
					exec1_branch_en		<= 1;
				end
				
				//Move From Hi
				FUNC_MFHI: begin
					if(exec0_div_busy) begin
						exec1_done			<= 0;
						exec1_div_stall		<= 1;
					end
					else begin
						exec1_done			<= 0;
						exec1_mdu_en_hi		<= 1;
					end
				end
				
				//Move From Lo
				FUNC_MFLO: begin
					if(exec0_div_busy) begin
						exec1_done			<= 0;
						exec1_div_stall		<= 1;
					end
					else begin
						exec1_done			<= 0;
						exec1_mdu_en_lo		<= 1;
					end
				end
				
				//Move To Hi
				FUNC_MTHI: begin
					exec1_done			<= 1;
					exec1_mdu_en_hi		<= 1;
					exec1_mdu_wr_hi		<= 1;
					exec1_mdu_wdata		<= exec0_rs;
				end
				
				//Move To Lo
				FUNC_MTLO: begin
					exec1_done			<= 1;
					exec1_mdu_en_lo		<= 1;
					exec1_mdu_wr_lo		<= 1;
					exec1_mdu_wdata		<= exec0_rs;
				end
				
				//Multiply Signed
				FUNC_MULT: begin
					//nothing here, handled elsewhere
					exec1_done			<= 1;
				end
				
				//Multiply Unsigned
				FUNC_MULTU: begin
					//nothing here, handled elsewhere
					exec1_done			<= 1;
				end
				
				//Bitwise NOR
				FUNC_NOR: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= ~(exec0_rs | exec0_rt);
				end
				
				//Bitwise OR
				FUNC_OR: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs | exec0_rt;
				end
				
				//Shift left logical
				FUNC_SLL: begin
					shift_en		<= 1;
					shift_left		<= 1;
					shift_in		<= {32'h0, exec0_rt};
					shift_amt		<= exec0_shamt;
					
					exec1_wr_en		<= 1;
				end
				
				//Shift left logical by value
				FUNC_SLLV: begin
					shift_en		<= 1;
					shift_left		<= 1;
					shift_in		<= {32'h0, exec0_rt};
					shift_amt		<= exec0_rs[4:0];
					
					exec1_wr_en		<= 1;
				end
				
				//Set if less than
				FUNC_SLT: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					if($signed(exec0_rs) < $signed(exec0_rt))
						exec1_wr_data	<= 1;
					else
						exec1_wr_data	<= 0;
				end
				
				//Set if less than unsigned
				FUNC_SLTU: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					if(exec0_rs < exec0_rt)
						exec1_wr_data	<= 1;
					else
						exec1_wr_data	<= 0;
				end
				
				//Shift right arithmetic
				FUNC_SRA: begin
					shift_en		<= 1;
					shift_left		<= 0;
					shift_in		<= { {32{exec0_rt[31]}}, exec0_rt};
					shift_amt		<= exec0_shamt;
					
					exec1_wr_en		<= 1;
				end
				
				//Shift right arithmetic by value
				FUNC_SRAV: begin
					shift_en		<= 1;
					shift_left		<= 0;
					shift_in		<= { {32{exec0_rt[31]}}, exec0_rt};
					shift_amt		<= exec0_rs[4:0];
					
					exec1_wr_en		<= 1;
				end
				
				//Shift right logical
				FUNC_SRL: begin
					shift_en		<= 1;
					shift_left		<= 0;
					shift_in		<= {32'h0, exec0_rt};
					shift_amt		<= exec0_shamt;
					
					exec1_wr_en		<= 1;
				end
				
				//Shift right logical by value
				FUNC_SRLV: begin
					shift_en		<= 1;
					shift_left		<= 0;
					shift_in		<= {32'h0, exec0_rt};
					shift_amt		<= exec0_rs[4:0];
					
					exec1_wr_en		<= 1;
				end
				
				//Subtract signed (same as subu)
				FUNC_SUB: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs - exec0_rt;
				end
				
				//Subtract unsigned
				FUNC_SUBU: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs - exec0_rt;
				end

				//System call (handled elsewhere)
				FUNC_SYSCALL: begin
				end
				
				//Bitwise XOR
				FUNC_XOR: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs ^ exec0_rt;
				end
			
				default: begin
					$display("Unknown instruction (R-type function %x) at T=%d", exec0_func, $time());
					exec1_bad_instruction	<= 1;
				end
				
			endcase
		end
		else begin
		
			case(exec0_opcode)
			
				//Add immediate (same as addiu since we dont do overflow traps)
				OP_ADDI: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs + exec0_immval_sx;
				end
			
				//Add immediate unsigned
				OP_ADDIU: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs + exec0_immval_sx;
				end
			
				//Bitwise AND immediate
				OP_ANDI: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs & exec0_immval;
				end
			
				//Branch if equal
				OP_BEQ: begin
					exec1_wr_en			<= 0;
					exec1_done			<= 1;
					
					exec1_branch_en		<= (exec0_rs == exec0_rt);
				end
				
				//Branch if greater than zero
				OP_BGTZ: begin
					exec1_wr_en			<= 0;
					exec1_done			<= 1;
					
					exec1_branch_en		<= ($signed(exec0_rs) > 0);
				end				
				
				//Branch if less than or equal to zero
				OP_BLEZ: begin
					exec1_wr_en			<= 0;
					exec1_done			<= 1;
					
					exec1_branch_en		<= ($signed(exec0_rs) <= 0);
				end	
			
				//Branch if not equal
				OP_BNE: begin
					exec1_wr_en			<= 0;
					exec1_done			<= 1;
					
					exec1_branch_en		<= (exec0_rs != exec0_rt);
				end
			
				//MUltiple branch opcodes
				OP_BRANCH: begin
				
					//done after this insn
					exec1_done			<= 1;
					
					//prepare to link either way
					exec1_wr_data		<= exec0_pc + 32'h8;		//skip delay slot instruction
				
					case(exec0_branch_op)
						BRANCH_BGEZ: begin
							exec1_branch_en	<= ($signed(exec0_rs) >= 0);
						end
						BRANCH_BGEZAL: begin
							exec1_branch_en	<= ($signed(exec0_rs) >= 0);
							exec1_wr_en		<= ($signed(exec0_rs) >= 0);
						end
						BRANCH_BLTZ: begin
							exec1_branch_en	<= ($signed(exec0_rs) < 0);
						end
						BRANCH_BLTZAL: begin
							exec1_branch_en	<= ($signed(exec0_rs) < 0);
							exec1_wr_en		<= ($signed(exec0_rs) < 0);
						end
					endcase
				end
				
				//OP_COPROC not implemented for now
			
				//Jump
				OP_J: begin
					exec1_wr_en			<= 0;
					exec1_done			<= 1;
					
					exec1_branch_en		<= 1;
				end
			
				//Jump and link
				OP_JAL: begin
					exec1_wr_en			<= 1;
					exec1_done			<= 1;
					exec1_wr_data		<= exec0_pc + 32'h8;		//skip delay slot instruction
					
					exec1_branch_en		<= 1;
				end
				
				//Load Byte
				OP_LB: begin
					exec1_memsize		<= WORDSIZE_BYTE;
					exec1_mem_sx		<= 1;
					exec1_memrd			<= 1;
				end
				
				//Load Byte Unsigned
				OP_LBU: begin
					exec1_memsize		<= WORDSIZE_BYTE;
					exec1_mem_sx		<= 0;
					exec1_memrd			<= 1;
				end
				
				//Load Halfword
				OP_LH: begin
					exec1_memsize		<= WORDSIZE_HALF;
					exec1_mem_sx		<= 1;
					exec1_memrd			<= 1;
				end
				
				//Load Halfword Unsigned
				OP_LHU: begin
					exec1_memsize		<= WORDSIZE_HALF;
					exec1_mem_sx		<= 0;
					exec1_memrd			<= 1;
				end
				
				//Load-upper-immediate
				OP_LUI: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= {exec0_immval, 16'h0};
				end
				
				//Load Word
				OP_LW: begin
					exec1_memsize		<= WORDSIZE_WORD;
					exec1_mem_sx		<= 0;
					exec1_memrd			<= 1;
				end
				
				//Bitwise OR immediate
				OP_ORI: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs | exec0_immval;
				end
				
				//Store Byte
				OP_SB: begin
					//nothing yet
				end
				
				//Store Halfword
				OP_SH: begin
					//nothing yet
				end
				
				//Set if less than immediate
				OP_SLTI: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					if($signed(exec0_rs) < $signed(exec0_immval_sx))
						exec1_wr_data	<= 1;
					else
						exec1_wr_data	<= 0;
				end
				
				//Set if less than immediate unsigned
				OP_SLTIU: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					if(exec0_rs < exec0_immval_sx)
						exec1_wr_data	<= 1;
					else
						exec1_wr_data	<= 0;
				end
				
				//Store Word
				OP_SW: begin
					//nothing yet
				end
				
				//Bitwise XOR immediate
				OP_XORI: begin
					exec1_wr_en		<= 1;
					exec1_done		<= 1;
					exec1_wr_data	<= exec0_rs ^ exec0_immval;
				end
				
				default: begin
					$display("Unknown instruction (opcode %x) at T=%d", exec0_func, $time());
					exec1_bad_instruction	<= 1;
				end
				
			endcase
		end
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Second cycle processing
	
		if(!exec1_done) begin
			
			//Wait for result from the barrel shifter, then use it
			if(shift_en) begin
				exec2_wr_en		<= 1;
				exec2_done		<= 1;
				exec2_wr_data	<= shift_out_raw[31:0];
			end
			
			//MFLO/MFHI are busy but nothing to do until next cycle
			
			//memory reads are busy but nothing to do until next cycle
			
		end
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Third cycle processing
		
		if(!exec2_done) begin
		
			//MFLO
			if(exec2_mdu_en_lo) begin
				exec3_wr_en		<= 1;
				exec3_wr_data	<= exec2_mdu_rdata_lo;
			end
			
			//MFHI
			if(exec2_mdu_en_hi) begin
				exec3_wr_en		<= 1;
				exec3_wr_data	<= exec2_mdu_rdata_hi;
			end
			
			//Memory read
			if(exec2_memrd) begin
			
				//Hits
				if(exec2_dside_hit[1]) begin
					exec3_wr_en		<= 1;
					exec3_wr_data	<= exec2_memdata;
				end
				
				//Wipe out register ID if miss... can be removed to improve timing but makes LA traces cleaner
				else begin
					exec3_wr_id		<= 0;
				end
			end
			
			//Process incoming RPCs if successful
			if(exec2_rpc_rx_en && (exec2_rpc_rx_valid || exec2_syscall_repeat)) begin
			
				//First cycle is 127:64
				//Second cycle is 31:0
			
				if(UNIT_NUM == 0) begin
					if(exec2_syscall_repeat)
						exec3_wr_id		<= k0;	//63:32
					else
						exec3_wr_id		<= v1;	//127:96
				end
				
				else begin
					if(exec2_syscall_repeat)
						exec3_wr_id		<= k1;	//31:0
					else
						exec3_wr_id		<= v0;	//95:64
				end
			
				exec3_wr_data	<= exec2_rpc_rx_data;
				exec3_wr_en		<= 1;
				
			end
			
		end
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Stall calculation
	
	always @(*) begin
	
		exec1_stall		<= 0;
		
		//Stall if RPC transmit fifo is full	
		if(exec1_rpc_block)
			exec1_stall		<= 1;
			
		//Receiving an RPC?
		if(exec1_rpc_rx_en) begin
		
			//Stall unless this is the second half
			if(!exec1_syscall_repeat)
				exec1_stall	<= 1;
		
		end
		
		//Stall if reading from MDU and divide is in progress
		if(exec1_div_stall)
			exec1_stall	<= 1;
		
		//Declare stall in case of cache miss
		exec2_mem_stall	<= exec2_mem && !exec2_dside_hit[1];
		
	end
	
endmodule


