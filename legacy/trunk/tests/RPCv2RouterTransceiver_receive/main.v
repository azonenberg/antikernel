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
	@brief Formal validation test harness for RPCv2RouterTransceiver_receive
	
	The goal of this test is to prove that the receiver always correctly interprets well-formed incoming packets.
		
	More formally:
		* rpc_rx_ack is RPC_ACK_IDLE when a receive is not in progress.
		* When rpc_rx_en is asserted, rpc_rx_ack is set to RPC_ACK_ACK for one cycle if the transceiver is idle. During
		  the remainder of the packet, rpc_rx_ack is set to RPC_ACK_IDLE.
		* During the cycle that rpc_rx_en was asserted, as well as the following three cycles, rpc_fab_rx_we is asserted
		  and rpc_fab_rx_waddr counts from 0 to 3.
		* During the first cycle of the packet, rpc_fab_rx_dst_addr is set to the low 16 bits of rpc_rx_data.
		* Once the packet is fully received, if rpc_rx_en goes high rpc_rx_ack is set to RPC_ACK_NAK the following
		  cycle. rpc_fab_inbox_full goes high and stays high until reset.
		* When rpc_fab_rx_done is asserted, the module resets and is ready for another packet.
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
	wire[1:0]			rpc_fab_rx_waddr;
	wire[31:0]			rpc_fab_rx_wdata;
	wire[15:0]			rpc_fab_rx_dst_addr;
	wire				rpc_fab_rx_we;
	wire				rpc_fab_inbox_full;
	
	RPCv2RouterTransceiver_receive rx(
		.clk(clk),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_waddr(rpc_fab_rx_waddr),
		.rpc_fab_rx_wdata(rpc_fab_rx_wdata),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		
		.rpc_fab_rx_we(rpc_fab_rx_we),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[3:0] state		= 0;

	reg rpc_rx_nak_expected		= 0;
	
	reg[15:0] rpc_header_expected	= 0;
	reg rpc_fab_rx_en_expected			= 0;
	
	always @(posedge clk) begin
		
		rpc_rx_nak_expected <= 0;
		rpc_fab_rx_en_expected <= 0;

		//Data should always be combinatorially forwarded.
		//We normally can expect rpc_rx_data to be zero if a packet isn't in progress, as both transceivers will do this.
		//It doesn't really matter what the data is when a packet isn't in progress as long as rpc_fab_rx_we is not set,
		//as the data won't do anything.
		assert(rpc_fab_rx_wdata == rpc_rx_data);
		
		//Header should change only when we expect it to
		assert(rpc_fab_rx_dst_addr == rpc_header_expected);
			
		//Should only start a message when we expect it
		assert(rpc_fab_rx_en_expected == rpc_fab_rx_en);

		case(state)
			
			//IDLE state
			0: begin
				
				//Should not be ACKing.
				//If, however, we got an rx_en the same cycle that rx_done was set. If so, we should have a NAK here.
				if(!rpc_rx_nak_expected)
					assert(rpc_rx_ack == RPC_ACK_IDLE);
				else
					assert(rpc_rx_ack == RPC_ACK_NAK);
		
				//Should be ready to write to address zero
				assert(rpc_fab_rx_waddr == 0);

				//If a packet comes in. we should sample the header and write to the buffer.
				if(rpc_rx_en) begin
					state <= 1;
					rpc_header_expected <= rpc_rx_data[15:0];
					assert(rpc_fab_rx_we == 1);
				end

				//Nothing is happening
				else
					assert(rpc_fab_rx_we == 0);
					
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);

			end
			
			//Done with second cycle of message (first data word)
			1: begin

				//We should be ACKing the message
				assert(rpc_rx_ack == RPC_ACK_ACK);
				
				//Should be writing to address 1
				assert(rpc_fab_rx_waddr == 1);
				assert(rpc_fab_rx_we == 1);
				
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);

				state <= 2;				
			end
			
			//Done with third cycle of message (second data word)
			2: begin

				//Should not be ACKing
				assert(rpc_rx_ack == RPC_ACK_IDLE);
				
				//Write to next address
				assert(rpc_fab_rx_waddr == 2);
				assert(rpc_fab_rx_we == 1);
				
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);

				state <= 3;
				
			end
			
			//Done with fourth cycle of message (third data word)
			3: begin

				//Should not be ACKing
				assert(rpc_rx_ack == RPC_ACK_IDLE);
						
				//Write to next address
				assert(rpc_fab_rx_waddr == 3);
				assert(rpc_fab_rx_we == 1);
				
				//Should not have anything in inbox
				assert(rpc_fab_inbox_full == 0);
				
				//Expect rx_en next cycle
				rpc_fab_rx_en_expected <= 1;

				state <= 4;
				
			end
		
			//Done with entire message
			4: begin

				//Inbox should be full
				assert(rpc_fab_inbox_full == 1);

				//Wait for host to say they're done
				if(rpc_fab_rx_done) begin
					rpc_header_expected <= 0;
					state				<= 0;
				end

				//If any packets come in they should be NAKed
				if(rpc_rx_en)
					rpc_rx_nak_expected <= 1;
					
				//Verify that we have a NAK if one is expected
				if(rpc_rx_nak_expected)
					assert(rpc_rx_ack == RPC_ACK_NAK);
				else
					assert(rpc_rx_ack == RPC_ACK_IDLE);

			end
			
		endcase
		
	end

endmodule
