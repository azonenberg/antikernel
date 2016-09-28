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
	@brief L1 cache for the GRAFTON CPU
	
	Read flow
		Assert rd_en with rd_addr valid
		Wait for rd_valid to go high, use rd_data
		
	Write flow
		Assert wr_en with wr_addr and wr_data valid
		Do not issue another write transaction until wr_done goes high
		
	DMA flush stuff
		Assert flush_en to flush all dirty cache lines to memory before doing a DMA transaction
		
	MMU interface TODO
		
	All CPU-side addresses are virtual.
 */
module GraftonCPUL1Cache(

	//Clocks
	clk,
	
	//NoC interface
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//I-side interface
	iside_cpu_addr,
	iside_rd_en, iside_rd_data, iside_rd_valid,
	
	//D-side interface
	dside_cpu_addr,
	dside_wr_en, dside_wr_data, dside_wr_mask, dside_wr_done, 
	dside_rd_en, dside_rd_data, dside_rd_valid,
	
	//CPU control interface
	flush_en, segfault, badvaddr, mmu_wr_en, mmu_wr_page_id, mmu_wr_phyaddr, mmu_wr_nocaddr, mmu_wr_permissions,
	
	//Status interface to main CPU
	dma_op_active, dma_op_addr, dma_op_cleared, dma_op_segfaulted, debug_clear_segfault,
	
	//Bootloader interface
	bootloader_start, bootloader_rd_en, bootloader_rd_data, bootloader_rd_addr, bootloader_pc_wr,
	
	//Profiling stats
	imiss_start, imiss_done, dmiss_start, dmiss_done
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	
	//DMA interface
	output wire dma_tx_en;
	output wire[31:0] dma_tx_data;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output wire dma_rx_ack;
	
	//I-side interface
	input wire iside_rd_en;
	input wire[31:0] iside_cpu_addr;
	output wire[31:0] iside_rd_data;
	output wire iside_rd_valid;
	
	//D-side interface
	input wire[31:0] dside_cpu_addr;
	input wire dside_wr_en;
	input wire[31:0] dside_wr_data;
	input wire[3:0] dside_wr_mask;
	output wire dside_wr_done;
	input wire dside_rd_en;
	output wire[31:0] dside_rd_data;
	output wire dside_rd_valid;
	
	//Cache control interface
	input wire flush_en;
	output reg segfault = 0;
	output reg[31:0] badvaddr = 32'hfeedfeed;
	input wire mmu_wr_en;
	input wire[8:0] mmu_wr_page_id;
	input wire[31:0] mmu_wr_phyaddr;
	input wire[15:0] mmu_wr_nocaddr;
	input wire[2:0] mmu_wr_permissions;
	
	//Status stuff
	output reg dma_op_active = 0; 
	output reg[15:0] dma_op_addr = 0;
	input wire dma_op_cleared;
	input wire dma_op_segfaulted;
	input wire debug_clear_segfault;
	
	//Bootloader interface
	output reg bootloader_start = 0;
	input wire bootloader_rd_en;
	output wire[31:0] bootloader_rd_data;
	input wire[31:0] bootloader_rd_addr;
	input wire bootloader_pc_wr;
	
	//Profiling stuff
	output reg	imiss_start	= 0;
	output reg	imiss_done	= 0;
	output reg	dmiss_start	= 0;
	output reg	dmiss_done	= 0;
	
	//MMU settings
	parameter bootloader_host = 16'h0000;
	parameter bootloader_addr = 32'h00000000;
	
	parameter NOC_ADDR = 16'h0000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transceiver
	
	`include "DMARouter_constants.v"
	
	//DMA transmit signals
	//Send a request to the bootloader immediately upon reset
	wire dtx_busy;
	reg[15:0] dtx_dst_addr		= bootloader_host;
	reg[1:0] dtx_op				= DMA_OP_READ_REQUEST;
	reg[9:0] dtx_len			= 512;
	reg[31:0] dtx_addr			= bootloader_addr;
	reg dtx_en					= 1;
	wire dtx_rd;
	wire[9:0] dtx_raddr;
	reg[31:0] dtx_buf_out = 0;
	
	//DMA receive signals
	reg drx_ready = 1;
	wire drx_en;
	wire[15:0] drx_src_addr;
	wire[15:0] drx_dst_addr;
	wire[1:0] drx_op;
	wire[31:0] drx_addr;
	wire[9:0] drx_len;	
	reg drx_buf_rd = 0;
	reg[9:0] drx_buf_addr = 0;
	reg[31:0] drx_buf_data = 0;
	
	wire[8:0] drx_buf_addr_fwd;
	assign drx_buf_addr_fwd = bootloader_rd_en ? bootloader_rd_addr[8:0] : drx_buf_addr[8:0];
	
	wire		rx_buf_rd = drx_buf_rd || bootloader_rd_en;
	wire[8:0]	rx_buf_addr = drx_buf_addr_fwd;
	
	reg[31:0] rx_buf[511:0];
	
	//Fill buffer to zero by default
	integer i;
	initial begin
		for(i=0; i<512; i = i+1)
			rx_buf[i] = 0;
	end
	
	//Write to receive buffer
	wire rx_we ;
	wire[8:0] rx_buf_waddr;
	wire[31:0] rx_buf_wdata;
	always @(posedge clk) begin
		if(rx_we)
			rx_buf[rx_buf_waddr] <= rx_buf_wdata;
	end
	
	//Read from receive buffer
	always @(posedge clk) begin
		if(rx_buf_rd)
			drx_buf_data <= rx_buf[rx_buf_addr];
	end
		
	wire	rx_state_header_2;
		
	DMATransceiverCore #(
		.LEAF_PORT(1),
		.LEAF_ADDR(NOC_ADDR)
	) txvr_core (
		.clk(clk),
		.dma_tx_en(dma_tx_en),
		.dma_tx_data(dma_tx_data),
		.dma_tx_ack(dma_tx_ack),
		.dma_rx_en(dma_rx_en),
		.dma_rx_data(dma_rx_data),
		.dma_rx_ack(dma_rx_ack),
		.tx_done(),
		.tx_busy(dtx_busy),
		.tx_src_addr(16'h0000),
		.tx_dst_addr(dtx_dst_addr),
		.tx_op(dtx_op),
		.tx_addr(dtx_addr),
		.tx_len(dtx_len),
		.tx_en(dtx_en),
		.tx_rd(dtx_rd),
		.tx_raddr(dtx_raddr),
		.tx_buf_out(dtx_buf_out),
		.rx_ready(drx_ready),
		.rx_en(drx_en),
		.rx_src_addr(drx_src_addr),
		.rx_dst_addr(drx_dst_addr),
		.rx_op(drx_op),
		.rx_addr(drx_addr),
		.rx_len(drx_len),
		.rx_we(rx_we),
		.rx_buf_waddr(rx_buf_waddr),
		.rx_buf_wdata(rx_buf_wdata),
		.rx_state_header_2(rx_state_header_2)
	);
		
	assign bootloader_rd_data = drx_buf_data;
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I-side cache bank
	
	wire iside_ctl_rd_en;
	wire[31:0] iside_ctl_rd_addr;
	reg[31:0] iside_ctl_rd_daddr = 0;
	reg iside_ctl_rd_valid = 0;
	reg iside_ctl_rd_done = 0;
	
	reg iside_ctl_segfault = 0;
	
	reg iside_ctl_rd_done_buf = 0;
	reg iside_ctl_rd_done_buf2 = 0;
	always @(posedge clk) begin
		iside_ctl_rd_done_buf <= iside_ctl_rd_done;
		iside_ctl_rd_done_buf2 <= iside_ctl_rd_done_buf;
	end
	
	GraftonCPUL1CacheBank iside_bank(
		.clk(clk),
		
		.cpu_addr(iside_cpu_addr),
		
		.wr_en(1'h0),
		.wr_data(32'h0),
		.wr_mask(4'h0),
		.wr_done(),
		
		.rd_en(iside_rd_en || iside_ctl_rd_done_buf2),
		.rd_data(iside_rd_data),
		.rd_valid(iside_rd_valid),
		
		.ctl_rd_en(iside_ctl_rd_en),
		.ctl_rd_addr(iside_ctl_rd_addr),
		.ctl_rd_data(drx_buf_data),
		.ctl_rd_daddr(iside_ctl_rd_daddr),
		.ctl_rd_valid(iside_ctl_rd_valid),
		.ctl_rd_done(iside_ctl_rd_done),
		
		.ctl_wr_en(), 
		.ctl_wr_addr(),
		.ctl_wr_data(),
		.ctl_wr_done(1'b0),
		.ctl_flush_en(1'b0),			//flushing not supported
		.ctl_flush_done(),
		
		.ctl_segfault(iside_ctl_segfault)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// D-side cache bank
	
	wire dside_ctl_rd_en;
	wire[31:0] dside_ctl_rd_addr;
	reg[31:0] dside_ctl_rd_daddr = 0;
	reg dside_ctl_rd_valid = 0;
	reg dside_ctl_rd_done = 0;
	
	reg dside_ctl_rd_done_buf = 0;
	reg dside_ctl_rd_done_buf2 = 0;
	always @(posedge clk) begin
		dside_ctl_rd_done_buf <= dside_ctl_rd_done;
		dside_ctl_rd_done_buf2 <= dside_ctl_rd_done_buf;
	end
	
	wire dside_ctl_wr_en;
	wire[31:0] dside_ctl_wr_addr;
	wire[31:0] dside_ctl_wr_data;
	reg dside_ctl_wr_done = 0;
	
	reg dside_ctl_segfault = 0;
	
	GraftonCPUL1CacheBank dside_bank(
		.clk(clk),
		
		.cpu_addr(dside_cpu_addr),
				
		.wr_en(dside_wr_en),
		.wr_data(dside_wr_data),
		.wr_mask(dside_wr_mask),
		.wr_done(dside_wr_done),
		
		.rd_en(dside_rd_en || dside_ctl_rd_done_buf2),
		.rd_data(dside_rd_data),
		.rd_valid(dside_rd_valid),
		
		.ctl_rd_en(dside_ctl_rd_en),
		.ctl_rd_addr(dside_ctl_rd_addr),
		.ctl_rd_data(drx_buf_data),
		.ctl_rd_daddr(dside_ctl_rd_daddr),
		.ctl_rd_valid(dside_ctl_rd_valid),
		.ctl_rd_done(dside_ctl_rd_done),
				
		.ctl_wr_en(dside_ctl_wr_en), 
		.ctl_wr_addr(dside_ctl_wr_addr),
		.ctl_wr_data(dside_ctl_wr_data),
		.ctl_wr_done(dside_ctl_wr_done),
		.ctl_flush_en(1'b0),			//flushing not supported (yet)
		.ctl_flush_done(),
		
		.ctl_segfault(dside_ctl_segfault)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The MMU

	reg mmu_translate_en = 0;
	reg[31:0] mmu_vaddr = 0;
	wire[31:0] mmu_phyaddr;
	wire[15:0] mmu_nocaddr;
	wire[2:0] mmu_permissions;
	wire mmu_invalid;
	
	GraftonCPUMMU
	#(
		.bootloader_addr(bootloader_addr),
		.bootloader_host(bootloader_host)
	) mmu(
		.clk(clk),
		.translate_en(mmu_translate_en),
		.vaddr(mmu_vaddr),
		.phyaddr(mmu_phyaddr),
		.nocaddr(mmu_nocaddr),
		.permissions(mmu_permissions),
		.invalid(mmu_invalid),
		
		.mmu_wr_en(mmu_wr_en),
		.mmu_wr_page_id(mmu_wr_page_id),
		.mmu_wr_phyaddr(mmu_wr_phyaddr),
		.mmu_wr_nocaddr(mmu_wr_nocaddr),
		.mmu_wr_permissions(mmu_wr_permissions)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transmit buffer for cache flushes
	
	//This is small... can use a LUTRAM because it doesn't contain very much data
	
	reg[31:0] dma_transmit_buf[511:0];
	
	initial begin
		for(i=0; i<512; i=i+1)
			dma_transmit_buf[i] <= 0;
	end
		
	//Address computation
	reg txbuf_wr_en = 0;
	reg[31:0] txbuf_wr_data = 0;
	reg[8:0] txbuf_wr_addr = 0;
	always @(posedge clk) begin	
		txbuf_wr_en <= 0;
		
		//First write? Reset address
		if(!txbuf_wr_en && dside_ctl_wr_en)
			txbuf_wr_addr <= 0;
			
		//Nope, bump it
		else
			txbuf_wr_addr <= txbuf_wr_addr + 8'h1;
			
		//Data
		txbuf_wr_en <= dside_ctl_wr_en;
		txbuf_wr_data <= dside_ctl_wr_data;
				
	end
	
	//Read/write logic
	always @(posedge clk) begin
		if(txbuf_wr_en)
			dma_transmit_buf[txbuf_wr_addr] <= txbuf_wr_data;
		if(dtx_rd)
			dtx_buf_out <= dma_transmit_buf[dtx_raddr];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main cache control state machine
	
	`include "GraftonCPUL1Cache_states_constants.v"
	
	reg[3:0] state = STATE_BOOT;
	
	reg[31:0] pending_dside_rd_addr = 0;
	reg pending_dside_rd = 0;
	reg reading_from_dside = 0;
	
	reg[31:0] pending_iside_rd_addr = 0;
	reg pending_iside_rd = 0;
	reg reading_from_iside = 0;
	
	reg[31:0] pending_dside_wr_addr = 0;
	reg pending_dside_wr = 0;
	reg writing_to_dside = 0;
	
	//Combinatorial inputs to the MMU
	always @(*) begin
		mmu_translate_en <= 0;
		mmu_vaddr <= 0;
		reading_from_iside <= 0;
		reading_from_dside <= 0;
		writing_to_dside <= 0;
	
		if( (state == STATE_IDLE) && !segfault) begin
			
			//D-side bus wins, this may cause an I-side cache miss but that's OK
			if(pending_dside_wr) begin
				mmu_translate_en <= 1;
				mmu_vaddr <= pending_dside_wr_addr;
				writing_to_dside <= 1;
			end
			else if(dside_ctl_wr_en) begin
				mmu_translate_en <= 1;
				mmu_vaddr <= dside_ctl_wr_addr;
				writing_to_dside <= 1;
			end
			
			else if(pending_dside_rd) begin
				mmu_translate_en <= 1;
				mmu_vaddr <= pending_dside_rd_addr;
				reading_from_dside <= 1;
			end
			
			else if(dside_ctl_rd_en) begin
				mmu_translate_en <= 1;
				mmu_vaddr <= dside_ctl_rd_addr;
				reading_from_dside <= 1;
			end
			
			else if(pending_iside_rd) begin
				mmu_translate_en <= 1;
				mmu_vaddr <= pending_iside_rd_addr;
				reading_from_iside <= 1;
			end
			
			else if(iside_ctl_rd_en) begin
				mmu_translate_en <= 1;
				mmu_vaddr <= iside_ctl_rd_addr;
				reading_from_iside <= 1;
			end
			
		end
	end
	
	reg[31:0] mmu_vaddr_buf = 0;
	reg[9:0] drx_buf_addr_buf = 0;
	always @(posedge clk) begin
		
		dtx_en <= 0;
		drx_buf_rd <= 0;
		
		iside_ctl_rd_valid <= 0;
		iside_ctl_rd_done <= 0;
		dside_ctl_rd_valid <= 0;
		dside_ctl_rd_done <= 0;
		dside_ctl_wr_done <= 0;
		
		iside_ctl_segfault <= 0;
		dside_ctl_segfault <= 0;
		
		bootloader_start <= 0;
		
		if(mmu_translate_en)
			mmu_vaddr_buf <= mmu_vaddr;
		
		//Save old read address
		if(drx_buf_rd)
			drx_buf_addr_buf <= drx_buf_addr;
			
		//Save I-side read requests
		if(iside_ctl_rd_en) begin
			pending_iside_rd_addr <= iside_ctl_rd_addr;
			pending_iside_rd <= 1;
		end
		
		//Save D-side read requests
		if(dside_ctl_rd_en) begin
			pending_dside_rd_addr <= dside_ctl_rd_addr;
			pending_dside_rd <= 1;
		end
		
		//Save D-side write requests
		if(dside_ctl_wr_en) begin
			pending_dside_wr_addr <= dside_ctl_wr_addr;
			pending_dside_wr <= 1;
		end
		
		if(debug_clear_segfault)
			segfault <= 0;
		
		//Hang on segfault
		if(segfault) begin
			pending_iside_rd <= 0;
			pending_dside_rd <= 0;
			pending_dside_wr <= 0;
		end
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Boot logic
					
			//Start bootloader as soon as ELF headers are read, then sit back and wait for it to finish
			STATE_BOOT: begin
				if(drx_en)
					bootloader_start <= 1;
				if(bootloader_pc_wr)
					state <= STATE_IDLE;	
			end	//end STATE_BOOT
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for something to happen
			// (MMU control inputs are combinatorial)
			STATE_IDLE: begin
			
				//Initialize DMA settings that never change
				dtx_len <= 4;
			
				if(writing_to_dside) begin
					state <= STATE_MMU_WRITE;
					pending_dside_wr <= 0;
				end
				else if(reading_from_dside) begin
					state <= STATE_MMU_READ;
					pending_dside_rd <= 0;
				end
				else if(reading_from_iside) begin
					state <= STATE_MMU_EXEC;
					pending_iside_rd <= 0;
				end
			
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// I-side read miss handling
			
			//MMU conversion done, issue the DMA read
			STATE_MMU_EXEC: begin
			
				//Set DMA address regardless of whether we actually send it or not to avoid extra conditionals
				dtx_op <= DMA_OP_READ_REQUEST;
				dtx_addr <= mmu_phyaddr;
				dtx_dst_addr <= mmu_nocaddr;
			
				if(!mmu_permissions[0] || mmu_invalid) begin
					segfault <= 1;
					badvaddr <= mmu_vaddr_buf;
					
					iside_ctl_segfault <= 1;
					
					//synthesis translate_off
					$display("[GraftonCPUL1Cache] Segfault on execute");
					//synthesis translate_on
					state <= STATE_IDLE;
				end
				else begin
					dtx_en <= 1;
					state <= STATE_DMA_EXEC;
					
					//synthesis translate_off
					/*
					$display("[GraftonCPUL1Cache] Cache miss on read of address %08x from %04x", 
						mmu_phyaddr, mmu_nocaddr);
					*/
					//synthesis translate_on
				end
			end	//end STATE_MMU_EXEC
			
			STATE_DMA_EXEC: begin
			
				if(dma_op_segfaulted) begin
					segfault <= 1; 
					iside_ctl_segfault <= 1;
					state <= STATE_IDLE;
				end
			
				//Got a response to our read query
				//TODO: Handle incoming DMA messages with wrong dest?
				//Process it!
				if(rx_we && (drx_src_addr == dtx_dst_addr)) begin
					
					//Busy, no new DMA messages allowed for now
					drx_ready <= 0;

					drx_buf_rd <= 1;
					drx_buf_addr <= 0;
					state <= STATE_ISIDE_WB0;
					
				end
				
			end	//end STATE_DMA_EXEC
			
			//Write DMA data back to cache
			STATE_ISIDE_WB0: begin
				drx_buf_rd <= 1;
				drx_buf_addr <= 1;
				state <= STATE_ISIDE_WB1;
				
				iside_ctl_rd_valid <= 1;
				iside_ctl_rd_daddr <= iside_ctl_rd_addr;
			end	//end STATE_ISIDE_WB0
			
			STATE_ISIDE_WB1: begin
			
				//Write back
				iside_ctl_rd_valid <= 1;
				iside_ctl_rd_daddr <= iside_ctl_rd_addr + {drx_buf_addr, 2'b00};
				
				//Fetch next word
				if(drx_buf_addr_buf < 2) begin
					drx_buf_rd <= 1;
					drx_buf_addr <= drx_buf_addr + 9'h1;
					//stay in current state
				end
				else begin
					iside_ctl_rd_done <= 1;
					drx_ready <= 1;
					state <= STATE_IDLE;
				end

			end	//end STATE_ISIDE_WB1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// D-side read miss handling
			
			//MMU conversion done, issue the DMA read
			STATE_MMU_READ: begin
			
				//Set DMA address regardless of whether we actually send it or not to avoid extra conditionals
				dtx_op <= DMA_OP_READ_REQUEST;
				dtx_addr <= mmu_phyaddr;
				dtx_dst_addr <= mmu_nocaddr;
			
				if(!mmu_permissions[2] || mmu_invalid) begin
					segfault <= 1;
					badvaddr <= mmu_vaddr_buf;
					
					dside_ctl_segfault <= 1;
					
					//synthesis translate_off
					$display("[GraftonCPUL1Cache] Segfault on read");
					$display("FAIL");
					$finish;
					//synthesis translate_on
					state <= STATE_IDLE;
				end
				else begin
					dtx_en <= 1;
					state <= STATE_DMA_READ;
					
					dma_op_active <= 1;
					dma_op_addr <= mmu_nocaddr;
					
					//synthesis translate_off
					/*
					$display("[GraftonCPUL1Cache] Dispatching read request to physical address %x:%x",
						mmu_nocaddr, mmu_phyaddr);
					*/
					//synthesis translate_on
				end
			end	//end STATE_MMU_READ
			
			STATE_DMA_READ: begin
				
				if(dma_op_segfaulted) begin
					segfault <= 1; 
					dside_ctl_segfault <= 1;
					state <= STATE_IDLE;
				end
			
				//Got a response to our read query
				//Process it!
				if(drx_en && (drx_src_addr == dtx_dst_addr)) begin
					
					dma_op_active <= 0;
					
					//Busy, no new DMA messages allowed for now
					drx_ready <= 0;
					
					//TODO: Stream the message into the cache
					
					drx_buf_rd <= 1;
					drx_buf_addr <= 0;
					state <= STATE_DSIDE_WB0;
					
				end
			end	//end STATE_DMA_READ
			
			//Write DMA data back to cache
			STATE_DSIDE_WB0: begin
				drx_buf_rd <= 1;
				drx_buf_addr <= 1;
				state <= STATE_DSIDE_WB1;
				
				dside_ctl_rd_valid <= 1;
				dside_ctl_rd_daddr <= dside_ctl_rd_addr;
			end	//end STATE_DSIDE_WB0
			STATE_DSIDE_WB1: begin
			
				//Write back
				dside_ctl_rd_valid <= 1;
				dside_ctl_rd_daddr <= dside_ctl_rd_addr + {drx_buf_addr, 2'b00};
				
				//Fetch next word
				if(drx_buf_addr_buf < 2) begin
					drx_buf_rd <= 1;
					drx_buf_addr <= drx_buf_addr + 9'h1;
					//stay in current state
				end
				else begin
					dside_ctl_rd_done <= 1;
					drx_ready <= 1;
					state <= STATE_IDLE;
				end

			end	//end STATE_DSIDE_WB1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Write / flush handling
			
			STATE_MMU_WRITE: begin

				//Set DMA address regardless of whether we actually send it or not to avoid extra conditionals
				dtx_op <= DMA_OP_WRITE_REQUEST;
				dtx_addr <= mmu_phyaddr;
				dtx_dst_addr <= mmu_nocaddr;

				if(!mmu_permissions[1] || mmu_invalid) begin
					segfault <= 1;
					badvaddr <= mmu_vaddr_buf;
					dside_ctl_segfault <= 1;
					
					//synthesis translate_off
					$display("[GraftonCPUL1Cache] Segfault on write");
					//synthesis translate_on
					state <= STATE_IDLE;
				end
				else begin
					dtx_en <= 1;

					state <= STATE_DMA_WRITE;
					
					dma_op_active <= 1;
					dma_op_addr <= mmu_nocaddr;
					
					//synthesis translate_off
					/*
					$display("[GraftonCPUL1Cache] Dispatching write request to physical address %x:%x (%.2f)",
						mmu_nocaddr, mmu_phyaddr, $time());
					*/
					//synthesis translate_on
				end
				
			end	//end STATE_MMU_WRITE
			
			STATE_DMA_WRITE: begin
			
				pending_dside_wr <= 0;
				
				if(dma_op_segfaulted) begin
					segfault <= 1;
					dside_ctl_segfault <= 1;
					state <= STATE_IDLE;
				end
				
				if(dma_op_cleared) begin
					dma_op_active <= 0;
					dside_ctl_wr_done <= 1;
					state <= STATE_IDLE;
				end
				
			end	//end STATE_DMA_WRITE

		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Profiling stuff
	
	always @(*) begin
		imiss_start		<= iside_ctl_rd_en;
		imiss_done		<= iside_ctl_rd_done;
		dmiss_start		<= dside_ctl_rd_en;
		dmiss_done		<= dside_ctl_rd_done;
	end
	
endmodule

