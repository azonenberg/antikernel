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

module UartLATestBitstream(
	input wire clk,
    output wire[3:0] led,
    inout wire[7:0] pmod_e
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
		.clk(clk_bufg),

		//RPC interface
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ready(rpc_tx_ready),

		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ready(rpc_rx_ready),

		//Debug indicators
		.led()
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Loopback core

    RPCv3EchoNode #(
		.NOC_WIDTH(32),
		.NOC_ADDR(16'hfeed)
	) echo (
		.clk(clk_bufg),

		.rpc_tx_en(rpc_rx_en),
		.rpc_tx_data(rpc_rx_data),
		.rpc_tx_ready(rpc_rx_ready),

		.rpc_rx_en(rpc_tx_en),
		.rpc_rx_data(rpc_tx_data),
		.rpc_rx_ready(rpc_tx_ready)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // The LA

    assign pmod_e[7:4] = 4'h0;
    assign pmod_e[3] = 1'bz;
    assign pmod_e[1:0] = 2'h0;

    RedTinUartWrapper #(
		.WIDTH(128),
		.DEPTH(512),
		.UART_CLKDIV(16'd1085),	//115200 @ 125 MHz
		.SYMBOL_ROM(
			{
				16384'h0,
				"DEBUGROM",
				32'd8000,		//8000 ps = 8 ns = 125 MHz
				32'd512,		//Capture depth (TODO auto-patch this?)
				32'd128,		//Capture width (TODO auto-patch this?)
				{ "rpc_rx_en\0", 	8'd1,  8'h0 },
				{ "rpc_rx_ready\0", 8'd1,  8'h0 },
				{ "rpc_tx_en\0", 	8'd1,  8'h0 },
				{ "rpc_tx_ready\0", 8'd1,  8'h0 },
				{ "padding\0",      8'd60, 8'h0 },
				{ "rpc_rx_data\0",	8'd32, 8'h0 },
				{ "rpc_tx_data\0",	8'd32, 8'h0 }
			}
		)
	) analyzer (
		.clk(clk_bufg),
		.capture_clk(clk_bufg),
		.din({
				rpc_rx_en,
				rpc_rx_ready,
				rpc_tx_en,
				rpc_tx_ready,
				60'h0,			//Unused bits (pad to multiple of 64)
				rpc_rx_data,
				rpc_tx_data
			}),
		.uart_rx(pmod_e[3]),
		.uart_tx(pmod_e[2]),

		.led(led)
	);

endmodule
