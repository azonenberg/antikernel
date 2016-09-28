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
	@brief ISim simulation test for AdderTree
 */

module testAdderTree;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock setup
	
	reg		clk;

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
		
	initial begin
		#25000;
		$display("FAIL: Test timed out");
		$finish;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	reg[255:0]	din			= 0;
	reg			din_valid	= 0;
	reg			din_start	= 0;
	
	wire[31:0]	dout;
	wire		dout_valid;
	
	AdderTree #(
		.DATA_WIDTH(32),
		.SUM_WIDTH(64),
		.SAMPLES_PER_CLOCK(8),
		.TREE_FANIN(4)
	) dut (
		.clk(clk),
		.din(din),
		.din_valid(din_valid),
		.din_start(din_start),
		.dout(dout),
		.dout_valid(dout_valid)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test logic
	
	reg[7:0] state = 0;
	integer i;
	
	always @(posedge clk) begin
	
		din_valid	<= 0;
		din_start	<= 0;
	
		case(state)
			
			//Feed some data in
			0: begin
				$display("Sum 0...63");
				din_valid	<= 1;
				din_start	<= 1;
				din			<= {32'h0, 32'h1, 32'h2, 32'h3, 32'h4, 32'h5, 32'h6, 32'h7};
				state		<= 1;
			end
			
			//Do nothing, verify things work if we have gaps in the data
			1: begin
				state		<= 2;
			end
			
			//Feed in more data
			2: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 3;
			end
			3: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 4;
			end
			4: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 5;
			end
			5: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 6;
			end
			6: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 7;
			end
			7: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 8;
			end
			8: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 9;
			end
			
			//We should have a sum at the end
			//This should be 2016
			9: begin
				if(dout_valid) begin
					$display("Got a sum");
					if(dout == 'd2016)
						$display("Good");
					else begin
						$display("FAIL: Got a bad sum (%d, expected 2080)", dout);
						$finish;
					end
					
					state	<= 10;
				end
			end
			
			//Feed some more in
			10: begin
				$display("Sum 500...563");
				din_valid	<= 1;
				din_start	<= 1;
				din			<= {32'd500, 32'd501, 32'd502, 32'd503, 32'd504, 32'd505, 32'd506, 32'd507};
				state		<= 11;
			end
			
			//Do nothing, verify things work if we have gaps in the data
			11: begin
				state		<= 12;
			end
			
			//Feed in more data
			12: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 13;
			end
			13: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 14;
			end
			14: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 15;
			end
			15: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 16;
			end
			16: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 17;
			end
			17: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 18;
			end
			18: begin
				din			<= din + {32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8, 32'h8};
				din_valid	<= 1;
				state		<= 19;
			end
			
			//We should have a sum at the end
			//This should be 34016
			19: begin
				if(dout_valid) begin
					$display("Got a sum");
					if(dout == 'd34016)
						$display("Good");
					else begin
						$display("FAIL: Got a bad sum (%d, expected 2080)", dout);
						$finish;
					end
					
					state	<= 20;
				end
			end
			
			20: begin
				$display("PASS");
				$finish;
			end
			
		endcase
	
	end
	
endmodule

