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
    // Loopback core for now

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
    // Main state machine

	/*
		PIN MAPPING

		pmod_e[0] = DQ1 = P3
		pmod_e[1] = DQ3 = P5
		pmod_e[2] = DQ4 = P12
		pmod_e[3] = DQ6 = P14
		pmod_e[4] = DQ0 = P2 (input only!!)
		pmod_e[5] = DQ2 = P4
		pmod_e[6] = DQ5 = P13
		pmod_e[7] = DQ7 = P15
	 */

	reg test_out = 0;
    assign pmod_e[0]	= test_out;	//Drive P3
    assign pmod_e[1]	= 1'bz;		//Float P5

    //Unused signals
	assign pmod_e[2]	= 1'b0;		//P12
	assign pmod_e[3]	= 1'b0;		//P14
	assign pmod_e[4]	= 1'b0;		//P2
	assign pmod_e[5]	= 1'b0;		//P4
	assign pmod_e[6]	= 1'b0;		//P13
	assign pmod_e[7]	= 1'b0;		//P15

	/*

	//Verify we get correct loopback
	always @(posedge clk_bufg)
		led <= {3'b000, pmod_e[1]};

    reg[23:0] count = 0;

    always @(posedge clk_bufg) begin
		count <= count + 1'h1;
		if(count == 0)
			test_out <= ~test_out;
    end
    */

    /*
		We need to send out a pulse and see when it comes back

		Round 1: measure in 8 ns ticks
     */

    reg[7:0] state = 0;
    reg[3:0] count = 0;
    always @(posedge clk) begin

		case(state)

			0: begin
				test_out	<= 0;
				state		<= 1;
				count		<= 0;
			end

			//wait a while to make sure the whole wire is low
			1: begin
				count		<= count + 1'h1;
				if(count == 15)
					state	<= 2;
			end

			//drive high
			2: begin
				count		<= 0;
				test_out	<= 1;
				state		<= 3;
			end

			3: begin
				count		<= count + 1'h1;
				if(pmod_e[1] || (count == 15) ) begin
					led		<= count;
					state	<= 4;
				end
			end

			4: begin
				//hold there forever
			end



		endcase

    end

endmodule
