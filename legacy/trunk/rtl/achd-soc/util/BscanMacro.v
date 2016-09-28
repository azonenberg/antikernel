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
	@brief Boundary scan wrapper for a JTAG user instruction
	
	Wrapper for BSCAN_SPARTAN6, BSCANE2, etc.
	
	Does not currently support Spartan-3A.
 */
module BscanMacro(

	//Indicates this JTAG instruction is loaded in the IR
	instruction_active,
	
	//One-hot state values (note that in SHIFT-IR etc all are deasserted)
	state_capture_dr,
	state_reset,
	state_runtest,
	state_shift_dr,
	state_update_dr,
	
	//JTAG nets
	tck, tck_gated,
	tms,
	tdi,
	tdo		//ignored if this instruction isn't loaded	
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O / parameter declarations
	
	parameter USER_INSTRUCTION = 1;
	
	output wire instruction_active;
	output wire tck;
	output wire state_capture_dr;
	output wire state_reset;
	output wire state_runtest;
	output wire state_shift_dr;
	output wire state_update_dr;
	output wire tck_gated;
	output wire tms;
	output wire tdi;
	input wire tdo;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual primitive
	
	`ifdef XILINX_SPARTAN6
		BSCAN_SPARTAN6 #(
			.JTAG_CHAIN(USER_INSTRUCTION)
		)
		user_bscan (
			.SEL(instruction_active),
			.TCK(tck),
			.CAPTURE(state_capture_dr),
			.RESET(state_reset),
			.RUNTEST(state_runtest),
			.SHIFT(state_shift_dr),
			.UPDATE(state_update_dr),
			.DRCK(tck_gated),
			.TMS(tms),
			.TDI(tdi),
			.TDO(tdo)
		);

	`endif
	
	`ifdef XILINX_7SERIES
		BSCANE2 #(
			.JTAG_CHAIN(USER_INSTRUCTION)
		)
		user_bscan (
			.SEL(instruction_active),
			.TCK(tck),
			.CAPTURE(state_capture_dr),
			.RESET(state_reset),
			.RUNTEST(state_runtest),
			.SHIFT(state_shift_dr),
			.UPDATE(state_update_dr),
			.DRCK(tck_gated),
			.TMS(tms),
			.TDI(tdi),
			.TDO(tdo)
		);
	`endif

endmodule

