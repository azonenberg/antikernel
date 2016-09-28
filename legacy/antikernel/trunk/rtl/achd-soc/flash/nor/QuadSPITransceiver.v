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
	@brief A simple transceiver for quad SPI. Just a bunch of shift registers and glue.
	
	Assumes 8-bit transfers for now.
	
	Does not manage the chip select signal; the parent is responsible for this.
	
	Runs output clock at Fclk / 2.
 */
module QuadSPITransceiver(
	clk, busy, done,
	spi_sck, spi_data,
	tx_en_single, tx_en_quad, tx_data,
	rx_en_single, rx_en_quad, rx_data,
	dummy_en_single
    );

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	//Global control flags
	input wire clk;
	output wire busy;
	output reg done = 0;
	
	//SPI bus
	output reg spi_sck = 0;
	inout wire[3:0] spi_data;
	
	//Command bus
	input wire tx_en_single;
	input wire tx_en_quad;
	input wire[7:0] tx_data;
	input wire rx_en_single;
	input wire rx_en_quad;
	input wire dummy_en_single;
	output reg[7:0] rx_data = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Glue logic for IO tristates etc
	
	reg tx_single_active = 0;
	reg tx_quad_active = 0;
	reg rx_single_active = 0;
	reg rx_quad_active = 0;
	
	wire tx_active;
	assign tx_active = tx_single_active | tx_quad_active;
	
	assign busy = tx_single_active | tx_quad_active | rx_single_active | rx_quad_active;
	
	//A little glue here is needed since "inout reg" doesn't work
	//This is still a combinatorial signal though.
	reg[3:0] spi_data_reg;
	assign spi_data = spi_data_reg;
	
	//Output data
	reg[3:0] spi_dout = 0;	//When doing single-width operations, spi_dout[0] = MOSI
	
	//Tri-states for SPI data
	always @(tx_single_active, tx_quad_active, rx_single_active, rx_quad_active,
				spi_dout) begin
		
		//Default if nothing is going on
		//CAUTION: Unless quad enable bit is already set, spi_data[3:2] must be pulled up in the UCF or on the PCB
		spi_data_reg <= 4'bzzzz;
		
		//In single transmit mode, MOSI is the only data output.
		//If in quad transmit mode, all lines become outputs.
		if(tx_single_active)
			spi_data_reg[0] <= spi_dout[0];
		if(tx_quad_active)
			spi_data_reg <= spi_dout;
			
		//In single receive mode, MISO is the only data input.
		//Let it float (default).
		
		//In quad receive mode, all data lines become inputs.
		if(rx_quad_active)
			spi_data_reg <= 4'bzzzz;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// SERDES logic
	
	reg[7:0] tx_data_buf = 0;
	reg[3:0] bitcount = 0;
	
	reg[6:0] rx_buf = 0;
	
	always @(posedge clk) begin
		
		done <= 0;
		
		//Do the stuff
		if(busy) begin
		
			//Toggle clock
			spi_sck <= !spi_sck;
			
			//Transmit logic
			if(spi_sck) begin
		
				//x1 transmit mode
				if(tx_single_active) begin
					
					//If we just sent bit 7, stop
					if(bitcount == 7) begin
						tx_single_active <= 0;
						done <= 1;
					end
					
					//Shift data left and continue
					else begin
						spi_dout[0] <= tx_data_buf[7];
						tx_data_buf <= {tx_data_buf[6:0], 1'b0};
						bitcount <= bitcount + 4'd1;
					end
					
				end
				
				//x4 transmit mode
				if(tx_quad_active) begin
					if(bitcount == 7) begin
						done <= 1;
						tx_quad_active <= 0;
					end
					
					else begin
						spi_dout <= tx_data_buf[7:4];
						bitcount <= 7;
					end
				end
				
			end
			
			//Receive logic
			if(spi_sck) begin
			
				//x1 receive mode
				if(rx_single_active) begin
					
					rx_buf <= {rx_buf[5:0], spi_data[1]};
					
					//If we just got bit 7, stop
					if(bitcount == 7) begin
						rx_data <= {rx_buf[6:0], spi_data[1]};
						rx_single_active <= 0;
						done <= 1;
					end
					
					//Shift in data and continue
					else
						bitcount <= bitcount + 4'd1;
					
				end
				
				//x4 receive mode
				if(rx_quad_active) begin
				
					rx_data <= {rx_data[3:0], spi_data};
					
					//If we just got bit 4, stop
					if(bitcount == 4) begin
						rx_quad_active <= 0;
						done <= 1;
					end
					
					//Shift in data and continue
					else
						bitcount <= 4;
					
				end
				
			end
		
		end
		
		//clock idles low
		else
			spi_sck <= 0;
		
		//Start an x1 transmit cycle
		if(tx_en_single) begin
			tx_data_buf <= {tx_data[6:0], 1'b0};	//first bit is on the wire already
			tx_single_active <= 1;
			bitcount <= 0;
			
			//Start transmitting next cycle
			//Transmit MSB first
			spi_dout[0] <= tx_data[7];
		end
		
		//Start an x4 transmit cycle
		if(tx_en_quad) begin
			tx_data_buf <= {tx_data[3:0], 4'b0};	//first bit is on the wire already
			tx_quad_active <= 1;
			bitcount <= 0;
			
			//Start transmitting next cycle
			//Transmit MSB first
			spi_dout <= tx_data[7:4];
		end
		
		//Start an x1 receive cycle
		if(rx_en_single) begin
			rx_buf <= 0;
			rx_single_active <= 1;
			bitcount <= 0;
		end
		
		//Start an x4 receive cycle
		if(rx_en_quad) begin
			rx_buf <= 0;
			rx_quad_active <= 1;
			bitcount <= 0;
		end
		
		//Send a SINGLE dummy clock regardless of mode
		if(dummy_en_single) begin
			rx_buf <= 0;
			rx_quad_active <= 1;
			bitcount <= 4;
		end
		
	end

endmodule
