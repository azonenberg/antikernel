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
	@brief Test vectors for the cache.
	
	For now, only I-side is tested since D-side isn't really implemented
 */
module testSaratogaCPUL1Cache;

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
	
	reg[4:0]	ifetch0_tid			= 0;
	reg			ifetch0_iside_rd	= 0;
	reg[31:0]	ifetch0_iside_addr	= 0;
	reg[4:0]	ifetch1_tid			= 0;
	reg[4:0]	decode0_tid			= 0;
	wire[63:0]	decode0_insn;
	wire[1:0]	decode0_iside_hit;
	
	wire		miss_rd;
	wire[4:0]	miss_tid;
	wire[31:0]	miss_addr;
	
	reg			push_wr				= 0;
	reg[4:0]	push_tid			= 0;
	reg[31:0]	push_addr			= 0;
	reg[63:0]	push_data			= 0;
	
	SaratogaCPUL1Cache dut(
		.clk(clk),
		
		.ifetch0_tid(ifetch0_tid),
		.ifetch0_iside_rd(ifetch0_iside_rd),
		.ifetch0_iside_addr(ifetch0_iside_addr),
		.ifetch0_thread_active( (ifetch0_tid == 3) || (ifetch0_tid == 4) ),
		
		.ifetch1_tid(ifetch1_tid),
		.ifetch1_thread_active( (ifetch1_tid == 3) || (ifetch1_tid == 4) ),
		
		.decode0_tid(decode0_tid),
		.decode0_insn(decode0_insn),
		.decode0_iside_hit(decode0_iside_hit),
		
		.exec0_tid(5'h0),
		.exec0_dside_rd(1'b0),
		.exec0_dside_wr(1'b0),
		.exec0_dside_wmask(4'b0),
		.exec0_dside_addr(32'h0),
		.exec0_dside_din(32'h0),
		.exec0_thread_active(1'b0),
		.exec1_tid(5'h0),
		.exec1_thread_active(1'b0),
		.exec2_tid(5'h0),
		.exec2_dside_dout(),
		.exec2_dside_hit(),
		
		.miss_rd(miss_rd),
		.miss_tid(miss_tid),
		.miss_addr(miss_addr),
		.miss_perms(),
		
		.push_wr(push_wr),
		.push_tid(push_tid),
		.push_addr(push_addr),
		.push_data(push_data),
		
		.flush_en(),
		.flush_tid(),
		.flush_addr(),
		.flush_dout(),
		.flush_done(1'b0)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push flags down the pipe
	
	always @(posedge clk) begin
		ifetch1_tid <= ifetch0_tid;
		decode0_tid <= ifetch1_tid;
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Miss handling code
	
	reg			miss_active		= 0;
	reg[1:0]	miss_count		= 0;
	
	//Calculate the address we're reading from
	reg[31:0] pending_addr		= 0;
	always @(*) begin
		pending_addr			<= miss_addr + {miss_count, 3'b00};
	end
	
	//The actual ROM
	function time rom;
		input[31:0] addr;
		
		case(addr)
			
			32'hbfc00000:	rom	= 64'hfeedfacebaadf00d;
			32'hbfc00008:	rom	= 64'hc0dec0decdcdcdcd;
			32'hbfc00010:	rom	= 64'ha3a3a3a3cccccccc;
			32'hbfc00018:	rom	= 64'heeeeeeeedddddddd;
			
			32'hcfc00000:	rom	= 64'h1111111122222222;
			32'hcfc00008:	rom	= 64'h3333333344444444;
			32'hcfc00010:	rom	= 64'h5555555566666666;
			32'hcfc00018:	rom	= 64'h7777777788888888;
		
			32'hdfc00000:	rom	= 64'hcccccccccccccccc;
			32'hdfc00008:	rom	= 64'hcccccccccccccccc;
			32'hdfc00010:	rom	= 64'hcccccccccccccccc;
			32'hdfc00018:	rom	= 64'hcccccccccccccccc;
			
			default:		rom = 64'hffffffffffffffff;
			
		endcase
		
	endfunction
	
	//Respond to incoming misses immediately with 8 words back to back
	//Cache will keep tid/addr on the bus until we do the push so no need to buffer them
	always @(posedge clk) begin
	
		push_addr		<= 0;
		push_wr			<= 0;
		push_tid		<= 0;
		push_data		<= 0;
	
		//Go into miss-handling mode
		if(miss_rd) begin
			miss_active			<= 1;
			miss_count			<= 0;
		end
		
		//If we're processing a miss, go push the next word
		if(miss_active) begin
		
			push_addr			<= pending_addr;
			push_tid			<= miss_tid;
			push_wr				<= 1;
			miss_count			<= miss_count + 2'h1;
			
			if(miss_count == 3)
				miss_active		<= 0;
			
			push_data			<= rom(pending_addr);
			
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver code
	
	task assert();
		input value;
		begin
			if(!value) begin	
				$display("FAIL: Assertion failed at T=%.f ns", $time());
				$finish;
			end
		end
	endtask
	
	reg[31:0]	t3_pc	= 32'hbfc00000;
	reg[31:0]	t4_pc	= 32'hcfc00000;
	
	always @(posedge clk) begin
		
		//Barrel, swap every cycle	
		//Run 8 simulated threads to keep the sim shorter
		ifetch0_tid				<= ifetch0_tid + 5'h1;
		ifetch0_tid[4:3]		<= 0;
		
		ifetch0_iside_rd		<= 0;
		ifetch0_iside_addr		<= 0;
		
		//Fetch from both threads
		if(ifetch0_tid == 2) begin
			ifetch0_iside_rd		<= 1;
			ifetch0_iside_addr		<= t3_pc;
		end
		
		if(ifetch0_tid == 3) begin
			ifetch0_iside_rd		<= 1;
			ifetch0_iside_addr		<= t4_pc;
		end
		
		//Bump the pc's if they hit
		if(decode0_tid == 3) begin
			if(decode0_iside_hit == 2'b10)
				t3_pc	<= t3_pc + 4;
			else if(decode0_iside_hit == 2'b11) begin
				t3_pc	<= t3_pc + 8;
				
				//Cause a collision
				if(t3_pc == 32'hbfc00018)
					t3_pc	<= 32'hdfc00000;
				
			end
		end
		if(decode0_tid == 4) begin
			if(decode0_iside_hit == 2'b10)
				t4_pc	<= t4_pc + 4;
			else if(decode0_iside_hit == 2'b11)
				t4_pc	<= t4_pc + 8;
		end
		
	end
	
	reg[31:0]	ifetch1_pc	= 0;
	reg[31:0]	decode0_pc	= 0;
	
	always @(posedge clk) begin
		ifetch1_pc	<= ifetch0_iside_addr;
		decode0_pc	<= ifetch1_pc;
		
		//Sanity checking
		if(decode0_iside_hit == 2'b11) begin
			assert(decode0_insn == rom(decode0_pc));
			$display("Got good hit for thread %d pc %x", decode0_tid, decode0_pc);
			
			if( (decode0_tid == 4) && (decode0_pc == 32'hcfc00038) ) begin
				$display("PASS: Test completed without error");
				$finish;
			end
		end
		
	end

	initial begin
		#5000;
		$display("FAIL: Test timed out");
		$finish;
	end
     
endmodule

