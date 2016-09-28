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
	@brief HMAC-SHA256 signature checking module
	
	Input is handled as 32-bit words and must be multiple of 32 bits in size.
	
	Key is a 512-bit synthesis-time constant.
 */
module HMACSHA256SignatureChecker(
	clk,
	start_en, data_en, finish_en, din,
	done, dout_valid, dout
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire clk;
	
	input wire			start_en;
	input wire			data_en;
	input wire			finish_en;
	input wire[31:0]	din;
	
	output reg			done		= 0;
	output reg			dout_valid	= 0;
	output reg[31:0]	dout		= 0;
	
	//The key
	parameter			KEY_0 = 32'h00000000;
	parameter			KEY_1 = 32'h00000000;
	parameter			KEY_2 = 32'h00000000;
	parameter			KEY_3 = 32'h00000000;
	parameter			KEY_4 = 32'h00000000;
	parameter			KEY_5 = 32'h00000000;
	parameter			KEY_6 = 32'h00000000;
	parameter			KEY_7 = 32'h00000000;
	parameter			KEY_8 = 32'h00000000;
	parameter			KEY_9 = 32'h00000000;
	parameter			KEY_A = 32'h00000000;
	parameter			KEY_B = 32'h00000000;
	parameter			KEY_C = 32'h00000000;
	parameter			KEY_D = 32'h00000000;
	parameter			KEY_E = 32'h00000000;
	parameter			KEY_F = 32'h00000000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Padding ROM
	
	reg[31:0] padrom[31:0];
	
	initial begin
	
		//inner padding
		padrom[5'h00]		<= KEY_0 ^ 32'h36363636;
		padrom[5'h01]		<= KEY_1 ^ 32'h36363636;
		padrom[5'h02]		<= KEY_2 ^ 32'h36363636;
		padrom[5'h03]		<= KEY_3 ^ 32'h36363636;
		padrom[5'h04]		<= KEY_4 ^ 32'h36363636;
		padrom[5'h05]		<= KEY_5 ^ 32'h36363636;
		padrom[5'h06]		<= KEY_6 ^ 32'h36363636;
		padrom[5'h07]		<= KEY_7 ^ 32'h36363636;
		padrom[5'h08]		<= KEY_8 ^ 32'h36363636;
		padrom[5'h09]		<= KEY_9 ^ 32'h36363636;
		padrom[5'h0a]		<= KEY_A ^ 32'h36363636;
		padrom[5'h0b]		<= KEY_B ^ 32'h36363636;
		padrom[5'h0c]		<= KEY_C ^ 32'h36363636;
		padrom[5'h0d]		<= KEY_D ^ 32'h36363636;
		padrom[5'h0e]		<= KEY_E ^ 32'h36363636;
		padrom[5'h0f]		<= KEY_F ^ 32'h36363636;
		
		//inner padding
		padrom[5'h10]		<= KEY_0 ^ 32'h5c5c5c5c;
		padrom[5'h11]		<= KEY_1 ^ 32'h5c5c5c5c;
		padrom[5'h12]		<= KEY_2 ^ 32'h5c5c5c5c;
		padrom[5'h13]		<= KEY_3 ^ 32'h5c5c5c5c;
		padrom[5'h14]		<= KEY_4 ^ 32'h5c5c5c5c;
		padrom[5'h15]		<= KEY_5 ^ 32'h5c5c5c5c;
		padrom[5'h16]		<= KEY_6 ^ 32'h5c5c5c5c;
		padrom[5'h17]		<= KEY_7 ^ 32'h5c5c5c5c;
		padrom[5'h18]		<= KEY_8 ^ 32'h5c5c5c5c;
		padrom[5'h19]		<= KEY_9 ^ 32'h5c5c5c5c;
		padrom[5'h1a]		<= KEY_A ^ 32'h5c5c5c5c;
		padrom[5'h1b]		<= KEY_B ^ 32'h5c5c5c5c;
		padrom[5'h1c]		<= KEY_C ^ 32'h5c5c5c5c;
		padrom[5'h1d]		<= KEY_D ^ 32'h5c5c5c5c;
		padrom[5'h1e]		<= KEY_E ^ 32'h5c5c5c5c;
		padrom[5'h1f]		<= KEY_F ^ 32'h5c5c5c5c;
	
	end
	
	reg[4:0]	padrom_raddr	= 0;
	reg[31:0]	padrom_rdata	= 0;
	
	always @(*) begin
		padrom_rdata		<= padrom[padrom_raddr];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Temporary buffer for storing hash results
	
	reg			hashbuf_wr		= 0;
	reg[2:0]	hashbuf_addr	= 0;
	reg[31:0]	hashbuf_din		= 0;
	wire[31:0]	hashbuf_dout;
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(8),
		.DUAL_PORT(0),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b0),
		.INIT_ADDR(0),
		.INIT_FILE(0)
	) hashmem (
		.porta_clk(clk),
		.porta_en(1'b1),
		.porta_addr(hashbuf_addr),
		.porta_we(hashbuf_wr),
		.porta_din(hashbuf_din),
		.porta_dout(hashbuf_dout),
		.portb_clk(clk),
		.portb_en(1'b0),
		.portb_addr(3'h0),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout()
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The hasher
	
	reg			hash_start_en	= 0;
	reg			hash_data_en	= 0;
	reg 		hash_finish_en	= 0;
	reg[31:0]	hash_din		= 0;
	
	wire		hash_done;
	wire		hash_dout_valid;
	wire[31:0]	hash_dout;
	
	MicrocodedSHA256 hasher(
		.clk(clk),
		.start_en(hash_start_en),
		.data_en(hash_data_en),
		.finish_en(hash_finish_en),
		.din(hash_din),
		.done(hash_done),
		.dout_valid(hash_dout_valid),
		.dout(hash_dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	/*
		On reset
			Reset hasher
			Hash ipad
		On message process
			Push on to hasher
		On finish
			Finish hash
			Save output
			Reset hasher
			Hash opad
			Finish hash
			Stream out the resulting HMAC
	 */
	 
	 reg[3:0]		state = 0;
	 
	 always @(posedge clk) begin
	 
		hash_start_en	<= 0;
		hash_data_en	<= 0;
		hash_finish_en	<= 0;
		hash_din		<= 0;
		
		done			<= 0;
		
		hashbuf_wr		<= 0;
		hashbuf_din		<= 0;
		
		case(state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Idle, wait for commands
			
			0: begin
				
				//Reset and start a new hash
				if(start_en) begin
					hash_start_en	<= 1;
					state			<= 1;
				end
				
				//Feed in new data words
				if(data_en) begin
					hash_data_en	<= 1;
					hash_din		<= din;
					state			<= 4;
				end
				
				//Finish a hash
				if(finish_en) begin
					hash_finish_en	<= 1;
					hashbuf_addr	<= 0;
					state			<= 5;
				end
				
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Initialization
			
			//Wait for hasher to reset
			1: begin
				if(hash_done) begin
					padrom_raddr	<= 0;
					state			<= 2;
				end
			end
			
			//Hash i_pad
			2: begin
				hash_data_en		<= 1;
				hash_din			<= padrom_rdata;
				padrom_raddr		<= padrom_raddr + 5'h1;
				state				<= 3;
			end
			
			3: begin
				if(hash_done) begin
					
					//Done pre-hashing?
					if(padrom_raddr == 5'h10) begin
						padrom_raddr	<= 0;
						done			<= 1;
						state			<= 0;
					end
					
					//No, hash next word
					else
						state		<= 2;
						
				end
			end
						
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for data to be processed
			
			4: begin
				if(hash_done) begin
					done	<= 1;
					state	<= 0;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Finish the HMAC
			
			//Wait for first hash to finish
			5: begin
				
				//Save the first-pass hash to the buffer
				if(hash_dout_valid) begin
					hashbuf_wr		<= 1;
					hashbuf_din		<= hash_dout;
				end
				
				//Bump address after each hash data word
				if(hashbuf_wr)
					hashbuf_addr	<= hashbuf_addr + 3'h1;

				//If hash is done, reset the hasher for pass 2
				if(hash_done) begin
					hash_start_en	<= 1;
					state			<= 6;
				end
				
			end

			//Wait for reset to finish
			6: begin
				if(hash_done) begin
					state			<= 7;
					padrom_raddr	<= 5'h10;
				end
			end
			
			//Hash o_pad
			7: begin
				hash_data_en		<= 1;
				hash_din			<= padrom_rdata;
				padrom_raddr		<= padrom_raddr + 5'h1;
				state				<= 8;
			end
			
			8: begin
				if(hash_done) begin
					
					//Done pre-hashing?
					if(padrom_raddr == 5'h0) begin
						hashbuf_addr	<= 0;
						state			<= 9;
					end
					
					//No, hash next word
					else
						state		<= 7;
						
				end
			end
			
			//Hash the original hash
			9: begin
				hash_data_en		<= 1;
				hash_din			<= hashbuf_dout;
				state				<= 10;
			end
			
			10: begin
				if(hash_done) begin
				
					hashbuf_addr		<= hashbuf_addr + 3'h1;
				
					if(hashbuf_addr == 7) begin
						hash_finish_en	<= 1;
						state			<= 11;
					end
					else
						state			<= 9;
					
				end
			end
			
			//Wait for the hash to finish
			11: begin
				dout_valid				<= hash_dout_valid;
				dout					<= hash_dout;
				if(hash_done) begin
					done				<= 1;
					state				<= 0;
				end
			end

		endcase
	 
	 end

endmodule
