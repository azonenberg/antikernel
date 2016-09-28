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
	@brief A generic multiport memory macro using the XOR-based technique. All ports use the same clock.
	
	For R read ports and W write ports:
		Area is W*(R+W) = O(W^2 + WR) memory elements
		Critical path delay is a read plus a W:1 xor tree.
	
	May use either block RAM (1 cycle latency minimum, optional second register to improve timing)
	or LUT RAM (combinatorial read, optional register to improve timing)
	
	Note that there is NO FORWARDING in this implementation! This means that there is a delay of OUT_REG cycles after
	a write is issued before the data commits to RAM and can be read. In addition, the result of multiple simultaneous
	writes on different ports to the same address is undefined.
	
	Reference: "Multi-ported memories for FPGAs via XOR" (http://dl.acm.org/citation.cfm?id=2145730)
	
	TODO: cleaner init stuff
 */
module MultiportMemoryMacro(
	clk,
	wr_en, wr_addr, wr_data,
	rd_en, rd_addr, rd_data
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//dimensions of the array
	parameter WIDTH = 1;
	parameter DEPTH = 8;
	
	//number of bits in the address bus
	`include "clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);
	
	//Number of read ports
	parameter NREAD = 1;

	//Number of write ports
	parameter NWRITE = 2;
	
	//set true to use block RAM, false for distributed RAM
	parameter USE_BLOCK = 0;
	
	//set to 0 for no output register, 1 for one cycle latency, 2 for 2-cycle latency
	//note that USE_BLOCK requires OUT_REG to be 1 or 2
	//Read enables are ignored if OUT_REG is not set.
	parameter OUT_REG = 0;
	
	//Initialize to address (takes precedence over INIT_FILE)
	parameter INIT_ADDR = 0;
	
	//Initialization file (set to empty string to fill with zeroes)
	parameter INIT_FILE = "";
	
	//If neither INIT_ADDR nor INIT_FILE is set, set to INIT_VALUE
	parameter INIT_VALUE = {WIDTH{1'h0}};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Single shared clock
	input wire							clk;
	
	//Write ports
	input wire[NWRITE-1 : 0]			wr_en;
	input wire[NWRITE*ADDR_BITS-1 : 0]	wr_addr;
	input wire[NWRITE*WIDTH-1 : 0]		wr_data;
	
	//Read ports
	input wire[NREAD-1 : 0]				rd_en;
	input wire[NREAD*ADDR_BITS-1 : 0]	rd_addr;
	output reg[NREAD*WIDTH-1 : 0]		rd_data = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory array

	/* 
		Basic memory structure is a grid of NWRITE rows x (NWRITE + NREAD) columns. Each cell is a simple dual port RAM.
			Columns 0...NREAD-1 are used for reads
			Columns NREAD...NCOLS-1 are used for writes
		
		To READ address X from read port Y:
			Issue simultaneous reads to address X of column NWRITE + Y
			XOR together all outputs and use this as output
			
		To WRITE data Z to address X from write port Y:
			Issue simultaneous reads to address X of column Y
			XOR together all memory outputs except row Y, XOR with Z
			Write the XOR sum back to address X of row Y
	 */
	
	localparam NCOLS = NWRITE + NREAD;
	
	//All reads go to an entire column
	reg[NCOLS-1 : 0]				col_rd			= 0;
	reg[ADDR_BITS*NCOLS-1 : 0]		col_rd_addr		= 0;
	
	//All writes go to an entire row
	reg[NWRITE-1 : 0]				row_wr			= 0;
	reg[ADDR_BITS*NWRITE-1 : 0]		row_wr_addr		= 0;
	reg[WIDTH*NWRITE-1 : 0]			row_wr_data		= 0;
	
	//Outputs of each cell in the grid
	wire[WIDTH-1 : 0]				cell_dout[NCOLS*NWRITE-1 : 0];

	//The memory
	genvar x;
	genvar y;
	generate
	
		for(x=0; x<NCOLS; x=x+1) begin : colblock
			for(y=0; y<NWRITE; y=y+1) begin : rowblock
		
				//Optimize out the diagonals (not used anyway)
				if( (x >= NREAD) && (y == (x - NREAD)) ) begin
					assign cell_dout[y*NCOLS + x] = 0;
				end
				
				//No, normal memory cell
				else begin
					MemoryMacro #(
						.WIDTH(WIDTH),
						.DEPTH(DEPTH),
						.DUAL_PORT(1),
						.TRUE_DUAL(0),
						.USE_BLOCK(USE_BLOCK),
						.OUT_REG(OUT_REG ? 1 : 0),
						.INIT_ADDR((y == 0) ? INIT_ADDR : 0),	//due to xor, only initialize the first row
						.INIT_FILE((y == 0) ? INIT_FILE : "")	//rest need to stay zero
					) mem (
					
						//Write port
						.porta_clk(clk),
						.porta_en(row_wr[y]),
						.porta_addr(row_wr_addr[y*ADDR_BITS +: ADDR_BITS]),
						.porta_we(row_wr[y]),
						.porta_din(row_wr_data[y*WIDTH +: WIDTH]),
						.porta_dout(),
						
						//Read port
						.portb_clk(clk),
						.portb_en(col_rd[x]),
						.portb_addr(col_rd_addr[x*ADDR_BITS +: ADDR_BITS]),
						.portb_we(1'b0),
						.portb_din({WIDTH{1'b0}}),
						.portb_dout(cell_dout[y*NCOLS + x])
					);
				end
		
			end		
		end
	
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read logic
	
	genvar ncol;
	integer nrow;
	integer nbit;
	
	reg[WIDTH-1 : 0]					col_dout[NCOLS-1 : 0];
	
	reg[NWRITE-1 : 0]					cell_dout_transposed[NCOLS*WIDTH-1 : 0];
	
	generate
	
		//Transpose cell outputs so we can use unary reduction operators
		for(ncol=0; ncol<NCOLS; ncol=ncol+1) begin : transposeblock
			always @(*) begin
				for(nbit=0; nbit<WIDTH; nbit=nbit+1) begin
					for(nrow=0; nrow<NWRITE; nrow=nrow+1) begin
						
						//Omit the diagonals from col_dout_final for write ports.
						if( (ncol >= NREAD) && (nrow == (ncol - NREAD)) )
							cell_dout_transposed[ncol*WIDTH + nbit][nrow] <= 1'b0;
						else
							cell_dout_transposed[ncol*WIDTH + nbit][nrow] <= cell_dout[NCOLS*nrow + ncol][nbit];
						
					end
				end
			end
		end
		
		//Read ports
		for(ncol=0; ncol < NREAD; ncol = ncol + 1) begin : readblock
			always @(*) begin
				col_rd[ncol]								<= rd_en[ncol];
				col_rd_addr[ncol*ADDR_BITS +: ADDR_BITS]	<= rd_addr[ADDR_BITS*ncol +: ADDR_BITS];
			end
		end
		
		//Write ports
		for(ncol=0; ncol < NWRITE; ncol = ncol + 1) begin : writeblock2
			always @(*) begin
				col_rd[ncol + NREAD]									<= wr_en[ncol];
				col_rd_addr[(ncol + NREAD) * ADDR_BITS +: ADDR_BITS]	<= wr_addr[ADDR_BITS*ncol +: ADDR_BITS];
			end
		end
	
		//Combinatorially XOR together all of the column outputs
		for(ncol=0; ncol<NCOLS; ncol=ncol+1) begin : xorblock
			always @(*) begin
				for(nbit=0; nbit<WIDTH; nbit=nbit+1)
					col_dout[ncol][nbit] <= ^cell_dout_transposed[ncol*WIDTH + nbit];
			end
		end
	endgenerate
	
	//The outputs of each column
	//Valid OUT_REG clock cycles after the associated read
	wire[WIDTH-1 : 0]					col_dout_final[NCOLS-1 : 0];
	
	//Register column outputs (only if OUT_REG is 2)
	generate
		
		//If we're doing a second stage of registering, save the xor outputs
		if(OUT_REG == 2) begin
			
			reg[WIDTH-1 : 0]					col_dout_ff[NCOLS-1 : 0];

			for(ncol=0; ncol<NCOLS; ncol=ncol+1) begin : initblock
				initial
					col_dout_ff[ncol] <= 0;
			end
			
			for(ncol=0; ncol<NCOLS; ncol=ncol+1) begin : pipeblock
				always @(posedge clk)
					col_dout_ff[ncol] <= col_dout[ncol];
			end
			
			for(ncol=0; ncol<NCOLS; ncol=ncol+1) begin: assblock1
				assign col_dout_final[ncol] = col_dout_ff[ncol];
			end
			
		end
		
		//Only one or two stages of registers, just pass-through
		else begin
		
			for(ncol=0; ncol<NCOLS; ncol=ncol+1) begin : assblock2
				assign col_dout_final[ncol] = col_dout[ncol];
			end
		
		end
		
		//Copy output of read ports into the top level output
		for(ncol=0; ncol<NREAD; ncol=ncol+1) begin : readouts
			always @(*) begin
				rd_data[ncol*WIDTH +: WIDTH] <= col_dout_final[ncol];
			end
		end
		
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Write logic
	
	//Write port X writes col_dout_final[NREAD + X] ^ data_to_write.
	//This write occurs OUT_REG clock cycles after the initial read was dispatched.
	
	//Register the write addresses and data as necessary
	reg						wr_en_ff1[NWRITE-1 : 0];
	reg						wr_en_ff2[NWRITE-1 : 0];
	reg[ADDR_BITS-1 : 0]	wr_addr_ff1[NWRITE-1 : 0];
	reg[ADDR_BITS-1 : 0]	wr_addr_ff2[NWRITE-1 : 0];
	reg[WIDTH-1 : 0]		wr_data_ff1[NWRITE-1 : 0];
	reg[WIDTH-1 : 0]		wr_data_ff2[NWRITE-1 : 0];
	
	generate
		initial begin
			for(nrow=0; nrow<NWRITE; nrow=nrow+1) begin
				wr_en_ff1[nrow]		<= 0;
				wr_en_ff2[nrow]		<= 0;
				wr_addr_ff1[nrow]	<= 0;
				wr_addr_ff2[nrow]	<= 0;
				wr_data_ff1[nrow]	<= 0;
				wr_data_ff2[nrow]	<= 0;
			end
		end
		
		//Push stuff down the pipeline
		always @(posedge clk) begin
			for(nrow=0; nrow<NWRITE; nrow=nrow+1) begin
				wr_en_ff1[nrow]		<= wr_en[nrow];
				wr_en_ff2[nrow]		<= wr_en_ff1[nrow];
				wr_addr_ff1[nrow]	<= wr_addr[ADDR_BITS*nrow +: ADDR_BITS];
				wr_addr_ff2[nrow]	<= wr_addr_ff1[nrow];
				wr_data_ff1[nrow]	<= wr_data[WIDTH*nrow +: WIDTH];
				wr_data_ff2[nrow]	<= wr_data_ff1[nrow];
			end
		end
	
		//We write to wr_addr, wr_addr_ff1, or wr_addr_ff2 as appropriate
		always @(*) begin
			for(nrow=0; nrow<NWRITE; nrow=nrow+1) begin
				case(OUT_REG)
					
					0: begin
						row_wr[nrow]								<= wr_en[nrow];
						row_wr_addr[nrow*ADDR_BITS +: ADDR_BITS]	<= wr_addr[ADDR_BITS*nrow +: ADDR_BITS];
						row_wr_data[nrow*WIDTH +: WIDTH]			<= col_dout_final[NREAD + nrow] ^
																	   wr_data[WIDTH*nrow +: WIDTH];
					end
					
					1: begin
						row_wr[nrow]								<= wr_en_ff1[nrow];
						row_wr_addr[nrow*ADDR_BITS +: ADDR_BITS]	<= wr_addr_ff1[nrow];
						row_wr_data[nrow*WIDTH +: WIDTH]			<= col_dout_final[NREAD + nrow] ^
																	   wr_data_ff1[nrow];
					end
					
					2: begin
						row_wr[nrow]								<= wr_en_ff2[nrow];
						row_wr_addr[nrow*ADDR_BITS +: ADDR_BITS]	<= wr_addr_ff2[nrow];
						row_wr_data[nrow*WIDTH +: WIDTH]			<= col_dout_final[NREAD + nrow] ^
																	   wr_data_ff2[nrow];
					end
					
					default: begin
						row_wr[nrow]								<= 0;
						row_wr_addr[nrow*ADDR_BITS +: ADDR_BITS]	<= 0;
						row_wr_data[nrow*WIDTH +: WIDTH]			<= 0;
					end
					
				endcase
			end
		end
	endgenerate
	
endmodule
