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
	@brief NoC packet sniffer for a single link.
	
	Contains four independent capture cores and can capture data on both tx and rx of RPC and DMA simultaneously.
	
	@module
	@opcodefile		NocPacketSniffer_opcodes.constants
	
	@rpcfn			SNIFF_START
	@brief			Starts the sniffer.
	
	@rpcfn_ok		SNIFF_START
	@brief			The sniffer is running. Captured data will be streamed to the caller via DMA write request packets.
	
	@rpcfn_fail		SNIFF_START
	@brief			The sniffer could not be started because another capture is in progress.
	
	@rpcfn			SNIFF_STOP
	@brief			Stops the sniffer.
	
	@rpcfn_ok		SNIFF_STOP
	@brief			Capture stopped.
	
	DMA target address map
		0x0000_0000		RPC rx buffer
		0x0000_0800		RPC tx buffer
		0x0000_1000		DMA rx buffer
		0x0000_1800		DMA tx buffer
 */
module NocPacketSniffer(
	clk,
	
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	sniff_rpc_tx_en, sniff_rpc_tx_data, sniff_rpc_tx_ack, sniff_rpc_rx_en, sniff_rpc_rx_data, sniff_rpc_rx_ack,
	sniff_dma_tx_en, sniff_dma_tx_data, sniff_dma_tx_ack, sniff_dma_rx_en, sniff_dma_rx_data, sniff_dma_rx_ack
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Sampling clock
	input wire clk;
	
	//RPC control interface
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;
	
	//DMA data interface
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	//RPC capture interface
	input wire sniff_rpc_tx_en;
	input wire[31:0] sniff_rpc_tx_data;
	input wire[1:0] sniff_rpc_tx_ack;
	input wire sniff_rpc_rx_en;
	input wire[31:0] sniff_rpc_rx_data;
	input wire[1:0] sniff_rpc_rx_ack;
	
	//DMA capture interface
	input wire sniff_dma_tx_en;
	input wire[31:0] sniff_dma_tx_data;
	input wire sniff_dma_tx_ack;
	input wire sniff_dma_rx_en;
	input wire[31:0] sniff_dma_rx_data;
	input wire sniff_dma_rx_ack;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "DMARouter_constants.v"
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR = 16'h0000;
	
	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;
	
	wire		rpc_fab_rx_en;
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
		.LEAF_ADDR(NOC_ADDR)
	) txvr(
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
	
	//DMA transmit signals
	wire		dtx_busy;
	reg[15:0]	dtx_dst_addr = 0;
	reg[1:0]	dtx_op = 0;
	reg[9:0]	dtx_len = 0;
	reg[31:0]	dtx_addr = 0;
	reg			dtx_en = 0;
	wire		dtx_rd;
	wire[9:0]	dtx_raddr;
	reg[31:0]	dtx_buf_out = 0;
	
	//DMA receive signals ignored, we don't have a use for incoming DMA
		
	//DMA transceiver
	DMATransceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(NOC_ADDR)
	) dma_txvr(
		.clk(clk),
		.dma_tx_en(dma_tx_en), .dma_tx_data(dma_tx_data), .dma_tx_ack(dma_tx_ack),
		.dma_rx_en(dma_rx_en), .dma_rx_data(dma_rx_data), .dma_rx_ack(dma_rx_ack),
		
		.tx_done(),
		.tx_busy(dtx_busy), .tx_src_addr(16'h0000), .tx_dst_addr(dtx_dst_addr), .tx_op(dtx_op), .tx_len(dtx_len),
		.tx_addr(dtx_addr), .tx_en(dtx_en), .tx_rd(dtx_rd), .tx_raddr(dtx_raddr), .tx_buf_out(dtx_buf_out),
		
		.rx_ready(1'b1), .rx_en(), .rx_src_addr(), .rx_dst_addr(),
		.rx_op(), .rx_addr(), .rx_len(),
		.rx_buf_rd(1'b0), .rx_buf_addr(9'h0), .rx_buf_data(), .rx_buf_rdclk(clk)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Capture cores
	
	wire[8:0]	capture_words_ready[3:0];
	wire[31:0]	capture_read_data[3:0];
	reg			capture_read_en[3:0];
	wire		capture_overflow_alert[3:0];
	
	//Clear out flags
	integer i;
	initial begin
		for(i=0; i<4; i=i+1)
			capture_read_en[i]	<= 0;
	end
	
	RPCPacketSnifferCore rpc_tx_sniffer(
		.clk(clk),
		
		.sniff_rpc_en(sniff_rpc_tx_en),
		.sniff_rpc_data(sniff_rpc_tx_data),
		.sniff_rpc_ack(sniff_rpc_tx_ack),
		
		.words_ready(capture_words_ready[0]),
		.read_en(capture_read_en[0]),
		.read_data(capture_read_data[0]),
		.overflow_alert(capture_overflow_alert[0])
		);
		
	RPCPacketSnifferCore rpc_rx_sniffer(
		.clk(clk),
		
		.sniff_rpc_en(sniff_rpc_rx_en),
		.sniff_rpc_data(sniff_rpc_rx_data),
		.sniff_rpc_ack(sniff_rpc_rx_ack),
		
		.words_ready(capture_words_ready[1]),
		.read_en(capture_read_en[1]),
		.read_data(capture_read_data[1]),
		.overflow_alert(capture_overflow_alert[1])
		);
	
	DMAPacketSnifferCore dma_tx_sniffer(
		.clk(clk),
		
		.sniff_dma_en(sniff_dma_tx_en),
		.sniff_dma_data(sniff_dma_tx_data),
		.sniff_dma_ack(sniff_dma_tx_ack),
		
		.words_ready(capture_words_ready[2]),
		.read_en(capture_read_en[2]),
		.read_data(capture_read_data[2]),
		.overflow_alert(capture_overflow_alert[2])
		);
		
	DMAPacketSnifferCore dma_rx_sniffer(
		.clk(clk),
		
		.sniff_dma_en(sniff_dma_rx_en),
		.sniff_dma_data(sniff_dma_rx_data),
		.sniff_dma_ack(sniff_dma_rx_ack),
		
		.words_ready(capture_words_ready[3]),
		.read_en(capture_read_en[3]),
		.read_data(capture_read_data[3]),
		.overflow_alert(capture_overflow_alert[3])
		);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sniffer-wide state data
	
	//The address of our host
	reg[15:0]	host_addr		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC state machine
		
	`include "NocPacketSniffer_opcodes_constants.v"

	localparam RPC_STATE_IDLE		= 0;
	localparam RPC_STATE_TXHOLD		= 1;
	
	reg[3:0] rpc_state				= RPC_STATE_IDLE;
	
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		
		case(rpc_state)
		
			RPC_STATE_IDLE: begin
			
				if(rpc_fab_inbox_full) begin
				
					//Done no matter what
					rpc_fab_rx_done	<= 1;
					
					//Prepare to respond
					rpc_fab_tx_d0		<= 0;
					rpc_fab_tx_d1		<= 0;
					rpc_fab_tx_d2		<= 0;
					rpc_fab_tx_dst_addr	<= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum	<= rpc_fab_rx_callnum;
					rpc_fab_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
					
					//Calls need a response, anything else gets dropped
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
					
						case(rpc_fab_rx_callnum)
						
							//Start capture if not started. If started, fail
							SNIFF_START: begin
								if(host_addr == 0)
									host_addr	<= rpc_fab_rx_src_addr;
								else
									rpc_fab_tx_type	<= RPC_TYPE_RETURN_FAIL;
							end	//end SNIFF_START
						
							//Stop capture
							SNIFF_STOP: begin
								host_addr	<= 0;
							end	//end SNIFF_STOP
						
							default: begin
								//unrecognized call, fail
								rpc_fab_tx_type	<= RPC_TYPE_RETURN_FAIL;
							end
						
						endcase
						
						//Always sending a response
						rpc_fab_tx_en	<= 1;
						rpc_state		<= RPC_STATE_TXHOLD;
					
					end
					
				end
			
			end	//end RPC_STATE_IDLE
			
			RPC_STATE_TXHOLD: begin
				if(rpc_fab_tx_done)
					rpc_state	<= RPC_STATE_IDLE;
			end	//end RPC_STATE_TXHOLD
		
		endcase
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Sniffer watcher / DMA state machine
	
	//Round robin pointer indicates which node we should try to send from first
	reg[1:0]	rr_pointer	= 0;
	
	//Time since last time we sent from it
	reg[31:0]	last_send[3:0];
	initial begin
		for(i=0; i<4; i=i+1)
			last_send[i]	<= 0;
	end
	
	//The selected sender for the current transmission
	reg[1:0]	current_packet_source		= 0;
	
	localparam	DMA_STATE_IDLE	= 0;
	localparam	DMA_STATE_SEND	= 1;
	localparam	DMA_STATE_HOLD	= 2;
	
	reg[3:0]	dma_state		= DMA_STATE_IDLE;
	
	always @(posedge clk) begin
			
		dtx_en	<= 0;
			
		//Increment the "last send" timers for every port if they're not empty.
		//If they're empty, the timer should hold at zero though
		for(i=0; i<4; i=i+1) begin
			if(capture_words_ready[i])
				last_send[i]	<= last_send[i] + 32'h1;
			else				
				last_send[i]	<= 0;
		end
		
		case(dma_state)
		
			//IDLE: Nothing going on
			DMA_STATE_IDLE: begin
			
				//Only send if we have somebody to send to!
				if(host_addr != 0) begin
			
					//If the round robin winner is stagnating, or more than half full, send it
					//512k clocks = 52 ms @ 10 MHz or 5 ms @ 100 MHz
					if( (last_send[rr_pointer] > 32'h7ffff) || (capture_words_ready[rr_pointer] > 255) ) begin
						current_packet_source	<= rr_pointer;
						dma_state				<= DMA_STATE_SEND;
					end
					
					//Is any buffer more than half full, or stagnating? Send it
					else begin
						for(i=0; i<4; i=i+1) begin
							if( (last_send[i] > 16383) || (capture_words_ready[i] > 255) ) begin
								current_packet_source	<= i[1:0];
								dma_state				<= DMA_STATE_SEND;
							end
						end
					end

				end
			
			end	//end DMA_STATE_IDLE
			
			//Start a new transmission
			DMA_STATE_SEND: begin
			
				//always send however much data is ready
				dtx_en			<= 1;
				dtx_op			<= DMA_OP_WRITE_REQUEST;
				dtx_dst_addr	<= host_addr;
				dtx_len			<= capture_words_ready[current_packet_source];
				
				//address is used to indicate which type of data this is
				case(current_packet_source)
					0: dtx_addr	<= 32'h00000000;
					1: dtx_addr	<= 32'h00000800;
					2: dtx_addr	<= 32'h00001000;
					3: dtx_addr	<= 32'h00001800;
				endcase
				
				//Bump the round-robin pointer so another port has priority now
				rr_pointer		<= rr_pointer + 2'h1;
				
				//Wait until it's done
				dma_state		<= DMA_STATE_HOLD;
				
			end	//end DMA_STATE_SEND
			
			//Wait for the current transmission to finish
			DMA_STATE_HOLD: begin
				if(!dtx_en && !dtx_busy)
					dma_state				<= DMA_STATE_IDLE;
			end	//end DMA_STATE_HOLD
		
		endcase
				
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Muxes for DMA transmits
		
	always @(*) begin
	
		for(i=0; i<4; i=i+1)
			capture_read_en[i]	<= 0;
		
		capture_read_en[current_packet_source]	<= dtx_rd;
		dtx_buf_out								<= capture_read_data[current_packet_source];
	
	end
	
    
endmodule
