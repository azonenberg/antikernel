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
    // The debug bridge

    wire		rpc_tx_en;
    wire[31:0]	rpc_tx_data;
    wire		rpc_tx_ready;

    JtagDebugBridge #(
		.NOC_WIDTH(32)
    ) bridge(
		.clk(clk_bufg),

		//RPC loopback for testing
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ready(rpc_tx_ready),

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

	always @(*)
		led[0]	<= cmp_out;

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
		.clk(clk_bufg),
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
    // Blink the output

    reg[22:0] count = 0;
    always @(posedge clk_bufg) begin
		count <= count + 1;
		if(count == 0)
			prbs_out = ~prbs_out;
    end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Configure the DAC to drive mid-scale

    reg[3:0] state = 0;

    always @(posedge clk_bufg) begin

		i2c_tx_en		<= 0;
		i2c_rx_en		<= 0;
		i2c_start_en	<= 0;
		i2c_restart_en	<= 0;
		i2c_stop_en		<= 0;

		i2c_rx_ack		<= 1;

		case(state)

			0: begin
				i2c_start_en	<= 1;
				state			<= 1;
			end

			1: begin
				if(!i2c_start_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= {4'b1100, 3'b000, 1'b0};			//Write to an MCP47x6A0 (address LSBs 3'b000)
					state		<= 2;
				end
			end

			2: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= {3'b010, 2'b00, 2'b00, 1'b0};	//write volatile memory
																	//Vref = Vdd
																	//not powering down
																	//gain of 1
					state		<= 3;
				end
			end

			3: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= 8'h40;	//eight high bits of DAC (left justified)
					state		<= 4;
				end
			end

			4: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_tx_en	<= 1;
					i2c_tx_data	<= 8'h00;	//four low bits of DAC (left justified)
					state		<= 5;
				end
			end

			5: begin
				if(!i2c_tx_en && !i2c_busy) begin
					i2c_stop_en	<= 1;
					state		<= 6;
				end
			end

			6: begin
				//hang forever
			end

		endcase

    end

endmodule
