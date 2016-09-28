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
	@brief Control state machine for BlockRamAllocator.
*/

module BlockRamAllocator_control(
	clk,
	rpc_fab_tx_en, rpc_fab_tx_dst_addr, rpc_fab_tx_callnum, rpc_fab_tx_type,
		rpc_fab_tx_d0, rpc_fab_tx_d1, rpc_fab_tx_d2, rpc_fab_tx_done,
	rpc_fab_rx_en, rpc_fab_rx_src_addr, rpc_fab_rx_callnum, rpc_fab_rx_type,
		rpc_fab_rx_d1, rpc_fab_rx_d2, rpc_fab_rx_done,
	dtx_busy, dtx_en, dtx_dst_addr, dtx_op, dtx_len, dtx_addr, dtx_raddr,
	drx_ready, drx_en, drx_src_addr, drx_op, drx_addr, drx_len, drx_buf_rd, drx_buf_addr, drx_buf_data,
	storage_raddr, storage_we, storage_wdata, storage_waddr,
	page_owner_wr_en, page_owner_wr_data, page_owner_addr, page_owner_rd_data,
	free_page_count, free_list_rd_en, free_list_rd_data, free_list_wr_en, free_list_wr_data, rpc_fab_inbox_full
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//Number of 2KB pages in the memory
	parameter NUM_PAGES		= 8;
	
	`include "../util/clog2.vh"
	
	//Number of bits in a page ID
	localparam PAGE_ID_BITS = clog2(NUM_PAGES);
	
	//Depth of the memory, in 32-bit words
	localparam DEPTH = NUM_PAGES * 512;
	
	//number of bits in the address bus
	localparam ADDR_BITS = clog2(DEPTH);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	output reg			rpc_fab_tx_en		= 0;
	output reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	output reg[7:0]		rpc_fab_tx_callnum	= 0;
	output reg[2:0]		rpc_fab_tx_type		= 0;
	output reg[20:0]	rpc_fab_tx_d0		= 0;
	output reg[31:0]	rpc_fab_tx_d1		= 0;
	output reg[31:0]	rpc_fab_tx_d2		= 0;
	input wire			rpc_fab_tx_done;
	
	input wire			rpc_fab_rx_en;
	input wire[15:0]	rpc_fab_rx_src_addr;
	input wire[7:0]		rpc_fab_rx_callnum;
	input wire[2:0]		rpc_fab_rx_type;
	input wire[31:0]	rpc_fab_rx_d1;
	input wire[31:0]	rpc_fab_rx_d2;
	output reg			rpc_fab_rx_done		= 0;
	input wire			rpc_fab_inbox_full;
	
	input wire			dtx_busy;
	output reg			dtx_en				= 0;
	output reg[15:0]	dtx_dst_addr		= 0;
	output reg[1:0]		dtx_op				= 0;
	output reg[9:0]		dtx_len				= 0;
	output reg[31:0]	dtx_addr			= 0;
	input wire[9:0]		dtx_raddr;
	
	output reg			drx_ready			= 1;
	input wire			drx_en;
	input wire[15:0]	drx_src_addr;
	input wire[1:0]		drx_op;
	input wire[31:0]	drx_addr;
	input wire[9:0]		drx_len;
	output reg			drx_buf_rd			= 0;
	output reg[9:0]		drx_buf_addr		= 0;
	input wire[31:0]	drx_buf_data;
	
	output wire[31:0]	storage_raddr;
	output reg			storage_we			= 0;
	output wire[31:0]	storage_wdata;
	output reg[31:0]	storage_waddr		= 0;
	
	output reg						page_owner_wr_en	= 0;
	output reg[15:0]				page_owner_wr_data	= 0;
	output reg[PAGE_ID_BITS-1:0]	page_owner_addr		= 0;
	input wire[15:0]				page_owner_rd_data;
	
	input wire[PAGE_ID_BITS:0]		free_page_count;
	output reg						free_list_rd_en		= 0;
	input wire[PAGE_ID_BITS-1:0]	free_list_rd_data;
	output reg						free_list_wr_en		= 0;
	output reg[PAGE_ID_BITS-1:0]	free_list_wr_data	= 0;
	
	parameter NOC_ADDR = 16'h0000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Memory addressing helpers

	/*
		PHYSICAL ADDRESS map

		26:11		Page ID
		10:2		Word within the page
		1:0			Byte within the page (ignored, always zero)
	 */
	 
	reg zeroize = 0;
		
	//The page ID of the current address
	//Bottom 11 bits 10:0 are the byte address within the page (last 3 must be zero for cache line alignment)
	//Next 16 26:11 are page ID
	//31:27 are unimplemented and must be zero
	wire[15:0] drx_page_id = drx_addr[26:11];
	reg[15:0] drx_page_id_ff = 0;
	wire[31:0] drx_end_addr = drx_addr + drx_len;
	wire[15:0] drx_end_page_id = drx_end_addr[26:11];
	
	//Page ID for RPC mode (chown/free)
	wire[15:0] rpc_page_id = rpc_fab_rx_d1[26:11];
	
	//Current addresses within the page (in words)
	reg[8:0] purge_addr = 0;
	reg[8:0] drx_base_addr = 0;
	wire[8:0] dma_storage_blockaddr = drx_buf_addr_buf + drx_base_addr;
	wire[8:0] dtx_block_addr = dtx_raddr + drx_base_addr;
	
	//Read stuff
	assign storage_raddr = {drx_page_id_ff, dtx_block_addr};
	
	//Register read stuff
	reg[8:0] drx_buf_addr_buf	= 0;
	reg[31:0] drx_buf_data_buf	= 0;
	always @(posedge clk) begin
		if(drx_buf_rd)
			drx_buf_addr_buf <= drx_buf_addr[8:0];
		drx_buf_data_buf	<= drx_buf_data;
	end
	
	//Write stuff (delayed one cycle)
	assign storage_wdata = zeroize ? 32'h00000000 : drx_buf_data_buf;
	wire[31:0] storage_waddr_adv;
	reg storage_we_adv;
	assign storage_waddr_adv = zeroize ? 
		{ rpc_page_id, purge_addr } :
		{ drx_page_id_ff, dma_storage_blockaddr};
	always @(posedge clk) begin
		storage_waddr	<= storage_waddr_adv;
		storage_we		<= storage_we_adv;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "RPCv2Router_type_constants.v"
	`include "RPCv2Router_ack_constants.v"
	`include "DMARouter_constants.v"
	`include "NetworkedDDR2Controller_opcodes_constants.v"
	`include "BlockRamAllocator_state_constants.v"
	
	reg rpc_message_pending = 0;
	reg dma_message_pending = 0;
	
	reg[2:0] state = STATE_IDLE;
	
	//Name some common state values
	wire rpc_rx_ready;
	assign rpc_rx_ready = rpc_fab_rx_en || rpc_message_pending;
	wire rpc_call_active;
	assign rpc_call_active = (state == STATE_IDLE) && rpc_rx_ready && (rpc_fab_rx_type == RPC_TYPE_CALL);

	//Register the read address/data
	reg[PAGE_ID_BITS-1:0]	page_owner_addr_ff		= 0;
	reg[15:0]				page_owner_rd_data_ff	= 0;
	always @(posedge clk) begin
		page_owner_addr_ff		<= page_owner_addr;
		page_owner_rd_data_ff	<= page_owner_rd_data;
	end
	wire rpc_process_active = (state == STATE_RPC_PROCESS);

	//Combinatorial logic for ownership reads and writes
	reg rpc_owner_ok		= 0;
	reg dma_owner_ok		= 0;
	always @(*) begin
		page_owner_wr_en	<= 0;
		page_owner_wr_data	<= 0;
		
		rpc_owner_ok		<= (rpc_fab_rx_src_addr == page_owner_rd_data_ff);
		dma_owner_ok		<= (drx_src_addr == page_owner_rd_data_ff);
		
		//We just processed a call
		if(rpc_process_active) begin
					
			//Reuse the read address from last cycle
			page_owner_addr		<= page_owner_addr_ff;
			
			//Issue the write, if necessary
			case(rpc_fab_rx_callnum)
				
				RAM_ALLOCATE: begin
					page_owner_wr_data <= rpc_fab_rx_src_addr;
					if(free_page_count != 0)
						page_owner_wr_en <= 1;
				end	//end RAM_ALLOCATE
				
				RAM_CHOWN: begin
					page_owner_wr_data <= rpc_fab_rx_d2[15:0];
					if(rpc_owner_ok)
						page_owner_wr_en <= 1;
				end	//end RAM_CHOWN
				
				RAM_FREE: begin
					page_owner_wr_data <= NOC_ADDR;
					if(rpc_owner_ok)
						page_owner_wr_en <= 1;
				end	//end RAM_FREE
				
				default: begin
				end
				
			endcase
			
		end
		
		//Call came through
		else if(rpc_call_active) begin

			if(rpc_fab_rx_callnum == RAM_ALLOCATE)
				page_owner_addr <= free_list_rd_data;
			else
				page_owner_addr <= rpc_page_id[PAGE_ID_BITS-1:0];
			
		end
		
		//Otherwise use DMA source address
		else
			page_owner_addr <= drx_page_id[PAGE_ID_BITS-1:0];
		
	end
	
	//Main sequential state logic
	always @(posedge clk) begin
	
		rpc_fab_tx_en	<= 0;
		rpc_fab_rx_done	<= 0;
		drx_buf_rd		<= 0;
		dtx_en			<= 0;
		storage_we_adv	<= 0;
		free_list_wr_en <= 0;
		free_list_rd_en <= 0;
		
		//When a message comes in and we're busy, make a note of it
		if(rpc_fab_rx_en)
			rpc_message_pending <= 1;
		if(drx_en) begin
			dma_message_pending <= 1;
			drx_ready <= 0;
		end
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Nothing to do

			STATE_IDLE: begin
					
				//Prepare to respond to whatever we got
				rpc_fab_tx_d0 <= 0;
				rpc_fab_tx_d1 <= 0;
				rpc_fab_tx_d2 <= 0;
					
				//See if any RPC commands are here
				if(rpc_rx_ready) begin
				
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
					
					rpc_message_pending <= 0;
					
					case(rpc_fab_rx_type)
									
						//Remote procedure call - deal with it
						RPC_TYPE_CALL: begin
							state <= STATE_RPC_PROCESS;
						end
						
						default: begin
							rpc_fab_rx_done <= 1;
						end
						
					endcase
					
				end	//end check for rpc messages
				
				//See if any DMA commands are here
				else if(drx_en || dma_message_pending) begin
					dma_message_pending <= 0;

					//Prepare to send success/fail interrupt. Default to fail.
					rpc_fab_tx_dst_addr <= drx_src_addr;
					rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_d0 <= drx_len;
					rpc_fab_tx_d1 <= drx_addr;
					rpc_fab_tx_callnum <= RAM_OP_FAILED;
					
					//Assume it succeeded (we don't send DMA on failure)
					dtx_addr <= drx_addr;
					dtx_len <= drx_len;
					dtx_dst_addr <= drx_src_addr;
					dtx_op <= DMA_OP_READ_DATA;
					drx_page_id_ff <= drx_page_id;
					drx_base_addr <= drx_addr[10:2];
					
					//Memory operations cannot cross page boundaries.
					//While we're at it, verify the address is sane
					//and the length is a multiple of 4 words (one cache line)
					if( (drx_page_id != drx_end_page_id) ||
						(drx_addr[31:27] != 0) ||
						(drx_addr[3:0] != 0) ||
						(drx_len[1:0] != 0)
						) begin
						
						rpc_fab_tx_en <= 1;								
						state <= STATE_RPC_TXHOLD;
						
					end
					
					//Looks good, go crunch it
					else
						state <= STATE_DMA_PROCESS;

				end	//end check for dma messages
				
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Procss incoming RPCs
			
			STATE_RPC_PROCESS: begin
				case(rpc_fab_rx_callnum)
								
					//Get RAM status
					RAM_GET_STATUS: begin
						rpc_fab_tx_d0[15:0] <= free_page_count;
						rpc_fab_tx_d0[16] <= 1;
						rpc_fab_tx_en <= 1;
						rpc_fab_rx_done <= 1;		
						state <= STATE_RPC_TXHOLD;																
					end
					
					//Allocate a single page of RAM.
					//Memory is guaranteed to be zero-filled.
					RAM_ALLOCATE: begin
					
						//Out of memory									
						if(free_page_count == 0) begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_en <= 1;
							rpc_fab_rx_done <= 1;
							state <= STATE_RPC_TXHOLD;
						end
						
						//Memory is available
						else begin
							
							//Send the message
							rpc_fab_tx_d1 <= {free_list_rd_data, 11'h0};
							rpc_fab_tx_en <= 1;
							rpc_fab_rx_done <= 1;
							
							//Store the new ownership record (done combinatorially)
							
							//Pop the FIFO and continue
							free_list_rd_en <= 1;
							state <= STATE_RPC_TXHOLD;
							
						end
						
					end	//end RAM_ALLOCATE
					
					//Change ownership of a single page of RAM
					RAM_CHOWN: begin
						
						//Ignore the request if we don't own the page
						if(!rpc_owner_ok) begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_en <= 1;
							
							rpc_fab_rx_done <= 1;
							state <= STATE_RPC_TXHOLD;
						end
						
						//Do the chown
						else begin
						
							//Actual chown is done combinatorially
							rpc_fab_tx_en <= 1;
							
							rpc_fab_rx_done <= 1;
							state <= STATE_RPC_TXHOLD;
						
						end
						
					end	//end RAM_CHOWN
					
					//Free a single page of RAM.
					RAM_FREE: begin
					
						//Ignore the request if we don't own the page
						if(!rpc_owner_ok) begin
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							rpc_fab_tx_en <= 1;
							
							rpc_fab_tx_d0	<= rpc_fab_rx_src_addr;
							rpc_fab_tx_d1	<= page_owner_rd_data_ff;
							
							rpc_fab_rx_done <= 1;
							state <= STATE_RPC_TXHOLD;
						end
						
						//We own it, update records
						else begin
							
							//Store the new ownership record (done combinatorially)
							
							//Push the page ID onto the free list
							free_list_wr_data <= rpc_fab_rx_d1[11 +: PAGE_ID_BITS];
							free_list_wr_en <= 1;
							
							//Start the zeroize operation
							zeroize <= 1;
							storage_we_adv <= 1;
							purge_addr <= 0;
							state <= STATE_ZEROIZE;
							
						end
					
					end
					
					//Not implemented? Report failure right away
					default: begin								
						rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
						rpc_fab_tx_en <= 1;
						
						rpc_fab_rx_done <= 1;
						
						state <= STATE_RPC_TXHOLD;
					end
					
				endcase
			end	//end STATE_RPC_PROCESS
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// DMA logic
			
			STATE_DMA_PROCESS: begin
			
				//Bad sender
				if(!dma_owner_ok) begin
					rpc_fab_tx_en <= 1;									
					state <= STATE_RPC_TXHOLD;
				end
			
				//Nope, check the opcode
				else begin
					case(drx_op)
							
						DMA_OP_WRITE_REQUEST: begin
							//TODO: figure out how to stream without copying
							drx_buf_rd <= 1;
							drx_buf_addr <= 0;
							state <= STATE_WRITE;
							
							drx_page_id_ff <= drx_page_id;
							drx_base_addr <= drx_addr[10:2];

						end	//end DMA_OP_WRITE_REQUEST
						
						DMA_OP_READ_REQUEST: begin

							dtx_en <= 1;
							state <= STATE_DMA_TXHOLD;
							
							//Immediately clear the ingress buffer to avoid potential send-during-receive
							//deadlocks
							drx_ready <= 1;
							
						end	//end DMA_OP_READ_REQUEST
						
						//ignore other stuff. just send fail alert
						default: begin
							rpc_fab_tx_en <= 1;							
							state <= STATE_RPC_TXHOLD;
						end
						
					endcase
				end
			
			end	//end STATE_DMA_PROCESS
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Writeback/copy logic
			
			STATE_WRITE: begin
			
				//Prepare to send write-done interrupt
				rpc_fab_tx_callnum <= RAM_WRITE_DONE;
			
				//Write the current data
				storage_we_adv <= 1;
				
				//Start reading next address
				drx_buf_rd <= 1;
				drx_buf_addr <= drx_buf_addr + 10'h1;
			
				//Just wrote last word? Done
				if((drx_buf_addr_buf + 10'h1) == drx_len) begin
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
					storage_we_adv <= 0;
				end
			
			end	//end STATE_WRITE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Zeroization during free
			
			STATE_ZEROIZE: begin
				
				storage_we_adv <= 1;
				purge_addr <= purge_addr + 9'h1;
				
				//Stop once zeroization is done
				if(purge_addr == 511) begin
					storage_we_adv <= 0;
				
					rpc_fab_tx_en <= 1;
					rpc_fab_rx_done <= 1;
					state <= STATE_RPC_TXHOLD;
				end
				
			end	//end STATE_ZEROIZE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// DMA helper states
			
			STATE_DMA_TXHOLD: begin
				if(!dtx_en && !dtx_busy)
					state <= STATE_IDLE;
			end //end STATE_DMA_TXHOLD
			
			STATE_RPC_TXHOLD: begin
			
				zeroize <= 0;
			
				if(rpc_fab_tx_done) begin
				
					//BUGFIX: Do not set drx_ready if we have a pending message!
					if(!dma_message_pending)
						drx_ready <= 1;
					
					state <= STATE_IDLE;
				end
			end	//end STATE_RPC_TXHOLD
			
		endcase

	end
	
endmodule
