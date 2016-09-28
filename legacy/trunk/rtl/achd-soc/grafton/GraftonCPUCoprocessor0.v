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
	@brief Coprocessor 0 - debug logic and RPC transceiver interface
 */
module GraftonCPUCoprocessor0(
	clk,
	cp0_rd_en, cp0_rd_data, cp0_wr_en,
	mmu_wr_page_id, mmu_wr_phyaddr, mmu_wr_nocaddr, mmu_wr_permissions,
	debug_mem_active, debug_message, debug_message_pending, debug_dside_rd_en, debug_dside_wr_en, debug_dside_cpu_addr,
	debug_clear_segfault,
	dside_rd_valid, dside_rd_data,
	dma_op_active, dma_op_addr, dma_op_cleared, dma_op_segfaulted,
	freeze, bad_instruction, segfault, badvaddr,
	execute_pc, execute_regid_b, execute_regval_a_fwd, execute_regval_b_fwd,
	mem_regval, mem_regid_d,
	mdu_lo, mdu_hi,
	rpc_fab_rx_en, rpc_fab_rx_dst_addr, rpc_fab_rx_callnum, rpc_fab_rx_type, rpc_fab_rx_src_addr, 
	rpc_fab_rx_d0, rpc_fab_rx_d1, rpc_fab_rx_d2, rpc_fab_rx_done, rpc_fab_rx_en_cpu, rpc_fab_rx_done_cpu,
	rpc_fab_tx_en, rpc_fab_tx_dst_addr, rpc_fab_tx_callnum, rpc_fab_tx_type, rpc_fab_tx_d0, rpc_fab_tx_d1, rpc_fab_tx_d2,
	rpc_fab_tx_done, rpc_fab_tx_en_cpu,
	bootloader_pc_wr, step_en, step_done, execute_instruction_issued,
	imiss_start, imiss_done, dmiss_start, dmiss_done, iside_rd_valid
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	input wire			clk;
	
	input wire			cp0_rd_en;
	output reg[31:0]	cp0_rd_data = 0;
	input wire			cp0_wr_en;
	
	output reg[8:0]		mmu_wr_page_id = 0;
	output reg[31:0]	mmu_wr_phyaddr = 0;
	output reg[15:0]	mmu_wr_nocaddr = 0;
	output reg[2:0]		mmu_wr_permissions = 0;
	
	output reg			debug_mem_active		= 0;
	output reg			debug_message			= 0;
	output reg			debug_message_pending	= 0;
	output reg			debug_dside_rd_en		= 0;
	output reg			debug_dside_wr_en		= 0;
	output reg[31:0]	debug_dside_cpu_addr	= 0;
	output reg			debug_clear_segfault	= 0;
	
	input wire			dside_rd_valid;
	input wire[31:0]	dside_rd_data;
	
	input wire			dma_op_active; 
	input wire[15:0]	dma_op_addr;
	output reg			dma_op_cleared			= 0;
	output reg			dma_op_segfaulted		= 0;
	
	output wire			freeze;
	input wire			bad_instruction;
	input wire			segfault;
	input wire[31:0]	badvaddr;
	
	output reg			step_en = 0;
	input wire			step_done;
	
	input wire[31:0]	execute_pc;
	input wire[4:0]		execute_regid_b;
	input wire[31:0]	execute_regval_a_fwd;
	input wire[31:0]	execute_regval_b_fwd;
	
	input wire[31:0]	mem_regval;
	input wire[4:0]		mem_regid_d;
	
	input wire[31:0]	mdu_lo;
	input wire[31:0]	mdu_hi;
	
	output reg			rpc_fab_tx_en = 0;
	output reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	output reg[7:0]		rpc_fab_tx_callnum	= 0;
	output reg[2:0]		rpc_fab_tx_type		= 0;
	output reg[20:0]	rpc_fab_tx_d0		= 0;
	output reg[31:0]	rpc_fab_tx_d1		= 0;
	output reg[31:0]	rpc_fab_tx_d2		= 0;
	input wire			rpc_fab_tx_done;
	input wire			rpc_fab_tx_en_cpu;
	
	input wire			rpc_fab_rx_en;
	input wire[2:0]		rpc_fab_rx_type;
	input wire[15:0]	rpc_fab_rx_src_addr;
	input wire[15:0]	rpc_fab_rx_dst_addr;
	input wire[7:0]		rpc_fab_rx_callnum;
	input wire[20:0]	rpc_fab_rx_d0;
	input wire[31:0]	rpc_fab_rx_d1;
	input wire[31:0]	rpc_fab_rx_d2;
	output reg			rpc_fab_rx_done		= 0;
	output reg			rpc_fab_rx_en_cpu	= 0;
	input wire			rpc_fab_rx_done_cpu;
	
	//profiling stuff
	input wire			execute_instruction_issued;
	input wire			imiss_start;
	input wire			imiss_done;
	input wire			dmiss_start;
	input wire			dmiss_done;
	input wire			iside_rd_valid;
	
	input wire			bootloader_pc_wr;
	
	parameter			debug_mode				= 0;
	parameter			bootloader_host			= 16'h0000;
	parameter			bootloader_addr			= 32'h00000000;
	
	parameter 			profiling				= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Profiling logic
	
	reg[31:0]			profiling_cycle_count	= 0;
	reg[31:0]			profiling_insn_count	= 0;
	reg[31:0]			profiling_imisstime		= 0;
	reg[31:0]			profiling_dmisstime		= 0;
	reg[31:0]			profiling_ireads		= 0;
	reg[31:0]			profiling_dreads		= 0;
	reg[31:0]			profiling_imisses		= 0;
	reg[31:0]			profiling_dmisses		= 0;
	
	reg					imiss_active	= 0;
	reg					dmiss_active	= 0;
	
	always @(posedge clk) begin
	
		if(imiss_start)
			imiss_active	<= 1;
		if(imiss_done)
			imiss_active	<= 0;
		if(dmiss_start)
			dmiss_active	<= 1;
		if(dmiss_done)
			dmiss_active	<= 0;
	
		//Don't collect stats if disabled at synth time.
		//If freezing, don't touch stats.
		if(profiling) begin
			
			if(!freeze) begin
			
				//Always bump cycle count
				profiling_cycle_count		<= profiling_cycle_count + 32'h1;
				
				//Bump instruction count if we are issuing a new instruction
				if(execute_instruction_issued)
					profiling_insn_count	<= profiling_insn_count + 32'h1;
				
				//Bump miss cycle count if a miss is active
				if(imiss_start || imiss_active)
					profiling_imisstime		<= profiling_imisstime + 32'h1;
				if(dmiss_start || dmiss_active)
					profiling_dmisstime		<= profiling_dmisstime + 32'h1;
				
				//Bump read counts any time one succeeds
				if(iside_rd_valid)
					profiling_ireads		<= profiling_ireads + 32'h1;
				if(dside_rd_valid)
					profiling_dreads		<= profiling_dreads + 32'h1;
					
				//Bump miss counts any time we start fetching a cache line
				if(imiss_start)
					profiling_imisses		<= profiling_imisses + 32'h1;
				if(dmiss_start)
					profiling_dmisses		<= profiling_dmisses + 32'h1;
			
			end
			
		end
		
		//Not profiling, force everything to zero
		else begin
			profiling_cycle_count	<= 0;
			profiling_insn_count	<= 0;
			profiling_imisstime		<= 0;
			profiling_dmisstime		<= 0;
			profiling_ireads		<= 0;
			profiling_dreads		<= 0;
			profiling_imisses		<= 0;
			profiling_dmisses		<= 0;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state logic
	
	`include "RPCv2Router_type_constants.v"					//Pull in autogenerated constant tables
	`include "RPCv2Router_ack_constants.v"
	`include "GraftonCPUCoprocessorRegisters_constants.v"
	`include "GraftonCPURPCDebugOpcodes_constants.v"
	
	reg freeze_ff = 1;
	reg breakpoint_hit = 0; 
	assign freeze = freeze_ff || breakpoint_hit || bad_instruction || segfault;
	
	reg debug_message_done = 0;
		
	localparam DEBUG_STATE_IDLE			= 0;
	localparam DEBUG_STATE_RPC_TXHOLD	= 1;
	localparam DEBUG_STATE_REG_READ		= 2;
	localparam DEBUG_STATE_MEM_READ		= 3;
	localparam DEBUG_STATE_STEP			= 4;
		
	//Current debug state machine
	reg[3:0] debug_state = DEBUG_STATE_IDLE;
		
	//Address of the debug monitor
	reg[15:0] debug_monitor_addr = 0;
		
	reg[5:0] boot_timer = 1;
		
	generate
	
		if(debug_mode) begin

			//Combinatorial detection of debug messages
			always @(*) begin
				debug_message <= 0;
			
				if(rpc_fab_rx_en && (rpc_fab_rx_type == RPC_TYPE_CALL)) begin

					/*
						Enter debug mode if we get a new message and all of the following are true:
							* Type = RPC_TYPE_CALL
							* Opcode = DEBUG_CONNECT
							* Source address is in debug subnet
							* We are currently frozen
					 */
					if(	(rpc_fab_rx_callnum == DEBUG_CONNECT) &&
						(rpc_fab_rx_src_addr[15:14] == 2'b11) &&
						freeze) begin
						
						debug_message <= 1;
						
					end
				
					if(rpc_fab_rx_src_addr == debug_monitor_addr)
						debug_message <= 1;
						
				end
			
			end
			
		end
		
		else begin
			always @(*)
				debug_message <= 0;
		end
		
	endgenerate
	
	reg rpc_fab_tx_busy = 0;
	reg rpc_fab_tx_en_cp0 = 0;
	reg debug_segfault_sent = 0;
	reg[31:0] badvaddr_debug_saved = 0;
	reg debug_breakpoint_sent = 0;
	
	//List of hardware breakpoints (only 2 supported right now)
	reg[31:0] bp_addresses[1:0];
	reg bp_valid[1:0];
	initial begin
		bp_addresses[0] <= 0;
		bp_addresses[1] <= 0;
		bp_valid[0] <= 0;
		bp_valid[1] <= 0;
	end
	
	//Combinatorial checks for breakpoint matches
	generate
		always @(*) begin
			breakpoint_hit <= 0;
			/*
			if(debug_mode) begin
				if(	
						(
							( (execute_pc == bp_addresses[0]) && bp_valid[0] ) ||
							( (execute_pc == bp_addresses[1]) && bp_valid[1] )
						) && !mem_stallout && !debug_breakpoint_sent
					) begin
					breakpoint_hit <= 1;
				end
			end
			*/
		end
	endgenerate
	
	reg breakpoint_hit_ff = 0;
	
	generate
		always @(posedge clk) begin
		
			//Clear debug flags
			debug_dside_rd_en <= 0;
			debug_message_done <= 0;
			debug_clear_segfault <= 0;
			
			if(debug_clear_segfault)
				debug_segfault_sent <= 0;
				
			//Freeze the CPU for the first 64 clocks, then unfreeze
			if(!debug_mode) begin
				/*
				if(boot_timer != 0) begin
					boot_timer <= boot_timer + 6'h1;
					if(boot_timer == 6'h3f)
						freeze_ff <= 0;
				end
				*/
				if(bootloader_pc_wr)
					freeze_ff <= 0;
			end

			//Freeze if a combinatorial freeze comes in
			if(breakpoint_hit_ff || breakpoint_hit || bad_instruction || segfault || step_done) begin
				step_en		<= 0;
				freeze_ff	<= 1;
			end
			if(breakpoint_hit)
				breakpoint_hit_ff <= 1;
				
			//Busy flag
			if(rpc_fab_tx_en)
				rpc_fab_tx_busy <= 1;
			if(rpc_fab_tx_done)
				rpc_fab_tx_busy <= 0;
		
			rpc_fab_tx_en_cp0 <= 0;
		
			if(cp0_wr_en) begin
				case (mem_regid_d)
				
					//RPC stuff
					//TODO: If in debug mode, save this stuff separately
					cp0_rpc_dst_addr:	rpc_fab_tx_dst_addr <= mem_regval[15:0];
					//cp0_rpc_src_addr is read only
					cp0_rpc_callnum: 	rpc_fab_tx_callnum <= mem_regval[7:0];
					cp0_rpc_type: 		rpc_fab_tx_type <= mem_regval[2:0];
					cp0_rpc_d0: 		rpc_fab_tx_d0 <= mem_regval[20:0];
					cp0_rpc_d1: 		rpc_fab_tx_d1 <= mem_regval;
					cp0_rpc_d2: 		rpc_fab_tx_d2 <= mem_regval;
					
					//MMU stuff
					cp0_mmu_page_id:	mmu_wr_page_id <= mem_regval[19:11];
					cp0_mmu_phyaddr:	mmu_wr_phyaddr <= mem_regval;
					cp0_mmu_nocaddr:	mmu_wr_nocaddr <= mem_regval[15:0];
					cp0_mmu_perms:		mmu_wr_permissions <= mem_regval[2:0];
					
					default: begin
					end
					
				endcase
			end
			
			//Debug monitor module
			if(debug_mode) begin
				
				if(debug_message)
					debug_message_pending <= 1;
			
				case(debug_state)
				
					//Ready, wait for events
					DEBUG_STATE_IDLE: begin
					
						//Send interrupt on segfault
						if(segfault && !rpc_fab_tx_busy && !debug_segfault_sent) begin
							
							rpc_fab_tx_dst_addr <= debug_monitor_addr;
							rpc_fab_tx_callnum <= DEBUG_SEGFAULT;
							
							rpc_fab_tx_d0 <= 0;
							rpc_fab_tx_d1 <= 0;
							rpc_fab_tx_d2 <= 0;
							
							rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
							
							rpc_fab_tx_en_cp0 <= 1;
							debug_segfault_sent <= 1;
							
							debug_state <= DEBUG_STATE_RPC_TXHOLD;
							
							badvaddr_debug_saved <= badvaddr;
							
						end
						
						//Send interrupt on breakpoint
						else if(breakpoint_hit_ff && !debug_breakpoint_sent && !rpc_fab_tx_busy) begin
							
							rpc_fab_tx_dst_addr <= debug_monitor_addr;
							rpc_fab_tx_callnum <= DEBUG_BREAKPOINT;
							
							rpc_fab_tx_d0 <= 0;
							rpc_fab_tx_d1 <= 0;
							rpc_fab_tx_d2 <= 0;
							
							rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
							
							rpc_fab_tx_en_cp0 <= 1;
							debug_breakpoint_sent <= 1;
							
							debug_state <= DEBUG_STATE_RPC_TXHOLD;
							
						end
					
						else if(debug_message_pending || debug_message) begin
							
							//Clear flags etc
							debug_message_pending <= 0;				
							debug_monitor_addr <= rpc_fab_rx_src_addr;
						
							//Save default stuff
							rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
							rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
						
							//Debug message arrived! Do something with it
							case(rpc_fab_rx_callnum)
								
								//Connect to debug core? Say "we're alive"
								DEBUG_CONNECT: begin
									
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 32'hdeadbeef;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
									
								end	//end DEBUG_CONNECT
								
								//Ask the CPU to halt wherever it is
								DEBUG_HALT: begin
								
									//Freeze everything
									freeze_ff <= 1;
									
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
								
								end	//end DEBUG_HALT
								
								//Get current status in case of a halt
								//and return the program counter and status flags
								DEBUG_GET_STATUS: begin
								
									rpc_fab_tx_d0 <= {18'h0, segfault, bad_instruction, freeze};
									rpc_fab_tx_d1 <= execute_pc;
									rpc_fab_tx_d2 <= badvaddr_debug_saved;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
								
								end	//end DEBUG_GET_STATUS
								
								//Read the current MDU values
								DEBUG_GET_MDU: begin
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= mdu_lo;
									rpc_fab_tx_d2 <= mdu_hi;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
								end	//end DEBUG_GET_MDU
								
								//Read two CPU registers
								DEBUG_READ_REGISTERS: begin
									debug_state <= DEBUG_STATE_REG_READ;
								end	//end DEBUG_READ_REGISTERS
								
								DEBUG_RESUME: begin
								
									freeze_ff <= 0;
									debug_breakpoint_sent <= 0;
									breakpoint_hit_ff <= 0;
								
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
								end	//end DEBUG_RESUME
								
								DEBUG_READ_MEMORY: begin
									
									//Request the read (one word)
									debug_dside_rd_en <= 1;
									debug_mem_active <= 1;
									debug_dside_cpu_addr <= rpc_fab_rx_d1;
									
									debug_state <= DEBUG_STATE_MEM_READ;
									
								end	//end DEBUG_READ_MEMORY
								
								DEBUG_CLEAR_SEGFAULT: begin
									
									debug_clear_segfault <= 1;
									
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
									
								end	//end DEBUG_READ_MEMORY
								
								DEBUG_SET_HWBREAK: begin
									
									//Default to success
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									
									//Try to set the breakpoint
									if(!bp_valid[0]) begin
										bp_addresses[0] <= rpc_fab_rx_d1;
										bp_valid[0] <= 1;
									end
									else if(!bp_valid[1]) begin
										bp_addresses[1] <= rpc_fab_rx_d1;
										bp_valid[1] <= 1;
									end
										
									//No breaks free? Fail
									else
										rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
									
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
									
								end	//end DEBUG_SET_HWBREAK
								
								DEBUG_CLEAR_HWBREAK: begin
								
									//Default to success
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
								
									//Try to clear the breakpoint at each possible location
									if(bp_addresses[0] == rpc_fab_rx_d1) begin
										bp_addresses[0] <= 0;
										bp_valid[0] <= 0;
									end
									if(bp_addresses[1] == rpc_fab_rx_d1) begin
										bp_addresses[1] <= 0;
										bp_valid[1] <= 0;
									end
									
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
								
								end
								
								//Single step (by one instruction)
								DEBUG_SINGLE_STEP: begin
									
									//Return success no matter what
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									
									rpc_fab_tx_d0 	<= 0;
									rpc_fab_tx_d1 	<= 0;
									rpc_fab_tx_d2 	<= 0;
									
									//Unfreeze for one cycle
									step_en			<= 1;
									freeze_ff		<= 0;
									
									debug_state		<= DEBUG_STATE_STEP;
									
								end
									
								//TODO: Other debug calls
								
								//Not implemented? Die
								default: begin
								
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;									
									
								end
								
							endcase
						end	
					end	//end DEBUG_STATE_IDLE
					
					//Wait for transmit to complete
					DEBUG_STATE_RPC_TXHOLD: begin
						if(rpc_fab_tx_done) begin
							debug_message_done <= 1;
							debug_state <= DEBUG_STATE_IDLE;
						end
					end	//end DEBUG_STATE_RPC_TXHOLD
					
					//Read register values
					DEBUG_STATE_REG_READ: begin
						rpc_fab_tx_d0 <= 0;
						rpc_fab_tx_d1 <= execute_regval_a_fwd;	//use forwarding to catch stuff in the pipeline
						rpc_fab_tx_d2 <= execute_regval_b_fwd;
						
						rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_en_cp0 <= 1;
									
									debug_state <= DEBUG_STATE_RPC_TXHOLD;
					end	//end DEBUG_STATE_REG_READ
					
					//Read memory
					DEBUG_STATE_MEM_READ: begin
					
						//Read finished? Great!
						if(dside_rd_valid) begin
							
							debug_mem_active <= 0;
							
							rpc_fab_tx_d0 <= 0;
							rpc_fab_tx_d1 <= dside_rd_data;
							rpc_fab_tx_d2 <= 0;
							
							rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
							rpc_fab_tx_en_cp0 <= 1;
							
							debug_state <= DEBUG_STATE_RPC_TXHOLD;
							
						end
						
						//Bad address? Return failure
						else if(segfault) begin
						
							debug_mem_active <= 0;
							
							debug_clear_segfault <= 1;
							
							rpc_fab_tx_d0 <= 0;
							rpc_fab_tx_d1 <= badvaddr;
							rpc_fab_tx_d2 <= debug_dside_cpu_addr;
							
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_en_cp0 <= 1;
							
							debug_state <= DEBUG_STATE_RPC_TXHOLD;
						
						end
					
					end	//end DEBUG_STATE_MEM_READ
					
					//Wait for single step
					DEBUG_STATE_STEP: begin
						if(step_done) begin
							rpc_fab_tx_en_cp0 <= 1;
							debug_state <= DEBUG_STATE_RPC_TXHOLD;
						end
					end	//end DEBUG_STATE_STEP
					
					//TODO: Other debug stuff
					
				endcase
			end

		end
	endgenerate
	
	//Detect RAM write-complete acknowledgements
	`include "NetworkedDDR2Controller_opcodes_constants.v"
	reg dma_op_cleared_fwd = 0;
	reg dma_op_segfaulted_fwd = 0;
	always @(*) begin
		
		dma_op_cleared_fwd <= 0;
		dma_op_segfaulted_fwd <= 0;
		
		if(dma_op_active) begin
			if(rpc_fab_rx_en && (rpc_fab_rx_type == RPC_TYPE_INTERRUPT) && (dma_op_addr == rpc_fab_rx_src_addr)) begin
			
				if(rpc_fab_rx_callnum == RAM_OP_FAILED)
					dma_op_segfaulted_fwd <= 1;
				else
					dma_op_cleared_fwd <= 1;
			end
		end
	end
	always @(posedge clk) begin
		dma_op_cleared <= dma_op_cleared_fwd;
		dma_op_segfaulted <= dma_op_segfaulted_fwd;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main RPC transceiver logic
	
	//Mark RPC messages as done as soon as they arrive to avoid blocking
	always @(posedge clk) begin
		rpc_fab_rx_done <= 0;
		
		if(rpc_fab_rx_en && !debug_message)
			rpc_fab_rx_done <= 1;
			
		if(debug_message_done)
			rpc_fab_rx_done <= 1;
			
		//TODO: If FIFO is full, block (this should never happen)
	end

	//RPC transmit logic
	always @(*) begin
		
		//Transmit if the CPU wants to
		rpc_fab_tx_en <= rpc_fab_tx_en_cpu;
		
		//Or if the coprocessor does
		if(rpc_fab_tx_en_cp0)
			rpc_fab_tx_en <= 1;
		
	end

	/*
		New receive control path
			Message arrives
			If interrupt from RAM, mark operation as cleared and do not push onto FIFO
			If not, push onto FIFO
			Mark done immediately
			
			If message is ready to read, but head buffer is empty, pop fifo
	 */
	reg rpc_fifo_pop = 0;
	wire[127:0] rpc_fifo_dout;
	wire rpc_fifo_empty;
	SingleClockFifo #(
		.WIDTH(128),
		.DEPTH(256),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) input_fifo (
		.clk(clk),
		.wr(rpc_fab_rx_en && !dma_op_cleared_fwd && !dma_op_segfaulted_fwd && !debug_message),
		.din({
			rpc_fab_rx_src_addr,
			rpc_fab_rx_dst_addr,
			
			rpc_fab_rx_callnum,
			rpc_fab_rx_type,
			rpc_fab_rx_d0,
			
			rpc_fab_rx_d1,
			
			rpc_fab_rx_d2
		}),
		.rd(rpc_fifo_pop),
		.dout(rpc_fifo_dout),
		.overflow(),
		.underflow(),
		.empty(rpc_fifo_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
    );
    		
	//ignore cp0_rd_en for now and just do combinatorial reads all the time
	always @(*) begin
		cp0_rd_data <= 0;
		
		case(execute_regid_b)
			
			cp0_rpc_src_addr:	cp0_rd_data <= rpc_fifo_dout[127:112];
			cp0_rpc_dst_addr:	cp0_rd_data <= rpc_fifo_dout[111:96];
			cp0_rpc_callnum:	cp0_rd_data <= rpc_fifo_dout[95:88];
			cp0_rpc_type:		cp0_rd_data <= rpc_fifo_dout[87:85];
			cp0_rpc_d0:			cp0_rd_data <= rpc_fifo_dout[84:64];
			cp0_rpc_d1:			cp0_rd_data <= rpc_fifo_dout[63:32];
			cp0_rpc_d2:			cp0_rd_data <= rpc_fifo_dout[31:0];
			cp0_boot_rom_addr:	cp0_rd_data <= bootloader_addr;
			cp0_boot_rom_host:	cp0_rd_data <= bootloader_host;
			
			cp0_prof_clocks:	cp0_rd_data	<= profiling_cycle_count;
			cp0_prof_insns:		cp0_rd_data	<= profiling_insn_count;
			cp0_prof_dmisses:	cp0_rd_data	<= profiling_dmisses;
			cp0_prof_dreads:	cp0_rd_data	<= profiling_dreads;
			cp0_prof_imisses:	cp0_rd_data	<= profiling_imisses;
			cp0_prof_ireads:	cp0_rd_data	<= profiling_ireads;
			cp0_prof_dmisstime:	cp0_rd_data	<= profiling_dmisstime;
			cp0_prof_imisstime:	cp0_rd_data	<= profiling_imisstime;
			
			default: begin
			end
			
		endcase
		
	end
	
	//Interface from FIFO to CPU
	reg cpu_is_processing_rpc_message = 0;
	always @(posedge clk) begin
		
		rpc_fifo_pop <= 0;
		
		rpc_fab_rx_en_cpu <= rpc_fifo_pop;
		
		//If CPU is idle and a new message arrives, pop it and tell the CPU
		if(!rpc_fifo_empty && !cpu_is_processing_rpc_message) begin
			cpu_is_processing_rpc_message <= 1;
			rpc_fifo_pop <= 1;
		end
		
		//When the CPU is done, keep track
		if(rpc_fab_rx_done_cpu)
			cpu_is_processing_rpc_message <= 0;
		
	end
	
endmodule
