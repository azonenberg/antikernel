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
	@brief Linear Technology LTC3374 8-channel buck converter
	
	Feedback nets are looped back internally but may be routed specially on the PCB for remote sensing
 */
module LTC3374(vin, gnd, en, vout, tempraw, pgood);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	parameter NUM_OUTPUTS	= 1;			//legal values are 1 to 8
	
	parameter PWM_MODE		= "BURST";		//legal values are "BURST" or "CONTINUOUS"
	
	parameter CURRENT_0		= 1;			//in amps
	parameter CURRENT_1		= 1;
	parameter CURRENT_2		= 1;
	parameter CURRENT_3		= 1;
	parameter CURRENT_4		= 1;
	parameter CURRENT_5		= 1;
	parameter CURRENT_6		= 1;
	parameter CURRENT_7		= 1;
	
	parameter VOLTAGE_0		= 3300;			//in mV
	parameter VOLTAGE_1		= 3300;
	parameter VOLTAGE_2		= 3300;
	parameter VOLTAGE_3		= 3300;
	parameter VOLTAGE_4		= 3300;
	parameter VOLTAGE_5		= 3300;
	parameter VOLTAGE_6		= 3300;
	parameter VOLTAGE_7		= 3300;
	
	parameter FEEDBACK_R1	= 270;			//in kohms
											//typically does not need to be changed
											
	parameter PASSIVE_TOLERANCE	= 1;		//in percent
											//typically does not need to be changed
											
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Input power
	(* MIN_POWER_VOLTAGE = 2700 *)
	(* MAX_POWER_VOLTAGE = 5500 *)
	input wire	vin;
	
	//System ground
	(* MIN_POWER_VOLTAGE = 0 *)
	(* MAX_POWER_VOLTAGE = 0 *)
	input wire	gnd;
	
	//Channel enables and outputs
	input wire[NUM_OUTPUTS-1 : 0]	en;
	output wire[NUM_OUTPUTS-1 : 0]	vout;
	
	//Raw temperature diode reading
	output wire		tempraw;
	
	//Power-good output
	(* OPEN_DRAIN *)
	output wire		pgood;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pack incoming settings into arrays for easier access
	
	//Voltage for each output channel
	localparam CHANNEL_VOLTAGE =
	{
		VOLTAGE_7[31:0],
		VOLTAGE_6[31:0],
		VOLTAGE_5[31:0],
		VOLTAGE_4[31:0],
		VOLTAGE_3[31:0],
		VOLTAGE_2[31:0],
		VOLTAGE_1[31:0],
		VOLTAGE_0[31:0]
	};
	
	//Current for each output channel		
	localparam CHANNEL_CURRENT =
	{
		(NUM_OUTPUTS > 7) ? CURRENT_7[2:0] : 3'b0,
		(NUM_OUTPUTS > 6) ? CURRENT_6[2:0] : 3'b0,
		(NUM_OUTPUTS > 5) ? CURRENT_5[2:0] : 3'b0,
		(NUM_OUTPUTS > 4) ? CURRENT_4[2:0] : 3'b0,
		(NUM_OUTPUTS > 3) ? CURRENT_3[2:0] : 3'b0,
		(NUM_OUTPUTS > 2) ? CURRENT_2[2:0] : 3'b0,
		(NUM_OUTPUTS > 1) ? CURRENT_1[2:0] : 3'b0,
		CURRENT_0[2:0]		
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Glue for channel number reordering
	
	//Total number of internal channels used
	localparam CHANNELS_USED =
		{3'b00, CHANNEL_CURRENT[0*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[1*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[2*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[3*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[4*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[5*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[6*3 +: 3]} +
		{3'b00, CHANNEL_CURRENT[7*3 +: 3]};
		
	//Find the base internal channel used by each output channel
	localparam BASE_3 	= CHANNEL_CURRENT[2*3 +: 3] + CHANNEL_CURRENT[1*3 +: 3] + CHANNEL_CURRENT[0*3 +: 3];
	localparam BASE_6	= CHANNEL_CURRENT[5*3 +: 3] + CHANNEL_CURRENT[4*3 +: 3] + CHANNEL_CURRENT[3*3 +: 3] + BASE_3;
	localparam CHANNEL_BASE =
	{
		CHANNEL_CURRENT[6*3 +: 3] + BASE_6,
		BASE_6,
		CHANNEL_CURRENT[4*3 +: 3] + CHANNEL_CURRENT[3*3 +: 3] + BASE_3,
		CHANNEL_CURRENT[3*3 +: 3] + BASE_3,
		BASE_3,
		CHANNEL_CURRENT[1*3 +: 3] + CHANNEL_CURRENT[0*3 +: 3],
		CHANNEL_CURRENT[0*3 +: 3],
		3'b0
	};
	
	//Determine which channels are being used in master mode
	//(a channel is a master if it's the base of another channel)
	function [0:0] IsChannelMaster;
		input integer target;
		input integer nchans;
		input [23:0] channel_base;
		integer i;
		
		begin
			IsChannelMaster = 0;
			for(i=0; i<nchans; i=i+1) begin
				if(channel_base[i*3 +: 3] == target)
					IsChannelMaster = 1;
			end
		end
		
	endfunction
	
	//indexed by INTERNAL rail number
	localparam CHANNEL_MASTER_MASK =
	{
		IsChannelMaster(7, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(6, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(5, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(4, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(3, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(2, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(1, CHANNELS_USED, CHANNEL_BASE),
		IsChannelMaster(0, CHANNELS_USED, CHANNEL_BASE)
	};
	
	//Determine the corresonding output channel for a given internal channel
	function [2:0] GetOutRail;
		input integer target;
		input input [23:0] channel_base;
		input integer num_outputs;
		
		integer i;
		
		begin
			GetOutRail = 0;
			for(i=0; i<num_outputs; i=i+1) begin
				if(channel_base[i*3 +: 3] <= target)
					GetOutRail = i;
			end
			
		end
		
	endfunction
	
	localparam OUT_RAIL_MAP = 
	{
		GetOutRail(7, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(6, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(5, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(4, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(3, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(2, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(1, CHANNEL_BASE, NUM_OUTPUTS),
		GetOutRail(0, CHANNEL_BASE, NUM_OUTPUTS)
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Component value calculation
	
	//Pull in the e-number scripts
	`include "enumber.vh"
	
	//Find the best resistor values to use
	localparam VFB_TARGET	= 800;	//+/- 20 mV (TODO calculate possible drift)
	function[31:0]	GetFeedbackResistor;
		input integer	voltage;
		input integer	vfb_target;
		input integer	feedback_r1;
		input integer	passive_tolerance;
		
		begin
			GetFeedbackResistor	= choose_evalue( ((voltage-vfb_target)*feedback_r1) / vfb_target, passive_tolerance);
		end
		
	endfunction

	//indexed by OUTPUT rail number
	localparam RFB_CONCAT_OUT	=
	{
		GetFeedbackResistor(VOLTAGE_7, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_6, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_5, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_4, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_3, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_2, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_1, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE),
		GetFeedbackResistor(VOLTAGE_0, VFB_TARGET, FEEDBACK_R1, PASSIVE_TOLERANCE)
	};
	
	//indexed by INTERNAL rail number
	localparam RFB_CONCAT	=
	{
		RFB_CONCAT_OUT[OUT_RAIL_MAP[7*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[6*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[5*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[4*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[3*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[2*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[1*3 +: 3]*32 +: 32],
		RFB_CONCAT_OUT[OUT_RAIL_MAP[0*3 +: 3]*32 +: 32]
	};
	
	//Compute actual output voltages
	//Be careful with order of operations to avoid roundoff error
	function[31:0] GetVActual;
		input integer rfb;
		input integer feedback_r1;
		input integer vfb_target;
		begin
			GetVActual = vfb_target + ((vfb_target*rfb) / feedback_r1);
		end
	endfunction
	
	//indexed by OUTPUT rail number
	localparam VACTUAL =
	{
		GetVActual(RFB_CONCAT_OUT[7*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[6*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[5*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[4*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[3*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[2*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[1*32 +: 32], FEEDBACK_R1, VFB_TARGET),
		GetVActual(RFB_CONCAT_OUT[0*32 +: 32], FEEDBACK_R1, VFB_TARGET)
	};

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Internal output nets used for voltage tagging
	
	//TODO: Is there a cleaner way to tag individual nets?	
	(* POWER_VOLTAGE = VACTUAL[0*32 +: 32] *)	wire	vout_internal_0;
	(* POWER_VOLTAGE = VACTUAL[1*32 +: 32] *)	wire	vout_internal_1;
	(* POWER_VOLTAGE = VACTUAL[2*32 +: 32] *)	wire	vout_internal_2;
	(* POWER_VOLTAGE = VACTUAL[3*32 +: 32] *)	wire	vout_internal_3;
	(* POWER_VOLTAGE = VACTUAL[4*32 +: 32] *)	wire	vout_internal_4;
	(* POWER_VOLTAGE = VACTUAL[5*32 +: 32] *)	wire	vout_internal_5;
	(* POWER_VOLTAGE = VACTUAL[6*32 +: 32] *)	wire	vout_internal_6;
	(* POWER_VOLTAGE = VACTUAL[7*32 +: 32] *)	wire	vout_internal_7;
	
	wire[7:0]	vout_internal =
	{
		vout_internal_7,
		vout_internal_6,
		vout_internal_5,
		vout_internal_4,
		vout_internal_3,
		vout_internal_2,
		vout_internal_1,
		vout_internal_0
	};
	
	assign vout = vout_internal[NUM_OUTPUTS-1 : 0];

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DRC checks and output configuration printing
	
	integer j;
	initial begin
		
		//Print global stuff
		$display("LTC3374 configuration:");
		$display("    Using %d/8 channels", CHANNELS_USED);
		$display("    PWM mode: %s", PWM_MODE);
		$display("    Passive tolerance: %d %%", PASSIVE_TOLERANCE);
		$display("    R1 feedback: %d K", FEEDBACK_R1 / 1000);
		
		//Global sanity checks
		if( (NUM_OUTPUTS < 1) || (NUM_OUTPUTS > 8) ) begin
			$display("ERROR: LTC3374 must have 1 to 8 outputs, tried to use %d", NUM_OUTPUTS);
			$finish();
		end
		if( (CHANNELS_USED == 0) || (CHANNELS_USED > 8) )begin
			$display("ERROR: LTC3374 must have 1 to 8 channels, tried to use %d", CHANNELS_USED);
			$finish();
		end
		if( (PWM_MODE != "BURST") && (PWM_MODE != "CONTINUOUS") ) begin
			$display("ERROR: LTC3374 legal values for PWM_MODE are BURST and CONTINUOUS (specified %s)", PWM_MODE);
			$finish();
		end
		
		//Per-channel processing
		for(j=0; j<NUM_OUTPUTS; j=j+1) begin
			
			//Print configuration
			$display("    %d: Channels %d-%d (%dA capacity)", 
				j,
				CHANNEL_BASE[j*3 +: 3],
				CHANNEL_BASE[j*3 +: 3] + CHANNEL_CURRENT[j*3 +: 3] - 1,
				CHANNEL_CURRENT[j*3 +: 3]);
			$display("       Requested %d mV, got %d mV (Rfb = %d K)",
				CHANNEL_VOLTAGE[j*32 +: 32],
				VACTUAL[j*32 +: 32],
				RFB_CONCAT_OUT[j*32 +: 32]/1000);
				
			//TODO: Sanity check that output voltage is close to the nominal value
			
			//TODO: Sanity check resistor value is reasonable
			
			//At most 4 channels can be paralleled
			if(CHANNEL_CURRENT[j*3 +: 3] > 4) begin
				$display("ERROR: LTC3374 cannot parallel more than 4 channels (requested %d for channel %d)",
					CHANNEL_CURRENT[j*3 +: 3], j);
				$finish();
			end
			
			//Channel output voltage must be between 800 mV and 5V
			//TODO: Also verify Vout < Vin
			if( (CHANNEL_VOLTAGE[j*32 +: 32] < 800) || (CHANNEL_VOLTAGE[j*32 +: 32] > 5000) )begin
				$display("ERROR: LTC3374 output range is 800 mV to Vin (requested %d mV)", CHANNEL_VOLTAGE[j*32 +: 32]);
				$finish();
			end				
			
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Component instantiation
	
	genvar i;
	generate
	
		//Burst mode selection
		wire		burst_mode;
		if(PWM_MODE == "BURST")
			assign burst_mode = gnd;
		else
			assign burst_mode = vin;
	
		//Feedback inputs
		wire[7:0]	internal_feedback;
		
		//Enable signals
		wire[7:0]	internal_en;
		
		//Switcher outputs
		wire[7:0]	switch_out;
		
		//Inductor outputs
		wire[7:0]	inductor_out;
		
		//The actual SMPS controller
		(* value = "LTC3374EUHF#PBF" *)
		(* distributor = "digikey" *)
		(* distributor_part = "LTC3374EUHF#PBF-ND" *)
		QFN_38_0p5MM_5x7MM smps_ctrl (
			
			//Internal feedback nodes
			.p1(internal_feedback[0]), 
			.p6(internal_feedback[1]),
			.p7(internal_feedback[2]),
			.p12(internal_feedback[3]),
			.p20(internal_feedback[4]),
			.p25(internal_feedback[5]),
			.p26(internal_feedback[6]),
			.p31(internal_feedback[7]),
			
			//Power inputs
			.p2(vin), 
			.p5(vin),
			.p8(vin),
			.p11(vin),
			.p21(vin),
			.p24(vin),
			.p27(vin),
			.p30(vin),
			.p35(vin),
			
			//Enable inputs
			.p13(internal_en[3]),
			.p14(internal_en[2]),
			.p18(internal_en[5]),
			.p19(internal_en[4]),
			.p32(internal_en[7]),
			.p33(internal_en[6]),
			.p37(internal_en[1]),
			.p38(internal_en[0]),
			
			//Output voltages
			.p3(switch_out[0]),
			.p4(switch_out[1]),
			.p9(switch_out[2]),
			.p10(switch_out[3]),
			.p22(switch_out[4]),
			.p23(switch_out[5]),
			.p28(switch_out[6]),
			.p29(switch_out[7]),
			
			//Ground (exposed pad only)
			.PAD(gnd),
			
			//Thermal diode output
			.p36(tempraw),
			
			//Burst mode select
			.p34(burst_mode),
			
			//Power-good output
			.p15(pgood),
			
			//Synchronization to external oscillator (not implemented)
			.p16(gnd),
			
			//Oscillator frequency selection (use default 2 MHz)
			.p17(vin)
			
		);
				
		//Per-channel processing
		for(i=0; i<8; i=i+1) begin:ichan
		
			//Slave mode?
			if(!CHANNEL_MASTER_MASK[i]) begin
			
				//If an output is being used in slave mode, tie FB to Vin
				assign internal_feedback[i] = vin;
				
				//Combine switch outputs as necessary
				if(i > 0)
					assign switch_out[i] = switch_out[i-1];
					
				//Turn off the control circuit
				assign internal_en[i] = gnd;
				
			end
			
			//Unused channel?
			else if(i > CHANNELS_USED) begin
				assign internal_en[i] = gnd;
			end
				
			//Not a slave... create a resistor divider
			else begin
			
				//Upper feedback resistor
				(* value = RFB_CONCAT[i*32 +: 32] *)
				(* tolerance = PASSIVE_TOLERANCE *)
				(* units = "K" *)
				EIA_0402_RES_NOSILK fbdiv_hi (
					.p1(vout_internal[i]),
					.p2(internal_feedback[i])
				);
			
				//Lower feedback resistor
				(* value = FEEDBACK_R1 *)
				(* tolerance = PASSIVE_TOLERANCE *)
				(* units = "K" *)
				EIA_0402_RES_NOSILK fbdiv_lo (
					.p1(internal_feedback[i]),
					.p2(gnd)
				);
				
				//Power inductor
				case(CHANNEL_CURRENT[OUT_RAIL_MAP[i*3 +: 3]*3 +: 3])
				
					//not datasheet recommended, but board tested
					1: begin
						(* distributor = "digikey" *)
						(* distributor_part = "587-2098-1-ND" *)
						(* value = 2200 *)
						(* units = "nH" *)
						INDUCTOR_YUDEN_NR6028 L (.p1(switch_out[i]), .p2(inductor_out[i]));
					end

					//overkill but should work
					//TODO: find smaller alternative
					2: begin
						(* distributor = "digikey" *)
						(* distributor_part = "445-4118-1-ND" *)
						(* value = 2200 *)
						(* units = "nH" *)
						INDUCTOR_TDK_SPM6530 L (.p1(switch_out[i]), .p2(inductor_out[i]));
					end
					
					//overkill but should work
					//TODO: find smaller alternative
					3: begin
						(* distributor = "digikey" *)
						(* distributor_part = "445-4118-1-ND" *)
						(* value = 2200 *)
						(* units = "nH" *)
						INDUCTOR_TDK_SPM6530 L (.p1(switch_out[i]), .p2(inductor_out[i]));
					end
					
					//datasheet recommendation
					4: begin
						(* distributor = "digikey" *)
						(* distributor_part = "445-4118-1-ND" *)
						(* value = 2200 *)
						(* units = "nH" *)
						INDUCTOR_TDK_SPM6530 L (.p1(switch_out[i]), .p2(inductor_out[i]));
					end
					
				endcase

				
				//Hook up enable
				assign internal_en[i] = en[OUT_RAIL_MAP[i*3 +: 3]];
				
			end
			
			//Tie inductor outputs to actual outputs
			assign inductor_out[i] = vout_internal[OUT_RAIL_MAP[i*3 +: 3]];
			
			//Input filter caps
			//This capacitor is about 9 uF @ 5V, pretty close to the nominal 10 uF.
			(* distributor = "digikey" *)
			(* distributor_part = "1276-2728-1-ND" *)
			(* value = 220 *)
			(* units = "uF" *)
			(* tolerance = 20 *)
			(* voltage = 16 *)
			EIA_1206_CAP_NOSILK incap(.p1(vin), .p2(gnd) );
						
		end
		
		for(i=0; i<NUM_OUTPUTS; i=i+1) begin:ochan
		
			//TODO: Optional compensation caps to tweak transient response
		
			//Output filter caps
			case(CHANNEL_CURRENT[i*3 +: 3])
			
				//need nominal 22 uF
				1: begin
				
					//we lose 20% capacitance at 2V so don't use it beyond there
					if(CHANNEL_VOLTAGE[i*32 +: 32] < 2000) begin			
						(* distributor = "digikey" *)
						(* distributor_part = "1276-2412-1-ND" *)
						(* value = 22 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_0805_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );			
					end
					
					//this one costs 3x as much but is only 20% down at 5V
					else begin		
						(* distributor = "digikey" *)
						(* distributor_part = "1276-3299-1-ND" *)
						(* value = 22 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 25 *)
						EIA_1206_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );
					end

				end
				
				//need nominal 47 uF
				2: begin
					
					//we lose 20% capacitance at 2V so don't use it beyond there
					if(CHANNEL_VOLTAGE[i*32 +: 32] < 2000) begin				
						(* distributor = "digikey" *)
						(* distributor_part = "1276-1167-1-ND" *)
						(* value = 47*)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_1210_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );
					end
					
					//over 2x the price, down about 30% at 5V
					//TODO consider larger value
					else begin			
						(* distributor = "digikey" *)
						(* distributor_part = "1276-3376-1-ND" *)
						(* value = 47 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 16 *)
						EIA_1210_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );
					end
					
				end
				
				//need nominal 68 uF
				3: begin
				
					//we lose 40% capacitance at 3V which leaves us still around 60 uF
					if(CHANNEL_VOLTAGE[i*32 +: 32] < 3000) begin		
						(* distributor = "digikey" *)
						(* distributor_part = "1276-1782-1-ND" *)
						(* value = 100 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_1210_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );
					end
					
					//this one is 60% down at 5V, still leaves us at 68 uF
					else begin		
						(* distributor = "digikey" *)
						(* distributor_part = "1276-3367-1-ND" *)
						(* value = 150 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_1210_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );
					end
					
				end
				
				//need nominal 100 uF
				4: begin
					
					//30% down at 3V leaves us at 105 uF
					if(CHANNEL_VOLTAGE[i*32 +: 32] < 3000) begin
						(* distributor = "digikey" *)
						(* distributor_part = "1276-3367-1-ND" *)
						(* value = 150 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_1210_CAP_NOSILK ocap(.p1(vout[i]), .p2(gnd) );
					end
					
					//no sane ceramic caps are still 100 uF at 5V, so parallel two
					else begin
					
						(* distributor = "digikey" *)
						(* distributor_part = "1276-3367-1-ND" *)
						(* value = 150 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_1210_CAP_NOSILK ocap_1 (.p1(vout[i]), .p2(gnd) );
						
						(* distributor = "digikey" *)
						(* distributor_part = "1276-3367-1-ND" *)
						(* value = 150 *)
						(* units = "uF" *)
						(* tolerance = 20 *)
						(* voltage = 6 *)
						EIA_1210_CAP_NOSILK ocap_2 (.p1(vout[i]), .p2(gnd) );
					
					end
					
				end
			
			endcase
			
		end
		
	endgenerate

endmodule

