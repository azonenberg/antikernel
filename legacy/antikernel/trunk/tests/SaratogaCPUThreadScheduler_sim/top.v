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
	@brief Test vectors for the thread scheduler
 */
module testSaratogaCPUThreadScheduler_sim;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock oscillator
	
	reg clk = 0;

	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	
	always begin
		#5;
		clk = 0;
		#5;
		clk = ready;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	`include "SaratogaCPUThreadScheduler_opcodes_constants.v";

	reg[2:0]		ctrl_opcode	= THREAD_SCHED_OP_NOP;
	reg[2:0]		ctrl_tid_in	= 0;
	wire[2:0]		ctrl_tid_out;
	wire			ctrl_op_ok;
	wire			ctrl_op_done;
	
	wire[2:0]		ifetch0_tid;
	wire			ifetch0_thread_active;
	wire[2:0]		ifetch1_tid;
	wire			ifetch1_thread_active;
	wire[2:0]		decode0_tid;
	wire			decode0_thread_active;
	wire[2:0]		decode1_tid;
	wire			decode1_thread_active;
	wire[2:0]		exec0_tid;
	wire			exec0_thread_active;
	wire[2:0]		exec1_tid;
	wire			exec1_thread_active;
	wire[2:0]		exec2_tid;
	wire			exec2_thread_active;
	wire[2:0]		exec3_tid;
	wire			exec3_thread_active;

	SaratogaCPUThreadScheduler #(
		.MAX_THREADS(8)
	) sched (
		.clk(clk),
		
		.ifetch0_tid(ifetch0_tid),
		.ifetch0_thread_active(ifetch0_thread_active),
		.ifetch1_tid(ifetch1_tid),
		.ifetch1_thread_active(ifetch1_thread_active),
		.decode0_tid(decode0_tid),
		.decode0_thread_active(decode0_thread_active),
		.decode1_tid(decode1_tid),
		.decode1_thread_active(decode1_thread_active),
		.exec0_tid(exec0_tid),
		.exec0_thread_active(exec0_thread_active),
		.exec1_tid(exec1_tid),
		.exec1_thread_active(exec1_thread_active),
		.exec2_tid(exec2_tid),
		.exec2_thread_active(exec2_thread_active),
		.exec3_tid(exec3_tid),
		.exec3_thread_active(exec3_thread_active),
		
		.ctrl_opcode(ctrl_opcode),
		.ctrl_tid_in(ctrl_tid_in),
		.ctrl_tid_out(ctrl_tid_out),
		.ctrl_op_ok(ctrl_op_ok),
		.ctrl_op_done(ctrl_op_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification code
	
	wire[2:0]	pipeline_tids[7:0];
	wire		pipeline_active[7:0];
	assign pipeline_tids[0] = ifetch0_tid;
	assign pipeline_tids[1] = ifetch1_tid;
	assign pipeline_tids[2] = decode0_tid;
	assign pipeline_tids[3] = decode1_tid;
	assign pipeline_tids[4] = exec0_tid;
	assign pipeline_tids[5] = exec1_tid;
	assign pipeline_tids[6] = exec2_tid;
	assign pipeline_tids[7] = exec3_tid;
	assign pipeline_active[0] = ifetch0_thread_active;
	assign pipeline_active[1] = ifetch1_thread_active;
	assign pipeline_active[2] = decode0_thread_active;
	assign pipeline_active[3] = decode1_thread_active;
	assign pipeline_active[4] = exec0_thread_active;
	assign pipeline_active[5] = exec1_thread_active;
	assign pipeline_active[6] = exec2_thread_active;
	assign pipeline_active[7] = exec3_thread_active;
	
	integer i;
	integer j;
	always @(posedge clk) begin
	
		//Make sure no thread is present and valid in two pipeline stages at once
		for(i=0; i<8; i=i+1) begin
			for(j=i+1; j<8; j=j+1) begin
				if( (pipeline_tids[i] == pipeline_tids[j]) && pipeline_active[i] && pipeline_active[j] ) begin
					$display("FAIL: Thread %d is present in pipeline stages %d and %d simultaneously",
						pipeline_tids[i], i, j);
					$finish;
				end				
			end
		end
		
		//TODO: Verify the threads in the pipeline are currently running
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver code
	
	reg[7:0] count = 0;
	
	always @(posedge clk) begin
	
		count <= count + 1;
		
		ctrl_opcode				<= THREAD_SCHED_OP_NOP;
		ctrl_tid_in				<= 0;
	
		case(count)
		
			//Allocate a new thread ID
			1: begin
				ctrl_opcode		<= THREAD_SCHED_OP_ALLOC;
			end
			
			//Wait for alloc
			
			//Put it onto the run queue
			3: begin
				if(ctrl_op_done) begin
			
					if(!ctrl_op_ok) begin
						$display("FAIL: Allocation didn't succeed");
						$finish;
					end
					
					$display("Successfully allocated new thread %d", ctrl_tid_out);
				
					ctrl_opcode		<= THREAD_SCHED_OP_RUN;
					ctrl_tid_in		<= ctrl_tid_out;
				
				end
			end
			
			//Allocate another TID
			6: begin
				ctrl_opcode		<= THREAD_SCHED_OP_ALLOC;
			end
			
			//Put it onto the run queue
			8: begin
			
				if(ctrl_op_done) begin
			
					if(!ctrl_op_ok) begin
						$display("FAIL: Allocation didn't succeed");
						$finish;
					end
					
					$display("Successfully allocated new thread %d", ctrl_tid_out);
				
					ctrl_opcode		<= THREAD_SCHED_OP_RUN;
					ctrl_tid_in		<= ctrl_tid_out;
					
				end
			end
			
			//Test double-insert and make sure it fails
			11: begin
				ctrl_opcode		<= THREAD_SCHED_OP_RUN;
				ctrl_tid_in		<= 1;
			end
			
			13: begin
				if(ctrl_op_done) begin
					if(ctrl_op_ok) begin
						$display("FAIL: Double-run didn't return error code as it should have");
						$finish;
					end
					else
						$display("Double-run failed as expected");
				end
			end
			
			//Start another few threads
			14: begin
				ctrl_opcode		<= THREAD_SCHED_OP_ALLOC;
			end
			16: begin
				if(ctrl_op_done) begin
					if(!ctrl_op_ok) begin
						$display("FAIL: Allocation didn't succeed");
						$finish;
					end
					
					$display("Successfully allocated new thread %d", ctrl_tid_out);
				
					ctrl_opcode		<= THREAD_SCHED_OP_RUN;
					ctrl_tid_in		<= ctrl_tid_out;
				end
			end
			
			//Remove thread zero from the run queue for a while
			30: begin
				ctrl_opcode		<= THREAD_SCHED_OP_SLEEP;
				ctrl_tid_in		<= 0;
			end
			32: begin
				if(ctrl_op_done && !ctrl_op_ok) begin
					$display("FAIL: Sleep didn't succeed");
					$finish;
				end
			end
			
			//Remove it entirely and push it back onto the free list
			33: begin
				ctrl_opcode		<= THREAD_SCHED_OP_KILL;
				ctrl_tid_in		<= 0;
			end
			35: begin
				if(ctrl_op_done && !ctrl_op_ok) begin
					$display("FAIL: Free didn't succeed");
					$finish;
				end
			end
			
			//Double-free and make sure it fails
			37: begin
				ctrl_opcode		<= THREAD_SCHED_OP_KILL;
				ctrl_tid_in		<= 0;
			end
			39: begin
				if(ctrl_op_done && ctrl_op_ok) begin
					$display("FAIL: Double-free didn't return error");
					$finish;
				end
			end
		
		endcase
		
	end
	
	initial begin
		#1000;
		$display("PASS: Test completed without error");
		$finish;
	end
      
endmodule

