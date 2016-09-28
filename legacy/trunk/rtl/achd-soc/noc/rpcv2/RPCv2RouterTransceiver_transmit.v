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

module RPCv2RouterTransceiver_transmit(
	
	//System-synchronous clock
	clk,
	
	//Network interface, outbound side
	rpc_tx_en, rpc_tx_data, rpc_tx_ack,
		
	//Fabric interface, outbound side
	rpc_fab_tx_en,
	rpc_fab_tx_rd_en, rpc_fab_tx_raddr, rpc_fab_tx_rdata,
	rpc_fab_tx_done
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	`include "RPCv2Router_ack_constants.v"
	
	//System-synchronous clock
	input wire clk;
	
	//No init values on combinatorial regs because Yosys has issues with that
	
	//Network interface, outbound side
	output reg       rpc_tx_en;
	output reg[31:0] rpc_tx_data;
	input wire[1:0]  rpc_tx_ack;
	
	//Fabric interface, outbound side
	input wire     	 rpc_fab_tx_en;
	output reg	 	 rpc_fab_tx_rd_en;
	output reg[1:0]	 rpc_fab_tx_raddr		= 0;
	input wire[31:0] rpc_fab_tx_rdata;
	output reg       rpc_fab_tx_done		= 0;
	
	parameter LEAF_PORT = 0;
	parameter LEAF_ADDR = 16'h0;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Actual state logic
	
	localparam TX_STATE_IDLE			= 0;
	localparam TX_STATE_FETCH			= 1;
	localparam TX_STATE_WAIT			= 2;
	
	always @(*) begin
		
		//Don't transmit if not fetching
		rpc_tx_en <= 0;
		rpc_fab_tx_rd_en <= 0;
		
		if( (tx_state == TX_STATE_IDLE) || ((tx_state == TX_STATE_FETCH) && rpc_fab_tx_raddr == 0) )
			rpc_tx_data <= 0;
		else
			rpc_tx_data <= rpc_fab_tx_rdata;
		
		if(tx_state == TX_STATE_FETCH) begin

			rpc_fab_tx_rd_en <= 1;

			//Start transmit as soon as we have the data
			if(rpc_fab_tx_raddr == 1) begin

				rpc_tx_en <= 1;
				
				//If leaf port, don't trust incoming source address
				if(LEAF_PORT)
					rpc_tx_data <= {LEAF_ADDR, rpc_fab_tx_rdata[15:0]};
			end
			
		end
		
	end
	
	reg tx_got_ack = 0;
	reg tx_retransmit_needed = 0;
	
	reg[1:0] tx_state = TX_STATE_IDLE;
	always @(posedge clk) begin
		
		rpc_fab_tx_done <= 0;
		
		//When an ACK comes in, process it
		//BUGFIX: Do not set tx_got_ack or tx_retransmit_needed if we're not sending a packet
		if( (rpc_tx_ack != RPC_ACK_IDLE) && (tx_state != TX_STATE_IDLE) && !tx_got_ack) begin
			tx_got_ack <= 1;
			case(rpc_tx_ack)
				RPC_ACK_ACK: tx_retransmit_needed <= 0;		//Positive ACK - we're done
				RPC_ACK_NAK: tx_retransmit_needed <= 1;		//NAK - need to send again
				default: 	tx_retransmit_needed <= 1;		//Invalid value? Treat it as a NAK
			endcase
		end
		
		//Read the next address every time a read is requested
		if(rpc_fab_tx_rd_en)
			rpc_fab_tx_raddr <= rpc_fab_tx_raddr + 2'h1;
		
		//Main state machine
		case(tx_state)
			
			//Idle - wait for a send request (or a retransmit flag) and read routing header
			TX_STATE_IDLE: begin
			
				//Read pointer remains zero
				
				tx_got_ack <= 0;
				tx_retransmit_needed <= 0;
			
				if(rpc_fab_tx_en || tx_retransmit_needed)
					tx_state <= TX_STATE_FETCH;
			end
			
			//Fetching the packet
			TX_STATE_FETCH: begin
				if(rpc_fab_tx_raddr == 3)
					tx_state <= TX_STATE_WAIT;
			end

			//Wait for the ACK
			TX_STATE_WAIT: begin
				
				//Did we get an ACK? Go back to the idle state. Retransmits happen there, if needed.
				//If we do NOT need to retransmit, strobe the DONE flag
				if(tx_got_ack) begin
					tx_state <= TX_STATE_IDLE;
					if(!tx_retransmit_needed)
						rpc_fab_tx_done <= 1;
				end

			end

		endcase
		
	end
	
endmodule
