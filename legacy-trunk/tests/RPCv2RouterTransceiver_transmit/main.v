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
	@brief Formal validation test harness for RPCv2RouterTransceiver_transmit
	
	The goal of this test is to prove that the transceiver always produces valid, correctly formed RPC messages from
	the input data.
		
	More formally:
		* When the transmitter is idle, tx_en, tx_done, and tx_data are always zero
		* When the transmitter is idle, asserting tx_en will start a transmission
		* The next cycle, we read data word 0.
		* The next cycle, tx_en is high and and tx_data is tx_rdata. If LEAF_ADDR is set, tx_rdata[31:16] is replaced
		  with LEAF_ADDR. Read data word 1.
		* The next cycle, tx_data is tx_rdata. Read data word 2.
		* The next cycle, tx_data is tx_rdata. Read data word 3.
		* The next cycle, tx_data is tx_rdata and no read occurs.
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
	tx_en, tx_ack, rpc_fab_tx_rdata
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			tx_en;
	input wire[1:0]		tx_ack;
	input wire[31:0]	rpc_fab_tx_rdata;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceiver

	wire				rpc_tx_en;
	wire[31:0]			rpc_tx_data;
	wire				rpc_fab_tx_rd_en;
	wire[1:0]			rpc_fab_tx_raddr;
	wire				rpc_fab_tx_done;

	RPCv2RouterTransceiver_transmit #(
		.LEAF_PORT(1),
		.LEAF_ADDR(16'h8002)
	) txvr (
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(tx_ack),
		
		.rpc_fab_tx_en(tx_en),
		.rpc_fab_tx_rd_en(rpc_fab_tx_rd_en),
		.rpc_fab_tx_raddr(rpc_fab_tx_raddr),
		.rpc_fab_tx_rdata(rpc_fab_tx_rdata),
		.rpc_fab_tx_done(rpc_fab_tx_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[3:0]	txvr_state					= 0;
	
	reg			tx_got_ack = 0;
	reg			tx_retransmit_needed 		= 0;
	reg[1:0]	tx_raddr_expected			= 0;
	reg			rpc_fab_tx_done_expected	= 0;
	
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
																//(this should not be possible in a real network)
				endcase
			end
			
		end
		
		//Verify we're always reading the right address (increments each time a read happens)
		assert(rpc_fab_tx_raddr == tx_raddr_expected);
		if(rpc_fab_tx_rd_en)
			tx_raddr_expected <= tx_raddr_expected + 2'h1;
		
		//Verify we're done at the expected time and no others
		rpc_fab_tx_done_expected <= 0;
		assert(rpc_fab_tx_done == rpc_fab_tx_done_expected);
	
		case(txvr_state)
			
			//IDLE - wait for something to happen
			0: begin
			
				//Verify that we're ready to read the packet headers
				assert(rpc_fab_tx_raddr == 0);
			
				//Start a transmission
				if(tx_en || tx_retransmit_needed) begin
				
					//Clear ACK flags
					tx_got_ack <= 0;
					tx_retransmit_needed <= 0;

					//Go on to next state
					txvr_state <= 1;
					
				end

				//Should not be reading
				assert(rpc_fab_tx_rd_en == 0);
				
				//All outputs should be low if not transmitting
				assert(rpc_tx_en == 0);
				assert(rpc_tx_data == 0);

			end
			
			//FETCH - read data from SRAM
			1: begin
				
				//Should be reading
				assert(rpc_fab_tx_rd_en == 1);

				//Header word was read, time to start the packet
				if(rpc_fab_tx_raddr == 1) begin
				
					//Should be transmitting this cycle
					assert(rpc_tx_en == 1);
					
					//Should have valid packet headers with source address overwritten.
					assert(rpc_tx_data == {16'h8002, rpc_fab_tx_rdata[15:0]});
					
				end
				
				//Packet body
				else begin
					
					//Should not be starting a transmit
					assert(rpc_tx_en == 0);
					
					//Should be copying message data unless this is the first cycle
					if(rpc_fab_tx_raddr == 0)
						assert(rpc_tx_data == 0);
					else
						assert(rpc_tx_data == rpc_fab_tx_rdata);
					
				end
				
				if(rpc_fab_tx_raddr == 3)
					txvr_state <= 2;
			end
			
			//Wait for an ACK
			2: begin
				
				//Not starting a packet
				assert(rpc_tx_en == 0);
				
				//Should be copying last word of message
				assert(rpc_tx_data == rpc_fab_tx_rdata);
				
				if(tx_got_ack) begin
					
					//No matter what, go back to start
					txvr_state <= 0;
					
					//Should be done sending if we don't need a a retransmit
					if(!tx_retransmit_needed) begin
						rpc_fab_tx_done_expected <= 1;

						//Clear ACK flags
						tx_got_ack <= 0;
						tx_retransmit_needed <= 0;
					end

				end

			end
			
		endcase
		
	end

endmodule
