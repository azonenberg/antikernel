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

module SPIFlashTestBitstream(
    inout wire[7:0] pmod_dq,

    //output reg		starting = 0,

    inout wire[3:0] flash_dq,
    output wire		flash_cs_n,

    input wire		uart_rxd,
    output wire		uart_txd,

    output reg[3:0] led	= 0
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
    // Internal clock source

    wire intosc;
    wire cclk;					//FIXME
    wire cclk_tris	= 0;		//forums say LOW is enable

	STARTUPE2 #(
		.PROG_USR("FALSE"),		//Don't lock resets (requires encrypted bitstream)
		.SIM_CCLK_FREQ(15.0)	//Default to 66 MHz clock for simulation boots
	)
	startup (
		.CFGCLK(),				//Configuration clock not used
		.CFGMCLK(intosc),		//Internal configuration oscillator
		.EOS(),					//End-of-startup ignored
		.CLK(),					//Configuration clock not used
		.GSR(1'b0),				//Not using GSR
		.GTS(1'b0),				//Not using GTS
		.KEYCLEARB(1'b1),		//Not zeroizing BBRAM
		.PREQ(),				//PROG_B request not used
		.PACK(1'b0),			//PROG_B ack not used

		.USRCCLKO(cclk),		//CCLK pin
		.USRCCLKTS(cclk_tris),	//Assert to tristate CCLK

		.USRDONEO(1'b1),		//Hold DONE pin high
		.USRDONETS(1'b1)		//Do not tristate DONE pin
								//This is weird - seems like opposite polarity from every other TS pin!
		);

	wire intosc_bufg;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) bufg_intosc (
		.clkin(intosc),
		.clkout(intosc_bufg),
		.ce(1'b1)
	);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Identify this device as an indirect SPI flash programmer

    JtagUserIdentifier #(
		.IDCODE_VID(24'h42445a),	//"ADZ"
		.IDCODE_PID(8'h01)			//Indirect SPI programming
    ) id (
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The JTAG interface

    reg[31:0]	tx_shreg = 0;
	reg[31:0]	rx_shreg = 0;

	wire		tap_active;
	wire		tap_shift;
	wire		tap_clear;
	wire		tap_tck_raw;
	wire		tap_tck_bufh;
	wire		tap_tdi;
	wire		tap_reset;

    JtagTAP #(
		.USER_INSTRUCTION(2)
	) tap_debug (
		.instruction_active(tap_active),
		.state_capture_dr(tap_clear),
		.state_reset(tap_reset),
		.state_runtest(),
		.state_shift_dr(tap_shift),
		.state_update_dr(),
		.tck(tap_tck_raw),
		.tck_gated(),
		.tms(),
		.tdi(tap_tdi),
		.tdo(tx_shreg[0])
	);

	//Buffer the clock b/c ISE is derpy and often won't instantiate a buffer (woo skew!)
	//TODO: according to comments in older code BUFHs here sometimes won't work in spartan6?
	ClockBuffer #(
		.TYPE("LOCAL"),
		.CE("NO")
	) tap_tck_clkbuf (
		.clkin(tap_tck_raw),
		.clkout(tap_tck_bufh),
		.ce(1'b1)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Synchronize TAP reset request over to internal clock domain.

	reg tap_reset_ff = 0;
	reg jtag_side_reset = 0;
	always @(posedge tap_tck_bufh) begin
		tap_reset_ff	<= tap_reset;
		jtag_side_reset	<= tap_reset && !tap_reset_ff;
	end

	wire	core_side_reset;
	HandshakeSynchronizer sync_tap_reset(
		.clk_a(tap_tck_bufh),
		.en_a(jtag_side_reset),
		.ack_a(),					//We don't need a reset acknowledgement.
									//As long as the internal clock isn't more than ~30x slower than the JTAG clock,
									//the reset will complete long before anything can happen
		.busy_a(),					//No need to check for busy state, resetting during a reset is a no-op

		.clk_b(intosc_bufg),
		.en_b(core_side_reset),
		.ack_b(core_side_reset),	//Acknowledge the reset as soon as we get it
		.busy_b()
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Convert JTAG data from a stream of bits to a stream of 32-bit words

	reg[4:0] phase = 0;
	always @(posedge tap_tck_bufh) begin

		//Use the capture-dr -> shift-dr transition to word align our data
		if(tap_clear)
			phase	<= 0;

		//Nothign fancy happening, just go to the next bit
		else if(tap_shift)
			phase	<= phase + 1'h1;

	end

	//TX data shift register
	reg[31:0]	tx_data			= 0;
	reg			tx_data_needed	= 0;
	always @(posedge tap_tck_bufh) begin

		tx_data_needed		<= 0;

		if(!tap_active) begin
		end

		//Load the next word of data
		else if(tap_clear || (tap_shift && phase == 31) )
			tx_shreg		<= tx_data;

		//Send stuff
		else if(tap_shift)
			tx_shreg		<= { 1'b0, tx_shreg[31:1] };

		//If we are almost done with the current word, ask for another one
		if(tap_shift && phase == 29)
			tx_data_needed	<= 1;

	end

	//RX data shift register
	reg			rx_valid = 0;

	always @(posedge tap_tck_bufh) begin
		rx_valid	<= 0;

		if(!tap_active) begin
		end

		//Receive stuff
		else if(tap_shift) begin
			rx_shreg		<= { tap_tdi, rx_shreg[31:1] };

			if(phase == 31)
				rx_valid	<= 1;
		end

	end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The flash controller

    wire		cmd_en_sync;
    reg[3:0]	cmd_id			= FLASH_OP_READ;
    reg[15:0]	cmd_len			= 0;
    reg[31:0]	cmd_addr		= 0;
    wire[7:0]	read_data;
    wire		read_valid;
    wire[7:0]	write_data;
    reg			write_valid		= 0;
    wire		write_ready;

    wire[15:0]	capacity_mbits;

    wire		flash_busy;

    wire		la_ready;

    QuadSPIFlashController #(
		.QUAD_DISABLE(1)		//no quad mode yet
    ) ctrl (
		.clk(intosc_bufg),
		.clkdiv(16'd4),			//4x slower than internal clock (~16 MHz typ)

		.spi_sck(cclk),
		.spi_dq(flash_dq),
		.spi_cs_n(flash_cs_n),

		.cmd_en(cmd_en_sync),
		.cmd_id(cmd_id),
		.cmd_len(cmd_len),
		.cmd_addr(cmd_addr),
		.read_data(read_data),
		.read_valid(read_valid),
		.write_data(write_data),
		.write_valid(write_valid),
		.write_ready(write_ready),
		.busy(flash_busy),

		.capacity_mbits(capacity_mbits),

		//DEBUG
		//.uart_rxd(uart_rxd),
		//.uart_txd(uart_txd),

		.start(1'b1)
		);

	//Generate a single-cycle "done" flag
	reg			flash_done		= 0;
	reg			flash_busy_ff	= 0;

	always @(posedge intosc_bufg) begin
		flash_busy_ff	<= flash_busy;
		flash_done		<= 0;
		if(flash_busy_ff && !flash_busy)
			flash_done	<= 1;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Command synchronization

    reg			cmd_en			= 0;
    wire		cmd_done_sync;

    wire		flash_busy_sync;
    wire		flash_done_sync;

    ThreeStageSynchronizer sync_flash_busy(
		.clk_in(intosc_bufg),
		.din(flash_busy),
		.clk_out(/*tap_tck_bufh*/intosc_bufg),
		.dout(flash_busy_sync)
	);

	wire		cmd_sync_busy;	//debug
    HandshakeSynchronizer sync_flash_cmd(
		.clk_a(/*tap_tck_bufh*/intosc_bufg),
		.en_a(cmd_en),
		.ack_a(cmd_done_sync),
		.busy_a(cmd_sync_busy),

		.clk_b(intosc_bufg),
		.en_b(cmd_en_sync),
		.ack_b(flash_done),
		.busy_b()
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The UART

	//8N1 configuration, no others supported
	reg			uart_tx_en		= 0;
	reg[7:0]	uart_tx_data	= 0;
	wire		uart_tx_active;
	wire		uart_rx_en;
	wire[7:0]	uart_rx_data;

	UART #(
		.OVERSAMPLE(1'b1)
	) uart (
		.clk(intosc_bufg),
		.clkdiv(16'd577),	//115200 baud @ 66.5 MHz

		.tx(uart_txd),
		.tx_data(uart_tx_data),
		.tx_en(uart_tx_en),
		.txactive(uart_tx_active),

		.rx(uart_rxd),
		.rx_data(uart_rx_data),
		.rx_en(uart_rx_en),
		.rxactive()
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Output FIFO going to the UART

	reg			tx_fifo_wr_en		= 0;
	reg[7:0]	tx_fifo_wr_data		= 0;
	reg			tx_fifo_rd_en		= 0;
	wire[7:0]	tx_fifo_rd_data;
	wire		tx_fifo_empty;

    SingleClockFifo #(
		.WIDTH(8),
		.DEPTH(1024),
		.USE_BLOCK(1),
		.OUT_REG(1)
	) tx_fifo (
		.clk(intosc_bufg),
		.wr(tx_fifo_wr_en),
		.din(tx_fifo_wr_data),
		.rd(tx_fifo_rd_en),
		.dout(tx_fifo_rd_data),
		.overflow(),
		.underflow(),
		.empty(tx_fifo_empty),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
	);

	reg			tx_fifo_rd_en_ff	= 0;
	reg[1:0]	tx_fifo_state		= 0;
	always @(posedge intosc_bufg) begin
		tx_fifo_rd_en		<= 0;
		tx_fifo_rd_en_ff	<= tx_fifo_rd_en;
		uart_tx_en			<= 0;

		case(tx_fifo_state)

			0: begin

				if(!tx_fifo_empty) begin
					tx_fifo_rd_en	<= 1;
					tx_fifo_state	<= 1;
				end

			end

			1: begin
				if(tx_fifo_rd_en_ff) begin
					uart_tx_en		<= 1;
					uart_tx_data	<= tx_fifo_rd_data;
					tx_fifo_state	<= 2;
				end
			end

			2: begin
				if(!uart_tx_en && !uart_tx_active)
					tx_fifo_state	<= 0;
			end


		endcase

	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Input FIFO from the UART to the flash controller

    reg			rx_fifo_wr_en		= 0;
	reg[7:0]	rx_fifo_wr_data		= 0;

	always @(posedge intosc_bufg) begin
		write_valid	<= write_ready;
	end

    SingleClockFifo #(
		.WIDTH(8),
		.DEPTH(1024),
		.USE_BLOCK(1),
		.OUT_REG(1)
	) rx_fifo (
		.clk(intosc_bufg),
		.wr(rx_fifo_wr_en),
		.din(rx_fifo_wr_data),
		.rd(write_ready),
		.dout(write_data),
		.overflow(),
		.underflow(),
		.empty(),
		.full(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Main JTAG state machine

    localparam STATE_BOOTING	= 4'h0;
    localparam STATE_IDLE		= 4'h1;
    localparam STATE_GET_ADDR	= 4'h2;
    localparam STATE_GET_LEN	= 4'h3;
    localparam STATE_READ		= 4'h4;
    localparam STATE_SIZE		= 4'h5;
    localparam STATE_WIPE		= 4'h6;
    localparam STATE_ERASE		= 4'h7;
    localparam STATE_GET_PDATA	= 4'h8;
    localparam STATE_PROGRAM	= 4'h9;

    localparam STATE_HANG		= 4'hf;

    reg[3:0]	state			= STATE_BOOTING;
    reg[15:0]	count			= 0;

    `include "QuadSPIFlashController_opcodes_localparam.vh"

    always @(posedge /*tap_tck_bufh*/intosc_bufg) begin

		cmd_en					<= 0;
		tx_fifo_wr_en			<= 0;
		rx_fifo_wr_en			<= 0;

		case(state)

			//Wait for flash to start initializing
			STATE_BOOTING: begin
				if(flash_busy_sync)
					state		<= STATE_IDLE;
			end	//end STATE_BOOTING

			STATE_IDLE: begin

				led[0]	<= (capacity_mbits == 64);

				if(uart_rx_en) begin

					case(uart_rx_data)
						"b": begin
							cmd_id			<= FLASH_OP_WIPE;
							cmd_addr		<= 0;
							cmd_len			<= 0;
							cmd_en			<= 1;
							state			<= STATE_WIPE;
						end

						"e": begin
							count			<= 0;
							cmd_id			<= FLASH_OP_ERASE;
							state			<= STATE_GET_ADDR;
						end

						"p": begin
							count			<= 0;
							cmd_id			<= FLASH_OP_PROGRAM;
							state			<= STATE_GET_ADDR;
						end

						"r": begin
							count			<= 0;
							cmd_id			<= FLASH_OP_READ;
							state			<= STATE_GET_ADDR;
						end

						"s": begin
							tx_fifo_wr_en		<= 1;
							tx_fifo_wr_data	<= capacity_mbits[15:8];
							state			<= STATE_SIZE;
						end

						default: begin
						end

					endcase

				end

			end	//end STATE_IDLE

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// System metadata

			STATE_SIZE: begin

				tx_fifo_wr_en		<= 1;
				tx_fifo_wr_data	<= capacity_mbits[7:0];
				state			<= STATE_IDLE;

			end	//end STATE_SIZE

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for bulk erase to complete

			STATE_WIPE: begin
				if(flash_done) begin
					tx_fifo_wr_en	<= 1;
					tx_fifo_wr_data	<= 8'h01;
					state			<= STATE_IDLE;
				end
			end	//end STATE_WIPE

			STATE_ERASE: begin
				if(flash_done) begin
					led[3]			<= 1;
					tx_fifo_wr_en	<= 1;
					tx_fifo_wr_data	<= 8'h01;
					state			<= STATE_IDLE;
				end
			end	//end STATE_ERASE

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read arguments

			STATE_GET_ADDR: begin
				if(uart_rx_en) begin

					case(count)
						0:		cmd_addr[31:24] <= uart_rx_data;
						1:		cmd_addr[23:16] <= uart_rx_data;
						2:		cmd_addr[15:8]	<= uart_rx_data;
						3:		cmd_addr[7:0]	<= uart_rx_data;
					endcase

					count		<= count + 1'h1;

					if(count == 3) begin
						count	<= 0;
						state	<= STATE_GET_LEN;
					end

				end
			end	//end STATE_GET_ADDR

			STATE_GET_LEN: begin
				if(uart_rx_en) begin

					case(count)
						0:		cmd_len[15:8]	<= uart_rx_data;
						1:		cmd_len[7:0]	<= uart_rx_data;
					endcase

					count		<= count + 1'h1;

					if(count == 1) begin
						count	<= 0;

						//Send the command to be executed
						cmd_en			<= 1;

						case(cmd_id)

							FLASH_OP_PROGRAM: begin
								state			<= STATE_GET_PDATA;
								cmd_en			<= 0;	//don't program yet!
							end

							FLASH_OP_READ: begin
								state			<= STATE_READ;
							end

							FLASH_OP_ERASE: begin
								led[2]			<= 1;
								state			<= STATE_ERASE;
							end

						endcase
					end

				end
			end	//end STATE_GET_LEN

			STATE_GET_PDATA: begin
				if(uart_rx_en) begin
					count			<= count + 1'h1;
					rx_fifo_wr_en	<= 1;
					rx_fifo_wr_data	<= uart_rx_data;
				end

				if(count == cmd_len) begin
					cmd_en			<= 1;
					state			<= STATE_PROGRAM;
				end

			end

			STATE_PROGRAM: begin
				if(cmd_done_sync) begin
					tx_fifo_wr_en	<= 1;
					tx_fifo_wr_data	<= 8'h01;
					state			<= STATE_IDLE;
				end
			end	//end STATE_PROGRAM

			STATE_READ: begin

				if(read_valid) begin
					tx_fifo_wr_en		<= 1;
					tx_fifo_wr_data		<= read_data;
				end

				//Done
				if(cmd_done_sync)
					state			<= STATE_IDLE;

			end	//end STATE_READ

		endcase

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // DEBUG

    DDROutputBuffer #(
		.WIDTH(1)
	) clkoutbuf(
		.clk_p(intosc_bufg),
		.clk_n(!intosc_bufg),
		.dout(pmod_dq[7]),
		.din0(1'b0),
		.din1(1'b1)
	);

	//assign pmod_dq[6:0] = 7'h0;
	assign pmod_dq[0] = flash_cs_n;
	assign pmod_dq[1] = cclk;
	assign pmod_dq[2] = flash_dq[0];	//mosi
	assign pmod_dq[3] = flash_dq[1];	//miso

	assign pmod_dq[6]	= flash_done;
	assign pmod_dq[4]	= (cmd_id == FLASH_OP_PROGRAM) && cmd_en;
	assign pmod_dq[5]	= (state == STATE_IDLE);

	/*
	//intclk is 66.5 MHz for current prototype at last measurement
	RedTinUartWrapper #(
		.WIDTH(128),
		.DEPTH(2048),
		.UART_CLKDIV(16'd577),		//115200 @ 66.5 MHz
		.SYMBOL_ROM(
			{
				16384'h0,
				"DEBUGROM", 				8'h0, 8'h01, 8'h00,
				32'd15037,			//period of internal clock, in ps
				32'd2048,			//Capture depth (TODO auto-patch this?)
				32'd128,			//Capture width (TODO auto-patch this?)
				{ "state",					8'h0, 8'h4,  8'h0 },
				{ "flash_busy_sync",		8'h0, 8'h1,  8'h0 },
				{ "cmd_en",					8'h0, 8'h1,  8'h0 },
				{ "cmd_en_sync",			8'h0, 8'h1,  8'h0 },
				{ "cmd_done_sync",			8'h0, 8'h1,  8'h0 },
				{ "flash_cs_n",				8'h0, 8'h1,  8'h0 },
				{ "cmd_sync_busy",			8'h0, 8'h1,  8'h0 },
				{ "flash_done",				8'h0, 8'h1,  8'h0 }
			}
		)
	) analyzer (
		.clk(intosc_bufg),
		.capture_clk(intosc_bufg),
		.din({
				state,					//4
				flash_busy_sync,		//1
				cmd_en,					//1
				cmd_en_sync,			//1
				cmd_done_sync,			//1
				flash_cs_n,				//1
				cmd_sync_busy,			//1
				flash_done,				//1

				117'h0					//padding
			}),
		.uart_rx(uart_rxd),
		.uart_tx(uart_txd),
		.la_ready(la_ready)
	);*/

endmodule
