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
	@brief Formal validation test harness for RPCv2Transceiver_transmit
	
	The goal of this test is to prove that the transceiver always produces valid, correctly formed RPC messages from
	the input data.
		
	More formally:
		* When the transmitter is idle, tx_en, tx_done, and tx_data are always zero
		* When the transmitter is idle, asserting tx_en will start a transmission
		* The same cycle, tx_data is {tx_src_addr, tx_dst_addr}. If LEAF_PORT is set,
		  tx_src_addr is replaced by LEAF_ADDR.
		* The next cycle, tx_data is {tx_callnum, tx_type, tx_d0}
		* The next cycle, tx_data is d1
		* The next cycle, tx_data is d2
		* If tx_ack is ever set to RPC_ACK_NAK then a retransmit will occur the next cycle, or after sending d2,
		  whichever comes later.
		* If tx_ack is ever set to RPC_ACK_ACK then tx_done will be set the next cycle, or after sending d2, whichever
		  comes later.
		* tx_en is ignored if the transceiver is not idle.
		* All data fields are sampled one cycle before tx_data is updated. This means that retransmitted packets can
		  hypothetically be different from the originally sent packet. Standards-compliant receivers MUST ignore packet
		  data if they did not ACK it.
 */
module main(
	clk,
	tx_en, tx_ack, tx_d0, tx_d1, tx_d2, tx_d3
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			tx_en;
	input wire[1:0]		tx_ack;
	input wire[31:0]	tx_d0;
	input wire[31:0]	tx_d1;
	input wire[31:0]	tx_d2;
	input wire[31:0]	tx_d3;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceiver
	
	wire				rpc_tx_en;
	wire[31:0]			rpc_tx_data;
	wire				rpc_fab_tx_done;
	
	RPCv2Transceiver_transmit txvr (
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(tx_ack),
		
		.rpc_fab_tx_en(tx_en),
		.rpc_fab_tx_src_addr(tx_d0[31:16]),
		.rpc_fab_tx_dst_addr(tx_d0[15:0]),
		.rpc_fab_tx_callnum(tx_d1[31:24]),
		.rpc_fab_tx_type(tx_d1[23:21]),
		.rpc_fab_tx_d0(tx_d1[20:0]),
		.rpc_fab_tx_d1(tx_d2),
		.rpc_fab_tx_d2(tx_d3),
		.rpc_fab_tx_done(rpc_fab_tx_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[2:0] txvr_state		= 0;
	
	reg tx_got_ack = 0;
	reg tx_retransmit_needed = 0;
	
	always @(posedge clk) begin
	
		//Currently transmitting? Search for ACKs
		if(txvr_state != 0) begin
			
			//We have an ACK
			if((tx_ack != RPC_ACK_IDLE) && !tx_got_ack) begin
				tx_got_ack <= 1;
				case(tx_ack)
					RPC_ACK_ACK: tx_retransmit_needed <= 0;		//Positive ACK - we're done
					RPC_ACK_NAK: tx_retransmit_needed <= 1;		//NAK - need to send again
					default: 	tx_retransmit_needed <= 1;		//Invalid value? Treat it as a NAK
				endcase
			end
			
		end
	
		case(txvr_state)
			
			//IDLE - wait for something to happen
			0: begin
			
				//Transmit packet headers if we're starting
				if(tx_en || tx_retransmit_needed) begin
				
					//Clear ACK flags
					tx_got_ack <= 0;
					tx_retransmit_needed <= 0;
					
					//Should be transmitting this cycle
					assert(rpc_tx_en == 1);
					
					//Should have valid packet headers
					assert(rpc_tx_data == tx_d0);

					//Go on to next state
					txvr_state <= 1;
				end
				
				//All outputs should be low if not transmitting
				else begin
					assert(rpc_tx_en == 0);
					assert(rpc_tx_data == 0);
				end
				
				//No matter what, we're not done transmitting
				assert(rpc_fab_tx_done == 0);
					
			end
			
			//Transmit first data word
			1: begin
			
				//Not starting a packet, or done with this one
				assert(rpc_tx_en == 0);
				assert(rpc_fab_tx_done == 0);
			
				//Should have valid data word
				//tx_din was forked off to tx_callnum, tx_type, tx_d0
				//so rpc_tx_data should equal {rpc_fab_tx_callnum, rpc_fab_tx_type, rpc_fab_tx_d0} which is tx_d1
				assert(rpc_tx_data == tx_d1);
			
				//Go on to next state
				txvr_state <= 2;
				
			end
			
			//Transmit second data word
			2: begin
				
				//Not starting a packet, or done with this one
				assert(rpc_tx_en == 0);
				assert(rpc_fab_tx_done == 0);
				
				//Should have valid data word
				//rpc_tx_data should equal rpc_fab_tx_d1 which is tx_d2
				assert(rpc_tx_data == tx_d2);
			
				//Go on to next state
				txvr_state <= 3;
				
			end
			
			//Transmit third data word
			3: begin
				
				//Not starting a packet or done with this one
				assert(rpc_tx_en == 0);
				assert(rpc_fab_tx_done == 0);
				
				//Should have valid data word
				//rpc_tx_data should equal rpc_fab_tx_d2 which is tx_d3
				assert(rpc_tx_data == tx_d3);
			
				//Go on to next state
				txvr_state <= 4;
				
			end
			
			//Wait for an ACK
			4: begin
				
				//Not starting a packet
				assert(rpc_tx_en == 0);
				
				//Should have no data
				assert(rpc_tx_data == 0);
				
				if(tx_got_ack) begin
					
					//No matter what, go back to start
					txvr_state <= 0;
					
					//Should be done sending if we don't need a a retransmit
					if(!tx_retransmit_needed) begin
						
						assert(rpc_fab_tx_done == 1);

						//Clear ACK flags
						tx_got_ack <= 0;
						tx_retransmit_needed <= 0;
					end
					
					//Should not be done sending
					else
						assert(rpc_fab_tx_done == 0);

				end

			end

		endcase

	end
	
endmodule
