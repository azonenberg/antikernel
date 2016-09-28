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
	@brief Bootloader for new SARATOGA thread instances
 */
module SaratogaCPUELFLoader(
	clk,
	
	read_pending,
	
	start_en, start_tid, start_nocaddr, start_phyaddr, start_done, start_ok, start_errcode,
	
	mmu_wr_en, mmu_wr_tid, mmu_wr_valid, mmu_wr_perms, mmu_wr_vaddr, mmu_wr_nocaddr, mmu_wr_phyaddr, mmu_wr_done,
	
	signature_buf_inc, signature_buf_wr, signature_buf_wdata, signature_buf_waddr, signature_buf_tid,
	
	pc_wr, pc_tid, pc_addr,
	
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
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	//NoC address of the CPU
	parameter NOC_ADDR			= 16'h0000;
	
	//Code signing key
	parameter HMAC_KEY_0	= 32'h00000000;
	parameter HMAC_KEY_1	= 32'h00000000;
	parameter HMAC_KEY_2	= 32'h00000000;
	parameter HMAC_KEY_3	= 32'h00000000;
	parameter HMAC_KEY_4	= 32'h00000000;
	parameter HMAC_KEY_5	= 32'h00000000;
	parameter HMAC_KEY_6	= 32'h00000000;
	parameter HMAC_KEY_7	= 32'h00000000;
	parameter HMAC_KEY_8	= 32'h00000000;
	parameter HMAC_KEY_9	= 32'h00000000;
	parameter HMAC_KEY_A	= 32'h00000000;
	parameter HMAC_KEY_B	= 32'h00000000;
	parameter HMAC_KEY_C	= 32'h00000000;
	parameter HMAC_KEY_D	= 32'h00000000;
	parameter HMAC_KEY_E	= 32'h00000000;
	parameter HMAC_KEY_F	= 32'h00000000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Main clock
	input wire		clk;
	
	//Held high if a DMA read has been sent, but not come back
	output reg					read_pending		= 0;
	
	//Control bus from RPC subsystem
	input wire					start_en;
	input wire[TID_BITS-1:0]	start_tid;
	input wire[15:0]			start_nocaddr;
	input wire[31:0]			start_phyaddr;
	output reg					start_done 			= 0;
	output reg					start_ok			= 0;
	output reg[7:0]				start_errcode		= 0;
	
	//Control bus to program counters
	output reg					pc_wr				= 0;
	output reg[TID_BITS-1 : 0]	pc_tid				= 0;
	output reg[31:0]			pc_addr				= 0;
	
	//Control bus to MMU
	output reg					mmu_wr_en			= 0;
	output reg[TID_BITS-1:0]	mmu_wr_tid			= 0;
	output reg					mmu_wr_valid		= 0;
	output reg[2:0]				mmu_wr_perms		= 0;
	output reg[31:0]			mmu_wr_vaddr		= 0;
	output reg[15:0]			mmu_wr_nocaddr		= 0;
	output reg[31:0]			mmu_wr_phyaddr		= 0;
	input wire					mmu_wr_done;
	
	//Control bus to signature buffer
	output reg					signature_buf_inc	= 0;
	output reg					signature_buf_wr	= 0;
	output reg[31:0]			signature_buf_wdata	= 0;
	output reg[2:0]				signature_buf_waddr	= 0;
	output reg[TID_BITS-1:0]	signature_buf_tid	= 0;
	
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
	// Register status flags to improve timing
	reg							start_done_adv			= 0;
	reg							start_ok_adv			= 0;
	reg[7:0]					start_errcode_adv		= 0;
	
	always @(posedge clk) begin
		start_done		<= start_done_adv;
		start_ok		<= start_ok_adv;
		start_errcode	<= start_errcode_adv;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register incoming DMA data to improve timing
	
	reg							dma_fab_header_wr_en_ff		= 0;
	reg[1:0]					dma_fab_header_wr_addr_ff	= 0;
	reg[31:0]					dma_fab_header_wr_data_ff	= 0;
	reg							dma_fab_data_wr_en_ff		= 0;
	reg[8:0]					dma_fab_data_wr_addr_ff		= 0;
	reg[31:0]					dma_fab_data_wr_data_ff		= 0;
	reg							dma_fab_rx_inbox_full_ff	= 0;
	
	always @(posedge clk) begin
		dma_fab_header_wr_en_ff		<= dma_fab_header_wr_en;
		dma_fab_header_wr_addr_ff	<= dma_fab_header_wr_addr;
		dma_fab_header_wr_data_ff	<= dma_fab_header_wr_data;
		dma_fab_data_wr_en_ff		<= dma_fab_data_wr_en;
		dma_fab_data_wr_addr_ff		<= dma_fab_data_wr_addr;
		dma_fab_data_wr_data_ff		<= dma_fab_data_wr_data;
		dma_fab_rx_inbox_full_ff	<= dma_fab_rx_inbox_full;
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The HMAC unit
	
	reg			hmac_start_en	= 0;
	reg			hmac_data_en	= 0;
	wire[31:0]	hmac_din;
	wire		hmac_done;
	reg			hmac_finish_en	= 0;
	wire		hmac_dout_valid;
	wire[31:0]	hmac_dout;
	
	HMACSHA256SignatureChecker #(
		.KEY_0(HMAC_KEY_0),
		.KEY_1(HMAC_KEY_1),
		.KEY_2(HMAC_KEY_2),
		.KEY_3(HMAC_KEY_3),
		.KEY_4(HMAC_KEY_4),
		.KEY_5(HMAC_KEY_5),
		.KEY_6(HMAC_KEY_6),
		.KEY_7(HMAC_KEY_7),
		.KEY_8(HMAC_KEY_8),
		.KEY_9(HMAC_KEY_9),
		.KEY_A(HMAC_KEY_A),
		.KEY_B(HMAC_KEY_B),
		.KEY_C(HMAC_KEY_C),
		.KEY_D(HMAC_KEY_D),
		.KEY_E(HMAC_KEY_E),
		.KEY_F(HMAC_KEY_F)
	) hmac (
		.clk(clk),
		.start_en(hmac_start_en),
		.data_en(hmac_data_en),
		.finish_en(hmac_finish_en),
		.din(hmac_din),
		.done(hmac_done),
		.dout_valid(hmac_dout_valid),
		.dout(hmac_dout)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO of data to be hashed
	
	reg			hmac_fifo_wr	= 0;
	reg			hmac_fifo_rd	= 0;
	reg[31:0]	hmac_fifo_din	= 0;
	wire		hmac_fifo_empty;
	wire		hmac_fifo_full;
	
	SingleClockFifo #(
		.WIDTH(32),
		.DEPTH(512),
		.USE_BLOCK(1),
		.OUT_REG(1)
	) hmac_fifo (
		.clk(clk),
		.wr(hmac_fifo_wr),
		.din(hmac_fifo_din),
		.rd(hmac_fifo_rd),
		.dout(hmac_din),
		.overflow(),
		.underflow(),
		.empty(hmac_fifo_empty),
		.full(hmac_fifo_full),
		.rsize(),
		.wsize(),
		.reset(1'b0)
    );
    
    //Register done/empty flags to improve timing
    reg		hmac_fifo_empty_ff	= 0;
    reg		hmac_done_ff		= 0;
    always @(posedge clk) begin
		hmac_done_ff		<= hmac_done;
		hmac_fifo_empty_ff	<= hmac_fifo_empty;
    end
    
    //Pop the fifo into the hmac unit
    reg hmac_busy			= 0;
    always @(posedge clk) begin
    
		hmac_fifo_rd		<= 0;
    
		if(!hmac_busy && !hmac_fifo_empty) begin
			hmac_fifo_rd	<= 1;
			hmac_busy		<= 1;
		end
		
		hmac_data_en		<= hmac_fifo_rd;
		
		if(hmac_done)
			hmac_busy		<= 0;
		
    end
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// HMAC push logic
	
	//The thread context being initialized
	reg[TID_BITS-1:0]	saved_tid	= 0;
	
	reg	signature_buf_first	= 0;
	
	always @(posedge clk) begin
	
		signature_buf_inc	<= 0;
		
		signature_buf_wr	<= hmac_dout_valid;
		signature_buf_wdata	<= hmac_dout;
		
		//Always writing to the saved thread context
		signature_buf_tid	<= saved_tid;
		
		//If we are about to finish a HMAC check, reset the write address
		if(hmac_finish_en)
			signature_buf_first	<= 1;
			
		//If there is data coming out of the HMAC, write to the next address and bump the hash version number
		//This ensures no race conditions since we update both atomically
		if(hmac_dout_valid) begin
			signature_buf_inc	<= 1;
			
			if(signature_buf_first) begin
				signature_buf_first	<= 0;
				signature_buf_waddr	<= 0;
			end
			
			else
				signature_buf_waddr	<= signature_buf_waddr + 3'h1;
		end
		
	end
	
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO holding the expected HMAC signature
	
	reg			signature_fifo_rd	= 0;
	wire[31:0]	signature_fifo_dout;
	
	reg[31:0]	signature_fifo_din	= 0;
	reg			signature_fifo_wr	= 0;
	
	SingleClockFifo #(
		.WIDTH(32),
		.DEPTH(8),
		.USE_BLOCK(0),
		.OUT_REG(1)
	) signature_fifo (
		.clk(clk),
		
		.wr(signature_fifo_wr),
		.din(signature_fifo_din),
		
		.rd(signature_fifo_rd),
		.dout(signature_fifo_dout),
		
		.overflow(),
		.full(),
		.underflow(),
		.empty(),
		.rsize(),
		.wsize(),
		.reset(1'b0)
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO of page mappings to create
	
	//Saved program header fields
	reg[7:0]			ptype			= 0;
	reg[31:0]			poffset			= 0;
	reg[31:0]			pvaddr			= 0;
	reg[31:0]			pfilesz			= 0;
	reg[31:0]			pend			= 0;
	reg[31:0]			coffset			= 0;
	
	reg					map_fifo_wr		= 0;
	reg					map_fifo_rd		= 0;
	wire[62:0]			map_fifo_dout;
	wire				map_fifo_empty;
	
	wire[31:0]			pphyaddr		= saved_phyaddr + poffset;
	
	//Extract fields for the current program header
	wire[20:0]			phdr_pagelen			= map_fifo_dout[62:42] + 21'h1;		//round up, always map one page
	wire[31:0]			phdr_current_phyaddr	= {map_fifo_dout[41:21], 11'h0};
	wire[31:0]			phdr_current_vaddr		= {map_fifo_dout[20:0], 11'h0};
	
	//Current program header being mapped
	reg[20:0]			phdr_current_page	= 0;
	
	//Virtual and physical address of the current page about to get mapped
	wire[31:0]			phdr_map_phyaddr	= phdr_current_phyaddr + {phdr_current_page, 11'h0};
	wire[31:0]			phdr_map_vaddr		= phdr_current_vaddr + {phdr_current_page, 11'h0};
	
	//NoC address is always saved_nocaddr so no need to keep that separately
	//62:42	len in pages
	//41:21	phyaddr
	//20:0	vaddr
	SingleClockFifo #(
		.WIDTH(63),
		.DEPTH(8),
		.USE_BLOCK(0),
		.OUT_REG(1)
	) map_fifo (
		.clk(clk),
		
		.wr(map_fifo_wr),
		.din({pfilesz[31:11], pphyaddr[31:11], pvaddr[31:11]}),
		
		.rd(map_fifo_rd),
		.dout(map_fifo_dout),
		
		.overflow(),
		.full(),
		.underflow(),
		.empty(map_fifo_empty),
		.rsize(),
		.wsize(),
		.reset(1'b0)
    );
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state logic (TODO microcode?)
	
	//Address of the out-of-band management port
	localparam OOB_ADDR = NOC_ADDR;
	
	`include "SaratogaCPUELFLoader_states_constants.v"
	`include "DMARouter_constants.v"
	`include "SaratogaCPUPagePermissions_constants.v"
	`include "SaratogaCPUELFLoader_Ptypes_constants.v"
	`include "SaratogaCPUELFLoader_Errcodes_constants.v"

	reg[4:0]	state		= STATE_IDLE;
	
	//Location of the executable
	reg[31:0]			saved_phyaddr	= 0;
	reg[15:0]			saved_nocaddr	= 0;
	
	wire[15:0]			src_nocaddr		= (NOC_ADDR + MAX_THREADS) + saved_tid;
	
	//Saved header fields
	reg[31:0]			entry_point		= 0;
	reg[15:0]			phoff			= 0;
	reg[7:0]			phnum			= 0;
	reg[7:0]			phindex			= 0;
	
	//base address of the current phdr
	reg[31:0]			phbase			= 0;
	
	//base physical address of program header table
	reg[31:0]			phtbase			= 0;
		
	wire[31:0]			bytes_left_in_phdr	= (pend - coffset);
	wire[31:0]			words_left_in_phdr	= bytes_left_in_phdr[31:2];
	
	reg					signature_is_bad	= 0;
	reg					fail				= 0;
	
	reg					phdr_is_loadable	= 0;
	reg					phdr_is_signature	= 0;
	
	reg[31:0]			words_left_in_phdr_ff	= 0;
	
	always @(posedge clk) begin
	
		dma_fab_tx_en			<= 0;
		dma_fab_rx_done			<= 0;
		dma_fab_header_rd_data	<= 0;
		dma_fab_data_rd_data	<= 0;
		
		start_done_adv			<= 0;
		start_ok_adv			<= 0;
		
		hmac_fifo_wr			<= 0;
		hmac_fifo_din			<= 0;
		
		hmac_start_en			<= 0;
		hmac_finish_en			<= 0;
		
		signature_fifo_rd		<= 0;
		signature_fifo_wr		<= 0;
		
		map_fifo_wr				<= 0;
		map_fifo_rd				<= 0;
		
		//default MMU settings
		mmu_wr_tid				<= saved_tid;
		mmu_wr_valid			<= 1;
		mmu_wr_nocaddr			<= saved_nocaddr;
		mmu_wr_perms			<= PAGE_READ_EXECUTE;
		
		mmu_wr_en				<= 0;
		mmu_wr_vaddr			<= 0;
		mmu_wr_phyaddr			<= 0;
		
		pc_wr					<= 0;
		
		//Register to improve setup performnace
		words_left_in_phdr_ff	<= words_left_in_phdr;
		
		case(state)
		
			//Wait for a new start-thread request to come in
			//TODO: Make sure that if an invalid executable is loaded, all FIFOs are fully flushed before we can
			//accept new commands. 
			STATE_IDLE: begin
						
				//If a start request comes in, reset the HMAC core and prepare to dispatch a read of the first 2KB
				if(start_en) begin
					fail					<= 0;
					hmac_start_en			<= 1;
					saved_phyaddr			<= start_phyaddr;
					saved_nocaddr			<= start_nocaddr;
					saved_tid				<= start_tid;
					state					<= STATE_HMAC_RESET;
					start_errcode_adv		<= BL_NO_ERROR;
				end
			
			end	//end STATE_IDLE
			
			STATE_HMAC_RESET: begin
				if(hmac_done_ff) begin
					dma_fab_tx_en	<= 1;
					state			<= STATE_READ_HEADER;
				end
			end	//end STATE_HMAC_RESET
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// ELF header
			
			//Read the ELF header (first 16 words of the file)
			STATE_READ_HEADER: begin
				
				//Sending
				if(dma_fab_header_rd_en) begin
					
					case(dma_fab_header_rd_addr)
						0: dma_fab_header_rd_data	<= { src_nocaddr, saved_nocaddr };
						1: dma_fab_header_rd_data	<= { DMA_OP_READ_REQUEST, 20'h0, 10'h010 };
						2: dma_fab_header_rd_data	<= saved_phyaddr;
					endcase
					
				end
				
				if(dma_fab_tx_done) begin
					read_pending	<= 1;
					state			<= STATE_HEADER;
				end
				
			end	//end STATE_READ_HEADER
			
			//Process the incoming header
			STATE_HEADER: begin
			
				//Verify we're getting the right data
				//If not, drop the packet
				if(dma_fab_header_wr_en_ff) begin
					
					case(dma_fab_header_wr_addr_ff)
						
						0: begin
							if(dma_fab_header_wr_data_ff != {saved_nocaddr, src_nocaddr})
								state	<= STATE_HEADER_DROP;
						end
						
						1: begin
							if(dma_fab_header_wr_data_ff != {DMA_OP_READ_DATA, 20'h0, 10'h010})
								state	<= STATE_HEADER_DROP;
						end
						
						2: begin
							if(dma_fab_header_wr_data_ff != saved_phyaddr)
								state	<= STATE_HEADER_DROP;
						end
						
					endcase
					
				end
				
				//We have incoming message data!
				//Validate and save it
				if(dma_fab_data_wr_en_ff) begin
					case(dma_fab_data_wr_addr_ff)
						
						//e_ident EI_MAG
						0: begin
							if(dma_fab_data_wr_data_ff != 32'h7f454c46) begin
								start_errcode_adv	<= BL_ERR_EIDENT1;
								fail				<= 1;
							end				
						end
						
						//e_ident EI_CLASS/EI_DATA/EI_VERSION/EI_OSABI
						1: begin
							if(dma_fab_data_wr_data_ff != 32'h01020100) begin
								start_errcode_adv	<= BL_ERR_EIDENT2;
								fail				<= 1;
							end
						end
						
						//2/3 are e_ident padding
						
						//e_type, e_machine
						4: begin
							if(dma_fab_data_wr_data_ff != 32'h00020008) begin
								start_errcode_adv	<= BL_ERR_ETYPE;
								fail				<= 1;
							end
						end
						
						//e_version
						5: begin
							if(dma_fab_data_wr_data_ff != 32'h00000001) begin
								start_errcode_adv	<= BL_ERR_EVER;	//invalid e_version
								fail				<= 1;
							end
						end
						
						//e_entry, save it
						6: begin
							entry_point			<= dma_fab_data_wr_data_ff;
							
							//Add to the list of stuff we're signature-checking
							hmac_fifo_din		<= dma_fab_data_wr_data_ff;
							hmac_fifo_wr		<= 1;
						end
						
						//e_phoff
						7: begin
							phoff				<= dma_fab_data_wr_data_ff[15:0];
							phtbase				<= dma_fab_data_wr_data_ff[15:0] + saved_phyaddr;
						end
						
						//8 is shoff, ignore
						
						//9 is flags, ignore
						
						//10 is ehsize/phentsize
						10: begin
							if(dma_fab_data_wr_data_ff[15:0] != 16'h00000020) begin
								start_errcode_adv	<= BL_ERR_EPHENT;	//invalid e_phentsize
								fail				<= 1;
							end
						end
						
						//e_phnum / e_shentsize
						11: begin
							phnum				<= dma_fab_data_wr_data_ff[23:16];
						end
						
					endcase
					
				end
				
				//Start looking at the beginning of the program header table
				phbase				<= phtbase;
				
				//Start reading the first program header
				if(dma_fab_rx_inbox_full_ff) begin
				
					read_pending		<= 0;
					dma_fab_rx_done		<= 1;
					phindex				<= 0;
					phdr_current_page	<= 0;
				
					if(fail) begin
						start_done_adv		<= 1;
						start_ok_adv		<= 0;
						state				<= STATE_IDLE;
					end
					else begin
						dma_fab_tx_en 		<= 1;
						state				<= STATE_PHDR_READ;
					end
				end
				
			end	//end STATE_HEADER
			
			//Drop a packet we don't want
			STATE_HEADER_DROP: begin
				if(dma_fab_rx_inbox_full_ff) begin
					dma_fab_rx_done		<= 1;
					state				<= STATE_HEADER;
				end
			end	//end STATE_HEADER_DROP
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Program header
			
			//Dispatch the read command for a program header
			//One program header is 0-x
			STATE_PHDR_READ: begin
				
				//Sending
				if(dma_fab_header_rd_en) begin
					
					case(dma_fab_header_rd_addr)
						0: dma_fab_header_rd_data	<= { src_nocaddr, saved_nocaddr };
						1: dma_fab_header_rd_data	<= { DMA_OP_READ_REQUEST, 20'h0, 10'h008 };
						2: dma_fab_header_rd_data	<= phbase;
													//address of program_headers[phindex]
													//program header is 8 32-bit words
					endcase
					
				end
				
				if(dma_fab_tx_done) begin
					read_pending	<= 1;
					state			<= STATE_PHDR_PARSE;
				end
				
			end	//end STATE_PHDR_READ
			
			//Parse an incoming program header
			STATE_PHDR_PARSE: begin
			
				//Verify we're getting the right data
				//If not, drop the packet
				if(dma_fab_header_wr_en_ff) begin
				
					//Default to being loadable but not a signature
					phdr_is_loadable	<= 1;
					phdr_is_signature	<= 0;
					
					case(dma_fab_header_wr_addr_ff)
						
						0: begin
							if(dma_fab_header_wr_data_ff != {saved_nocaddr, src_nocaddr})
								fail	<= 1;
						end
						
						1: begin
							if(dma_fab_header_wr_data_ff != {DMA_OP_READ_DATA, 20'h0, 10'h008})
								fail	<= 1;
						end
						
						2: begin
							if(dma_fab_header_wr_data_ff != phbase)
								fail	<= 1;
						end
						
					endcase
					
				end
				if(fail)
					state	<= STATE_PHDR_DROP;
				
				//We have incoming message data!
				//Validate and save it
				if(dma_fab_data_wr_en_ff) begin
					case(dma_fab_data_wr_addr_ff)
					
						0:	begin
							if(dma_fab_data_wr_data_ff == 32'h70000005) begin
								ptype				<= PT_SIGNATURE;
								phdr_is_signature	<= 1;
							end
							else
								ptype	<= dma_fab_data_wr_data_ff[7:0];
						end
						1:	poffset	<= dma_fab_data_wr_data_ff;
						2:	pvaddr	<= dma_fab_data_wr_data_ff;
						//3 is p_paddr, ignore it
						4:	pfilesz	<= dma_fab_data_wr_data_ff;
						//5 is p_memsz, ignore it
						//6 is p_flags, ignore it						
						//7 is p_align, ignore it
					
					endcase
				end
				
				//Clear loadable flag if conditions aren't met
				if((dma_fab_data_wr_addr_ff == 6) && (ptype != PT_LOAD) || (pfilesz == 0) || (pvaddr == 0))
					phdr_is_loadable	<= 0;
				
				//Start reading the first program header
				if(dma_fab_rx_inbox_full_ff) begin
					dma_fab_rx_done		<= 1;
					read_pending		<= 0;
	
					//Add to list of page mappings
					if(phdr_is_loadable)
						map_fifo_wr		<= 1;
					
					//Crunch the program header if it's loadable or a signature
					if(phdr_is_loadable || phdr_is_signature ) begin
						dma_fab_tx_en	<= 1;
						state			<= STATE_PHDR_RBODY;
						
						//One after the last address in the segment
						pend			<= poffset + pfilesz;
						
						//Current offset in the file
						coffset			<= poffset;
					end
					else
						state		<= STATE_PHDR_NEXT;
				end
				
				//TODO: push the address info into some kind of fifo for memory mapping if we're successful
			
			end	//end STATE_PHDR_PARSE
			
			//Read the program header's body in 2KB chunks
			STATE_PHDR_RBODY: begin
				case(dma_fab_header_rd_addr)
					0: dma_fab_header_rd_data	<= { src_nocaddr, saved_nocaddr };
					1: begin
						dma_fab_header_rd_data	<= { DMA_OP_READ_REQUEST, 20'h0, 10'h000 };
						
						//If we can fit a full 512-word chunk, do it
						if(words_left_in_phdr_ff >= 512)
							dma_fab_header_rd_data[9:0]	<= 10'h200;
							
						//No, read the rest of it
						else
							dma_fab_header_rd_data[9:0]	<= words_left_in_phdr_ff[9:0];
							
					end
					2: dma_fab_header_rd_data	<= saved_phyaddr + coffset;
				endcase				
				
				if(dma_fab_tx_done) begin
					read_pending	<= 1;
					state			<= STATE_PHDR_BODY;
				end
				
			end	//end STATE_PHDR_RBODY
		
			//Incoming program header body data
			STATE_PHDR_BODY: begin
				
				//Verify we're getting the right data
				//If not, drop the packet
				if(dma_fab_header_wr_en_ff) begin
					
					case(dma_fab_header_wr_addr_ff)
						
						0: begin
							if(dma_fab_header_wr_data_ff != {saved_nocaddr, src_nocaddr})
								state	<= STATE_PHDR_BDROP;
						end
						
						1: begin
							//assume length is valid for now
							if(dma_fab_header_wr_data_ff[31:30] != DMA_OP_READ_DATA)
								state	<= STATE_PHDR_BDROP;
						end
						
						2: begin
							if(dma_fab_header_wr_data_ff != (saved_phyaddr + coffset))
								state	<= STATE_PHDR_BDROP;
						end
						
					endcase
					
				end
				
				//Push it into the fifo or signature buffer (unless we're reading the signature)
				if(dma_fab_data_wr_en_ff) begin	
					
					if(ptype == PT_SIGNATURE) begin
						signature_fifo_wr	<= 1;
						signature_fifo_din	<= dma_fab_data_wr_data_ff;
					end
					else begin
						hmac_fifo_wr		<= 1;
						hmac_fifo_din		<= dma_fab_data_wr_data_ff;
					end
					
				end
				
				//Done. Wait for the HMAC to finish if we're a PT_LOAD packet
				if(dma_fab_rx_inbox_full_ff) begin
				
					read_pending		<= 0;
				
					if(ptype == PT_SIGNATURE) begin
						dma_fab_rx_done	<= 1;
						state			<= STATE_PHDR_NEXT;
					end
					else
						state			<= STATE_HMAC_HASHING;
				end
				
			end	//end STATE_PHDR_BODY
			
			//Wait for the HMAC module to finish hashing the current data
			STATE_HMAC_HASHING: begin

				if(hmac_done_ff && hmac_fifo_empty_ff) begin
					
					dma_fab_rx_done	<= 1;
					
					//Stop if this was the last chunk
					if(words_left_in_phdr_ff <= 512)
						state		<= STATE_PHDR_NEXT;
						
					//Nope, go read another chunk
					else begin
						coffset			<= coffset + 32'h800;
						dma_fab_tx_en	<= 1;
						state			<= STATE_PHDR_RBODY;
					end
						
				end
				
			end	//end STATE_HMAC_HASHING
			
			//Go on to the next program header
			STATE_PHDR_NEXT: begin
				
				//Update phbase outside of conditionals to reduce critical path length
				phbase				<= phbase + 6'h20;
			
				if( (phindex + 8'h1) < phnum ) begin
					dma_fab_tx_en		<= 1;
					phindex				<= phindex + 8'h1;
					state				<= STATE_PHDR_READ;
				end
				
				//Nope, we're done
				else begin	
					hmac_finish_en		<= 1;
					signature_fifo_rd	<= 1;
					signature_is_bad	<= 0;
					state				<= STATE_HMAC_FINISH;
				end
			end	//end STATE_PHDR_NEXT
			
			//Drop a packet we don't want
			STATE_PHDR_BDROP: begin
				if(dma_fab_rx_inbox_full_ff) begin
					dma_fab_rx_done		<= 1;
					state				<= STATE_PHDR_BODY;
				end
			end	//end STATE_PHDR_BDROP
			
			//Drop a packet we don't want
			STATE_PHDR_DROP: begin
				fail					<= 0;
			
				if(dma_fab_rx_inbox_full_ff) begin
					dma_fab_rx_done		<= 1;
					dma_fab_tx_en		<= 1;
					//don't change phbase
					state				<= STATE_PHDR_READ;
				end
			end	//end STATE_PHDR_DROP
			
			//Done reading the program headers.
			//Finish computing the HMAC
			STATE_HMAC_FINISH: begin
			
				//New HMAC data is ready
				//Check it against the expected signature
				if(hmac_dout_valid) begin
					
					//Mismatched signature
					//Make a note of this, but don't do anything until the end to prevent timing attacks
					if(signature_fifo_dout != hmac_dout)
						signature_is_bad	<= 1;
					
					//Pop the fifo so we can read the next word
					signature_fifo_rd	<= 1;
					
				end
				
				//Done checking the hash
				if(hmac_done_ff) begin
				
					//If signature was invalid, stop now before changing any state
					if(signature_is_bad) begin
						start_done_adv		<= 1;
						start_ok_adv		<= 0;
						start_errcode_adv	<= BL_ERR_SIGNATURE;	//invalid HMAC signature
						state				<= STATE_IDLE;
					end
					
					//Nope, signature is good.
					//Start pushing state to the MMU etc
					else begin
						map_fifo_rd		<= 1;
						state			<= STATE_MMAP_0;
					end
				
				end

			end	//end STATE_HMAC_FINISH
			
			//Pop another program header from the list of pages we need to map
			STATE_MMAP_0: begin
			
				//Done doing memory mappings, start the thread!
				if(map_fifo_empty) begin					
					pc_wr			<= 1;
					pc_tid			<= saved_tid;
					pc_addr			<= entry_point;
					start_done_adv	<= 1;
					start_ok_adv	<= 1;
					state			<= STATE_IDLE;
				end
				
				//Pop a page (happens in background)
				else
					state		<= STATE_MMAP_1;
			
			end	//end STATE_MMAP_0
			
			//Push the current page to the MMU and bump our position
			STATE_MMAP_1: begin
				mmu_wr_en			<= 1;
				mmu_wr_phyaddr		<= phdr_map_phyaddr;
				mmu_wr_vaddr		<= phdr_map_vaddr;
				phdr_current_page	<= phdr_current_page + 21'h1;
				state				<= STATE_MMAP_2;
			end	//end STATE_MMAP_1
			
			//Wait for the MMU to finish
			STATE_MMAP_2: begin
			
				if(mmu_wr_done) begin
				
					//More pages to map? Go back and do it again
					if(phdr_current_page < phdr_pagelen)
						state		<= STATE_MMAP_1;
						
					//Nope, done mapping this phdr - on to the next
					else begin
						map_fifo_rd		<= 1;
						state			<= STATE_MMAP_0;
					end
				
				end
			
			end	//end STATE_MMAP_2
		
		endcase
		
	end
	
endmodule
