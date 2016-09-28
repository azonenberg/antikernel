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
	@brief Arbiter for DMA requests between L1 cache and bootloader
 */
module SaratogaCPUDMAArbiter(
	clk,
	
	//Status flags
	bootloader_read_pending, cache_read_pending,
	
	//Real DMA bus
	dma_fab_tx_en, dma_fab_tx_done,
	dma_fab_rx_en, dma_fab_rx_done, dma_fab_rx_inbox_full, dma_fab_rx_dst_addr,
	dma_fab_header_wr_en, dma_fab_header_wr_addr, dma_fab_header_wr_data,
	dma_fab_header_rd_en, dma_fab_header_rd_addr, dma_fab_header_rd_data,
	dma_fab_data_wr_en, dma_fab_data_wr_addr, dma_fab_data_wr_data,
	dma_fab_data_rd_en, dma_fab_data_rd_addr, dma_fab_data_rd_data,
	
	//L1 cache interface
	cache_dma_fab_tx_en, cache_dma_fab_tx_done,
	cache_dma_fab_rx_en, cache_dma_fab_rx_done, cache_dma_fab_rx_inbox_full, cache_dma_fab_rx_dst_addr,
	cache_dma_fab_header_wr_en, cache_dma_fab_header_wr_addr, cache_dma_fab_header_wr_data,
	cache_dma_fab_header_rd_en, cache_dma_fab_header_rd_addr, cache_dma_fab_header_rd_data,
	cache_dma_fab_data_wr_en, cache_dma_fab_data_wr_addr, cache_dma_fab_data_wr_data,
	cache_dma_fab_data_rd_en, cache_dma_fab_data_rd_addr, cache_dma_fab_data_rd_data,
	
	//Bootloader interface
	bootloader_dma_fab_tx_en, bootloader_dma_fab_tx_done,
	bootloader_dma_fab_rx_en, bootloader_dma_fab_rx_done, bootloader_dma_fab_rx_inbox_full, bootloader_dma_fab_rx_dst_addr,
	bootloader_dma_fab_header_wr_en, bootloader_dma_fab_header_wr_addr, bootloader_dma_fab_header_wr_data,
	bootloader_dma_fab_header_rd_en, bootloader_dma_fab_header_rd_addr, bootloader_dma_fab_header_rd_data,
	bootloader_dma_fab_data_wr_en, bootloader_dma_fab_data_wr_addr, bootloader_dma_fab_data_wr_data,
	bootloader_dma_fab_data_rd_en, bootloader_dma_fab_data_rd_addr, bootloader_dma_fab_data_rd_data
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire					clk;
	
	input wire					bootloader_read_pending;
	input wire					cache_read_pending;
	
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
	
	//L1 cache interface
	input wire					cache_dma_fab_tx_en;
	output reg					cache_dma_fab_tx_done			= 0;
	output reg					cache_dma_fab_rx_en				= 0;
	input wire					cache_dma_fab_rx_done;
	output reg					cache_dma_fab_rx_inbox_full		= 0;
	output reg[15:0]			cache_dma_fab_rx_dst_addr		= 0;
	output reg					cache_dma_fab_header_wr_en		= 0;
	output reg[1:0]				cache_dma_fab_header_wr_addr	= 0;
	output reg[31:0]			cache_dma_fab_header_wr_data	= 0;
	output reg					cache_dma_fab_header_rd_en		= 0;
	output reg[1:0]				cache_dma_fab_header_rd_addr	= 0;
	input wire[31:0]			cache_dma_fab_header_rd_data;
	output reg					cache_dma_fab_data_wr_en		= 0;
	output reg[8:0]				cache_dma_fab_data_wr_addr		= 0;
	output reg[31:0]			cache_dma_fab_data_wr_data		= 0;
	output reg					cache_dma_fab_data_rd_en		= 0;
	output reg[8:0]				cache_dma_fab_data_rd_addr		= 0;
	input wire[31:0]			cache_dma_fab_data_rd_data;
	
	//Bootloader interface
	input wire					bootloader_dma_fab_tx_en;
	output reg					bootloader_dma_fab_tx_done			= 0;
	output reg					bootloader_dma_fab_rx_en			= 0;
	input wire					bootloader_dma_fab_rx_done;
	output reg					bootloader_dma_fab_rx_inbox_full	= 0;
	output reg[15:0]			bootloader_dma_fab_rx_dst_addr		= 0;
	output reg					bootloader_dma_fab_header_wr_en		= 0;
	output reg[1:0]				bootloader_dma_fab_header_wr_addr	= 0;
	output reg[31:0]			bootloader_dma_fab_header_wr_data	= 0;
	output reg					bootloader_dma_fab_header_rd_en		= 0;
	output reg[1:0]				bootloader_dma_fab_header_rd_addr	= 0;
	input wire[31:0]			bootloader_dma_fab_header_rd_data;
	output reg					bootloader_dma_fab_data_wr_en		= 0;
	output reg[8:0]				bootloader_dma_fab_data_wr_addr		= 0;
	output reg[31:0]			bootloader_dma_fab_data_wr_data		= 0;
	output reg					bootloader_dma_fab_data_rd_en		= 0;
	output reg[8:0]				bootloader_dma_fab_data_rd_addr		= 0;
	input wire[31:0]			bootloader_dma_fab_data_rd_data;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual arbitration logic
	
	reg		bootloader_send_pending	= 0;
	reg		cache_send_pending		= 0;

	reg[1:0]	selected_sender		= 0;
	reg			waiting_for_rx		= 0;
	
	reg			dma_fab_tx_done_ff	= 0;

	always @(posedge clk) begin
	
		dma_fab_tx_en		<= 0;
		dma_fab_tx_done_ff	<= dma_fab_tx_done;
		
		//Keep track of pending sends
		if(bootloader_dma_fab_tx_en)
			bootloader_send_pending	<= 1;
		if(cache_dma_fab_tx_en)
			cache_send_pending	<= 1;
		
		//Start a send if we're idle
		if(selected_sender == 0) begin
	
			//Bootloader has first priority
			if(bootloader_send_pending) begin
				dma_fab_tx_en			<= 1;
				selected_sender			<= 1;
				bootloader_send_pending	<= 0;
			end	
			
			//otherwise cache
			else if(cache_send_pending) begin
				dma_fab_tx_en			<= 1;
				selected_sender			<= 2;
				cache_send_pending		<= 0;
			end	
			
		end
		
		//If the send is done, nobody is sending
		//Don't do this until one cycle after we set tx_done, so node has a chance to set read_pending
		if(dma_fab_tx_done_ff)
			selected_sender				<= 0;
			
		//If either has a pending read, select them
		if(bootloader_read_pending) begin
			selected_sender				<= 1;
			waiting_for_rx				<= 1;
		end
		if(cache_read_pending) begin
			selected_sender				<= 2;
			waiting_for_rx				<= 1;
		end

		//Finish receives
		if(waiting_for_rx) begin
			
			if( (selected_sender == 1) && bootloader_dma_fab_rx_done) begin
				waiting_for_rx			<= 0;
				selected_sender			<= 0;
			end
			
			if( (selected_sender == 2) && cache_dma_fab_rx_done) begin
				waiting_for_rx			<= 0;
				selected_sender			<= 0;
			end
			
		end

	end
	
	/*
		Initial state: Idle
		
		Bootloader sends DMA read:
			state = waiting for bootloader send
			pass stuff to bootloader
		Bootloader read active
			state = waiting for bootloader read
			pass stuff to bootloader
		Read done
			idle
			
		Cache sends DMA packet:
			state = waiting for cache send
			pass stuff to cache
		Cache read active
			state = waiting for cache read
			pass stuff to cache
	 */
	 
	 always @(*) begin
	 
		//Default if nothing is going on
		dma_fab_rx_done			<= 0;
		dma_fab_header_rd_data	<= 0;
		dma_fab_data_rd_data	<= 0;
		
		bootloader_dma_fab_tx_done			<= 0;
		bootloader_dma_fab_rx_en			<= 0;
		bootloader_dma_fab_rx_inbox_full	<= 0;
		bootloader_dma_fab_rx_dst_addr		<= 0;
		bootloader_dma_fab_header_wr_en		<= 0;
		bootloader_dma_fab_header_wr_addr	<= 0;
		bootloader_dma_fab_header_wr_data	<= 0;
		bootloader_dma_fab_header_rd_en		<= 0;
		bootloader_dma_fab_header_rd_addr	<= 0;
		bootloader_dma_fab_data_wr_en		<= 0;
		bootloader_dma_fab_data_wr_addr		<= 0;
		bootloader_dma_fab_data_wr_data		<= 0;
		bootloader_dma_fab_data_rd_en		<= 0;
		bootloader_dma_fab_data_rd_addr		<= 0;
		
		cache_dma_fab_tx_done			<= 0;
		cache_dma_fab_rx_en				<= 0;
		cache_dma_fab_rx_inbox_full		<= 0;
		cache_dma_fab_rx_dst_addr		<= 0;
		cache_dma_fab_header_wr_en		<= 0;
		cache_dma_fab_header_wr_addr	<= 0;
		cache_dma_fab_header_wr_data	<= 0;
		cache_dma_fab_header_rd_en		<= 0;
		cache_dma_fab_header_rd_addr	<= 0;
		cache_dma_fab_data_wr_en		<= 0;
		cache_dma_fab_data_wr_addr		<= 0;
		cache_dma_fab_data_wr_data		<= 0;
		cache_dma_fab_data_rd_en		<= 0;
		cache_dma_fab_data_rd_addr		<= 0;
				
		//Bootloader
		if(selected_sender[0]) begin
			bootloader_dma_fab_tx_done			<= dma_fab_tx_done;
			bootloader_dma_fab_rx_en			<= dma_fab_rx_en;
			dma_fab_rx_done						<= bootloader_dma_fab_rx_done;
			bootloader_dma_fab_rx_inbox_full	<= dma_fab_rx_inbox_full;
			bootloader_dma_fab_rx_dst_addr		<= dma_fab_rx_dst_addr;
			bootloader_dma_fab_header_wr_en		<= dma_fab_header_wr_en;
			bootloader_dma_fab_header_wr_addr	<= dma_fab_header_wr_addr;
			bootloader_dma_fab_header_wr_data	<= dma_fab_header_wr_data;
			bootloader_dma_fab_header_rd_en		<= dma_fab_header_rd_en;
			bootloader_dma_fab_header_rd_addr	<= dma_fab_header_rd_addr;
			dma_fab_header_rd_data				<= bootloader_dma_fab_header_rd_data;
			bootloader_dma_fab_data_wr_en		<= dma_fab_data_wr_en;
			bootloader_dma_fab_data_wr_addr		<= dma_fab_data_wr_addr;
			bootloader_dma_fab_data_wr_data		<= dma_fab_data_wr_data;
			bootloader_dma_fab_data_rd_en		<= dma_fab_data_rd_en;
			bootloader_dma_fab_data_rd_addr		<= dma_fab_data_rd_addr;
			dma_fab_data_rd_data				<= bootloader_dma_fab_data_rd_data;
		end
		
		//Cache
		if(selected_sender[1]) begin
			cache_dma_fab_tx_done			<= dma_fab_tx_done;
			cache_dma_fab_rx_en				<= dma_fab_rx_en;
			dma_fab_rx_done					<= cache_dma_fab_rx_done;
			cache_dma_fab_rx_inbox_full		<= dma_fab_rx_inbox_full;
			cache_dma_fab_rx_dst_addr		<= dma_fab_rx_dst_addr;
			cache_dma_fab_header_wr_en		<= dma_fab_header_wr_en;
			cache_dma_fab_header_wr_addr	<= dma_fab_header_wr_addr;
			cache_dma_fab_header_wr_data	<= dma_fab_header_wr_data;
			cache_dma_fab_header_rd_en		<= dma_fab_header_rd_en;
			cache_dma_fab_header_rd_addr	<= dma_fab_header_rd_addr;
			dma_fab_header_rd_data			<= cache_dma_fab_header_rd_data;
			cache_dma_fab_data_wr_en		<= dma_fab_data_wr_en;
			cache_dma_fab_data_wr_addr		<= dma_fab_data_wr_addr;
			cache_dma_fab_data_wr_data		<= dma_fab_data_wr_data;
			cache_dma_fab_data_rd_en		<= dma_fab_data_rd_en;
			cache_dma_fab_data_rd_addr		<= dma_fab_data_rd_addr;
			dma_fab_data_rd_data			<= cache_dma_fab_data_rd_data;
		end

	 end

endmodule
