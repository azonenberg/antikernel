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
	@brief ISim simulation test for ByteStreamPacketFifo
 */

module testByteStreamPacketFifo;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock generation

	reg	clk	= 0;
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
	
	reg			wr_start	= 0;
	reg[10:0]	wr_len		= 0;
	reg			wr_en		= 0;
	reg[31:0]	wr_data		= 0;
	reg			wr_commit	= 0;
	reg			wr_rollback = 0;
	wire		wr_overflow;
	wire		wr_mdfull;
	
	wire[10:0]	rd_len;
	wire		rd_ready;
	reg			rd_retransmit	= 0;
	reg			rd_next			= 0;
	reg			rd_en			= 0;
	wire[31:0]	rd_data;
	reg			rd_ack			= 0;
	
	ByteStreamPacketFifo #(
		.DEPTH(1024)
	) dut(
		.clk(clk),
		.reset(1'b0),
		
		.wr_start(wr_start),
		.wr_len(wr_len),
		.wr_en(wr_en),
		.wr_data(wr_data),
		.wr_commit(wr_commit),
		.wr_rollback(wr_rollback),
		.wr_overflow(wr_overflow),
		.wr_mdfull(wr_mdfull),
		
		.rd_len(rd_len),
		.rd_ready(rd_ready),
		.rd_retransmit(rd_retransmit),
		.rd_next(rd_next),
		.rd_en(rd_en),
		.rd_data(rd_data),
		.rd_ack(rd_ack)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test logic
	
	reg[7:0] state	= 0;
	reg[7:0] count	= 0;
		
	always @(posedge clk) begin
		
		wr_start		<= 0;
		wr_en			<= 0;
		wr_commit		<= 0;
		wr_rollback		<= 0;
		rd_en			<= 0;
		rd_next			<= 0;
		rd_retransmit	<= 0;
		rd_ack			<= 0;
		
		//default to advancing state
		state			<= state + 1'h1;
		
		case(state)
			
			//Prepare to write a 6-byte packet to the FIFO
			0: begin
				wr_start	<= 1;
				wr_len		<= 6;
			end
			
			//Write the packet itself
			1: begin
				wr_en		<= 1;
				wr_data		<= 32'hfeedface;
			end
			2: begin
				wr_en		<= 1;
				wr_data		<= 32'hc0de0000;
			end
			
			//Done, commit the write
			3: 	wr_commit	<= 1;		
			//4: Wait for commit
			
			//Verify that there is a packet available
			5: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 6) begin
					$display("ERROR: Expected 6-byte packet but got something else");
					$finish;
				end
			end
			
			//Write another packet
			6: begin
				wr_start	<= 1;
				wr_len		<= 5;
			end
			7: begin
				wr_en		<= 1;
				wr_data		<= 32'hbaadcafe;
			end
			8: begin
				wr_en		<= 1;
				wr_data		<= 32'hdd000000;
			end
			9: 	wr_commit	<= 1;
			//10: wait for commit

			//Verify the first packet is still available
			11: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 6) begin
					$display("ERROR: Expected 6-byte packet but got something else");
					$finish;
				end
			end
			
			//Try reading it
			12: rd_en		<= 1;
			13: rd_en		<= 1;
			14: begin
				if(rd_data != 32'hfeedface) begin
					$display("FAIL: Expected 32'hfeedface, got %08x", rd_data);
					$finish;
				end
			end
			15: begin
				if(rd_data[31:16] != 16'hc0de) begin
					$display("FAIL: Expected 32'hc0dexxxx, got %08x", rd_data);
					$finish;
				end
			end
			
			//Try reading the next packet
			16: rd_next		<= 1;
			//17: wait for fifo pop
			18: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 5) begin
					$display("ERROR: Expected 5-byte packet but got something else");
					$finish;
				end
			end
			
			//Try reading it
			19: rd_en		<= 1;
			20: rd_en		<= 1;
			21: begin
				if(rd_data != 32'hbaadcafe) begin
					$display("FAIL: Expected 32'hbaadcafe, got %08x", rd_data);
					$finish;
				end
			end
			22: begin
				if(rd_data[31:24] != 8'hdd) begin
					$display("FAIL: Expected 32'hddxxxxxx, got %08x", rd_data);
					$finish;
				end
			end
			
			//Go on to the next packet (there isn't one)
			23: rd_next	<= 1;
			//24: wait for pop
			
			//Verify there's no packet ready
			25: begin
				if(rd_ready) begin
					$display("ERROR: Should not be a packet ready, but there is");
					$finish;
				end
			end
			
			//Retransmit
			26: rd_retransmit	<= 1;
			//27: wait for retransmit
			28: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 6) begin
					$display("ERROR: Expected 6-byte packet but got something else");
					$finish;
				end
			end
			
			//Try reading it again
			29:	rd_en	<= 1;
			30:	rd_en	<= 1;
			31: begin
				if(rd_data != 32'hfeedface) begin
					$display("FAIL: Expected 32'hfeedface, got %08x", rd_data);
					$finish;
				end
			end
			32: begin
				if(rd_data[31:16] != 16'hc0de) begin
					$display("FAIL: Expected 32'hc0dexxxx, got %08x", rd_data);
					$finish;
				end
			end
			
			//Done reading this one
			33: rd_next	<= 1;
			//34: wait for fifo pop
			35: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 5) begin
					$display("ERROR: Expected 5-byte packet but got something else");
					$finish;
				end
			end
			
			//Push a third packet into the fifo
			//Write another packet
			36: begin
				wr_start	<= 1;
				wr_len		<= 3;
			end
			37: begin
				wr_en		<= 1;
				wr_data		<= 32'h558bec00;
			end
			38: wr_commit	<= 1;
			//39: wait for commit

			//Verify the current packet is still available
			40: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 5) begin
					$display("ERROR: Expected 5-byte packet but got something else");
					$finish;
				end
			end
			
			//Verify the second packet reads correctly
			41: rd_en		<= 1;
			42: rd_en		<= 1;
			43: begin
				if(rd_data != 32'hbaadcafe) begin
					$display("FAIL: Expected 32'hbaadcafe, got %08x", rd_data);
					$finish;
				end
			end
			44: begin
				if(rd_data[31:24] != 8'hdd) begin
					$display("FAIL: Expected 32'hddxxxxxx, got %08x", rd_data);
					$finish;
				end
			end
			
			//Done reading this one
			45: rd_next	<= 1;
			//46: wait for fifo pop
			47: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 3) begin
					$display("ERROR: Expected 3-byte packet but got something else");
					$finish;
				end
			end
			
			//Try reading the third packet
			48:	rd_en	<= 1;
			//49: wait for fifo pop
			50: begin
				if(rd_data[31:8] != 24'h558bec) begin
					$display("FAIL: Expected 32'h558becxx, got %08x", rd_data);
					$finish;
				end
			end
			
			//Now we have 3 packets in the buffer
			//ACK the first one
			51:	rd_ack	<= 1;
			
			//Retransmit and verify we go to the SECOND packet now
			52: rd_retransmit	<= 1;
			//53: wait for retransmit
			54: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 5) begin
					$display("ERROR: Expected 5-byte packet but got something else");
					$finish;
				end
			end
			
			//Try actually reading it
			55: rd_en		<= 1;
			56: rd_en		<= 1;
			57: begin
				if(rd_data != 32'hbaadcafe) begin
					$display("FAIL: Expected 32'hbaadcafe, got %08x", rd_data);
					$finish;
				end
			end
			58: begin
				if(rd_data[31:24] != 8'hdd) begin
					$display("FAIL: Expected 32'hddxxxxxx, got %08x", rd_data);
					$finish;
				end
			end
			
			//ACK the second and third packets
			59: rd_ack	<= 1;
			60:	rd_ack	<= 1;
			
			//61:Wait for pop
			
			//Should be nothing to read
			62: begin
				if(rd_ready || (rd_len != 0)) begin
					$display("ERROR: Should not have a packet ready");
					$finish;
				end
			end
			
			//Push a 2-word dummy packet
			63: begin
				wr_start	<= 1;
				wr_len		<= 7;
			end
			64: begin
				wr_en		<= 1;
				wr_data		<= 32'hccddeeff;
			end
			65: begin
				wr_en		<= 1;
				wr_data		<= 32'haabb9900;
			end
			66: wr_commit	<= 1;
			//67: wait for commit
			
			68: begin
				if(!rd_ready) begin
					$display("ERROR: Should be a packet ready, but there isn't");
					$finish;
				end
				if(rd_len != 7) begin
					$display("ERROR: Expected 7-byte packet but got something else");
					$finish;
				end
			end
			69: rd_en		<= 1;
			70: rd_en		<= 1;
			71: begin
				if(rd_data != 32'hccddeeff) begin
					$display("FAIL: Expected 32'hccddeeff, got %08x", rd_data);
					$finish;
				end
			end
			72: begin
				if(rd_data[31:8] != 24'haabb99) begin
					$display("FAIL: Expected 32'haabb99xx, got %08x", rd_data);
					$finish;
				end
			end
			
			//All good
			73: begin
				$display("PASS");
				$finish;
			end
			
		endcase
	
	end
	
	initial begin
		#25000;
		$display("FAIL: Test timed out");
		$finish;
	end
	
endmodule

