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
	@brief Main state machine logic for name server
 */
module NOCNameServer_control(
	clk,
	rd_en, rd_ptr, wr_en, wr_ptr,
	mutex_owned, mutex_granted, mutex_lock_en, mutex_unlock_en,
	host_out_ff, addr_out_ff,
	target_host, target_addr,
	host_hit, addr_hit,
	hmac_mem_wr, hmac_mem_addr, hmac_mem_din, hmac_mem_dout,
	hmac_start_en, hmac_data_en, hmac_finish_en, hmac_din, hmac_done, hmac_dout_valid, hmac_dout,
	rpc_fab_tx_en, rpc_fab_tx_callnum, rpc_fab_tx_type,
		rpc_fab_tx_d0, rpc_fab_tx_d1, rpc_fab_tx_d2, rpc_fab_tx_done,
	rpc_fab_rx_en, rpc_fab_rx_src_addr, rpc_fab_rx_dst_addr, rpc_fab_rx_callnum, rpc_fab_rx_type,
		rpc_fab_rx_d0, rpc_fab_rx_d1, rpc_fab_rx_d2, rpc_fab_rx_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	input wire	 		clk;
	
	//Size of the memory (always 256 in normal use
	`include "../../util/clog2.vh"
	parameter			DEPTH		= 256;
	localparam			ADDR_BITS = clog2(DEPTH);

	output reg						rd_en			= 0;
	output reg[ADDR_BITS-1:0]		rd_ptr			= 0;
	output reg 						wr_en			= 0;
	output reg[ADDR_BITS-1:0]		wr_ptr			= 0;

	input wire			mutex_owned;
	input wire			mutex_granted;
	output reg			mutex_lock_en	= 0;
	output reg			mutex_unlock_en	= 0;

	input wire[63:0]	host_out_ff;
	input wire[15:0]	addr_out_ff;
	
	output reg[63:0]	target_host		= 0;
	output reg[15:0]	target_addr		= 0;
	
	input wire			host_hit;
	input wire			addr_hit;

	output reg			hmac_mem_wr		= 0;
	output reg[3:0]		hmac_mem_addr	= 0;
	output reg[31:0]	hmac_mem_din	= 0;
	input wire[31:0]	hmac_mem_dout;
	
	output reg			hmac_start_en	= 0;
	output reg			hmac_data_en	= 0;
	output reg			hmac_finish_en	= 0;
	output reg[31:0]	hmac_din		= 0;
	input wire			hmac_done;
	input wire			hmac_dout_valid;
	input wire[31:0]	hmac_dout;
	
	output reg			rpc_fab_tx_en		= 0;
	output reg[7:0]		rpc_fab_tx_callnum	= 0;
	output reg[2:0]		rpc_fab_tx_type		= 0;
	output reg[20:0]	rpc_fab_tx_d0		= 0;
	output reg[31:0]	rpc_fab_tx_d1		= 0;
	output reg[31:0]	rpc_fab_tx_d2		= 0;
	input wire			rpc_fab_tx_done;
	
	input wire			rpc_fab_rx_en;
	input wire[15:0]	rpc_fab_rx_src_addr;
	input wire[15:0]	rpc_fab_rx_dst_addr;
	input wire[7:0]		rpc_fab_rx_callnum;
	input wire[2:0]		rpc_fab_rx_type;
	input wire[20:0]	rpc_fab_rx_d0;
	input wire[31:0]	rpc_fab_rx_d1;
	input wire[31:0]	rpc_fab_rx_d2;
	output reg			rpc_fab_rx_done = 0;

	parameter 			READ_ONLY		= 0;
	
	//DEBUG: Make formal proofs run faster
	parameter			MEM_ADDR_MAX	= 8'hff;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pipeline stuff
	
	reg						rd_en_ff		= 0;
	reg[ADDR_BITS-1:0]		rd_ptr_ff		= 0;
	
	reg						rd_en_ff2		= 0;
	reg[ADDR_BITS-1:0]		rd_ptr_ff2		= 0;
	
	//Push pointers down the pipeline
	always @(posedge clk) begin
		rd_en_ff		<= rd_en;
		rd_en_ff2		<= rd_en;
		
		rd_ptr_ff		<= rd_ptr;
		rd_ptr_ff2		<= rd_ptr_ff;
		
		if(rd_en)
			rd_ptr_ff	<= rd_ptr;
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machines
	
	`include "NOCNameServer_constants.v"			//Pull in autogenerated constant table
	`include "NOCNameServer_failcodes_constants.v"
	`include "RPCv2Router_type_constants.v"
	`include "RPCv2Router_ack_constants.v"
	
	localparam STATE_IDLE		= 4'h0;
	localparam STATE_QUERY		= 4'h1;
	localparam STATE_TX_WAIT	= 4'h2;
	localparam STATE_DISPATCH	= 4'h3;
	localparam STATE_LIST		= 4'h4;
	localparam STATE_HWRITE		= 4'h5;
	localparam STATE_HMAC		= 4'h6;
	localparam STATE_REGISTER	= 4'h7;
	
	reg			hmac_fail			= 0;
	
	reg[3:0]	state				= STATE_IDLE;
	reg			query_is_forward	= 0;
	
	always @(posedge clk) begin
		
		rpc_fab_tx_en	<= 0;
		rpc_fab_rx_done <= 0;
		
		rd_en			<= 0;
		wr_en			<= 0;
			
		hmac_mem_wr		<= 0;
		hmac_mem_din	<= 0;
		
		if(hmac_mem_wr || hmac_dout_valid || hmac_done)
			hmac_mem_addr	<= hmac_mem_addr + 4'h1;
		
		hmac_start_en	<= 0;
		hmac_data_en	<= 0;
		hmac_finish_en	<= 0;
		hmac_din		<= 0;
		
		mutex_lock_en	<= 0;
		mutex_unlock_en	<= 0;
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Shared control flow
			//Nothing going on, wait for incoming request
			STATE_IDLE: begin
			
				//Wipe transmit arguments to zero
				rpc_fab_tx_d0	<= 0;
				rpc_fab_tx_d1	<= 0;
				rpc_fab_tx_d2	<= 0;
				
				//Clear write pointer
				wr_ptr			<= 0;
			
				//Update call number as soon as a packet comes in.
				//High part of opcode is ignored, no valid opcode is > 7.
				rpc_fab_tx_callnum[7:3] <= 0;
				rpc_fab_tx_callnum[2:0] <= rpc_fab_rx_callnum[2:0];
				
				//Prepare to read in case it's a NAMESERVER_LIST call
				rd_ptr					<= rpc_fab_rx_d0[ADDR_BITS-1:0];
				
				//Preload transmit type with success, change to fail if things go bad
				rpc_fab_tx_type			<= RPC_TYPE_RETURN_SUCCESS;
			
				//Write to search fields no matter what we're looking for.
				target_host <= {rpc_fab_rx_d1, rpc_fab_rx_d2};
				target_addr <= rpc_fab_rx_d0[15:0];
			
				//Incoming packet!
				if(rpc_fab_rx_en) begin
				
					//Function call? Dispatch it.
					//Do a read right away in case it's a NAMESERVER_LIST call.
					//If we're trying to lock the mutex, do that now
					if(rpc_fab_rx_type == RPC_TYPE_CALL) begin
						state		<= STATE_DISPATCH;
						rd_en		<= 1;
						
						if(rpc_fab_rx_callnum[2:0] == NAMESERVER_LOCK)
							mutex_lock_en	<= 1;
					end
					
					//Drop  all other packets
					else
						rpc_fab_rx_done	<= 1;

				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			//Dispatch the RPC call
			STATE_DISPATCH: begin
			
				//Write to search fields no matter what we're looking for.
				rd_en				<= 1;
				query_is_forward	<= 0;
				hmac_mem_din		<= rpc_fab_rx_d1;
			
				case(rpc_fab_rx_callnum[2:0])	//ignore high part of opcode
					
					//Send immediately
					NAMESERVER_LIST: begin
						state			<= STATE_LIST;
					end	//end NAMESERVER_LIST
					
					NAMESERVER_FQUERY: begin	
						rd_ptr				<= 0;
						query_is_forward	<= 1;
						state				<= STATE_QUERY;
					end	//end NAMESERVER_FQUERY
										
					NAMESERVER_RQUERY: begin
						rd_ptr			<= 0;
						state			<= STATE_QUERY;
					end	//end NAMESERVER_RQUERY
					
					NAMESERVER_LOCK: begin
						
						//Send something regardless
						rpc_fab_tx_en	<= 1;
						state			<= STATE_TX_WAIT;
						
						//Fail if we're read-only
						if(READ_ONLY)
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
						
						//If someone else holds the mutex, request a retry
						else if(!mutex_granted)
							rpc_fab_tx_type <= RPC_TYPE_RETURN_RETRY;
							
						//We got the lock. Save settings and return
						else
							hmac_mem_addr	<= 0;
						
					end
					
					NAMESERVER_HMAC: begin
						
						//Fail if we're read-only or don't hold the lock
						if(READ_ONLY || !mutex_owned) begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_en	<= 1;
							state			<= STATE_TX_WAIT;
						end
						
						//Fail if we already wrote the whole hash
						else if(hmac_mem_addr[3]) begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_en	<= 1;
							state			<= STATE_TX_WAIT;
						end
						
						//All good, push the first block of the hash into the buffer
						//and reset the timeout on the mutex
						else begin
							mutex_lock_en	<= 1;
							hmac_mem_wr		<= 1;
							state			<= STATE_HWRITE;
						end
						
					end
					
					//Check the signature
					NAMESERVER_REGISTER: begin
						
						hmac_mem_addr	<= 4'ha;
						hmac_fail		<= 0;
						
						//Fail if we're read-only or don't hold the lock
						if(READ_ONLY || !mutex_owned) begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_d0	<= REGISTER_E_NOLOCK;
							rpc_fab_tx_en	<= 1;
							state			<= STATE_TX_WAIT;
						end
						
						//Reset the hasher
						else begin
							rpc_fab_tx_d0	<= REGISTER_E_OK;
							hmac_start_en	<= 1;
							state			<= STATE_HMAC;
						end
						
					end
					
					default: begin
						//Unknown opcode, return failure
						rpc_fab_tx_en	<= 1;
						rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
						state			<= STATE_TX_WAIT;
					end
				endcase
			end	//end STATE_DISPATCH

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// NAMESERVER_LIST

			STATE_LIST: begin
			
				rpc_fab_tx_en	<= 1;
				state			<= STATE_TX_WAIT;

				rpc_fab_tx_d0 	<= addr_out_ff;
				rpc_fab_tx_d1 	<= host_out_ff[63:32];
				rpc_fab_tx_d2 	<= host_out_ff[31:0];
			
			end	//end STATE_LIST

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// NAMESERVER_HMAC

			STATE_HWRITE: begin
			
				//Write the second block of the hash
				hmac_mem_wr		<= 1;
				hmac_mem_din	<= rpc_fab_rx_d2;
			
				//Done
				rpc_fab_tx_en	<= 1;
				state			<= STATE_TX_WAIT;
			
			end	//end STATE_HWRITE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// NAMESERVER_REGISTER
			
			STATE_HMAC: begin
				
				//New HMAC word coming out? Check it
				if(hmac_dout_valid) begin
									
					//Report failures at the end to avoid timing attacks
					if(hmac_dout != hmac_mem_dout)
						hmac_fail		<= 1;
				
				end
				
				//Done with the previous hash attempt? Decide what to do
				if(hmac_done) begin
				
					//Feed in the message being verified
					if( (hmac_mem_addr >= 4'ha) && (hmac_mem_addr <= 4'hd) ) begin
						hmac_data_en	<= 1;
						case(hmac_mem_addr)
							4'ha: hmac_din	<= {rpc_fab_rx_src_addr, rpc_fab_rx_dst_addr};
							4'hb: hmac_din	<= {rpc_fab_rx_callnum, rpc_fab_rx_type, rpc_fab_rx_d0};
							4'hc: hmac_din	<= rpc_fab_rx_d1;
							4'hd: hmac_din	<= rpc_fab_rx_d2;
						endcase
					end
					
					//Done hashing? Finish the hash
					else if(hmac_mem_addr == 4'he) begin
						hmac_finish_en	<= 1;
						hmac_mem_addr	<= 0;
					end
					
					//Done with the hash
					else begin
					
						hmac_mem_addr	<= 0;
											
						//Auth denied
						if(hmac_fail) begin
							rpc_fab_tx_en		<= 1;
							rpc_fab_tx_d0		<= REGISTER_E_HMAC;
							rpc_fab_tx_type		<= RPC_TYPE_RETURN_FAIL;
							state				<= STATE_TX_WAIT;
						end
						
						//Good signature, do the insert
						else begin
							rd_en			<= 1;
							wr_ptr			<= 0;
							state			<= STATE_REGISTER;
						end

					end
				
				end
				
			end	//end STATE_HMAC
			
			//Scan the entire name table and look for duplicates and free space
			STATE_REGISTER: begin
				
				//Prepare to read the next list item
				rd_en	<= 1;
				rd_ptr	<= rd_ptr + 1'h1;
				
				if(rd_en_ff2) begin
				
					//If we find an empty spot, save the location so we can use it
					//Spot zero is always used by name server itself, so we use it as null
					if( (host_out_ff == 64'h0) && (wr_ptr == 0) )
						wr_ptr				<= rd_ptr_ff2;
			
					//If we match the host name, fail. We can't have one hostname pointing to two addresses
					if(host_hit) begin
						rpc_fab_tx_en		<= 1;
						rpc_fab_tx_d0		<= REGISTER_E_DUP;
						rpc_fab_tx_type		<= RPC_TYPE_RETURN_FAIL;
						state				<= STATE_TX_WAIT;
					end
					
					//Searched the whole list? Done.
					else if(rd_ptr_ff2 == (DEPTH-1)) begin

						//Unlock the mutex no matter what
						mutex_unlock_en		<= 1;
						
						//Send the return packet no matter what
						rpc_fab_tx_en		<= 1;
						state				<= STATE_TX_WAIT;

						//If we found an empty spot, use it
						if(wr_ptr != 0) begin
							wr_en				<= 1;
							rpc_fab_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
						end
						
						//Otherwise, give up
						else begin
							rpc_fab_tx_d0		<= REGISTER_E_NOSPACE;
							rpc_fab_tx_type		<= RPC_TYPE_RETURN_FAIL;
						end
						
					end
					
				end
				
			end	//end STATE_REGISTER

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// NAMESERVER_*QUERY
			
			STATE_QUERY: begin
	
				//Write to transmit data assuming it was a hit
				rpc_fab_tx_d0 <= addr_out_ff;
				rpc_fab_tx_d1 <= host_out_ff[63:32];
				rpc_fab_tx_d2 <= host_out_ff[31:0];
				
				//Prepare to read the next list item
				rd_en	<= 1;
				rd_ptr	<= rd_ptr + 1'h1;
	
				//Search iff the last read is finished
				if(rd_en_ff2) begin
					
					//Did we find it? Send it
					if(
						( !query_is_forward && addr_hit ) ||
						(  query_is_forward && host_hit )
					  ) begin
						rpc_fab_tx_en <= 1;
						state <= STATE_TX_WAIT;
					end
					
					//Searched the whole list? Give up
					else if(rd_ptr_ff2 == (DEPTH-1)) begin
						rpc_fab_tx_en <= 1;
						rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
						state <= STATE_TX_WAIT;
					end
				
				end		
				
			end	//end STATE_QUERY

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for transmission to finish and then set rx_done
			
			STATE_TX_WAIT: begin
				if(rpc_fab_tx_done) begin
					rpc_fab_rx_done <= 1;
					state <= STATE_IDLE;
				end
			end	//end STATE_TX_WAIT
			
		endcase
	end
	
endmodule

