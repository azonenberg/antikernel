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
	@brief An I/O delay line
	
	For now, we only support synthesis-time fixed delay values (no runtime tuning).
 */
module IODelayBlock(
	i_pad, i_fabric, i_fabric_serdes,
	o_pad, o_fabric,
	input_en
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter WIDTH = 16;
	
	parameter INPUT_DELAY	= 100;		//picoseconds
	parameter OUTPUT_DELAY	= 100;		//picoseconds
	parameter DIRECTION		= "INPUT";	//INPUT or OUTPUT only support for now (no IO mode yet)
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire[WIDTH-1 : 0]		i_pad;				//input from pad to rx datapath
	output wire[WIDTH-1 : 0]	i_fabric;			//output from rx datapath to fabric
	output wire[WIDTH-1 : 0]	i_fabric_serdes;	//output from rx datapath to input SERDES
	
	output wire[WIDTH-1 : 0]	o_pad;				//output from tx datapath to pad
	input wire[WIDTH-1 : 0]		o_fabric;			//input from fabric or serdes to tx datapath
	
	input wire		input_en;						//high = input, low = output
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Delay tap calculation
	
	//Look up the speed grade passed in from Splash
	localparam SPEED_GRADE = `XILINX_SPEEDGRADE;
	
	//Pull in chip-specific speed grade info
	`include "IODelayBlock_spartan6.vh"
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual delay block
		
	genvar i;
	generate
		for(i=0; i<WIDTH; i = i+1) begin: delays
	
			//Fixed uncalibrated delays for Spartan-6
			`ifdef XILINX_SPARTAN6
			
				localparam input_delay_taps = s6_target_delay(INPUT_DELAY);
				localparam output_delay_taps = s6_target_delay(OUTPUT_DELAY);
				
				//Sanity check, max number of taps is 255
				initial begin
					if(input_delay_taps > 255) begin
						$display("ERROR: IODelayBlock computed >255 taps (%d) for input delay value %d ps",
							input_delay_taps, INPUT_DELAY);
						$finish;
					end
					if(output_delay_taps > 255) begin
						$display("ERROR: IODelayBlock computed >255 taps (%d) for output delay value %d ps",
							output_delay_taps, OUTPUT_DELAY);
						$finish;
					end
				end
				
				//The actual delay block
				//Keep it in IO mode so we can use the same module as input and output with minimal changes
				IODELAY2 #(
					.IDELAY_VALUE(input_delay_taps),
					.IDELAY2_VALUE(0),
					.IDELAY_MODE("NORMAL"),
					.ODELAY_VALUE(output_delay_taps),
					.IDELAY_TYPE("FIXED"),
					.DELAY_SRC((DIRECTION == "IN") ? "IDATAIN" : "ODATAIN"),
					.SERDES_MODE("NONE"),
					.DATA_RATE("DDR")
				) delayblock
				(
					.IDATAIN(i_pad[i]),
					.T(input_en),
					.ODATAIN(o_fabric[i]),
					.CAL(),
					.IOCLK0(),
					.IOCLK1(),
					.CLK(),
					.INC(1'b0),
					.CE(1'b0),
					.RST(),
					.BUSY(),
					.DATAOUT(i_fabric_serdes[i]),
					.DATAOUT2(i_fabric[i]),
					.TOUT(),				//tristate not implemented
					.DOUT(o_pad[i])
				);
				
				//Print stats
				initial begin
					if(i == 0) begin
						$display("INFO: Target input delay for IODelayBlock is %d ps, actual is %d - %d",
							INPUT_DELAY, s6_iodelay_val(input_delay_taps) / 3, s6_iodelay_val(input_delay_taps));
						$display("INFO: Target output delay for IODelayBlock is %d ps, actual is %d - %d",
							OUTPUT_DELAY, s6_iodelay_val(output_delay_taps) / 3, s6_iodelay_val(output_delay_taps));
					end
				end
				
			`endif
			
			//PTV-calibrated delays for 7 series
			//For now, we only support fixed delays and assume the reference clock is 200 MHz
			//(300/400 MHz refclk only supported in -2 and -3 speed grades for 7 series)
			//Delays for artix7 and kintex7 are the same
			`ifdef XILINX_7SERIES
			
				localparam tap_size				= 78;	//78.125 ps per tap at 200 MHz
				localparam input_delay_taps 	= INPUT_DELAY / tap_size;
				localparam output_delay_taps	= INPUT_DELAY / tap_size;
			
				//Sanity check, max number of taps is 31
				initial begin
					if(input_delay_taps > 31) begin
						$display("ERROR: IODelayBlock computed >31 taps (%d) for input delay value %d ps",
							input_delay_taps, INPUT_DELAY);
						$finish;
					end
					if(output_delay_taps > 31) begin
						$display("ERROR: IODelayBlock computed >31 taps (%d) for input delay value %d ps",
							output_delay_taps, OUTPUT_DELAY);
						$finish;
					end
				end
			
				//Create the input delay
				if(DIRECTION == "IN") begin
				
					//Create the IDELAY block
					IDELAYE2 #(
						.IDELAY_TYPE("FIXED"),
						.DELAY_SRC("IDATAIN"),
						.IDELAY_VALUE(input_delay_taps),
						.HIGH_PERFORMANCE_MODE("FALSE"),		//TODO: decide when to enable
						.SIGNAL_PATTERN("DATA"),				//TODO: handle clocks
						.REFCLK_FREQUENCY(200),					//TODO: Make configurable
						.CINVCTRL_SEL("FALSE"),
						.PIPE_SEL("FALSE")
					) idelayblock (
						.C(),
						.REGRST(1'b0),
						.LD(1'b0),
						.CE(1'b0),
						.INC(1'b0),
						.CINVCTRL(1'b0),
						.CNTVALUEIN(5'b0),
						.IDATAIN(i_pad[i]),
						.DATAIN(1'b0),
						.LDPIPEEN(1'b0),
						.DATAOUT(i_fabric[i]),
						.CNTVALUEOUT()
					);
				
					assign o_pad[i]				= 0;
					assign i_fabric_serdes[i]	= i_fabric[i];
				end
				
				else if(DIRECTION == "OUT") begin
					//ODELAY not implemented for 7 series yet
					/*
					initial begin
						$display("7-series ODELAY not implemented yet in IODelayBlock\n");
						$finish;
					end
					*/
					assign o_pad[i]				= o_fabric[i];
				end
				
				//Print stats
				initial begin
					if(i == 0) begin
						$display("INFO: Target input delay for IODelayBlock is %d ps, actual is %d",
							INPUT_DELAY, input_delay_taps * tap_size);
						$display("INFO: Target output delay for IODelayBlock is %d ps, actual is %d",
							OUTPUT_DELAY, input_delay_taps * tap_size);
					end
				end
				
			`endif
			
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Delay calibration during initialization
	
endmodule

