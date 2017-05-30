/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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

module GreenpakTimingTestBitstream(
	input wire clk,
    output reg[3:0] led,

    inout wire[7:0] pmod_dq
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The Zynq CPU (not actually used for anything for now, just to make DRC shut up)

    // Only define this if we're targeting a Zynq part
	`ifdef XILINX_ZYNQ7

	XilinxZynq7CPU cpu(
		.cpu_jtag_tdo(),
		.cpu_jtag_tdi(1'b0),
		.cpu_jtag_tms(1'b0),
		.cpu_jtag_tck(1'b0),

		//Don't use any of these signals
		.__nowarn_528_cpu_clk(),
		.__nowarn_528_cpu_por_n(),
		.__nowarn_528_cpu_srst_n()
	);

	`endif

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Buffer the main system clock

	wire clk_bufg;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) sysclk_clkbuf (
		.clkin(clk),
		.clkout(clk_bufg),
		.ce(1'b1)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// PLL to turn our 100 MHz system clock into 200 for the IO delay line

	wire[3:0]	unused_clkout;

	wire		clk_noc;
	wire		clk_iodelay;

	wire		pll_locked;

	wire		pll_busy;

	reg			reconfig_start			= 0;
	reg			reconfig_finish			= 0;
	wire		reconfig_cmd_done;

	reg			reconfig_vco_en			= 0;
	reg[6:0]	reconfig_vco_mult		= 0;
	reg[6:0]	reconfig_vco_indiv		= 0;
	reg			reconfig_vco_bandwidth	= 0;

	reg			reconfig_output_en		= 0;
	reg[2:0]	reconfig_output_idx		= 0;
	reg[7:0]	reconfig_output_div		= 0;
	reg[8:0]	reconfig_output_phase	= 0;

    ReconfigurablePLL #(
		.OUTPUT_GATE(6'b000011),		//Gate the outputs we use when not in use
		.OUTPUT_BUF_GLOBAL(6'b000011),	//Use BUFGs on everything
		.OUTPUT_BUF_LOCAL(6'b000000),	//Don't use BUFHs
		.IN0_PERIOD(10.000),			//100 MHz input
		.IN1_PERIOD(10.000),			//unused, but same as IN0
		.OUT0_MIN_PERIOD(5.000),		//200 MHz output for NoC
		.OUT1_MIN_PERIOD(5.000),		//200 MHz output for IO delay calibration
		.OUT2_MIN_PERIOD(5.000),		//100 MHz output (unused)
		.OUT3_MIN_PERIOD(5.000),		//100 MHz output (unused)
		.OUT4_MIN_PERIOD(5.000),		//100 MHz output (unused)
		.OUT5_MIN_PERIOD(5.000),		//100 MHz output (unused)
		.ACTIVE_ON_START(1'b0),			//Don't do anything until reset
		.PRINT_CONFIG(1'b0)				//Don't print our default config since we're about to change it anyway
	) pll (
		.clkin({clk_bufg, clk_bufg}),	//feed PLL with clock before the BUFG so we get a new timing name
		.clksel(1'b0),
		.clkout({unused_clkout, clk_iodelay, clk_noc}),
		.reset(1'b0),
		.locked(pll_locked),

		.busy(pll_busy),
		.reconfig_clk(clk_bufg),
		.reconfig_start(reconfig_start),
		.reconfig_finish(reconfig_finish),
		.reconfig_cmd_done(reconfig_cmd_done),

		.reconfig_vco_en(reconfig_vco_en),
		.reconfig_vco_mult(reconfig_vco_mult),
		.reconfig_vco_indiv(reconfig_vco_indiv),
		.reconfig_vco_bandwidth(reconfig_vco_bandwidth),

		.reconfig_output_en(reconfig_output_en),
		.reconfig_output_idx(reconfig_output_idx),
		.reconfig_output_div(reconfig_output_div),
		.reconfig_output_phase(reconfig_output_phase)
		);

	//Set up the PLL (TODO: tweak coefficients etc)
	reg[3:0] pll_reconfig_state = 0;
	always @(posedge clk_bufg) begin
		reconfig_start		<= 0;
		reconfig_finish		<= 0;
		reconfig_vco_en		<= 0;
		reconfig_output_en	<= 0;

		case(pll_reconfig_state)

			0: begin
				if(!pll_busy) begin
					reconfig_start		<= 1;
					pll_reconfig_state	<= 1;
				end
			end

			1: begin
				if(!reconfig_start) begin
					reconfig_vco_en			<= 1;
					reconfig_vco_indiv		<= 1;
					reconfig_vco_mult		<= 10;	//1 GHz Fvco
					reconfig_vco_bandwidth	<= 1;
					pll_reconfig_state		<= 2;
				end
			end

			2: begin
				if(reconfig_cmd_done) begin
					reconfig_output_en		<= 1;
					reconfig_output_idx		<= 0;	//clk_noc
					reconfig_output_div		<= 5;	//200 MHz
					reconfig_output_phase	<= 0;
					pll_reconfig_state		<= 3;
				end
			end

			3: begin
				if(reconfig_cmd_done) begin
					reconfig_output_en		<= 1;
					reconfig_output_idx		<= 1;	//clk_iodelay
					reconfig_output_div		<= 5;	//200 MHz
					reconfig_output_phase	<= 0;
					pll_reconfig_state		<= 4;
				end
			end

			4: begin
				if(reconfig_cmd_done) begin
					reconfig_finish			<= 1;
					pll_reconfig_state		<= 5;
				end
			end

			5: begin
				//done, hang forever
			end

		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The debug bridge

    wire		rpc_tx_en;
    wire[31:0]	rpc_tx_data;
    wire		rpc_tx_ready;

    wire		rpc_rx_en;
    wire[31:0]	rpc_rx_data;
    wire		rpc_rx_ready;

    JtagDebugBridge #(
		.NOC_WIDTH(32)
    ) bridge(
		.clk(clk_noc),

		//RPC interface (crossed over)
		.rpc_tx_en(rpc_rx_en),
		.rpc_tx_data(rpc_rx_data),
		.rpc_tx_ready(rpc_rx_ready),

		.rpc_rx_en(rpc_tx_en),
		.rpc_rx_data(rpc_tx_data),
		.rpc_rx_ready(rpc_tx_ready),

		//Debug indicators
		.led()
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Transceiver for our debug stuff

    `include "RPCv3Transceiver_types_localparam.vh"

	reg			rpc_fab_rx_ready	= 1;
	wire		rpc_fab_rx_busy;
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;

	wire		rpc_fab_tx_busy;
	wire		rpc_fab_tx_done;
	reg			rpc_fab_tx_en		= 0;
	reg[15:0]	rpc_fab_tx_src_addr	= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;

	RPCv3Transceiver #(
		.DATA_WIDTH(32),
		.QUIET_WHEN_IDLE(1),
		.NODE_ADDR(16'h8000),
		.LEAF_NODE(1)
	) rpc_txvr (
		.clk(clk_noc),

		//Network side
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ready(rpc_tx_ready),
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ready(rpc_rx_ready),

		//Fabric side
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_busy(rpc_fab_tx_busy),
		.rpc_fab_tx_src_addr(rpc_fab_tx_src_addr),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),

		.rpc_fab_rx_ready(rpc_fab_rx_ready),
		.rpc_fab_rx_busy(rpc_fab_rx_busy),
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2)
		);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Calibrate the I/O delays

    IODelayCalibration delaycal(.refclk(clk_iodelay));

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // I/O buffers

    wire[2:0]	sample_in;
    reg			test_out = 0;
    reg[1:0]	drive_channel		= 0;

    /*
		PIN MAPPING

		pmod_dq[0] = DQ1 = P3
		pmod_dq[1] = DQ3 = P5
		pmod_dq[2] = DQ4 = P12
		pmod_dq[3] = DQ6 = P14
		pmod_dq[4] = DQ0 = P2 (input only!!)
		pmod_dq[5] = DQ2 = P4
		pmod_dq[6] = DQ5 = P13
		pmod_dq[7] = DQ7 = P15
	 */

    //Unused signals, for now
	assign pmod_dq[2]	= 1'b0;		//P12
	assign pmod_dq[3]	= 1'b0;		//P14
	assign pmod_dq[4]	= 1'b0;		//P2
	assign pmod_dq[6]	= 1'b0;		//P13
	assign pmod_dq[7]	= 1'b0;		//P15

    //P3 on greenpak
    IOBUF iobuf_dq0(
		.I(test_out),
		.T(drive_channel != 0),
		.O(sample_in[0]),
		.IO(pmod_dq[0])
	);

	//P5 on greenpak
    IOBUF iobuf_dq1(
		.I(test_out),
		.T(drive_channel != 1),
		.O(sample_in[1]),
		.IO(pmod_dq[1])
	);

	//P4 on greenpak
	IOBUF iobuf_dq5(
		.I(test_out),
		.T(drive_channel != 2),
		.O(sample_in[2]),
		.IO(pmod_dq[5])
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // I/O pin mapping and input delay lines

    //The delay line
	//Each tap is 1 / (64 * Fref) or 78 ps
	//Full scale on the delay is 32 taps or 2.5 ns.
	//This is, conveniently enough, the exact spacing between DDR phases!
	reg[4:0]	delay_val = 0;
	wire[4:0]	delay_reg[3:0];
	reg			delay_load	= 0;

	wire		test_in_delayed[3:0];
	wire[1:0]	test_in_arr[3:0];
	genvar i;
	generate
		for(i=0; i<3; i=i+1) begin : delayblock

			//Delay the signal
			IDELAYE2 #(
				.CINVCTRL_SEL("FALSE"),
				.DELAY_SRC("IDATAIN"),
				.HIGH_PERFORMANCE_MODE("TRUE"),
				.IDELAY_TYPE("VAR_LOAD"),
				.IDELAY_VALUE(0),
				.PIPE_SEL("FALSE"),
				.REFCLK_FREQUENCY(200),
				.SIGNAL_PATTERN("DATA")
			) idelay (
				.C(clk_noc),
				.CE(1'b0),
				.CINVCTRL(1'b0),
				.CNTVALUEIN(delay_val),
				.CNTVALUEOUT(delay_reg[i]),
				.DATAIN(),			//from FPGA fabric, not used
				.DATAOUT(test_in_delayed[i]),
				.IDATAIN(sample_in[i]),
				.INC(1'b1),
				.LD(delay_load),
				.LDPIPEEN(1'b0),
				.REGRST(1'b0)
			);

			//then de-serialize it
			IDDR #(
				.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
				.INIT_Q1(0),
				.INIT_Q2(0),
				.SRTYPE("SYNC")
			) ddr1 (
				.Q1(test_in_arr[i][1]),
				.Q2(test_in_arr[i][0]),
				.C(clk_noc),
				.CE(1'b1),
				.D(test_in_delayed[i]),
				.R(1'b0),
				.S(1'b0)
			);

		end
	endgenerate

	//tie off unused channel 4
	assign test_in_delayed[3] = 0;
	assign test_in_arr[3] = 2'h0;
	assign delay_reg[3] = 5'h0;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Main state machine

	localparam STATE_IDLE 		 	= 0;
	localparam STATE_TESTING	 	= 1;
	localparam STATE_TEST_WAIT_0	= 2;
	localparam STATE_TEST_WAIT_1	= 3;
	localparam STATE_TX_WAIT	 	= 4;

	reg[3:0] 	state	= STATE_IDLE;
	reg[15:0] 	count	= 0;

	always @(*)
		led[3]		<= pll_locked;

	reg[1:0]		sample_channel		= 0;

    always @(posedge clk_noc) begin

		//Clear single-cycle flags
		delay_load				<= 0;
		rpc_fab_tx_en			<= 0;

		//TODO: better flow control?
		rpc_fab_rx_ready		<= 1;

		case(state)

			//Sit around and wait for a message
			STATE_IDLE: begin

				//Drive the output low
				test_out				<= 0;

				//If we get a message, doesn't matter what it is, run a test
				if(rpc_fab_rx_en) begin
					led[2:0]			<= 3'h2;

					delay_val			<= rpc_fab_rx_d0[4:0];
					delay_load			<= 1;

					sample_channel		<= rpc_fab_rx_d1[1:0];
					drive_channel		<= rpc_fab_rx_d1[3:2];

					//Prepare to reply
					rpc_fab_tx_src_addr	<= rpc_fab_rx_dst_addr;	//loop back src/dst address
					rpc_fab_tx_dst_addr	<= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum	<= rpc_fab_rx_callnum;
					rpc_fab_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
					rpc_fab_tx_d0		<= 0;
					rpc_fab_tx_d1		<= 0;
					rpc_fab_tx_d2		<= 0;

					count				<= 0;

					state				<= STATE_TEST_WAIT_0;
				end

			end	//end STATE_IDLE

			STATE_TEST_WAIT_0: begin

				//Wait until delay line finishes updating
				if( (delay_val == delay_reg[0]) && (delay_val == delay_reg[1]) ) begin
					test_out			<= 1;
					state				<= STATE_TESTING;
				end

			end

			STATE_TESTING: begin

				//Bump count by 1 since it counts the number of SDR cycles (DDR cycles are 2x this)
				count			<= count + 1'h1;

				//Push new data down the shift register for debugging
				rpc_fab_tx_d1			<= {rpc_fab_tx_d1[30:0], test_in_arr[sample_channel][0]};
				rpc_fab_tx_d2			<= {rpc_fab_tx_d2[30:0], test_in_arr[sample_channel][1]};

				//We're done if we hit the maximum count value, or if either bit goes high
				if(test_in_arr[sample_channel]) begin

					//EVEN phase
					if(test_in_arr[sample_channel][0] == test_in_arr[sample_channel][1])
						rpc_fab_tx_d0		<= {count, 1'h0};

					//ODD phase
					else
						rpc_fab_tx_d0		<= {count, 1'h1};


					led[2:0]				<= 3'h3;
					rpc_fab_tx_en			<= 1;
					state					<= STATE_TX_WAIT;
				end

				else if(count == 16'hffff) begin
					led[2:0]		<= 3'h5;
					rpc_fab_tx_type	<= RPC_TYPE_RETURN_FAIL;
					rpc_fab_tx_en	<= 1;
					state			<= STATE_TX_WAIT;
				end

			end	//end STATE_TESTING

			//Wait for send to complete
			STATE_TX_WAIT: begin
				if(rpc_fab_tx_done) begin
					led[2:0]		<= 3'h4;
					state			<= STATE_IDLE;
				end
			end	//end STATE_TX_WAIT

		endcase

    end

endmodule
