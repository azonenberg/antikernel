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
	@brief ISim simulation test for AdderMacroWithInputXors
 */

module testAdderMacroWithInputXors;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	reg[31:0]	da		= 0;
	reg[31:0]	db		= 0;
	reg[31:0]	ax		= 0;
	reg[31:0]	bx		= 0;
	wire[31:0]	dout;
	
	AdderMacroWithInputXors #(
		.WIDTH(32)
	) dut (
		.a(da),
		.b(db),
		.ax(ax),
		.bx(bx),
		.q(dout)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test logic (unclocked)
	
	task assert_good;
		input[31:0] da;
		input[31:0] db;
		input[31:0] ax;
		input[31:0] bx;
		input[31:0] actual;
		reg[31:0] expected;
		begin
			expected = (da ^ ax) + (db ^ bx);
			if(expected != actual) begin
				$display("FAIL: da=%x, db=%x, ax=%x, bx=%x, expected=%x, actual=%x", da, db, ax, bx, expected, actual);
				$finish;
			end
		end
	endtask
	
	initial begin
	
		#100;
	
		da = 0;
		db = 0;
		ax = 0;
		bx = 0;
		#5;
		assert_good(da, db, ax, bx, dout);
		
		da = 32'h11223344;
		db = 32'h55667788;
		ax = 32'hdeadbeef;
		bx = 32'hbaadc0de;
		#5;
		assert_good(da, db, ax, bx, dout);
		
		da = 32'hfeedface;
		db = 32'h00000000;
		ax = 32'hdeadbeef;
		bx = 32'hbaadc0de;
		#5;
		assert_good(da, db, ax, bx, dout);
		
		da = 32'hfeedface;
		db = 32'h00000000;
		ax = 32'hcdcdcdcd;
		bx = 32'hfeeefeee;
		#5;
		assert_good(da, db, ax, bx, dout);
		
		$display("PASS");
		$finish;
	
	end
	
endmodule

