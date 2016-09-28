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
	@brief Ethernet CRC-32 (derived from easics.be generator)
	
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
	   * polynomial: (0 1 2 4 5 7 8 10 11 12 16 22 23 26 32)
	   * data width: 16
	
	 Info : tools@easics.be
	        http://www.easics.com
 */
module EthernetCRC32_x16(clk, reset, update, din, crc_flipped, crc_x8_flipped);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk;
	input wire reset;
	
	input wire update;
	input wire[15:0] din;
	
	reg[31:0] crc = 0;
	reg[31:0] crc_x8 = 0;
	
	output wire[31:0] crc_flipped;
	output wire[31:0] crc_x8_flipped;
	
	wire[31:0] crc_not = ~crc;
	wire[31:0] crc_x8_not = ~crc_x8;
	assign crc_flipped =
	{
		crc_not[24], crc_not[25], crc_not[26], crc_not[27],
		crc_not[28], crc_not[29], crc_not[30], crc_not[31],
		
		crc_not[16], crc_not[17], crc_not[18], crc_not[19],
		crc_not[20], crc_not[21], crc_not[22], crc_not[23],
	
		crc_not[8], crc_not[9], crc_not[10], crc_not[11],
		crc_not[12], crc_not[13], crc_not[14], crc_not[15],
		
		crc_not[0], crc_not[1], crc_not[2], crc_not[3],
		crc_not[4], crc_not[5], crc_not[6], crc_not[7]		
	};
	
	assign crc_x8_flipped =
	{
		crc_x8_not[24], crc_x8_not[25], crc_x8_not[26], crc_x8_not[27],
		crc_x8_not[28], crc_x8_not[29], crc_x8_not[30], crc_x8_not[31],
		
		crc_x8_not[16], crc_x8_not[17], crc_x8_not[18], crc_x8_not[19],
		crc_x8_not[20], crc_x8_not[21], crc_x8_not[22], crc_x8_not[23],
	
		crc_x8_not[8], crc_x8_not[9], crc_x8_not[10], crc_x8_not[11],
		crc_x8_not[12], crc_x8_not[13], crc_x8_not[14], crc_x8_not[15],
		
		crc_x8_not[0], crc_x8_not[1], crc_x8_not[2], crc_x8_not[3],
		crc_x8_not[4], crc_x8_not[5], crc_x8_not[6], crc_x8_not[7]		
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual CRC function
	
	wire[15:0] din_flipped = 
	{
		din[8], din[9], din[10], din[11],
		din[12], din[13], din[14], din[15],
		din[0], din[1], din[2], din[3],
		din[4], din[5], din[6], din[7]
	};
	
	always @(posedge clk) begin
		if(reset)
			crc <= 'hffffffff;
		if(update) begin
			crc[0] <= din_flipped[12] ^ din_flipped[10] ^ din_flipped[9] ^ din_flipped[6] ^ din_flipped[0] ^ crc[16] ^ crc[22] ^ crc[25] ^ crc[26] ^ crc[28];
			crc[1] <= din_flipped[13] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[1] ^ din_flipped[0] ^ crc[16] ^ crc[17] ^ crc[22] ^ crc[23] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29];
			crc[2] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[9] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[2] ^ din_flipped[1] ^ din_flipped[0] ^ crc[16] ^ crc[17] ^ crc[18] ^ crc[22] ^ crc[23] ^ crc[24] ^ crc[25] ^ crc[29] ^ crc[30];
			crc[3] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[10] ^ din_flipped[9] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[3] ^ din_flipped[2] ^ din_flipped[1] ^ crc[17] ^ crc[18] ^ crc[19] ^ crc[23] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31];
			crc[4] <= din_flipped[15] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[8] ^ din_flipped[6] ^ din_flipped[4] ^ din_flipped[3] ^ din_flipped[2] ^ din_flipped[0] ^ crc[16] ^ crc[18] ^ crc[19] ^ crc[20] ^ crc[22] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[31];
			crc[5] <= din_flipped[13] ^ din_flipped[10] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[3] ^ din_flipped[1] ^ din_flipped[0] ^ crc[16] ^ crc[17] ^ crc[19] ^ crc[20] ^ crc[21] ^ crc[22] ^ crc[23] ^ crc[26] ^ crc[29];
			crc[6] <= din_flipped[14] ^ din_flipped[11] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[2] ^ din_flipped[1] ^ crc[17] ^ crc[18] ^ crc[20] ^ crc[21] ^ crc[22] ^ crc[23] ^ crc[24] ^ crc[27] ^ crc[30];
			crc[7] <= din_flipped[15] ^ din_flipped[10] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[5] ^ din_flipped[3] ^ din_flipped[2] ^ din_flipped[0] ^ crc[16] ^ crc[18] ^ crc[19] ^ crc[21] ^ crc[23] ^ crc[24] ^ crc[26] ^ crc[31];
			crc[8] <= din_flipped[12] ^ din_flipped[11] ^ din_flipped[10] ^ din_flipped[8] ^ din_flipped[4] ^ din_flipped[3] ^ din_flipped[1] ^ din_flipped[0] ^ crc[16] ^ crc[17] ^ crc[19] ^ crc[20] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[28];
			crc[9] <= din_flipped[13] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[2] ^ din_flipped[1] ^ crc[17] ^ crc[18] ^ crc[20] ^ crc[21] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29];
			crc[10] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[9] ^ din_flipped[5] ^ din_flipped[3] ^ din_flipped[2] ^ din_flipped[0] ^ crc[16] ^ crc[18] ^ crc[19] ^ crc[21] ^ crc[25] ^ crc[29] ^ crc[30];
			crc[11] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[12] ^ din_flipped[9] ^ din_flipped[4] ^ din_flipped[3] ^ din_flipped[1] ^ din_flipped[0] ^ crc[16] ^ crc[17] ^ crc[19] ^ crc[20] ^ crc[25] ^ crc[28] ^ crc[30] ^ crc[31];
			crc[12] <= din_flipped[15] ^ din_flipped[13] ^ din_flipped[12] ^ din_flipped[9] ^ din_flipped[6] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[2] ^ din_flipped[1] ^ din_flipped[0] ^ crc[16] ^ crc[17] ^ crc[18] ^ crc[20] ^ crc[21] ^ crc[22] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31];
			crc[13] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[10] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[5] ^ din_flipped[3] ^ din_flipped[2] ^ din_flipped[1] ^ crc[17] ^ crc[18] ^ crc[19] ^ crc[21] ^ crc[22] ^ crc[23] ^ crc[26] ^ crc[29] ^ crc[30];
			crc[14] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[11] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[4] ^ din_flipped[3] ^ din_flipped[2] ^ crc[18] ^ crc[19] ^ crc[20] ^ crc[22] ^ crc[23] ^ crc[24] ^ crc[27] ^ crc[30] ^ crc[31];
			crc[15] <= din_flipped[15] ^ din_flipped[12] ^ din_flipped[9] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[3] ^ crc[19] ^ crc[20] ^ crc[21] ^ crc[23] ^ crc[24] ^ crc[25] ^ crc[28] ^ crc[31];
			crc[16] <= din_flipped[13] ^ din_flipped[12] ^ din_flipped[8] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[0] ^ crc[0] ^ crc[16] ^ crc[20] ^ crc[21] ^ crc[24] ^ crc[28] ^ crc[29];
			crc[17] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[9] ^ din_flipped[6] ^ din_flipped[5] ^ din_flipped[1] ^ crc[1] ^ crc[17] ^ crc[21] ^ crc[22] ^ crc[25] ^ crc[29] ^ crc[30];
			crc[18] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[10] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[2] ^ crc[2] ^ crc[18] ^ crc[22] ^ crc[23] ^ crc[26] ^ crc[30] ^ crc[31];
			crc[19] <= din_flipped[15] ^ din_flipped[11] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[3] ^ crc[3] ^ crc[19] ^ crc[23] ^ crc[24] ^ crc[27] ^ crc[31];
			crc[20] <= din_flipped[12] ^ din_flipped[9] ^ din_flipped[8] ^ din_flipped[4] ^ crc[4] ^ crc[20] ^ crc[24] ^ crc[25] ^ crc[28];
			crc[21] <= din_flipped[13] ^ din_flipped[10] ^ din_flipped[9] ^ din_flipped[5] ^ crc[5] ^ crc[21] ^ crc[25] ^ crc[26] ^ crc[29];
			crc[22] <= din_flipped[14] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[0] ^ crc[6] ^ crc[16] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[30];
			crc[23] <= din_flipped[15] ^ din_flipped[13] ^ din_flipped[9] ^ din_flipped[6] ^ din_flipped[1] ^ din_flipped[0] ^ crc[7] ^ crc[16] ^ crc[17] ^ crc[22] ^ crc[25] ^ crc[29] ^ crc[31];
			crc[24] <= din_flipped[14] ^ din_flipped[10] ^ din_flipped[7] ^ din_flipped[2] ^ din_flipped[1] ^ crc[8] ^ crc[17] ^ crc[18] ^ crc[23] ^ crc[26] ^ crc[30];
			crc[25] <= din_flipped[15] ^ din_flipped[11] ^ din_flipped[8] ^ din_flipped[3] ^ din_flipped[2] ^ crc[9] ^ crc[18] ^ crc[19] ^ crc[24] ^ crc[27] ^ crc[31];
			crc[26] <= din_flipped[10] ^ din_flipped[6] ^ din_flipped[4] ^ din_flipped[3] ^ din_flipped[0] ^ crc[10] ^ crc[16] ^ crc[19] ^ crc[20] ^ crc[22] ^ crc[26];
			crc[27] <= din_flipped[11] ^ din_flipped[7] ^ din_flipped[5] ^ din_flipped[4] ^ din_flipped[1] ^ crc[11] ^ crc[17] ^ crc[20] ^ crc[21] ^ crc[23] ^ crc[27];
			crc[28] <= din_flipped[12] ^ din_flipped[8] ^ din_flipped[6] ^ din_flipped[5] ^ din_flipped[2] ^ crc[12] ^ crc[18] ^ crc[21] ^ crc[22] ^ crc[24] ^ crc[28];
			crc[29] <= din_flipped[13] ^ din_flipped[9] ^ din_flipped[7] ^ din_flipped[6] ^ din_flipped[3] ^ crc[13] ^ crc[19] ^ crc[22] ^ crc[23] ^ crc[25] ^ crc[29];
			crc[30] <= din_flipped[14] ^ din_flipped[10] ^ din_flipped[8] ^ din_flipped[7] ^ din_flipped[4] ^ crc[14] ^ crc[20] ^ crc[23] ^ crc[24] ^ crc[26] ^ crc[30];
			crc[31] <= din_flipped[15] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[8] ^ din_flipped[5] ^ crc[15] ^ crc[21] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[31];

			crc_x8[0] <= din_flipped[14] ^ din_flipped[8] ^ crc[24] ^ crc[30];
			crc_x8[1] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[9] ^ din_flipped[8] ^ crc[24] ^ crc[25] ^ crc[30] ^ crc[31];
			crc_x8[2] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[10] ^ din_flipped[9] ^ din_flipped[8] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31];
			crc_x8[3] <= din_flipped[15] ^ din_flipped[11] ^ din_flipped[10] ^ din_flipped[9] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[31];
			crc_x8[4] <= din_flipped[14] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[10] ^ din_flipped[8] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30];
			crc_x8[5] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[13] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[8] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
			crc_x8[6] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[13] ^ din_flipped[12] ^ din_flipped[10] ^ din_flipped[9] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31];
			crc_x8[7] <= din_flipped[15] ^ din_flipped[13] ^ din_flipped[11] ^ din_flipped[10] ^ din_flipped[8] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31];
			crc_x8[8] <= din_flipped[12] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[8] ^ crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
			crc_x8[9] <= din_flipped[13] ^ din_flipped[12] ^ din_flipped[10] ^ din_flipped[9] ^ crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29];
			crc_x8[10] <= din_flipped[13] ^ din_flipped[11] ^ din_flipped[10] ^ din_flipped[8] ^ crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29];
			crc_x8[11] <= din_flipped[12] ^ din_flipped[11] ^ din_flipped[9] ^ din_flipped[8] ^ crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28];
			crc_x8[12] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[12] ^ din_flipped[10] ^ din_flipped[9] ^ din_flipped[8] ^ crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30];
			crc_x8[13] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[13] ^ din_flipped[11] ^ din_flipped[10] ^ din_flipped[9] ^ crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31];
			crc_x8[14] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[10] ^ crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31];
			crc_x8[15] <= din_flipped[15] ^ din_flipped[13] ^ din_flipped[12] ^ din_flipped[11] ^ crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31];
			crc_x8[16] <= din_flipped[13] ^ din_flipped[12] ^ din_flipped[8] ^ crc[8] ^ crc[24] ^ crc[28] ^ crc[29];
			crc_x8[17] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[9] ^ crc[9] ^ crc[25] ^ crc[29] ^ crc[30];
			crc_x8[18] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[10] ^ crc[10] ^ crc[26] ^ crc[30] ^ crc[31];
			crc_x8[19] <= din_flipped[15] ^ din_flipped[11] ^ crc[11] ^ crc[27] ^ crc[31];
			crc_x8[20] <= din_flipped[12] ^ crc[12] ^ crc[28];
			crc_x8[21] <= din_flipped[13] ^ crc[13] ^ crc[29];
			crc_x8[22] <= din_flipped[8] ^ crc[14] ^ crc[24];
			crc_x8[23] <= din_flipped[14] ^ din_flipped[9] ^ din_flipped[8] ^ crc[15] ^ crc[24] ^ crc[25] ^ crc[30];
			crc_x8[24] <= din_flipped[15] ^ din_flipped[10] ^ din_flipped[9] ^ crc[16] ^ crc[25] ^ crc[26] ^ crc[31];
			crc_x8[25] <= din_flipped[11] ^ din_flipped[10] ^ crc[17] ^ crc[26] ^ crc[27];
			crc_x8[26] <= din_flipped[14] ^ din_flipped[12] ^ din_flipped[11] ^ din_flipped[8] ^ crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30];
			crc_x8[27] <= din_flipped[15] ^ din_flipped[13] ^ din_flipped[12] ^ din_flipped[9] ^ crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31];
			crc_x8[28] <= din_flipped[14] ^ din_flipped[13] ^ din_flipped[10] ^ crc[20] ^ crc[26] ^ crc[29] ^ crc[30];
			crc_x8[29] <= din_flipped[15] ^ din_flipped[14] ^ din_flipped[11] ^ crc[21] ^ crc[27] ^ crc[30] ^ crc[31];
			crc_x8[30] <= din_flipped[15] ^ din_flipped[12] ^ crc[22] ^ crc[28] ^ crc[31];
			crc_x8[31] <= din_flipped[13] ^ crc[23] ^ crc[29];
		end
		
	end

endmodule
