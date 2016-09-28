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
	@brief CRC-16 (derived from easics.be generator)
	
	Original license:
	
	Copyright (C) 1999-2008 Easics NV.
	 This source file may be used and distributed without restriction
	 provided that this copyright statement is not removed from the file
	 and that any derivative work contains the original copyright notice
	 and the associated disclaimer.
	
	 THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS
	 OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
	 WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
	
	 Purpose : synthesizable CRC function
	   * polynomial: (0 2 15 16)
	   * data width: 64
	
	 Info : tools@easics.be
	        http://www.easics.com
 */
module CRC16Hasher(clk, clear, din, crc);

	input wire			clk;
	input wire[63:0]	din;
	input wire			clear;
	output reg[15:0]	crc = 0;

	//alias for more concise code
	wire[63:0] d = din;
	
	wire[15:0] c = clear ? 0 : crc;

	always @(posedge clk) begin
	
		if(clear)
			crc	<= 0;
	
		crc[0]  <= d[63] ^ d[62] ^ d[61] ^ d[60] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[49] ^ d[48] ^ d[47] ^ d[46] ^ d[45] ^ d[43] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[34] ^ d[33] ^ d[32] ^ d[31] ^ d[30] ^ d[27] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[19] ^ d[18] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[12] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[2] ^ c[3] ^ c[4] ^ c[5] ^ c[6] ^ c[7] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
		crc[1]  <= d[63] ^ d[62] ^ d[61] ^ d[56] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[49] ^ d[48] ^ d[47] ^ d[46] ^ d[44] ^ d[42] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[34] ^ d[33] ^ d[32] ^ d[31] ^ d[28] ^ d[27] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[19] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[13] ^ d[12] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ c[0] ^ c[1] ^ c[2] ^ c[3] ^ c[4] ^ c[5] ^ c[6] ^ c[7] ^ c[8] ^ c[13] ^ c[14] ^ c[15];
		crc[2]  <= d[61] ^ d[60] ^ d[57] ^ d[56] ^ d[46] ^ d[42] ^ d[31] ^ d[30] ^ d[29] ^ d[28] ^ d[16] ^ d[14] ^ d[1] ^ d[0] ^ c[8] ^ c[9] ^ c[12] ^ c[13];
		crc[3]  <= d[62] ^ d[61] ^ d[58] ^ d[57] ^ d[47] ^ d[43] ^ d[32] ^ d[31] ^ d[30] ^ d[29] ^ d[17] ^ d[15] ^ d[2] ^ d[1] ^ c[9] ^ c[10] ^ c[13] ^ c[14];
		crc[4]  <= d[63] ^ d[62] ^ d[59] ^ d[58] ^ d[48] ^ d[44] ^ d[33] ^ d[32] ^ d[31] ^ d[30] ^ d[18] ^ d[16] ^ d[3] ^ d[2] ^ c[0] ^ c[10] ^ c[11] ^ c[14] ^ c[15];
		crc[5]  <= d[63] ^ d[60] ^ d[59] ^ d[49] ^ d[45] ^ d[34] ^ d[33] ^ d[32] ^ d[31] ^ d[19] ^ d[17] ^ d[4] ^ d[3] ^ c[1] ^ c[11] ^ c[12] ^ c[15];
		crc[6]  <= d[61] ^ d[60] ^ d[50] ^ d[46] ^ d[35] ^ d[34] ^ d[33] ^ d[32] ^ d[20] ^ d[18] ^ d[5] ^ d[4] ^ c[2] ^ c[12] ^ c[13];
		crc[7]  <= d[62] ^ d[61] ^ d[51] ^ d[47] ^ d[36] ^ d[35] ^ d[34] ^ d[33] ^ d[21] ^ d[19] ^ d[6] ^ d[5] ^ c[3] ^ c[13] ^ c[14];
		crc[8]  <= d[63] ^ d[62] ^ d[52] ^ d[48] ^ d[37] ^ d[36] ^ d[35] ^ d[34] ^ d[22] ^ d[20] ^ d[7] ^ d[6] ^ c[0] ^ c[4] ^ c[14] ^ c[15];
		crc[9]  <= d[63] ^ d[53] ^ d[49] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[23] ^ d[21] ^ d[8] ^ d[7] ^ c[1] ^ c[5] ^ c[15];
		crc[10] <= d[54] ^ d[50] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[24] ^ d[22] ^ d[9] ^ d[8] ^ c[2] ^ c[6];
		crc[11] <= d[55] ^ d[51] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[25] ^ d[23] ^ d[10] ^ d[9] ^ c[3] ^ c[7];
		crc[12] <= d[56] ^ d[52] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[26] ^ d[24] ^ d[11] ^ d[10] ^ c[4] ^ c[8];
		crc[13] <= d[57] ^ d[53] ^ d[42] ^ d[41] ^ d[40] ^ d[39] ^ d[27] ^ d[25] ^ d[12] ^ d[11] ^ c[5] ^ c[9];
		crc[14] <= d[58] ^ d[54] ^ d[43] ^ d[42] ^ d[41] ^ d[40] ^ d[28] ^ d[26] ^ d[13] ^ d[12] ^ c[6] ^ c[10];
		crc[15] <= d[63] ^ d[62] ^ d[61] ^ d[60] ^ d[59] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[49] ^ d[48] ^ d[47] ^ d[46] ^ d[45] ^ d[44] ^ d[42] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[34] ^ d[33] ^ d[32] ^ d[31] ^ d[30] ^ d[29] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[19] ^ d[18] ^ d[17] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[4] ^ d[3] ^ d[2] ^ d[1] ^ d[0] ^ c[0] ^ c[1] ^ c[2] ^ c[3] ^ c[4] ^ c[5] ^ c[6] ^ c[11] ^ c[12] ^ c[13] ^ c[14] ^ c[15];
	end

endmodule
