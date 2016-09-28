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
	@brief Formal validation test harness for RPCv2Arbiter 
 */
module main(
	clk,
	p0_en, p1_en, p2_en, p3_en, up_en,
	p0_addr, p1_addr, p2_addr, p3_addr, up_addr);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk;
	input wire[2:0] p0_addr;
	input wire[2:0] p1_addr;
	input wire[2:0] p2_addr;
	input wire[2:0] p3_addr;
	input wire[2:0] up_addr;
	
	input wire p0_en;
	input wire p1_en;
	input wire p2_en;
	input wire p3_en;
	input wire up_en;
	
	parameter THIS_PORT = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State tracking

	//Connections to arbiter
	wire tx_en;
	reg tx_done = 0;
	
	//State simulating a transceiver
	reg tx_active = 0;
	reg[1:0] done_count = 0;
	always @(posedge clk) begin
		tx_done <= 0;
	
		if(tx_en) begin
			tx_active <= 1;
			done_count <= 0;
		end

		else if(tx_active) begin
			case(done_count)
				0: done_count <= 1;
				1: done_count <= 2;
				2: done_count <= 3;
				3: begin
					done_count <= 0;
					tx_active <= 0;
					tx_done <= 1;
				end
			endcase
		end
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Input buffering
	
	wire[2:0] selected_sender;
	
	reg[2:0] p0_addr_buf = 0;
	reg[2:0] p1_addr_buf = 0;
	reg[2:0] p2_addr_buf = 0;
	reg[2:0] p3_addr_buf = 0;
	reg[2:0] up_addr_buf = 0;
	
	reg[4:0] port_inbox_full = 0;
		
	//Timer to keep track of how long any given port has been waiting
	integer i;
	reg[5:0] port_wait_time[4:0];
	initial begin
		for(i=0; i<5; i=i+1)
			port_wait_time[i] <= 0;
	end
	
	always @(posedge clk) begin
	
		//Keep track of how long ports have been waiting
		for(i=0; i<5; i=i+1) begin
			if(port_inbox_full[i])
				port_wait_time[i] <= port_wait_time[i] + 6'h1;
		end
	
		//If any input buffer is empty, allow it to be written if someone wants to send to us.
		if(!port_inbox_full[0] && p0_en && (p0_addr == THIS_PORT)) begin
			port_inbox_full[0] <= 1;
			p0_addr_buf <= p0_addr;
			port_wait_time[0] <= 0;
		end
		if(!port_inbox_full[1] && p1_en && (p1_addr == THIS_PORT)) begin
			port_inbox_full[1] <= 1;
			p1_addr_buf <= p1_addr;
			port_wait_time[1] <= 0;
		end
		if(!port_inbox_full[2] && p2_en && (p2_addr == THIS_PORT)) begin
			port_inbox_full[2] <= 1;
			p2_addr_buf <= p2_addr;
			port_wait_time[2] <= 0;
		end
		if(!port_inbox_full[3] && p3_en && (p3_addr == THIS_PORT)) begin
			port_inbox_full[3] <= 1;
			p3_addr_buf <= p3_addr;
			port_wait_time[3] <= 0;
		end
		if(!port_inbox_full[4] && up_en && (up_addr == THIS_PORT)) begin
			port_inbox_full[4] <= 1;
			up_addr_buf <= up_addr;
			port_wait_time[4] <= 0;
		end

		//If a message was sent, clear the buffer
		if(tx_en) begin
			for(i=0; i<5; i=i+1) begin
				if(selected_sender == i)
					port_inbox_full[i] <= 0;
			end
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Non-Starvation
	// If a port wants to send, it eventually will get to do so regardless of load on other ports.
	// Max wait time is 36 cycles (6 cycles per packet, 5 sources + RR wraparound)
	
	always @(posedge clk) begin

		for(i=0; i<5; i=i+1)
			assert(port_wait_time[i] < 37);
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	wire[15:0] p0_dst_addr		= {12'h800, 1'h0, p0_addr_buf};
	wire[15:0] p1_dst_addr		= {12'h800, 1'h0, p1_addr_buf};
	wire[15:0] p2_dst_addr		= {12'h800, 1'h0, p2_addr_buf};
	wire[15:0] p3_dst_addr 		= {12'h800, 1'h0, p3_addr_buf};
	wire[15:0] up_dst_addr		= {12'h800, 1'h0, up_addr_buf};
	
	RPCv2Arbiter #(
		.THIS_PORT(THIS_PORT)
	) uut (
		.clk(clk),
		.port_inbox_full(port_inbox_full),
		.port_dst_addr({
			up_dst_addr,
			p3_dst_addr,
			p2_dst_addr,
			p1_dst_addr,
			p0_dst_addr
		}),
		.tx_en(tx_en),
		.tx_done(tx_done),
		.selected_sender(selected_sender)
	);
	
endmodule
