`default_nettype none
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
	@brief A clock buffer
 */
module ClockBuffer(clkin, ce, clkout);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	parameter TYPE = "LOCAL";	//Set to LOCAL or GLOBAL
								//LOCAL is a hint and may not always be possible
	parameter CE = "YES";		//Set to YES or NO
								//If NO, ce input is ignored and clock is always enabled
								//Tying ce to 1'b1 is recommended for code readability
	
	input wire	clkin;
	input wire	ce;
	output wire	clkout;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual primitive

	generate
	
		//Local clock (one region of the device)
		if(TYPE == "LOCAL") begin
		
			//For Xilinx Spartan-6 or 7 series: Use a BUFH (TODO: Support other FPGAs)
			if(CE == "NO")
				BUFH clk_buf(.I(clkin), .O(clkout));
			
			//If we have a clock enable, we have to use a BUFG for Spartan-6 since it lacks BUFHCE
			else if(CE == "YES") begin
				`ifdef XILINX_SPARTAN6
					BUFGCE clk_buf(.I(clkin), .O(clkout), .CE(ce));
					initial begin
						$display("WARNING: Using BUFGCE instead of BUFHCE for ClockBuffer TYPE=\"LOCAL\", CE=\"YES\" since S6 has no BUFHCE");
					end
				`else
					BUFHCE clk_buf(.I(clkin), .O(clkout), .CE(ce));
				`endif
			end
			
			//Parameter error
			else begin
				initial begin
					$display("ERROR: ClockBuffer CE argument must be \"YES\" or \"NO\"");
					$finish;
				end
			end
		
		end
		
		//Global clock (entire device)
		else if(TYPE == "GLOBAL") begin
		
			//For Xilinx Spartan-6 or 7 series: Use a BUFG (TODO: Support other FPGAs)
			if(CE == "NO")
				BUFG clk_buf(.I(clkin), .O(clkout));
			
			//Use a BUFG for all Xilinx FPGAs
			else if(CE == "YES") begin
				BUFGCE clk_buf(.I(clkin), .O(clkout), .CE(ce));
			end
			
			//Parameter error
			else begin
				initial begin
					$display("ERROR: ClockBuffer CE argument must be \"YES\" or \"NO\"");
					$finish;
				end
			end
		
		end
		
		//Parameter error
		else begin
			initial begin
				$display("ERROR: ClockBuffer TYPE argument must be \"GLOBAL\" or \"LOCAL\"");
				$finish;
			end
		end
		
	endgenerate
	
endmodule

