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
	@brief Formal validation test harness for RPCv2Transceiver_receive
	
	The goal of this test is to prove that the receiver always correctly interprets well-formed incoming packets.
		
	More formally:
		* During the idle state, data lines don't change and rpc_fab_rx_en is low. rpc_rx_ack is RPC_ACK_IDLE.
		* When rpc_rx_en goes high, rpc_rx_ack goes to RPC_ACK_ACK for one cycle and rpc_fab_rx_[src|dest]_addr
		  are updated appropriately.
		* The next cycle, rpc_fab_rx_[callnum|type|d0] are updated.
		* The next cycle, rpc_fab_rx_d1 is updated.
		* The next cycle, rpc_fab_rx_d2 is updated and rpc_fab_rx_en goes high for one cycle.
		* If rpc_rx_en goes high at this point, rpc_rx_ack is set to RPC_ACK_NAK for one cycle.
		* When rpc_fab_rx_ack goes high, return to the idle state.
 */
module main(
	clk,
	rpc_rx_en, rpc_rx_data, rpc_fab_rx_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	
	input wire			rpc_fab_rx_done;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceiver

	wire[1:0]			rpc_rx_ack;
	
	wire				rpc_fab_rx_en;
	wire[15:0]			rpc_fab_rx_src_addr;
	wire[15:0]			rpc_fab_rx_dst_addr;
	wire[7:0]			rpc_fab_rx_callnum;
	wire[2:0]			rpc_fab_rx_type;
	wire[20:0]			rpc_fab_rx_d0;
	wire[31:0]			rpc_fab_rx_d1;
	wire[31:0]			rpc_fab_rx_d2;
	wire				rpc_fab_inbox_full;
	
	RPCv2Transceiver_receive rx (
		.clk(clk),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[2:0] state		= 0;
	
	reg rpc_fab_rx_en_expected	= 0;
	reg rpc_rx_nak_expected		= 0;
	
	//No init value to avoid yosys complaining about set-init-bits when we don't use all of it
	reg[31:0] rpc_rx_data_last;
	
	always @(posedge clk) begin
		
		rpc_rx_data_last <= rpc_rx_data;
		rpc_fab_rx_en_expected <= 0;
		rpc_rx_nak_expected <= 0;
		
		case(state)
			
			//IDLE state
			0: begin
				
				//Should not be ACKing.
				//If, however, we got an rx_en the same cycle that rx_done was set. If so, we should have a NAK here.
				if(!rpc_rx_nak_expected)
					assert(rpc_rx_ack == RPC_ACK_IDLE);
				else
					assert(rpc_rx_ack == RPC_ACK_NAK);
				
				//Data value is a don't-care once rx_done goes high
				//Can change arbitrarily during packet receipt
				
				//Should not be receiving a packet
				assert(rpc_fab_rx_en == 0);
				
				//Continue
				if(rpc_rx_en)
					state <= 1;
					
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);
					
			end
			
			//Done with first cycle of message (routing header)
			1: begin
			
				//We should be ACKing the message
				assert(rpc_rx_ack == RPC_ACK_ACK);
				
				//Should not be starting a message
				assert(rpc_fab_rx_en == 0);
			
				//Verify routing headers
				assert(rpc_fab_rx_src_addr == rpc_rx_data_last[31:16]);
				assert(rpc_fab_rx_dst_addr == rpc_rx_data_last[15:0]);
				
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);
				
				state <= 2;				
			end
			
			//Done with second cycle of message (first data word)
			2: begin
			
				//Should not be starting a message or ACKing
				assert(rpc_rx_ack == RPC_ACK_IDLE);
				assert(rpc_fab_rx_en == 0);
				
				//Verify status flags
				assert(rpc_fab_rx_callnum == rpc_rx_data_last[31:24]);
				assert(rpc_fab_rx_type == rpc_rx_data_last[23:21]);
				assert(rpc_fab_rx_d0 == rpc_rx_data_last[20:0]);
				
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);
				 
				state <= 3;
				
			end
			
			//Done with third cycle of message (second data word)
			3: begin
			
				//Should not be starting a message or ACKing
				assert(rpc_rx_ack == RPC_ACK_IDLE);
				assert(rpc_fab_rx_en == 0);
				
				//Verify message data
				assert(rpc_fab_rx_d1 == rpc_rx_data_last);
				
				//Should have rx_en next cycle
				rpc_fab_rx_en_expected <= 1;
				
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);
				
				state <= 4;
				
			end
			
			//Done with fourth cycle of message (third data word)
			4: begin
			
				//Verify message data during the first cycle
				if(rpc_fab_rx_en_expected) begin
					assert(rpc_fab_rx_en == 1);
					assert(rpc_fab_rx_d2 == rpc_rx_data_last);
				end
				
				//Should not be starting the message
				else
					assert(rpc_fab_rx_en == 0);
				
				//Wait for host to say they're done
				if(rpc_fab_rx_done)
					state <= 0;
					
				//If any packets come in they should be NAKed
				if(rpc_rx_en)
					rpc_rx_nak_expected <= 1;
					
				//Verify that we have a NAK if one is expected
				if(rpc_rx_nak_expected)
					assert(rpc_rx_ack == RPC_ACK_NAK);
				else
					assert(rpc_rx_ack == RPC_ACK_IDLE);
					
				//Inbox should be full
				assert(rpc_fab_inbox_full == 1);
				
			end
			
		endcase
		
	end

endmodule
