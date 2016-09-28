`timescale 1ns / 1ps
`default_nettype none
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
	@brief Block RAM based on-chip memory using the same API as NetworkedDDR2Controller.
		
	@module
	@opcodefile		../ddr2/NetworkedDDR2Controller_opcodes.constants
	
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
	@param			len				d0[15:0]:dec		Length of the data
	@param			addr			d1[31:0]:hex		Address of the data
	@brief			Access denied.
 */
module BlockRamAllocator(
	
	//Clocks
	clk,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack
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
	
	//Clocks
	input wire			clk;
	
	//NoC interface
	output wire			rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0]	rpc_rx_ack;
	
	output wire			dma_tx_en;
	output wire[31:0]	dma_tx_data;
	input wire			dma_tx_ack;
	input wire			dma_rx_en;
	input wire[31:0]	dma_rx_data;
	output wire			dma_rx_ack;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transceiver
	
	parameter NOC_ADDR = 16'h0000;
	
	wire		rpc_fab_tx_en;
	wire[15:0]	rpc_fab_tx_dst_addr;
	wire[7:0]	rpc_fab_tx_callnum;
	wire[2:0]	rpc_fab_tx_type;
	wire[20:0]	rpc_fab_tx_d0;
	wire[31:0]	rpc_fab_tx_d1;
	wire[31:0]	rpc_fab_tx_d2;
	wire		rpc_fab_tx_done;
	wire		rpc_fab_inbox_full;
	
	wire		rpc_fab_rx_en;
	wire[15:0]	rpc_fab_rx_src_addr;
	wire[15:0]	rpc_fab_rx_dst_addr;
	wire[7:0]	rpc_fab_rx_callnum;
	wire[2:0]	rpc_fab_rx_type;
	wire[20:0]	rpc_fab_rx_d0;
	wire[31:0]	rpc_fab_rx_d1;
	wire[31:0]	rpc_fab_rx_d2;
	wire		rpc_fab_rx_done;
		
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transceiver
	
	//DMA transmit signals
	wire		dtx_busy;
	wire[15:0]	dtx_dst_addr;
	wire[1:0]	dtx_op;
	wire[9:0]	dtx_len;
	wire[31:0]	dtx_addr;
	wire		dtx_en;
	wire		dtx_rd;
	wire[9:0]	dtx_raddr;
	wire[31:0]	dtx_buf_out;
	
	//DMA receive signals
	wire 		drx_ready;
	wire		drx_en;
	wire[15:0]	drx_src_addr;
	wire[1:0]	drx_op;
	wire[31:0]	drx_addr;
	wire[9:0]	drx_len;	
	wire		drx_buf_rd;
	wire[9:0]	drx_buf_addr;
	wire[31:0]	drx_buf_data;
	
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
		
		.rx_ready(drx_ready), .rx_en(drx_en), .rx_src_addr(drx_src_addr), .rx_dst_addr(),
		.rx_op(drx_op), .rx_addr(drx_addr), .rx_len(drx_len),
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(clk)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory bank itself

	wire[31:0]	storage_raddr;
	
	wire		storage_we;
	wire[31:0]	storage_waddr;
	wire[31:0]	storage_wdata;
	
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE("")
	) mem (
		.porta_clk(clk),
		.porta_en(storage_we),
		.porta_addr(storage_waddr[ADDR_BITS-1:0]),
		.porta_we(storage_we),
		.porta_din(storage_wdata),
		.porta_dout(),
		.portb_clk(clk),
		.portb_en(dtx_rd),
		.portb_addr(storage_raddr[ADDR_BITS-1:0]),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(dtx_buf_out)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Permissions storage
	
	wire					page_owner_wr_en;
	wire[15:0]				page_owner_wr_data;
	wire[PAGE_ID_BITS-1:0]	page_owner_addr;
	wire[15:0]				page_owner_rd_data;
	
	MemoryMacro #(
		.WIDTH(16),
		.DEPTH(NUM_PAGES),
		.DUAL_PORT(0),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(NOC_ADDR)
	) perms (
		.porta_clk(clk),
		.porta_en(1'b1),
		.porta_addr(page_owner_addr),
		.porta_we(page_owner_wr_en),
		.porta_din(page_owner_wr_data),
		.porta_dout(page_owner_rd_data),
		.portb_clk(1'b0),
		.portb_en(1'b0),
		.portb_addr({PAGE_ID_BITS{1'h0}}),
		.portb_we(1'b0),
		.portb_din(16'h0),
		.portb_dout()
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Free list
		
	wire[PAGE_ID_BITS:0]	free_page_count;
	
	wire					free_list_rd_en;
	wire[PAGE_ID_BITS-1:0]	free_list_rd_data;
	
	wire					free_list_wr_en;
	wire[PAGE_ID_BITS-1:0]	free_list_wr_data;
	
	SingleClockFifo #(
		.WIDTH(PAGE_ID_BITS),
		.DEPTH(NUM_PAGES),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(1),
		.INIT_FILE(""),
		.INIT_FULL(1)
	) freelist_2 (
		.clk(clk),
		
		.wr(free_list_wr_en),
		.din(free_list_wr_data),
		
		.rd(free_list_rd_en),
		.dout(free_list_rd_data),
		
		.overflow(),
		.underflow(),
		.empty(),
		.full(),
		.rsize(free_page_count),
		.wsize(),
		.reset(1'b0)
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	BlockRamAllocator_control #(
		.NOC_ADDR(NOC_ADDR),
		.NUM_PAGES(NUM_PAGES)
	) control(
		.clk(clk),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full(rpc_fab_inbox_full),
		
		.dtx_busy(dtx_busy),
		.dtx_en(dtx_en),
		.dtx_dst_addr(dtx_dst_addr),
		.dtx_op(dtx_op),
		.dtx_len(dtx_len),
		.dtx_addr(dtx_addr),
		.dtx_raddr(dtx_raddr),
		
		.drx_ready(drx_ready),
		.drx_en(drx_en),
		.drx_src_addr(drx_src_addr),
		.drx_op(drx_op),
		.drx_addr(drx_addr),
		.drx_len(drx_len),
		.drx_buf_rd(drx_buf_rd),
		.drx_buf_addr(drx_buf_addr),
		.drx_buf_data(drx_buf_data),
		
		.storage_raddr(storage_raddr),
		.storage_we(storage_we),
		.storage_wdata(storage_wdata),
		.storage_waddr(storage_waddr),
		
		.page_owner_wr_en(page_owner_wr_en),
		.page_owner_wr_data(page_owner_wr_data),
		.page_owner_addr(page_owner_addr),
		.page_owner_rd_data(page_owner_rd_data),
		
		.free_page_count(free_page_count),
		.free_list_rd_en(free_list_rd_en),
		.free_list_rd_data(free_list_rd_data),
		.free_list_wr_en(free_list_wr_en),
		.free_list_wr_data(free_list_wr_data)
	);
	
endmodule
