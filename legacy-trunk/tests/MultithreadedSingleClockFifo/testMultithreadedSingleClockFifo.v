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
	@brief Test vectors for the FIFO
 */
module testMultithreadedSingleClockFifo;

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
	
	reg[4:0]	tid		= 0;
	reg			wr		= 0;
	reg[31:0]	din		= 0;
	reg			rd		= 0;
	wire[31:0]	dout;
	wire		overflow;
	wire		underflow;
	wire		empty;
	wire		full;
	
	MultithreadedSingleClockFifo dut(
		.clk(clk),
		.rd_tid(tid),
		.wr_tid(tid),
		.wr(wr),
		.din(din),
		.rd(rd),
		.dout(dout),
		.overflow(overflow),
		.overflow_r(),
		.underflow(underflow),
		.underflow_r(),
		.empty(empty),
		.full(full),
		.reset(1'b0),
		.peek(1'b0)
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver code
	
	task assert();
		input value;
		begin
			if(!value) begin	
				$display("FAIL: Assertion failed at T=%.f ns", $time());
				//$finish;
			end
		end
	endtask
	
	reg[7:0]	count = 0;	
	
	always @(posedge clk) begin	
		count		<= count + 1;
		
		//Sequential validation
		case(count)
			
			1: begin
				$display("Pushing to thread 2");
				assert(!overflow && !underflow && empty && !full);
			end
			
			2: begin
			
				$display("Pushing to thread 3");
				assert(!overflow && !underflow && empty && !full);
			end
			
			3: begin
				$display("Pushing another word to thread 2");
				assert(!overflow && !underflow && !empty && !full);
			end
			
			4: begin
				$display("Pushing another word to thread 3");
				assert(!overflow && !underflow && !empty && !full);
			end
			
			5: begin
				$display("Popping a word from thread 2");
				assert(!overflow && !underflow && !empty && !full);
			end
			
			6: begin
				$display("Verifying pop");
				assert(dout == 32'hfeedface);
				$display("Popping a word from thread 2");
				assert(!overflow && !underflow && !empty && !full);
			end
			
			7: begin
				$display("Verifying pop");
				assert(dout == 32'hc0def00d);
				assert(!overflow && !underflow && empty && !full);
			end
			
			9: begin
				$display("Attempting underflow");
				assert(!overflow && underflow && empty && !full);
			end
			
		endcase
		
	end
	
	always @(*) begin
	
		tid			<= 0;
		wr			<= 0;
		din			<= 0;
		rd			<= 0;
	
		//Combinatorial test vector generation
		case(count)
		
			1: begin
				tid		<= 2;
				wr		<= 1;
				din		<= 32'hfeedface;
			end
			
			2: begin
				tid		<= 3;
				wr		<= 1;
				din		<= 32'hcdcdcdcd;
			end
			
			3: begin
				tid		<= 2;
				wr		<= 1;
				din		<= 32'hc0def00d;
			end
			
			4: begin
				tid		<= 3;
				wr		<= 1;
				din		<= 32'heeeeeeee;
			end
			
			5: begin
				tid		<= 2;
				rd		<= 1;
			end
			
			6: begin
				tid		<= 2;
				rd		<= 1;
			end
			
			7: begin
			end
			
			8: begin
				tid		<= 2;
				rd		<= 1;
			end
			
			9: begin
				$display("PASS: Test completed without error");
				$finish;
			end
		
		endcase
		
	end

	initial begin
		#3000;
		$display("FAIL: Test timed out");
		$finish;
	end
     
endmodule

