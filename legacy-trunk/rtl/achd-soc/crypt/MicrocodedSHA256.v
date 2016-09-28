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
	@brief Microcoded SHA-256, smaller and slower than AreaOptimizedSHA256
	
	Input is handled as 32-bit words and must be multiple of 32 bits in size.
	
	Input procedure:
	
		To start a new hash
			Assert start_en
			Wait for done to go high
			
		To hash data
			Assert data_en with data on din
			Wait for done to go high
			
		To finish a hash
			Assert finish_en
			When dout_valid goes high, a word of the hash is on dout
			Done is asserted the cycle after the last data word is output
 */
module MicrocodedSHA256(
	clk,
	start_en, data_en, finish_en, din,
	done, dout_valid, dout
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire 			clk;
	
	input wire			start_en;
	input wire			data_en;
	input wire			finish_en;
	input wire[31:0]	din;
	
	output reg			done		= 0;
	output reg			dout_valid	= 0;
	output reg[31:0]	dout		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The register file
	
	localparam REG_H0	= 5'h00;
	localparam REG_H1	= 5'h01;
	localparam REG_H2	= 5'h02;
	localparam REG_H3	= 5'h03;
	localparam REG_H4	= 5'h04;
	localparam REG_H5	= 5'h05;
	localparam REG_H6	= 5'h06;
	localparam REG_H7	= 5'h07;
	
	localparam REG_A	= 5'h08;
	localparam REG_B	= 5'h09;
	localparam REG_C	= 5'h0A;
	localparam REG_D	= 5'h0B;
	localparam REG_E	= 5'h0C;
	localparam REG_F	= 5'h0D;
	localparam REG_G	= 5'h0E;
	localparam REG_H	= 5'h0F;
	
	localparam REG_T0	= 5'h10;
	localparam REG_T1	= 5'h11;
	localparam REG_T2	= 5'h12;
	localparam REG_T3	= 5'h13;
	localparam REG_T4	= 5'h14;
	localparam REG_T5	= 5'h15;
	localparam REG_T6	= 5'h16;
	localparam REG_T7	= 5'h17;
	
	localparam REG_LN	= 5'h18;	//Message length (in 32-bit words)
	localparam REG_IN	= 5'h19;	//Input data register
	
	localparam REG_ZO	= 5'h1a;	//constant zero
	
	//1b to 1f not used
	
	reg			regfile_porta_en	= 0;
	reg[4:0]	regfile_porta_addr	= 0;
	reg			regfile_porta_wr	= 0;
	reg[31:0]	regfile_porta_din	= 0;
	wire[31:0]	regfile_porta_dout;
	
	reg			regfile_portb_en	= 0;
	reg[4:0]	regfile_portb_addr	= 0;
	wire[31:0]	regfile_portb_dout;
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(32),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1),
		.INIT_ADDR(0),
		.INIT_FILE(0)
	) regfile (
		.porta_clk(clk),
		.porta_en(regfile_porta_en),
		.porta_addr(regfile_porta_addr),
		.porta_we(regfile_porta_wr),
		.porta_din(regfile_porta_din),
		.porta_dout(regfile_porta_dout),
		.portb_clk(clk),
		.portb_en(regfile_portb_en),
		.portb_addr(regfile_portb_addr),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(regfile_portb_dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Data memory
	
	reg				wmem_en		= 0;
	reg				wmem_wr		= 0;
	reg[5:0]		wmem_addr	= 0;
	reg[31:0]		wmem_din	= 0;
	wire[31:0]		wmem_dout;
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(64),
		.DUAL_PORT(0),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b1),
		.INIT_ADDR(0),
		.INIT_FILE(0)
	) wmem (
		.porta_clk(clk),
		.porta_en(wmem_en),
		.porta_addr(wmem_addr),
		.porta_we(wmem_wr),
		.porta_din(wmem_din),
		.porta_dout(wmem_dout),
		
		.portb_clk(clk),
		.portb_en(1'b0),
		.portb_addr(6'h0),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout()
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Microcode / constant ROM
	
	//List of opcodes
	localparam OP_NOT		= 4'h0;	//rd = ~ra	
	localparam OP_ROR		= 4'h1;	//rd = ra >>> imm
	localparam OP_SHR		= 4'h2;	//rd = ra >> imm
	localparam OP_XOR		= 4'h3;	//rd = ra ^ rb
	localparam OP_ADD		= 4'h4; //rd = ra + rb
	localparam OP_AND		= 4'h5;	//rd = ra & rb
	localparam OP_LWR		= 4'h6;	//rd = rom[rb + imm]
	localparam OP_LW		= 4'h7;	//rd = w[rb - imm]
	localparam OP_SW		= 4'h8;	//w[rb + imm] = ra
	localparam OP_HLT		= 4'h9; //Assert DONE flag and stop executing microcode if ra == imm8
	localparam OP_OUT		= 4'ha;	//dout = ra and strobe dout_valid
	localparam OP_BGT		= 4'hb;	//Jump to imm if ra > rb
	
	//Padding for microcode to fit 32-bit ROM (needed for 32-bit data constants)
	localparam PAD			= 6'h0;
	 
	//Function base addresses
	localparam FUNC_INIT		= 9'h100;					//0b words long
	localparam FUNC_FINISH		= FUNC_INIT 	+ 9'h0b;	//14 words long
	localparam FUNC_COMPRESS	= FUNC_FINISH 	+ 9'h14;	//54 words long
	localparam FUNC_OUTPUT		= FUNC_COMPRESS + 9'h54;	//09 words long
	localparam FUNC_INPUT		= FUNC_OUTPUT   + 9'h09;	//0d words long
	 
	//256 words data ROM, 256 words microcode
	reg[31:0]	rom[511:0];
	
	/*
		31:27	6 bits of padding (zero)
		26:23	4-bit opcode
		22:18	5-bit destination register
		17:13	5-bit source register A
		12:8	5-bit source register B
		7:0		8-bit immediate constant
	 */
	reg[8:0] tmp;
	initial begin
	
		//00 - 3f = K values TODO
		rom[9'h000] <= 32'h428a2f98;
		rom[9'h001] <= 32'h71374491;
		rom[9'h002] <= 32'hb5c0fbcf;
		rom[9'h003] <= 32'he9b5dba5;
		rom[9'h004] <= 32'h3956c25b;
		rom[9'h005] <= 32'h59f111f1;
		rom[9'h006] <= 32'h923f82a4;
		rom[9'h007] <= 32'hab1c5ed5;
		rom[9'h008] <= 32'hd807aa98;
		rom[9'h009] <= 32'h12835b01;
		rom[9'h00a] <= 32'h243185be;
		rom[9'h00b] <= 32'h550c7dc3;
		rom[9'h00c] <= 32'h72be5d74;
		rom[9'h00d] <= 32'h80deb1fe;
		rom[9'h00e] <= 32'h9bdc06a7;
		rom[9'h00f] <= 32'hc19bf174;
		rom[9'h010] <= 32'he49b69c1;
		rom[9'h011] <= 32'hefbe4786;
		rom[9'h012] <= 32'h0fc19dc6;
		rom[9'h013] <= 32'h240ca1cc;
		rom[9'h014] <= 32'h2de92c6f;
		rom[9'h015] <= 32'h4a7484aa;
		rom[9'h016] <= 32'h5cb0a9dc;
		rom[9'h017] <= 32'h76f988da;
		rom[9'h018] <= 32'h983e5152;
		rom[9'h019] <= 32'ha831c66d;
		rom[9'h01a] <= 32'hb00327c8;
		rom[9'h01b] <= 32'hbf597fc7;
		rom[9'h01c] <= 32'hc6e00bf3;
		rom[9'h01d] <= 32'hd5a79147;
		rom[9'h01e] <= 32'h06ca6351;
		rom[9'h01f] <= 32'h14292967;
		rom[9'h020] <= 32'h27b70a85;
		rom[9'h021] <= 32'h2e1b2138;
		rom[9'h022] <= 32'h4d2c6dfc;
		rom[9'h023] <= 32'h53380d13;
		rom[9'h024] <= 32'h650a7354;
		rom[9'h025] <= 32'h766a0abb;
		rom[9'h026] <= 32'h81c2c92e;
		rom[9'h027] <= 32'h92722c85;
		rom[9'h028] <= 32'ha2bfe8a1;
		rom[9'h029] <= 32'ha81a664b;
		rom[9'h02a] <= 32'hc24b8b70;
		rom[9'h02b] <= 32'hc76c51a3;
		rom[9'h02c] <= 32'hd192e819;
		rom[9'h02d] <= 32'hd6990624;
		rom[9'h02e] <= 32'hf40e3585;
		rom[9'h02f] <= 32'h106aa070;
		rom[9'h030] <= 32'h19a4c116;
		rom[9'h031] <= 32'h1e376c08;
		rom[9'h032] <= 32'h2748774c;
		rom[9'h033] <= 32'h34b0bcb5;
		rom[9'h034] <= 32'h391c0cb3;
		rom[9'h035] <= 32'h4ed8aa4a;
		rom[9'h036] <= 32'h5b9cca4f;
		rom[9'h037] <= 32'h682e6ff3;
		rom[9'h038] <= 32'h748f82ee;
		rom[9'h039] <= 32'h78a5636f;
		rom[9'h03a] <= 32'h84c87814;
		rom[9'h03b] <= 32'h8cc70208;
		rom[9'h03c] <= 32'h90befffa;
		rom[9'h03d] <= 32'ha4506ceb;
		rom[9'h03e] <= 32'hbef9a3f7;
		rom[9'h03f] <= 32'hc67178f2;
		
		//40 - 47 = initial hash values
		rom[9'h040]	<= 32'h6a09e667;
		rom[9'h041]	<= 32'hbb67ae85;
		rom[9'h042]	<= 32'h3c6ef372;
		rom[9'h043]	<= 32'ha54ff53a;
		rom[9'h044]	<= 32'h510e527f;
		rom[9'h045]	<= 32'h9b05688c;
		rom[9'h046]	<= 32'h1f83d9ab;
		rom[9'h047]	<= 32'h5be0cd19;
		
		//48 - xx = random handy constants
		rom[9'h048] <= 32'h0000000F;
		rom[9'h049]	<= 32'h80000000;
		rom[9'h04a] <= 32'h00000001;
		rom[9'h04b] <= 32'h0000000E;
		rom[9'h04c] <= 32'h00000010;
		rom[9'h04d] <= 32'h00000040;
		rom[9'h04e] <= 32'h00000002;
		rom[9'h04f] <= 32'h00000020;
		rom[9'h050] <= 32'h00000003;
		
		//051 - 0FF = unused, leave X for now

		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//FUNC_INIT: Initialize H values to prepare for a new hash
		
		rom[FUNC_INIT + 8'h00]		<= {PAD, OP_LWR, REG_H0, REG_ZO, REG_ZO, 8'h40};	//h0 = rom['h40]
		rom[FUNC_INIT + 8'h01]		<= {PAD, OP_LWR, REG_H1, REG_ZO, REG_ZO, 8'h41};	//h1 = rom['h41]
		rom[FUNC_INIT + 8'h02]		<= {PAD, OP_LWR, REG_H2, REG_ZO, REG_ZO, 8'h42};	//h2 = rom['h42]
		rom[FUNC_INIT + 8'h03]		<= {PAD, OP_LWR, REG_H3, REG_ZO, REG_ZO, 8'h43};	//h3 = rom['h43]
		rom[FUNC_INIT + 8'h04]		<= {PAD, OP_LWR, REG_H4, REG_ZO, REG_ZO, 8'h44};	//h4 = rom['h44]
		rom[FUNC_INIT + 8'h05]		<= {PAD, OP_LWR, REG_H5, REG_ZO, REG_ZO, 8'h45};	//h5 = rom['h45]
		rom[FUNC_INIT + 8'h06]		<= {PAD, OP_LWR, REG_H6, REG_ZO, REG_ZO, 8'h46};	//h6 = rom['h46]
		rom[FUNC_INIT + 8'h07]		<= {PAD, OP_LWR, REG_H7, REG_ZO, REG_ZO, 8'h47};	//h7 = rom['h47]
		rom[FUNC_INIT + 8'h08]		<= {PAD, OP_ADD, REG_LN, REG_ZO, REG_ZO, 8'h00};	//ln = 0
		rom[FUNC_INIT + 8'h09]		<= {PAD, OP_ADD, REG_T7, REG_ZO, REG_ZO, 8'h00};	//t7 = 0 (not last chunk)
		rom[FUNC_INIT + 8'h0a]		<= {PAD, OP_HLT, REG_ZO, REG_ZO, REG_ZO, 8'h00};	//halt
	
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//FUNC_FINISH: Finish a hash
		
		//t7 = number of padding words added
		//     0 = not last chunk
		//     1 = last chunk, need to add padding + length
		//     2 = last chunk, need to add length
		//     3 = last chunk, fully padded
		// 
		
		//Load constants from ROM
		rom[FUNC_FINISH + 8'h00]	<= {PAD, OP_LWR, REG_T0, REG_ZO, REG_ZO, 8'h48};	//t0 = 15
		rom[FUNC_FINISH + 8'h01]	<= {PAD, OP_LWR, REG_T2, REG_ZO, REG_ZO, 8'h49};	//t2 = 0x80000000
		rom[FUNC_FINISH + 8'h02]	<= {PAD, OP_LWR, REG_T5, REG_ZO, REG_ZO, 8'h4b};	//t5 = 14
		rom[FUNC_FINISH + 8'h03]	<= {PAD, OP_LWR,  REG_T6, REG_ZO, REG_ZO, 8'h4a};	//t6 = 1
		
		//Compute size of this block. in words
		rom[FUNC_FINISH + 8'h04]	<= {PAD, OP_SHR, REG_T3, REG_LN, REG_ZO, 8'h05};	//t3 = msg len in words
		rom[FUNC_FINISH + 8'h05]	<= {PAD, OP_AND, REG_T1, REG_T3, REG_T0, 8'h00};	//t1 = wordlen mod 16
		
		//We are guaranteed to have room for the first pad word (0x80000000), so add it
		rom[FUNC_FINISH + 8'h06]	<= {PAD, OP_SW,  REG_ZO, REG_T2, REG_T1, 8'h00};	//w[t1] = t2
		rom[FUNC_FINISH + 8'h07]	<= {PAD, OP_ADD, REG_T1, REG_T1, REG_T6, 8'h00};	//i++
		rom[FUNC_FINISH + 8'h08]	<= {PAD, OP_ADD, REG_T7, REG_T6, REG_ZO, 8'h00};	//got 1st pad word
		tmp = FUNC_COMPRESS[7:0];
		rom[FUNC_FINISH + 8'h09]	<= {PAD, OP_BGT, REG_ZO, REG_T1, REG_T0, tmp[7:0]};	//if t1 > 15 block is full
																						//so compress
		
		//We have room for the second pad word. This is all zeroes and may be either the high
		//half of the 64-bit length, or filler before it.
		rom[FUNC_FINISH + 8'h0a]	<= {PAD, OP_SW,	 REG_ZO, REG_ZO, REG_T1, 8'h00};	//write zero/length
		rom[FUNC_FINISH + 8'h0b]	<= {PAD, OP_ADD, REG_T1, REG_T1, REG_T6, 8'h00};	//i++
		rom[FUNC_FINISH + 8'h0c]	<= {PAD, OP_ADD, REG_T7, REG_T7, REG_T6, 8'h00};	//got 2 pad words
		tmp = FUNC_COMPRESS[7:0];
		rom[FUNC_FINISH + 8'h0d]	<= {PAD, OP_BGT, REG_ZO, REG_T1, REG_T0, tmp[7:0]};	//if t1 > 15 block is full
																						//so compress
		
		//See if we need more padding
		tmp = FUNC_FINISH[7:0] + 8'h12;
		rom[FUNC_FINISH + 8'h0e]	<= {PAD, OP_BGT, REG_ZO, REG_T1, REG_T5, tmp[7:0]};	//if t1 > 14 no extra padding
																						//so go to last
		
		//We need more padding. Loop until we have 14 words total
		rom[FUNC_FINISH + 8'h0f]	<= {PAD, OP_SW,	 REG_ZO, REG_ZO, REG_T1, 8'h00};	//write zero/length
		rom[FUNC_FINISH + 8'h10]	<= {PAD, OP_ADD, REG_T1, REG_T1, REG_T6, 8'h00};	//i++
		tmp = FUNC_FINISH + 8'h0f;
		rom[FUNC_FINISH + 8'h11]	<= {PAD, OP_BGT, REG_ZO, REG_T0, REG_T1, tmp[7:0]};	//if 15 > i do it again

		//We are at word 15
		//Write the length word
		rom[FUNC_FINISH + 8'h12]	<= {PAD, OP_SW,	 REG_ZO, REG_LN, REG_T1, 8'h00};	//write low length																							
		rom[FUNC_FINISH + 8'h13]	<= {PAD, OP_LWR, REG_T7, REG_ZO, REG_ZO, 8'h50};	//got all 3 pad words
		//Fallthrough to FUNC_COMPRESS
		//FUNC_COMPRESS must be located immediately after FUNC_FINISH for this to work
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//FUNC_COMPRESS: Compression function
		//Runs one iteration of the compression function

		/*
			t7 = padding state
		
			Compression function
				Copy A from working hash
				Extend W buffer
				Main loop
				Add compressed chunk to current hash
				If we're in the second to last block, do prep and loop back to FUNC_FINISH
				If we're in the last block, stream out the hash and stop
		 */
		
		//Copy working variables from current hash
		rom[FUNC_COMPRESS + 8'h00]	<= {PAD, OP_ADD, REG_A , REG_H0, REG_ZO, 8'h00};	//a = h0
		rom[FUNC_COMPRESS + 8'h01]	<= {PAD, OP_ADD, REG_B , REG_H1, REG_ZO, 8'h00};	//b = h1
		rom[FUNC_COMPRESS + 8'h02]	<= {PAD, OP_ADD, REG_C , REG_H2, REG_ZO, 8'h00};	//c = h2
		rom[FUNC_COMPRESS + 8'h03]	<= {PAD, OP_ADD, REG_D , REG_H3, REG_ZO, 8'h00};	//d = h3
		rom[FUNC_COMPRESS + 8'h04]	<= {PAD, OP_ADD, REG_E , REG_H4, REG_ZO, 8'h00};	//e = h4
		rom[FUNC_COMPRESS + 8'h05]	<= {PAD, OP_ADD, REG_F , REG_H5, REG_ZO, 8'h00};	//f = h5
		rom[FUNC_COMPRESS + 8'h06]	<= {PAD, OP_ADD, REG_G , REG_H6, REG_ZO, 8'h00};	//g = h6
		rom[FUNC_COMPRESS + 8'h07]	<= {PAD, OP_ADD, REG_H , REG_H7, REG_ZO, 8'h00};	//h = h7
		
		//Extend W buffer: Init
		rom[FUNC_COMPRESS + 8'h08]	<= {PAD, OP_LWR, REG_T6, REG_ZO, REG_ZO, 8'h4c};	//t6 = 16
		rom[FUNC_COMPRESS + 8'h09]	<= {PAD, OP_LWR, REG_T5, REG_ZO, REG_ZO, 8'h4a};	//t5 = 1
		rom[FUNC_COMPRESS + 8'h0a]	<= {PAD, OP_LWR, REG_T4, REG_ZO, REG_ZO, 8'h4d};	//t4 = 64
		
		//Extend W buffer: Compute s0
		rom[FUNC_COMPRESS + 8'h0b]	<= {PAD, OP_LW , REG_T0, REG_ZO, REG_T6, 8'h0f};	//t0 = w[i-15]
		rom[FUNC_COMPRESS + 8'h0c]	<= {PAD, OP_ROR, REG_T1, REG_T0, REG_ZO, 8'h07};	//t1 = w[i-15] ror 7
		rom[FUNC_COMPRESS + 8'h0d]	<= {PAD, OP_ROR, REG_T2, REG_T0, REG_ZO, 8'h12};	//t2 = w[i-15] ror 18
		rom[FUNC_COMPRESS + 8'h0e]	<= {PAD, OP_XOR, REG_T1, REG_T1, REG_T2, 8'h00};	//t1 ^= t2
		rom[FUNC_COMPRESS + 8'h0f]	<= {PAD, OP_SHR, REG_T2, REG_T0, REG_ZO, 8'h03};	//t2 = w[i-15] >> 3
		rom[FUNC_COMPRESS + 8'h10]	<= {PAD, OP_XOR, REG_T1, REG_T1, REG_T2, 8'h00};	//t1 ^= t2
																						//t1 is now s0
		
		//Extend W buffer: Compute s1
		rom[FUNC_COMPRESS + 8'h11]	<= {PAD, OP_LW , REG_T0, REG_ZO, REG_T6, 8'h02};	//t0 = w[i-2]
		rom[FUNC_COMPRESS + 8'h12]	<= {PAD, OP_ROR, REG_T2, REG_T0, REG_ZO, 8'h11};	//t2 = w[i-2] ror 17
		rom[FUNC_COMPRESS + 8'h13]	<= {PAD, OP_ROR, REG_T3, REG_T0, REG_ZO, 8'h13};	//t3 = w[i-2] ror 19
		rom[FUNC_COMPRESS + 8'h14]	<= {PAD, OP_XOR, REG_T2, REG_T2, REG_T3, 8'h00};	//t2 ^= t3
		rom[FUNC_COMPRESS + 8'h15]	<= {PAD, OP_SHR, REG_T3, REG_T0, REG_ZO, 8'h0a};	//t3 = w[i-2] >> 10
		rom[FUNC_COMPRESS + 8'h16]	<= {PAD, OP_XOR, REG_T2, REG_T2, REG_T3, 8'h00};	//t2 ^= t3
																						//t2 is now s1
																						
		//Extend W buffer: Compute w[i]
		rom[FUNC_COMPRESS + 8'h17]	<= {PAD, OP_LW , REG_T0, REG_ZO, REG_T6, 8'h10};	//t0 = w[i-16]
		rom[FUNC_COMPRESS + 8'h18]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 += s0
		rom[FUNC_COMPRESS + 8'h19]	<= {PAD, OP_LW , REG_T1, REG_ZO, REG_T6, 8'h07};	//t1 = w[i-7]
		rom[FUNC_COMPRESS + 8'h1a]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 += w[i-7]
		rom[FUNC_COMPRESS + 8'h1b]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_T2, 8'h00};	//t0 += s1
																						//t0 is now w[i]
		rom[FUNC_COMPRESS + 8'h1c]	<= {PAD, OP_SW,  REG_ZO, REG_T0, REG_T6, 8'h00};	//w[i] = t0
		
		//Bump i and loop
		rom[FUNC_COMPRESS + 8'h1d]	<= {PAD, OP_ADD, REG_T6, REG_T6, REG_T5, 8'h00};	//t6 ++
		tmp = FUNC_COMPRESS + 8'h0b;
		rom[FUNC_COMPRESS + 8'h1e]	<= {PAD, OP_BGT, REG_ZO, REG_T4, REG_T6, tmp[7:0]};	//if i < 64 go again
		
		//Done extending W
		//Time to run the main loop
		rom[FUNC_COMPRESS + 8'h1f]	<= {PAD, OP_ADD, REG_T6, REG_ZO, REG_ZO, 8'h00};	//t6 = 0
		
		//Round loop: Compute s1
		rom[FUNC_COMPRESS + 8'h20]	<= {PAD, OP_ROR, REG_T0, REG_E,  REG_ZO, 8'h06};	//t0 = e ror 6
		rom[FUNC_COMPRESS + 8'h21]	<= {PAD, OP_ROR, REG_T1, REG_E,  REG_ZO, 8'h0b};	//t1 = e ror 11
		rom[FUNC_COMPRESS + 8'h22]	<= {PAD, OP_XOR, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 ^= t1
		rom[FUNC_COMPRESS + 8'h23]	<= {PAD, OP_ROR, REG_T1, REG_E,  REG_ZO, 8'h19};	//t1 = e ror 25
		rom[FUNC_COMPRESS + 8'h24]	<= {PAD, OP_XOR, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 ^= t1
																						//t0 = s1
		
		//Round loop: compute ch
		rom[FUNC_COMPRESS + 8'h25]	<= {PAD, OP_AND, REG_T1, REG_E,  REG_F,  8'h00};	//t1 = e & f
		rom[FUNC_COMPRESS + 8'h26]	<= {PAD, OP_NOT, REG_T2, REG_E,  REG_ZO, 8'h00};	//t2 = ~e;
		rom[FUNC_COMPRESS + 8'h27]	<= {PAD, OP_AND, REG_T2, REG_T2, REG_G,  8'h00};	//t2 &= g;
		rom[FUNC_COMPRESS + 8'h28]	<= {PAD, OP_XOR, REG_T1, REG_T1, REG_T2, 8'h00};	//t1 ^+ t2
																						//t1 = ch
		
		//Round loop: Compute temp1
		rom[FUNC_COMPRESS + 8'h29]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 = s1 + ch
		rom[FUNC_COMPRESS + 8'h2a]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_H,  8'h00};	//t0 = s1 + ch + h
		rom[FUNC_COMPRESS + 8'h2b]	<= {PAD, OP_LWR, REG_T1, REG_ZO, REG_T6, 8'h00};	//t1 = rom[i] = k[i]
		rom[FUNC_COMPRESS + 8'h2c]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 += k[i]
		rom[FUNC_COMPRESS + 8'h2d]	<= {PAD, OP_LW,  REG_T1, REG_ZO, REG_T6, 8'h00};	//t1 = w[i]
		rom[FUNC_COMPRESS + 8'h2e]	<= {PAD, OP_ADD, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 += w[i]
																						//t0 = temp1
																						
		//Round loop: Compute S0
		rom[FUNC_COMPRESS + 8'h2f]	<= {PAD, OP_ROR, REG_T1, REG_A,  REG_ZO, 8'h02};	//t1 = a ror 2
		rom[FUNC_COMPRESS + 8'h30]	<= {PAD, OP_ROR, REG_T2, REG_A,  REG_ZO, 8'h0d};	//t2 = a ror 13
		rom[FUNC_COMPRESS + 8'h31]	<= {PAD, OP_XOR, REG_T1, REG_T1, REG_T2, 8'h00};	//t1 ^= t2
		rom[FUNC_COMPRESS + 8'h32]	<= {PAD, OP_ROR, REG_T2, REG_A,  REG_ZO, 8'h16};	//t2 = a ror 22
		rom[FUNC_COMPRESS + 8'h33]	<= {PAD, OP_XOR, REG_T1, REG_T1, REG_T2, 8'h00};	//t1 ^= 52
																						//t1 = S0
																						
		//Round loop: Compute maj
		rom[FUNC_COMPRESS + 8'h34]	<= {PAD, OP_AND, REG_T2, REG_A,  REG_B,  8'h00};	//t2 = a & b
		rom[FUNC_COMPRESS + 8'h35]	<= {PAD, OP_AND, REG_T3, REG_A,  REG_C,  8'h00};	//t3 = a & c
		rom[FUNC_COMPRESS + 8'h36]	<= {PAD, OP_XOR, REG_T2, REG_T2, REG_T3, 8'h00};	//t2 ^= t3
		rom[FUNC_COMPRESS + 8'h37]	<= {PAD, OP_AND, REG_T3, REG_B,  REG_C,  8'h00};	//t3 = b & c
		rom[FUNC_COMPRESS + 8'h38]	<= {PAD, OP_XOR, REG_T2, REG_T2, REG_T3, 8'h00};	//t2 ^= t3
																						//t2 = maj
		
		//Round loop: Compute temp2
		rom[FUNC_COMPRESS + 8'h39]	<= {PAD, OP_ADD, REG_T1, REG_T1, REG_T2, 8'h00};	//t1 = S0 + maj
																						//t1 = temp2
		
		//Round loop: Shift columns and add in round values
		rom[FUNC_COMPRESS + 8'h3a]	<= {PAD, OP_ADD, REG_H,  REG_G,  REG_ZO, 8'h00};	//H = G
		rom[FUNC_COMPRESS + 8'h3b]	<= {PAD, OP_ADD, REG_G,  REG_F,  REG_ZO, 8'h00};	//G = F
		rom[FUNC_COMPRESS + 8'h3c]	<= {PAD, OP_ADD, REG_F,  REG_E,  REG_ZO, 8'h00};	//F = E
		rom[FUNC_COMPRESS + 8'h3d]	<= {PAD, OP_ADD, REG_E,  REG_D,  REG_T0, 8'h00};	//E = D + temp1
		rom[FUNC_COMPRESS + 8'h3e]	<= {PAD, OP_ADD, REG_D,  REG_C,  REG_ZO, 8'h00};	//D = C
		rom[FUNC_COMPRESS + 8'h3f]	<= {PAD, OP_ADD, REG_C,  REG_B,  REG_ZO, 8'h00};	//C = B
		rom[FUNC_COMPRESS + 8'h40]	<= {PAD, OP_ADD, REG_B,  REG_A,  REG_ZO, 8'h00};	//B = A
		rom[FUNC_COMPRESS + 8'h41]	<= {PAD, OP_ADD, REG_A,  REG_T0, REG_T1, 8'h00};	//a = temp1 + temp2
		
		//Bump i and loop
		rom[FUNC_COMPRESS + 8'h42]	<= {PAD, OP_ADD, REG_T6, REG_T6, REG_T5, 8'h00};	//t6 ++
		tmp = FUNC_COMPRESS + 8'h20;
		rom[FUNC_COMPRESS + 8'h43]	<= {PAD, OP_BGT, REG_ZO, REG_T4, REG_T6, tmp[7:0]};	//if i < 64 go again
		
		//Compression is done, add the chunk to the current hash value
		rom[FUNC_COMPRESS + 8'h44]	<= {PAD, OP_ADD, REG_H0, REG_H0, REG_A,  8'h00};	//h0 += a
		rom[FUNC_COMPRESS + 8'h45]	<= {PAD, OP_ADD, REG_H1, REG_H1, REG_B,  8'h00};	//h1 += b
		rom[FUNC_COMPRESS + 8'h46]	<= {PAD, OP_ADD, REG_H2, REG_H2, REG_C,  8'h00};	//h2 += c
		rom[FUNC_COMPRESS + 8'h47]	<= {PAD, OP_ADD, REG_H3, REG_H3, REG_D,  8'h00};	//h3 += d
		rom[FUNC_COMPRESS + 8'h48]	<= {PAD, OP_ADD, REG_H4, REG_H4, REG_E,  8'h00};	//h4 += e
		rom[FUNC_COMPRESS + 8'h49]	<= {PAD, OP_ADD, REG_H5, REG_H5, REG_F,  8'h00};	//h5 += f
		rom[FUNC_COMPRESS + 8'h4a]	<= {PAD, OP_ADD, REG_H6, REG_H6, REG_G,  8'h00};	//h6 += g
		rom[FUNC_COMPRESS + 8'h4b]	<= {PAD, OP_ADD, REG_H7, REG_H7, REG_H,  8'h00};	//h7 += h
		
		//If this is the last chunk and we don't need more padding, stop
		rom[FUNC_COMPRESS + 8'h4c]	<= {PAD, OP_LWR, REG_T0, REG_ZO, REG_ZO, 8'h4e};	//t0 = 2
		tmp = FUNC_OUTPUT[7:0];
		rom[FUNC_COMPRESS + 8'h4d]	<= {PAD, OP_BGT, REG_ZO, REG_T7, REG_T0, tmp[7:0]};	//if fully padded
																						//output hash and halt

		//If we need more padding, jump back to do that
		rom[FUNC_COMPRESS + 8'h4e]	<= {PAD, OP_ADD, REG_T1, REG_ZO, REG_ZO, 8'h00};	//t1 = 0
		rom[FUNC_COMPRESS + 8'h4f]	<= {PAD, OP_LWR, REG_T5, REG_ZO, REG_ZO, 8'h4b};	//Reload FUNC_FINISH's expected
		rom[FUNC_COMPRESS + 8'h50]	<= {PAD, OP_LWR, REG_T0, REG_ZO, REG_ZO, 8'h48};	//constants, since we overwrote
		rom[FUNC_COMPRESS + 8'h51]	<= {PAD, OP_LWR,  REG_T6, REG_ZO, REG_ZO, 8'h4a};	//them
		
		tmp = FUNC_FINISH + 8'h0e;
		rom[FUNC_COMPRESS + 8'h52]	<= {PAD, OP_BGT, REG_ZO, REG_T7, REG_ZO, tmp[7:0]};	//if we still need more padding
																						//do that
		
		//Done, nothing more to do
		rom[FUNC_COMPRESS + 8'h53]	<= {PAD, OP_HLT, REG_ZO, REG_ZO, REG_ZO, 8'h00};	//halt
	
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//FUNC_OUTPUT: Output a completed hash and halt
		
		rom[FUNC_OUTPUT + 8'h00]	<= {PAD, OP_OUT, REG_ZO, REG_H0, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h01]	<= {PAD, OP_OUT, REG_ZO, REG_H1, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h02]	<= {PAD, OP_OUT, REG_ZO, REG_H2, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h03]	<= {PAD, OP_OUT, REG_ZO, REG_H3, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h04]	<= {PAD, OP_OUT, REG_ZO, REG_H4, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h05]	<= {PAD, OP_OUT, REG_ZO, REG_H5, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h06]	<= {PAD, OP_OUT, REG_ZO, REG_H6, REG_ZO, 8'h00};
		rom[FUNC_OUTPUT + 8'h07]	<= {PAD, OP_OUT, REG_ZO, REG_H7, REG_ZO, 8'h00};
		
		rom[FUNC_OUTPUT + 8'h08]	<= {PAD, OP_HLT, REG_ZO, REG_ZO, REG_ZO, 8'h00};	//halt
	
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//FUNC_INPUT: Append a 32-bit word to the current hash and compress if necessary
	
		rom[FUNC_INPUT + 8'h00]		<= {PAD, OP_SHR, REG_T0, REG_LN, REG_ZO, 8'h05};	//t0 = len in words
		rom[FUNC_INPUT + 8'h01]		<= {PAD, OP_LWR, REG_T1, REG_ZO, REG_ZO, 8'h48};	//t1 = 0f
		rom[FUNC_INPUT + 8'h02]		<= {PAD, OP_AND, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 = len in words mod 16

		rom[FUNC_INPUT + 8'h03]		<= {PAD, OP_SW,  REG_ZO, REG_IN, REG_T0, 8'h00};	//w[len] = din
		rom[FUNC_INPUT + 8'h04]		<= {PAD, OP_LWR, REG_T0, REG_ZO, REG_ZO, 8'h4f};	//t0 = 32
		rom[FUNC_INPUT + 8'h05]		<= {PAD, OP_ADD, REG_LN, REG_LN, REG_T0, 8'h00};	//len += 32 (bits)
		
		rom[FUNC_INPUT + 8'h06]		<= {PAD, OP_SHR, REG_T0, REG_LN, REG_ZO, 8'h05};	//t0 = len in words
		rom[FUNC_INPUT + 8'h07]		<= {PAD, OP_LWR, REG_T1, REG_ZO, REG_ZO, 8'h48};	//t1 = 0f
		rom[FUNC_INPUT + 8'h08]		<= {PAD, OP_NOT, REG_T0, REG_T0, REG_ZO, 8'h00};	//t0[3:0] = f if full
		rom[FUNC_INPUT + 8'h09]		<= {PAD, OP_AND, REG_T0, REG_T0, REG_T1, 8'h00};	//t0 = len & f
		rom[FUNC_INPUT + 8'h0a]		<= {PAD, OP_LWR, REG_T1, REG_ZO, REG_ZO, 8'h4b};	//t1 = 0e
		tmp = FUNC_COMPRESS;
		rom[FUNC_INPUT + 8'h0b]		<= {PAD, OP_BGT, REG_ZO, REG_T0, REG_T1, tmp[7:0]};	//compress this block
																						//if block is full
		
		rom[FUNC_INPUT + 8'h0c]		<= {PAD, OP_HLT, REG_ZO, REG_ZO, REG_ZO, 8'h00};	//halt
	
	end
	
	//ROM read logic
	reg			rom_rd_en		= 0;
	reg[8:0]	rom_rd_addr		= 0;
	reg[31:0]	rom_rd_data		= 0;
	reg[31:0]	rom_rd_data_ff	= 0;
	
	always @(posedge clk) begin
		if(rom_rd_en)
			rom_rd_data	<= rom[rom_rd_addr];
			
		rom_rd_data_ff	<= rom_rd_data;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multicycle microcode processor
	
	localparam STATE_IDLE		= 3'h0;
	localparam STATE_IFETCH		= 3'h1;
	localparam STATE_RFETCH		= 3'h2;
	localparam STATE_MFETCH		= 3'h3;
	localparam STATE_EXEC		= 3'h4;
	localparam STATE_WB			= 3'h5;
	
	reg[2:0]	microcode_state			= STATE_IDLE;
	reg[7:0]	microcode_pc			= 0;
	
	reg[2:0]	microcode_state_next	= STATE_IDLE;
	reg[7:0]	microcode_pc_next		= 0;
	
	reg[31:0]	current_insn			= 0;
	
	//Barrel shifter and rotator
	reg[63:0]	rotout					= 0;
	reg[31:0]	shout					= 0;
	always @(posedge clk) begin
		shout	<= regfile_porta_dout >> current_insn[4:0];
		rotout	<= {regfile_porta_dout, regfile_porta_dout} >> current_insn[4:0];
	end
	
	always @(*) begin
	
		//Instruction sequencing
		case(microcode_state)
			
			//Go to next instruction if executing
			STATE_EXEC: begin
				microcode_state_next	<= microcode_state;
						
				//Jump if requested
				if( (current_insn[26:23] == OP_BGT) && (regfile_porta_dout > regfile_portb_dout) )
					microcode_pc_next	<= current_insn[7:0];
					
				//No, execute next insn
				else
					microcode_pc_next	<= microcode_pc	+ 8'h1;
				
			end
		
			//Idle, see if we need to start executing
			STATE_IDLE: begin
			
				if(start_en) begin
					microcode_pc_next		<= FUNC_INIT[7:0];
					microcode_state_next	<= STATE_WB;
				end
				
				//Start? Execute FUNC_FINISH
				else if(finish_en) begin
					microcode_pc_next		<= FUNC_FINISH[7:0];
					microcode_state_next	<= STATE_WB;
				end

				//Append data
				else if(data_en) begin
					microcode_pc_next		<= FUNC_INPUT[7:0];
					microcode_state_next	<= STATE_WB;
				end
				
				//Hold, do nothing
				else begin
					microcode_state_next	<= microcode_state;
					microcode_pc_next		<= microcode_pc;
				end
				
			end
		
			//Hold, do nothing
			default: begin
				microcode_state_next	<= microcode_state;
				microcode_pc_next		<= microcode_pc;
			end
		endcase
		
		//Default to not reading ROM
		rom_rd_en				<= start_en || data_en || finish_en ||
									(microcode_state == STATE_MFETCH) ||
									(microcode_state == STATE_WB);
		rom_rd_addr				<= {1'b1, microcode_pc};
		
		//Default to not reading register file
		regfile_porta_en		<= 0;
		regfile_porta_wr		<= 0;
		regfile_porta_addr		<= 0;
		regfile_portb_en		<= 0;
		regfile_portb_addr		<= 0;
		
		//Default to reading from data memory 
		//(this lets us cut an opcode bit out of the muxes)
		regfile_porta_din		<= wmem_dout;
		
		//Default to not touching data memory
		wmem_en					<= 0;
		wmem_wr					<= 0;
		wmem_addr				<= regfile_portb_dout[5:0] - current_insn[5:0];
		wmem_din				<= regfile_porta_dout;
	
		//Default to not done
		done					<= 0;
		
		//Only output data if it's valid
		dout					<= 0;
		dout_valid				<= 0;
		
		case(microcode_state)
		
			//IDLE: Do nothing unless an enable flag is coming in
			STATE_IDLE: begin

				//Append data
				if(data_en) begin
					regfile_porta_addr		<= REG_IN;
					regfile_porta_en		<= 1;
					regfile_porta_wr		<= 1;
					regfile_porta_din		<= din;
				end

			end
			
			//IFETCH: Instruction fetch
			STATE_IFETCH: begin
				microcode_state_next		<= STATE_RFETCH;
			end
			
			//RFETCH: Dispatch register reads
			STATE_RFETCH: begin
			
				//Read registers
				regfile_porta_en			<= 1;
				regfile_porta_addr			<= rom_rd_data_ff[17:13];
				regfile_portb_en			<= 1;
				regfile_portb_addr			<= rom_rd_data_ff[12:8];
				
				//Always do mfetch cycle (even if not reading from ROM)
				//so that the barrel shifter has time to run
				microcode_state_next		<= STATE_MFETCH;
			end
			
			STATE_MFETCH: begin
				
				//Read ROM
				rom_rd_addr					<= rom_rd_data_ff[7:0] + regfile_portb_dout[7:0];
				rom_rd_addr[8]				<= 1'b0;
				
				//Read W memory
				wmem_en						<= 1;
				
				microcode_state_next		<= STATE_EXEC;
				
			end
			
			//STATE_EXEC: Execute stuff
			STATE_EXEC: begin
				
				microcode_state_next		<= STATE_WB;
				
				//Prepare to do writeback if needed
				regfile_porta_en	<= 1;
				regfile_porta_wr	<= 1;
				regfile_porta_addr	<= current_insn[22:18];
			
				case(current_insn[26:23])
				
					//Read data memory
					OP_LW: 		regfile_porta_din			<= wmem_dout;
					
					//Write data memory
					OP_SW: begin
						regfile_porta_wr			<= 0;
						wmem_en						<= 1;
						wmem_wr						<= 1;
					end
				
					OP_ROR:		regfile_porta_din	<= rotout[31:0];
					OP_SHR:		regfile_porta_din	<= shout;
					OP_XOR: 	regfile_porta_din	<= regfile_porta_dout ^ regfile_portb_dout;
					OP_ADD: 	regfile_porta_din	<= regfile_porta_dout + regfile_portb_dout;
					OP_AND: 	regfile_porta_din	<= regfile_porta_dout & regfile_portb_dout;
					OP_NOT: 	regfile_porta_din	<= ~regfile_porta_dout;
					OP_LWR: 	regfile_porta_din	<= rom_rd_data;
					
					//Conditional halt if 8-bit quantities are equal
					OP_HLT: begin
						regfile_porta_en			<= 0;
						if(regfile_porta_dout[7:0] == current_insn[7:0]) begin
							microcode_state_next	<= STATE_IDLE;
							done					<= 1;
						end
					end
					
					//Output data
					OP_OUT: begin
						dout_valid				<= 1;
						dout					<= regfile_porta_dout;
						regfile_porta_wr		<= 0;
					end
					
					//Do nothing, maybe jump
					OP_BGT: begin
						regfile_porta_wr	<= 0;
					end
					
					//do nothing
					default: begin
						regfile_porta_wr	<= 0;
					end
				
				endcase
				
			end
			
			//Writeback
			STATE_WB: begin
			
				//Issue the instruction fetch
				rom_rd_en					<= 1;
				rom_rd_addr					<= {1'b1, microcode_pc};
				
				microcode_state_next		<= STATE_IFETCH;
				
			end
			
		endcase
		
	end
	
	always @(posedge clk) begin
		
		//Register combinatorial stuff to save state
		microcode_state	<= microcode_state_next;
		microcode_pc	<= microcode_pc_next;
		
		//If we just finished reading the instruction, save it
		if(microcode_state == STATE_RFETCH)
			current_insn	<= rom_rd_data;
		
	end
	
	//Debug logs
	always @(posedge clk) begin
	
		if(rom_rd_en && (microcode_state == STATE_WB) ) begin
			/*
			if(rom_rd_addr == FUNC_INIT)
				$display("FUNC_INIT");
			if(rom_rd_addr == FUNC_INPUT)
				$display("FUNC_INPUT");
			if(rom_rd_addr == FUNC_FINISH)
				$display("FUNC_FINISH");
			if(rom_rd_addr == FUNC_COMPRESS)
				$display("FUNC_COMPRESS");
			*/
			/*if(rom_rd_en && (rom_rd_addr == (FUNC_COMPRESS + 8'h20)))
				$display("FUNC_COMPRESS round loop");*/
			
		end
		/*
		if(microcode_state == STATE_EXEC) begin
			if(current_insn[26:23] == OP_BGT)
				$display("BGT: %x, %x", regfile_porta_dout, regfile_portb_dout);
		end
		
		if(wmem_en && wmem_wr)
			$display("Writing %x to w[%d]", wmem_din, wmem_addr);
		
		if(regfile_porta_en && regfile_porta_wr) begin
			if(regfile_porta_addr == REG_LN)
				$display("Writing %d to i (REG_LN)", regfile_porta_din);
			if(regfile_porta_addr == REG_T0)
				$display("Writing %x to REG_T0", regfile_porta_din);
			if(regfile_porta_addr == REG_T6)
				$display("Writing %d to i (REG_T6)", regfile_porta_din);

			if( (regfile_porta_addr >= REG_H0) && (regfile_porta_addr <= REG_H7) )
				$display("Writing %x to reg H%d", regfile_porta_din, regfile_porta_addr - REG_H0);
		end
		*/
		
	end
	
endmodule
