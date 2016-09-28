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
	@brief Thread scheduler for SARATOGA CPU.
	
	CPU core interface:
		{stage}_tid is the thread ID (if any) for that pipeline stage
		{stage}_thread_active is 1 if that pipeline stage currently has an assigned thread context
		
	Controller interface:
		Set ctrl_opcode to the operation being requested.
		If ctrl_op_ok is set the next cycle the operation was a success, else it failed.
		ctrl_op_done is set the same cycle to ease in synchronizing
		
		Note that there is a 2-cycle latency period between when a run/sleep operation is issued and when it
		takes effect. During this period, no new operations may be issued.
		
		THREAD_SCHED_OP_NOP
			Take no action
			
		THREAD_SCHED_OP_ALLOC
			Allocate a new thread context.
			ctrl_tid_out is set to the new thread ID if successful.
			Fails if no thread contexts are available.
			
		THREAD_SCHED_OP_KILL
			Kills the thread identified by ctrl_tid_in.
			Fails if the thread is not active.
			
		THREAD_SCHED_OP_RUN
			Marks the thread identified by ctrl_tid_in as ready and places it on the run queue.
			Fails if the thread is not active, or already on the run queue.
			
		THREAD_SCHED_OP_SLEEP
			Marks the thread identified by ctrl_tid_in as sleeping and removes it from the run queue.
			Fails if the thread is not active, or already sleeping.
 */
module SaratogaCPUThreadScheduler(
	clk,
	
	ifetch0_tid, ifetch0_thread_active,
	ifetch1_tid, ifetch1_thread_active,
	decode0_tid, decode0_thread_active,
	decode1_tid, decode1_thread_active,
	exec0_tid,   exec0_thread_active,
	exec1_tid,   exec1_thread_active,
	exec2_tid,   exec2_thread_active,
	exec3_tid,   exec3_thread_active,
	
	ctrl_opcode, ctrl_tid_in, ctrl_tid_out, ctrl_op_ok, ctrl_op_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS	= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS		= clog2(MAX_THREADS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clock
	input wire					clk;
	
	//Thread ID for each pipeline stage
	output reg[TID_BITS-1 : 0]	ifetch0_tid	= 0;
	output reg[TID_BITS-1 : 0]	ifetch1_tid	= 0;
	output reg[TID_BITS-1 : 0]	decode0_tid	= 0;
	output reg[TID_BITS-1 : 0]	decode1_tid	= 0;
	output reg[TID_BITS-1 : 0]	exec0_tid	= 0;
	output reg[TID_BITS-1 : 0]	exec1_tid	= 0;
	output reg[TID_BITS-1 : 0]	exec2_tid	= 0;
	output reg[TID_BITS-1 : 0]	exec3_tid	= 0;
	
	//Activity status for each pipeline stage
	//This indicates whether there is a thread active.
	//Note that each individual execution unit may or may not be doing anything even if the thread is active.
	output reg					ifetch0_thread_active	= 0;
	output reg					ifetch1_thread_active	= 0;
	output reg					decode0_thread_active	= 0;
	output reg					decode1_thread_active	= 0;
	output reg					exec0_thread_active		= 0;
	output reg					exec1_thread_active		= 0;
	output reg					exec2_thread_active		= 0;
	output reg					exec3_thread_active		= 0;
	
	//Control inputs
	input wire[2:0]				ctrl_opcode;
	input wire[TID_BITS-1 : 0]	ctrl_tid_in;
	output reg[TID_BITS-1 : 0]	ctrl_tid_out			= 0;
	output reg					ctrl_op_ok				= 0;
	output reg					ctrl_op_done			= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push state down the pipeline each cycle
	
	always @(posedge clk) begin
		ifetch1_thread_active		<= ifetch0_thread_active;
		ifetch1_tid					<= ifetch0_tid;
		decode0_thread_active		<= ifetch1_thread_active;
		decode0_tid					<= ifetch1_tid;
		decode1_thread_active		<= decode0_thread_active;
		decode1_tid					<= decode0_tid;
		exec0_thread_active			<= decode1_thread_active;
		exec0_tid					<= decode1_tid;
		exec1_thread_active			<= exec0_thread_active;
		exec1_tid					<= exec0_tid;
		exec2_thread_active			<= exec1_thread_active;
		exec2_tid					<= exec1_tid;
		exec3_thread_active			<= exec2_thread_active;
		exec3_tid					<= exec2_tid;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO of unallocated thread IDs
	
	reg							free_list_wr_en			= 0;
	reg[TID_BITS-1 : 0]			free_list_wr_data		= 0;
	reg							free_list_rd_en			= 0;
	wire[TID_BITS-1 : 0]		free_list_rd_data;
	wire						free_list_empty;
	
	reg[MAX_THREADS-1 : 0]		running_threads			= 0;
	
	SingleClockFifo #(
		.WIDTH(TID_BITS),
		.DEPTH(MAX_THREADS),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(1),
		.INIT_FILE(""),
		.INIT_FULL(1)
	) tid_freelist (
		.clk(clk),
		
		.wr(free_list_wr_en),
		.din(free_list_wr_data),
		
		.rd(free_list_rd_en),
		.dout(free_list_rd_data),
		
		.overflow(),
		.underflow(),
		.empty(free_list_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
    );
   
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Thread pipeline status
	
	reg							thread_entry_en			= 0;
	reg[TID_BITS-1 : 0]			thread_entry_tid		= 0;
	wire						thread_entry_inpipe;
	reg							thread_exit_en			= 0;
	reg[TID_BITS-1 : 0]			thread_exit_tid			= 0;
	 
	SaratogaCPUThreadScheduler_PipelineStatus #(
		.MAX_THREADS(MAX_THREADS)
	) pipeline_status (
		.clk(clk),
		.entry_en(thread_entry_en),
		.entry_tid(thread_entry_tid),
		.entry_inpipe(thread_entry_inpipe),
		.exit_en(thread_exit_en),
		.exit_tid(thread_exit_tid)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The run queue itself
	
	reg							queue_insert_en			= 0;
	reg							queue_delete_en			= 0;
	reg[TID_BITS-1 : 0]			queue_tid_in			= 0;
	wire						queue_err_out;
	
	wire						fetch_valid;
	wire[TID_BITS-1 : 0]		fetch_tid;
	reg							fetch_next				= 0;
	
	SaratogaCPUThreadScheduler_LinkedList #(
		.MAX_THREADS(MAX_THREADS)
	) run_queue (
		.clk(clk),
		
		.insert_en(queue_insert_en),
		.delete_en(queue_delete_en),
		.tid_in(queue_tid_in),
		.err_out(queue_err_out),
		
		.fetch_valid(fetch_valid),
		.fetch_tid(fetch_tid),
		.fetch_next(fetch_next)
	);
	
	//Register inputs to the run queue to improve timing
	reg							queue_insert_en_adv		= 0;
	reg							queue_delete_en_adv		= 0;
	reg[TID_BITS-1 : 0]			queue_tid_in_adv		= 0;
	
	always @(posedge clk) begin
		queue_insert_en		<= queue_insert_en_adv;
		queue_delete_en		<= queue_delete_en_adv;
		queue_tid_in		<= queue_tid_in_adv;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Fetch interface
	
	always @(*) begin
	
		//Look up the current pipeline status
		thread_entry_en			<= fetch_valid;
		thread_entry_tid		<= fetch_tid;
		
		//Fetch the next thread if the current thread wasn't already running
		fetch_next				<= !thread_entry_inpipe;
		
	end
	
	always @(posedge clk) begin
		//Issue a new instruction if the thread is running, but not already in the pipeline
		ifetch0_thread_active	<= fetch_valid && !thread_entry_inpipe;
		ifetch0_tid				<= fetch_tid;
	end
	
	//Let the status module know when a thread leaves the pipeline
	//TODO: Due to instruction fetch latency, can we do this earlier?
	always @(posedge clk) begin
		thread_exit_en			<= exec3_thread_active;
		thread_exit_tid			<= exec3_tid;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Controller interface

	`include "SaratogaCPUThreadScheduler_opcodes_constants.v";
	
	wire input_running = running_threads[ctrl_tid_in];
	
	always @(*) begin

		free_list_rd_en		<= 0;
		free_list_wr_en		<= 0;
		free_list_wr_data	<= 0;
		queue_insert_en_adv	<= 0;
		queue_delete_en_adv	<= 0;
		queue_tid_in_adv	<= 0;
		
		case(ctrl_opcode)
			
			//Allocate the thread context
			THREAD_SCHED_OP_ALLOC: begin
				free_list_rd_en	<= 1;
			end
			
			//Start running it
			THREAD_SCHED_OP_RUN: begin
				queue_insert_en_adv	<= 1;
				queue_tid_in_adv	<= ctrl_tid_in;
			end
			
			//Stop running it (but keep it allocated)
			THREAD_SCHED_OP_SLEEP: begin
				queue_delete_en_adv	<= 1;
				queue_tid_in_adv	<= ctrl_tid_in;
			end
			
			//Free it
			THREAD_SCHED_OP_KILL: begin
				if(input_running) begin
				
					//Push it onto the free list
					free_list_wr_en		<= 1;
					free_list_wr_data	<= ctrl_tid_in;
					
					//Remove it from the run queue if it's currently there
					queue_delete_en_adv		<= 1;
					queue_tid_in_adv		<= ctrl_tid_in;
					
				end
			end
			
		endcase
		
	end
	
	reg[2:0]				ctrl_opcode_ff		= 0;
	reg						input_running_ff	= 0;
	
	always @(posedge clk) begin
	
		ctrl_tid_out		<= 0;
		ctrl_op_ok			<= 0;
		ctrl_op_done		<= 0;
		
		ctrl_opcode_ff		<= ctrl_opcode;
		input_running_ff	<= input_running;
		
		//Clear running flag the first cycle
		if(ctrl_opcode == THREAD_SCHED_OP_KILL)
			running_threads[ctrl_tid_in]	<= 0;
		
		//Allocate a new thread ID (but don't put it on the run queue)
		//Single cycle operation
		if(ctrl_opcode == THREAD_SCHED_OP_ALLOC) begin
			ctrl_tid_out	<= free_list_rd_data;
			ctrl_op_ok		<= !free_list_empty;
			ctrl_op_done	<= 1;
			if(!free_list_empty)
				running_threads[free_list_rd_data]	<= 1;
		end
	
		//Try multi-cycle operations
		else begin
			case(ctrl_opcode_ff)
				
				//Start running a runnable thread
				THREAD_SCHED_OP_RUN: begin
					ctrl_op_ok		<= !queue_err_out;
					ctrl_op_done	<= 1;
				end
				
				//Stop running a currently running thread
				THREAD_SCHED_OP_SLEEP: begin
					ctrl_op_ok		<= !queue_err_out;
					ctrl_op_done	<= 1;
				end
				
				//Free a thread context. If it's in the run queue, it's removed.
				THREAD_SCHED_OP_KILL: begin
					ctrl_op_ok						<= input_running_ff;
					ctrl_op_done					<= 1;
					//ignore queue_err_out as it's legal to kill a sleeping thread
				end
			
			endcase 
		end
		
	end
	
endmodule
