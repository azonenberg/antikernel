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
	@brief ELF loader for GRAFTON CPU
 */
module GraftonCPUELFLoader(
	clk,
	start,
	rd_addr, rd_en, rd_data,
	mmu_wr_en, mmu_wr_page_id, mmu_wr_phyaddr,
	pc_wr, pc_out
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//Bring high for one cycle to begin boot
	input wire start;
	
	//Memory read port (expects single cycle latency)
	output reg[31:0] rd_addr = 0;
	output reg rd_en = 0;
	input wire[31:0] rd_data;
	
	//We read from the DMA rx buffer; logic to read that is external
	
	//MMU port
	output reg mmu_wr_en = 0;
	output reg[8:0] mmu_wr_page_id = 0;
	output reg[31:0] mmu_wr_phyaddr = 0;
	//TODO: mmu_permissions
	//mmu_wr_nocaddr is implicit (wherever we got loaded from) so don't include
	
	//Output to $pc
	output reg pc_wr = 0;
	output reg[31:0] pc_out = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State definitions
	
	`include "GraftonCPUELFLoader_states_constants.v"
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State variables

	reg[3:0] state = STATE_SETUP_0;
	
	reg[8:0] base = 0;
	reg[8:0] count = 0;
	reg[7:0] phnum = 0;
	
	reg loadable = 0;
	reg[31:0] virtual = 0;
	reg[31:0] disksize = 0;
	reg[31:0] offset = 0;
	reg[31:0] bcount = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Table values for ELF loader
	
	/*
		Microcoded state stuff
		
		9:6	= default next state
		5 	= 1 if read is relative to base
		4	= 1 to do a memory read
		3:0 = offsets from base address
	 */
	reg[9:0] microcode_table[15:0];
	
	initial begin
		microcode_table[STATE_SETUP_0]	<= {STATE_SETUP_0,	1'h0, 1'h0, 4'h0};	//e_ident[0]
		microcode_table[STATE_SETUP_1]	<= {STATE_SETUP_2,	1'h0, 1'h1, 4'h7};	//e_phoff
		microcode_table[STATE_SETUP_2]	<= {STATE_SETUP_3,	1'h0, 1'h1, 4'ha};	//e_phentsize
		microcode_table[STATE_SETUP_3]	<= {STATE_SETUP_4,	1'h0, 1'h1, 4'hb};	//e_phnum
		microcode_table[STATE_SETUP_4]	<= {STATE_SETUP_5,	1'h0, 1'h0, 4'h0};	//no read
		microcode_table[STATE_SETUP_5]	<= {STATE_HEADER_0, 1'h1, 1'h1, 4'h0};	//p_type
		
		microcode_table[STATE_HEADER_0] <= {STATE_HEADER_1,	1'h1, 1'h1, 4'h1};	//p_offset
		microcode_table[STATE_HEADER_1] <= {STATE_HEADER_2,	1'h1, 1'h1, 4'h2};	//p_vaddr
		microcode_table[STATE_HEADER_2] <= {STATE_HEADER_3,	1'h1, 1'h1, 4'h4};	//p_filesz
		microcode_table[STATE_HEADER_3] <= {STATE_HEADER_4,	1'h0, 1'h0, 4'h0};	//no read
		microcode_table[STATE_HEADER_4] <= {STATE_HEADER_6,	1'h0, 1'h1, 4'h6};	//e_entry, skip mmap by default
		microcode_table[STATE_HEADER_5] <= {STATE_HEADER_5,	1'h0, 1'h1, 4'h6};	//e_entry, stay in loop by default
		microcode_table[STATE_HEADER_6] <= {STATE_HEADER_0,	1'h1, 1'h1, 4'h8};	//p_type from next phdr, go to next
		
		microcode_table[STATE_SETUP_6]	<= {STATE_DONE,		1'h0, 1'h0, 4'h0};	//no read
		
		microcode_table[STATE_FAIL]		<= {STATE_FAIL,		1'h0, 1'h0, 4'h0};	//no read
		microcode_table[STATE_DONE]		<= {STATE_DONE,		1'h0, 1'h0, 4'h0};	//no read
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	wire[9:0] microcode_line = microcode_table[state];

	wire[20:0] vaddr_offset;
	assign vaddr_offset = (virtual + bcount) >> 11;

	always @(posedge clk) begin

		mmu_wr_en <= 0;
		rd_en <= 0;
		pc_wr <= 0;
		
		//Default to table-selected values
		if(microcode_line[5])
			rd_addr <= microcode_line[3:0] + base;
		else
			rd_addr <= microcode_line[3:0];
		rd_en <= microcode_line[4];
		state <= microcode_line[9:6];
		
		//Save data
		case(state)
			STATE_SETUP_3:	base <= rd_data[10:2];
			STATE_SETUP_5: 	phnum <= rd_data[23:16];
			STATE_HEADER_1:	loadable <= (rd_data == 1);
			STATE_HEADER_2:	offset <= rd_data;
			STATE_HEADER_3:	virtual <= rd_data;
			STATE_HEADER_4: disksize <= rd_data;
			STATE_SETUP_6: begin
				pc_out <= rd_data;
				pc_wr <= 1;
			end
		endcase
			
		//Debug outputs
		//synthesis translate_off
		case(state)
			STATE_SETUP_0:	$display("Reading ELF headers...");
			STATE_SETUP_3:	$display("    e_phoff = %0d", rd_data);
			STATE_SETUP_4:	$display("    e_phentsize = %0d words", rd_data[15:2]);
			STATE_SETUP_5:	$display("    e_phnum = %0d", rd_data[23:16]);
			STATE_HEADER_4:	begin
				$display("Program header %0d of %0d", count+1, phnum);
				if(loadable) begin
					$display("    Virtual address = 0x%x", virtual);
					if(rd_data == 0)
						$display("    Loadable but empty segment on disk, nothing to map");
					else begin
						$display("    Loadable, need to map");
						$display("    File offset = 0x%x", offset);
						$display("    Size on disk = 0x%x", rd_data);
					end
				end
				else
					$display("    Not loadable");
			end
			STATE_SETUP_6:	$display("Entry point = 0x%x", rd_data);
		endcase
		//synthesis translate_on
		
		//Sanity checking
		case(state)
			STATE_SETUP_2: begin
				if(rd_data != 32'h7f454c46) begin
					//synthesis translate_off
						$display("[GraftonCPUELFLoader] FAIL: ELF magic number is wrong");
					//synthesis translate_on
					state <= STATE_FAIL;
				end
			end
			STATE_SETUP_3: begin
				if((rd_data[31:11] != 0) || (rd_data[1:0])) begin
					//synthesis translate_off
					$display("[GraftonCPUELFLoader] FAIL: e_phoff is too big or not aligned");
					//synthesis translate_on
					state <= STATE_FAIL;
				end
			end
			STATE_SETUP_4: begin
				if(rd_data[15:0] != 32) begin
					//synthesis translate_off
					$display("[GraftonCPUELFLoader] FAIL: e_phentsize isn't valid");
					//synthesis translate_on
					state <= STATE_FAIL;
				end
			end
		endcase

		//Advanced processing and conditionals for a handful of states
		case(state)
		
			STATE_SETUP_0: begin
				if(start) begin
					rd_en <= 1;
					state <= STATE_SETUP_1;
				end
			end

			STATE_HEADER_4: begin
				bcount <= 0;
		
				if(loadable && (rd_data != 0))
					state <= STATE_HEADER_5;

			end	//end STATE_HEADER_4
			
			//Do the mapping
			STATE_HEADER_5: begin
			
				//Map this page
				mmu_wr_en <= 1;
				mmu_wr_page_id <= vaddr_offset[8:0];
				mmu_wr_phyaddr <= offset + bcount;
				
				//Go to the next page
				bcount <= bcount + 2048;
				
				//Last page? Go on to the next section.
				//Pre-emptively read the entry point address in case this was the last one
				if( (bcount + 2048) > disksize) begin
					state <= STATE_HEADER_6;
				end
	
			end	//end STATE_HEADER_5
			
			STATE_HEADER_6: begin
				count <= count + 9'h1;
				base <= base + 9'h8;
				
				//Done with the last section? Time to execute
				if(count+1 == phnum)
					state <= STATE_SETUP_6;				
				
			end	//end STATE_HEADER_6

		endcase
		
	end
	
endmodule
