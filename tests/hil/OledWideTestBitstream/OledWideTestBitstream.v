`default_nettype none
`timescale 1ns / 1ps
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

/**
	PMOD pinout

	0: cs_n
	1: mosi
	2: nc
	3: sck
	4: dc
	5: res
	6: vbatc
	7: vddc
 */
module OledWideTestBitstream(
	input wire clk,
    output reg[3:0] led = 0,
    input wire[3:0] switch,
    input wire[3:0] button,
    inout wire[7:0] pmod_a
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Clocking

    wire clk_bufg;
	ClockBuffer #(
		.TYPE("GLOBAL"),
		.CE("NO")
	) clk_buf (
		.clkin(clk),
		.clkout(clk_bufg),
		.ce(1'b1)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The Zynq CPU (not actually used for anything for now, just to make DRC shut up)

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

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Tie off unused pins

    assign pmod_a[2]	= 1'b0;			//NC

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Switch debouncing

	wire[3:0] switch_debounced;
	wire[3:0] switch_rising;
	wire[3:0] switch_falling;

	wire[3:0] button_debounced;
	wire[3:0] button_rising;
	wire[3:0] button_falling;

	SwitchDebouncerBlock #(
		.WIDTH(4),
		.INIT_VAL(0)
	) switch_debouncer (
		.clk(clk_bufg),
		.din(switch),
		.dout(switch_debounced),
		.rising(switch_rising),
		.falling(switch_falling)
	);

	SwitchDebouncerBlock #(
		.WIDTH(4),
		.INIT_VAL(0)
	) button_debouncer (
		.clk(clk_bufg),
		.din(button),
		.dout(button_debounced),
		.rising(button_rising),
		.falling(button_falling)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Framebuffer RAM

	//GPU write bus
	reg 		gpu_wr_en	= 0;
	reg[8:0]	gpu_wr_addr	= 0;
	reg[7:0]	gpu_wr_data	= 0;

	//Display read bus
	wire		display_rd_en;
	wire[8:0]	display_rd_addr;
	wire[7:0]	display_rd_data;

	//Should be vertical 4-pixel wide bars
    MemoryMacro #(
		.WIDTH(8),
		.DEPTH(512),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1'b1),
		.INIT_VALUE(8'h0F),
		.INIT_ADDR(0),
		.INIT_FILE("")
    ) framebuffer (
		.porta_clk(clk_bufg),
		.porta_en(gpu_wr_en),
		.porta_addr(gpu_wr_addr),
		.porta_we(gpu_wr_en),
		.porta_din(gpu_wr_data),
		.porta_dout(),

		.portb_clk(clk_bufg),
		.portb_en(display_rd_en),
		.portb_addr(display_rd_addr),
		.portb_we(1'b0),
		.portb_din(8'h0),
		.portb_dout(display_rd_data)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The display controller

    wire power_state;
    wire ready;
    reg refresh			= 0;

    SSD1306 #(
		.INTERFACE("SPI")
	) display_ctrl (
		.clk(clk_bufg),
		.clkdiv(16'd14),		//~8.9 MHz w/ 125 MHz sysclk, max for SSD1306 is 10 MHz

		//Bus to LCD
		.rst_out_n(pmod_a[5]),
		.spi_sck(pmod_a[3]),
		.spi_mosi(pmod_a[1]),
		.spi_cs_n(pmod_a[0]),
		.cmd_n(pmod_a[4]),
		.vbat_en_n(pmod_a[6]),
		.vdd_en_n(pmod_a[7]),

		.powerup(switch_rising[0]),
		.powerdown(switch_falling[0]),
		.refresh(refresh),

		.framebuffer_rd_en(display_rd_en),
		.framebuffer_rd_addr(display_rd_addr),
		.framebuffer_rd_data(display_rd_data),

		.power_state(power_state),
		.ready(ready)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TODO: Other logic

    always @(*) begin
		led[3]		<= switch_debounced[3] ^ switch_debounced[2] ^ switch_debounced[1];	//prevent warnings
		led[2]		<= button_debounced[3] ^ button_debounced[2] ^ button_debounced[1];

		led[1]		<= ready;
		led[0]		<= power_state;

		refresh		<= button_rising[0];
    end

endmodule
