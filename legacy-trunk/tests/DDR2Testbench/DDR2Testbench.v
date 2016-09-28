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
	@brief Testbench for NativeDDR2Controller
 */

module DDR2Testbench();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Oscillator
	reg clk_100mhz = 0;
	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	always begin
		#5;
		clk_100mhz = 0;
		#5;
		clk_100mhz = ready;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// PLL for clock multiplication
	wire pll_locked_MainClockPLL;
	
	wire clk_p_raw;
	wire clk_n_raw;
	wire clk_p_bufg;
	wire clk_n_bufg;
	BUFGCE bufgce_p(.I(clk_p_raw), .O(clk_p_bufg), .CE(pll_locked_MainClockPLL));
	BUFGCE bufgce_n(.I(clk_n_raw), .O(clk_n_bufg), .CE(pll_locked_MainClockPLL));
	
	wire clk_feedback_MainClockPLL;
	PLL_BASE #(
		.CLKIN_PERIOD(10), 		//10ns
		.CLKFBOUT_MULT(8),    	//VCO frequency 800 MHz
		.CLKFBOUT_PHASE(0.0),
		.CLKOUT0_DIVIDE(4),		//200 MHz
		.CLKOUT1_DIVIDE(4),
		.CLKOUT2_DIVIDE(4),
		.CLKOUT3_DIVIDE(4),
		.CLKOUT4_DIVIDE(1),
		.CLKOUT5_DIVIDE(1),
		.CLKOUT0_DUTY_CYCLE(0.5),
		.CLKOUT1_DUTY_CYCLE(0.5),
		.CLKOUT2_DUTY_CYCLE(0.5),
		.CLKOUT3_DUTY_CYCLE(0.5),
		.CLKOUT4_DUTY_CYCLE(0.5),
		.CLKOUT5_DUTY_CYCLE(0.5),
		.CLKOUT0_PHASE(0.0),
		.CLKOUT1_PHASE(180.0),
		.CLKOUT2_PHASE(0.0),
		.CLKOUT3_PHASE(0.0),
		.CLKOUT4_PHASE(0),
		.CLKOUT5_PHASE(0),
		.BANDWIDTH("OPTIMIZED"),
		.CLK_FEEDBACK("CLKFBOUT"),
		.COMPENSATION("SYSTEM_SYNCHRONOUS"),
		.DIVCLK_DIVIDE(1),
		.REF_JITTER(0.1),
		.RESET_ON_LOSS_OF_LOCK("FALSE")
	)
	MainClockPLL (
		.CLKFBOUT(clk_feedback_MainClockPLL),
		.CLKOUT0(clk_p_raw),
		.CLKOUT1(clk_n_raw),
		.CLKOUT2(),
		.CLKOUT3(),
		.CLKOUT4(),
		.CLKOUT5(),
		.LOCKED(pll_locked_MainClockPLL),
		.CLKFBIN(clk_feedback_MainClockPLL),
		.CLKIN(clk_100mhz),
		.RST(1'b0)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The UUT
	
	//DDR2 interface	
	wire ddr2_ras_n;
	wire ddr2_cas_n;
	wire ddr2_udqs_p;
	wire ddr2_udqs_n;
	wire ddr2_ldqs_p;
	wire ddr2_ldqs_n;
	wire ddr2_udm;
	wire ddr2_ldm;
	wire ddr2_we_n;
	wire ddr2_ck_p;
	wire ddr2_ck_n;
	wire ddr2_cke;
	wire ddr2_odt;
	wire[2:0] ddr2_ba;
	wire[12:0] ddr2_addr;
	wire[15:0] ddr2_dq;
	
	//Fabric interface
	reg[31:0] addr = 0;
	wire done;
	reg wr_en = 0;
	reg[127:0] wr_data = 0;
	reg rd_en = 0;
	wire[127:0] rd_data;
	wire calib_done;
	
	NativeDDR2Controller controller(
		
		//Clocks		
		.clk_p(clk_p_bufg),
		.clk_n(clk_n_bufg),
		
		//Fabric interface
		.addr(addr),
		.done(done),
		.wr_en(wr_en),
		.wr_data(wr_data),
		.rd_en(rd_en),
		.rd_data(rd_data),
		.calib_done(calib_done),
		
		//DDR2 interface
		.ddr2_ras_n(ddr2_ras_n),
		.ddr2_cas_n(ddr2_cas_n),
		.ddr2_udqs_p(ddr2_udqs_p),
		.ddr2_udqs_n(ddr2_udqs_n),
		.ddr2_ldqs_p(ddr2_ldqs_p),
		.ddr2_ldqs_n(ddr2_ldqs_n),
		.ddr2_udm(ddr2_udm),
		.ddr2_ldm(ddr2_ldm),
		.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),
		.ddr2_ck_n(ddr2_ck_n),
		.ddr2_cke(ddr2_cke),
		.ddr2_odt(ddr2_odt),
		.ddr2_ba(ddr2_ba),
		.ddr2_addr(ddr2_addr),
		.ddr2_dq(ddr2_dq)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RAM simulation model
	
	//Select speed grade
	`define sg25E
	
	//The actual RAM model
	ddr2 ramchip(
		.ck(ddr2_ck_p),
		.ck_n(ddr2_ck_n),
		.cke(ddr2_cke),
		.cs_n(1'b0),		//hard-wired on the atlys
		.ras_n(ddr2_ras_n),
		.cas_n(ddr2_cas_n),
		.we_n(ddr2_we_n),
		.dm_rdqs({ddr2_udm, ddr2_ldm}),
		.ba(ddr2_ba),
		.addr(ddr2_addr),
		.dq(ddr2_dq),
		.dqs({ddr2_udqs_p, ddr2_ldqs_p}),
		.dqs_n({ddr2_udqs_n, ddr2_ldqs_n}),
		.rdqs_n(),
		.odt(ddr2_odt)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Top-level test logic
	reg[7:0] tstate = 0;
	always @(posedge clk_p_bufg) begin
	
		addr <= 0;
	
		wr_en <= 0;	
		wr_data <= 0;
	
		rd_en <= 0;
		
	
		case(tstate)
			
			//Wait for calibration to finish)
			0: begin
				if(calib_done) begin
					tstate <= 1;
					$display("Controller reports calibration done");
				end
			end
			
			//Issue a write request
			1: begin
				$display("Issuing write request");
				wr_en <= 1;
				addr <= 32'h0000c0d0;
				wr_data <= {32'hfeedface, 32'hc0def00d, 32'h41414242, 32'hc0ffffee};
				tstate <= 2;
			end
			2: begin
				if(done) begin
					tstate <= 3;
					$display("Write complete");
				end
			end
			
			//Read it back
			3: begin
				$display("Issuing read request");
				rd_en <= 1;
				addr <= 32'h0000c0d0;
				tstate <= 4;
			end
			4: begin
				if(done) begin
					$display("Read complete");
					if(rd_data == {32'hfeedface, 32'hc0def00d, 32'h41414242, 32'hc0ffffee}) begin
						$display("Read OK");
						tstate <= 5;
					end
					else begin
						$display("Read data mismatch");
						$display("FAIL");
						$finish;
					end
				end
			end
			
			//All good if we got here
			5: begin
				$display("PASS");
				$finish;
			end
			
		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Stop the test after 400us and declare fail if we haven't finished yet
	initial begin
		#400000;
		$display("FAIL");
		$finish;
	end
	

endmodule
