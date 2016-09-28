`timescale 1ns / 1ps
`default_nettype none
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
	@brief Unit test for QuadSPITransceiver
 */

module QuadSPITransceiverTest();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Oscillator
	
	reg clk = 0;
	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	always begin
		#5;
		clk = 0;
		#5;
		clk = ready;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The transceiver
	
	wire busy;
	wire done;
	wire spi_sck;
	wire[3:0] spi_data;
	reg tx_en_single = 0;
	reg tx_en_quad = 0;
	reg[7:0] tx_data = 0;
	reg rx_en_single = 0;
	reg rx_en_quad = 0;
	wire[7:0] rx_data;
	
	QuadSPITransceiver txvr(
		.clk(clk),
		.busy(busy),
		.done(done),
		.spi_sck(spi_sck),
		.spi_data(spi_data),
		.tx_en_single(tx_en_single),
		.tx_en_quad(tx_en_quad),
		.tx_data(tx_data),
		.rx_en_single(rx_en_single),
		.rx_en_quad(rx_en_quad),
		.rx_data(rx_data),
		.dummy_en_single(1'b0)
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver
	
	reg spi_single_tx_data_ok = 0;
	reg spi_quad_tx_data_ok = 0;
	
	reg[7:0] state = 0;
	
	reg[7:0] dummy_tx_data = 0;
		
	always @(posedge clk) begin
	
		tx_en_single <= 0;
		tx_en_quad <= 0;
		rx_en_single <= 0;
		rx_en_quad <= 0;
	
		case(state)
		
			//Wait during startup
			0: begin
				state <= 1;
			end
			
			//Send a byte in single mode
			1: begin
				$write("SPI transmitter test, x1 mode... ");
				tx_en_single <= 1;
				tx_data <= 'h55;
				state <= 2;
			end
			2: begin
				if(done) begin
					if(spi_single_tx_data_ok) begin
						$display("OK");
						state <= 10;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end
			
			//Receive a byte in single mode
			10: begin
				$write("SPI receiver test, x1 mode... ");
				rx_en_single <= 1;
				dummy_tx_data <= 'hcd;
				state <= 11;
			end
			11: begin
				if(done) begin
					if(dummy_tx_data == rx_data) begin
						$display("OK");
						state <= 20;
					end
					else begin
						$display("FAIL (got %x, should be %x)", rx_data, dummy_tx_data);
						$finish;
					end
				end
			end
			
			//Send a byte in quad mode
			20: begin
				$write("SPI transmitter test, x4 mode... ");
				tx_en_quad <= 1;
				tx_data <= 'h5a;
				state <= 21;
			end
			21: begin
				if(done) begin
					if(spi_quad_tx_data_ok) begin
						$display("OK");
						state <= 30;
					end
					else begin
						$display("FAIL");
						$finish;
					end
				end
			end
			
			//Receive a byte in quad mode
			30: begin
				$write("SPI receiver test, x4 mode... ");
				rx_en_quad <= 1;
				dummy_tx_data <= 'ha3;
				state <= 31;
			end
			31: begin
				if(done) begin
					if(dummy_tx_data == rx_data) begin
						$display("OK");
						state <= 40;
					end
					else begin
						$display("FAIL (got %x, should be %x)", rx_data, dummy_tx_data);
						$finish;
					end
				end
			end
			
			//Finished
			40: begin
				$display("PASS");
				$finish;
			end
		
		endcase
	end
	
	//Dummy receiver for verifying transmitter
	reg[7:0] spi_single_verify_rxd = 0;
	reg[7:0] spi_quad_verify_rxd = 0;
	always @(posedge spi_sck) begin
		spi_single_verify_rxd = {spi_single_verify_rxd[6:0], spi_data[0]};
		spi_single_tx_data_ok = (spi_single_verify_rxd == tx_data);
		
		spi_quad_verify_rxd = {spi_quad_verify_rxd[3:0], spi_data};
		spi_quad_tx_data_ok = (spi_quad_verify_rxd == tx_data);
	end
	
	//Dummy transmitter for verifying receiver
	reg rx_single_active = 0;
	reg rx_quad_active = 0;
	reg[3:0] spi_test_txd = 0;
	assign spi_data = (rx_single_active || rx_quad_active) ? spi_test_txd : 4'bzzzz;
	reg[7:0] dummy_tx_data_reg = 0;
	always @(posedge clk) begin
	
		//Setup
		if(rx_en_single) begin
			rx_single_active <= 1;
			dummy_tx_data_reg <= dummy_tx_data;
		end
		if(rx_en_quad) begin
			rx_quad_active <= 1;
			dummy_tx_data_reg <= dummy_tx_data;
		end
		
		//Shift register
		if(!spi_sck) begin
			
			//x1 transmit
			if(rx_single_active) begin
				spi_test_txd <= 0;
				spi_test_txd[1] <= dummy_tx_data_reg[7];
				dummy_tx_data_reg <= {dummy_tx_data_reg[6:0], 1'b0};
				if(done)
					rx_single_active <= 0;
			end
			
			//x4 transmit
			if(rx_quad_active) begin
				spi_test_txd <= dummy_tx_data_reg[7:4];
				dummy_tx_data_reg <= {dummy_tx_data_reg[3:0], 4'b0};
				if(done)
					rx_quad_active <= 0;
			end
			
		end
	end

endmodule

