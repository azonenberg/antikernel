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
	@brief Test vectors for the MMU
 */
module testSaratogaCPUMMU;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock oscillator
	
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
	// The DUT
	
	reg			translate_en		= 0;
	reg[4:0]	translate_tid		= 0;
	reg[31:0]	translate_vaddr		= 0;
	reg[2:0]	translate_perms		= 0;
	wire[15:0]	translate_nocaddr;
	wire[31:0]	translate_phyaddr;
	wire		translate_done;
	wire		translate_failed;
	
	reg			mgmt_wr_en			= 0;
	reg[4:0]	mgmt_wr_tid			= 0;
	reg			mgmt_wr_valid		= 0;
	reg[2:0]	mgmt_wr_perms		= 0;
	reg[31:0]	mgmt_wr_vaddr		= 0;
	reg[15:0]	mgmt_wr_nocaddr		= 0;
	reg[31:0]	mgmt_wr_phyaddr		= 0;
	wire		mgmt_wr_done;
	
	SaratogaCPUMMU #(
		.MAX_THREADS(32)
	) dut (
		.clk(clk),
		
		.translate_en(translate_en),
		.translate_tid(translate_tid),
		.translate_vaddr(translate_vaddr),
		.translate_perms(translate_perms),
		.translate_nocaddr(translate_nocaddr),
		.translate_phyaddr(translate_phyaddr),
		.translate_done(translate_done),
		.translate_failed(translate_failed),
		
		.mgmt_wr_en(mgmt_wr_en),
		.mgmt_wr_tid(mgmt_wr_tid),
		.mgmt_wr_valid(mgmt_wr_valid),
		.mgmt_wr_perms(mgmt_wr_perms),
		.mgmt_wr_vaddr(mgmt_wr_vaddr),
		.mgmt_wr_nocaddr(mgmt_wr_nocaddr),
		.mgmt_wr_phyaddr(mgmt_wr_phyaddr),
		.mgmt_wr_done(mgmt_wr_done)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test driver code
	
	task assert();
		input value;
		begin
			if(!value) begin	
				$display("FAIL: Assertion failed at T=%.f ns", $time());
				$finish;
			end
		end
	endtask
	
	reg[7:0] count	= 0;
	
	always @(posedge clk) begin
	
		translate_en	<= 0;
		translate_tid	<= 0;
		translate_vaddr	<= 0;
		translate_perms	<= 0;
	
		mgmt_wr_en		<= 0;
		mgmt_wr_tid		<= 0;
		mgmt_wr_valid	<= 0;
		mgmt_wr_perms	<= 0;
		mgmt_wr_vaddr	<= 0;
		mgmt_wr_phyaddr	<= 0;
		mgmt_wr_nocaddr	<= 0;
	
		case(count)
			
			//Look up a nonexistent address (outside the mappable area)
			0: begin
				$display("Looking up unmappable address");
				translate_en	<= 1;
				translate_vaddr	<= 32'hbfc00000;
				translate_tid	<= 2;
				translate_perms	<= 3'h4;		//read
				count			<= 1;
			end
			
			//Expect it to fail
			1: begin
				if(translate_done) begin
					if(translate_failed) begin
						$display("    Got expected failure");
						count		<= 2;
					end
					else begin
						$display("    Translation should have failed, but didn't");
						$finish;
					end
				end
			end
			
			//Look up an unmapped, but mappable, address
			2: begin
				$display("Looking up unmapped address");
				translate_en	<= 1;
				translate_vaddr	<= 32'h40000800;
				translate_tid	<= 2;
				translate_perms	<= 3'h4;		//read
				count			<= 3;
			end
			
			//Expect it to fail
			3: begin
				if(translate_done) begin
					if(translate_failed) begin
						$display("    Got expected failure");
						count		<= 4;
					end
					else begin
						$display("    Translation should have failed, but didn't");
						$finish;
					end
				end
			end
			
			//Try mapping it
			4: begin
				$display("Mapping a page");
				mgmt_wr_en			<= 1;
				mgmt_wr_nocaddr		<= 16'hc001;
				mgmt_wr_phyaddr		<= 32'hc0def000;
				mgmt_wr_tid			<= 2;
				mgmt_wr_vaddr		<= 32'h40000800;
				mgmt_wr_valid		<= 1;
				mgmt_wr_perms		<= 3'h6;	//read and write
				count				<= 5;
			end
			
			5: begin
				if(mgmt_wr_done) begin
					$display("    Done");
					count			<= 6;
				end
			end
			
			//Try looking it up again
			6: begin
				$display("Looking up freshly mapped address");
				translate_en	<= 1;
				translate_vaddr	<= 32'h40000800;
				translate_perms	<= 3'h4;		//read
				translate_tid	<= 2;
				count			<= 7;
			end
			
			7: begin
				if(translate_done) begin
					if(translate_failed) begin
						$display("    Translation failed");
						$finish;
					end
					
					else if( (translate_phyaddr == 32'hc0def000) && (translate_nocaddr == 16'hc001) ) begin
						$display("    Good mapping");
						count		<= 8;
					end
					
					else begin
						$display("    Bad mapping");
						$finish;
					end
					
				end
			end
			
			//Try looking up the same page with an offset
			8: begin
				$display("Looking up freshly mapped address with offset");
				translate_en	<= 1;
				translate_vaddr	<= 32'h400009d0;
				translate_perms	<= 3'h4;		//read
				translate_tid	<= 2;
				count			<= 9;
			end
			
			9: begin
				if(translate_done) begin
					if(translate_failed) begin
						$display("    Translation failed");
						$finish;
					end
					
					else if( (translate_phyaddr == 32'hc0def1d0) && (translate_nocaddr == 16'hc001) ) begin
						$display("    Good mapping");
						count		<= 10;
					end
					
					else begin
						$display("    Bad mapping");
						$finish;
					end
					
				end
			end
			
			//Try looking it up with bad permissions
			//Look up an unmapped, but mappable, address
			10: begin
				$display("Looking up valid address with illegal permissions");
				translate_en	<= 1;
				translate_vaddr	<= 32'h40000800;
				translate_tid	<= 2;
				translate_perms	<= 3'h1;	//execute, illegal
				count			<= 11;
			end
			
			//Expect it to fail
			11: begin
				if(translate_done) begin
					if(translate_failed) begin
						$display("    Got expected failure");
						count		<= 12;
					end
					else begin
						$display("    Translation should have failed, but didn't");
						$finish;
					end
				end
			end
			
			//Try looking it up with bad permissions
			//Look up an unmapped, but mappable, address
			12: begin
				$display("Looking up valid address from the wrong thread");
				translate_en	<= 1;
				translate_vaddr	<= 32'h40000800;
				translate_tid	<= 3;
				translate_perms	<= 3'h4;		//read
				count			<= 13;
			end
			
			//Expect it to fail
			13: begin
				if(translate_done) begin
					if(translate_failed) begin
						$display("    Got expected failure");
						count		<= 14;
					end
					else begin
						$display("    Translation should have failed, but didn't");
						$finish;
					end
				end
			end
			
			14: begin
				$display("PASS: Test completed without error");
				$finish;
			end
			
		endcase
	
	end

	initial begin
		#5000;
		$display("FAIL: Test timed out");
		$finish;
	end

endmodule

