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
    inout wire[7:0] pmod_c
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

	wire[5:0]	pll_clkout;
	wire		pll_locked;

	wire		clk_noc		= pll_clkout[0];
	wire		clk_prbs	= pll_clkout[1];
	wire		clk_sample	= pll_clkout[2];

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
		.OUTPUT_GATE(6'b000111),		//Gate the outputs we use when not in use
		.OUTPUT_BUF_GLOBAL(6'b000111),	//Use BUFGs on everything
		.OUTPUT_BUF_LOCAL(6'b000000),	//Don't use BUFHs
		.IN0_PERIOD(8.000),				//125 MHz input
		.IN1_PERIOD(8.000),				//unused, but same as IN0
		.OUT0_MIN_PERIOD(8.000),		//125 MHz output for NoC
		.OUT1_MIN_PERIOD(4.000),		//250 MHz output for PRBS generation
		.OUT2_MIN_PERIOD(4.000),		//250 MHz output for sampling clock
		.OUT3_MIN_PERIOD(8.000),		//125 MHz output (unused)
		.OUT4_MIN_PERIOD(8.000),		//125 MHz output (unused)
		.OUT5_MIN_PERIOD(8.000),		//125 MHz output (unused)
		.ACTIVE_ON_START(1'b1),			//TEMP: Start doing stuff right off the bat
		.PRINT_CONFIG(1'b0)				//Don't print our default config since we're about to change it anyway
	) pll (
		.clkin({clk_bufg, clk_bufg}),
		.clksel(1'b0),
		.clkout(pll_clkout),
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
			// INIT: Load VCO configuration (8x multiplier)

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
				reconfig_vco_mult		<= 8;	//1 GHz Fvco (1000 ps per tick)
				reconfig_vco_indiv		<= 1;
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
							reconfig_output_div		<= 8;	//125 MHz NoC
							reconfig_output_phase	<= 0;
						end

						1: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 4;	//250 MHz PRBS
							reconfig_output_phase	<= 0;
						end

						2: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 4;	//250 MHz sampling
							reconfig_output_phase	<= 0;	//No phase shift yet
						end

						3: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 8;	//125 MHz unused
							reconfig_output_phase	<= 0;
						end

						4: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 8;	//125 MHz unused
							reconfig_output_phase	<= 0;
						end

						5: begin
							reconfig_output_en		<= 1;
							reconfig_output_div		<= 8;	//125 MHz unused
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
				reconfig_output_idx		<= 2;	//reconfigure the sampling clock
				reconfig_output_div		<= 4;
				reconfig_output_phase	<= phase_off;
				pll_state				<= PLL_STATE_SHIFT_1;
			end	//end PLL_STATE_SHIFT_0

			PLL_STATE_SHIFT_1: begin
				if(reconfig_cmd_done) begin
					reconfig_finish		<= 1;
					pll_state			<= PLL_STATE_SHIFT_2;
				end
			end	//end PLL_STATE_SHIFT_1

			PLL_STATE_SHIFT_2: begin
				if(pll_locked) begin
					pll_state			<= PLL_STATE_IDLE;
					phase_done			<= 1;
				end
			end	//end PLL_STATE_SHIFT_2

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

    reg	prbs_out	= 0;	//Drive low by default since nothing interesting is happening

    //Drive PRBS single ended, tie off the adjacent signal to prevent noise from coupling into it
    assign pmod_c[0] = prbs_out;
    assign pmod_c[1] = 1'b0;

    reg		cmp_le = 1;

    OBUFDS obuf_cmp_le(
		.I(cmp_le),
		.O(pmod_c[4]),
		.OB(pmod_c[5])
	);

	wire	cmp_out;
	IBUFDS ibuf_cmp_out(
		.I(pmod_c[6]),
		.IB(pmod_c[7]),
		.O(cmp_out)
	);

	//TODO: OSERDES for driving the PRBS at higher than fabric clock rates

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

		.i2c_scl(pmod_c[3]),
		.i2c_sda(pmod_c[2]),

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

    reg			prbs_reset 	= 0;
    reg[1:0]	prbs_count	= 0;

	always @(posedge clk_prbs) begin

		//Fake PRBS generator (squarewave at 31 MHz)
		prbs_count		<= prbs_count + 1'h1;
		if(prbs_count == 0)
			prbs_out	<= ~prbs_out;

		if(prbs_reset) begin
			prbs_count	<= 0;
			prbs_out	<= 0;
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
		.busy_a(),	//we don't need the busy flag

		.clk_b(clk_sample),
		.en_b(sample_start),
		.ack_b(sample_done)
	);

	reg[255:0]	samples				= 0;

	reg			sample_busy			= 0;
	reg[8:0]	sample_count		= 0;
	always @(posedge clk_sample) begin

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

		//Reset the PRBS generator as needed
		//TODO: synchronize this once we get to larger phase offsets
		prbs_reset	<= !sample_busy;

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
				if(sample_done_noc) begin

					//Send our 256 samples, 64 at a time, over 4 messages.
					//Kick off the first one now
					rpc_fab_tx_d1		<= samples[0 +: 32];
					rpc_fab_tx_d2		<= samples[32 +: 32];
					rpc_fab_tx_en		<= 1;
					block_count			<= 1;
					state				<= STATE_SEND;
				end

			end	//end STATE_CAPTURE

			STATE_SEND: begin

				if(rpc_fab_tx_done) begin

					block_count			<= block_count + 1'h1;

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
