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
	@brief 8b/10b disparity table (computes current disparity, not running total)
 */
module DisparityCalculator8b10b(isk, din, disp);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire		isk;
	input wire[7:0]	din;
	output reg		disp	= 0;	//true = flip, false = preserve

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// K-character ROM
	
	reg kdisp = 0;
	
	always @(*) begin
		
		//invalid k-character? leave at 0
		kdisp	<= 0;
		
		case(din)
			8'h1c:	kdisp	<= 0;	//K28.0
			8'h3c:	kdisp	<= 1;	//K28.1
			8'h5c:	kdisp	<= 1;	//K28.2
			8'h7c:	kdisp	<= 1;	//K28.3
			8'h9c:	kdisp	<= 0;	//K28.4
			8'hbc:	kdisp	<= 1;	//K28.5
			8'hdc:	kdisp	<= 1;	//K28.6
			8'hfc:	kdisp	<= 0;	//K28.7
			8'hf7:	kdisp	<= 0;	//K23.7
			8'hfb:	kdisp	<= 0;	//K27.7
			8'hfd:	kdisp	<= 0;	//K29.7
			8'hfe:	kdisp	<= 0;	//K30.7
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// D-character ROMs
	
	reg ddisp = 0;
	
	reg dhi = 0;
	reg dlo = 0;
	
	always @(*) begin
	
		//3b/4b code (D0.x)
		case(din[7:5])
			0:	dhi <= 1;
			1:	dhi <= 0;
			2:	dhi <= 0;
			3:	dhi <= 1;
			4:	dhi <= 1;
			5:	dhi <= 0;
			6:	dhi <= 0;
			7:	dhi <= 1;
		endcase
		
		//5b/6b code (Dx)
		case(din[4:0])
			0:	dlo	<= 1;
			1:	dlo	<= 1;
			2:	dlo	<= 1;
			3:	dlo	<= 0;
			4:	dlo	<= 1;
			5:	dlo	<= 0;
			6:	dlo	<= 0;
			7:	dlo	<= 1;
			8:	dlo	<= 1;
			9:	dlo	<= 0;
			10:	dlo	<= 0;
			11:	dlo	<= 0;
			12:	dlo	<= 0;
			13:	dlo	<= 0;
			14:	dlo	<= 0;
			15:	dlo	<= 1;
			16:	dlo	<= 1;
			17:	dlo	<= 0;
			18:	dlo	<= 0;
			19:	dlo	<= 0;
			20:	dlo	<= 0;
			21:	dlo	<= 0;
			22:	dlo	<= 0;
			23:	dlo	<= 1;
			24:	dlo	<= 1;
			25:	dlo	<= 0;
			26:	dlo	<= 0;
			27:	dlo	<= 1;
			28:	dlo	<= 0;
			29:	dlo	<= 1;
			30:	dlo	<= 1;
			31:	dlo	<= 0;
		endcase
		
		//Final disparity is xor of the two halves
		ddisp	<= dhi ^ dlo;
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Output mux
	
	always @(*) begin
		if(isk)
			disp	<= kdisp;
		else
			disp	<= ddisp;
	end

endmodule
 
