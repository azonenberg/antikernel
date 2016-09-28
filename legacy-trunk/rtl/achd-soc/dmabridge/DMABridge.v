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
	@brief Implementation of DMABridge
	
	@module
	@brief			Bridge between RAM-buffered and streaming DMA
	@opcodefile		DMABridge_opcodes.constants
	
	@rpcfn			BRIDGE_REGISTER_TARGET
	@brief			Registers the sender as the target for new DMA writes
	
	@rpcfn_ok		BRIDGE_REGISTER_TARGET
	@brief			Registration complete
	
	@rpcfn_fail		BRIDGE_REGISTER_TARGET
	@brief			Registration failed (maybe someone else is registered as the target already?)
	
	@rpcint			BRIDGE_PAGE_READY
	@brief			New page ready for processing
	@param			addr		{d0[15:0],d1[31:0]}:phyaddr			Physical address of page
	@param			len			d2[9:0]:dec							Length of message, in words
	@param			sender		d2[31:16]:nocaddr					NoC address of the packet's original sender
	
	@rpcfn			BRIDGE_SEND_PAGE
	@brief			Send data contained in a RAM page to address 0x00000000 of a target
	@param			addr		{d0[15:0],d1[31:0]}:phyaddr			Physical address of page
	@param			len			d2[9:0]:dec							Length of message, in words
	@param			dest		d2[31:16]:nocaddr					NoC address of the destination
	
	@rpcfn_ok		BRIDGE_SEND_PAGE
	@brief			Page sent
	
	@rpcfn_fail		BRIDGE_SEND_PAGE
	@brief			Page could not be sent (permissions error?)
 */
module DMABridge(
	clk,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//NoC interface
	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;
	
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "DMARouter_constants.v"
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR			= 16'h0000;

	reg			rpc_master_tx_en 		= 0;
	reg[15:0]	rpc_master_tx_dst_addr	= 0;
	reg[7:0]	rpc_master_tx_callnum	= 0;
	reg[2:0]	rpc_master_tx_type		= 0;
	reg[20:0]	rpc_master_tx_d0		= 0;
	reg[31:0]	rpc_master_tx_d1		= 0;
	reg[31:0]	rpc_master_tx_d2		= 0;
	wire		rpc_master_tx_done;
	
	wire		rpc_master_rx_en;
	wire[15:0]	rpc_master_rx_src_addr;
	wire[15:0]	rpc_master_rx_dst_addr;
	wire[7:0]	rpc_master_rx_callnum;
	wire[2:0]	rpc_master_rx_type;
	wire[20:0]	rpc_master_rx_d0;
	wire[31:0]	rpc_master_rx_d1;
	wire[31:0]	rpc_master_rx_d2;
	reg			rpc_master_rx_done		= 0;
	wire		rpc_master_inbox_full;
	
	reg			rpc_slave_tx_en 		= 0;
	reg[15:0]	rpc_slave_tx_dst_addr	= 0;
	reg[7:0]	rpc_slave_tx_callnum	= 0;
	reg[2:0]	rpc_slave_tx_type		= 0;
	reg[20:0]	rpc_slave_tx_d0			= 0;
	reg[31:0]	rpc_slave_tx_d1			= 0;
	reg[31:0]	rpc_slave_tx_d2			= 0;
	wire		rpc_slave_tx_done;
	
	wire		rpc_slave_rx_en;
	wire[15:0]	rpc_slave_rx_src_addr;
	wire[15:0]	rpc_slave_rx_dst_addr;
	wire[7:0]	rpc_slave_rx_callnum;
	//slave rx type is always RPC_TYPE_CALL
	wire[20:0]	rpc_slave_rx_d0;
	wire[31:0]	rpc_slave_rx_d1;
	wire[31:0]	rpc_slave_rx_d2;
	reg			rpc_slave_rx_done		= 0;
	wire		rpc_slave_inbox_full;
	
	RPCv2MasterSlave #(
		.LEAF_ADDR(NOC_ADDR),
		.DROP_MISMATCH_CALLS(1)
	) rpc_txvr (
		//NoC interface
		.clk(clk),
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		//Master interface
		.rpc_master_tx_en(rpc_master_tx_en),
		.rpc_master_tx_dst_addr(rpc_master_tx_dst_addr),
		.rpc_master_tx_callnum(rpc_master_tx_callnum),
		.rpc_master_tx_type(rpc_master_tx_type),
		.rpc_master_tx_d0(rpc_master_tx_d0),
		.rpc_master_tx_d1(rpc_master_tx_d1),
		.rpc_master_tx_d2(rpc_master_tx_d2),
		.rpc_master_tx_done(rpc_master_tx_done),
		
		.rpc_master_rx_en(rpc_master_rx_en),
		.rpc_master_rx_src_addr(rpc_master_rx_src_addr),
		.rpc_master_rx_dst_addr(rpc_master_rx_dst_addr),
		.rpc_master_rx_callnum(rpc_master_rx_callnum),
		.rpc_master_rx_type(rpc_master_rx_type),
		.rpc_master_rx_d0(rpc_master_rx_d0),
		.rpc_master_rx_d1(rpc_master_rx_d1),
		.rpc_master_rx_d2(rpc_master_rx_d2),
		.rpc_master_rx_done(rpc_master_rx_done),
		.rpc_master_inbox_full(rpc_master_inbox_full),
		
		//Slave interface
		.rpc_slave_tx_en(rpc_slave_tx_en),
		.rpc_slave_tx_dst_addr(rpc_slave_tx_dst_addr),
		.rpc_slave_tx_callnum(rpc_slave_tx_callnum),
		.rpc_slave_tx_type(rpc_slave_tx_type),
		.rpc_slave_tx_d0(rpc_slave_tx_d0),
		.rpc_slave_tx_d1(rpc_slave_tx_d1),
		.rpc_slave_tx_d2(rpc_slave_tx_d2),
		.rpc_slave_tx_done(rpc_slave_tx_done),
		
		.rpc_slave_rx_en(rpc_slave_rx_en),
		.rpc_slave_rx_src_addr(rpc_slave_rx_src_addr),
		.rpc_slave_rx_dst_addr(rpc_slave_rx_dst_addr),
		.rpc_slave_rx_callnum(rpc_slave_rx_callnum),
		.rpc_slave_rx_d0(rpc_slave_rx_d0),
		.rpc_slave_rx_d1(rpc_slave_rx_d1),
		.rpc_slave_rx_d2(rpc_slave_rx_d2),
		.rpc_slave_rx_done(rpc_slave_rx_done),
		.rpc_slave_inbox_full(rpc_slave_inbox_full)
	);
	
	//DMA transmit signals
	wire dtx_busy;
	reg[15:0] dtx_dst_addr		= 0;
	reg[1:0] dtx_op = 0;
	reg[9:0] dtx_len = 0;
	reg[31:0] dtx_addr = 0;
	reg dtx_en = 0;
	wire dtx_rd;
	wire[9:0] dtx_raddr;
	reg[31:0] dtx_buf_out		= 0;
	
	//DMA receive signals
	reg drx_ready				= 1;
	wire drx_en;
	wire[15:0] drx_src_addr;
	wire[15:0] drx_dst_addr;
	wire[1:0] drx_op;
	wire[31:0] drx_addr;
	wire[9:0] drx_len;	
	reg drx_buf_rd = 0;
	reg[9:0] drx_buf_addr		= 0;
	wire[31:0] drx_buf_data;
	
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
		
		.rx_ready(drx_ready), .rx_en(drx_en), .rx_src_addr(drx_src_addr), .rx_dst_addr(drx_dst_addr),
		.rx_op(drx_op), .rx_addr(drx_addr), .rx_len(drx_len),
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(clk)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RAM allocator (and chown logic)
	
	`include "NOCNameServer_constants.v"
	`include "NetworkedDDR2Controller_opcodes_constants.v"
	
	`include "DMABridge_allocator_states_constants.v"
	`include "DMABridge_opcodes_constants.v"
	
	reg[3:0]		alloc_state	= ALLOC_STATE_BOOT_0;
	
	//Routing address of important nodes
	reg[15:0]		ram_addr		= 0;
	reg				target_addr_ok	= 0;
	reg[15:0]		target_addr		= 0;
	
	//Physical address of the currently pending page of RAM
	//(to be written to first)
	reg				head_page_ok	= 0;
	reg[31:0]		head_page_addr	= 0;
	
	//Address of the next page of RAM (to be moved to head)
	reg				next_page_ok	= 0;
	reg[31:0]		next_page_addr	= 0;
	
	//Comms between the two main state machines
	reg				chown_sent		= 0;
	
	//Address of the DMA packet we want to send
	reg				dma_send_ready		= 0;
	reg				dma_send_done		= 0;
	reg[15:0]		dma_send_nocaddr	= 0;
	reg[31:0]		dma_send_phyaddr	= 0;
	reg[9:0]		dma_send_len		= 0;
	reg				dma_send_failed		= 0;
	reg				dma_send_retry		= 0;
	reg[15:0]		dma_send_dest		= 0;
	
	always @(posedge clk) begin
		
		rpc_master_rx_done		<= 0;
		rpc_master_tx_en		<= 0;
		chown_sent				<= 0;
		rpc_slave_tx_en			<= 0;
		dma_send_failed			<= 0;
		
		case(alloc_state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Boot stuff
			
			//Ask the name server where RAM is
			ALLOC_STATE_BOOT_0: begin
				rpc_master_tx_en 		<= 1;
				rpc_master_tx_dst_addr	<= NAMESERVER_ADDR;
				rpc_master_tx_type 		<= RPC_TYPE_CALL;
				rpc_master_tx_callnum	<= NAMESERVER_FQUERY;
				rpc_master_tx_d0 		<= 0;
				rpc_master_tx_d1 		<= {"ram", 8'h0};
				rpc_master_tx_d2		<= 16'h0;
				alloc_state				<= ALLOC_STATE_BOOT_1;
			end	//end ALLOC_STATE_BOOT_0
			
			//Wait for name server response
			ALLOC_STATE_BOOT_1: begin
				if(rpc_master_inbox_full) begin
					rpc_master_rx_done	<= 1;
					
					//always save the address, just ignore it if it's not what we want
					ram_addr		<= rpc_master_rx_d0[15:0];
				
					//advance states as needed
					case(rpc_master_rx_type)
						RPC_TYPE_RETURN_FAIL:		alloc_state			<= ALLOC_STATE_HANG;
						RPC_TYPE_RETURN_SUCCESS:	alloc_state 		<= ALLOC_STATE_MALLOC_0;
						RPC_TYPE_RETURN_RETRY:		rpc_master_tx_en	<= 1;
					endcase
					
				end			
			end	//end ALLOC_STATE_BOOT_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// The allocator
			
			//Send the allocate request
			ALLOC_STATE_MALLOC_0: begin
				rpc_master_tx_en 		<= 1;
				rpc_master_tx_dst_addr	<= ram_addr;
				rpc_master_tx_type 		<= RPC_TYPE_CALL;
				rpc_master_tx_callnum	<= RAM_ALLOCATE;
				rpc_master_tx_d0 		<= 0;
				rpc_master_tx_d1 		<= 0;
				rpc_master_tx_d2		<= 0;
				alloc_state				<= ALLOC_STATE_MALLOC_1;
			end	//end ALLOC_STATE_MALLOC_0
			
			//Wait for the allocation to return
			ALLOC_STATE_MALLOC_1: begin
			
				if(rpc_master_inbox_full && !rpc_master_rx_done) begin
					rpc_master_rx_done	<= 1;
				
					//Advance states as needed
					case(rpc_master_rx_type)
					
						//If we have no memory, just try allocating again
						RPC_TYPE_RETURN_FAIL:		rpc_master_tx_en	<= 1;
						RPC_TYPE_RETURN_RETRY:		rpc_master_tx_en	<= 1;
						
						//If successful, save it
						RPC_TYPE_RETURN_SUCCESS: begin
						
							//Save address to head if the head is empty
							//If the head is empty, we need to allocate a second page for the next
							if(!head_page_ok) begin
								head_page_addr		<= rpc_master_rx_d1;
								head_page_ok		<= 1;
								rpc_master_tx_en	<= 1;
							end
							
							//If we already have a head page, save it to the next and finish up
							else begin
								next_page_addr	<= rpc_master_rx_d1;
								next_page_ok	<= 1;
								alloc_state		<= ALLOC_STATE_IDLE;
							end
							
						end
						
					endcase
					
				end		
			
			end	//end ALLOC_STATE_MALLOC_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Chown after a successful write
			
			//Send the chown request
			ALLOC_STATE_CHOWN_0: begin
			
				rpc_master_tx_callnum		<= RAM_CHOWN;
				rpc_master_tx_type			<= RPC_TYPE_CALL;
				rpc_master_tx_dst_addr		<= ram_addr;
				rpc_master_tx_d0			<= 0;
				rpc_master_tx_d1			<= head_page_addr;
				rpc_master_tx_d2			<= target_addr;
				rpc_master_tx_en			<= 1;
				
				alloc_state					<= ALLOC_STATE_CHOWN_1;
			
			end	//end ALLOC_STATE_CHOWN_0
			
			//Wait for the chown to return
			ALLOC_STATE_CHOWN_1: begin
			
				if(rpc_master_inbox_full) begin
					rpc_master_rx_done	<= 1;
				
					//Advance states as needed
					case(rpc_master_rx_type)
						RPC_TYPE_RETURN_FAIL: 		alloc_state			<= ALLOC_STATE_HANG;
						RPC_TYPE_RETURN_RETRY:		rpc_master_tx_en	<= 1;
						RPC_TYPE_RETURN_SUCCESS: 	alloc_state			<= ALLOC_STATE_INT_0;
					endcase
					
				end		
			
			end	//end ALLOC_STATE_CHOWN_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Sending the interrupt
			
			ALLOC_STATE_INT_0: begin
				
				//Format and send the packet
				rpc_master_tx_dst_addr		<= target_addr;
				rpc_master_tx_type			<= RPC_TYPE_INTERRUPT;
				rpc_master_tx_callnum		<= BRIDGE_PAGE_READY;
				rpc_master_tx_d0			<= ram_addr;
				rpc_master_tx_d1			<= head_page_addr;
				rpc_master_tx_d2[9:0]		<= drx_len;
				rpc_master_tx_d2[31:16]		<= drx_src_addr;
				rpc_master_tx_d2[15:10]		<= 0;
				rpc_master_tx_en			<= 1;
				
				//Wait for the send
				alloc_state					<= ALLOC_STATE_INT_1;
				
				//Update status
				chown_sent					<= 1;
				head_page_addr				<= next_page_addr;
				head_page_ok				<= next_page_ok;
				next_page_addr				<= 0;
				next_page_ok				<= 0;
				
			end	//end ALLOC_STATE_INT_0
			
			ALLOC_STATE_INT_1: begin
				
				//When the send is done, allocate another page
				if(rpc_master_tx_done)
					alloc_state				<= ALLOC_STATE_MALLOC_0;
				
			end	//end ALLOC_STATE_INT_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Sending DMA to targets
			
			ALLOC_STATE_SEND_0: begin
			
				//If we get a failed interrupt, forward to the DMA state machine
				if(rpc_master_inbox_full) begin
				
					//No calls active, should never be anything but an interrupt from RAM
					if( (rpc_master_rx_type == RPC_TYPE_INTERRUPT) && (rpc_master_rx_src_addr == ram_addr) ) begin
					
						//For now, always assume it's a failed interrupt since no writes are active
						//Tell the DMA engine it failed
						dma_send_failed		<= 1;
						dma_send_ready		<= 0;
						
						//Send a "failed" RPC back to the caller
						rpc_slave_tx_type		<= RPC_TYPE_RETURN_FAIL;
						alloc_state				<= ALLOC_STATE_TX_HOLD;
						rpc_slave_tx_en			<= 1;
					
					end
					
					rpc_master_rx_done		<= 1;
				
				end
				
				//If we get pre-empted, kick it back with a retry
				else if(dma_send_retry) begin
					rpc_slave_tx_type		<= RPC_TYPE_RETURN_RETRY;
					alloc_state				<= ALLOC_STATE_TX_HOLD;
					rpc_slave_tx_en			<= 1;
				end
				
				//Done sending the message, free the RAM we sent from
				else if(dma_send_done) begin
					dma_send_ready			<= 0;
					rpc_master_tx_callnum	<= RAM_FREE;
					rpc_master_tx_d0		<= 0;
					rpc_master_tx_d1		<= dma_send_phyaddr;
					rpc_master_tx_d2		<= 0;
					rpc_master_tx_dst_addr	<= dma_send_nocaddr;
					rpc_master_tx_type		<= RPC_TYPE_CALL;
					rpc_master_tx_en		<= 1;
					
					alloc_state				<= ALLOC_STATE_SEND_1;
				end
			
			end	//end ALLOC_STATE_SEND_0
			
			ALLOC_STATE_SEND_1: begin
			
				//Wait for a successful return
				if(rpc_master_inbox_full) begin
				
					//Not expecting any interrupts so drop them
					
					//If it's from RAM, return with whatever return value we got from it
					if( (rpc_master_rx_src_addr == dma_send_nocaddr) && (rpc_master_rx_type != RPC_TYPE_INTERRUPT) ) begin
						rpc_slave_tx_type		<= rpc_master_rx_type;
						alloc_state				<= ALLOC_STATE_TX_HOLD;
						rpc_slave_tx_en			<= 1;
					end
					
					rpc_master_rx_done		<= 1;
				
				end

			end	//end ALLOC_STATE_SEND_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Error handling
			
			//HANG - wait for reset
			ALLOC_STATE_HANG: begin
			end	//end ALLOC_STATE_HANG
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Nothing to do, wait for events
		
			ALLOC_STATE_IDLE: begin
			
				//If we get a write-done interrupt, forward it to the DMA state machine
				if(rpc_master_inbox_full) begin
				
					//No calls active, should never be anything but an interrupt from RAM
					if( (rpc_master_rx_type == RPC_TYPE_INTERRUPT) && (rpc_master_rx_src_addr == ram_addr) ) begin
					
						//For now, always assume it's a write-done interrupt since RAM never sends anything else
						//(except write failed, which should be impossible as we only write to memory we own)
						alloc_state			<= ALLOC_STATE_CHOWN_0;
					
					end
					
					rpc_master_rx_done		<= 1;
				
				end
				
				//If we get an incoming function call, process it
				else if(rpc_slave_inbox_full) begin
				
					//Default slave to returning from the call
					rpc_slave_tx_dst_addr	<= rpc_slave_rx_src_addr;
					rpc_slave_tx_callnum	<= rpc_slave_rx_callnum;
					rpc_slave_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
					rpc_slave_tx_d0			<= rpc_slave_rx_d0;
					rpc_slave_tx_d1			<= rpc_slave_rx_d1;
					rpc_slave_tx_d2			<= rpc_slave_rx_d2;
					
					case(rpc_slave_rx_callnum)
						
						//Register the sender as the target for DMA operations
						BRIDGE_REGISTER_TARGET: begin
						
							//Somebody already came in? Reject the request with an error
							if(target_addr_ok)
								rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							
							//If not, save the stuff
							else begin
								target_addr_ok		<= 1;
								target_addr			<= rpc_slave_rx_src_addr;
							end
							
							alloc_state				<= ALLOC_STATE_TX_HOLD;
							rpc_slave_tx_en			<= 1;
						
						end	//end BRIDGE_REGISTER_TARGET
						
						//Send a new page
						BRIDGE_SEND_PAGE: begin
						
							//If the sender is not our target, drop the request with an error
							if(!target_addr_ok || (target_addr != rpc_slave_rx_src_addr) ) begin
								rpc_slave_tx_type		<= RPC_TYPE_RETURN_FAIL;
								alloc_state				<= ALLOC_STATE_TX_HOLD;
								rpc_slave_tx_en			<= 1;
							end
							
							//Packet is valid.
							//Forward it on to the target, and don't return until it's sent.
							//(If we don't block, we can drop packets if RPC can't keep up with DMA)
							else begin
								dma_send_ready			<= 1;
								dma_send_nocaddr		<= rpc_slave_rx_d0[15:0];
								dma_send_phyaddr		<= rpc_slave_rx_d1[31:0];
								dma_send_len			<= rpc_slave_rx_d2[9:0];
								dma_send_dest			<= rpc_slave_rx_d2[31:16];
								alloc_state				<= ALLOC_STATE_SEND_0;
							end
						
						end	//end BRIDGE_SEND_PAGE
					
						//Default: Reject with an error
						default: begin
							rpc_slave_tx_type		<= RPC_TYPE_RETURN_FAIL;
							alloc_state				<= ALLOC_STATE_TX_HOLD;
							rpc_slave_tx_en			<= 1;
						end
						
					endcase
					
					//Always done processing
					rpc_slave_rx_done		<= 1;
					
				end
			
			end	//end ALLOC_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for transmit to finish before we can send another message
			
			ALLOC_STATE_TX_HOLD: begin
				if(rpc_slave_tx_done)
					alloc_state	<= ALLOC_STATE_IDLE;
			end	//end ALLOC_STATE_TX_HOLD
			
		endcase
		
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Inbound DMA handling
	
	`include "DMABridge_inbound_states_constants.v"

	reg[3:0]	inbound_state		= INBOUND_STATE_BOOT;
	
	reg[9:0]	drx_buf_addr_ff		= 0;
	
	//Combinatorial forwarding of read addresses
	always @(*) begin
	
		drx_buf_addr	<= dtx_raddr;
		drx_buf_rd		<= dtx_rd;
		dtx_buf_out		<= drx_buf_data;
		
		//If reading off the end of the buffer, return zeroes instead
		if(drx_buf_addr_ff >= drx_len)
			dtx_buf_out	<= 32'h00000000;
		
	end

	always @(posedge clk) begin
		
		//Clear single-cycle flags
		dtx_en				<= 0;
		dma_send_retry		<= 0;
		dma_send_done		<= 0;
		
		//Keep track of inbox state
		if(drx_en)
			drx_ready		<= 0;
			
		drx_buf_addr_ff		<= drx_buf_addr;
		
		case(inbound_state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for us to be fully initialized
			
			INBOUND_STATE_BOOT: begin
			
				//Drop any packets we get during boot
				drx_ready	<= 1;
				
				if(target_addr_ok)
					inbound_state		<= INBOUND_STATE_IDLE;
			
			end	//end INBOUND_STATE_BOOT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for a new message to come in
			
			INBOUND_STATE_IDLE: begin
				
				//Inbound packets have priority
				if(!drx_ready) begin
					
					//If it's a write request, forward it to RAM
					if(drx_op == DMA_OP_WRITE_REQUEST) begin
						dtx_len			<= drx_len;
						dtx_dst_addr	<= ram_addr;
						dtx_op			<= DMA_OP_WRITE_REQUEST;
						inbound_state	<= INBOUND_STATE_WRITE_0;
						
						//If length mod 4 is not zero, round up to the next multiple of 4 words
						//so we write a full cache line
						if(drx_len[1:0])
							dtx_len		<= (drx_len | 10'h3) + 10'h1;
						
					end
					
					//If it's anything else, and we're idle, drop it
					else begin
						drx_ready		<= 1;
					end
						
				end
				
				//Deal with outbound stuff otherwise
				else if(dma_send_ready && !dma_send_done) begin
					
					//Start out by sending a read request to RAM to grab the page
					dtx_dst_addr		<= dma_send_nocaddr;
					dtx_addr			<= dma_send_phyaddr;
					dtx_len				<= dma_send_len;
					dtx_op				<= DMA_OP_READ_REQUEST;
					dtx_en				<= 1;
					inbound_state		<= INBOUND_STATE_READ_0;
					
					//If length mod 4 is not zero, round up to the next multiple of 4 words
					//so we read a full cache line
					if(dma_send_len[1:0])
						dtx_len			<= (dma_send_len | 10'h3) + 10'h1;
					
				end
			
			end	//end INBOUND_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// New inbound DMA send
			
			INBOUND_STATE_READ_0: begin
			
				//Wait for a DMA message from RAM
				if(!drx_ready) begin
				
					//If it's a write REQUEST, abort the current transaction and deal with it.
					if(drx_op == DMA_OP_WRITE_REQUEST) begin
						inbound_state	<= INBOUND_STATE_IDLE;
						dma_send_retry	<= 1;
					end
						
					//If it's read data, start sending
					else if(drx_op == DMA_OP_READ_DATA) begin
						
						dtx_dst_addr	<= dma_send_dest;
						dtx_addr		<= 0;
						dtx_len			<= dma_send_len;
						dtx_op			<= DMA_OP_WRITE_REQUEST;
						dtx_en			<= 1;
						
						inbound_state	<= INBOUND_STATE_READ_1;
						
					end
					
					//Read requests are meaningless, drop
					else
						drx_ready		<= 1;
				
				end
				
				//If the send failed, give up
				if(dma_send_failed)
					inbound_state		<= INBOUND_STATE_IDLE;
				
				
			end	//end INBOUND_STATE_READ_0
			
			INBOUND_STATE_READ_1: begin
			
				//Wait for DMA send to finish, then alert the RPC state machine we're done
				if(!dtx_busy && !dtx_en) begin
					drx_ready			<= 1;
					dma_send_done		<= 1;
					inbound_state		<= INBOUND_STATE_IDLE;
				end
			
			end	//end INBOUND_STATE_READ_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// New inbound DMA write
			
			INBOUND_STATE_WRITE_0: begin
			
				//If we have a free page of RAM, write to it
				if(head_page_ok) begin
					dtx_addr			<= head_page_addr;
					dtx_en				<= 1;
					inbound_state		<= INBOUND_STATE_WRITE_1;
				end
				
				//if no free memory, just wait until we have some
			
			end	//end INBOUND_STATE_WRITE_0
			
			INBOUND_STATE_WRITE_1: begin
			
				//Wait for the chown to be sent so we can reset
				if(chown_sent) begin
					drx_ready			<= 1;
					inbound_state		<= INBOUND_STATE_IDLE;
				end
			
			end	//end INBOUND_STATE_WRITE_1
			
		endcase
		
	end
	
endmodule
