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
	@brief Formal validation test harness for NOCNameServer_control
 */
module main(
	clk,
	rpc_rx_en, rpc_rx_data, rpc_tx_ack,
	host_hit, addr_hit,
	mutex_owned, mutex_granted,
	hmac_done, hmac_dout_valid, hmac_dout,
	host_out_ff, addr_out_ff
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	
	input wire[1:0]		rpc_tx_ack;
	
	input wire			host_hit;
	input wire			addr_hit;
	
	input wire			mutex_owned;
	input wire			mutex_granted;
	
	input wire			hmac_done;	
	input wire			hmac_dout_valid;
	input wire[31:0]	hmac_dout;
	
	input wire[63:0]	host_out_ff;
	input wire[15:0]	addr_out_ff;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transceiver to register incoming packets
	
	//We need this to enforce the invariant that opcodes etc won't change while a message is being processed
	
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	wire		rpc_fab_rx_done;
	
	RPCv2Transceiver_receive rx (
		.clk(clk),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full()
	);
	
	wire				rpc_fab_tx_en;
	wire[20:0]			rpc_fab_tx_d0;
	wire[31:0]			rpc_fab_tx_d1;
	wire[31:0]			rpc_fab_tx_d2;
	wire[7:0]			rpc_fab_tx_callnum;
	wire[2:0]			rpc_fab_tx_type;
	wire				rpc_fab_tx_done;
	
	RPCv2Transceiver_transmit tx (
		.clk(clk),
		
		.rpc_tx_en(),
		.rpc_tx_data(),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(16'h8000),
		.rpc_fab_tx_dst_addr(rpc_fab_rx_src_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	//Size of the memory (always 256 in normal use
	`include "../../rtl/achd-soc/util/clog2.vh"
	parameter			DEPTH		= 8;
	localparam			ADDR_BITS = clog2(DEPTH);
	
	wire		rd_en;
	wire[2:0]	rd_ptr;
	wire		wr_en;
	wire[2:0]	wr_ptr;
	
	wire		hmac_mem_wr;
	wire[3:0]	hmac_mem_addr;
	wire[31:0]	hmac_mem_din;
	wire[31:0]	hmac_mem_dout;
	
	wire		mutex_lock_en;
	wire		mutex_unlock_en;
	
	wire[15:0]	target_addr;
	wire[63:0]	target_host;
	
	wire		hmac_start_en;
	wire		hmac_data_en;
	wire		hmac_finish_en;
	wire[31:0]	hmac_din;
	
	NOCNameServer_control #(
		.READ_ONLY(1'b0),
		.DEPTH(DEPTH)
	) control(
		.clk(clk),
		
		.rd_en(rd_en),
		.rd_ptr(rd_ptr),
		.wr_en(wr_en),
		.wr_ptr(wr_ptr),
		
		.mutex_owned(mutex_owned),
		.mutex_granted(mutex_granted),
		.mutex_lock_en(mutex_lock_en),
		.mutex_unlock_en(mutex_unlock_en),
		
		.host_out_ff(host_out_ff),
		.addr_out_ff(addr_out_ff),
		
		.target_host(target_host),
		.target_addr(target_addr),
		
		.host_hit(host_hit),
		.addr_hit(addr_hit),
		
		.hmac_mem_wr(hmac_mem_wr),
		.hmac_mem_addr(hmac_mem_addr),
		.hmac_mem_din(hmac_mem_din),
		.hmac_mem_dout(hmac_mem_dout),
		
		.hmac_start_en(hmac_start_en),
		.hmac_data_en(hmac_data_en),
		.hmac_finish_en(hmac_finish_en),
		.hmac_din(hmac_din),
		.hmac_done(hmac_done),
		.hmac_dout_valid(hmac_dout_valid),
		.hmac_dout(hmac_dout),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
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
		.rpc_fab_rx_done(rpc_fab_rx_done)
		);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state verification logic
	
	`include "RPCv2Router_type_constants.v"
	`include "NOCNameServer_constants.v"			//Pull in autogenerated constant table
	
	reg			cmd_busy	= 0;
	reg			tx_busy		= 0;
	reg			tx_busy_ff	= 0;
	reg[7:0]	count		= 0;
	
	reg[2:0]	tx_type_expected	= RPC_TYPE_RETURN_SUCCESS;
	reg[7:0]	tx_callnum_expected	= 0;
	
	reg[20:0]	tx_d0_expected		= 0;
	reg[31:0]	tx_d1_expected		= 0;
	reg[31:0]	tx_d2_expected		= 0;
	
	reg[4:0]	hang_count	= 0;
	reg			hang		= 0;
	
	reg			mutex_granted_ff	= 0;
	
	reg[63:0]	host_out_ff2	= 0;
	reg[15:0]	addr_out_ff2	= 0;
	
	always @(posedge clk) begin
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Time-limit the proof. This is obviously less than ideal since the proof isn't complete
		
		if(!hang) begin
			hang_count	<= hang_count + 1;
			if(hang_count == 31)
				hang <= 1;
		end
		
		if(hang) begin
			//do nothing
		end
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Currently processing a command.
		
		//Don't try to verify all of the internal operations, just verify end-to-end consistency.
		//In other words, persistent state changes should only take effect iff the spec dictates 
		
		else if(cmd_busy) begin
		
			addr_out_ff2		<= addr_out_ff;
			host_out_ff2		<= host_out_ff;
			
			count				<= count + 1;
			
			mutex_granted_ff	<= mutex_granted;
	
			//If a send is going out, make sure the values are what we expected
			if(rpc_fab_tx_en) begin
				cmd_busy	<= 0;
				tx_busy		<= 1;
				
				//We should always expect the call number to equal whatever came in
				tx_callnum_expected		<= rpc_fab_rx_callnum[2:0];
				assert(rpc_fab_tx_callnum == rpc_fab_rx_callnum[2:0]);
				
				//Expected type for the send should equal whatever the type is now
				tx_type_expected		<= rpc_fab_tx_type;
				
				//Save expected data
				tx_d0_expected			<= rpc_fab_tx_d0;
				tx_d1_expected			<= rpc_fab_tx_d1;
				tx_d2_expected			<= rpc_fab_tx_d2;
				
				case(rpc_fab_rx_callnum[2:0])
					
					//Lock the mutex.
					NAMESERVER_LOCK: begin
					
						//Data values are undefined.
						
						//Don't write to memory, touch the mutex, or mess with the HMAC engine.
						//It's OK to read, though
						assert(wr_en == 0);
						assert(hmac_mem_wr == 0);
						assert(mutex_lock_en == 0);
						assert(mutex_unlock_en == 0);
						assert(hmac_start_en == 0);
						assert(hmac_data_en == 0);
						assert(hmac_finish_en == 0);
					
						//Should succeed iff the mutex was granted
						if(mutex_granted_ff)
							assert(rpc_fab_tx_type == RPC_TYPE_RETURN_SUCCESS);
					
						//otherwise retry
						else
							assert(rpc_fab_tx_type == RPC_TYPE_RETURN_RETRY);
							
						//fail if read only (not tested here)
						
					end	//end NAMESERVER_LOCK
					
					//Read a single entry from the name server
					NAMESERVER_LIST: begin
						
						//Don't write to memory, touch the mutex, or mess with the HMAC engine.
						//It's OK to read, though
						assert(wr_en == 0);
						assert(hmac_mem_wr == 0);
						assert(mutex_lock_en == 0);
						assert(mutex_unlock_en == 0);
						assert(hmac_start_en == 0);
						assert(hmac_data_en == 0);
						assert(hmac_finish_en == 0);
						
						//Always succeeds
						assert(rpc_fab_tx_type == RPC_TYPE_RETURN_SUCCESS);
						
						//Should return data from the memory read last cycle
						assert(rpc_fab_tx_d0 == addr_out_ff2);
						assert({rpc_fab_tx_d1, rpc_fab_tx_d2} == host_out_ff2);
						
					end	//end NAMESERVER_LIST
					
					//We don't know what it is.
					//Don't try to prove anything about it
					default: begin
						hang	<= 1;
					end
				endcase
				
			end
			
			//If the message is not an RPC call, ignore it.
			else if(rpc_fab_rx_type != RPC_TYPE_CALL) begin
			
				//Don't send anything
				assert(rpc_fab_tx_en == 0);
				
				//Don't touch data memory
				assert(rd_en == 0);
				assert(wr_en == 0);
				
				//Don't touch HMAC memory
				assert(hmac_mem_wr == 0);
				
				//Don't touch the mutex
				assert(mutex_lock_en == 0);
				assert(mutex_unlock_en == 0);
				
				//Don't touch HMAC engine
				assert(hmac_start_en == 0);
				assert(hmac_data_en == 0);
				assert(hmac_finish_en == 0);
				
				//Drop the packet
				assert(rpc_fab_rx_done == 1);
				cmd_busy	<= 0;
				
			end
			
			//It's a call, process it.
			else begin
				case(count)
					
					//Cycle 0 = STATE_IDLE results
					0: begin
					
						//Don't write to memory, unlock the mutex, or mess with the HMAC engine.
						//It's OK to read, though
						assert(wr_en == 0);
						assert(hmac_mem_wr == 0);
						assert(mutex_unlock_en == 0);
						assert(hmac_start_en == 0);
						assert(hmac_data_en == 0);
						assert(hmac_finish_en == 0);
						
						//Try to lock the mutex iff we're requesting a lock
						if(rpc_fab_rx_callnum[2:0] == NAMESERVER_LOCK)
							assert(mutex_lock_en == 1);
						else
							assert(mutex_lock_en == 0);
							
					end	//end cycle 0
					
					//Cycle 1 = STATE_DISPATCH results
					//TODO: Do stuff here
					1: begin
					
						case(rpc_fab_rx_callnum[2:0])
						
							//Read from a specified address in the name table
							NAMESERVER_LIST: begin
							
								//Should actually be doing the read (from the requested address)
								assert(rd_ptr == rpc_fab_rx_d0[ADDR_BITS-1 : 0]);
								assert(rd_en == 1);
							
								//Don't write to memory, mess with the mutex, or mess with the HMAC engine.
								assert(wr_en == 0);
								assert(hmac_mem_wr == 0);
								assert(mutex_lock_en == 0);
								assert(mutex_unlock_en == 0);
								assert(hmac_start_en == 0);
								assert(hmac_data_en == 0);
								assert(hmac_finish_en == 0);
							
							end
							
							//Lock should be sending now, so complain if we get here
							NAMESERVER_LOCK: begin
								assert(0);
							end
							
							//TODO: Other opcodes
							default: begin
								hang	<= 1;
							end
							
						endcase
					
					end	//end cycle 1
					
					//Cycle 2 = first compute state
					2: begin
					
						case(rpc_fab_rx_callnum[2:0])
						
							//don't check NAMESERVER_LOCK as that's done already
						
							//Should be sending now, so complain if we get here
							NAMESERVER_LIST: begin
								assert(0);
							end
						
							default: begin
								//TODO
							end
						
						endcase
					
					end
			
				endcase
			end
			
		end
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// A packet is currently being sent.
		// Make sure values didn't change from when we first sent them.
		else if(tx_busy) begin
			
			tx_busy_ff		<= 1;
		
			//Header fields should not have changed
			assert(rpc_fab_tx_type == tx_type_expected);
			assert(rpc_fab_tx_callnum == tx_callnum_expected);
			
			//Data should not have changed
			assert(rpc_fab_tx_d0 == tx_d0_expected);
			assert(rpc_fab_tx_d1 == tx_d1_expected);
			assert(rpc_fab_tx_d2 == tx_d2_expected);
			
			//Don't touch data memory
			assert(rd_en == 0);
			assert(wr_en == 0);
			
			//Don't touch HMAC memory
			assert(hmac_mem_wr == 0);
			
			//Don't touch the mutex
			assert(mutex_lock_en == 0);
			assert(mutex_unlock_en == 0);
			
			//Don't touch HMAC engine
			assert(hmac_start_en == 0);
			assert(hmac_data_en == 0);
			assert(hmac_finish_en == 0);
			
			//Don't start another send
			assert(rpc_fab_tx_en == 0);
			
			//Done
			if(rpc_fab_tx_done)
				tx_busy	<= 0;
			
		end
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Not doing anything
		else begin
			
			tx_busy_ff	<= 0;
			
			//If we just finished a send, we're done receiving
			//Otherwise, leave the buffer alone
			assert(rpc_fab_rx_done == tx_busy_ff);
			
			//Don't touch data memory
			assert(rd_en == 0);
			assert(wr_en == 0);
			
			//Don't touch HMAC memory
			assert(hmac_mem_wr == 0);
			
			//Don't touch the mutex
			assert(mutex_lock_en == 0);
			assert(mutex_unlock_en == 0);
			
			//Don't touch HMAC engine
			assert(hmac_start_en == 0);
			assert(hmac_data_en == 0);
			assert(hmac_finish_en == 0);
			
			//When a new command comes in, save it
			if(rpc_fab_rx_en) begin
				cmd_busy	<= 1;
				count		<= 0;
			end
			
		end		
	end
	
endmodule
