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
	@brief Controller for 16-bit DDR2 SDRAM with native interface (no NoC links or access controls)
 */
module NativeDDR2Controller(
	
	//Clock
	clk_p, clk_n,
	
	//Fabric interface
	addr, done, 
	wr_en, wr_data, 
	rd_en, rd_data,
	calib_done,
	
	//DDR2 interface
	ddr2_ras_n, ddr2_cas_n, ddr2_udqs_p, ddr2_udqs_n, ddr2_ldqs_p, ddr2_ldqs_n,
	ddr2_udm, ddr2_ldm, ddr2_we_n,
	ddr2_ck_p, ddr2_ck_n, ddr2_cke, ddr2_odt,
	ddr2_ba, ddr2_addr,
	ddr2_dq
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//DDR input clock
	input wire clk_p;
	input wire clk_n;
	
	//Fabric interface
	input wire[31:0] addr;
	output reg done = 0;
	input wire wr_en;
	input wire[127:0] wr_data;
	input wire rd_en;
	output wire[127:0] rd_data;
	output reg calib_done = 0;
	
	//DDR2 interface
	(* IOB="FORCE" *)	output reg 		ddr2_ras_n  = 1;
	(* IOB="FORCE" *)	output reg 		ddr2_cas_n	= 1;
	(* IOB="FORCE" *)	output reg 		ddr2_we_n	= 1;
	(* IOB="FORCE" *)	output reg[2:0]	ddr2_ba		= 3'b111;
						inout wire 		ddr2_udqs_p;
						inout wire 		ddr2_udqs_n;
						inout wire 		ddr2_ldqs_p;
						inout wire 		ddr2_ldqs_n;
	(* IOB="FORCE" *)	output reg 		ddr2_udm 	= 0;	//not masking
	(* IOB="FORCE" *)	output reg 		ddr2_ldm 	= 0;
						output wire		ddr2_ck_p;
						output wire		ddr2_ck_n;
	(* IOB="FORCE" *)	output reg  	ddr2_cke 	= 0;
	(* IOB="FORCE" *)	output reg 		ddr2_odt	= 0;
	//cs_n is hard-wired on the Atlys
	(* IOB="FORCE" *)	output reg[12:0] ddr2_addr	= 0;
						inout wire[15:0] ddr2_dq;
						
	//Register all control signals by one cycle for improved setup times
	//Force these to actually be separate FFs!
	(* KEEP="yes" *) reg ddr2_ras_n_adv = 0;
	(* KEEP="yes" *) reg ddr2_cas_n_adv = 0;
	(* KEEP="yes" *) reg ddr2_we_n_adv = 0;
	(* KEEP="yes" *) reg ddr2_cke_adv = 0;
	(* KEEP="yes" *) reg[2:0] ddr2_ba_adv = 0;
	(* KEEP="yes" *) reg[12:0] ddr2_addr_adv = 0;
	always @(posedge clk_p) begin
		ddr2_ras_n <= ddr2_ras_n_adv;
		ddr2_cas_n <= ddr2_cas_n_adv;
		ddr2_we_n <= ddr2_we_n_adv;
		ddr2_cke <= ddr2_cke_adv;
		ddr2_ba <= ddr2_ba_adv;
		ddr2_addr <= ddr2_addr_adv;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DDR output enable
	
	//Active-low output enable in DDR domain (one per channel)
	wire[17:0] ddr2_oe_n;		//top 2 for DQS*
	
	//Output enable in clk_p domain
	reg ddr2_oe_0_n = 0;
	reg ddr2_oe_1_n = 0;
	
	DDROutputBuffer #(.WIDTH(18)) oe_oddr2(
		.clk_p(clk_p),
		.clk_n(clk_n),
		.dout(ddr2_oe_n),
		.din0({18{ddr2_oe_0_n}}),
		.din1({18{ddr2_oe_1_n}})
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Differential buffers and delays for DQS
	
	/*
		Output
			Send data normally, then DQS delayed half a DDR cycle
		Input
			Delay data ~half a DDR cycle, then capture on main clock
			
		Ignore DQS on input, we'll figure out the phase shift ourself
	 */
	
	//Input DQ strobes
	wire ddr2_udqs_in;
	wire ddr2_ldqs_in;
	
	//Single-ended DDR DQS output signals (not delayed)
	wire[1:0] ddr2_dqs_out;
	
	//Single-ended DDR DQS output signals (delayed)
	wire[1:0] ddr2_dqs_out_delayed;
	wire[1:0] ddr2_dqs_in_delayed;
	wire[1:0] ddr2_dqs_t_delayed;
	
	//Single-ended SDR DQS output signals
	reg ddr2_udqs_out_0 = 0;
	reg ddr2_ldqs_out_0 = 0;
	
	//DDR output buffer for *DQS
	DDROutputBuffer #(.WIDTH(2)) dqs_oddr2(
		.clk_p(clk_p),
		.clk_n(clk_n),
		.dout(ddr2_dqs_out),
		.din0({ddr2_udqs_out_0, ddr2_ldqs_out_0}),
		.din1({1'b0, 1'b0})
		);
	
	localparam DQS_DELAY_VALUE = 15;
	IODELAY2 #(
		.IDELAY_VALUE(0),
		.IDELAY2_VALUE(0),
		.IDELAY_MODE("NORMAL"),
		.ODELAY_VALUE(DQS_DELAY_VALUE),
		.IDELAY_TYPE("DEFAULT"),
		.COUNTER_WRAPAROUND("STAY_AT_LIMIT"),
		.DELAY_SRC("IO"),
		.SERDES_MODE("NONE"),
		//synthesis translate_off
		.SIM_TAP_DELAY(DQS_DELAY_VALUE),
		//synthesis translate_on
		.DATA_RATE("DDR")
	) ddr2_udqs_iodelay2
	(
		.T(ddr2_oe_n[17]),
		.IDATAIN(ddr2_udqs_in),
		.ODATAIN(ddr2_dqs_out[1]),
		.CAL(),
		.IOCLK0(),
		.IOCLK1(),
		.CLK(),
		.INC(),
		.CE(),
		.RST(),
		.BUSY(),
		.DATAOUT(ddr2_dqs_in_delayed[1]),
		.DATAOUT2(),
		.TOUT(ddr2_dqs_t_delayed[1]),
		.DOUT(ddr2_dqs_out_delayed[1])
	);
	
	IODELAY2 #(
		.IDELAY_VALUE(0),
		.IDELAY2_VALUE(0),
		.IDELAY_MODE("NORMAL"),
		.ODELAY_VALUE(DQS_DELAY_VALUE),
		.IDELAY_TYPE("DEFAULT"),
		.COUNTER_WRAPAROUND("STAY_AT_LIMIT"),
		.DELAY_SRC("IO"),
		.SERDES_MODE("NONE"),
		//synthesis translate_off
		.SIM_TAP_DELAY(DQS_DELAY_VALUE),
		//synthesis translate_on
		.DATA_RATE("DDR")
	) ddr2_ldqs_iodelay2
	(
		.T(ddr2_oe_n[16]),
		.IDATAIN(ddr2_ldqs_in),
		.ODATAIN(ddr2_dqs_out[0]),
		.CAL(),
		.IOCLK0(),
		.IOCLK1(),
		.CLK(),
		.INC(),
		.CE(),
		.RST(),
		.BUSY(),
		.DATAOUT(ddr2_dqs_in_delayed[0]),
		.DATAOUT2(),
		.TOUT(ddr2_dqs_t_delayed[0]),
		.DOUT(ddr2_dqs_out_delayed[0])
	);
	
	//Differential I/O buffers for *DQS
	IOBUFDS ddr2_udqs_iobufds(
		.I(ddr2_dqs_out_delayed[1]),
		.O(ddr2_udqs_in),
		.T(ddr2_dqs_t_delayed[1]),
		.IO(ddr2_udqs_p),
		.IOB(ddr2_udqs_n));
	IOBUFDS ddr2_ldqs_iobufds(
		.I(ddr2_dqs_out_delayed[0]),
		.O(ddr2_ldqs_in),
		.T(ddr2_dqs_t_delayed[0]),
		.IO(ddr2_ldqs_p),
		.IOB(ddr2_ldqs_n)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DQ buffers
	
	wire[15:0] ddr2_oe_n_delayed;
	wire[15:0] dout_ddr_delayed;
	wire[15:0] din_ddr;
	
	genvar i;
	generate
		for(i=0; i<16; i = i+1) begin: dqbuffers
			IOBUF iobuf(.I(dout_ddr_delayed[i]), .IO(ddr2_dq[i]), .O(din_ddr[i]), .T(ddr2_oe_n_delayed[i]));
		end
	endgenerate
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DDR buffers for DQ
	
	localparam DQ_DELAY_VALUE = 15;

	//Output signals in clk_p domain before delay
	reg[15:0] ddr2_dq_out_0 = 0;
	reg[15:0] ddr2_dq_out_1 = 0;
	
	//Output DDR buffer
	wire[15:0] dout_ddr;
	DDROutputBuffer #(.WIDTH(16)) dq_oddr2(
		.clk_p(clk_p),
		.clk_n(clk_n),
		.dout(dout_ddr),
		.din0(ddr2_dq_out_0),
		.din1(ddr2_dq_out_1)
		);
	
	//IODELAYs
	wire[15:0] din_ddr_delayed;
	generate
		for(i=0; i<16; i = i+1) begin: dqdelays
			IODELAY2 #(
				.IDELAY_VALUE(DQ_DELAY_VALUE),
				.IDELAY2_VALUE(0),
				.IDELAY_MODE("NORMAL"),
				.ODELAY_VALUE(0),
				.IDELAY_TYPE("FIXED"),
				.COUNTER_WRAPAROUND("STAY_AT_LIMIT"),
				.DELAY_SRC("IO"),
				.SERDES_MODE("NONE"),
				//synthesis translate_off
				.SIM_TAP_DELAY(DQ_DELAY_VALUE),
				//synthesis translate_on
				.DATA_RATE("DDR")
			) ddr2_dq_iodelay2
			(
				.T(ddr2_oe_n[i]),
				.IDATAIN(din_ddr[i]),
				.ODATAIN(dout_ddr[i]),
				.CAL(),
				.IOCLK0(),
				.IOCLK1(),
				.CLK(),
				.INC(),
				.CE(),
				.RST(),
				.BUSY(),
				.DATAOUT(din_ddr_delayed[i]),
				.DATAOUT2(),
				.TOUT(ddr2_oe_n_delayed[i]),
				.DOUT(dout_ddr_delayed[i])
			);
		end
	endgenerate
	
	//SDR input data synchronous to falling edge of clock
	//May or may not be phase shifted
	wire[15:0] ddr2_dq_in_0;
	wire[15:0] ddr2_dq_in_1;
	
	//synthesis translate_off
	reg[15:0] din_ddr_buf = 0;
	always @(posedge clk_p or posedge clk_n) begin
		din_ddr_buf <= din_ddr;
	end
	//synthesis translate_on
	
	//Input DDR buffer
	DDRInputBuffer #(.WIDTH(16)) udq_iddr2(
		.clk_p(clk_p),
		.clk_n(clk_n),
		`ifdef XILINX_ISIM
			.din(din_ddr_buf),
		`else
			.din(din_ddr_delayed),
		`endif
		.dout0(ddr2_dq_in_1),
		.dout1(ddr2_dq_in_0)
		);
		
	//Phase-shift correction for DDRs
	localparam ddr2_dq_phase_shift = 0;
	reg[15:0] ddr2_dq_in_0_buf = 0;
	reg[15:0] ddr2_dq_in_1_buf = 0;
	always @(posedge clk_p) begin
		ddr2_dq_in_0_buf <= ddr2_dq_in_0;
		ddr2_dq_in_1_buf <= ddr2_dq_in_1;
		if(ddr2_dq_phase_shift) begin
			ddr2_dq_in_0_buf <= ddr2_dq_in_1;
			ddr2_dq_in_1_buf <= ddr2_dq_in_0;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Differential clock output buffer
	
	//Phase-shift the output clock by 180 degrees
	//If we clock data out on our clock's rising edge, the RAM will see a rising edge half a cycle later
	wire ddr2_clk_raw;
	ODDR2 #
	(
		.DDR_ALIGNMENT("C0"),
		.SRTYPE("ASYNC"),
		.INIT(0)
	) ddr2_oddr2_clock_output
	(
		.C0(clk_p),
		.C1(clk_n),
		.D0(1'b0),
		.D1(1'b1),
		.CE(1'b1),
		.R(1'b0),
		.S(1'b0),
		.Q(ddr2_clk_raw)
	);
	
	OBUFDS ddr2_ck_obufds(.I(ddr2_clk_raw), .O(ddr2_ck_p), .OB(ddr2_ck_n));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Temporary data storage for READS
	
	reg[31:0] current_addr = 0;
	
	//Read data
	reg[127:0] read_data = 0;
	reg read_pending = 0;
	assign rd_data = read_data;
	
	//One-hot write enables for each of the four cycles in a burst
	reg[3:0] read_data_we_advance = 0;
	reg[3:0] read_data_we = 0;
	always @(posedge clk_p) begin
	
		read_data_we <= read_data_we_advance;
	
		if(read_data_we[0]) begin	
			read_data[15:0] <= ddr2_dq_in_0_buf;
			read_data[31:16] <= ddr2_dq_in_1_buf;
		end
		if(read_data_we[1]) begin
			read_data[47:32] <= ddr2_dq_in_0_buf;
			read_data[63:48] <= ddr2_dq_in_1_buf;
		end
		if(read_data_we[2]) begin
			read_data[79:64] <= ddr2_dq_in_0_buf;
			read_data[95:80] <= ddr2_dq_in_1_buf;
		end
		if(read_data_we[3]) begin
			read_data[111:96] <= ddr2_dq_in_0_buf;
			read_data[127:112] <= ddr2_dq_in_1_buf;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Temporary data storage for WRITES
	
	//Write data. Default to writing calibration dataset, then switch to real data once cal is done
	reg[127:0] write_data =
	{
		16'h5555, 16'haaaa,
		16'hffff, 16'h0000,
		16'h1234, 16'hedcb,
		16'h9abc, 16'h6543
	};
	reg write_pending = 0;
	
	reg[1:0] write_data_sel = 0;
	always @(posedge clk_p) begin
		case(write_data_sel)
			0: begin
				ddr2_dq_out_0 <= write_data[15:0];
				ddr2_dq_out_1 <= write_data[31:16];
			end
			1: begin
				ddr2_dq_out_0 <= write_data[47:32];
				ddr2_dq_out_1 <= write_data[63:48];
			end
			2: begin
				ddr2_dq_out_0 <= write_data[79:64];
				ddr2_dq_out_1 <= write_data[95:80];
			end
			3: begin
				ddr2_dq_out_0 <= write_data[111:96];
				ddr2_dq_out_1 <= write_data[127:112];
			end
		endcase
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
		
	//TOGO: Get these time values from external (NoC) logic
	//For now, assume constant 200 MHz clock, maximum CL
	localparam powerup_time = 50000;	//Power-up delay (200us)
	localparam cas_latency = 6;			//
	localparam  activate_to_rowop = 3;	//Trcd = 12.5ns = 3 cycles
	localparam  precharge_time = 15;	//Trp = 12.5ns = 3 cycles
										//For some reason this isn't working
	localparam refresh_interval = 1500;	//Refresh period
										//(slightly under the nominal 7.8us, rounded to allow room for bursts to complete)
	localparam refresh_time = 26;		//Trfc = 127.5 ns = 26 cycles

	//Delay stuff
	reg[15:0] delaycount = 0;
	reg delaycount_we = 0;
	reg[15:0] delaycount_init = 0;
	reg[15:0] delaycompare = powerup_time;
	reg[15:0] delaycompare_init = 0;
	reg delaycount_match = 0;
	always @(posedge clk_p) begin
		delaycount_match <= (delaycount + 16'h1) == delaycompare;
	end
	
	//Calibration status
	reg[7:0] calib_match_1 = 0;
	reg calib_match_2 = 0;
	reg calib_match_3 = 0;
	
	//Refresh timers
	reg refreshtime_reset = 0;
	reg[10:0] refreshtime = 0;
	
	//Root-level control states (one-hot coding tried but had poor timing performance)
	localparam STATE_WAIT		= 0;
	localparam STATE_STARTUP	= 1;
	localparam STATE_IDLE		= 2;
	localparam STATE_CALIB		= 3;
	localparam STATE_READ		= 4;	//should be same high-order bits
	localparam STATE_WRITE		= 5;
	localparam STATE_REFRESH	= 6;
	
	//Progress counters within one state
	(* MAX_FANOUT = "REDUCE" *) reg[3:0] startup_count = 0;
	(* MAX_FANOUT = "REDUCE" *) reg[3:0] calib_count = 0;
	(* MAX_FANOUT = "REDUCE" *) reg[3:0] rw_count = 0;
	(* MAX_FANOUT = "REDUCE" *) reg[3:0] refresh_count = 0;
	
	//Start up in the wait state doing the startup delay
	reg[6:0] state = STATE_WAIT;
	reg[6:0] state_next = STATE_STARTUP;
	reg[6:0] state_rw_next = STATE_STARTUP;
	reg state_is_calibration = 0;
	
	//Keep track of which row is currently open
	reg active_row_valid[7:0];
	reg[12:0] active_row_id[7:0];
	reg[12:0] current_row_id = 0;
	reg current_row_valid = 0;
	initial begin
		active_row_id[0] <= 0;
		active_row_valid[0] <= 0;
		active_row_id[1] <= 0;
		active_row_valid[1] <= 0;
		active_row_id[2] <= 0;
		active_row_valid[2] <= 0;
		active_row_id[3] <= 0;
		active_row_valid[3] <= 0;
		active_row_id[4] <= 0;
		active_row_valid[4] <= 0;
		active_row_id[5] <= 0;
		active_row_valid[5] <= 0;
		active_row_id[6] <= 0;
		active_row_valid[6] <= 0;
		active_row_id[7] <= 0;
		active_row_valid[7] <= 0;
	end
	reg active_row_we = 0;
	reg[12:0] active_row_din = 0;
	always @(posedge clk_p) begin
		if(active_row_we)
			active_row_id[current_addr[13:11]] <= active_row_din;
		current_row_id <= active_row_id[current_addr[13:11]];
	end
	
	/*
		Addressing scheme
		32 bits total
			31:27	Not implemented, must be zero
			26:14	Row address A[12:0]
			13:11	Bank address
			10:4	High 7 column address bits (column number)
					A[12:11] are don't cares for column address
					A[10] is auto-precharge select bit
			3:1		Low 3 column address bits (always 0)
			0		Always 0 (16-bit data bus)
			
		RAM is 8 banks x 8192 rows x 256 columns x 64 bits per entry
	 */
	
	reg refresh_needed = 0;
	always @(posedge clk_p) begin
		
		//default command: device selected, nop, address zero
		ddr2_ras_n_adv <= 1;
		ddr2_cas_n_adv <= 1;
		ddr2_we_n_adv <= 1;
		ddr2_addr_adv <= 0;
		
		//Enable on-die termination
		ddr2_odt <= 1;
		
		//Bump refresh timer
		if(refreshtime >= refresh_interval)
			refresh_needed <= 1;
		if(refreshtime_reset) begin
			refreshtime <= 0;
			refreshtime_reset <= 0;
			refresh_needed <= 0;
		end
		else
			refreshtime <= refreshtime + 11'h1;
		
		//Clear done flag
		done <= 0;
		
		//Not updating row IDs by default
		active_row_we <= 0;
		active_row_din <= 0;
		
		//Store pending read/write requests
		//Only legal if there is not already a read/write in progress
		if(wr_en && !state_is_calibration) begin
			current_addr <= addr;
			write_data <= wr_data;
			write_pending <= 1;
		end
		if(rd_en) begin
			current_addr <= addr;
			read_pending <= 1;
		end
		
		//Updated every cycle but only meaningful during calibration step 2
		calib_match_1[7] <= (read_data[127:112] == 16'h5555);
		calib_match_1[6] <= (read_data[111:96] == 16'haaaa);
		calib_match_1[5] <= (read_data[95:80] == 16'hffff);
		calib_match_1[4] <= (read_data[79:64] == 16'h0000);
		calib_match_1[3] <= (read_data[63:48] == 16'h1234);
		calib_match_1[2] <= (read_data[47:32] == 16'hedcb);
		calib_match_1[1] <= (read_data[31:16] == 16'h9abc);
		calib_match_1[0] <= (read_data[15:0] == 16'h6543);
		
		//Updated every cycle but only meaningful during calibration step 3
		calib_match_2 <= (calib_match_1 == 8'hff);
		
		//Updated every cycle but only meaningful during calibration step 4
		calib_match_3 <= calib_match_2;
		
		//Counter for delay stuff
		if(delaycount_we) begin
			delaycount_we <= 0;
			delaycount_init <= 0;
			delaycount <= delaycount_init + 16'h1;
			delaycompare <= delaycompare_init;
		end
		else
			delaycount <= delaycount + 16'h1;
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			//Idle - sit around and wait for stuff to do
			STATE_IDLE: begin			
				state_rw_next <= STATE_IDLE;
				refresh_count <= 0;
				rw_count <= 0;

				//For reads or writes:
				//Look up the currently active row and see if it's the same one we're about to use
				current_row_valid <= active_row_valid[current_addr[13:11]];

				//Refresh has first priority
				if(refresh_needed && !refreshtime_reset)
					state <= STATE_REFRESH;
				
				//If not refreshing, execute pending read/write request. Writes have priority.
				else if(write_pending)
					state <= STATE_WRITE;
				else if(read_pending)
					state <= STATE_READ;
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Initial physical-layer initialization
			STATE_STARTUP: begin
				startup_count <= startup_count + 4'h1;
				state_next <= STATE_STARTUP;
				
				//Default to 64 except in a few special cases
				delaycount_init <= 0;
				delaycompare_init <= 64;
				
				case(startup_count)
					
					//Wait >200us then turn on the clock enable and wait another >64 cycles
					0: begin
						ddr2_cke_adv <= 1;
						
						delaycount_we <= 1;
						delaycompare_init <= 128;
						state <= STATE_WAIT;
					end
					
					//Precharge all banks
					1: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 0;
						ddr2_addr_adv[10] <= 1;
						
						state <= STATE_WAIT;
						delaycount_we <= 1;
					end
					
					//Program EMR2 with all zeros
					2: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h2;		//EMR2
						ddr2_addr_adv <= 'h0;
						
						state <= STATE_WAIT;
						delaycount_we <= 1;
					end
					
					//Program EMR3 with all zeros
					3: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h3;		//EMR3
						ddr2_addr_adv <= 'h0;
						
						state <= STATE_WAIT;
						delaycount_we <= 1;
					end
					
					//Program initial physical-layer EMR settings
					4: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h1;		//EMR
						
						ddr2_addr_adv <= 0;			//Default values for all other settings
						ddr2_addr_adv[0] <= 0;		//DLL on
						ddr2_addr_adv[1] <= 0;		//Full drive strength
						ddr2_addr_adv[5:3] <= 0;	//Zero additive latency (TODO: is this right?)
						ddr2_addr_adv[6] <= 1;		//6, 2: ODT = 50 ohm
						ddr2_addr_adv[2] <= 1;
						
						state <= STATE_WAIT;
						delaycount_we <= 1;
					end
					
					//Reset DLL and set CAS latency
					5: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h0;		//EMR
						
						ddr2_addr_adv <= 0;				//Default values for all settings
						ddr2_addr_adv[2:0] <= 3'b011;	//8-word bursts
						ddr2_addr_adv[6:4] <= cas_latency;
						ddr2_addr_adv[8] <= 1;			//Reset DLL
						ddr2_addr_adv[11:9] <= 3'b111;	//Write recovery (leave it at maximum for now)
						
						state <= STATE_WAIT;
						delaycount_we <= 1;
						delaycompare_init <= 200;
					end
					
					//Precharge all banks
					6: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 0;
						ddr2_addr_adv[10] <= 1;
					
						delaycount_we <= 1;
						state <= STATE_WAIT;

						//Return from the wait directly into a refresh cycle
						state_rw_next <= STATE_STARTUP;
						state_next <= STATE_REFRESH;
					end
					
					//Auto refresh twice
					7: begin
						state_rw_next <= STATE_STARTUP;
						state <= STATE_REFRESH;
					end
					
					//DLL reset bit is self-clearing according to spec but clear it anyway just to be sure
					8: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h0;		//EMR
						
						ddr2_addr_adv <= 0;				//Default values for all settings
						ddr2_addr_adv[2:0] <= 3'b011;	//8-word bursts
						ddr2_addr_adv[6:4] <= cas_latency;
						ddr2_addr_adv[11:9] <= 3'b111;	//Write recovery (leave it at maximum for now)
						
						delaycount_we <= 1;
						state <= STATE_WAIT;
					end
					
					//Load EMR with OCD defaults
					9: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h1;				//EMR
						
						ddr2_addr_adv <= 0;				//Default values for all other settings
						ddr2_addr_adv[0] <= 0;			//DLL on
						ddr2_addr_adv[1] <= 0;			//Full drive strength
						ddr2_addr_adv[5:3] <= 0;		//Zero additive latency (TODO: is this right?)
						ddr2_addr_adv[6] <= 1;			//6, 2: ODT = 50 ohm
						ddr2_addr_adv[2] <= 1;
						ddr2_addr_adv[9:7] <= 3'b111;	//Enable OCD defaults
						
						delaycount_we <= 1;
						state <= STATE_WAIT;
					end
					
					//Disable OCD mode
					10: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						ddr2_ba_adv <= 'h1;				//EMR
						
						ddr2_addr_adv <= 0;				//Default values for all other settings
						ddr2_addr_adv[0] <= 0;			//DLL on
						ddr2_addr_adv[1] <= 0;			//Full drive strength
						ddr2_addr_adv[5:3] <= 0;		//Zero additive latency (TODO: is this right?)
						ddr2_addr_adv[6] <= 1;			//6, 2: ODT = 50 ohm
						ddr2_addr_adv[2] <= 1;
									
						delaycount_we <= 1;
						state <= STATE_WAIT;
						
						calib_count <= 0;
						state_next <= STATE_CALIB;
						state_is_calibration <= 1;
					end
					
				endcase			
			end	//end STATE_STARTUP
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// I/O delay calibration
			STATE_CALIB: begin
				state_rw_next <= STATE_CALIB;
				
				case(calib_count)
					
					//Initial write to get data into memory
					//Assume write timing is good enough but we need to calibrate our read stuff still
					0: begin
						//Do a write full of edges
						current_addr <= 0;
						rw_count <= 0;
						state <= STATE_WRITE;
						
						calib_count <= 1;
					end
					
					//Do a read
					1: begin
						current_addr <= 0;
						rw_count <= 0;
						state <= STATE_READ;
						
						calib_count <= 2;
					end
					
					//TODO: In between here, have a loop trying various I/O delay values
					//For the time being use a constant offset determined by experiment
					
					//Calibration is finished (hopefully)
					//Sanity check it
					2: begin
						//calib_match_1 gets written with the desired values at this time
						calib_count <= 3;
					end
					3: begin
						//calib_match_2 gets written with the desired values at this time
						calib_count <= 4;
					end
					4: begin
						//calib_match_3 gets written with the desired values at this time
						calib_count <= 5;
					end
					5: begin
						//Calibration success? Refresh and go to idle state
						if(calib_match_3) begin
							calib_done <= 1;
							
							refresh_count <= 0;
							state_rw_next <= STATE_IDLE;
							state <= STATE_REFRESH;
							
							state_is_calibration <= 0;
						end
						
						//POST failure
						//TODO: recalibrate?
						else begin
						end
					end
					
				endcase
			end	//end STATE_CALIB

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read datapath
			STATE_READ: begin
				rw_count <= rw_count + 4'h1;
				state_next <= STATE_READ;
				
				case(rw_count)
					
					0: begin
						
						//Look up the bank and row used by this command. See if the row is currently open.
						//If so, issue the write command immediately (without precharging and activating)
						if( current_row_valid && (current_row_id == current_addr[26:14]) ) begin
							rw_count <= 3;
						end
					end
						
					//Precharge the old row
					//(skip this if we're using the same row).
					1: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 0;
						ddr2_addr_adv[10] <= 0;		//precharge single bank
						
						ddr2_ba_adv <= current_addr[13:11];
					
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= precharge_time;
						state <= STATE_WAIT;
					end
				
					//Activate the target row
					//(skip this if the row is already activated).
					2: begin				
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 1;
						
						ddr2_addr_adv <= current_addr[26:14];
						ddr2_ba_adv <= current_addr[13:11];
						
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= activate_to_rowop - 1;
						state <= STATE_WAIT;
						
						//Make a note of the new active row
						active_row_we <= 1;
						active_row_din <= current_addr[26:14];
						active_row_valid[current_addr[13:11]] <= 1;
						
					end
					
					//Bank is activated, issue the read command
					3: begin
						//Read
						ddr2_ras_n_adv <= 1;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 1;
						
						//Specify the bank
						ddr2_ba_adv <= current_addr[13:11];
						
						//Column address
						ddr2_addr_adv[12:11] <= 0;
						ddr2_addr_adv[10] <= 0;						//no auto precharge
						ddr2_addr_adv[9:0] <= current_addr[10:1];
						
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= cas_latency + 2;
						state <= STATE_WAIT;
						
						//Will cause writes to the buffer every cycle during the CAS-to-RAS delay, but that's harmless
						read_data_we_advance <= 4'b0001;
					end
					
					4: begin
						read_data_we_advance <= 4'b0010;
					end
					5: begin
						read_data_we_advance <= 4'b0100;
					end
					6: begin
						read_data_we_advance <= 4'b1000;
					end
					7: begin
						read_data_we_advance <= 4'h0;
					end
					8: begin
					end
					
					//Done
					9: begin
					
						if(read_pending) begin
							read_pending <= 0;
							done <= 1;
						end
					
						rw_count <= 0;
						state <= state_rw_next;
					end
					
				endcase
			end
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Write datapath
			
			STATE_WRITE: begin
			 		 
				//Any function call we do here (to wait, etc) will return here
				state_next <= STATE_WRITE;
				
				//Always go on to the next state
				rw_count <= rw_count + 4'h1;
			 
				case(rw_count)
				
					0: begin
						
						//Look up the bank and row used by this command. See if the row is currently open.
						//If so, issue the write command immediately (without precharging)
						if( current_row_valid && (current_row_id == current_addr[26:14]) )
							rw_count <= 3;
					end
						
					//Precharge the old row
					//(skip this if the same row is being used again).
					1: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 0;
						ddr2_addr_adv[10] <= 0;		//precharge single bank
						
						ddr2_ba_adv <= current_addr[13:11];
					
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= precharge_time;
						state <= STATE_WAIT;
					end
				
					//Activate the target row
					//(skip this if the row is already activated).
					2: begin				
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 1;
						
						ddr2_addr_adv <= current_addr[26:14];
						ddr2_ba_adv <= current_addr[13:11];
						
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= activate_to_rowop - 1;
						state <= STATE_WAIT;
						
						//Make a note of the new active row
						active_row_we <= 1;
						active_row_din <= current_addr[26:14];
						active_row_valid[current_addr[13:11]] <= 1;
						
					end
					
					//Bank is activated, issue the write command
					3: begin
						//Write
						ddr2_ras_n_adv <= 1;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 0;
						
						//Specify the bank
						ddr2_ba_adv <= current_addr[13:11];
						
						//Column address
						ddr2_addr_adv[12:11] <= 0;
						ddr2_addr_adv[10] <= 0;						//no auto precharge
						ddr2_addr_adv[9:0] <= current_addr[10:1];
					end
					
					4: begin
						//Activate the output enables
						ddr2_oe_0_n <= 0;
						ddr2_oe_1_n <= 0;
						
						//Load the first data word into the output register
						write_data_sel <= 0;
						
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare <= cas_latency - 4;
						state <= STATE_WAIT;
					end
					
					//Send the first data words
					5: begin
						//Strobe DQS
						ddr2_udqs_out_0 <= 1;
						ddr2_ldqs_out_0 <= 1;
							
						//Load the next data word into the output register
						write_data_sel <= 1;
					end
					6: begin
						write_data_sel <= 2;
					end
					7: begin
						write_data_sel <= 3;
					end
					8: begin
					end
					9: begin
						ddr2_udqs_out_0 <= 0;
						ddr2_ldqs_out_0 <= 0;
					end
					10: begin
						ddr2_oe_0_n <= 1;
						ddr2_oe_1_n <= 1;
						
						write_pending <= 0;
						if(write_pending)
							done <= 1;
							
						rw_count <= 0;
						state <= state_rw_next;
					end
					
				endcase
			end	//end STATE_WRITE

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Refresh process
			STATE_REFRESH: begin
				state_next <= STATE_REFRESH;
				
				//Mark all rows as closed
				active_row_valid[0] <= 0;
				active_row_valid[1] <= 0;
				active_row_valid[2] <= 0;
				active_row_valid[3] <= 0;
				active_row_valid[4] <= 0;
				active_row_valid[5] <= 0;
				active_row_valid[6] <= 0;
				active_row_valid[7] <= 0;

				case(refresh_count)
					//Precharge all open banks (TODO: only do this if a bank is open)
					0: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 1;
						ddr2_we_n_adv <= 0;
						ddr2_addr_adv[10] <= 1;
					
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= precharge_time;
						state <= STATE_WAIT;
						state_next <= STATE_REFRESH;
					
						refresh_count <= 1;
					end
					
					1: begin
						ddr2_ras_n_adv <= 0;
						ddr2_cas_n_adv <= 0;
						ddr2_we_n_adv <= 1;
						
						delaycount_we <= 1;
						delaycount_init <= 0;
						delaycompare_init <= refresh_time;
						state <= STATE_WAIT;
						
						refresh_count <= 2;
					end
					
					2: begin
						refresh_count <= 0;
						refreshtime_reset <= 1;
						state <= state_rw_next;
					end
					
				endcase
			end
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Helper states
			
			//Wait N clock cycles, then go to state_next
			STATE_WAIT: begin
				if(delaycount_match)
					state <= state_next;
			end	//end STATE_WAIT

		endcase
	end
	
endmodule
