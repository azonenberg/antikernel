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
	@brief ISim simulation test for ReconfigurablePLL
 */

module testReconfigurablePLL;

	reg [1:0]	clkin = 0;
	reg 		clksel = 0;
	reg 		reset = 0;
	reg 		reconfig_clk = 0;
	wire [5:0]	clkout;
	wire		locked;
	reg			reconfig_start		= 0;
	reg			reconfig_finish		= 0;
	reg			reconfig_vco_en		= 0;
	reg[6:0]	reconfig_vco_mult	= 0;
	reg[6:0]	reconfig_vco_indiv	= 0;
	wire		reconfig_cmd_done;
	wire		busy;
	reg			reconfig_vco_bandwidth	= 0;
	reg			reconfig_output_en		= 0;
	reg[2:0]	reconfig_output_idx		= 0;
	reg[7:0]	reconfig_output_div		= 0;

	//The target PLL device
	ReconfigurablePLL #(
		.OUTPUT_GATE(6'b111111),		//gate all outputs until locked
		.OUTPUT_BUF_GLOBAL(6'b111111),	//use BUFGs
		.OUTPUT_BUF_LOCAL(6'b000000),	//do not use BUFHs
		.IN0_PERIOD(12.5),				//input clock freq
		.IN1_PERIOD(12.5),
		.OUT0_MIN_PERIOD(5),			//200 MHz
		.OUT1_MIN_PERIOD(10),			//100 MHz
		.OUT2_MIN_PERIOD(2.5),			//400 MHz
		.OUT3_MIN_PERIOD(5),			//200 MHz
		.OUT4_MIN_PERIOD(5),			//200 MHz
		.OUT5_MIN_PERIOD(5)				//200 MHz
	) uut (
		.clkin(clkin), 
		.clksel(clksel), 
		.clkout(clkout), 
		.reset(reset), 
		.locked(locked), 
		.busy(busy),
		.reconfig_clk(reconfig_clk),
		.reconfig_start(reconfig_start),
		.reconfig_finish(reconfig_finish),
		.reconfig_vco_en(reconfig_vco_en),
		.reconfig_vco_mult(reconfig_vco_mult),
		.reconfig_vco_indiv(reconfig_vco_indiv),
		.reconfig_cmd_done(reconfig_cmd_done),
		.reconfig_vco_bandwidth(reconfig_vco_bandwidth),
		.reconfig_output_en(reconfig_output_en),
		.reconfig_output_idx(reconfig_output_idx),
		.reconfig_output_div(reconfig_output_div)
	);

	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	
	//input clock (only one for now)
	always begin
		#6.25;
		clkin[0] = 0;
		#6.25;
		clkin[0] = ready;
	end
	
	//reconfiguration clock
	always begin
		#5;
		reconfig_clk = 0;
		#5;
		reconfig_clk = ready;
	end
	
	//Measure the frequency of each clock output
	real clock_periods[5:0];
	real clock_starts[5:0];
	genvar i;
	generate
		for(i=0; i<6; i=i+1) begin:freqcounter
			always @(posedge clkout[i]) begin
				clock_starts[i] 	<= $realtime();
				clock_periods[i]	<= $realtime() - clock_starts[i];
			end
		end
	endgenerate
	
	real delta;
	
	reg[7:0] state	= 0;
	reg[7:0] count	= 0;
	
	//Check if a clock period is within a given tolerance of a target period
	function integer clockcheck;
		input real period;
		input real target;
		input real tolerance;
		
		real delta;
		
		begin
			delta = period - target;
			if( (delta > tolerance) || (delta < -tolerance) ) begin
				clockcheck = 0;
				
				$display("FAIL: Clock output is bad (expected %f ns period, measured %f)", target, period);
				$finish;
				
			end
			else
				clockcheck = 1;
		end
		
	endfunction
	
	always @(posedge reconfig_clk) begin
	
		reset				<= 0;
		
		reconfig_start		<= 0;
		reconfig_finish		<= 0;
		reconfig_vco_en		<= 0;
		
		reconfig_output_en	<= 0;
	
		case(state)
			
			//Initial reset
			0:	state			<= 1;
			1: begin
				if(!busy) begin
					$display("Initial reset");
					state			<= 2;
					reset			<= 1;
				end
			end
			
			//Wait for lock
			//default VCO freq is 80 MHz * 10 = 800 MHz = 1.25 ns
			2: begin
				if(locked) begin
					$display("Locked");
					state		<= 3;
				end
			end
			
			//Enter reconfig mode
			3: begin
				$display("Start reconfigure");
				reconfig_start	<= 1;
				state			<= 4;
			end
			
			//Change the VCO settings
			4: begin
				$display("Reconfigure VCO");
				reconfig_vco_en			<= 1;	//high bandwidth
				reconfig_vco_bandwidth	<= 1;
				reconfig_vco_indiv		<= 3;	//26.667 MHz at the PFD
				reconfig_vco_mult		<= 24;	//640 MHz at the VCO (1.563 ns)
				state					<= 5;				
			end
			
			//Wait for the reconfiguration to complete
			5: begin
				if(reconfig_cmd_done) begin
					$display("Finish reconfiguration");
					reconfig_finish	<= 1;
					state			<= 6;
				end
			end
			
			//Wait for the PLL to lock
			6: begin
				if(locked) begin
					$display("Locked");
					count	<= 0;
					state	<= 7;
				end
			end
			
			//Wait for all outputs to have at least one cycle
			7: begin
				count	<= count + 1;
				if(count == 63)
					state	<= 8;
			end
			
			//Check their periods. Allow 50ps of jitter
			8: begin
				$display("Period check");
				
				clockcheck(clock_periods[0],  6.250, 0.05);		//0 = Fvco/4 = 160 MHz = 6.25 ns
				clockcheck(clock_periods[1], 12.500, 0.05);		//1 = Fvco/8 =  80 MHz = 12.5 ns
				clockcheck(clock_periods[2],  3.125, 0.05);		//2 = Fvco/2 = 320 MHz = 3.125 ns
				clockcheck(clock_periods[3],  6.250, 0.05);		//3 = Fvco/4 = 160 MHz = 6.25 ns
				clockcheck(clock_periods[4],  6.250, 0.05);		//4 = Fvco/4 = 160 MHz = 6.25 ns
				clockcheck(clock_periods[5],  6.250, 0.05);		//5 = Fvco/4 = 160 MHz = 6.25 ns

				state	<= 9;
				
			end
			
			//Go back into reconfig mode
			9: begin
				$display("Start reconfigure");
				reconfig_start	<= 1;
				state			<= 10;
			end
			
			//Change the divisor for output #5 to 16 (40 MHz, 25 ns)
			10: begin
				$display("Reconfigure channel 5");
				reconfig_output_en	<= 1;
				reconfig_output_idx	<= 5;
				reconfig_output_div	<= 16;
				state				<= 11;
			end
			
			11: begin
				if(reconfig_cmd_done) begin
					$display("Finish reconfiguration");
					reconfig_finish	<= 1;
					state			<= 12;
				end
			end
			
			//Wait for the PLL to lock
			12: begin
				if(locked) begin
					$display("Locked");
					count	<= 0;
					state	<= 13;
				end
			end
			
			//Wait for all outputs to have at least one cycle
			13: begin
				count	<= count + 1;
				if(count == 63)
					state	<= 14;
			end
			
			//Check their periods. Allow 50ps of jitter
			14: begin
				$display("Period check");
				
				clockcheck(clock_periods[0],  6.250, 0.05);		//0 = Fvco/4 = 160 MHz = 6.25 ns
				clockcheck(clock_periods[1], 12.500, 0.05);		//1 = Fvco/8 =  80 MHz = 12.5 ns
				clockcheck(clock_periods[2],  3.125, 0.05);		//2 = Fvco/2 = 320 MHz = 3.125 ns
				clockcheck(clock_periods[3],  6.250, 0.05);		//3 = Fvco/4 = 160 MHz = 6.25 ns
				clockcheck(clock_periods[4],  6.250, 0.05);		//4 = Fvco/4 = 160 MHz = 6.25 ns
				clockcheck(clock_periods[5], 25.000, 0.05);		//5 = Fvco/16 = 40 MHz = 25 ns

				state	<= 15;
				
			end
			
			//For now, we're good
			15: begin
				$display("PASS");
				$finish;
			end
			
		endcase
	
	end
	
	initial begin
		#25000;
		$display("FAIL: Test timed out");
		$finish;
	end
	
endmodule

