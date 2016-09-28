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
	@brief NoC interface to NativeDDR2Controller including resource management
	
	This is a PoC module which may not scale well to larger memory arrays.
	
	The 128MB of available memory is logically divided into 65,536 pages of 2KB each.
	Each page is further divided into 128 128-bit cache lines.
	
	Memory map (page addresses)
		  0 -   63		List of page owner IDs, 8 pages per cache line.
						Each page of ownership data can hold 1k page IDs (2 bytes each)
						For 64k pages of memory, we thus need 64 pages.

						By default all pages >= 128 are unallocated (owner ID 0x0000).
						Page IDs <128  are reserved for internal use by the memory manager and can never be used
						by outside code.
							
		 64 -   127		Free list
						Circular FIFO of free page IDs
		 
		128 - 65535		Available for use by application code
	
	All read/write transactions must:
		Access an integer number of cache lines in order. No partial cache-line writes are permitted.
		Be performed by the owner of the page.
		Be completely contained within one page. No writes crossing page boundaries are permitted, even if both pages
		    are owned by the caller.
		
	@module
	@opcodefile		NetworkedDDR2Controller_opcodes.constants
	
	@rpcfn			RAM_GET_STATUS
	@brief			Gets the current status of the RAM controller. Blocks until init is done.
	
	@rpcfn_ok		RAM_GET_STATUS
	@brief			RAM status retrieved
	@param			ready			d0[16]:dec			Indicates if memory is fully initialized
	@param			freepagecount	d0[15:0]:dec		Number of free RAM pages
	
	@rpcfn			RAM_ALLOCATE
	@brief			Allocates one page of memory.
	
	@rpcfn_ok		RAM_ALLOCATE
	@brief			Memory allocated. The allocated page is zero-filled.
	@param			addr			d1[31:0]:hex		Address of new memory page
	
	@rpcfn_fail		RAM_ALLOCATE
	@brief			Out of memory.
	
	@rpcfn			RAM_CHOWN
	@brief			Change ownership of a page of RAM. The caller loses all rights to the page.
	@param			addr			d1[31:0]:hex		Address of page to chown
	@param			new_owner		d2[15:0]:nocaddr	New owner of page
	
	@rpcfn_ok		RAM_CHOWN
	@brief			Ownership records updated.
	
	@rpcfn_fail		RAM_CHOWN
	@brief			Access denied. The caller probably didn't own the page.
	
	@rpcfn			RAM_FREE
	@brief			Free a page of RAM. The caller loses all rights to the page.
	@param			addr			d1[31:0]:hex		Address of page to free
	
	@rpcfn_ok		RAM_FREE
	@brief			Memory freed.
	
	@rpcfn_fail		RAM_FREE
	@brief			Access denied. The caller probably didn't own the page.
	
	@rpcint			RAM_WRITE_DONE
	@brief			Write committed.
	@param			len				d0[15:0]:dec		Length of the written data
	@param			addr			d1[31:0]:hex		Address of written data
	
	@rpcint			RAM_OP_FAILED
	@brief			Access denied.
			
	TODO:
		-------------------------------------------------------
		RAM_FREE_ALL		Free all pages.
		-------------------------------------------------------
			Parameters:		None
			Returns:		No response
			Frees all pages owned by the caller. This operation is slow and should be used rarely, for example
			during termination of a process.
 */
module NetworkedDDR2Controller(
	
	//Clocks
	clk, clk_ddr_p, clk_ddr_n,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//DDR2 interface
	ddr2_ras_n, ddr2_cas_n, ddr2_udqs_p, ddr2_udqs_n, ddr2_ldqs_p, ddr2_ldqs_n,
	ddr2_udm, ddr2_ldm, ddr2_we_n,
	ddr2_ck_p, ddr2_ck_n, ddr2_cke, ddr2_odt,
	ddr2_ba, ddr2_addr,
	ddr2_dq
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;
	input wire clk_ddr_p;
	input wire clk_ddr_n;
	
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
	
	//DDR2 interface
	output wire 	ddr2_ras_n;
	output wire 	ddr2_cas_n;
	output wire 	ddr2_we_n;
	output wire[2:0] ddr2_ba;
	inout wire 		ddr2_udqs_p;
	inout wire 		ddr2_udqs_n;
	inout wire 		ddr2_ldqs_p;
	inout wire 		ddr2_ldqs_n;
	output wire 	ddr2_udm;
	output wire 	ddr2_ldm;
	output wire		ddr2_ck_p;
	output wire		ddr2_ck_n;
	output wire  	ddr2_cke;
	output wire 	ddr2_odt;
	//cs_n is hard-wired on the Atlys
	output wire[12:0] ddr2_addr;
	inout wire[15:0] ddr2_dq;

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
	wire dtx_busy;
	reg[15:0] dtx_dst_addr = 0;
	reg[1:0] dtx_op = 0;
	reg[9:0] dtx_len = 0;
	reg[31:0] dtx_addr = 0;
	reg dtx_en = 0;
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
		
	//The page ID of the current address
	//Bottom 11 bits are the address within the page
	//31:27 and 3:0 must always be zero
	wire[15:0] drx_page_id = drx_addr[26:11];
	wire[31:0] drx_end_addr = drx_addr + drx_len;
	wire[15:0] drx_end_page_id = drx_end_addr[26:11];
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//DMA transmit buffer
	
	//The actual memory
	reg[31:0] dtx_buffer[511:0];
	integer j;
	initial begin
		for(j=0; j<512; j = j+1)
			dtx_buffer[j] <= 0;
	end
	
	//Reads
	always @(posedge clk) begin
		if(dtx_rd)
			dtx_buf_out <= dtx_buffer[dtx_raddr];
	end
	
	//Writes
	reg dtx_buf_we = 0;
	reg[9:0] dtx_waddr = 0;
	reg[31:0] dtx_wdata = 0;
	always @(posedge clk) begin
		if(dtx_buf_we)
			dtx_buffer[dtx_waddr[8:0]] <= dtx_wdata;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual RAM controller
	
	//Note that the fabric interface on the controller is synchronous to the rising edge of clk_ddr_p.
	//Guaranteed to be faster than clk_noc but not necessarily by a specific multiplier.
	
	//Fabric interface
	//Flags are in clk domain, data crosses from clk to clk_ddr_p
	reg wr_en = 0;
	(* REGISTER_BALANCING = "yes" *) reg[127:0] wr_data = 0;
	wire calib_done_sync;
	reg[31:0] addr = 0;
	wire done_sync;
	reg post_status = 0;
	
	//Flags are in clk domain, data crosses from clk_ddr_p to clk
	reg rd_en = 0;
	wire[127:0] rd_data;
	wire calib_done;
	
	//Pipeline all read/write data by one cycle to improve setup times.
	//Addresses and write data are set once and left until the read/write cycle completes.
	reg[31:0] addr_buf = 0;
	reg[127:0] wr_data_buf = 0;
	always @(posedge clk) begin
		addr_buf <= addr;
		wr_data_buf <= wr_data;
	end
	
	//Status flags in clk_ddr_p domain before/after synchronizers
	wire done;
	wire wr_en_sync;
	wire rd_en_sync;
	
	//Buffer output by one cycle to improve setup times
	reg[127:0] rd_data_buf = 0;
	reg done_sync_buf = 0;
	reg done_sync_buf2 = 0;
	always @(posedge clk) begin
		rd_data_buf <= rd_data;
		done_sync_buf <= done_sync;
		done_sync_buf2 <= done_sync_buf;
	end
	
	NativeDDR2Controller controller(
		
		//Clocks
		.clk_p(clk_ddr_p),
		.clk_n(clk_ddr_n),
		
		//Fabric interface (all in clk_ddr_p domain)
		.addr(addr_buf),
		.done(done),
		.wr_en(wr_en_sync),
		.wr_data(wr_data_buf),
		.rd_en(rd_en_sync),
		.rd_data(rd_data),
		.calib_done(calib_done),
		
		//DDR2 interface
		.ddr2_ras_n(ddr2_ras_n),
		.ddr2_cas_n(ddr2_cas_n),
		.ddr2_udqs_p(ddr2_udqs_p),
		.ddr2_udqs_n(ddr2_udqs_n),
		.ddr2_ldqs_p(ddr2_ldqs_p),
		.ddr2_ldqs_n(ddr2_ldqs_n),
		.ddr2_udm(ddr2_udm),
		.ddr2_ldm(ddr2_ldm),
		.ddr2_we_n(ddr2_we_n),
		.ddr2_ck_p(ddr2_ck_p),
		.ddr2_ck_n(ddr2_ck_n),
		.ddr2_cke(ddr2_cke),
		.ddr2_odt(ddr2_odt),
		.ddr2_ba(ddr2_ba),
		.ddr2_addr(ddr2_addr),
		.ddr2_dq(ddr2_dq)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock domain crossing for status flags
	
	ThreeStageSynchronizer sync_calib_done(.clk_in(clk_ddr_p), .din(calib_done), .clk_out(clk),	.dout(calib_done_sync));
	
	wire wr_done_sync;
	wire rd_done_sync;
	assign done_sync = wr_done_sync || rd_done_sync;
	HandshakeSynchronizer sync_wr_en
		(.clk_a(clk),		.en_a(wr_en),      .ack_a(wr_done_sync), .busy_a(),
		 .clk_b(clk_ddr_p), .en_b(wr_en_sync), .ack_b(done));
	
	HandshakeSynchronizer sync_rd_en
		(.clk_a(clk),		.en_a(rd_en),      .ack_a(rd_done_sync), .busy_a(),
		 .clk_b(clk_ddr_p), .en_b(rd_en_sync), .ack_b(done));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Ownership cache
	
	/*
		The raw ownership record in DRAM is a 64k x 16 array mapping page IDs to owner IDs.
		
		Ownership cache is four block RAMs: 128 bits wide x 512 rows.
		
		Each cache line stores eight page IDs. The cache can store 8*512 = 4k page IDs or 1/16 of the total
		ownership table. The cache is direct mapped since it's so large compared to the total ownership table.
		
		The tag only needs to be 4 bits, plus a valid bit in the MSB.
		
		Address breakdown:
			15  :  12 = tag
			11  :   3 = row
			 2  :   0 = col
			 
		Cache line breakdown:
			132       = valid bit
			131 : 128 = tag
			127 :   0 = data
	 */
	 
	 //The actual cache memory block
	 reg[132:0] ownership_cache[511:0];
	 	
	//Initialize cache to empty
	initial begin
		for(j=0; j<512; j = j+1)
			ownership_cache[j] <= 0;
	end
	
	//Cache addresses
	reg[15:0] ownership_cache_in_pageid = 0;	//Page ID being searched for / written to
	
	//Reads
	reg ownership_cache_rd_en = 0;
	reg[132:0] ownership_cache_out_raw = 0;
	wire[127:0] ownership_cache_data_out 	= ownership_cache_out_raw[127:0];
	wire[3:0] ownership_cache_tag_out 		= ownership_cache_out_raw[131:128];
	wire ownership_cache_line_valid			= ownership_cache_out_raw[132];
	wire[8:0] ownership_cache_addr 			= ownership_cache_in_pageid[11:3];
	
	always @(posedge clk) begin
		if(ownership_cache_rd_en)
			ownership_cache_out_raw <= ownership_cache[ownership_cache_addr];
	end
	
	//Writes
	reg ownership_cache_wr_en = 0;
	reg[127:0] ownership_cache_in_row = 0;		//Cache line being written

	always @(posedge clk) begin
		if(ownership_cache_wr_en) begin
			ownership_cache[ownership_cache_addr] <=
				{
					1'b1,								//valid bit
					ownership_cache_in_pageid[15:12],	//tag
					ownership_cache_in_row				//data
				};
		end
	end
	
	//Mux for output data
	reg[15:0] ownership_cache_out_candidate_owner_raw = 0;
	reg chown_page_current_owner_match = 0;
	reg drx_src_addr_match = 0;
	always @(posedge clk) begin
		chown_page_current_owner_match <= (chown_page_current_owner == ownership_cache_out_candidate_owner_raw);
		drx_src_addr_match <= (drx_src_addr == ownership_cache_out_candidate_owner_raw);
	end
	always @(*) begin
		ownership_cache_out_candidate_owner_raw <= 0;
		case(ownership_cache_in_pageid[2:0])
			0: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[127:112];
			1: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[111:96]; 
			2: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[95:80];
			3: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[79:64];
			4: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[63:48];
			5: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[47:32];
			6: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[31:16];
			7: ownership_cache_out_candidate_owner_raw <= ownership_cache_data_out[15:0];
		endcase
	end
	
	//Hit checking
	wire ownership_cache_rd_hit;
	assign ownership_cache_rd_hit = 
		ownership_cache_line_valid &&
		(ownership_cache_tag_out == ownership_cache_in_pageid[15:12]);		//Tag match
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Free list and cache
	
	/**
		The free list is a circular FIFO consisting of 64 pages (64 to 127) storing eight page IDs per row.
		
		Since the first 128 pages (0 to 127) are used internally for the ownership cache and free list, the entire list
		can never get used. A maximum of 65408 (0xff80) pages can be allocated at a time. As a result, the start and end
		pointers can never be on the same cache line as each other and the FIFO can never actually be full.
		
		Since we can only read and write entire cache lines, we need buffers for the beginning and end.
		
		Page 128 is the first actual data page.
	 */
	
	//Pointers to individual free-list slots.
	//First 13 bits are the cache line index, last 3 are the column within the cache line.
	reg[15:0] free_list_start_ptr = 16'h0010;		//Address to pop the next alloc from
	reg[15:0] free_list_end_ptr   = 16'hff80;		//Address to push the next free to
	
	//Friendly names for low/high sections of pointers
	wire[2:0] free_list_start_ptr_lo  = free_list_start_ptr[2:0];
	wire[12:0] free_list_start_ptr_hi = free_list_start_ptr[15:3];
	wire[2:0] free_list_end_ptr_lo    = free_list_end_ptr[2:0];
	wire[12:0] free_list_end_ptr_hi   = free_list_end_ptr[15:3];
	
	//Cached free-list lines
	//free_list_x_ptr_lo always points somewhere within these blocks.
	//When we pop from the last column in free_list_start_cache, read the next one.
	//When we push to the last column in free_list_end_cache, flush it to RAM.
	reg[15:0] free_list_start_cache[7:0];
	reg[15:0] free_list_end_cache[7:0];
	initial begin
		free_list_start_cache[0] <= 16'h0080;
		free_list_start_cache[1] <= 16'h0081;
		free_list_start_cache[2] <= 16'h0082;
		free_list_start_cache[3] <= 16'h0083;
		free_list_start_cache[4] <= 16'h0084;
		free_list_start_cache[5] <= 16'h0085;
		free_list_start_cache[6] <= 16'h0086;
		free_list_start_cache[7] <= 16'h0087;
		
		free_list_end_cache[0] <= 16'h0000;
		free_list_end_cache[1] <= 16'h0000;
		free_list_end_cache[2] <= 16'h0000;
		free_list_end_cache[3] <= 16'h0000;
		free_list_end_cache[4] <= 16'h0000;
		free_list_end_cache[5] <= 16'h0000;
		free_list_end_cache[6] <= 16'h0000;
		free_list_end_cache[7] <= 16'h0000;
	end
	
	//Number of free pages in memory
	reg[15:0] free_page_count = 16'hff80;			//Number of free pages
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "NetworkedDDR2Controller_opcodes_constants.v"
	`include "NetworkedDDR2Controller_state_constants.v"
	
	reg[4:0] state = STATE_BOOT_0;
	reg[4:0] state_next = STATE_IDLE;
	reg[4:0] state_own_hit = STATE_IDLE;

	//set if a message arrived while we were busy
	reg dma_message_pending = 0;
	
	//Index used for initializing free list during boot, not used elsewhere
	reg[15:0] freelist_base = 0;
	
	//Parameters for chown
	reg chown_request_external = 0;					//Asserted if the chown request was an external function call.
													//De-asserted if the chown request was internal (alloc/free).
	reg[15:0] chown_page_current_owner = 0;			//The node requesting the chown (should be current owner but check)
	reg[15:0] chown_page_new_owner = 0;				//The new owner of the page
	
	//Counters for boot logic
	reg[31:0] boot_addr = 0;
	(* MAX_FANOUT = "reduce" *) reg[2:0] ram_init_step = 0;
	
	//Set for the first cycle of a free-wipe operation
	reg free_wipe_start = 0;
	
	//ID of the next free page
	reg[15:0] next_free_page = 16'h0080;
	
	//Indicates if we have any free memory
	reg has_free_memory = 1;
	
	reg rpc_tx_busy = 0;
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		wr_en <= 0;
		rd_en <= 0;
		drx_buf_rd <= 0;
		dtx_en <= 0;
		dtx_buf_we <= 0;
		
		ownership_cache_rd_en <= 0;
		ownership_cache_wr_en <= 0;
		
		//Save the address of the page which we would allocate if we got a RAM_ALLOCATE next cycle
		next_free_page <= free_list_start_cache[free_list_start_ptr_lo];
		
		//When a message comes in and we're busy, make a note of it
		if(drx_en) begin
			dma_message_pending <= 1;
			drx_ready <= 0;
		end
		
		if(rpc_fab_tx_en)
			rpc_tx_busy <= 1;
		if(rpc_fab_tx_done)
			rpc_tx_busy <= 0;
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Nothing to do

			STATE_IDLE: begin
				
				//If a transmit is in progress, wait
				if(rpc_fab_tx_en || rpc_tx_busy) begin
				end				
				
				//See if any RPC commands are here
				else if(rpc_fab_inbox_full) begin
					
					//Prepare to respond to whatever we got
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
					
					case(rpc_fab_rx_type)
						
						//Ignore
						RPC_TYPE_RETURN_FAIL: begin
							rpc_fab_rx_done <= 1;
						end
						
						//Ignore
						RPC_TYPE_RETURN_SUCCESS: begin
							rpc_fab_rx_done <= 1;
						end
						
						//Remote procedure call - deal with it
						RPC_TYPE_CALL: begin
							case(rpc_fab_rx_callnum)
								
								//Get RAM status
								RAM_GET_STATUS: begin
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_d0 <= {4'b0, calib_done_sync, free_page_count};
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
								end
								
								//Allocate a single page of RAM.
								//Memory is guaranteed to be zero-filled.
								RAM_ALLOCATE: begin
									
									//Out of memory? Return error
									if(!has_free_memory) begin
										rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
										rpc_fab_tx_d0 <= 0;
										rpc_fab_tx_d1 <= 0;
										rpc_fab_tx_d2 <= 0;
										rpc_fab_tx_en <= 1;
										
										rpc_fab_rx_done <= 1;
									end
									
									//Allocate a new page
									else begin
																	
										/*
											Give out the pointer immediately to hide latency.
										
											Note that not all data structures related to the page are initialized yet,
											but all calls to the page will block anyway until the allocation is done.
											
											free_list_start_page is the page ID.
											Shift left by 11 bits (multiply by 2048) to get the starting address of the
											page.
										 */
										rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
										rpc_fab_tx_d0 <= 0;
										rpc_fab_tx_d1 <= {next_free_page, 11'h0};
										rpc_fab_tx_d2 <= 0;
										rpc_fab_tx_en <= 1;
										rpc_fab_rx_done <= 1;
										
										//Update FIFO pointers
										free_list_start_ptr <= free_list_start_ptr + 16'h1;
										free_page_count <= free_page_count - 16'h1;
										if(free_page_count == 1)
											has_free_memory <= 0;
										
										//Prepare to set up new ownership records
										ownership_cache_rd_en <= 1;
										ownership_cache_in_pageid <= next_free_page;
										chown_page_current_owner <= NOC_ADDR;
										chown_page_new_owner <= rpc_fab_rx_src_addr;
										chown_request_external <= 0;

										//If we just allocated the last row in the free-list cache, load a new row
										//into the cache and update permissions records after.
										if(free_list_start_ptr_lo == 3'h7) begin
											addr <= 32'h00020000 + {free_list_start_ptr_hi, 4'h0};
											rd_en <= 1;
											state_next <= STATE_OWNLOOKUP_0;
											state_own_hit <= STATE_CHOWN_0;
											state <= STATE_FREELIST_LOAD;
										end
										
										//Otherwise, update permissions immediately.
										else begin
											state <= STATE_OWNLOOKUP_0;
											state_own_hit <= STATE_CHOWN_0;
										end
										
									end
								end	//end RAM_ALLOCATE
								
								//Change ownership of a single page of RAM
								RAM_CHOWN: begin
									
									//Look up permissions on the page
									ownership_cache_in_pageid <= rpc_fab_rx_d1[26:11];
									ownership_cache_rd_en <= 1;
									state <= STATE_OWNLOOKUP_0;
									
									//When we're done with the permissions lookup, change ownership if all went OK
									chown_page_current_owner <= rpc_fab_rx_src_addr;
									chown_page_new_owner <= rpc_fab_rx_d2[15:0];
									chown_request_external <= 1;
									state_own_hit <= STATE_CHOWN_0;
									
								end	//end RAM_CHOWN
								
								//Free a single page of RAM.
								RAM_FREE: begin
									
									//As usual, start by looking up permissions
									ownership_cache_in_pageid <= rpc_fab_rx_d1[26:11];
									ownership_cache_rd_en <= 1;
									state <= STATE_OWNLOOKUP_0;
									
									//When we're done with the permissions lookup, do the free-list maintenance
									state_own_hit <= STATE_FREE_0;
									
									//Prepare for the chown operation at the end, but don't do it yet
									chown_page_current_owner <= rpc_fab_rx_src_addr;
									chown_page_new_owner <= NOC_ADDR;
									chown_request_external <= 1;
									
								end
								
								/*
								//TODO
								RAM_FREE_ALL: begin
								end
								*/
								
								//Not implemented? Report failure right away
								default: begin								
									rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
								end
								
							endcase
						end
					endcase
					
				end	//end check for rpc messages
				
				//See if any DMA commands are here
				else if(drx_en || dma_message_pending) begin
					dma_message_pending <= 0;
					
					case(drx_op)
						DMA_OP_WRITE_REQUEST: begin
							
							//Writes to memory cannot cross page boundaries.
							//While we're at it, verify the address is sane
							//and the length is a multiple of 4 words (one cache line)
							if( (drx_page_id != drx_end_page_id) ||
								(drx_addr[31:27] != 0) ||
								(drx_addr[3:0] != 0) ||
								(drx_len[1:0] != 0)
								) begin
								
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= RAM_OP_FAILED;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								
								drx_ready <= 1;
								
								state <= STATE_IDLE;
								
							end
							
							//Valid write request
							//Need to authenticate it!
							else begin
								ownership_cache_rd_en <= 1;
								ownership_cache_in_pageid <= drx_page_id;
								state <= STATE_OWNLOOKUP_0;
								state_own_hit <= STATE_WRITE_0;
								
								//Get ready to send "write done" interrupt if everything worked out
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= RAM_WRITE_DONE;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;

								rpc_fab_rx_done <= 1;
								
							end
							
						end	//end DMA_OP_WRITE_REQUEST
						
						DMA_OP_READ_REQUEST: begin
							
							//Reads from memory cannot cross page boundaries.
							//While we're at it, verify the address is sane
							//and the length is a multiple of 4 words (one cache line)
							if( (drx_page_id != drx_end_page_id) ||
								(drx_addr[31:27] != 0) ||
								(drx_addr[3:0] != 0) ||
								(drx_len[1:0] != 0)
								) begin
								
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= RAM_OP_FAILED;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								
								drx_ready <= 1;
								
								state <= STATE_IDLE;
								
							end
							
							//Valid read request
							//Need to authenticate it!
							else begin
								ownership_cache_rd_en <= 1;
								ownership_cache_in_pageid <= drx_page_id;
								state <= STATE_OWNLOOKUP_0;
								state_own_hit <= STATE_READ_0;
								
								//Save DMA parameters for future use
								dtx_addr <= drx_addr;
								dtx_len <= drx_len;
								dtx_dst_addr <= drx_src_addr;
								dtx_op <= DMA_OP_READ_DATA;
								
								//Prepare to send "failed" interrupt if necessary
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= RAM_OP_FAILED;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;
							end
							
						end	//end DMA_OP_READ_REQUEST
						
						//ignore other stuff
						default: begin

							rpc_fab_tx_dst_addr <= drx_src_addr;
							rpc_fab_tx_callnum <= RAM_OP_FAILED;
							rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
							rpc_fab_tx_d0 <= drx_len;
							rpc_fab_tx_d1 <= drx_addr;
							rpc_fab_tx_d2 <= 0;
							rpc_fab_tx_en <= 1;
							
							drx_ready <= 1;
							
							state <= STATE_IDLE;
							
						end
						
					endcase
					
				end	//end check for dma messages
				
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Free-list cache maintenance
			
			//Load the free list cache and return to state_next
			STATE_FREELIST_LOAD: begin
				if(done_sync_buf2) begin
					
					free_list_start_cache[0] <= rd_data_buf[127:112];
					free_list_start_cache[1] <= rd_data_buf[111:96];
					free_list_start_cache[2] <= rd_data_buf[95:80];
					free_list_start_cache[3] <= rd_data_buf[79:64];
					free_list_start_cache[4] <= rd_data_buf[63:48];
					free_list_start_cache[5] <= rd_data_buf[47:32];
					free_list_start_cache[6] <= rd_data_buf[31:16];
					free_list_start_cache[7] <= rd_data_buf[15:0];
					
					state <= state_next;
				end
			end	//end STATE_FREELIST_LOAD
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Ownership cache lookups
			
			//1-cycle delay for cache read to complete
			//Must begin reading cache line before going here
			STATE_OWNLOOKUP_0: begin
				state <= STATE_OWNLOOKUP_1;
			end	//end STATE_OWNLOOKUP_0
			
			STATE_OWNLOOKUP_1: begin
				
				//Cache lookup complete. If it's a hit, we're done
				if(ownership_cache_rd_hit)
					state <= state_own_hit;
				
				//Not in the cache at all... need to hit up DRAM.
				else begin

					//Write back the old cache line if it's valid
					if(ownership_cache_line_valid) begin
						addr <= {ownership_cache_tag_out, ownership_cache_in_pageid[11:3], 4'b0};
						wr_data <= ownership_cache_data_out;
						wr_en <= 1;
						state <= STATE_OWNLOOKUP_WRITEBACK;
					end
				
					//Old cache line is not valid, just flush it
					else begin
						addr <= {ownership_cache_in_pageid[15:3], 4'b0};
						rd_en <= 1;
						state <= STATE_OWNLOOKUP_2;
					end
				end
				
			end	//end STATE_OWNLOOKUP_3
			
			//Wait for changed data to be written back to the cache
			//then read the correct value
			STATE_OWNLOOKUP_WRITEBACK: begin
				if(done_sync_buf2) begin
					addr <= {ownership_cache_in_pageid[15:3], 4'b0};
					rd_en <= 1;
					state <= STATE_OWNLOOKUP_2;
				end
			end	//end STATE_OWNLOOKUP_WRITEBACK
			
			//When data comes back from DRAM, write to the cache line
			STATE_OWNLOOKUP_2: begin
				if(done_sync_buf2) begin
					ownership_cache_wr_en <= 1;
					ownership_cache_in_row <= rd_data_buf;					//Copy read data
					state <= STATE_OWNLOOKUP_3;
				end
			end	//end STATE_OWNLOOKUP_2
			
			//Data from DRAM is now in cache, go back and read it
			STATE_OWNLOOKUP_3: begin
				state <= STATE_OWNLOOKUP_4;
			end	//end STATE_OWNLOOKUP_3
			
			STATE_OWNLOOKUP_4: begin
				state <= STATE_OWNLOOKUP_0;
				ownership_cache_rd_en <= 1;
			end	//end STATE_OWNLOOKUP_4
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Ownership record maintenance
			
			/*
				Verify that page chown_page_id is owned by chown_page_current_owner
				If mismatch, security violation... ignore the request
				If match, change new owner to chown_page_new_owner
				
				Returns to STATE_IDLE
			 */
			
			//We have the requested cache line, look it up
			STATE_CHOWN_0: begin
			
				rpc_fab_tx_d0 <= 0;
				rpc_fab_tx_d1 <= 0;
				rpc_fab_tx_d2 <= 0;
				
				//Default to failure unless we succeed
				rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
			
				//Owned by someone else?
				//Security violation, don't change owner.
				if(!chown_page_current_owner_match) begin
				
					//Send back "failed" status if this was a chown request rather than an allocation
					if(chown_request_external) begin						
						rpc_fab_tx_en <= 1;
						rpc_fab_rx_done <= 1;
					end
				
					state <= STATE_IDLE;
				end
				
				//Owner is good!
				//Writeback time!
				else
					state <= STATE_CHOWN_1;
			end	//end STATE_CHOWN_0

			STATE_CHOWN_1: begin
			
				ownership_cache_wr_en <= 1;
				ownership_cache_in_row <= ownership_cache_data_out;
				case(ownership_cache_in_pageid[2:0])
					0: ownership_cache_in_row[127:112] <= chown_page_new_owner;
					1: ownership_cache_in_row[111:96] <= chown_page_new_owner;
					2: ownership_cache_in_row[95:80] <= chown_page_new_owner;
					3: ownership_cache_in_row[79:64] <= chown_page_new_owner;
					4: ownership_cache_in_row[63:48] <= chown_page_new_owner;
					5: ownership_cache_in_row[47:32] <= chown_page_new_owner;
					6: ownership_cache_in_row[31:16] <= chown_page_new_owner;
					7: ownership_cache_in_row[15:0] <= chown_page_new_owner;
				endcase
				
				//Send back "OK" status if this was a chown request rather than an allocation
				if(chown_request_external) begin
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
					rpc_fab_tx_en <= 1;
					rpc_fab_rx_done <= 1;
				end
				
				state <= STATE_IDLE;
				
			end	//end STATE_CHOWN_1				
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Write processing
			
			STATE_WRITE_0: begin
			
				//Not owned by the sender? Security violation, ignore the request
				if(!drx_src_addr_match) begin
				
					rpc_fab_tx_dst_addr <= drx_src_addr;
					rpc_fab_tx_callnum <= RAM_OP_FAILED;
					rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_d0 <= drx_len;
					rpc_fab_tx_d1 <= drx_addr;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					
					drx_ready <= 1;
					state <= STATE_IDLE;
				end
				
				//Valid request.
				//Start processing it.
				else begin
									
					//save DRAM address for later use
					addr <= drx_addr;
					
					drx_buf_addr <= 0;
					drx_buf_rd <= 1;
					state <= STATE_WRITE_1;
					
				end
			
			end	//end STATE_WRITE_0
			
			STATE_WRITE_1: begin
				//First data block is being read
				//Start reading the second
				drx_buf_addr <= drx_buf_addr + 10'h1;
				drx_buf_rd <= 1;
				state <= STATE_WRITE_2;
			end	//end STATE_WRITE_1
			
			STATE_WRITE_2: begin
				//First block ready
				//Second in progress
				//Start the third
				wr_data[127:96] <= drx_buf_data;
				drx_buf_addr <= drx_buf_addr + 10'h1;
				drx_buf_rd <= 1;
				state <= STATE_WRITE_3;
			end	//end STATE_WRITE_2
			
			STATE_WRITE_3: begin
				//Second block ready
				//Third in progress
				//Start the fourth
				wr_data[95:64] <= drx_buf_data;
				drx_buf_addr <= drx_buf_addr + 10'h1;
				drx_buf_rd <= 1;
				state <= STATE_WRITE_4;
			end	//end STATE_WRITE_3
			
			STATE_WRITE_4: begin
				//Third block ready
				//Fourth in progress
				wr_data[63:32] <= drx_buf_data;
				state <= STATE_WRITE_5;
			end	//end STATE_WRITE_4
			
			STATE_WRITE_5: begin
				//Fourth block ready. Send it to DRAM.
				wr_data[31:0] <= drx_buf_data;
				wr_en <= 1;
				state <= STATE_WRITE_6;
				
				//Bump the address in case we need it
				drx_buf_addr <= drx_buf_addr + 10'h1;
				
			end	//end STATE_WRITE_5
			
			STATE_WRITE_6: begin
				if(done_sync_buf2) begin
				
					//Set address regardless of whether we're stopping to reduce logic on critical path
					//We only use the value in the "else" case
					addr <= addr + 32'h10;
				
					//If this was the last cache line, stop.
					if(drx_buf_addr >= drx_len) begin
						drx_ready <= 1;
						rpc_fab_tx_en <= 1;
						state <= STATE_IDLE;
					end
					
					//Otherwise, go on to the next one.
					else begin
						drx_buf_rd <= 1;
						state <= STATE_WRITE_1;
					end
				end
			end	//end STATE_WRITE_6
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read processing
			
			STATE_READ_0: begin
			
				//Not owned by the sender? Security violation, ignore the request
				if(!drx_src_addr_match) begin
					rpc_fab_tx_dst_addr <= drx_src_addr;
					rpc_fab_tx_callnum <= RAM_OP_FAILED;
					rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
					rpc_fab_tx_d0 <= drx_len;
					rpc_fab_tx_d1 <= drx_addr;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					
					drx_ready <= 1;
					state <= STATE_IDLE;
				end
				
				//Valid request.
				//Start processing it.
				else begin
					
					//Initiate the DRAM read immediately
					addr <= drx_addr;
					dtx_waddr <= 0;
					rd_en <= 1;
					state <= STATE_READ_1;
					
				end
			
			end	//end STATE_READ_0
			
			STATE_READ_1: begin
				if(done_sync_buf2) begin
					//DRAM read is done, write first word to DMA buffer
					dtx_buf_we <= 1;
					dtx_wdata <= rd_data_buf[127:96];
					state <= STATE_READ_2;
				end
			end	//end STATE_READ_1
			
			STATE_READ_2: begin
				//Write second word to DMA buffer
				dtx_buf_we <= 1;
				dtx_waddr <= dtx_waddr + 10'h1;
				dtx_wdata <= rd_data_buf[95:64];
				state <= STATE_READ_3;
			end	//end STATE_READ_2;
			
			STATE_READ_3: begin
				//Write third word to DMA buffer
				dtx_buf_we <= 1;
				dtx_waddr <= dtx_waddr + 10'h1;
				dtx_wdata <= rd_data_buf[63:32];
				state <= STATE_READ_4;
			end	//end STATE_READ_3;
			
			STATE_READ_4: begin
				//Write last word to DMA buffer
				dtx_buf_we <= 1;
				dtx_waddr <= dtx_waddr + 10'h1;
				dtx_wdata <= rd_data_buf[31:0];
				state <= STATE_READ_5;
			end	//end STATE_READ_4;
			
			STATE_READ_5: begin
				//Issue another DRAM read or send the message, as appropriate
				
				//Done filling buffer, send it
				if((dtx_waddr + 10'h1) >= dtx_len) begin
					dtx_en <= 1;
					state <= STATE_DMA_TXHOLD;
				end
				
				//We've got another cache line to send
				else begin
					dtx_waddr <= dtx_waddr + 10'h1;
					addr <= addr + 32'h10;
					rd_en <= 1;
					state <= STATE_READ_1;
				end
				
			end	//end STATE_READ_5
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// DMA helper states
			
			STATE_DMA_TXHOLD: begin
				if(!dtx_en && !dtx_busy) begin
					drx_ready <= 1;
					state <= STATE_IDLE;
				end
			end //end STATE_DMA_TXHOLD
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Free operation requested
			
			STATE_FREE_0: begin
			
				//Prepare to send fail status
				rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
				rpc_fab_tx_d0 <= 0;
				rpc_fab_tx_d1 <= 0;
				rpc_fab_tx_d2 <= 0;
			
				//Not owned by the sender? Security violation, ignore the request
				if(!chown_page_current_owner_match) begin
					rpc_fab_tx_en <= 1;
					rpc_fab_rx_done <= 1;
					
					state <= STATE_IDLE;
				end
				
				//Ownership records are OK, zero-fill and actually do the free operation		
				else begin
					free_wipe_start <= 1;
					state <= STATE_FREE_1;
				end
				
			end	//end STATE_FREE_0
			
			STATE_FREE_1: begin

				//Begin the wipe operation
				if(free_wipe_start) begin
					boot_addr <= {ownership_cache_in_pageid, 11'h0};
					addr <= {ownership_cache_in_pageid, 11'h0};
					wr_data <= 128'h0;
					wr_en <= 1;
					free_wipe_start <= 0;
				end
			
				//Run the next cycle of the wipe operation when the previous one finishes
				else if(done_sync_buf2) begin
					
					//Done?
					if(boot_addr[10:0] == 11'h7f0)
						state <= STATE_FREE_2;
					
					//No, zero-fill the next row
					else begin
						boot_addr <= boot_addr + 10'h1;
						addr <= boot_addr + 10'h1;
						wr_en <= 1;
					end
					
				end
				
			end	//end STATE_FREE_1
			
			STATE_FREE_2: begin
				
				//We now have one more free page. Update the free-table size and bump the pointer.
				free_page_count <= free_page_count + 16'h1;
				free_list_end_ptr <= free_list_end_ptr + 16'h1;
				
				//Push the page onto the free list
				free_list_end_cache[free_list_end_ptr_lo] <= ownership_cache_in_pageid;
				
				//If we have less than 8 free pages, it's possible that the start pointer will be right behind
				//the end pointer, within the same cache line. In order to maintain cache coherency, we need to
				//push freed pages directly into the start cache when this happens.
				if(free_list_start_ptr_hi == free_list_end_ptr_hi)
					free_list_start_cache[free_list_end_ptr_lo] <= ownership_cache_in_pageid;
			
				//If we just filled up the last row in the free-list cache, push it to DRAM.
				if(free_list_end_ptr_lo == 3'h7) begin
					addr <= 32'h00020000 + {free_list_end_ptr_hi, 4'h0};
					state <= STATE_FREE_3;
				end
				
				//Otherwise, just update ownership records and return
				else
					state <= STATE_CHOWN_0;
			
			end	//end STATE_FREE_2
			
			STATE_FREE_3: begin
			
				//free_list_end_cache has been written, now go and use the data
				wr_data[127:112] <= free_list_start_cache[0];
				wr_data[111:96] <= free_list_start_cache[1];
				wr_data[95:80] <= free_list_start_cache[2];
				wr_data[79:64] <= free_list_start_cache[3];
				wr_data[63:48] <= free_list_start_cache[4];
				wr_data[47:32] <= free_list_start_cache[5];
				wr_data[31:16] <= free_list_start_cache[6];
				wr_data[15:0] <= free_list_start_cache[7];

				wr_en <= 1;
				state <= STATE_FREE_4;

			end	//end STATE_FREE_3
			
			STATE_FREE_4: begin
				if(done_sync_buf2) begin
					state <= STATE_CHOWN_0;
					has_free_memory <= 1;
				end
					
			end	//end STATE_FREE_4
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Power-on initialization sequence
		
			//Wait for calibration to finish, then start filling ownership records
			STATE_BOOT_0: begin
				if(calib_done_sync) begin
					
					//Write addresses to the first memory row
					addr <= 0;
					boot_addr <= 0;
					wr_en <= 1;
					wr_data <= {NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR};
					state <= STATE_BOOT_1;
					
					ram_init_step <= 0;
					
				end
			end	//end STATE_BOOT_0
		
			/*
				Fill the ownership IDs (8 page IDs per cache line)
				Pages 0...127 (cache lines 0 ... 15 in table) are owned by us (NOC_ADDR).
				Pages 128 and up (cache lines 16...8191 in table) are free (0x0000)
				
				Fill the free list (8 page IDs per cache line)
				
				The free list itself is pages 64 ... 127 (cache lines 0x2000 to 0x3fff)
				
				Cache lines 0x2000 to 0x3fef get filled with page IDs 0x0080 to 0xffff (3ff0 to 3fff are empty).
				
				Fill the rest of memory with zeros to prevent any side channels.
			 */
			STATE_BOOT_1: begin				

				//Last write is done? Go on to the next address
				if(done_sync_buf2) begin
					
					//Go on to the next cache line
					addr <= boot_addr + 32'h10;
					boot_addr <= boot_addr + 32'h10;
					wr_en <= 1;

					//About to write the last page in a block? Go on to the next one
					if(boot_addr == 32'h0001ffe0)			//End of ownership records
						ram_init_step <= 1;
					else if(boot_addr == 32'h0003fee0)		//End of free list
						ram_init_step <= 2;
					else if(boot_addr == 32'h07ffffe0)		//End of physical memory
						ram_init_step <= 3;
				
					//Set up the data
					case(ram_init_step)
						
						//All memory is owned by us to begin with
						0: wr_data <= {NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR, NOC_ADDR};
						
						//Valid page IDs
						1: begin
							wr_data <=
							{
								16'h0080 + freelist_base,
								16'h0081 + freelist_base,
								16'h0082 + freelist_base,
								16'h0083 + freelist_base,
								16'h0084 + freelist_base,
								16'h0085 + freelist_base,
								16'h0086 + freelist_base,
								16'h0087 + freelist_base
							};

							freelist_base <= freelist_base + 16'h8;
						end
						
						//Zero fill unused memory
						2: wr_data <= 128'h0;
						
						//Done
						3: begin
							// synthesis translate_off
							$display("NetworkedDDR2Controller: Initialization complete");
							// synthesis translate_on
						
							wr_en <= 0;
							state <= STATE_IDLE;
						end
						
					endcase
					
	
				end

			end	//end STATE_BOOT_1
			
		endcase

	end

endmodule
