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
    // Pin shuffling for zybo pmod

    reg		vdd_en_n	= 1;
    reg		vbat_en_n 	= 1;
    reg		cmd_n		= 0;
    wire	spi_sck;
    wire	spi_mosi;
    reg		spi_cs_n	= 1;

    reg		rst_out		= 1;

    //Pin assignments
	assign pmod_a[0]	= spi_cs_n;
	assign pmod_a[1]	= spi_mosi;
	assign pmod_a[2]	= 1'b0;			//NC
	assign pmod_a[3]	= spi_sck;
	assign pmod_a[4]	= cmd_n;
	assign pmod_a[5]	= rst_out;
	assign pmod_a[6]	= vbat_en_n;
	assign pmod_a[7]	= vdd_en_n;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // SPI interface

	reg			spi_shift_en	= 0;
	wire		spi_shift_done;
	reg[7:0]	spi_tx_data		= 0;

	//125 MHz internal clock
	//10 MHz max for SSD1306
	//Dividing by 14 gives us ~8.9 MHz which leaves some headroom
    SPITransceiver #(
		.SAMPLE_EDGE("RISING"),
		.LOCAL_EDGE("NORMAL")
    ) spi_tx (

		.clk(clk_bufg),
		.clkdiv(16'd14),

		.spi_sck(spi_sck),
		.spi_mosi(spi_mosi),
		.spi_miso(1'b0),			//read not hooked up

		.shift_en(spi_shift_en),
		.shift_done(spi_shift_done),
		.tx_data(spi_tx_data),
		.rx_data()
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Switch debouncing

	wire[3:0] switch_debounced;
	wire[3:0] switch_rising;
	wire[3:0] switch_falling;

	SwitchDebouncerBlock #(
		.WIDTH(4),
		.INIT_VAL(0)
	) debouncer (
		.clk(clk_bufg),
		.din(switch),
		.dout(switch_debounced),
		.rising(switch_rising),
		.falling(switch_falling)
	);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // SPI chip select control wrapper

    reg			spi_byte_en		= 0;
    reg[2:0]	spi_byte_state	= 0;
    reg[2:0]	spi_byte_count	= 0;
    reg			spi_byte_done	= 0;

    //SPI state machine
    always @(posedge clk) begin

		spi_shift_en		<= 0;
		spi_byte_done		<= 0;

		case(spi_byte_state)

			//Wait for command request, then assert CS
			0: begin
				if(spi_byte_en) begin
					spi_cs_n		<= 0;
					spi_byte_state	<= 1;
					spi_byte_count	<= 0;
				end
			end

			//Wait 3 clocks of setup time, then initiate the transfer
			1: begin
				spi_byte_count		<= spi_byte_count + 1'd1;
				if(spi_byte_count == 2) begin
					spi_shift_en	<= 1;
					spi_byte_state	<= 2;
				end
			end

			//Wait for transfer to finish
			2: begin
				if(spi_shift_done) begin
					spi_byte_count	<= 0;
					spi_byte_state	<= 3;
				end
			end

			//Wait 3 clocks of hold time, then deassert CS
			3: begin
				spi_byte_count		<= spi_byte_count + 1'd1;
				if(spi_byte_count == 2) begin
					spi_cs_n		<= 1;
					spi_byte_state	<= 4;
					spi_byte_count	<= 0;
				end
			end

			//Wait 3 clocks of inter-frame gap, then return
			4: begin
				spi_byte_count		<= spi_byte_count + 1'd1;
				if(spi_byte_count == 2) begin
					spi_byte_done	<= 1;
					spi_byte_state	<= 0;
				end
			end

		endcase

    end

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Board bring-up

	reg[7:0] state = 0;
	reg[23:0] count = 0;

    always @(posedge clk_bufg) begin

		spi_byte_en				<= 0;

		case(state)

			//Init
			0: begin

				led				<= 0;

				if(switch_rising[0]) begin
					vdd_en_n	<= 0;

					count		<= 0;
					state		<= 1;

					led[0]		<= 1;
				end
			end

			//Give power rails ~1 ms to stabilize, then turn the display off
			1: begin
				count			<= count + 1'h1;
				if(count == 24'h01ffff) begin
					spi_tx_data		<= 8'hae;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 2;
				end
			end

			//Wait for command to finish, then strobe reset for ~1 ms
			2: begin
				if(spi_byte_done) begin
					rst_out			<= 0;
					count			<= 0;
					state			<= 3;
				end
			end

			//When reset finishes, set the charge pump and pre-charge period
			3: begin
				count			<= count + 1'h1;
				if(count == 24'h01ffff) begin
					rst_out			<= 1;

					spi_tx_data		<= 8'h8d;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 4;
				end
			end
			4: begin
				if(spi_byte_done) begin
					spi_tx_data		<= 8'h14;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 5;
				end
			end
			5: begin
				if(spi_byte_done) begin
					spi_tx_data		<= 8'hd9;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 6;
				end
			end
			6: begin
				if(spi_byte_done) begin
					spi_tx_data		<= 8'hf1;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 7;
				end
			end

			//When the last send finishes, turn on Vcc and wait ~100 ms
			7: begin
				if(spi_byte_done) begin
					vbat_en_n		<= 0;
					count			<= 0;
					state			<= 8;
				end
			end

			//After the wait is over, turn the display to solid white regardless of the actual RAM contents
			8: begin
				count				<= count + 1'h1;
				if(count == 24'hbfffff) begin
					spi_tx_data		<= 8'ha5;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 9;
				end
			end

			//Turn the actual display on
			9: begin
				if(spi_byte_done) begin
					spi_tx_data		<= 8'hAF;
					spi_byte_en		<= 1;
					cmd_n			<= 0;
					state			<= 10;
				end
			end

			//Done, wait for something to happen
			10: begin
				led[1]				<= 1;
				if(switch_falling[0]) begin
					state			<= 50;
				end
			end

			/////////////////////

			//SHUTDOWN: Send "display off" command
			50: begin
				led[2]			<= 1;
				spi_tx_data		<= 8'hae;
				spi_byte_en		<= 1;
				cmd_n			<= 0;
				state			<= 51;
			end

			//When send finishes, turn off Vbat
			51: begin
				if(spi_byte_done) begin
					vbat_en_n	<= 1;
					count		<= 0;
					state		<= 52;
				end
			end

			//Wait 100ms then turn off Vdd and reset
			52: begin
				count			<= count + 1'h1;
				if(count == 24'hbfffff) begin
					vdd_en_n	<= 1;
					state		<= 0;
				end
			end

		endcase

    end

endmodule
