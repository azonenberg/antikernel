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
	@brief Test vectors for the divider core
 */
module testSaratogaCPUDivider;
	
	//Clock generator
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
	
	//Test inputs
	reg			in_start	= 0;
	reg			in_sign		= 0;
	reg[4:0]	in_tid		= 0;
	reg[31:0]	in_dend		= 42;
	reg[31:0]	in_dvsr		= 69;
	
	//Test outputs
	wire		out_done;
	wire[4:0]	out_tid;
	wire[31:0]	out_quot;
	wire[31:0]	out_rem;
	
	//The DUT
	SaratogaCPUDivider #(
		.MAX_THREADS(32)
	) uut (
		.clk(clk),
		
		.in_start(in_start),
		.in_sign(in_sign),
		.in_tid(in_tid),
		.in_dend(in_dend),
		.in_dvsr(in_dvsr),
		
		.out_done(out_done),
		.out_tid(out_tid),
		.out_quot(out_quot),
		.out_rem(out_rem)
	);
	
	//Pseudorandom input generation using a LCG (not very random, but probably adequate)
	//LCG parameters chosen from glibc
	//For now, always unsigned
	always @(posedge clk) begin
		in_dend		<= (1103515245 * in_dend) + 12345;
		in_dend[31]	<= 0;
		
		in_dvsr		<= (1103515245 * in_dvsr) + 12345;
		in_dvsr[31]	<= 0;
	end
	
	//Cycle counter
	reg[15:0] count		= 0;
	always @(posedge clk) begin
		count		<= count + 1;
	end
	reg[4:0] target_tid	= 0;
	always @(*) begin
		target_tid	<= count[4:0];
	end
	
	//Thread status tracking
	reg[31:0] thread_busy = 0;
	always @(posedge clk) begin
		if(in_start)
			thread_busy[in_tid] <= 1;
		
		if(out_done)
			thread_busy[out_tid] <= 0;
			
	end
	
	reg[31:0] expected_quot[31:0];
	reg[31:0] expected_rem[31:0];
	
	//Main test logic	
	always @(posedge clk) begin
		
		count		<= count + 1;
		
		in_start	<= 0;
		in_sign		<= 0;
		in_tid		<= 0;
		
		//Start a new division if the current thread isn't busy
		if(!thread_busy[target_tid]) begin
			in_start	<= 1;
			in_sign		<= 0;
			in_tid		<= target_tid;
		end
		
		if(in_start) begin	
			expected_quot[in_tid]	<= in_dend / in_dvsr;
			expected_rem[in_tid]	<= in_dend % in_dvsr;
		end
		
		//Test the results
		if(out_done) begin
			$display("Done: tid=%d quot=%d rem=%d", out_tid, out_quot, out_rem);
			
			if(expected_quot[out_tid] != out_quot) begin
				$display("FAIL: quotient mismatch (%d, expected %d)", out_quot, expected_quot[out_tid]);
				$finish;
			end
			
			if(expected_rem[out_tid] != out_rem) begin
				$display("FAIL: remient mismatch (%d, expected %d)", out_rem, expected_rem[out_tid]);
				$finish;
			end
			
		end
		
	end
	
	//Timeout logic
	initial begin
		#100000;
		$display("PASS (test ran to completion without error)");
		$finish;
	end
      
endmodule

