`timescale 1ns / 1ps
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
	@brief SPI transceiver
 */
module SPITransceiver(
	clk,
	clkdiv,
	spi_sck, spi_mosi, spi_miso,
	shift_en, shift_done, tx_data, rx_data
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	//Clocking
	input wire clk;
	input wire[15:0] clkdiv;
	
	//SPI interface
	output reg spi_sck = 0;
	output reg spi_mosi = 0;
	input wire spi_miso;
	
	//Control interface
	input wire shift_en;
	output reg shift_done = 0;
	input wire[7:0] tx_data;
	output reg[7:0] rx_data = 0;
	
	//Indicates which edge of SCK the remote end samples data on.
	parameter SAMPLE_EDGE = "RISING";
	
	//Indicates which edge of SCK the local end samples data on
	//NORMAL = same as remote
	//INVERTED = opposite
	parameter LOCAL_EDGE = "NORMAL";
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	reg active = 0;
	reg[3:0] count = 0;
	reg[14:0] clkcount = 0;
	
	reg[6:0] tx_shreg = 0;
	
	initial begin
		if( (SAMPLE_EDGE != "RISING") && (SAMPLE_EDGE != "FALLING") ) begin
			$display("ERROR: Invalid sample edge in SPITransceiver");
			$finish;
		end
	end
	
	reg almost_done	= 0;
	always @(posedge clk) begin
		shift_done <= 0;
		
		//Wait for a start request
		if(shift_en) begin
			active <= 1;
			clkcount <= 0;
			
			if(SAMPLE_EDGE == "FALLING") begin
				count <= 1;
				spi_sck <= 1;
			end
			else begin
				count <= 0;
				spi_sck <= 0;
			end
			
			spi_mosi <= tx_data[7];
			tx_shreg <= tx_data[6:0];
		end
		
		//Toggle processing
		if(active) begin
			clkcount <= clkcount + 15'h1;
			if(clkcount == clkdiv[15:1]) begin
			
				//Reset the counter and toggle the clock
				clkcount <= 0;
				spi_sck <= !spi_sck;
				
				//Make the done flag wait half a bit period if necessary
				if(almost_done) begin
					spi_sck		<= 0;
					shift_done	<= 1;
					active		<= 0;
					almost_done	<= 0;
				end
			
				//ACTIVE EDGE
				else if( (spi_sck && (SAMPLE_EDGE == "RISING")) || (!spi_sck && (SAMPLE_EDGE == "FALLING")) ) begin
					spi_mosi <= tx_shreg[6];
					
					tx_shreg <= {tx_shreg[5:0], 1'b0};
					
					if(LOCAL_EDGE == "INVERTED")
						rx_data <= {rx_data[6:0], spi_miso};
					
				end
				
				//INACTIVE EDGE
				else begin
					count <= count + 4'h1;
					
					if(LOCAL_EDGE == "NORMAL")
						rx_data <= {rx_data[6:0], spi_miso};
					
					//Stop on the last inactive edge
					if( (count == 'd8) ) begin
						spi_sck		<= 0;
						almost_done	<= 1;
					end
					
				end
			
			end
		end
	end
    
endmodule
