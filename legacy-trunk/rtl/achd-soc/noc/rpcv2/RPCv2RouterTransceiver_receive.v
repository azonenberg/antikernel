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

module RPCv2RouterTransceiver_receive(
	
	//System-synchronous clock
	clk,
	
	//Network interface, inbound side
	rpc_rx_en, rpc_rx_data, rpc_rx_ack,
		
	//Fabric interface, inbound side
	rpc_fab_rx_en,
	rpc_fab_rx_waddr, rpc_fab_rx_wdata, rpc_fab_rx_dst_addr, rpc_fab_rx_we,
	rpc_fab_rx_done, rpc_fab_inbox_full
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	`include "RPCv2Router_ack_constants.v"
	
	//System-synchronous clock
	input wire clk;

	//Network interface, inbound side
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output reg[1:0]  rpc_rx_ack				= RPC_ACK_IDLE;
	
	//Fabric interface, inbound side
	output reg      	rpc_fab_rx_en			= 0;
	output reg[1:0]	 	rpc_fab_rx_waddr;
	output wire[31:0] 	rpc_fab_rx_wdata;
	output reg[15:0] 	rpc_fab_rx_dst_addr		= 0;
	output reg		 	rpc_fab_rx_we;
	input wire     		rpc_fab_rx_done;
	output wire			rpc_fab_inbox_full;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Actual state logic
	
	assign rpc_fab_rx_wdata = rpc_rx_data;
	
	localparam RX_STATE_IDLE	= 0;
	localparam RX_STATE_D0		= 1;
	localparam RX_STATE_D1		= 2;
	localparam RX_STATE_D2		= 3;
	localparam RX_STATE_WAIT	= 4;
	
	//Combinatorial generation of addresses and stuff
	always @(*) begin
		rpc_fab_rx_we <= 0;
		rpc_fab_rx_waddr <= 0;
		
		case(rx_state)
		
			//Write start of packet
			RX_STATE_IDLE: begin
				if(rpc_rx_en)
					rpc_fab_rx_we <= 1;
			end
			
			RX_STATE_D0: begin
				rpc_fab_rx_waddr <= 1;
				rpc_fab_rx_we <= 1;
			end
			
			RX_STATE_D1: begin
				rpc_fab_rx_waddr <= 2;
				rpc_fab_rx_we <= 1;
			end
			
			RX_STATE_D2: begin
				rpc_fab_rx_waddr <= 3;
				rpc_fab_rx_we <= 1;
			end
			
		endcase
		
	end
	
	assign rpc_fab_inbox_full = (rx_state == RX_STATE_WAIT);
	
	reg[2:0] rx_state = RX_STATE_IDLE;
	always @(posedge clk) begin
	
		rpc_rx_ack <= RPC_ACK_IDLE;
		rpc_fab_rx_en <= 0;
	
		case(rx_state)
			
			//Idle - sit around and wait for packets to come in
			RX_STATE_IDLE: begin
							
				//If a packet comes in, acknowledge it and save the header
				if(rpc_rx_en) begin
					rpc_fab_rx_dst_addr <= rpc_rx_data[15:0];
					
					//We're available, acknowledge it
					//This is the routing header, save it and go on to the next word
					rpc_rx_ack <= RPC_ACK_ACK;
					rx_state <= RX_STATE_D0;
				end
				
			end	//end RX_STATE_IDLE
			
			//Receive data
			RX_STATE_D0: begin
				rx_state <= RX_STATE_D1;
			end
			RX_STATE_D1: begin
				rx_state <= RX_STATE_D2;
			end
			RX_STATE_D2: begin
				rpc_fab_rx_en <= 1;
				rx_state <= RX_STATE_WAIT;
			end
			
			//Wait for rpc_fab_rx_done
			RX_STATE_WAIT: begin
			
				//Done?
				if(rpc_fab_rx_done) begin
					rx_state <= RX_STATE_IDLE;
					
					//Wipe dest address back to zero
					rpc_fab_rx_dst_addr <= 0;
				end
				
				//Reject any incoming packets with a NAK
				if(rpc_rx_en)
					rpc_rx_ack <= RPC_ACK_NAK;

			end
			
		endcase
	end	
	
endmodule
