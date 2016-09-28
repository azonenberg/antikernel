`timescale 1ns / 1ps
`default_nettype none
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
	@brief Circular linked list of threads
	
	CPU interface:
		Every clock cycle, if fetch_valid is 0, do nothing.
		If fetch_valid is 1, check pipeline status externally.
		If thread isn't in pipeline, set fetch_next=1 and issue instruction from fetch_tid
		else set fetch_next=0 and stall
		
	Control interface:
		To push a thread onto the run queue:
			assert insert_en with tid_in valid
		To pop a thread off the run queue:
			assert delete_en with tid_in valid				
 */
module SaratogaCPUThreadScheduler_LinkedList(
	clk,
	insert_en, delete_en, tid_in, err_out,
	fetch_valid, fetch_tid, fetch_next
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
	
	input wire clk;
	
	//Run queue manipulation flags
	//All manipulations have two cycles of latency before taking full effect,
	//but return success/fail status immediately.
	//Do not issue any new operations during this latency period.
	input wire					insert_en;
	input wire					delete_en;
	input wire[TID_BITS-1 : 0]	tid_in;
	output reg					err_out				= 0;
	
	//CPU fetch interface
	output reg					fetch_valid			= 0;			//true if fetch_tid is an active, runnable thread
	output reg[TID_BITS-1 : 0]	fetch_tid			= 0;			//ID of the thread to run next
	input wire					fetch_next;							//true if we should advance to the next thread
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register inputs to improve timing
	
	reg						insert_en_ff	= 0;
	reg						insert_en_ff2	= 0;
	reg						delete_en_ff	= 0;
	reg						delete_en_ff2	= 0;
	reg[TID_BITS-1 : 0]		tid_in_ff		= 0;
	reg[TID_BITS-1 : 0]		tid_in_ff2		= 0;
	
	always @(posedge clk) begin
		insert_en_ff		<= insert_en && !err_out;
		delete_en_ff		<= delete_en && !err_out;
		tid_in_ff			<= tid_in;
		insert_en_ff2		<= insert_en_ff;
		delete_en_ff2		<= delete_en_ff;
		tid_in_ff2			<= tid_in_ff;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State storage
	
	reg[MAX_THREADS-1 : 0]		is_active			= 0;			//set to true if the associated thread is
																	//currently running
	
	(* MAX_FANOUT = "reduce" *)												
	reg[TID_BITS-1 : 0]			current_tid			= 0;			//the current thread
	
	wire[TID_BITS-1 : 0]		cpu_next_ptr;
	wire[TID_BITS-1 : 0]		cpu_prev_ptr;
	
	wire[TID_BITS-1 : 0]		ctl_next_ptr;
	wire[TID_BITS-1 : 0]		ctl_prev_ptr;
	
	reg							ctl_rd_en			= 0;
	reg[TID_BITS-1 : 0]			ctl_rd_addr			= 0;				//Read address for pointer memory
	
	reg[1:0]					ctl_wr_en			= 2'b0;
	reg[TID_BITS-1 : 0]			ctl_next0_addr		= 0;
	reg[TID_BITS-1 : 0]			ctl_prev0_addr		= 0;
	reg[TID_BITS-1 : 0]			ctl_next0_wdata		= 0;
	reg[TID_BITS-1 : 0]			ctl_next1_wdata		= 0;
	reg[TID_BITS-1 : 0]			ctl_prev0_wdata		= 0;
	reg[TID_BITS-1 : 0]			ctl_prev1_wdata		= 0;
	
	//Register write data to improve timing
	reg[1:0]					ctl_wr_en_ff		= 2'b0;
	reg[TID_BITS*2 - 1 : 0]		ctl_next_waddr_ff	= 0;
	reg[TID_BITS*2 - 1 : 0]		ctl_next_wdata_ff	= 0;
	reg[TID_BITS*2 - 1 : 0]		ctl_prev_waddr_ff	= 0;
	reg[TID_BITS*2 - 1 : 0]		ctl_prev_wdata_ff	= 0;
	reg[TID_BITS-1 : 0]			ctl_next_ptr_ff		= 0;
	always @(posedge clk) begin
		ctl_wr_en_ff			<= ctl_wr_en;
		ctl_next_waddr_ff		<= {tid_in_ff, ctl_next0_addr};
		ctl_next_wdata_ff		<= {ctl_next1_wdata, ctl_next0_wdata};
		ctl_prev_waddr_ff		<= {tid_in_ff, ctl_prev0_addr};
		ctl_prev_wdata_ff		<= {ctl_prev1_wdata, ctl_prev0_wdata};
		ctl_next_ptr_ff			<= ctl_next_ptr;
	end
	
	//Next-node pointer in the linked list
	MultiportMemoryMacro #(
		.WIDTH(TID_BITS),
		.DEPTH(MAX_THREADS),
		.NREAD(2),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) mem_next_ptr (
		.clk(clk),

		.wr_en(  ctl_wr_en_ff),
		.wr_addr(ctl_next_waddr_ff),
		.wr_data(ctl_next_wdata_ff),
		
		.rd_en(  {1'b1,         ctl_rd_en}),
		.rd_addr({current_tid,  ctl_rd_addr}),
		.rd_data({cpu_next_ptr, ctl_next_ptr})
	);
	
	//Next-node pointer in the linked list
	MultiportMemoryMacro #(
		.WIDTH(TID_BITS),
		.DEPTH(MAX_THREADS),
		.NREAD(2),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) mem_prev_ptr (
		.clk(clk),
		
		.wr_en(  ctl_wr_en_ff),
		.wr_addr(ctl_prev_waddr_ff),
		.wr_data(ctl_prev_wdata_ff),
		
		.rd_en(  {1'b1,         ctl_rd_en}),
		.rd_addr({current_tid,  ctl_rd_addr}),
		.rd_data({cpu_prev_ptr, ctl_prev_ptr})
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main control logic
	
	wire current_is_active		= is_active[current_tid];
	wire input_is_active		= is_active[tid_in];
	
	always @(*) begin
		
		//Fetch port stuff
		//fetch_tid is undefined if thread is not running
		fetch_tid		<= current_tid;
		fetch_valid		<= current_is_active;
		
		//Zero out write stuff by default
		ctl_wr_en		<= 0;

		//Default pointer stuff to deleting
		ctl_next0_addr		<= ctl_prev_ptr;
		ctl_next0_wdata		<= ctl_next_ptr;
		ctl_prev0_addr		<= ctl_next_ptr;
		ctl_prev0_wdata		<= ctl_prev_ptr;
		
		//write next/prev pointers for the new thread
		//ignored unless inserting and current_is_active is true
		ctl_next1_wdata		<= current_tid;
		ctl_prev1_wdata		<= cpu_prev_ptr;
		
		//No error		
		err_out			<= 0;
		
		//Look up the thread as needed
		ctl_rd_addr			<= tid_in_ff;
		ctl_rd_en			<= delete_en;
		
		//Do double-insert/free detection combinatorially as soon as the signal comes in
		if(insert_en && input_is_active)
			err_out 	<= 1;
		else if(delete_en && !input_is_active)
			err_out		<= 1;
		
		//Insert logic
		if(insert_en_ff) begin
		
			//write prev pointer for the current thread
			//ignored unless current_is_active is true
			ctl_prev0_addr		<= current_tid;
			ctl_prev0_wdata		<= tid_in_ff;
			
			//write next pointer for the old thread
			//ignored unless current_is_active is true
			ctl_next0_addr		<= cpu_prev_ptr;
			ctl_next0_wdata		<= tid_in_ff;
			
			//Writing to port 1 regardless
			ctl_wr_en[1]		<= 1;
		
			//If current thread isn't running, the queue must be empty
			//write next/prev pointers for this thread to loop back to itself
			if(!current_is_active) begin
				ctl_next1_wdata		<= tid_in_ff;
				ctl_prev1_wdata		<= tid_in_ff;
			end
			
			//If current thread is running, add it between current and prev
			else
				ctl_wr_en[0] <= 1;

		end
		
		//Delete logic
		else if(delete_en_ff)
			ctl_wr_en[0]		<= 1;
		
	end
	
	always @(posedge clk) begin
	
		//Advance to the next thread if needed
		if(fetch_next) begin
		
			//Deleting the upcoming thread? Jump to its successor instead
			if(delete_en_ff2 && (cpu_next_ptr == tid_in_ff2) )
				current_tid		<= ctl_next_ptr_ff;
			
			//No, just go ahead
			else
				current_tid		<= cpu_next_ptr;

		end
			
		//If we're adding a thread, and the current thread is not running, jump to it immediately
		if(insert_en_ff2 && !current_is_active)
			current_tid		<= tid_in_ff2;
			
		//Update thread status
		//Insert takes precedent if both are asserted simultaneously
		if(insert_en_ff2 || delete_en_ff2)
			is_active[tid_in_ff2]	<= insert_en_ff2;

	end
	
endmodule
