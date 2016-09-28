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
	@brief Glue logic to connect SARATOGA to the RPC network. Includes the OoB management interface.
 */
module SaratogaCPURPCSubsystem(
	clk,
	
	rpc_fab_tx_en, rpc_fab_tx_src_addr, rpc_fab_tx_dst_addr, rpc_fab_tx_callnum,
	rpc_fab_tx_type, rpc_fab_tx_d0, rpc_fab_tx_d1, rpc_fab_tx_d2, rpc_fab_tx_done,
	
	rpc_fab_inbox_full, rpc_fab_rx_en, rpc_fab_rx_src_addr, rpc_fab_rx_dst_addr, rpc_fab_rx_callnum,
	rpc_fab_rx_type, rpc_fab_rx_d0, rpc_fab_rx_d1, rpc_fab_rx_d2, rpc_fab_rx_done,
	
	bootloader_start_en, bootloader_start_tid, bootloader_start_nocaddr, bootloader_start_phyaddr,
	bootloader_start_done, bootloader_start_ok, bootloader_start_errcode,
	
	sched_ctrl_opcode, sched_ctrl_tid_in, sched_ctrl_tid_out, sched_ctrl_op_ok, sched_ctrl_op_done,
	
	signature_buf_inc, signature_buf_wr, signature_buf_wdata, signature_buf_waddr, signature_buf_tid,
	
	rpc_tx_fifo_rd, rpc_tx_fifo_empty, rpc_tx_fifo_dout, 
	rpc_rx_fifo_rd_en, rpc_rx_fifo_rd_tid, rpc_rx_fifo_rd_valid, rpc_rx_fifo_rd_data_muxed,
	
	decode1_tid, exec0_syscall, exec1_tid, exec1_unit0_en, exec0_syscall_repeat,
	
	mmu_mgmt_wr_en, mmu_mgmt_wr_tid, mmu_mgmt_wr_valid, mmu_mgmt_wr_perms, mmu_mgmt_wr_vaddr,
	mmu_mgmt_wr_nocaddr, mmu_mgmt_wr_phyaddr, mmu_mgmt_wr_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Our address
	parameter NOC_ADDR				= 16'h0;
	
	//Number of thread contexts
	parameter MAX_THREADS			= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS				= clog2(MAX_THREADS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clock
	input wire			clk;
	
	//RPC transmit interface
	output reg				rpc_fab_tx_en			= 0;
	output reg[15:0]		rpc_fab_tx_src_addr		= 0;
	output reg[15:0]		rpc_fab_tx_dst_addr		= 0;
	output reg[7:0]			rpc_fab_tx_callnum		= 0;
	output reg[2:0]			rpc_fab_tx_type			= 0;
	output reg[20:0]		rpc_fab_tx_d0			= 0;
	output reg[31:0]		rpc_fab_tx_d1			= 0;
	output reg[31:0]		rpc_fab_tx_d2			= 0;
	input wire				rpc_fab_tx_done;
	
	//RPC receive interface
	input wire				rpc_fab_inbox_full;
	input wire				rpc_fab_rx_en;
	input wire[15:0]		rpc_fab_rx_src_addr;
	input wire[15:0]		rpc_fab_rx_dst_addr;
	input wire[7:0]			rpc_fab_rx_callnum;
	input wire[2:0]			rpc_fab_rx_type;
	input wire[20:0]		rpc_fab_rx_d0;
	input wire[31:0]		rpc_fab_rx_d1;
	input wire[31:0]		rpc_fab_rx_d2;
	output reg				rpc_fab_rx_done			= 0;
	
	//Bootloader interface
	output reg					bootloader_start_en			= 0;
	output reg[TID_BITS-1:0]	bootloader_start_tid		= 0;
	output reg[15:0]			bootloader_start_nocaddr	= 0;
	output reg[31:0]			bootloader_start_phyaddr	= 0;
	input wire					bootloader_start_done;
	input wire					bootloader_start_ok;
	input wire[7:0]				bootloader_start_errcode;
	
	//Scheduler interface
	output reg[2:0]				sched_ctrl_opcode	= 0;
	output reg[TID_BITS-1 : 0]	sched_ctrl_tid_in	= 0;
	input wire[TID_BITS-1 : 0]	sched_ctrl_tid_out;
	input wire					sched_ctrl_op_ok;
	input wire					sched_ctrl_op_done;
	
	//HMAC interface for remote attestation
	input wire					signature_buf_inc;
	input wire					signature_buf_wr;
	input wire[31:0]			signature_buf_wdata;
	input wire[2:0]				signature_buf_waddr;
	input wire[TID_BITS-1 : 0]	signature_buf_tid;
	
	//RPC transmit FIFO interface
	output reg					rpc_tx_fifo_rd			= 0;
	input wire					rpc_tx_fifo_empty;
	input wire[127:0]			rpc_tx_fifo_dout;
	
	//RPC receive FIFO interface (pulled from execution unit)
	input wire					rpc_rx_fifo_rd_en;
	input wire[TID_BITS-1 : 0]	rpc_rx_fifo_rd_tid;
	output wire					rpc_rx_fifo_rd_valid;
	output reg[63:0]			rpc_rx_fifo_rd_data_muxed	= 0;
	
	//Syscall scheduler interface
	input wire[TID_BITS-1 : 0]	decode1_tid;
	input wire					exec0_syscall;
	output wire					exec0_syscall_repeat;
	input wire[TID_BITS-1 : 0]	exec1_tid;
	input wire					exec1_unit0_en;
	
	//MMU interface
	output reg					mmu_mgmt_wr_en		= 0;
	output reg[TID_BITS-1 : 0]	mmu_mgmt_wr_tid		= 0;
	output reg					mmu_mgmt_wr_valid	= 0;
	output reg[2:0]				mmu_mgmt_wr_perms	= 0;
	output reg[31:0]			mmu_mgmt_wr_vaddr	= 0;
	output reg[15:0]			mmu_mgmt_wr_nocaddr	= 0;
	output reg[31:0]			mmu_mgmt_wr_phyaddr	= 0;
	input wire					mmu_mgmt_wr_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive FIFO
	
	reg 					rpc_rx_fifo_wr_en		= 0;
	reg[TID_BITS-1 : 0]		rpc_rx_fifo_wr_tid		= 0;
	wire					rpc_rx_fifo_wr_overflow;
	
	wire[127:0]				rpc_rx_fifo_rd_data;
	
	SaratogaCPURPCReceiveFifo #(
		.MAX_THREADS(MAX_THREADS),
		.MESSAGES_PER_THREAD(16)
	) rx_fifo (
		.clk(clk),
		
		.wr_en(rpc_rx_fifo_wr_en),
		.wr_tid(rpc_rx_fifo_wr_tid),
		.wr_data({
			rpc_fab_rx_src_addr,
			rpc_fab_rx_dst_addr,
			rpc_fab_rx_callnum,
			rpc_fab_rx_type,
			rpc_fab_rx_d0,
			rpc_fab_rx_d1,
			rpc_fab_rx_d2
		}),
		.wr_overflow(rpc_rx_fifo_wr_overflow),		//TODO: What do we do with this?
		
		.rd_peek(!exec0_syscall_repeat),
		.rd_en(rpc_rx_fifo_rd_en),
		.rd_tid(rpc_rx_fifo_rd_tid),
		.rd_data(rpc_rx_fifo_rd_data),
		.rd_valid(rpc_rx_fifo_rd_valid)
	);
	
	reg[63:0]	exec1_rpc_rx_fifo_rd_data_muxed;
		
	reg		exec1_syscall_repeat = 0;
	always @(posedge clk) begin
		exec1_syscall_repeat				<= exec0_syscall_repeat;
		
		if(exec1_syscall_repeat)
			rpc_rx_fifo_rd_data_muxed		<= rpc_rx_fifo_rd_data[63:0];
		else
			rpc_rx_fifo_rd_data_muxed		<= rpc_rx_fifo_rd_data[127:64];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Scheduler pipeline stage
	
	//Advanced version of scheduler commands, to improve timing
	reg[2:0]			sched_ctrl_opcode_adv	= 0;
	reg[TID_BITS-1 : 0]	sched_ctrl_tid_in_adv	= 0;
	always @(posedge clk) begin
		sched_ctrl_opcode	<= sched_ctrl_opcode_adv;
		sched_ctrl_tid_in	<= sched_ctrl_tid_in_adv;
	end
	
	//Registered versions of scheduler outputs, to improve timing
	reg[TID_BITS-1 : 0]	sched_ctrl_tid_out_ff	= 0;
	reg					sched_ctrl_op_ok_ff		= 0;
	reg					sched_ctrl_op_done_ff	= 0;
	always @(posedge clk) begin
		sched_ctrl_op_done_ff			<= sched_ctrl_op_done;
	
		//Latch when the operation is done
		if(sched_ctrl_op_done) begin
			sched_ctrl_tid_out_ff		<= sched_ctrl_tid_out;
			sched_ctrl_op_ok_ff			<= sched_ctrl_op_ok;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// HMAC buffer for remote attestation
	
	//Remote attestation read ports
	reg					signature_rd_en		= 0;
	reg[TID_BITS-1 : 0]	signature_rd_tid	= 0;
	reg[2:0]			signature_rd_addr	= 0;
	wire[31:0]			signature_rd_data;
	wire[31:0]			signature_rd_seq;
	wire[31:0]			signature_wr_seq;
	
	//Buffer storing HMAC values
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS * 8),	//one HMAC value per thread
		.DUAL_PORT(1),
		.TRUE_DUAL(1),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) hmac_buf (
		.porta_clk(clk),
		.porta_en(signature_buf_wr),
		.porta_addr({signature_buf_tid, signature_buf_waddr}),
		.porta_we(signature_buf_wr),
		.porta_din(signature_buf_wdata),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(signature_rd_en),
		.portb_addr({signature_rd_tid, signature_rd_addr}),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(signature_rd_data)
	);
	
	//Buffer storing sequence numbers
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),	//one sequence value per thread
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) sequence_buf (
		
		.porta_clk(clk),
		.porta_en(signature_buf_inc),
		.porta_addr(signature_buf_tid),
		.porta_we(signature_buf_inc),
		.porta_din(signature_wr_seq + 32'h1),
		.porta_dout(signature_wr_seq),
		
		.portb_clk(clk),
		.portb_en(signature_rd_en),
		.portb_addr(signature_rd_tid),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(signature_rd_seq)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC OoB logic
	
	//Address of the out-of-band management port
	localparam OOB_ADDR = NOC_ADDR;
	
	`include "SaratogaCPUManagementOpcodes_constants.v"
	`include "SaratogaCPUThreadScheduler_opcodes_constants.v"
	`include "RPCv2Router_type_constants.v"
	`include "SaratogaCPUPagePermissions_constants.v"
	`include "SaratogaCPURPCSubsystem_states_constants.v"
	`include "SaratogaCPURPCSubsystem_CreateErrcodes_constants.v"
	
	reg[3:0] oob_state 		= STATE_IDLE;
	reg[3:0] oob_state_next	= STATE_IDLE;
	
	//Transmit stuff for OoB port
	reg			rpc_oob_tx_en			= 0;
	reg[15:0]	rpc_oob_tx_dst_addr		= 0;
	reg[7:0]	rpc_oob_tx_callnum		= 0;
	reg[2:0]	rpc_oob_tx_type			= 0;
	reg[20:0]	rpc_oob_tx_d0			= 0;
	reg[31:0]	rpc_oob_tx_d1			= 0;
	reg[31:0]	rpc_oob_tx_d2			= 0;
	reg			rpc_oob_tx_done			= 0;
	
	reg			mmu_busy	= 0;
	
	reg[TID_BITS-1 : 0]	current_tid		= 0;
	
	//Checks if the incoming RPC is from a local thread context
	reg			packet_from_thread	= 0;
	always @(posedge clk) begin
		packet_from_thread	<=  (rpc_fab_rx_src_addr[15:TID_BITS+1] == NOC_ADDR[15:TID_BITS+1]) &&
								(rpc_fab_rx_src_addr[TID_BITS] == 1'b1);
	end
	
	//Combinatorial state logic
	always @(*) begin
		
		//TODO: OR from both FIFO and OoB state machine
		rpc_fab_rx_done		<= 0;
		
		//Default to not doing anything with the scheduler
		sched_ctrl_opcode_adv		<= THREAD_SCHED_OP_NOP;
		sched_ctrl_tid_in_adv		<= 0;
		
		//Default to staying in same state
		oob_state_next				<= oob_state;
		
		//Default to not pushing onto rx fifo
		rpc_rx_fifo_wr_en			<= 0;
		
		//Thread ID for rx fifo
		rpc_rx_fifo_wr_tid			<= rpc_fab_rx_dst_addr[TID_BITS-1 : 0];
		
		bootloader_start_en			<= 0;
		bootloader_start_tid		<= 0;
		bootloader_start_nocaddr	<= 0;
		bootloader_start_phyaddr	<= 0;
		
		//Do RPC reads
		signature_rd_en				<= 0;
		signature_rd_tid			<= rpc_fab_rx_d0[TID_BITS-1 : 0];
		signature_rd_addr			<= rpc_fab_rx_d0[18:16];
		
		case(oob_state)
		
			//Idle, wait for incoming RPC sent to us
			STATE_IDLE: begin
			
				//Incoming message?
				if(rpc_fab_inbox_full) begin
			
					//Incoming RPC to OoB port
					if(rpc_fab_rx_dst_addr[TID_BITS] == 0) begin
					
						//Do full processing next cycle
						if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
							signature_rd_en	<= 1;
							oob_state_next	<= STATE_CALLIN;
						end
							
						//Nope, drop it				
						else
							rpc_fab_rx_done <= 1;

					end
				
					//Nope, it's a thread context
					//TODO: Snoop to see if it's a memory success/fail interrupt
					else begin
						rpc_fab_rx_done		<= 1;
						rpc_rx_fifo_wr_en	<= 1;
					end
						
				end

			end	//end STATE_IDLE
			
			//Incoming RPC call to the OoB port
			//TODO: Decide on security policy
			STATE_CALLIN: begin
				case(rpc_fab_rx_callnum)
				
					//Create a new process
					OOB_OP_CREATEPROCESS: begin
					
						//Step one: Allocate a new thread context
						sched_ctrl_opcode_adv	<= THREAD_SCHED_OP_ALLOC;
						oob_state_next			<= STATE_CREATE_1;
					
					end	//end OOB_OP_CREATEPROCESS
							
					//Query the number of currently running threads
					OOB_OP_GET_THREADCOUNT: begin
						oob_state_next			<= STATE_RPC_SEND;
					end
					
					//Do a memory mapping
					OOB_OP_MMAP: begin
						
						//Verify the packet is from a local thread
						if(packet_from_thread)
							oob_state_next		<= STATE_MMAP;
						
						//Invalid, send error
						else
							oob_state_next		<= STATE_RPC_SEND;
						
					end
					
					//Remote attestation
					OOB_OP_ATTEST: begin
						oob_state_next		<= STATE_RPC_SEND;
					end

					//Invalid, just send the error
					default: begin
						oob_state_next			<= STATE_RPC_SEND;
					end
					
				endcase
			end	//end STATE_CALLIN
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Memory mapping
			
			STATE_MMAP: begin
				oob_state_next					<= STATE_MMU_WAIT;
			end	//end STATE_MMAP
			
			STATE_MMU_WAIT: begin
				if(mmu_mgmt_wr_done) begin
					oob_state_next				<= STATE_RPC_SEND;
					rpc_fab_rx_done				<= 1;
				end
			end	//end STATE_MMU_WAIT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Process creation
			
			//We just got a thread ID allocated
			STATE_CREATE_1: begin
			
				if(sched_ctrl_op_done_ff) begin
				
					//Allocation failed, abort
					if(!sched_ctrl_op_ok_ff)
						oob_state_next				<= STATE_RPC_SEND;
						
					//Allocation successful, we have a thread context.
					//Send it to the bootloader for processing
					else begin
						bootloader_start_en			<= 1;
						bootloader_start_tid		<= sched_ctrl_tid_out_ff;
						bootloader_start_nocaddr	<= rpc_fab_rx_d1[15:0];
						bootloader_start_phyaddr	<= rpc_fab_rx_d2;
						oob_state_next				<= STATE_CREATE_2;
					end
					
				end
				
			end	//end STATE_CREATE_1
			
			//Wait for bootloader
			STATE_CREATE_2: begin
				
				//Bootloader is done starting the process
				//See if it was successful
				if(bootloader_start_done) begin
				
					//Yep, start the process
					if(bootloader_start_ok) begin
						sched_ctrl_opcode_adv	<= THREAD_SCHED_OP_RUN;
						sched_ctrl_tid_in_adv	<= current_tid;
						oob_state_next			<= STATE_CREATE_3;
					end
					
					//No, delete the thread context
					else begin
						sched_ctrl_opcode_adv	<= THREAD_SCHED_OP_KILL;
						sched_ctrl_tid_in_adv	<= current_tid;
						oob_state_next			<= STATE_RPC_SEND;
					end
				
				end
							
			end	//end STATE_CREATE_2
			
			//Thread created/destroyed, report status
			STATE_CREATE_3: begin
				if(sched_ctrl_op_done_ff)
					oob_state_next					<= STATE_RPC_SEND;
			end	//end STATE_CREATE_3
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Miscellaneous helpers
			
			//Do a transmit
			STATE_RPC_SEND: begin
				oob_state_next					<= STATE_RPC_SWAIT;
			end	//end STATE_RPC_SEND
			
			//Wait for transmit to finish
			STATE_RPC_SWAIT: begin
				if(rpc_oob_tx_done) begin
					rpc_fab_rx_done				<= 1;
					/*if(mmu_busy)
						oob_state_next			<= STATE_MMU_WAIT;
					else*/
						oob_state_next			<= STATE_IDLE;
				end
			end	//end STATE_RPC_SWAIT
		
		endcase
	
	end
	
	always @(posedge clk) begin
		oob_state		<= oob_state_next;
		
		mmu_mgmt_wr_en		<= 0;
		mmu_mgmt_wr_nocaddr	<= 0;
		mmu_mgmt_wr_perms	<= 0;
		mmu_mgmt_wr_phyaddr	<= 0;
		mmu_mgmt_wr_tid		<= 0;
		mmu_mgmt_wr_vaddr	<= 0;
		mmu_mgmt_wr_valid	<= 0;
		
		rpc_oob_tx_en	<= 0;
		
		//Keep track of busy flags
		if(mmu_mgmt_wr_en)
			mmu_busy	<= 1;
		if(mmu_mgmt_wr_done)
			mmu_busy	<= 0;
		
		case(oob_state)
		
			//It's an incoming RPC, set up the transmit data
			STATE_CALLIN: begin
				rpc_oob_tx_dst_addr	<= rpc_fab_rx_src_addr;
				rpc_oob_tx_callnum	<= rpc_fab_rx_callnum;
				rpc_oob_tx_type		<= RPC_TYPE_RETURN_FAIL;
				rpc_oob_tx_d0		<= 0;
				rpc_oob_tx_d1		<= 0;
				rpc_oob_tx_d2		<= 0;
				
				//If it's a query op, return data
				case(rpc_fab_rx_callnum)
				
					OOB_OP_GET_THREADCOUNT: begin
						rpc_oob_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
						rpc_oob_tx_d0		<= MAX_THREADS;
					end
					
					OOB_OP_ATTEST: begin
						rpc_oob_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
						rpc_oob_tx_d0		<= rpc_fab_rx_d0;
						rpc_oob_tx_d1		<= signature_rd_seq;
						rpc_oob_tx_d2		<= signature_rd_data;
					end
					
				endcase
				
			end	//end STATE_CALLIN
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Memory mapping
			
			STATE_MMAP: begin
				mmu_mgmt_wr_en		<= 1;
				mmu_mgmt_wr_nocaddr	<= rpc_fab_rx_d0[15:0];
				mmu_mgmt_wr_perms	<= PAGE_READ_WRITE;
				mmu_mgmt_wr_phyaddr	<= rpc_fab_rx_d1;
				mmu_mgmt_wr_tid		<= rpc_fab_rx_src_addr[TID_BITS-1:0];
				mmu_mgmt_wr_vaddr	<= rpc_fab_rx_d2;
				mmu_mgmt_wr_valid	<= 1;
			end	//end STATE_MMAP_0
			
			STATE_MMU_WAIT: begin
				rpc_oob_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
			end	//end STATE_MMU_WAIT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Process creation
			
			//Tried to allocate a thread. If it failed, abort
			STATE_CREATE_1: begin
				
				if(sched_ctrl_op_done_ff) begin
				
					//Allocation failed, abort
					if(!sched_ctrl_op_ok_ff)
						rpc_oob_tx_d0		<= OOB_CREATE_NO_THREAD_CONTEXTS;
						
					else
						current_tid			<= sched_ctrl_tid_out_ff;
					
				end
				
			end	//end STATE_CREATE_1			
			
			//Wait for bootloader
			STATE_CREATE_2: begin
			
				//Bootloader failed, abort
				if(bootloader_start_done && !bootloader_start_ok) begin
					rpc_oob_tx_d0		<= OOB_CREATE_BOOTLOADER_FAIL;
					rpc_oob_tx_d1		<= bootloader_start_errcode;
				end
			
			end	//end STATE_CREATE_2
			
			//Thread should be on run queue, report status
			STATE_CREATE_3: begin
				
				if(sched_ctrl_op_done_ff) begin
				
					if(!sched_ctrl_op_ok_ff)
						rpc_oob_tx_d0		<= OOB_CREATE_RUN_FAIL;
					
					else begin
						rpc_oob_tx_d0		<= current_tid;
						rpc_oob_tx_d1		<= NOC_ADDR + MAX_THREADS + current_tid;
						rpc_oob_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
					end
					
				end
				
			end	//end STATE_CREATE_3
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Miscellaneous helpers
			
			//Send the packet
			STATE_RPC_SEND: begin	
				rpc_oob_tx_en		<= 1;
			end	//end STATE_RPC_SEND
			
			//When the transmit is done (and the MMU is idle, if we did anything to it), stop
			STATE_RPC_SWAIT: begin
				if(rpc_oob_tx_done)
					rpc_oob_tx_en	<= 0;
			end	//end STATE_RPC_SWAIT

		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transmit logic
	
	//If true, we're processing an OoB request
	reg			rpc_sending_oob			= 0;
	
	//Combinatorial read logic
	reg			rpc_tx_busy = 0;
	
	//Register to improve setup times
	reg[127:0]	rpc_tx_fifo_dout_ff	= 0;
	reg			rpc_tx_fifo_rd_ff	= 0;
	always @(posedge clk) begin
		rpc_tx_fifo_dout_ff	<= rpc_tx_fifo_dout;
		rpc_tx_fifo_rd_ff	<= rpc_tx_fifo_rd;
	end
	
	always @(*) begin
		rpc_tx_fifo_rd		<= 0;
		
		//Doing OoB stuff, forward their stuff instead
		if(rpc_sending_oob) begin
			rpc_fab_tx_src_addr	<= OOB_ADDR;
			rpc_fab_tx_dst_addr	<= rpc_oob_tx_dst_addr;
			rpc_fab_tx_type		<= rpc_oob_tx_type;
			rpc_fab_tx_callnum	<= rpc_oob_tx_callnum;
			rpc_fab_tx_d0		<= rpc_oob_tx_d0;
			rpc_fab_tx_d1		<= rpc_oob_tx_d1;
			rpc_fab_tx_d2		<= rpc_oob_tx_d2;
		end
		
		//Not doing OoB stuff
		else begin
	
			//If not already sending something, but data is available, read it
			//Do not double-pop if we have >1 message in the FIFO!
			if(!rpc_tx_busy && !rpc_tx_fifo_empty && !rpc_oob_tx_en && !rpc_tx_fifo_rd_ff)
				rpc_tx_fifo_rd	<= 1;
		
			//Forward fifo outputs
			rpc_fab_tx_src_addr	<= rpc_tx_fifo_dout_ff[127:112];
			rpc_fab_tx_dst_addr	<= rpc_tx_fifo_dout_ff[111:96];
			rpc_fab_tx_callnum	<= rpc_tx_fifo_dout_ff[95:88];
			rpc_fab_tx_type		<= rpc_tx_fifo_dout_ff[87:85];
			rpc_fab_tx_d0		<= rpc_tx_fifo_dout_ff[84:64];
			rpc_fab_tx_d1		<= rpc_tx_fifo_dout_ff[63:32];
			rpc_fab_tx_d2		<= rpc_tx_fifo_dout_ff[31:0];
		end
		
	end
	
	//Sequential read logic
	always @(posedge clk) begin
		
		rpc_fab_tx_en		<= 0;
		rpc_oob_tx_done		<= 0;
		
		//Process OoB stuff if we need to
		if(rpc_oob_tx_en && !rpc_sending_oob && !rpc_tx_busy) begin
			rpc_sending_oob	<= 1;
			rpc_tx_busy		<= 1;
			rpc_fab_tx_en	<= 1;
		end
		
		//Set/clear busy flag
		if(rpc_tx_fifo_rd_ff) begin
			rpc_tx_busy		<= 1;
			rpc_fab_tx_en	<= 1;
		end
		if(rpc_fab_tx_done) begin
			rpc_tx_busy			<= 0;
			
			if(rpc_sending_oob) begin
				rpc_oob_tx_done		<= 1;
				rpc_sending_oob		<= 0;
			end
		end
			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC read double-pass tracking
	
	/*
		Need to repeat RPC read syscalls as follows
		
		First round
			Attempt to do the read
			Block a bunch of times until it succeeds
			If it succeeds, write "repeat" flag
			
		Second round
			
	 */
	
	reg					exec1_syscall	= 0;
	reg					exec1_rpc_rd	= 0;
	
	always @(posedge clk) begin
		exec1_syscall	<= exec0_syscall;
		exec1_rpc_rd	<= rpc_rx_fifo_rd_en;
	end

	//Store the pass ID
	//We only repeat syscalls for RPC reads!
	MemoryMacro #(
		.WIDTH(1),
		.DEPTH(MAX_THREADS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) pass_id_mem (
		.porta_clk(clk),
		.porta_en(exec1_unit0_en),
		.porta_addr(exec1_tid),
		.porta_we(1'b1),
		.porta_din(rpc_rx_fifo_rd_valid && exec1_rpc_rd && exec1_syscall),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(decode1_tid),
		.portb_we(1'b0),
		.portb_din(1'b0),
		.portb_dout(exec0_syscall_repeat)
	);
	
	/**
		Need a total of 65 bits of memory for each thread context
		
		Store the 64 bits we didn't write, plus whether we're on the first or second pass
	 */

endmodule
