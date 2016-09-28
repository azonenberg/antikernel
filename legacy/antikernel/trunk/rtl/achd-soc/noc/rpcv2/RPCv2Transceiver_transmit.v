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
	@brief Transceiver for RPC network, protocol version 2
	
	Transmit side module
 */
module RPCv2Transceiver_transmit(
	
	//System-synchronous clock
	clk,
	
	//Network interface, outbound side
	rpc_tx_en, rpc_tx_data, rpc_tx_ack,

	//Fabric interface, outbound side
	rpc_fab_tx_en,
	rpc_fab_tx_src_addr, rpc_fab_tx_dst_addr,
	rpc_fab_tx_callnum, rpc_fab_tx_type, rpc_fab_tx_d0,
	rpc_fab_tx_d1,
	rpc_fab_tx_d2,
	rpc_fab_tx_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	`include "RPCv2Router_ack_constants.v"
	
	//System-synchronous clock
	input wire clk;
	
	//Network interface, outbound side
	output reg       rpc_tx_en;
	output reg[31:0] rpc_tx_data;
	input wire[1:0]  rpc_tx_ack;
	
	//Fabric interface, outbound side
	input wire       rpc_fab_tx_en;
	input wire[15:0] rpc_fab_tx_src_addr;
	input wire[15:0] rpc_fab_tx_dst_addr;
	input wire[7:0]  rpc_fab_tx_callnum;
	input wire[2:0]  rpc_fab_tx_type;
	input wire[20:0] rpc_fab_tx_d0;
	input wire[31:0] rpc_fab_tx_d1;
	input wire[31:0] rpc_fab_tx_d2;
	output reg       rpc_fab_tx_done;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Actual transmit logic
	
	localparam TX_STATE_IDLE	= 0;
	localparam TX_STATE_D0		= 1;
	localparam TX_STATE_D1		= 2;
	localparam TX_STATE_D2		= 3;
	localparam TX_STATE_WAIT	= 4;
	
	reg tx_got_ack = 0;
	reg tx_retransmit_needed = 0;
	
	reg[2:0] tx_state = TX_STATE_IDLE;
	
	//Combinatorial transmit logic
	always @(*) begin
		rpc_tx_en		<= 0;
		rpc_tx_data		<= 0;
		rpc_fab_tx_done	<= 0;
		
		case(tx_state)
			
			//Idle and transmitting? Send first header
			//Don't allow tx_en the same cycle as tx_done
			TX_STATE_IDLE: begin
				if(rpc_fab_tx_en || tx_retransmit_needed) begin
					rpc_tx_en <= 1;
					rpc_tx_data <= {rpc_fab_tx_src_addr, rpc_fab_tx_dst_addr};
				end
			end
			
			//Send data words
			TX_STATE_D0:	rpc_tx_data <= {rpc_fab_tx_callnum, rpc_fab_tx_type, rpc_fab_tx_d0};
			TX_STATE_D1:	rpc_tx_data <= rpc_fab_tx_d1;
			TX_STATE_D2:	rpc_tx_data <= rpc_fab_tx_d2;
			
			//Wait for ACK and set DONE flag when done
			TX_STATE_WAIT: begin
				if(tx_got_ack && !tx_retransmit_needed)
					rpc_fab_tx_done <= 1;
			end
			
		endcase
		
	end
	
	//Sequential state logic
	always @(posedge clk) begin
		
		//When an ACK comes in, process it
		//BUGFIX: Do not set tx_got_ack or tx_retransmit_needed if we're not sending a packet
		if( (rpc_tx_ack != RPC_ACK_IDLE) && (tx_state != TX_STATE_IDLE) & !tx_got_ack ) begin
			tx_got_ack <= 1;
			case(rpc_tx_ack)
				RPC_ACK_ACK: tx_retransmit_needed <= 0;		//Positive ACK - we're done
				RPC_ACK_NAK: tx_retransmit_needed <= 1;		//NAK - need to send again
				default: 	tx_retransmit_needed <= 1;		//Invalid value? Treat it as a NAK
			endcase
		end
		
		case(tx_state)
		
			//Wait for send flag
			TX_STATE_IDLE: begin
				if(rpc_fab_tx_en || tx_retransmit_needed)
					tx_state <= TX_STATE_D0;
				
				tx_got_ack <= 0;
				tx_retransmit_needed <= 0;
			end
			
			//Send data
			TX_STATE_D0:	tx_state <= TX_STATE_D1;
			TX_STATE_D1:	tx_state <= TX_STATE_D2;
			TX_STATE_D2:	tx_state <= TX_STATE_WAIT;
			
			//Wait for ACK
			TX_STATE_WAIT: begin
				if(tx_got_ack)
					tx_state <= TX_STATE_IDLE;
			end
			
		endcase
		
	end
	
endmodule
