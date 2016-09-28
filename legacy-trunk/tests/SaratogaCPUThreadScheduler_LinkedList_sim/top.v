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
module testSaratogaCPUThreadScheduler_LinkedList_sim;

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
	
	reg			insert_en	= 0;
	reg			delete_en	= 0;
	reg[2:0]	tid_in		= 0;
	
	wire		fetch_valid;
	wire[2:0]	fetch_tid;
	reg			fetch_next	= 0;
	
	SaratogaCPUThreadScheduler_LinkedList #(
		.MAX_THREADS(8)
	) dut(
		.clk(clk),
		.insert_en(insert_en),
		.delete_en(delete_en),
		.tid_in(tid_in),
		.fetch_valid(fetch_valid),
		.fetch_tid(fetch_tid),
		.fetch_next(fetch_next),
		.err_out()
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification code
	
	reg[7:0] expected_thread_status		= 0;
	reg[7:0] expected_thread_status_buf	= 0;
	reg[7:0] expected_thread_status_buf2	= 0;
	
	always @(posedge clk) begin
		if(insert_en)
			expected_thread_status[tid_in] <= 1;
		if(delete_en)
			expected_thread_status[tid_in] <= 0;
			
		//Register thread status to model delayed write latency
		expected_thread_status_buf	<= expected_thread_status;
		expected_thread_status_buf2	<= expected_thread_status_buf;
			
		//Sanity check
		if(expected_thread_status_buf2[fetch_tid] != fetch_valid) begin
			$display("FAIL: Mismatch of thread status");
			$finish;
		end
		
		//TODO: verify threads are sequencing properly
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver code
	
	reg[7:0] count = 0;
	
	always @(posedge clk) begin
	
		insert_en		<= 0;
		delete_en		<= 0;
		tid_in			<= 0;
		fetch_next		<= 1;
		
		count			<= count + 8'h1;
	
		case(count)
			
			//Do nothing at first
			0: begin
			end
			
			//Start running a thread
			1: begin
				insert_en	<= 1;
				tid_in		<= 5;
			end
				
			//Start another thread
			4: begin
				insert_en	<= 1;
				tid_in		<= 4;
			end
			
			//Start another thread
			7: begin
				insert_en	<= 1;
				tid_in		<= 2;
			end
			
			//Kill the first one
			14: begin
				delete_en	<= 1;
				tid_in		<= 5;
			end
			
			//Kill another thread right after
			17: begin
				delete_en	<= 1;
				tid_in		<= 2;
			end
			
			//Then kill the last one
			20: begin
				delete_en	<= 1;
				tid_in		<= 4;
			end
			
			//and start some new threads (re-use old TIDs)
			24: begin
				insert_en	<= 1;
				tid_in		<= 7;
			end
			27: begin
				insert_en	<= 1;
				tid_in		<= 2;
			end
			30: begin
				insert_en	<= 1;
				tid_in		<= 5;
			end
			
			//Wait a while and kill one of them
			35: begin
				delete_en	<= 1;
				tid_in		<= 7;
			end
			
		endcase
	end
	
	initial begin
		#500;
		$display("PASS: Test completed without error");
		$finish;
	end
      
endmodule

