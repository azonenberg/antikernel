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
	@brief A mutex, with optional timeout
 */
module Mutex(
	clk,
	test_host, test_owned, test_granted,
	lock_en, unlock_en
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire	 		clk;
	
	input wire[15:0]	test_host;				//host wishing to acquire the mutex
	output wire			test_owned;				//returns true if we currently own the mutex
	output wire			test_granted;			//returns true if we got the lock
	
	input wire			lock_en;				//assert to try locking
	input wire			unlock_en;				//assert to try unlocking
	
	//set this to have the mutex auto-unlock after some inactivity
	parameter TIMEOUT_EN	= 1;
	
	//mutex timeout, in clock cycles (must be power of two)
	parameter TIMEOUT_VAL	= 32'h00100000;
	
	//Size of the timeout register
	`include "clog2.vh"
	localparam COUNTER_BITS = clog2(TIMEOUT_VAL);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual mutex
	
	reg[COUNTER_BITS-1:0]	lock_timeout		= 0;
	
	reg			locked		= 0;		//True if mutex is currently locked
	reg[15:0]	lock_host	= 0;		//Address of the host currently holding the mutex
	
	//Return status bits
	assign test_owned		= locked && (lock_host == test_host);
	assign test_granted		= !locked && lock_en;
	
	always @(posedge clk) begin
		
		//Bump timeout on the mutex lock, and clear lock when it hits zero
		if(TIMEOUT_EN) begin
			if(lock_timeout != 0)
				lock_timeout	<= lock_timeout - 1'h1;
			else
				locked			<= 0;
		end
		
		//Lock and unlock when requested
		if(lock_en && test_granted) begin
			locked			<= 1;
			lock_timeout	<= {COUNTER_BITS{1'h1}};
			lock_host		<= test_host;
		end
		
		//We can re-lock at any point and reset the timer
		if(lock_en && test_owned)
			lock_timeout	<= {COUNTER_BITS{1'h1}};
		
		if(unlock_en && test_owned)
			locked			<= 0;
		
	end
	
endmodule
