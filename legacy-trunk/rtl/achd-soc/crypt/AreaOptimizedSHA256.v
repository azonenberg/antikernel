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
	@brief Area-optimized SHA-256, slow but small.
	
	Operation:
		Assert reset for one cycle
		Divide message into blocks of 16 32-bit words
			Assert we with data on din to write a word to the buffer
			Write next 16 words (or less for last block)
			Assert blockend for one cycle. Last block should assert finish too.
			Wait for blockdone to go high (one cycle) before writing the next block
		Wait for done to go high(one cycle). dout will contain the hash over the next 8 cycles.
 */
module AreaOptimizedSHA256(
	clk,
	reset, resetdone, we, din, blockend, finish,
	blockdone, done, dout
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire clk;
	
	input wire reset;
	input wire we;
	input wire[31:0] din;
	input wire blockend;
	input wire finish;
	
	output reg resetdone = 0;
	output reg blockdone = 0;
	output reg done = 0;
	output reg[31:0] dout = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Shift registers for message expansion
	
	reg[5:0] wbuf_wr_addr = 0;
	reg wbuf_wr_en = 0;
	reg[31:0] wbuf_wdata = 0;
	
	//Use SRLs for these to save registers
	wire[31:0] wbuf_m14;
	ShiftRegisterMacro #(
		.WIDTH(32),
		.DEPTH(32)
	) wbuf_m14_shreg (
		.clk(clk),
		.addr(5'd13),
		.din(wbuf_wdata),
		.ce(wbuf_wr_en),
		.dout(wbuf_m14)
	);
	
	wire[31:0] wbuf_m6;
	ShiftRegisterMacro #(
		.WIDTH(32),
		.DEPTH(32)
	) wbuf_m6_shreg (
		.clk(clk),
		.addr(5'd5),
		.din(wbuf_wdata),
		.ce(wbuf_wr_en),
		.dout(wbuf_m6)
	);
	
	//FFs are more area-efficient here
	reg[31:0] wbuf_m1 = 0;
	reg[31:0] wbuf_m2 = 0;
	reg[31:0] wbuf_m7 = 0;
	reg[31:0] wbuf_m15 = 0;
	reg[31:0] wbuf_m16 = 0;
	always @(posedge clk) begin
		if(wbuf_wr_en) begin
			wbuf_m1 <= wbuf_wdata;
			wbuf_m2 <= wbuf_m1;
			wbuf_m7 <= wbuf_m6;
			wbuf_m15 <= wbuf_m14;
			wbuf_m16 <= wbuf_m15;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helper function
	
	function [31:0] rotr (input [31:0] data, input [4:0] shift);
		reg [63:0] tmp;
		begin
			tmp = {data, data} >> shift;
			rotr = tmp[31:0];
		end
	endfunction
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Round constant table
	
	(* RAM_STYLE = "BLOCK" *)
	reg[31:0] ktable[63:0];
	initial begin
		ktable[0] <= 32'h428a2f98;
		ktable[1] <= 32'h71374491;
		ktable[2] <= 32'hb5c0fbcf;
		ktable[3] <= 32'he9b5dba5;
		ktable[4] <= 32'h3956c25b;
		ktable[5] <= 32'h59f111f1;
		ktable[6] <= 32'h923f82a4;
		ktable[7] <= 32'hab1c5ed5;
		ktable[8] <= 32'hd807aa98;
		ktable[9] <= 32'h12835b01;
		ktable[10] <= 32'h243185be;
		ktable[11] <= 32'h550c7dc3;
		ktable[12] <= 32'h72be5d74;
		ktable[13] <= 32'h80deb1fe;
		ktable[14] <= 32'h9bdc06a7;
		ktable[15] <= 32'hc19bf174;
		ktable[16] <= 32'he49b69c1;
		ktable[17] <= 32'hefbe4786;
		ktable[18] <= 32'h0fc19dc6;
		ktable[19] <= 32'h240ca1cc;
		ktable[20] <= 32'h2de92c6f;
		ktable[21] <= 32'h4a7484aa;
		ktable[22] <= 32'h5cb0a9dc;
		ktable[23] <= 32'h76f988da;
		ktable[24] <= 32'h983e5152;
		ktable[25] <= 32'ha831c66d;
		ktable[26] <= 32'hb00327c8;
		ktable[27] <= 32'hbf597fc7;
		ktable[28] <= 32'hc6e00bf3;
		ktable[29] <= 32'hd5a79147;
		ktable[30] <= 32'h06ca6351;
		ktable[31] <= 32'h14292967;
		ktable[32] <= 32'h27b70a85;
		ktable[33] <= 32'h2e1b2138;
		ktable[34] <= 32'h4d2c6dfc;
		ktable[35] <= 32'h53380d13;
		ktable[36] <= 32'h650a7354;
		ktable[37] <= 32'h766a0abb;
		ktable[38] <= 32'h81c2c92e;
		ktable[39] <= 32'h92722c85;
		ktable[40] <= 32'ha2bfe8a1;
		ktable[41] <= 32'ha81a664b;
		ktable[42] <= 32'hc24b8b70;
		ktable[43] <= 32'hc76c51a3;
		ktable[44] <= 32'hd192e819;
		ktable[45] <= 32'hd6990624;
		ktable[46] <= 32'hf40e3585;
		ktable[47] <= 32'h106aa070;
		ktable[48] <= 32'h19a4c116;
		ktable[49] <= 32'h1e376c08;
		ktable[50] <= 32'h2748774c;
		ktable[51] <= 32'h34b0bcb5;
		ktable[52] <= 32'h391c0cb3;
		ktable[53] <= 32'h4ed8aa4a;
		ktable[54] <= 32'h5b9cca4f;
		ktable[55] <= 32'h682e6ff3;
		ktable[56] <= 32'h748f82ee;
		ktable[57] <= 32'h78a5636f;
		ktable[58] <= 32'h84c87814;
		ktable[59] <= 32'h8cc70208;
		ktable[60] <= 32'h90befffa;
		ktable[61] <= 32'ha4506ceb;
		ktable[62] <= 32'hbef9a3f7;
		ktable[63] <= 32'hc67178f2;
	end
	
	//Read port
	reg[5:0] ktable_rd_addr = 0;
	reg ktable_rd_en = 0;
	reg[31:0] k = 0;
	always @(posedge clk) begin
		if(ktable_rd_en)
			k <= ktable[ktable_rd_addr];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Actual hash process
	
	reg[31:0] h0 = 0;
	reg[31:0] h1 = 0;
	reg[31:0] h2 = 0;
	reg[31:0] h3 = 0;
	reg[31:0] h4 = 0;
	reg[31:0] h5 = 0;
	reg[31:0] h6 = 0;
	reg[31:0] h7 = 0;
	
	reg[31:0] a = 0;
	reg[31:0] b = 0;
	reg[31:0] c = 0;
	reg[31:0] d = 0;
	reg[31:0] e = 0;
	reg[31:0] f = 0;
	reg[31:0] g = 0;
	reg[31:0] h = 0;
	
	//Addition of the compressed chunks to the current hash
	wire[31:0] h0_next = h0 + a;
	wire[31:0] h1_next = h1 + b;
	wire[31:0] h2_next = h2 + c;
	wire[31:0] h3_next = h3 + d;
	wire[31:0] h4_next = h4 + e;
	wire[31:0] h5_next = h5 + f;
	wire[31:0] h6_next = h6 + g;
	wire[31:0] h7_next = h7 + h;
	
	/*
		Operation
		
		Reset
			Load h*
			Reset pointers
			
		Ready for chunk to start			
		Get write request
			Write to next word of W array
		Block end
			Copy h* into a...h
			Extend W, padding as needed if last block
			Run compression function
			Write back to h*
			Assert blockdone
			If last block and more padding is needed, go back and run one more block
		Done
			Assert blockdone
	 */
	
	`include "AreaOptimizedSHA256_states_constants.v"
	
	reg[3:0] state = STATE_IDLE;
	
	//can hold up to 4GB
	reg[32:0] message_len = 0;
	
	reg[31:0] temp1 = 0;
	reg[31:0] temp2 = 0;
	reg last_iter = 0;
	reg lastblock = 0;
	reg more_padding_needed = 0;
	reg[3:0] next_pad_state = STATE_IDLE;
	reg wbuf_wr_stop = 0;
	reg[2:0] donecount = 0;
	
	always @(posedge clk) begin
		
		wbuf_wr_en <= 0;
		resetdone <= 0;
		ktable_rd_en <= 0;
		blockdone <= 0;
		done <= 0;
		
		//Bump write address after a write finishes
		if(wbuf_wr_en)
			wbuf_wr_addr <= wbuf_wr_addr + 6'h1;
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Idle, wait for writes
			STATE_IDLE: begin
			
				//If writing to the current chunk, do it
				if(we) begin
					wbuf_wdata <= din;
					wbuf_wr_en <= 1;
					message_len <= message_len + 27'h1;
				end
				
				//If done writing to the block, process it
				if(blockend) begin
					
					more_padding_needed <= 0;
					lastblock <= 0;
					
					//Append padding if last block
					if(finish) begin
						state <= STATE_PAD_1;
						lastblock <= 1;
					end
					
					//If not finishing, go on and do the compression
					else begin
						state <= STATE_COMPRESS_0;
						
						a <= h0;
						b <= h1;
						c <= h2;
						d <= h3;
						e <= h4;
						f <= h5;
						g <= h6;
						h <= h7;

						ktable_rd_en <= 1;
						ktable_rd_addr <= 0;
					end
					
				end
			
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Padding
			
			//Append a 1 bit, then zeros
			STATE_PAD_1: begin
			
				//If this is the last block, and 14 or more words long, we need to finish padding in the next block
				if(wbuf_wr_addr >= 13) begin
					more_padding_needed <= 1;
					
					//If we have at least one word free, append the 0x80000000 and finish padding next block.
					if(wbuf_wr_addr <= 15) begin
						next_pad_state <= STATE_PAD_2;
						wbuf_wdata <= 32'h80000000;
						wbuf_wr_en <= 1;
						state <= STATE_PAD_2;
					end
					
					//Totally full? Skip padding for now
					else begin
						next_pad_state <= STATE_PAD_1;
						state <= STATE_COMPRESS_0;
					end

				end
				
				//Append the 1 bit then zeros
				else begin
					wbuf_wdata <= 32'h80000000;
					wbuf_wr_en <= 1;
					state <= STATE_PAD_2;
				end

			end	//end STATE_PAD_1
			
			//Append zero bits until the block hits 14 words in length
			STATE_PAD_2: begin
				if(!wbuf_wr_en) begin
					if(wbuf_wr_addr < 14) begin
						wbuf_wdata <= 32'h00000000;
						wbuf_wr_en <= 1;
					end
					else if(wbuf_wr_addr == 14)
						state <= STATE_PAD_3;
					else if(wbuf_wr_addr == 15) begin
						wbuf_wdata <= 32'h00000000;
						wbuf_wr_en <= 1;
						state <= STATE_COMPRESS_0;
					end
				end
			end
			
			//Append length, as a 64-bit big-endian integer
			//High half is always zero since we don't support >4GB messages
			STATE_PAD_3: begin
				wbuf_wdata <= {27'h0, message_len[31:26]};
				wbuf_wr_en <= 1;
				state <= STATE_PAD_4;				
			end	//end STATE_PAD_3
			STATE_PAD_4: begin
				wbuf_wdata <= {message_len[26:0], 5'b0};
				wbuf_wr_en <= 1;
				state <= STATE_COMPRESS_0;
			end	//end STATE_PAD_4
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Compression function
			
			STATE_COMPRESS_0: begin
				state <= STATE_COMPRESS_1;
				
				ktable_rd_en <= 1;
				ktable_rd_addr <= 0;
				
				wbuf_wr_stop <= 0;

			end	//end STATE_COMPRESS_0
			
			//Wait for initial table reads 
			STATE_COMPRESS_1: begin
				state <= STATE_COMPRESS_2;
				
				a <= h0;
				b <= h1;
				c <= h2;
				d <= h3;
				e <= h4;
				f <= h5;
				g <= h6;
				h <= h7;
				
				last_iter <= 0;
			end	//end STATE_COMPRESS_1
			
			STATE_COMPRESS_2: begin
			
				//Message expansion
				if(!wbuf_wr_stop) begin
					wbuf_wdata <=
						( rotr(wbuf_m15, 7) ^ rotr(wbuf_m15, 18) ^ wbuf_m15[31:3] ) +
						( rotr(wbuf_m2, 17) ^ rotr(wbuf_m2,  19) ^ wbuf_m2[31:10] ) +
						wbuf_m7 +
						wbuf_m16;
					wbuf_wr_en <= 1;
					if(wbuf_wr_addr == 63)
						wbuf_wr_stop <= 1;
				end
				
				//Flush shift registers with zeros to push out last 16 words
				else begin
					wbuf_wr_en <= 1;
					wbuf_wdata <= 32'h0;
				end
				
				temp1 <=
					(rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25) ) +
					( (e & f) ^ (~e & g) ) +
					wbuf_m16;
			
				temp2 <=	
					(rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22) ) +
					( (a & b) ^ (a & c) ^ (b & c) );
			
				state <= STATE_COMPRESS_3;
				
				//Prepare to read the next K value
				ktable_rd_en <= 1;
				ktable_rd_addr <= ktable_rd_addr + 6'h1;

			end	//end STATE_COMPRESS_2
			
			STATE_COMPRESS_3: begin
			
				h <= g;
				g <= f;
				f <= e;
				e <= d + temp1 + k + h;
				d <= c;
				c <= b;
				b <= a;
				a <= temp1 + k + h + temp2;
				
				//Handle the end
				if(ktable_rd_addr == 63)
					last_iter <= 1;
					
				if(last_iter)
					state <= STATE_BLOCK_DONE;
				else
					state <= STATE_COMPRESS_2;

			end	//end STATE_COMPRESS_3
			
			STATE_BLOCK_DONE: begin

				//Finish the block
				h0 <= h0_next;
				h1 <= h1_next;
				h2 <= h2_next;
				h3 <= h3_next;
				h4 <= h4_next;
				h5 <= h5_next;
				h6 <= h6_next;
				h7 <= h7_next;
				blockdone <= 1;
				state <= STATE_IDLE;
				
				last_iter <= 0;
				
				//More padding required? Go back and do another block
				if(more_padding_needed) begin
					state <= next_pad_state;
					more_padding_needed <= 0;
					
					wbuf_wr_addr <= 0;
					ktable_rd_en <= 1;
					ktable_rd_addr <= 0;
				end
				
				//Set done flat and output if this is the last block
				else if(lastblock) begin
					lastblock <= 0;
					
					done <= 1;
					dout <= h0_next;
					donecount <= 0;
					state <= STATE_DONE;
					
					ktable_rd_addr <= 0;
					wbuf_wr_addr <= 0;
					message_len <= 0;
				end

			end	//end STATE_BLOCK_DONE
			
			STATE_DONE: begin
				donecount <= donecount + 3'h1;

				case(donecount)
					0: dout <= h1;
					1: dout <= h2;
					2: dout <= h3;
					3: dout <= h4;
					4: dout <= h5;
					5: dout <= h6;
					
					6: begin
						dout <= h7;
						
						h0 <= 32'h6a09e667;
						h1 <= 32'hbb67ae85;
						h2 <= 32'h3c6ef372;
						h3 <= 32'ha54ff53a;
						h4 <= 32'h510e527f;
						h5 <= 32'h9b05688c;
						h6 <= 32'h1f83d9ab;
						h7 <= 32'h5be0cd19;
						
						state <= STATE_IDLE;
					end
				endcase

			end	//end STATE_DONE
			
		endcase
			
		if(reset) begin
			h0 <= 32'h6a09e667;
			h1 <= 32'hbb67ae85;
			h2 <= 32'h3c6ef372;
			h3 <= 32'ha54ff53a;
			h4 <= 32'h510e527f;
			h5 <= 32'h9b05688c;
			h6 <= 32'h1f83d9ab;
			h7 <= 32'h5be0cd19;
			
			ktable_rd_addr <= 0;
			wbuf_wr_addr <= 0;
			
			message_len <= 0;
			
			resetdone <= 1;
			
			state <= STATE_IDLE;
		end
					
	end
	
endmodule
