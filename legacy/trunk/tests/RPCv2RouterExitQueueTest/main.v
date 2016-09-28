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
	@brief Formal validation test harness for RPCv2Router exit queues
	
	The goal of this test is to prove that, assuming RPCv2RouterTransceiver_receive is correct, that the exit
	queue state is always correct.
	
	More formally:
		Transmitters are initially idle
		When an inbox is full, if its destination address points to us, we begin sending. Note that we are only proving
			that some valid message is sent; RPCv2Arbiter_NoStarve is responsible for proving fairness.
		When we finish sending, the inbox is cleared
 */
module main(
	clk,
	port_tx_ack,
	port_rx_en, port_rx_data
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
		
	//Number of downstream ports (upstream not included in total)
	parameter PORT_COUNT				= 4;
	
	//Number of total ports including upstream
	localparam TOTAL_PORT_COUNT			= PORT_COUNT + 1;
	
	parameter SUBNET_MASK = 16'hFFFC;	//default to /14 subnet
	parameter SUBNET_ADDR = 16'h8000;	//first valid subnet address
	parameter HOST_BIT_HIGH = 1;		//host bits
	localparam HOST_BIT_LOW = HOST_BIT_HIGH - 1;
	
	//Outbound port
	wire[TOTAL_PORT_COUNT-1:0]				port_tx_en;
	wire[TOTAL_PORT_COUNT*32 - 1:0]			port_tx_data;
	input wire[TOTAL_PORT_COUNT*2 - 1:0]	port_tx_ack;
	
	//Inbound port
	input wire[TOTAL_PORT_COUNT-1:0]		port_rx_en;
	input wire[TOTAL_PORT_COUNT*32 - 1:0]	port_rx_data;
	wire[TOTAL_PORT_COUNT*2 - 1:0]			port_rx_ack;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Internal ports on transceivers
	
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_tx_en;
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_tx_done;
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_tx_rd_en;
	wire[TOTAL_PORT_COUNT*2 - 1 : 0]	port_fab_tx_raddr;
	wire[TOTAL_PORT_COUNT*32 - 1 : 0] 	port_fab_tx_rdata;
	
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_rx_en;
	wire[TOTAL_PORT_COUNT*16 - 1 : 0]	port_fab_rx_dst_addr;
	wire[TOTAL_PORT_COUNT-1:0]	 		port_fab_rx_we;
	wire[TOTAL_PORT_COUNT*2 - 1 : 0] 	port_fab_rx_waddr;
	wire[TOTAL_PORT_COUNT*32 - 1 : 0]	port_fab_rx_wdata;
	wire[TOTAL_PORT_COUNT-1:0]			port_fab_rx_done;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Exit queue stuff
	
	//port_selected_sender[3*x +: 3] is the port that should be sending to port x
	wire[3*TOTAL_PORT_COUNT - 1 : 0]	port_selected_sender;
	
	//Read addresses and data for each port
	wire[1:0]							port_rdbuf_addr[TOTAL_PORT_COUNT-1:0];
	wire[TOTAL_PORT_COUNT*32 - 1:0]		port_rdbuf_out;
	
	wire[TOTAL_PORT_COUNT - 1 : 0]		port_fab_rx_done;
	
	//Indicates which ports currently have messages sitting in their buffers
	wire[TOTAL_PORT_COUNT-1:0]	port_inbox_full;
	
	//Reduced version of a full RPC router
	genvar i;
	generate
		
		//Port logic
		for(i=0; i<TOTAL_PORT_COUNT; i = i+1) begin : ports
			
			//Transceiver
			RPCv2RouterTransceiver #(
				.LEAF_PORT(0),
				.LEAF_ADDR(0)
			) txvr (
				
				.clk(clk),
				
				.rpc_tx_en(port_tx_en[i]),
				.rpc_tx_data(port_tx_data[i*32 +: 32]),
				.rpc_tx_ack(port_tx_ack[i*2 +: 2]),
				
				.rpc_rx_en(port_rx_en[i]),
				.rpc_rx_data(port_rx_data[i*32 +: 32]),
				.rpc_rx_ack(port_rx_ack[i*2 +: 2 ]),
				
				.rpc_fab_tx_en(port_fab_tx_en[i]),
				.rpc_fab_tx_rd_en(port_fab_tx_rd_en[i]),
				.rpc_fab_tx_raddr(port_fab_tx_raddr[i*2 +: 2]),
				.rpc_fab_tx_rdata(port_fab_tx_rdata[i*32 +: 32]),
				.rpc_fab_tx_done(port_fab_tx_done[i]),
				
				.rpc_fab_rx_en(port_fab_rx_en[i]),
				.rpc_fab_rx_dst_addr(port_fab_rx_dst_addr[i*16 +: 16]),
				.rpc_fab_rx_we(port_fab_rx_we[i]),
				.rpc_fab_rx_waddr(port_fab_rx_waddr[i*2 +: 2]),
				.rpc_fab_rx_wdata(port_fab_rx_wdata[i*32 +: 32]),
				.rpc_fab_rx_done(port_fab_rx_done[i]),
				.rpc_fab_inbox_full(port_inbox_full[i])
			);

			//Packet buffer SRAM is assumed correct

			//Arbitration
			RPCv2Arbiter #(
				.THIS_PORT(i),
				.SUBNET_MASK(SUBNET_MASK),
				.SUBNET_ADDR(SUBNET_ADDR),
				.HOST_BIT_HIGH(HOST_BIT_HIGH)
			) arbiter (
				.clk(clk),
				.port_inbox_full(port_inbox_full),
				.port_dst_addr(port_fab_rx_dst_addr),
				.tx_en(port_fab_tx_en[i]),
				.tx_done(port_fab_tx_done[i]),
				.selected_sender(port_selected_sender[3*i +: 3])
			);
			
			//Keep track of inbox state
			RPCv2RouterInboxTracking #(
				.PORT_COUNT(PORT_COUNT),
				.THIS_PORT(i)
			) inbox_tracker (
				.clk(clk),
				.port_selected_sender(port_selected_sender),
				.port_fab_tx_rd_en(port_fab_tx_rd_en),
				.port_fab_tx_raddr(port_fab_tx_raddr),
				.port_fab_tx_done(port_fab_tx_done),
				.port_fab_rx_done(port_fab_rx_done[i]),
				.port_rdbuf_addr(port_rdbuf_addr[i])
			);
			
			//Crossbar mux omitted since we're not actually sending anything
			
		end
		
	endgenerate
	
	//SRAM is assumed correct
	//Crossbar is already proven correct

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Verification logic (Duplicate for each port)
	
	`include "RPCv2Router_ack_constants.v"
	
	reg[2:0]	state	= 0;
	reg[2:0]	count	= 0;
	
	integer j;
	
	parameter PROOF_PORT = 0;
	
	reg[4:0] delay_count = 0;
	
	//The port that is currently sending to us, or 5 if nobody
	wire[2:0] our_sender = port_selected_sender[3*PROOF_PORT +: 3];
	
	//The destination address of the port sending to us (should always be our address if we're sending)
	reg[15:0] our_source;
	always @(*) begin
		case(our_sender)
			0: our_source <= port_fab_rx_dst_addr[15:0];
			1: our_source <= port_fab_rx_dst_addr[31:16];
			2: our_source <= port_fab_rx_dst_addr[47:32];
			3: our_source <= port_fab_rx_dst_addr[63:48];
			4: our_source <= port_fab_rx_dst_addr[79:64];
			default:	our_source <= 0;
		endcase
	end
	
	reg[2:0] our_sender_expected = 0;
	
	always @(posedge clk) begin
	
		if(state != 4)
			delay_count <= delay_count + 1;

		case(state)
			
			//IDLE - wait for something to happen
			0: begin
				
				//Should not be sending
				assert(port_fab_tx_en[PROOF_PORT] == 0);
				
				//If a message is here, and it's addressed to us, we should start sending.
				//Do different checks depending on whether we're the upstream port or not.
				//At this point, we are only checking if SOMEONE is sending to us, we don't care who it is.
				//That's the arbiter's job and we only care that they make a valid decision.
				for(j=0; j<5; j = j+1) begin
				
					//Upstream port - check for subnet not matching
					if(PROOF_PORT == 4) begin
						if( (port_fab_rx_dst_addr[16*j +: 16] & SUBNET_MASK) != SUBNET_ADDR)
							state <= 1;
					end
					
					//Normal port
					else if(port_inbox_full[j] && 												//message is there
						( (port_fab_rx_dst_addr[16*j +: 16] & SUBNET_MASK) == SUBNET_ADDR )	&&	//in our subnet
						(port_fab_rx_dst_addr[16*j + HOST_BIT_LOW +: 2] == PROOF_PORT)			//our port index
						) begin
							state <= 1;
					end
					
				end
				
			end	//state 0
			
			//Someone should be sending to us. Make sure they are, and that we're the destination.
			1: begin
				
				//Verify that we're reading from a valid port
				assert(our_sender != 5);
				
				//Save sender, this should not change during the send of the packet
				our_sender_expected <= our_sender;
				
				//Nobody should be flushing this port_fab_rx_done
				assert(port_fab_rx_done[our_sender] == 0);
				
				//Verify the message is being sent to us
				if(PROOF_PORT == 4)
					assert((our_source & SUBNET_MASK) != SUBNET_ADDR);
				else begin
					assert((our_source & SUBNET_MASK) == SUBNET_ADDR);
					assert(our_source[HOST_BIT_HIGH:HOST_BIT_LOW] == PROOF_PORT);
				end
					
				//We should be starting a send
				assert(port_fab_tx_en[PROOF_PORT] == 1);
				state <= 2;
				
			end	//state 1
			
			//We're sending, verify nobody clears the inbox
			2: begin
				
				//Make sure sender is valid
				assert(our_sender == our_sender_expected);
				
				//Make sure nobody is flushing the inbox while the send is in progress.
				//But we should flush when the send completes.
				if(port_fab_tx_done[PROOF_PORT]) begin
					assert(port_fab_rx_done[our_sender] == 1);
					state <= 0;
				end
				else
					assert(port_fab_rx_done[our_sender] == 0);
				
			end	//state 2
			
			//Hold here forever
			4: begin
			end

		endcase
		
		//Stop proof after this much depth
		if(delay_count >= 18)
			state <= 4;
		
	end
	
endmodule
