`timescale 1ns / 1ps
`default_nettype none
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
	@brief Trigger logic for RED TIN
 */
module RedTinLogicAnalyzer_trigger(
	capture_clk, din_buf2, din_buf3,
	
	reset,
	reconfig_clk, reconfig_din, reconfig_ce, reconfig_finish,
	
	trigger
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Capture data width (must be a multiple of 64)
	parameter 					DATA_WIDTH = 128;

	//Capturing
	input wire					capture_clk;
	input wire[DATA_WIDTH-1:0]	din_buf2;
	input wire[DATA_WIDTH-1:0]	din_buf3;

	//Reconfiguration data for loading trigger settings
	input wire					reset;
	input wire 					reconfig_clk;	
	input wire[31:0]			reconfig_din;
	input wire					reconfig_ce;
	input wire					reconfig_finish;
	
	//Trigger output
	output reg					trigger = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Trigger logic

	/*
		DATA_WIDTH channels packed into DATA_WIDTH/2 LUTs (two bits for each).
		Configuration is done in 32 columns of LUTs, so 64 bits for one row of LUTs.
		
		Only the low 16 bits of each LUT are meaningful; 16 "don't care" bits must be clocked
		into the high half.
		
		LUTs are loaded MSB first.
	 */
	 
	localparam TRIGGER_ROWS = DATA_WIDTH / 64;
	
	//Raw output of each trigger LUT
	//Need to transpose for AND reduction
	wire[TRIGGER_ROWS-1:0] trigger_out_raw[31:0];
	
	//Shift register output of each trigger LUT
	wire[31:0] trigger_shout[TRIGGER_ROWS-1 : 0];
	
	//Shift register input of each trigger LUT
	wire[31:0] trigger_shin[TRIGGER_ROWS-1 : 0];
	
	//Temporary for AND reduction
	wire[31:0] column_trigger_out;
	
	genvar ncol;
	genvar nrow;
	generate
		for(ncol=0; ncol<32; ncol = ncol + 1) begin: triggercolblock
		
			//Build stuff in the column
			for(nrow = 0; nrow < TRIGGER_ROWS; nrow = nrow + 1) begin : triggerrowblock
			
				//The actual shift register
				SRLC32E #(
					.INIT(32'h0)
				) shreg (
					.Q(trigger_out_raw[ncol][nrow]),
					.Q31(trigger_shout[nrow][ncol]),
					.A({
						1'b0,
						din_buf2[64*nrow + ncol*2 +: 2],
						din_buf3[64*nrow + ncol*2 +: 2]
					}),
					.CE(reconfig_ce),
					.CLK(reconfig_clk),
					.D(trigger_shin[nrow][ncol])
				);
				
				//Hook up the inputs
				//We shift into the LOW order block. This means that we should load the HIGH order block first.
				if(nrow == 0)
					assign trigger_shin[nrow][ncol] = reconfig_din[ncol];
				else
					assign trigger_shin[nrow][ncol] = trigger_shout[nrow-1][ncol];
					
			end
			
			//AND-reduce the output of this column
			assign column_trigger_out[ncol] = &trigger_out_raw[ncol];
			
		end
	endgenerate
		
	//Enable trigger when we're not configuring
	reg config_done = 0;
	always @(posedge reconfig_clk) begin
		if(reset)
			config_done <= 0;
		
		else if(reconfig_finish)
			config_done <= 1;		
	end
	
	//Need to move flag across clock domains
	wire config_done_sync;
	ThreeStageSynchronizer sync_capture_done(
		.clk_in(reconfig_clk), 	.din(config_done),
		.clk_out(capture_clk),	.dout(config_done_sync));
	
	//Secondary reduction of the trigger output
	//Trigger if all channels' conditions were met and we're fully configured
	always @(posedge capture_clk) begin
		trigger <= (column_trigger_out == 32'hffffffff) && config_done_sync;
	end
	
endmodule
