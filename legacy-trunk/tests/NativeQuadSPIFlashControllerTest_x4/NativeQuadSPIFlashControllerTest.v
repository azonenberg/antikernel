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
	@brief Unit test for NativeQuadSPIFlashController in quad mode
 */

module NativeQuadSPIFlashControllerTest_x4();

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
	// The flash chip
	
	wire spi_sck;
	wire[3:0] spi_data;
	wire spi_cs_n;
	
	s25fl008k #(
		.mem_file_name("../../../testdata/flash_dummy_data.hex"),
		.screg_file_name("none")
		)flash(
		.SI(spi_data[0]),
		.SO(spi_data[1]),
		.SCK(spi_sck),
		.CSNeg(spi_cs_n),
		.HOLDNeg(spi_data[3]),
		.WPNeg(spi_data[2])
		);
	

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The controller
	
	wire busy;
	wire done;
	wire[31:0] addr;
	wire[9:0] burst_size;
	wire read_en;
	wire read_data_valid;
	wire[31:0] read_data;
	wire erase_en;
	wire write_en;
	wire write_rden;
	wire[31:0] write_data;
	wire[31:0] max_address;
	
	NativeQuadSPIFlashController #(
		.ENABLE_QUAD_MODE(1)
	) dut (
		.clk(clk),
		.reset(1'b0),
		
		.spi_cs_n(spi_cs_n),
		.spi_sck(spi_sck),
		.spi_data(spi_data),
		
		.busy(busy),
		.done(done),
		.addr(addr),
		.burst_size(burst_size),
		
		.read_en(read_en),
		.read_data_valid(read_data_valid),
		.read_data(read_data),
		
		.erase_en(erase_en),
		
		.write_en(write_en),
		.write_rden(write_rden),
		.write_data(write_data),
		
		.max_address(max_address)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The test driver
	
	NativeQuadSPIFlashControllerTestDriver ctrl(
		.clk(clk),
			
		.busy(busy),
		.done(done),
		.addr(addr),
		.burst_size(burst_size),
		
		.read_en(read_en),
		.read_data_valid(read_data_valid),
		.read_data(read_data),
		
		.erase_en(erase_en),
		
		.write_en(write_en),
		.write_rden(write_rden),
		.write_data(write_data),
		
		.max_address(max_address)
	);
	
endmodule

