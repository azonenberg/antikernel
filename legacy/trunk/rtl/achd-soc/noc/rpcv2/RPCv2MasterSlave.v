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
	@brief Master/slave splitter for RPC network
	
	Adds 1 cycle of latency each way, but hides lots of complexity from the module developer.
 */
module RPCv2MasterSlave(
	clk,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	
	//Master interface
	rpc_master_tx_en, rpc_master_tx_dst_addr, rpc_master_tx_callnum, rpc_master_tx_type,
	rpc_master_tx_d0, rpc_master_tx_d1, rpc_master_tx_d2, rpc_master_tx_done,
	
	rpc_master_rx_en, rpc_master_rx_src_addr, rpc_master_rx_dst_addr, rpc_master_rx_callnum, rpc_master_rx_type,
	rpc_master_rx_d0, rpc_master_rx_d1, rpc_master_rx_d2, rpc_master_rx_done, rpc_master_inbox_full,
	
	//Slave interface
	rpc_slave_tx_en, rpc_slave_tx_dst_addr, rpc_slave_tx_callnum, rpc_slave_tx_type,
	rpc_slave_tx_d0, rpc_slave_tx_d1, rpc_slave_tx_d2, rpc_slave_tx_done,
	
	rpc_slave_rx_en, rpc_slave_rx_src_addr, rpc_slave_rx_dst_addr, rpc_slave_rx_callnum,
	rpc_slave_rx_d0, rpc_slave_rx_d1, rpc_slave_rx_d2, rpc_slave_rx_done, rpc_slave_inbox_full
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
		
	//Clocks
	input wire			clk;
	
	//NoC interface
	output wire			rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0]	rpc_rx_ack;
	
	//Master interface
	input wire			rpc_master_tx_en;
	input wire[15:0]	rpc_master_tx_dst_addr;
	input wire[7:0]		rpc_master_tx_callnum;
	input wire[2:0]		rpc_master_tx_type;
	input wire[20:0]	rpc_master_tx_d0;
	input wire[31:0]	rpc_master_tx_d1;
	input wire[31:0]	rpc_master_tx_d2;
	output reg			rpc_master_tx_done		= 0;
	
	output reg			rpc_master_rx_en		= 0;
	output reg[15:0]	rpc_master_rx_src_addr	= 0;
	output reg[15:0]	rpc_master_rx_dst_addr	= 0;
	output reg[7:0]		rpc_master_rx_callnum	= 0;
	output reg[2:0]		rpc_master_rx_type		= 0;
	output reg[20:0]	rpc_master_rx_d0		= 0;
	output reg[31:0]	rpc_master_rx_d1		= 0;
	output reg[31:0]	rpc_master_rx_d2		= 0;
	input wire			rpc_master_rx_done;
	output reg			rpc_master_inbox_full	= 0;
	
	//Slave interface
	input wire			rpc_slave_tx_en;
	input wire[15:0]	rpc_slave_tx_dst_addr;
	input wire[7:0]		rpc_slave_tx_callnum;
	input wire[2:0]		rpc_slave_tx_type;
	input wire[20:0]	rpc_slave_tx_d0;
	input wire[31:0]	rpc_slave_tx_d1;
	input wire[31:0]	rpc_slave_tx_d2;
	output reg			rpc_slave_tx_done		= 0;
	
	output reg			rpc_slave_rx_en			= 0;
	output reg[15:0]	rpc_slave_rx_src_addr	= 0;
	output reg[15:0]	rpc_slave_rx_dst_addr	= 0;
	output reg[7:0]		rpc_slave_rx_callnum	= 0;
	//no rx type since its always RPC_TYPE_CALL
	output reg[20:0]	rpc_slave_rx_d0			= 0;
	output reg[31:0]	rpc_slave_rx_d1			= 0;
	output reg[31:0]	rpc_slave_rx_d2			= 0;
	input wire			rpc_slave_rx_done;
	output reg			rpc_slave_inbox_full	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The transceiver
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter LEAF_ADDR				= 16'h0000;

	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;
	
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	reg			rpc_fab_rx_done		= 0;
	wire		rpc_fab_inbox_full;
	
	RPCv2Transceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(LEAF_ADDR)
	) txvr (
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(16'h0000),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		
		.rpc_fab_rx_en(),
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
	// Extra flags for retry port since its not a top level port
	
	reg			rpc_retry_tx_en			= 0;
	reg			rpc_retry_tx_done		= 0;
	reg[15:0]	rpc_retry_tx_dst_addr	= 0;
	reg[7:0]	rpc_retry_tx_callnum	= 0;
	reg[20:0]	rpc_retry_tx_d0			= 0;
	reg[31:0]	rpc_retry_tx_d1			= 0;
	reg[31:0]	rpc_retry_tx_d2			= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Inbound message processing

	localparam	INBOX_STATE_IDLE		= 0;
	localparam	INBOX_STATE_RETRY		= 1;
	reg			inbox_state				= INBOX_STATE_IDLE;
	
	//If this is set, the master port will silently drop all inbound return values
	//that did not come from rpc_master_tx_dst_addr. Interrupts are always allowed from anywhere.
	parameter	DROP_MISMATCH_CALLS		= 0;
		
	always @(posedge clk) begin
	
		rpc_slave_rx_en				<= 0;
		rpc_master_rx_en			<= 0;
		rpc_retry_tx_en				<= 0;
		rpc_fab_rx_done				<= 0;
		
		//Clear inbox-full flags as needed
		if(rpc_master_rx_done)
			rpc_master_inbox_full	<= 0;
		if(rpc_slave_rx_done)
			rpc_slave_inbox_full	<= 0;
		
		case(inbox_state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// IDLE - wait for an incoming message
			
			INBOX_STATE_IDLE: begin
	
				if(rpc_fab_inbox_full && !rpc_fab_rx_done) begin
				
					//Inbound call to the slave port
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						
						//If we have room in the inbox, put it there
						if(!rpc_slave_inbox_full) begin
						
							rpc_slave_rx_en			<= 1;
							rpc_slave_inbox_full	<= 1;
							rpc_slave_rx_callnum	<= rpc_fab_rx_callnum;
							rpc_slave_rx_src_addr	<= rpc_fab_rx_src_addr;
							rpc_slave_rx_dst_addr	<= rpc_fab_rx_dst_addr;
							rpc_slave_rx_d0			<= rpc_fab_rx_d0;
							rpc_slave_rx_d1			<= rpc_fab_rx_d1;
							rpc_slave_rx_d2			<= rpc_fab_rx_d2;
						
						end
						
						//Inbox is full, reject with a retry
						else begin
						
							rpc_retry_tx_en			<= 1;
							rpc_retry_tx_callnum	<= rpc_fab_rx_callnum;
							rpc_retry_tx_dst_addr	<= rpc_fab_rx_src_addr;
							rpc_retry_tx_d0			<= rpc_fab_rx_d0;
							rpc_retry_tx_d1			<= rpc_fab_rx_d1;
							rpc_retry_tx_d2			<= rpc_fab_rx_d2;
							
							inbox_state				<= INBOX_STATE_RETRY;
						
						end
						
						//In either case, we're done handling the message
						rpc_fab_rx_done				<= 1;
					
					end	//end RPC_TYPE_CALL
						
					//Inbound return or interrupt to the master port
					else if(
							(rpc_fab_rx_type == RPC_TYPE_RETURN_SUCCESS) ||
							(rpc_fab_rx_type == RPC_TYPE_RETURN_FAIL) ||
							(rpc_fab_rx_type == RPC_TYPE_RETURN_RETRY) ||
							(rpc_fab_rx_type == RPC_TYPE_INTERRUPT)
						) begin
						
						//If we are dropping mismatched calls, and this is a mismatch, drop it regardless of inbox
						//Always allow interrupts, though
						if(DROP_MISMATCH_CALLS &&
							(rpc_fab_rx_src_addr != rpc_master_tx_dst_addr) &&
							(rpc_fab_rx_type != RPC_TYPE_INTERRUPT)) begin
							rpc_fab_rx_done			<= 1;
						end
						
						//If the master inbox has space, forward it
						else if(!rpc_master_inbox_full) begin
							rpc_master_rx_en		<= 1;
							rpc_master_inbox_full	<= 1;
							rpc_master_rx_type		<= rpc_fab_rx_type;
							rpc_master_rx_callnum	<= rpc_fab_rx_callnum;
							rpc_master_rx_src_addr	<= rpc_fab_rx_src_addr;
							rpc_master_rx_dst_addr	<= rpc_fab_rx_dst_addr;
							rpc_master_rx_d0		<= rpc_fab_rx_d0;
							rpc_master_rx_d1		<= rpc_fab_rx_d1;
							rpc_master_rx_d2		<= rpc_fab_rx_d2;
							
							//Done handling the message
							rpc_fab_rx_done			<= 1;
						end
						
						//If inbox is full, just block until there's room
						
					end
					
					//TODO: Handle network status messages
					//For now, drop them
					else begin
						rpc_fab_rx_done				<= 1;
					end
				
				end
				
			end	//end INBOX_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// RETRY - wait for a retry request to be sent
			
			INBOX_STATE_RETRY: begin
				if(rpc_retry_tx_done)
					inbox_state		<= INBOX_STATE_IDLE;
			end	//end INBOX_STATE_RETRY
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Outbound message sending
	
	//Saved transmit enable flags
	reg		slave_tx_en			= 0;
	reg		master_tx_en		= 0;
	reg		retry_tx_en			= 0;
	
	//Forwarded flags
	wire	slave_tx_en_fwd		= slave_tx_en | rpc_slave_tx_en;
	wire	master_tx_en_fwd	= master_tx_en | rpc_master_tx_en;
	wire	retry_tx_en_fwd		= retry_tx_en | rpc_retry_tx_en;
	
	//Internal state so we know who is sending
	localparam TX_SRC_NONE			= 2'h0;
	localparam TX_SRC_SLAVE			= 2'h1;
	localparam TX_SRC_MASTER		= 2'h2;
	localparam TX_SRC_RETRY			= 2'h3;
	reg			tx_busy				= 0;
	reg[1:0]	tx_src				= TX_SRC_NONE;
	
	always @(posedge clk) begin
		
		//Clear flags
		rpc_fab_tx_en		<= 0;
		rpc_master_tx_done	<= 0;
		rpc_slave_tx_done	<= 0;
		rpc_retry_tx_done	<= 0;
		
		//Save transmit enables
		if(rpc_slave_tx_en)
			slave_tx_en		<= 1;
		if(rpc_master_tx_en)
			master_tx_en	<= 1;
		if(rpc_retry_tx_en)
			retry_tx_en		<= 1;
		
		//If we just finished sending, notify the relevant entity
		if(rpc_fab_tx_done) begin
			tx_busy			<= 0;
			case(tx_src)
				TX_SRC_SLAVE:	rpc_slave_tx_done	<= 1;
				TX_SRC_MASTER:	rpc_master_tx_done	<= 1;
				TX_SRC_RETRY:	rpc_retry_tx_done	<= 1;
			endcase
		end
			
		//If we have a transmit enable and are not busy, send the message
		else if(!tx_busy) begin
		
			//Retry has highest priority
			if(retry_tx_en_fwd) begin
				slave_tx_en			<= 0;
				
				tx_src				<= TX_SRC_RETRY;
				tx_busy				<= 1;
			
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= rpc_retry_tx_dst_addr;
				rpc_fab_tx_callnum	<= rpc_retry_tx_callnum;
				rpc_fab_tx_type		<= RPC_TYPE_RETURN_RETRY;		//always the same
				rpc_fab_tx_d0		<= rpc_retry_tx_d0;
				rpc_fab_tx_d1		<= rpc_retry_tx_d1;
				rpc_fab_tx_d2		<= rpc_retry_tx_d2;
			end

			//then slave
			else if(slave_tx_en_fwd) begin
				slave_tx_en			<= 0;
				
				tx_src				<= TX_SRC_SLAVE;
				tx_busy				<= 1;
			
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= rpc_slave_tx_dst_addr;
				rpc_fab_tx_callnum	<= rpc_slave_tx_callnum;
				rpc_fab_tx_type		<= rpc_slave_tx_type;
				rpc_fab_tx_d0		<= rpc_slave_tx_d0;
				rpc_fab_tx_d1		<= rpc_slave_tx_d1;
				rpc_fab_tx_d2		<= rpc_slave_tx_d2;
			end
			
			//and master is lowest
			else if(master_tx_en_fwd) begin
				master_tx_en		<= 0;
				
				tx_src				<= TX_SRC_MASTER;
				tx_busy				<= 1;
			
				rpc_fab_tx_en		<= 1;
				rpc_fab_tx_dst_addr	<= rpc_master_tx_dst_addr;
				rpc_fab_tx_callnum	<= rpc_master_tx_callnum;
				rpc_fab_tx_type		<= rpc_master_tx_type;
				rpc_fab_tx_d0		<= rpc_master_tx_d0;
				rpc_fab_tx_d1		<= rpc_master_tx_d1;
				rpc_fab_tx_d2		<= rpc_master_tx_d2;
			end
		
		end
		
	end
	
endmodule
