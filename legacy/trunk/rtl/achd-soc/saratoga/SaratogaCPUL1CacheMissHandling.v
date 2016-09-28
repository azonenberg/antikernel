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
	@brief Cache miss handling logic
 */
module SaratogaCPUL1CacheMissHandling(
	clk,
	miss_rd, miss_tid, miss_addr, miss_perms,
	push_wr, push_tid, push_addr, push_data,
	flush_en, flush_tid, flush_addr, flush_data, flush_done,
	
	read_pending,
	
	mmu_translate_en, mmu_translate_tid, mmu_translate_vaddr, mmu_translate_perms, mmu_translate_nocaddr,
		mmu_translate_phyaddr, mmu_translate_done, mmu_translate_failed,
		
	dma_fab_tx_en, dma_fab_tx_done,
	dma_fab_rx_en, dma_fab_rx_done, dma_fab_rx_inbox_full, dma_fab_rx_dst_addr,
	
	dma_fab_header_wr_en, dma_fab_header_wr_addr, dma_fab_header_wr_data,
	dma_fab_header_rd_en, dma_fab_header_rd_addr, dma_fab_header_rd_data,
	
	dma_fab_data_wr_en, dma_fab_data_wr_addr, dma_fab_data_wr_data,
	dma_fab_data_rd_en, dma_fab_data_rd_addr, dma_fab_data_rd_data
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//NoC address of the CPU
	parameter NOC_ADDR			= 16'h0000;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	//Number of words in a cache line
	parameter WORDS_PER_LINE	= 8;
	
	//Number of bits for word addressing
	localparam WORD_ADDR_BITS = clog2(WORDS_PER_LINE);
	
	//Number of bits for byte indexing (constant)
	localparam BYTE_ADDR_BITS	= 2;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;
	
	//Miss interface
	input wire					miss_rd;
	input wire[TID_BITS-1 : 0]	miss_tid;
	input wire[2:0]				miss_perms;
	input wire[31:0]			miss_addr;
	
	//Push interface
	output reg					push_wr			= 0;
	output reg[TID_BITS-1:0]	push_tid		= 0;
	output reg[31:0]			push_addr		= 0;
	output reg[63:0]			push_data		= 0;
	
	output reg					read_pending	= 0;
	
	//Flush interface
	input wire					flush_en;
	input wire[TID_BITS-1:0]	flush_tid;
	input wire[31:0]			flush_addr;
	input wire[63:0]			flush_data;
	output reg					flush_done		= 0;
	
	//MMU interface
	output reg					mmu_translate_en		= 0;
	output reg[TID_BITS-1 : 0]	mmu_translate_tid		= 0;
	output reg[31:0]			mmu_translate_vaddr		= 0;
	output reg[2:0]				mmu_translate_perms		= 0;
	input wire[15:0]			mmu_translate_nocaddr;
	input wire[31:0]			mmu_translate_phyaddr;
	input wire					mmu_translate_done;
	input wire					mmu_translate_failed;
	
	//DMA interface
	output reg					dma_fab_tx_en			= 0;
	input wire					dma_fab_tx_done;
	input wire					dma_fab_rx_en;
	output reg					dma_fab_rx_done			= 0;
	input wire					dma_fab_rx_inbox_full;
	input wire[15:0]			dma_fab_rx_dst_addr;
	
	input wire					dma_fab_header_wr_en;
	input wire[1:0]				dma_fab_header_wr_addr;
	input wire[31:0]			dma_fab_header_wr_data;
	input wire					dma_fab_header_rd_en;
	input wire[1:0]				dma_fab_header_rd_addr;
	output reg[31:0]			dma_fab_header_rd_data	= 0;
	
	input wire					dma_fab_data_wr_en;
	input wire[8:0]				dma_fab_data_wr_addr;
	input wire[31:0]			dma_fab_data_wr_data;
	input wire					dma_fab_data_rd_en;
	input wire[8:0]				dma_fab_data_rd_addr;
	output reg[31:0]			dma_fab_data_rd_data	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Buffer of data to be flushed
	
	wire[63:0]		flush_mem_dout;
	
	localparam QWORD_ADDR_BITS = WORD_ADDR_BITS - 1;
	
	MemoryMacro #(
		.WIDTH(64),
		.DEPTH(WORDS_PER_LINE/2),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1'b0),
		.OUT_REG(1'b0),
		.INIT_ADDR(1'b0),
		.INIT_FILE("")
	) flush_data_mem (

		.porta_clk(clk),
		.porta_en(flush_en),
		.porta_addr(flush_addr[(BYTE_ADDR_BITS + 1) +: QWORD_ADDR_BITS]),
		.porta_we(flush_en),
		.porta_din(flush_data),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(dma_fab_data_rd_addr[1 +: QWORD_ADDR_BITS]),	//bit 0 is word selector
		.portb_we(1'b0),
		.portb_din(64'h0),
		.portb_dout(flush_mem_dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state logic
	
	`include "SaratogaCPUPagePermissions_constants.v"
	`include "SaratogaCPUL1CacheMissHandling_states_constants.v"
	`include "DMARouter_constants.v"
		
	reg[3:0] state	= STATE_IDLE;
	
	//Source address of the thread that's missing
	wire[15:0]	miss_nocaddr		= (NOC_ADDR + MAX_THREADS) + miss_tid;
	
	//Source address of the thread that's flushing
	wire[15:0]	flush_nocaddr		= (NOC_ADDR + MAX_THREADS) + flush_tid;
	
	//Burst length padded out to 10 bits
	wire[9:0]	miss_burstlen		= WORDS_PER_LINE;
	
	always @(posedge clk) begin
	
		mmu_translate_en		<= 0;
		mmu_translate_tid		<= 0;
		mmu_translate_vaddr		<= 0;
		mmu_translate_perms		<= 0;
		
		dma_fab_tx_en			<= 0;
		dma_fab_rx_done			<= 0;
		
		dma_fab_header_rd_data	<= 0;
		dma_fab_data_rd_data	<= 0;
		
		push_wr					<= 0;
		push_tid				<= 0;
		push_addr				<= 0;
		
		flush_done				<= 0;
		
		case(state)
			
			//Idle - sit around and wait for a miss to happen
			STATE_IDLE: begin
			
				//Miss came in, send it to the MMU for translation
				if(miss_rd) begin
					
					mmu_translate_en		<= 1;
					mmu_translate_tid		<= miss_tid;
					mmu_translate_vaddr		<= miss_addr;
					mmu_translate_perms		<= miss_perms;
					
					state					<= STATE_READ_MMU;
					
				end
				
				//Flush came in, send it to the MMU for translation
				if(flush_en) begin
				
					mmu_translate_en		<= 1;
					mmu_translate_tid		<= flush_tid;
					mmu_translate_vaddr		<= flush_addr;
					mmu_translate_perms		<= PAGE_WRITE;
				
					state					<= STATE_WRITE_MMU;
				end
			
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read path
			
			//Wait for the MMU to finish translation
			STATE_READ_MMU: begin
				if(mmu_translate_done) begin
					
					//TODO: Figure out how to handle segfaults!
					//For now, we'll hang and all subsequent memory accesses will block.
					//This is obviously sub-optimal.
					//Proper solution is to terminate the offending thread
					if(mmu_translate_failed) begin
					end
					
					//Translate worked out fine, issue the fetch
					else begin
						dma_fab_tx_en		<= 1;
						state				<= STATE_READ_SEND;
					end
					
				end				
			end	//end STATE_READ_MMU
			
			//Wait for the DMA send to finish
			STATE_READ_SEND: begin
			
				if(dma_fab_header_rd_en) begin
					case(dma_fab_header_rd_addr)
						0: 	dma_fab_header_rd_data	<= { miss_nocaddr, mmu_translate_nocaddr};
						1:	dma_fab_header_rd_data	<= { DMA_OP_READ_REQUEST, 20'h0, miss_burstlen };
						2:	dma_fab_header_rd_data	<= mmu_translate_phyaddr;
					endcase
				end
				
				//do not send data, it's a read request
				
				if(dma_fab_tx_done) begin
					state			<= STATE_READ_WAIT;
					read_pending	<= 1;
				end
			
			end	//end STATE_READ_SEND
			
			//Wait for data to come back
			STATE_READ_WAIT: begin
			
				//New packet? Deal with it
				if(dma_fab_header_wr_en) begin
					
					//Source is not the place we missed from? Drop it
					if(dma_fab_header_wr_data[31:16] != mmu_translate_nocaddr)
						state	<= STATE_READ_DROP;
						
					//Destination address is not our thread? Drop it
					//TODO: Support multiple outstanding misses
					else if(dma_fab_header_wr_data[15:0] != miss_nocaddr)
						state	<= STATE_READ_DROP;
						
					//It's a good packet, handle it
					else
						state	<= STATE_READ_BODY;
					
				end
			
			end	//end STATE_READ_WAIT
			
			//Process an incoming DMA packet
			STATE_READ_BODY: begin
			
				if(dma_fab_header_wr_en) begin
					//TODO: Sanity check packet body
				end
			
				//Incoming data
				if(dma_fab_data_wr_en) begin
			
					//If the data is an EVEN address, just save it
					if(!dma_fab_data_wr_addr[0])
						push_data[63:32]	<= dma_fab_data_wr_data;
					
					//If the data is an ODD address, push it to the cache bank
					else begin
						push_wr				<= 1;
						push_tid			<= miss_tid;
						push_addr			<= miss_addr + {dma_fab_data_wr_addr[8:1], 3'h0};
						push_data[31:0]		<= dma_fab_data_wr_data;
					end
					
				end
				
				if(dma_fab_rx_inbox_full) begin
					read_pending		<= 0;
					dma_fab_rx_done		<= 1;
					state				<= STATE_IDLE;
				end
			
			end	//end STATE_READ_BODY
			
			//Drop a packet we don't want
			STATE_READ_DROP: begin
				if(dma_fab_rx_inbox_full) begin
					dma_fab_rx_done		<= 1;
					state				<= STATE_READ_WAIT;
				end
			end	//end STATE_READ_DROP
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read path
			
			//Wait for the MMU to finish translation
			STATE_WRITE_MMU: begin
				if(mmu_translate_done) begin
					
					//TODO: Figure out how to handle segfaults!
					//For now, we'll hang and all subsequent memory accesses will block.
					//This is obviously sub-optimal.
					//Proper solution is to terminate the offending thread
					if(mmu_translate_failed) begin
					end
					
					//Translate worked out fine, issue the fetch
					else begin
						dma_fab_tx_en		<= 1;
						state				<= STATE_WRITE_SEND;
					end
					
				end				
			end	//end STATE_WRITE_MMU
			
			//Wait for the DMA send to finish
			STATE_WRITE_SEND: begin
			
				if(dma_fab_header_rd_en) begin
					case(dma_fab_header_rd_addr)
						0: 	dma_fab_header_rd_data	<= { flush_nocaddr, mmu_translate_nocaddr};
						1:	dma_fab_header_rd_data	<= { DMA_OP_WRITE_REQUEST, 20'h0, miss_burstlen };
						2:	dma_fab_header_rd_data	<= mmu_translate_phyaddr;
					endcase
				end
				
				//Pick even or odd word from the memory
				if(dma_fab_data_rd_en) begin
					if(dma_fab_data_rd_addr[0])
						dma_fab_data_rd_data	<= flush_mem_dout[31:0];
					else
						dma_fab_data_rd_data	<= flush_mem_dout[63:32];
				end
				
				if(dma_fab_tx_done) begin
					flush_done		<= 1;
					state			<= STATE_IDLE;
				end
			
			end	//end STATE_WRITE_SEND
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Push incoming DMA to the destination nodes
	
	//TODO: Need to figure out how to handle access-denied and write-done messages from the endpoint
	//Probably just snoop traffic coming off the RPC interface
	
endmodule

