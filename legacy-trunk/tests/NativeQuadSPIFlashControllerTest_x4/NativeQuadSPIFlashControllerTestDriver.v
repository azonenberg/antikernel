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
	@brief Common code for NativeQuadSPIFlashController unit tests
 */

module NativeQuadSPIFlashControllerTestDriver(
	clk,
	busy, done,
	addr, burst_size,
	read_en, read_data_valid, read_data,
	erase_en,
	write_en, write_rden, write_data,
	max_address
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations

	input wire clk;

	input wire busy;
	input wire done;
	output reg[31:0] addr = 0;
	output reg[9:0] burst_size = 0;
	output reg read_en = 0;
	input wire read_data_valid = 0;
	input wire[31:0] read_data;
	output reg erase_en = 0;
	output reg write_en = 0;
	input wire write_rden;
	output reg[31:0] write_data = 0;
	input wire[31:0] max_address;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver
	
	reg[7:0] state = 0;
	reg[7:0] count = 0;
	reg[31:0] expected_value = 0;
	
	always @(posedge clk) begin
		
		read_en <= 0;
		erase_en <= 0;
		write_en <= 0;
		
		case(state)
			
			//Wait for reset to finish, then issue a read
			0: begin
				if(!busy) begin
					$display("Flash is 0x0%x bytes (%0d MB)", max_address + 1, (max_address + 1) / (1024*1024*8));
					$display("Reading initial data...");
					state <= 1;

					read_en <= 1;
					burst_size <= 4;
					addr <= 0;
					count <= 0;
				end
			end
			
			//Wait for read to finish
			1: begin
				if(read_data_valid) begin
				
					//See what we should be getting
					case(count)
						0: expected_value = 32'hdeadbeef;
						1: expected_value = 32'hbaadc0de;
						2: expected_value = 32'hfeedface;
						3: expected_value = 32'h12345678;
					endcase
				
					//Good data?
					if(read_data == expected_value) begin
						
						
						if(count == (burst_size - 1)) begin
							
							//Last one! Make sure the read is finished or we'll have problems
							if(!done || busy) begin
								$display("    should have finished after four words, but didn't");
								$finish;
							end
						
							count <= 0;
							state <= 2;
							
							$display("    OK");
							
						end
						
						else
							count <= count + 1;
							
					end
					
					else begin
						$display("    got incorrect data %x at index %d (expected %x)", read_data, count, expected_value);
						$finish;
					end
				end
			end
						
			//Erase the first 4KB sector of flash
			2: begin
				$display("Erasing first flash sector...");
				erase_en <= 1;
				state <= 3;
			end
			3: begin
				if(done) begin
					$display("    done");
					state <= 4;
				end
			end
		
			//Read the first 4 values again (should be all FF)
			4: begin
				if(!busy) begin
					$display("Reading initial data again (should be blank now)...");
					state <= 5;

					read_en <= 1;
					burst_size <= 4;
					addr <= 0;
				end
			end
			
			5: begin
				if(read_data_valid) begin
					
					if(read_data == 32'hffffffff) begin	
						
						if(count == (burst_size - 1)) begin
							if(!done || busy) begin
								$display("    should have finished after four words, but didn't");
								$finish;
							end
							count <= 0;
							state <= 6;							
							$display("    OK");
						end
						
						else
							count <= count + 1;
							
					end
					
					else begin
						$display("    got incorrect data %x at index %d (expected %x)", read_data, count, 32'hffffffff);
						$finish;
					end
				end
			end
			
			//Program the first flash page with new data
			6: begin
				$display("Programming first flash page...");
				write_en <= 1;
				burst_size <= 4;
				state <= 7;
				count <= 0;
				addr <= 0;
			end
			
			7: begin
				
				if(write_rden) begin
					case(count)
						0: write_data <= 32'h11223344;
						1: write_data <= 32'h55667788;
						2: write_data <= 32'haabbccdd;
						3: write_data <= 32'h87654321;
					endcase
					count <= count + 1;
				end
				
				if(done) begin
					$display("    done");
					state <= 8;
				end
				
			end
			
			//Read the first 4 values once again
			8: begin
				if(!busy) begin
					$display("Reading freshly programmed data...");
					state <= 9;

					read_en <= 1;
					burst_size <= 4;
					addr <= 0;
					count <= 0;
				end
			end
			
			9: begin
				if(read_data_valid) begin
				
					//See what we should be getting
					case(count)
						0: expected_value = 32'h11223344;
						1: expected_value = 32'h55667788;
						2: expected_value = 32'haabbccdd;
						3: expected_value = 32'h87654321;
					endcase
				
					//Good data?
					if(read_data == expected_value) begin
					
						if(count == (burst_size - 1)) begin
							
							//Last one! Make sure the read is finished or we'll have problems
							if(!done || busy) begin
								$display("    should have finished after four words, but didn't");
								$finish;
							end
						
							count <= 0;
							state <= 10;
							
							$display("    OK");
							
						end
						
						else
							count <= count + 1;
							
					end
					
					else begin
						$display("    got incorrect data %x at index %d (expected %x)", read_data, count, expected_value);
						$finish;
					end
				end
			end
			
			10: begin
				$display("Test suite finished (PASS)");
				$finish;
			end
			
		endcase
		
	end
	
	//Die if test hangs
	initial begin
		#6000000;
		$display("FAIL (timeout)");
		$finish;
	end
	
endmodule
