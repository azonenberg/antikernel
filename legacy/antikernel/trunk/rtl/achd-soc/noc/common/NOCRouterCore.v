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
	@brief Core routing algorithm for NoC routers
 */
module NOCRouterCore(
	tx_en, tx_data,
	portnum
    );

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire tx_en;
	input wire[31:0] tx_data;
	
	output reg[2:0] portnum = 0;
		
	/*
		This is NOT like a typical IP subnet mask - the mask specifies the bits to be checked when
		making routing decisions. This means that for a /8 subnet the masks would look something like
		FC00 (subnet) and 0300 (host).
		
		TODO: allow a single CIDR-style input and auto-compute the rest of these values at
		compile time?
	 */
	parameter SUBNET_MASK = 16'hFFFC;	//default to /14 subnet
	parameter SUBNET_ADDR = 16'h8000;	//first valid subnet address
	parameter HOST_BIT_HIGH = 1;			//host bits
	localparam HOST_BIT_LOW = HOST_BIT_HIGH - 1;

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Main routing logic
	
	//Combinatorial forwarding
	always @(tx_en, tx_data) begin
		
		portnum <= 0;
		
		//tx_en asserted? Load new address
		//TODO: only do this on first tx_en rising edge
		if(tx_en) begin
			if((tx_data & SUBNET_MASK) == SUBNET_ADDR)
				portnum <= tx_data[HOST_BIT_HIGH:HOST_BIT_LOW];
			else
				portnum <= 4;
		end
		
	end


endmodule
