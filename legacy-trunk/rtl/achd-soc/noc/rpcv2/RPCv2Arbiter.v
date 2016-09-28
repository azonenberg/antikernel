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
	@brief Arbitration for RPCv2 protocol
 */
module RPCv2Arbiter(
	clk,
	port_inbox_full,
	port_dst_addr,
	tx_en, tx_done,
	selected_sender
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Network clock
	input wire clk;
	
	//Status of each incoming port
	input wire[4:0] port_inbox_full;
	
	//Destination address headers for each incoming port
	input wire[79:0] port_dst_addr;
		
	//Link to outbound transceiver
	output reg tx_en = 0;
	input wire tx_done;
	
	//Control signal for muxes
	output reg[2:0] selected_sender = 5;
	
	//Our port number
	parameter THIS_PORT = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Address matching logic
	
	parameter SUBNET_MASK = 16'hFFFC;	//default to /14 subnet
	parameter SUBNET_ADDR = 16'h8000;	//first valid subnet address
	parameter HOST_BIT_HIGH = 1;		//host bits
	localparam HOST_BIT_LOW = HOST_BIT_HIGH - 1;
	
	//Each bit is set if the associated port's destination address refers to us.
	//Note that this may be true even if they are not actually trying to send.
	reg[4:0] port_match = 0;
	
	integer i;
	always @(*) begin
	
		port_match <= 0;
		
		//We are the uplink port - match anything NOT in our subnet
		if(THIS_PORT == 4) begin
			for(i=0; i<5; i=i+1)
				port_match[i] <= (port_dst_addr[i*16 +: 16] & SUBNET_MASK) != SUBNET_ADDR;
		end
		
		//We are a downstream port - match anything IN our subnet and matching our address range
		else begin
			for(i=0; i<5; i=i+1) begin
				port_match[i] <=
					( (port_dst_addr[i*16 +: 16] & SUBNET_MASK) == SUBNET_ADDR ) &&
					( port_dst_addr[i*16 + HOST_BIT_LOW +: 2] == THIS_PORT );
			end
		
		end
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// See who wants to send to us (address match + data in buffer)
	
	reg[4:0] port_sending_to_us;
	
	always @(*) begin
		for(i=0; i<5; i=i+1)
			port_sending_to_us[i] <= port_match[i] && port_inbox_full[i];
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main control logic
	
	reg[2:0] rr_port = THIS_PORT;
	
	localparam STATE_IDLE = 0;
	localparam STATE_SENDING = 1;
	
	reg state = STATE_IDLE;
	always @(posedge clk) begin
	
		tx_en <= 0;
	
		case(state)
			
			//Idle - wait for someone to send to us
			STATE_IDLE: begin
			
				//Default to reading from port 5 (nonexistent)
				selected_sender <= 5;
				
				//Assume no round-robin match
				//Let the first port who wants to talk do so
				//Uplink has top priority, then other ports
				for(i=4; i>=0; i=i-1) begin
					if(port_sending_to_us[i]) begin
						state <= STATE_SENDING;
						selected_sender <= i[2:0];
						tx_en <= 1;
					end
				end
								
				//Check for round-robin match at end, they get max priority
				for(i=4; i>=0; i=i-1) begin
					if(port_sending_to_us[i] && (rr_port == i) ) begin
						state <= STATE_SENDING;
						selected_sender <= i[2:0];
						tx_en <= 1;
					end
				end
			
			end
			
			//Sending - wait for transmission to complete, then bump round-robin port and continue
			STATE_SENDING: begin
				if(tx_done) begin
					rr_port <= rr_port + 3'h1;
					if(rr_port == 4)
						rr_port <= 0;
					
					//Clear selected sender immediately, by the time we see tx_done they're already
					//finished processing the packet
					selected_sender <= 5;
					
					state <= STATE_IDLE;
				end
			end
			
		endcase
	
	end
	
endmodule
