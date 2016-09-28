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
	@brief EXECUTE stage of GRAFTON pipeline
 */
module GraftonCPUExecuteStage(
	clk,
	execute_regval_a, execute_regval_b, 
	execute_rtype, execute_bubble, execute_opcode, execute_func, execute_immval, execute_regid_d,
	stall_in, stall_out, execute_jumping, execute_jump_address, execute_pc, execute_jump_offset,
	execute_shamt, execute_coproc_op, execute_branch_op,
	
	rpc_fab_tx_done, rpc_fab_rx_en, rpc_fab_rx_done,
	
	cp0_wr_en, rpc_fab_tx_en,
	cp0_rd_en, cp0_rd_data,
	
	mem_regid_d, mem_regval, mem_regwrite, mem_read_lsb,
	
	mem_read_size, mem_read_sx,
	
	dside_rd_en, dside_cpu_addr,
	dside_wr_en, dside_wr_mask, dside_wr_data,
	
	trace_flag,
	
	mmu_wr_en, cache_flush_en,
	
	mdu_lo, mdu_hi,
	
	freeze, bad_instruction, bad_instruction_opcode, bad_instruction_func, bad_instruction_pc/*,
	
	execute_mem_addr, rpc_rx_pending*/
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//Inputs from register file
	input wire[31:0] execute_regval_a;
	input wire[31:0] execute_regval_b;
	
	//Inputs from decode stage
	input wire execute_rtype;
	input wire execute_bubble;
	input wire[5:0] execute_opcode;
	input wire[5:0] execute_func;
	input wire[15:0] execute_immval;
	input wire[4:0] execute_regid_d;
	input wire[31:0] execute_pc;
	input wire[25:0] execute_jump_offset;
	input wire[4:0] execute_shamt;
	input wire[4:0] execute_coproc_op;
	input wire[4:0] execute_branch_op;
	
	//RPC interface
	output reg rpc_fab_tx_en = 0;
	input wire rpc_fab_tx_done;
	input wire rpc_fab_rx_en;
	output reg rpc_fab_rx_done = 0;
	
	//Stall stuff
	input wire stall_in;
	output reg stall_out = 0;
	
	//Output data
	output reg mem_regwrite = 0;
	output reg[4:0] mem_regid_d = 0;
	output reg[31:0] mem_regval = 0;
	
	//Memory control stuff
	output reg[1:0] mem_read_size = 0;
	output reg mem_read_sx = 0;
	output reg[1:0] mem_read_lsb = 0;
	
	//Coprocessor 0 interface
	output reg cp0_wr_en = 0;
	output wire cp0_rd_en;
	input wire[31:0] cp0_rd_data;
	
	//Outputs for debug core
	output mdu_lo;
	output mdu_hi;
	
	//MMU / cache interface
	output reg mmu_wr_en = 0;
	output reg cache_flush_en;
	
	//Combinatorial outputs for jumping
	output reg execute_jumping = 0;
	output reg[31:0] execute_jump_address = 0;
	
	//Status stuff
	input wire freeze;
	output reg bad_instruction = 0;
	output reg[5:0] bad_instruction_opcode = 0;
	output reg[5:0] bad_instruction_func = 0;
	output reg[31:0] bad_instruction_pc = 0;
	
	//D-side memory bus control
	output reg dside_rd_en = 0;
	output reg[31:0] dside_cpu_addr = 0;
	output reg dside_wr_en = 0;
	output reg[3:0] dside_wr_mask = 0;
	output reg[31:0] dside_wr_data = 0;
	
	//Trace bus
	output reg trace_flag = 0;
	
	//Jump offset
	//TODO: Compute this in decode stage?
	wire[31:0] execute_immval_sx;
	assign execute_immval_sx = { {16{execute_immval[15]}}, execute_immval };
	wire[31:0] execute_branch_address;
	assign execute_branch_address = execute_pc + {execute_immval_sx[29:0], 2'h0} + 32'h4;
	
	//Debug
	//output execute_mem_addr;
	//output rpc_rx_pending;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Virtual addresses of trap handlers for emulated instructions
	
	`include "GraftonCPUCoprocessorRegisters_constants.v"
	
	reg[31:0] div_handler = 0;
	reg[31:0] divu_handler = 0;
	
	always @(posedge clk) begin
		if(cp0_wr_en) begin
		
			case(mem_regid_d)
				cp0_div_handler:	div_handler <= mem_regval;
				cp0_divu_handler:	divu_handler <= mem_regval;
				
				default: begin
				end
			endcase
		
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Combinatorial logic for branches and coprocessor stuff
	
	`include "GraftonCPUInstructionFunctions_constants.v"
	`include "GraftonCPUInstructionOpcodes_constants.v"
	
	always @(*) begin
		
		execute_jumping <= 0;
		execute_jump_address <= 0;
		
		//If bubbling, do nothing
		if(execute_bubble) begin
		end
		
		//R-type instructions switch on func
		else if(execute_rtype) begin
			case(execute_func)
				FUNC_JALR: begin
					execute_jumping <= 1;
					execute_jump_address <= execute_regval_a;
				end	//end FUNC_JALR
				
				FUNC_JR: begin
					execute_jumping <= 1;
					execute_jump_address <= execute_regval_a;
				end	//end FUNC_JR
				
				FUNC_DIV: begin
					execute_jumping <= 1;
					execute_jump_address <= div_handler;
				end	//end FUNC_DIV
				
				FUNC_DIVU: begin
					execute_jumping <= 1;
					execute_jump_address <= divu_handler;
				end	//end FUNC_DIVU
				
				default: begin
					//not a jump, no action needed
				end
				
			endcase
		end	//end R-type
		
		//otherwise switch on opcode
		else begin
			case(execute_opcode)
			
				OP_BEQ: begin
					execute_jumping <= (execute_regval_a == execute_regval_b);
					execute_jump_address <= execute_branch_address;
				end	//end OP_BEQ
				
				OP_BGTZ: begin
					execute_jumping <= ($signed(execute_regval_a) > 0);
					execute_jump_address <= execute_branch_address;
				end	//end OP_BGTZ
				
				OP_BLEZ: begin
					execute_jumping <= ($signed(execute_regval_a) <= 0);
					execute_jump_address <= execute_branch_address;
				end	//end OP_BLEZ
			
				OP_BNE: begin
					execute_jumping <= (execute_regval_a != execute_regval_b);
					execute_jump_address <= execute_branch_address;
				end	//end OP_BNE
				
				//Several branch instruction use the same opcode
				OP_BRANCH: begin
					case(execute_branch_op)
						BRANCH_BGEZ: begin
							execute_jumping <= ($signed(execute_regval_a) >= 0);
							execute_jump_address <= execute_branch_address;
						end
						
						BRANCH_BGEZAL: begin
							execute_jumping <= ($signed(execute_regval_a) >= 0);
							execute_jump_address <= execute_branch_address;
						end
						
						BRANCH_BLTZ: begin
							execute_jumping <= ($signed(execute_regval_a) < 0);
							execute_jump_address <= execute_branch_address;
						end
						
						BRANCH_BLTZAL: begin
							execute_jumping <= ($signed(execute_regval_a) < 0);
							execute_jump_address <= execute_branch_address;
						end
						
						default: begin
						end
					endcase
				end	//end OP_BRANCH
				
				OP_J: begin
					execute_jumping <= 1;
					execute_jump_address <= {execute_pc[31:28], execute_jump_offset, 2'h0};
				end	//end OP_J
				
				OP_JAL: begin
					execute_jumping <= 1;
					execute_jump_address <= {execute_pc[31:28], execute_jump_offset, 2'h0};
				end	//end OP_JAL
				
				default: begin
					//not a jump, no action needed
				end
			endcase
		end	//end I/J type
		
	end
	
	assign cp0_rd_en = (execute_opcode == OP_COPROC) && (execute_coproc_op == OP_MFC0) && !stall_out && !execute_bubble;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Shifter(s)
	
	//Input muxing
	reg[4:0] shifter_offset = 0;
	reg shifter_direction = 0;		//1 = left
	reg shifter_sign_extend = 0;
	always @(*) begin
		
		shifter_sign_extend <= 0;
		shifter_direction <= 0;
		shifter_offset <= 0;
		
		case(execute_func)
			
			FUNC_SLL: begin
				shifter_offset <= execute_shamt;
				shifter_direction <= 1;
				shifter_sign_extend <= 0;
			end	//end FUNC_SLL
			
			FUNC_SLLV: begin
				shifter_offset <= execute_regval_a[4:0];
				shifter_direction <= 1;
				shifter_sign_extend <= 0;
			end	//end FUNC_SLLV
			
			FUNC_SRA: begin
				shifter_offset <= execute_shamt;
				shifter_direction <= 0;
				shifter_sign_extend <= 1;
			end	//end FUNC_SRA
			
			FUNC_SRAV: begin
				shifter_offset <= execute_regval_a[4:0];
				shifter_direction <= 0;
				shifter_sign_extend <= 1;
			end	//end FUNC_SRAV
			
			FUNC_SRL: begin
				shifter_offset <= execute_shamt;
				shifter_direction <= 0;
				shifter_sign_extend <= 0;
			end	//end FUNC_SLL
			
			FUNC_SRLV: begin
				shifter_offset <= execute_regval_a[4:0];
				shifter_direction <= 0;
				shifter_sign_extend <= 0;
			end	//end FUNC_SLLV
			
			default: begin
			end
			
		endcase
		
	end
	
	//Sign extend, or not, the input
	reg[63:0] shifter_in = 0;
	always @(*) begin
		shifter_in[63:32] <= 0;
		shifter_in[31:0] <= execute_regval_b;
		if(shifter_sign_extend)
			shifter_in[63:32] <= { 32{execute_regval_b[31]} };
	end
	
	//Do the actual shift
	reg[63:0] shifter_out_raw = 0;
	always @(*) begin
		if(shifter_direction == 1)
			shifter_out_raw <= {32'h0, shifter_in[31:0] << shifter_offset};
		else
			shifter_out_raw <= shifter_in >> shifter_offset;
	end
	
	//Explicit truncation to avoid warnings
	wire[31:0] shifter_out;
	assign shifter_out = shifter_out_raw[31:0];
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multiply / divide unit
	
	//Output registers
	reg[31:0] mdu_hi = 0;
	reg[31:0] mdu_lo = 0;
	
	//Buffer the register values after forwarding
	reg[31:0] execute_regval_a_buf = 0;
	reg[31:0] execute_regval_b_buf = 0;
	always @(posedge clk) begin
		execute_regval_a_buf <= execute_regval_a;
		execute_regval_b_buf <= execute_regval_b;
	end
	
	//Check if the multiplication is signed
	wire multiply_is_signed = (execute_func == FUNC_MULT);

	(* MULT_STYLE = "pipe_block" *) reg[63:0] mdu_product = 0;
	reg[63:0] mdu_product_buf = 0;
	always @(posedge clk) begin
		mdu_product <= multiply_is_signed ?
			( $signed(execute_regval_a_buf) * $signed(execute_regval_b_buf) ) :
			( execute_regval_a_buf * execute_regval_b_buf );
		
		mdu_product_buf <= mdu_product;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main execute logic
	
	`include "GraftonCPURegisterIDs_constants.v"
	`include "GraftonCPUCoprocessorOpcodes_constants.v"
	`include "GraftonCPUSyscalls_constants.v"
	`include "GraftonCPUBranchOpcodes_constants.v"
	
	localparam STALL_RPC_TX = 0;
	localparam STALL_RPC_RX = 1;
	localparam STALL_MULT	= 2;
	
	reg[1:0] reason_for_stall = STALL_RPC_TX;
	
	reg rpc_rx_pending = 0;
	
	wire[31:0] execute_mem_addr;
	assign execute_mem_addr = execute_regval_a + execute_immval_sx;
	
	reg[1:0] mult_cycle = 0;

	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		mmu_wr_en <= 0;
		dside_rd_en <= 0;
		dside_wr_en <= 0;
		
		//needs to be done outside freeze/stall check so we get single pulses for debug
		trace_flag <= 0;
		
		//needs to be done outside freeze/stall check so we can deassert immediately while cache flushes
		cache_flush_en <= 0;
		
		//For now, we cannot receive RPC messages when frozen. This is to allow debug messages to unfreeze us
		//without showing up in the input queue.
		if(!freeze) begin
		
			if(rpc_fab_rx_en)
				rpc_rx_pending <= 1;
		end
		
		//End stall if necessary
		if(stall_out) begin
			case(reason_for_stall)
				
				STALL_RPC_TX: begin
					if(rpc_fab_tx_done)
						stall_out <= 0;
				end	//end STALL_RPC_TX
				
				STALL_RPC_RX: begin
					if(rpc_fab_rx_en || rpc_rx_pending) begin
						stall_out <= 0;
						rpc_rx_pending <= 0;
					end
				end	//end STALL_RPC_RX
				
				//3-cycle multiply completion
				STALL_MULT: begin
					if(mult_cycle == 0)
						mult_cycle <= 1;
					else if(mult_cycle == 1)
						mult_cycle <= 2;
					else begin
						mdu_hi <= mdu_product_buf[63:32];
						mdu_lo <= mdu_product_buf[31:0];
						stall_out <= 0;
					end
				end	//end STALL_MULT

				default: begin
				end
				
			endcase
		end
	
		if(freeze) begin
			//turn off outputs in freeze mode to ensure full freeze
			mem_regwrite <= 0;
		end
		
		else begin
				
			if(stall_out) begin				
			end
		
			else if(!stall_in) begin
			
				//Default values for outputs
				mem_regval <= 0;
				mem_regwrite <= 0;
				mem_regid_d <= 0;
				cp0_wr_en <= 0;
				
				mem_read_size <= 0;
				
				//Default register ID unless otherwise specified
				mem_regid_d <= execute_regid_d;
			
				//If bubbling, do nothing
				if(execute_bubble) begin
				end
				
				//R-type instructions switch on func
				else if(execute_rtype) begin
					case(execute_func)
					
						FUNC_ADD: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a + execute_regval_b;
						end	//end FUNC_ADD
					
						FUNC_ADDU: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a + execute_regval_b;
						end	//end FUNC_ADDU
						
						FUNC_AND: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a & execute_regval_b;
						end	//end FUNC_AND
						
						FUNC_BREAK: begin
							
							//Generated by gcc after a divide for div-by-zero checks
							//Ignore for now
							
						end	//end FUNC_BREAK
						
						FUNC_DIV: begin
							mdu_hi <= execute_regval_a;			//Save inputs
							mdu_lo <= execute_regval_b;
							
							mem_regwrite <= 1;
							mem_regval <= execute_pc + 32'h4;	//repeat delay slot instruction
																//TODO: bubble it out the first time
							mem_regid_d <= k0;					//link to $k0 to avoid clobbering $ra
						end	//end FUNC_DIV
						
						FUNC_DIVU: begin
							mdu_hi <= execute_regval_a;			//Save inputs
							mdu_lo <= execute_regval_b;
							
							mem_regwrite <= 1;
							mem_regval <= execute_pc + 32'h4;	//repeat delay slot instruction
																//TODO: bubble it out the first time
							mem_regid_d <= k0;					//link to $k0 to avoid clobbering $ra
						end	//end FUNC_DIVU
					
						FUNC_JALR: begin
							mem_regwrite <= 1;
							mem_regval <= execute_pc + 32'h8;	//skip delay slot instruction
							mem_regid_d <= ra;
						end	//end OP_JALR
					
						FUNC_JR: begin
							//nothing
						end	//end OP_JR
						
						//Move from hi: rd <= hi
						FUNC_MFHI: begin
							mem_regval <= mdu_hi;
							mem_regwrite <= 1;
						end	//end FUNC_MFHI
						
						//Move from lo: rd <= lo
						FUNC_MFLO: begin
							mem_regval <= mdu_lo;
							mem_regwrite <= 1;
						end	//end FUNC_MFHI
						
						//Move to hi: hi <= rs
						FUNC_MTHI: begin
							mdu_hi <= execute_regval_a;
						end	//end FUNC_MTHI
						
						//Move to lo: lo <= rs
						FUNC_MTLO: begin
							mdu_lo <= execute_regval_a;
						end	//end FUNC_MTLO
						
						FUNC_MULT: begin
							stall_out <= 1;
							reason_for_stall <= STALL_MULT;
							mult_cycle <= 0;
						end	//end FUNC_MULT
						
						FUNC_MULTU: begin
							stall_out <= 1;
							reason_for_stall <= STALL_MULT;
							mult_cycle <= 0;
						end	//end FUNC_MULTU
					
						FUNC_NOR: begin
							mem_regwrite <= 1;
							mem_regval <= ~(execute_regval_a | execute_regval_b);
						end	//end FUNC_OR
					
						FUNC_OR: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a | execute_regval_b;
						end	//end FUNC_OR
						
						FUNC_SLL: begin
							mem_regwrite <= 1;
							mem_regval <= shifter_out;
						end	//end FUNC_SLL
						
						FUNC_SLLV: begin
							mem_regwrite <= 1;
							mem_regval <= shifter_out;
						end	//end FUNC_SLLV
						
						FUNC_SLT: begin
							mem_regwrite <= 1;
							if($signed(execute_regval_a) < $signed(execute_regval_b))
								mem_regval <= 1;
							else
								mem_regval <= 0;
						end	//end FUNC_SLT
						
						FUNC_SLTU: begin
							mem_regwrite <= 1;
							if(execute_regval_a < execute_regval_b)
								mem_regval <= 1;
							else
								mem_regval <= 0;
						end	//end FUNC_SLTU
						
						FUNC_SRA: begin
							mem_regwrite <= 1;
							mem_regval <= shifter_out;
						end	//end FUNC_SRA
						
						FUNC_SRAV: begin
							mem_regwrite <= 1;
							mem_regval <= shifter_out;
						end	//end FUNC_SRAV
						
						FUNC_SRL: begin
							mem_regwrite <= 1;
							mem_regval <= shifter_out;
						end	//end FUNC_SRL
						
						FUNC_SRLV: begin
							mem_regwrite <= 1;
							mem_regval <= shifter_out;
						end	//end FUNC_SRLV
						
						FUNC_SUB: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a - execute_regval_b;
						end	//end FUNC_SUB
					
						FUNC_SUBU: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a - execute_regval_b;
						end	//end FUNC_SUBU
						
						FUNC_SYSCALL: begin
							
							//Look up the syscall number
							case(execute_regval_a[7:0])
								
								//Send the pending RPC message and stall until it's done
								SYS_SEND_RPC: begin
									rpc_fab_tx_en <= 1;
									
									stall_out <= 1;
									reason_for_stall <= STALL_RPC_TX;
								end	//end SYS_SEND_RPC
								
								//Receive an RPC message, stalling if the buffer is empty
								SYS_RECV_RPC: begin
									
									if(rpc_fab_rx_en || rpc_rx_pending) begin
										//Buffer is full, do not stall
									end
									
									else begin
										stall_out <= 1;
										reason_for_stall <= STALL_RPC_RX;
									end
									
								end	//end SYS_RECV_RPC
								
								//Done with the last RPC message
								SYS_RPC_DONE: begin
									rpc_fab_rx_done <= 1;
									rpc_rx_pending <= 0;
								end	//end SYS_RPC_DONE
								
								//MMU setup
								SYS_MMAP: begin
									mmu_wr_en <= 1;
								end	//end SYS_MMAP
								
								//Cache flush
								SYS_CACHE_FLUSH: begin
									cache_flush_en <= 1;
								end	//end SYS_CACHE_FLUSH
								
								//Trace
								SYS_TRACE: begin
									//synthesis translate_off
									$display("[GraftonCPUExecuteStage] Trace flag");
									//synthesis translate_on
									trace_flag <= 1;
								end	//end SYS_TRACE
							
								default: begin
								end
							endcase
							
						end	//end FUNC_SYSCALL
						
						FUNC_XOR: begin
							mem_regwrite <= 1;
							mem_regval <= execute_regval_a ^ execute_regval_b;
						end	//end FUNC_XOR
						
						default: begin
							bad_instruction <= 1;
							bad_instruction_opcode <= OP_RTYPE;
							bad_instruction_func <= execute_func;
							bad_instruction_pc <= execute_pc;
						end
					endcase
				end	//end R-type
				
				//otherwise switch on opcode
				else begin
				
					case(execute_opcode)
					
						//Add immediate: rd = rs + imm
						OP_ADDI: begin
							mem_regval <= execute_regval_a + execute_immval_sx;
							mem_regwrite <= 1;
						end	//end OP_ADDI
					
						//Add immediate unsigned: rd = rs + imm
						OP_ADDIU: begin
							mem_regval <= execute_regval_a + execute_immval_sx;
							mem_regwrite <= 1;
						end	//end OP_ADDIU
						
						//AND immediate: rd = rs & imm
						OP_ANDI: begin
							mem_regval <= execute_regval_a & execute_immval;
							mem_regwrite <= 1;
						end	//end OP_ANDI
						
						//Branch instructions need no action taken here unless we're linking
						//Branch if equal
						OP_BEQ: begin
						end	//end OP_BEQ
						
						//Branch if >0
						OP_BGTZ: begin
						end	//end OP_BGTZ
						
						//Branch if <= 0
						OP_BLEZ: begin
						end	//end OP_BLEZ
						
						//Branch if not equal
						OP_BNE: begin
						end	//end OP_BNE
						
						//Several branch instruction use the same opcode
						OP_BRANCH: begin
							case(execute_branch_op)
								BRANCH_BGEZ: begin
								end
								
								BRANCH_BGEZAL: begin
									mem_regwrite <= execute_jumping;
									mem_regval <= execute_pc + 32'h8;	//skip delay slot instruction
									mem_regid_d <= ra;
								end
								
								BRANCH_BLTZ: begin
								end
								
								BRANCH_BLTZAL: begin
									mem_regwrite <= execute_jumping;
									mem_regval <= execute_pc + 32'h8;	//skip delay slot instruction
									mem_regid_d <= ra;
								end
								
								default: begin
									bad_instruction <= 1;
								end
							endcase
						end	//end OP_BRANCH
						
						OP_COPROC: begin
							
							case(execute_coproc_op)
								
								//Move from coprocessor
								OP_MFC0: begin
									mem_regwrite <= 1;
									mem_regval <= cp0_rd_data;
								end	//end OP_MFC0
								
								//Move to coprocessor
								OP_MTC0: begin
									cp0_wr_en <= 1;
									mem_regwrite <= 0;
									mem_regval <= execute_regval_b;
								end	//end OP_MTC0
								
								default: begin
									bad_instruction <= 1;
								end
							endcase
							
						end	//end OP_COPROC
						
						OP_J: begin
							//no action
						end	//end OP_J
						
						OP_JAL: begin
							mem_regwrite <= 1;
							mem_regval <= execute_pc + 32'h8;	//skip delay slot instruction
							mem_regid_d <= ra;
						end	//end OP_JAL
						
						//Load upper immediate: rd <= {imm, 16'h0}
						OP_LUI: begin
							mem_regval <= {execute_immval, 16'h0};
							mem_regwrite <= 1;
						end	//end OP_LUI
						
						//Load word: rd <= mem[rs + imm]
						OP_LW: begin
							dside_rd_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							mem_read_size <= 2;			//reading full word
							mem_read_lsb <= 0;			//aligned read
							mem_read_sx <= 0;			//not sign extending
							
							//synthesis translate_off
							/*
							$display("[GraftonCPUExecuteStage] Loading memory from address %x, pc %x (%.2f)",
								{execute_mem_addr[31:2], 2'b0}, execute_pc, $time());
							$display("%x %x %x", execute_pc, execute_regval_a, execute_immval_sx);
							*/
							//synthesis translate_on
							
							if(execute_mem_addr[1:0] != 0)						//unaligned loads not supported
								bad_instruction <= 1;
						end	//end OP_LW
						
						//Load half word: rd <= sign_extend(mem[rs + imm][15:0])
						OP_LH: begin
							dside_rd_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							mem_read_size <= 1;						//reading half word
							mem_read_lsb <= execute_mem_addr[1:0];
							mem_read_sx <= 1;						//sign extending
							
							if(execute_mem_addr[0] != 0)			//unaligned loads not supported
								bad_instruction <= 1;
						end	//end OP_LH
						
						//Load half word unsigned: rd <= zero_extend(mem[rs + imm][15:0])
						OP_LHU: begin
							dside_rd_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							mem_read_size <= 1;						//reading half word
							mem_read_lsb <= execute_mem_addr[1:0];
							mem_read_sx <= 0;						//not sign extending
							
							if(execute_mem_addr[0] != 0)			//unaligned loads not supported
								bad_instruction <= 1;
						end	//end OP_LHU
						
						//Load byte: rd <= sign_extend(mem[rs + imm][7:0])
						OP_LB: begin
							dside_rd_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							mem_read_size <= 0;						//reading byte
							mem_read_lsb <= execute_mem_addr[1:0];
							mem_read_sx <= 1;						//sign extending

						end	//end OP_LB
						
						//Load byte unsigned: rd <= zero_extend(mem[rs + imm][7:0])
						OP_LBU: begin
							dside_rd_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							mem_read_size <= 0;						//reading byte
							mem_read_lsb <= execute_mem_addr[1:0];
							mem_read_sx <= 0;						//not sign extending

						end	//end OP_LBU
						
						//OR immediate unsigned: rd = rs | imm
						OP_ORI: begin
							mem_regval <= execute_regval_a | execute_immval;
							mem_regwrite <= 1;
						end	//end OP_ORI
						
						//Store half-word: mem[rs+imm] = rt
						OP_SH: begin
							dside_wr_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							//Repeat data as necessary
							dside_wr_data <= {execute_regval_b[15:0], execute_regval_b[15:0]};
							
							//Check high vs low half
							if(execute_mem_addr[1])
								dside_wr_mask <= 4'b0011;
							else
								dside_wr_mask <= 4'b1100;
							
						end	//end OP_SH
						
						//Store byte: mem[rs+imm] = rt
						OP_SB: begin
							dside_wr_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							
							//Repeat data as necessary
							dside_wr_data <= {execute_regval_b[7:0], execute_regval_b[7:0], execute_regval_b[7:0], execute_regval_b[7:0]};
							
							//Check high vs low half
							case(execute_mem_addr[1:0])
								0:	dside_wr_mask <= 4'b1000;
								1:	dside_wr_mask <= 4'b0100;
								2:	dside_wr_mask <= 4'b0010;
								3:	dside_wr_mask <= 4'b0001;
							endcase
							
						end	//end OP_SB
						
						OP_SLTI: begin
							mem_regwrite <= 1;
							if($signed(execute_regval_a) < $signed(execute_immval_sx))
								mem_regval <= 1;
							else
								mem_regval <= 0;
						end	//end OP_SLTI
						
						OP_SLTIU: begin
							mem_regwrite <= 1;
							if(execute_regval_a < execute_immval_sx)
								mem_regval <= 1;
							else
								mem_regval <= 0;
						end	//end OP_SLTIU
						
						//Store word: mem[rs+imm] = rt
						OP_SW: begin
							dside_wr_en <= 1;
							dside_cpu_addr <= {execute_mem_addr[31:2], 2'b0};	//force address to be aligned
							dside_wr_mask <= 4'b1111;
							dside_wr_data <= execute_regval_b;
														
						end	//end OP_SW
						
						//XOR immediate: rd = rs ^ imm
						OP_XORI: begin
							mem_regval <= execute_regval_a ^ execute_immval;
							mem_regwrite <= 1;
						end	//end OP_XORI
						
						default: begin
							bad_instruction <= 1;
							bad_instruction_opcode <= execute_opcode;
							bad_instruction_func <= 0;
							bad_instruction_pc <= execute_pc;
						end
					endcase
				end	//end I/J type
			end	
		end
	end
	
endmodule
