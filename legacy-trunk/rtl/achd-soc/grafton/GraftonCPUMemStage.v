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
	@brief MEM stage of GRAFTON pipeline
 */
module GraftonCPUMemStage(
	clk,
	stall_out,
	mem_regwrite, mem_regid_d, mem_regval,
	writeback_regwrite, writeback_regid_d, writeback_regval,
	dside_wr_en, dside_wr_done, 
	dside_rd_en, dside_cpu_addr, dside_rd_data, dside_rd_valid,
	mem_read_size, mem_read_sx, mem_read_lsb,
	freeze
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//Stall stuff
	output reg stall_out = 0;
	
	//Inputs from execute stage
	input wire mem_regwrite;
	input wire[4:0] mem_regid_d;
	input wire[31:0] mem_regval;
	input wire[1:0] mem_read_size;
	input wire mem_read_sx;
	input wire[1:0] mem_read_lsb;
	
	//Bus to D-side L1 cache
	input wire dside_wr_en;
	input wire dside_wr_done;
	input wire dside_rd_en;
	input wire[31:0] dside_cpu_addr;
	input wire[31:0] dside_rd_data;
	input wire dside_rd_valid;
	
	//Outputs to writeback stage
	output reg writeback_regwrite = 0;
	output reg[4:0] writeback_regid_d = 0;
	output reg[31:0] writeback_regval = 0;
	
	input wire freeze;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main logic

	reg mem_read_active = 0;
	reg mem_write_active = 0;
	
	reg stall_out_r = 0;
	
	always @(*) begin
		stall_out <= 0;
		
		if(stall_out_r)
			stall_out <= 1;
			
		if(dside_rd_en && !dside_rd_valid)
			stall_out <= 1;
			
		if(dside_wr_en && !dside_wr_done)
			stall_out <= 1;
	end
	
	//Sign extension
	//wire[31:0] execute_immval_sx;
	//assign execute_immval_sx = { {16{execute_immval[15]}}, execute_immval };
	reg[4:0] regid_saved = 0;
	
	always @(posedge clk) begin
		if(freeze) begin
		end
		
		else begin
		
			//Initiate memory read
			if(dside_rd_en) begin
				regid_saved <= mem_regid_d;
				
				//do not clear writeback_regwrite here so forwarding works
				
				mem_read_active <= 1;
				stall_out_r <= 1;
			end
			
			//Initiate memory write
			if(dside_wr_en) begin
				mem_write_active <= 1;
				stall_out_r <= 1;
			end
		
			//Memory read stuff
			if(dside_rd_en || mem_read_active) begin
			
				//Need to repeat the write during a stall so forwarding works
				//Do not clear writeback_regwrite here
				
				//Do the writeback
				if(dside_rd_valid) begin
					stall_out_r <= 0;
					writeback_regwrite <= 1;
					writeback_regid_d <= regid_saved;
					
					//synthesis translate_off
					//$display("[GraftonCPUMemStage] Read value %x (%.2f)", dside_rd_data, $time());
					//synthesis translate_on
					
					case(mem_read_size)
						0: begin
							//byte
							case(mem_read_lsb)
								0: begin
									if(mem_read_sx)
										writeback_regval <= { {24{dside_rd_data[31]}}, dside_rd_data[31:24] };
									else
										writeback_regval <= { 24'h0, dside_rd_data[31:24] };		
								end
								1: begin
									if(mem_read_sx)
										writeback_regval <= { {24{dside_rd_data[23]}}, dside_rd_data[23:16] };
									else
										writeback_regval <= { 24'h0, dside_rd_data[23:16] };
								end
								2: begin
									if(mem_read_sx)
										writeback_regval <= { {24{dside_rd_data[15]}}, dside_rd_data[15:8] };
									else
										writeback_regval <= { 24'h0, dside_rd_data[15:8] };
								end
								3: begin
									if(mem_read_sx)
										writeback_regval <= { {24{dside_rd_data[7]}}, dside_rd_data[7:0] };
									else
										writeback_regval <= { 24'h0, dside_rd_data[7:0] };
								end
							endcase							
						end	//end byte
						
						//halfword
						1: begin
							if(mem_read_lsb[1]) begin
								if(mem_read_sx)
									writeback_regval <= { {16{dside_rd_data[15]}}, dside_rd_data[15:0] };
								else
									writeback_regval <= { 16'h0, dside_rd_data[15:0] };								
							end
							else begin
								if(mem_read_sx)
									writeback_regval <= { {16{dside_rd_data[31]}}, dside_rd_data[31:16] };
								else
									writeback_regval <= { 16'h0, dside_rd_data[31:16] };								
							end
						end	//end halfword
						
						//word
						2: begin
							writeback_regval <= dside_rd_data;
						end	//end word
						
						default: begin
						end
					endcase					
					
					mem_read_active <= 0;
				end

			end
			
			//Memory write stuff
			else if(dside_wr_en || mem_write_active) begin
				
				//Need to repeat the write during a stall so forwarding works
				//Do not clear writeback_regwrite here
				
				if(dside_wr_done) begin
					mem_write_active <= 0;
					stall_out_r <= 0;
				end
			end
			
			//Everything else
			else begin
				stall_out_r <= 0;
			
				writeback_regwrite <= mem_regwrite;
				writeback_regid_d <= mem_regid_d;
				writeback_regval <= mem_regval;
			end
			
		end
	end
	
	
endmodule
