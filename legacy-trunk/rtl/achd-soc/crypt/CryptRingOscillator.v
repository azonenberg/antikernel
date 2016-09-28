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
	@brief Ring oscillator for cryptographic applications
 */
module CryptRingOscillator(reset, clkout);
	
	input wire reset;
	(* S = "yes" *) output wire clkout;

	//Inverter stage
	(* S = "yes" *) wire dout0;
	(* S = "yes" *) (* RLOC = "X0Y0" *) LUT2 #(.INIT(2'b0001)) nor0 (.O(dout0),  .I0(clkout), .I1(reset) );

	//Buffer stages	
	(* S = "yes" *) wire dout1;
	(* S = "yes" *) wire dout2;
	(* S = "yes" *) wire dout3;
	
	(* S = "yes" *) (* RLOC = "X0Y0" *) LUT1 #(.INIT(2'b10)) buf1( .O(dout1),  .I0(dout0)  );
	(* S = "yes" *) (* RLOC = "X0Y0" *) LUT1 #(.INIT(2'b10)) buf2( .O(dout2),  .I0(dout1)  );
	(* S = "yes" *) (* RLOC = "X0Y0" *) LUT1 #(.INIT(2'b10)) buf3( .O(dout3),  .I0(dout2)  );
	(* S = "yes" *) (* RLOC = "X1Y0" *) LUT1 #(.INIT(2'b10)) buf4( .O(clkout),  .I0(dout3)  );

endmodule
