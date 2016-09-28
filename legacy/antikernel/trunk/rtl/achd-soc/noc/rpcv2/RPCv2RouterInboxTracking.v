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
	@brief Figure out who's using our output and pick the right addresses
 */
module RPCv2RouterInboxTracking(
	clk,
	port_selected_sender, port_fab_tx_rd_en, port_fab_tx_raddr, port_fab_tx_done, port_fab_rx_done, port_rdbuf_addr
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Network clock
	input wire								clk;
	
	//Number of downstream ports (upstream not included in total)
	parameter PORT_COUNT					= 4;
	
	//Index of this port
	parameter THIS_PORT						= 0;
	
	//Number of total ports including upstream
	localparam TOTAL_PORT_COUNT				= PORT_COUNT + 1;
	
	input wire[3*TOTAL_PORT_COUNT - 1 : 0]	port_selected_sender;
	input wire[TOTAL_PORT_COUNT - 1 : 0]	port_fab_tx_done;
	
	input wire[TOTAL_PORT_COUNT-1 : 0]		port_fab_tx_rd_en;
	input wire[TOTAL_PORT_COUNT*2 - 1:0]	port_fab_tx_raddr;
	
	//Clear inbox
	output reg								port_fab_rx_done;
	
	//Inbox SRAM read address for this port
	output reg[1:0]							port_rdbuf_addr;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main control logic
	
	integer i;
	always @(*) begin
	
		//Default to not done
		port_fab_rx_done <= 0;
		
		//Default address to zero if nobody is reading from us
		port_rdbuf_addr <= 0;
	
		//Check all ports and see if we're routing to them
		for(i=0; i<TOTAL_PORT_COUNT; i=i+1) begin
			if(port_selected_sender[3*i +: 3] == THIS_PORT) begin
		
				//Use their address if they're actually reading
				if(port_fab_tx_rd_en[i])
					port_rdbuf_addr <= port_fab_tx_raddr[i*2 +: 2];
		
				//If any ports are reading from us, and done, then flush our inbox
				if(port_fab_tx_done[i])
					port_fab_rx_done <= 1;
		
			end
		end

	end
	
endmodule
