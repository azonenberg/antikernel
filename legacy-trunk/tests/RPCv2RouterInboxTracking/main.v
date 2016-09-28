`default_nettype none
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
	@brief Formal validation test harness for RPCv2RouterInboxTracking
	
	The goal of this test is to prove:
	 * port_fab_rx_done is normally zero
	 * port_fab_rx_done goes high if a port is done and was reading from us
	 
	 * port_rdbuf_addr is normally zero
	 * If any port's selected_sender is us, and tx_rd_en is high, port_rdbuf_addr will be set to that port's tx_raddr
 */
module main(
	clk, port_selected_sender, port_fab_tx_done, port_fab_tx_rd_en, port_fab_tx_raddr
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	input wire[14:0]	port_selected_sender;
	input wire[4:0]		port_fab_tx_done;
	input wire[4:0]		port_fab_tx_rd_en;
	input wire[9:0]		port_fab_tx_raddr;
	
	parameter THIS_PORT = 2;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual inbox tracker
	
	wire				port_fab_rx_done;
	wire[1:0]			port_rdbuf_addr;
	
	RPCv2RouterInboxTracking #(
		.PORT_COUNT(4),
		.THIS_PORT(THIS_PORT)
	) tracker (
		.clk(clk),
		.port_selected_sender(port_selected_sender),
		.port_fab_tx_done(port_fab_tx_done),
		.port_fab_rx_done(port_fab_rx_done),
		.port_fab_tx_raddr(port_fab_tx_raddr),
		.port_fab_tx_rd_en(port_fab_tx_rd_en),
		.port_rdbuf_addr(port_rdbuf_addr)
		);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	always @(posedge clk) begin
		
		
		//Should be done if they're done and were reading from us
		if( ((port_selected_sender[ 2 :  0] == THIS_PORT) && port_fab_tx_done[0]) ||
			((port_selected_sender[ 5 :  3] == THIS_PORT) && port_fab_tx_done[1]) ||
			((port_selected_sender[ 8 :  6] == THIS_PORT) && port_fab_tx_done[2]) ||
			((port_selected_sender[11 :  9] == THIS_PORT) && port_fab_tx_done[3]) ||
			((port_selected_sender[14 : 12] == THIS_PORT) && port_fab_tx_done[4])
			) begin
				
			assert(port_fab_rx_done == 1);
			
		end
		
		//not done
		else
			assert(port_fab_rx_done == 0);
			
		//Copy their address if they're reading from us
		if((port_selected_sender[14:12] == THIS_PORT) && port_fab_tx_rd_en[4])
			assert(port_rdbuf_addr == port_fab_tx_raddr[9:8]);
		else if((port_selected_sender[11:9] == THIS_PORT) && port_fab_tx_rd_en[3])
			assert(port_rdbuf_addr == port_fab_tx_raddr[7:6]);
		else if((port_selected_sender[8:6] == THIS_PORT) && port_fab_tx_rd_en[2])
			assert(port_rdbuf_addr == port_fab_tx_raddr[5:4]);
		else if((port_selected_sender[5:3] == THIS_PORT) && port_fab_tx_rd_en[1])
			assert(port_rdbuf_addr == port_fab_tx_raddr[3:2]);
		else if((port_selected_sender[2:0] == THIS_PORT) && port_fab_tx_rd_en[0])
			assert(port_rdbuf_addr == port_fab_tx_raddr[1:0]);
		else
			assert(port_rdbuf_addr == 0);

	end

endmodule
