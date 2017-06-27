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

module PRBSTestBitstream(
	input wire clk,
    output reg[3:0] led = 0,
    inout wire scope_i2c_sda,
    inout wire scope_i2c_scl,
    input wire scope_out_p,
    input wire scope_out_n,
    output wire scope_le_p,
    output wire scope_le_n,
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
    // PLL for clocking everything

	wire[1:0]	unused_clkout;

	wire		clk_noc;
	wire		clk_prbs;
	wire		clk_sample;
	wire		clk_latch;

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
		.OUTPUT_GATE(6'b001111),		//Gate the outputs we use when not in use
		.OUTPUT_BUF_GLOBAL(6'b001111),	//Use BUFGs on everything
		.OUTPUT_BUF_LOCAL(6'b000000),	//Don't use BUFHs
		.IN0_PERIOD(10.000),			//100 MHz input
		.IN1_PERIOD(10.000),			//unused, but same as IN0
		.OUT0_MIN_PERIOD(8.000),		//125 MHz output for NoC
		.OUT1_MIN_PERIOD(4.000),		//250 MHz output for PRBS generation
		.OUT2_MIN_PERIOD(4.000),		//250 MHz output for sampling clock
		.OUT3_MIN_PERIOD(4.000),		//250 MHz output for comparator latch
		.OUT4_MIN_PERIOD(8.000),		//125 MHz output (unused)
		.OUT5_MIN_PERIOD(8.000),		//125 MHz output (unused)
		.ACTIVE_ON_START(1'b1),			//TEMP: Start doing stuff right off the bat
		.PRINT_CONFIG(1'b0)				//Don't print our default config since we're about to change it anyway
	) pll (
		.clkin({clk, clk}),				//feed PLL with clock before the BUFG so we get a new timing name
		.clksel(1'b0),
		.clkout({unused_clkout, clk_latch, clk_sample, clk_prbs, clk_noc}),
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

	//PLL reconfiguration state machine
	localparam	PLL_STATE_INIT_0			= 0;
	localparam	PLL_STATE_INIT_1			= 1;
	localparam	PLL_STATE_INIT_2			= 2;
	localparam	PLL_STATE_INIT_3			= 3;
	localparam	PLL_STATE_IDLE				= 4;
	localparam	PLL_STATE_SHIFT_0			= 5;
	localparam	PLL_STATE_SHIFT_1			= 6;
	localparam	PLL_STATE_SHIFT_2			= 7;
	localparam	PLL_STATE_SHIFT_3			= 8;

	reg[3:0]	pll_state					= PLL_STATE_INIT_0;

	//Commands for requesting dynamic phase shift
	reg			phase_start_noc		= 0;
	wire		phase_start;
	reg[8:0]	phase_off			= 0;

	reg			phase_done			= 0;
	wire		phase_done_noc;

    HandshakeSynchronizer sync_phase(
		.clk_a(clk_noc),
		.en_a(phase_start_noc),
		.ack_a(phase_done_noc),
		.busy_a(),	//we don't need the busy flag

		.clk_b(clk_bufg),
		.en_b(phase_start),
		.ack_b(phase_done)
	);

	wire[2:0] 	reconfig_output_idx_next	= reconfig_output_idx + 1'h1;
	always @(posedge clk_bufg) begin
		reconfig_start		<= 0;
		reconfig_finish		<= 0;
		reconfig_vco_en		<= 0;
		reconfig_output_en	<= 0;

		phase_done			<= 0;

		case(pll_state)

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// INIT: Load VCO configuration

			//Wait for busy flag to clear, then start the reconfig process
			PLL_STATE_INIT_0: begin
				if(!pll_busy) begin
					reconfig_start		<= 1;
					pll_state			<= PLL_STATE_INIT_1;
				end
			end	//end PLL_STATE_INIT_0

			//Reconfigure the VCO
			PLL_STATE_INIT_1: begin
				reconfig_vco_en			<= 1;
				reconfig_vco_mult		<= 25;	//1.25 GHz Fvco (800 ps per tick)
				reconfig_vco_indiv		<= 2;
				reconfig_vco_bandwidth	<= 1;

				reconfig_output_idx		<= 7;	//channel -1 (mod 8) so we wrap to 0 next cycle

				pll_state				<= PLL_STATE_INIT_2;
			end	//end PLL_STATE_INIT_1

			//Reconfigure our outputs with default initial config
			PLL_STATE_INIT_2: begin
				if(reconfig_cmd_done) begin

					//Go on to next channel
					reconfig_output_idx	<= reconfig_output_idx_next;

					case(reconfig_output_idx_next)

						0: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 10;	//125 MHz NoC
							reconfig_output_phase	<= 0;
						end

						1: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 5;	//250 MHz PRBS
							reconfig_output_phase	<= 0;	//No phase delay here
						end

						2: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 5;	//250 MHz sampling
							reconfig_output_phase	<= 0;
						end

						3: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 5;	//250 MHz latch
							reconfig_output_phase	<= 0;
						end

						4: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 10;	//125 MHz unused
							reconfig_output_phase	<= 0;
						end

						5: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 10;	//125 MHz unused
							reconfig_output_phase	<= 0;
						end

						//Done reconfiguring, start the PLL
						6: begin
							reconfig_finish		<= 1;
							pll_state			<= PLL_STATE_INIT_3;
						end

					endcase

				end
			end	//end PLL_STATE_INIT_2

			//Wait for PLL to lock
			PLL_STATE_INIT_3: begin
				if(pll_locked)
					pll_state					<= PLL_STATE_IDLE;
			end	//end PLL_STATE_INIT_3

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// IDLE - wait for interesting stuff to happen

			PLL_STATE_IDLE: begin
				if(phase_start) begin
					reconfig_start		<= 1;
					pll_state			<= PLL_STATE_SHIFT_0;
				end
			end	//end PLL_STATE_IDLE

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// SHIFT - apply a new phase shift

			PLL_STATE_SHIFT_0: begin
				reconfig_output_en		<= 1;
				reconfig_output_idx		<= 2;	//delay the sampling clock so we sample later in the waveform
				reconfig_output_div		<= 5;
				reconfig_output_phase	<= phase_off;
				pll_state				<= PLL_STATE_SHIFT_1;
			end	//end PLL_STATE_SHIFT_0

			PLL_STATE_SHIFT_1: begin
				if(reconfig_cmd_done) begin
					reconfig_output_en		<= 1;
					reconfig_output_idx		<= 3;	//delay the latch clock by 1/4 sampling clock (1000 ps)
													//so it doesn't toggle until we sample
					reconfig_output_div		<= 5;
					reconfig_output_phase	<= phase_off + 8'd10;
					pll_state				<= PLL_STATE_SHIFT_2;
				end
			end	//end PLL_STATE_SHIFT_1

			PLL_STATE_SHIFT_2: begin
				if(reconfig_cmd_done) begin
					reconfig_finish		<= 1;
					pll_state			<= PLL_STATE_SHIFT_3;
				end
			end	//end PLL_STATE_SHIFT_2

			PLL_STATE_SHIFT_3: begin
				if(pll_locked) begin
					pll_state			<= PLL_STATE_IDLE;
					phase_done			<= 1;
				end
			end	//end PLL_STATE_SHIFT_3

		endcase

		led[0]		<= pll_locked;

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

		//Point to point crossover connection
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
    // I/O buffers

    wire	cmp_le;

    OBUFDS obuf_cmp_le(
		.I(cmp_le),
		.O(scope_le_p),
		.OB(scope_le_n)
	);

	wire	cmp_out;
	IBUFDS ibuf_cmp_out(
		.I(scope_out_p),
		.IB(scope_out_n),
		.O(cmp_out)
	);

	//Drive comparator latch enable with a delayed version of our sampling clock.
	//This way it's nice and stable when we're ready to read it
    DDROutputBuffer #(
		.WIDTH(1)
	) le_ddrbuf (
		.clk_p(clk_latch),
		.clk_n(!clk_latch),
		.din0(1'b0),
		.din1(1'b1),
		.dout(cmp_le)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // I2C stuff

    reg			i2c_tx_en	= 0;
    wire		i2c_tx_ack;
    reg[7:0]	i2c_tx_data	= 0;

    reg			i2c_rx_en	= 0;
    reg			i2c_rx_ack	= 0;
    wire[7:0]	i2c_rx_data;
    wire		i2c_rx_rdy;

    reg			i2c_start_en	= 0;
    reg			i2c_restart_en	= 0;
    reg			i2c_stop_en		= 0;
    wire		i2c_busy;

    I2CTransceiver i2c_txvr(
		.clk(clk_noc),
		.clkdiv(16'd1000),		//125 kHz

		.i2c_scl(scope_i2c_scl),
		.i2c_sda(scope_i2c_sda),

		.tx_en(i2c_tx_en),
		.tx_ack(i2c_tx_ack),
		.tx_data(i2c_tx_data),

		.rx_en(i2c_rx_en),
		.rx_rdy(i2c_rx_rdy),
		.rx_out(i2c_rx_data),
		.rx_ack(i2c_rx_ack),

		.start_en(i2c_start_en),
		.restart_en(i2c_restart_en),
		.stop_en(i2c_stop_en),
		.busy(i2c_busy)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // RPC transceiver for talking to the host

    reg			rpc_fab_tx_en		= 0;
	wire		rpc_fab_tx_busy;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;

	reg			rpc_fab_rx_ready	= 1;	//start out ready
	wire		rpc_fab_rx_busy;
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;

	RPCv3Transceiver #(
		.DATA_WIDTH(/*NOC_WIDTH*/32),
		.QUIET_WHEN_IDLE(1),
		.LEAF_NODE(1),
		.NODE_ADDR(16'hfe00)
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
		.rpc_fab_tx_src_addr(16'h0000),
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
    // PRBS generator (locked to and higher speed than NoC clock)

    reg[2:0]	prbs_count		= 0;
    reg[6:0]	prbs_shreg		= 1;

	//Step the PRBS shift register by TWO bits per clock
    wire[6:0]	prbs_shreg_next = { prbs_shreg[5:0], prbs_shreg[6] ^ prbs_shreg[5] };
    wire[6:0]	prbs_shreg_next2 = { prbs_shreg_next[5:0], prbs_shreg_next[6] ^ prbs_shreg_next[5] };

	/*
	//and drive them out the pin at double rate
    DDROutputBuffer #(
		.WIDTH(1)
	) prbs_ddrbuf (
		.clk_p(clk_prbs),
		.clk_n(!clk_prbs),
		//.din0(1'b0),
		//.din1(1'b1),
		.din0(prbs_shreg[0]),
		//.din1(prbs_shreg[0]),
		.din1(prbs_shreg_next[0]),
		.dout(pmod_c[0])
	);
	*/

	//Drive out the CCLK pin b/c that's what we have a probe on
	STARTUPE2 #(
		.PROG_USR("FALSE"),
		.SIM_CCLK_FREQ(15.0)
	)
	startup (
		.CFGCLK(),
		.CFGMCLK(),
		.EOS(),
		.CLK(),
		.GSR(1'b0),
		.GTS(1'b0),
		.KEYCLEARB(1'b1),
		.PREQ(),
		.PACK(1'b0),

		.USRCCLKO(prbs_shreg[0]),
		.USRCCLKTS(1'b0),

		.USRDONEO(1'b1),
		.USRDONETS(1'b1)
		);

	assign pmod_dq[7:0] = 0;
	//assign pmod_dq[6:0] = 0;
	//assign pmod_dq[7] = prbs_shreg[0];

	always @(posedge clk_prbs) begin

		//DDR PRBS7 generator
		//prbs_shreg	<= prbs_shreg_next2;

		//SDR PRBS7 generator
		prbs_shreg	<= prbs_shreg_next;

		//Slow PRBS7 generator
		//prbs_count	<= prbs_count + 1'h1;
		//if(prbs_count == 0)
		//	prbs_shreg	<= prbs_shreg_next;

		//Squarewave at 1/4 rate
		//prbs_count	<= prbs_count + 1'h1;
		//if(prbs_count == 0)
		//	prbs_shreg		<= ~prbs_shreg;

		//Reset the shreg
		//Our clock is phase locked to, and faster than,  the NoC clock so this should be safe to use in the PRBS domain
		//(We're double speed so we're going to be held in reset for 2 clk_prbs cycles)
		if(sample_start_noc) begin
			prbs_count	<= 0;
			prbs_shreg	<= 1;
		end

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Sampling block

	reg			sample_start_noc	= 0;
	wire		sample_start;

	reg			sample_done			= 0;
	wire		sample_done_noc;

    HandshakeSynchronizer sync_sample(
		.clk_a(clk_noc),
		.en_a(sample_start_noc),
		.ack_a(sample_done_noc),
		.busy_a(),					//we don't need the busy flag

		.clk_b(clk_sample),
		.en_b(sample_start),
		.ack_b(sample_done)
	);

	reg[255:0]	samples				= 0;

	reg			sample_busy			= 0;
	reg[8:0]	sample_count		= 0;
	always @(posedge clk_sample) begin

		sample_done			<= 0;

		//Load samples into the shift register
		if(sample_busy) begin
			samples			<= {cmp_out, samples[255:1]};
			sample_count	<= sample_count + 1'h1;

			if(sample_count == 255) begin
				sample_busy	<= 0;
				sample_done	<= 1;
			end

		end

		//Start recording
		else if(sample_start) begin
			sample_busy		<= 1;
			sample_count	<= 0;
		end

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Main state machine

	localparam STATE_IDLE		= 0;
	localparam STATE_DAC_WAIT	= 1;
	localparam STATE_CAPTURE	= 2;
	localparam STATE_SEND		= 3;
	localparam STATE_PLL_WAIT	= 4;

    reg[7:0]	state = STATE_IDLE;

    reg			dac_wr_en	= 0;
    reg[15:0]	dac_code	= 0;
    reg			dac_done	= 0;

    reg[3:0]	block_count	= 0;

    `include "RPCv3Transceiver_types_localparam.vh"

    always @(posedge clk_noc) begin

		sample_start_noc		<= 0;
		phase_start_noc			<= 0;

		dac_wr_en				<= 0;
		rpc_fab_tx_en			<= 0;

		if(rpc_fab_rx_en)
			rpc_fab_rx_ready	<= 0;

		case(state)

			STATE_IDLE: begin

				//Wait for a message
				if(rpc_fab_rx_en) begin

					//Prepare to send response
					rpc_fab_tx_dst_addr	<= rpc_fab_rx_src_addr;
					rpc_fab_tx_type		<= rpc_fab_rx_type;
					rpc_fab_tx_callnum	<= rpc_fab_rx_callnum;
					rpc_fab_tx_d0		<= rpc_fab_rx_d0;
					rpc_fab_tx_d1		<= 1;
					rpc_fab_tx_d2		<= 2;

					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin

						//Prepare to return response
						rpc_fab_tx_type	<= RPC_TYPE_RETURN_SUCCESS;

						case(rpc_fab_rx_callnum)

							//Set up DAC
							0: begin
								dac_wr_en			<= 1;
								dac_code			<= rpc_fab_rx_d0[15:0];
								state				<= STATE_DAC_WAIT;
							end

							//Capture a waveform
							1: begin
								sample_start_noc	<= 1;
								state				<= STATE_CAPTURE;
							end

							//Adjust PLL phase offset
							2: begin
								phase_start_noc		<= 1;
								phase_off			<= rpc_fab_rx_d0[8:0];
								state				<= STATE_PLL_WAIT;
							end

						endcase
					end

				end

			end	//end STATE_IDLE

			//Wait for DAC to be done
			STATE_DAC_WAIT: begin
				if(dac_done) begin
					rpc_fab_rx_ready	<= 1;
					rpc_fab_tx_en		<= 1;
					state				<= STATE_IDLE;
				end
			end	//end STATE_DAC_WAIT

			//Wait for PLL to be done
			STATE_PLL_WAIT: begin
				if(phase_done_noc) begin
					rpc_fab_rx_ready	<= 1;
					rpc_fab_tx_en		<= 1;
					state				<= STATE_IDLE;
				end
			end

			STATE_CAPTURE: begin
				led[1]					<= 1;
				if(sample_done_noc) begin
					led[2]				<= 1;

					//Send our 256 samples, 64 at a time, over 4 messages.
					//Kick off the first one now and do the rest in the next state
					rpc_fab_tx_d1		<= samples[0 +: 32];
					rpc_fab_tx_d2		<= samples[32 +: 32];
					rpc_fab_tx_en		<= 1;
					block_count			<= 1;
					state				<= STATE_SEND;
				end

			end	//end STATE_CAPTURE

			STATE_SEND: begin

				if(rpc_fab_tx_done) begin

					led[3]						<= 1;

					block_count					<= block_count + 1'h1;

					case(block_count)

						1: begin
							rpc_fab_tx_d1		<= samples[64 +: 32];
							rpc_fab_tx_d2		<= samples[96 +: 32];
							rpc_fab_tx_en		<= 1;
						end

						2: begin
							rpc_fab_tx_d1		<= samples[128 +: 32];
							rpc_fab_tx_d2		<= samples[160 +: 32];
							rpc_fab_tx_en		<= 1;
						end

						3: begin
							rpc_fab_tx_d1		<= samples[192 +: 32];
							rpc_fab_tx_d2		<= samples[224 +: 32];
							rpc_fab_tx_en		<= 1;

							//done after this
							rpc_fab_rx_ready	<= 1;
							state				<= STATE_IDLE;
						end

					endcase

				end

			end	//end STATE_SEND

		endcase
    end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Control the DAC

    reg[2:0] dac_state = 0;

    always @(posedge clk_noc) begin

		i2c_tx_en		<= 0;
		i2c_rx_en		<= 0;
		i2c_start_en	<= 0;
		i2c_restart_en	<= 0;
		i2c_stop_en		<= 0;

		i2c_rx_ack		<= 1;

		dac_done		<= 0;

		case(dac_state)

			0: begin
				if(dac_wr_en) begin
					i2c_start_en	<= 1;
					dac_state		<= 1;
				end
			end

			1: begin
				if(!i2c_start_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= {4'b1100, 3'b000, 1'b0};			//Write to an MCP47x6A0 (address LSBs 3'b000)
					dac_state	<= 2;
				end
			end

			2: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= {3'b010, 2'b00, 2'b00, 1'b0};	//write volatile memory
																	//Vref = Vdd
																	//not powering down
																	//gain of 1
					dac_state	<= 3;
				end
			end

			3: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= dac_code[15:8];	//eight high bits of DAC (left justified)
					dac_state	<= 4;
				end
			end

			4: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= dac_code[7:0];	//four low bits of DAC (left justified)
					dac_state	<= 5;
				end
			end

			5: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_stop_en	<= 1;
					dac_state	<= 0;
					dac_done	<= 1;
				end
			end

		endcase

    end

endmodule
