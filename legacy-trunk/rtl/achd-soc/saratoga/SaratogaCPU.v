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
	@brief Top-level module for SARATOGA CPU
	
	@module
	@opcodefile		SaratogaCPUManagementOpcodes.constants
	
	@rpcfn			OOB_OP_NOP
	@brief			No-operation
	
	@rpcfn			OOB_OP_GET_THREADCOUNT
	@brief			Get number of thread contexts
	
	@rpcfn_ok		OOB_OP_GET_THREADCOUNT
	@brief			Thread count retrieved
	@param			pcount			d0[15:0]:dec					Number of thread contexts
	
	@rpcfn			OOB_OP_CREATEPROCESS
	@brief			Create process
	@param			phyaddr			{d1[15:0],d2[31:0]}:phyaddr		Physical address of the executable
	
	@rpcfn_ok		OOB_OP_CREATEPROCESS
	@brief			Process created
	@param			nocaddr			d1[15:0]:nocaddr				NoC address of the new process
	@param 			tid				d0[15:0]:dec					Thread ID of the new process
	
	@rpcfn_fail		OOB_OP_CREATEPROCESS
	@brief			Process creation failed
	@param			errcode			d0[7:0]:enum					SaratogaCPURPCSubsystem_CreateErrcodes.constants
	@param			blerrcode		d1[7:0]:enum					SaratogaCPUELFLoader_Errcodes.constants
	
	@rpcfn			OOB_OP_MMAP
	@brief			Write to page table
	@param			phyaddr			{d0[15:0],d1[31:0]}:phyaddr		Physical address of the page
	@param			vaddr			d2[31:0]:hex					Virtual address of the page
	
	@rpcfn			OOB_OP_ATTEST
	@brief			Get signature of running thread
	@param			index			d0[18:16]:dec					Which 32-bit word of the signature to retrieve
	@param			tid				d0[15:0]:dec					The thread ID to search
	
	@rpcfn_ok		OOB_OP_ATTEST
	@brief			Thread signature
	@param			index			d0[18:16]:dec					Which 32-bit word of the signature to retrieve
	@param			tid				d0[15:0]:dec					The thread ID to search
	@param			modcount		d1[31:0]:hex					Modification count (if this changes, executable was reloaded)
	@param			sig				d2[31:0]:hex					The signature
	
	@rpcfn_ok		OOB_OP_MMAP
	@brief			Page table updated
 */
module SaratogaCPU(
	clk,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack/*,
	
	//Debug flag
	trace_flag*/
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Number of thread contexts
	parameter MAX_THREADS		= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS			= clog2(MAX_THREADS);
	
	//Number of words in a cache line
	parameter WORDS_PER_LINE	= 8;
	
	//Number of cache lines per associativity bank
	parameter LINES_PER_BANK	= 16;
	
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
	
	//Clock
	input wire clk;
	
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
	
	//Trace flag
	/*output */wire			trace_flag;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transceiver
	
	parameter NOC_ADDR = 16'h0000;
	
	wire		rpc_fab_tx_en;
	wire[15:0]	rpc_fab_tx_src_addr;
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
		.LEAF_PORT(1'h0),
		.LEAF_ADDR(16'h0)
	) rpc_txvr(
		.clk(clk),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(rpc_fab_tx_src_addr),
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
	
	wire		dma_fab_tx_en;
	wire		dma_fab_tx_done;
	
	wire		dma_fab_rx_en;
	wire		dma_fab_rx_done;
	wire		dma_fab_rx_inbox_full;
	wire[15:0]	dma_fab_rx_dst_addr;
	
	wire		dma_fab_header_wr_en;
	wire[1:0]	dma_fab_header_wr_addr;
	wire[31:0]	dma_fab_header_wr_data;
	wire		dma_fab_header_rd_en;
	wire[1:0]	dma_fab_header_rd_addr;
	wire[31:0]	dma_fab_header_rd_data;
	
	wire		dma_fab_data_wr_en;
	wire[8:0]	dma_fab_data_wr_addr;
	wire[31:0]	dma_fab_data_wr_data;
	wire		dma_fab_data_rd_en;
	wire[8:0]	dma_fab_data_rd_addr;
	wire[31:0]	dma_fab_data_rd_data;
	
	DMARouterTransceiver #(
		.LEAF_PORT(1'b0),
		.LEAF_ADDR(16'h0)
	) dma_txvr (
		.clk(clk),
		.dma_tx_en(dma_tx_en),
		.dma_tx_data(dma_tx_data),
		.dma_tx_ack(dma_tx_ack),
		.dma_rx_en(dma_rx_en),
		.dma_rx_data(dma_rx_data),
		.dma_rx_ack(dma_rx_ack),
		
		.tx_en(dma_fab_tx_en),
		.tx_done(dma_fab_tx_done),
		
		.rx_en(dma_fab_rx_en),
		.rx_done(dma_fab_rx_done),
		.rx_inbox_full(dma_fab_rx_inbox_full),
		.rx_inbox_full_cts(),
		.rx_dst_addr(dma_fab_rx_dst_addr),
	
		.header_wr_en(dma_fab_header_wr_en),
		.header_wr_addr(dma_fab_header_wr_addr),
		.header_wr_data(dma_fab_header_wr_data),
		.header_rd_en(dma_fab_header_rd_en),
		.header_rd_addr(dma_fab_header_rd_addr),
		.header_rd_data(dma_fab_header_rd_data), 
		
		.data_wr_en(dma_fab_data_wr_en),
		.data_wr_addr(dma_fab_data_wr_addr),
		.data_wr_data(dma_fab_data_wr_data),
		.data_rd_en(dma_fab_data_rd_en),
		.data_rd_addr(dma_fab_data_rd_addr),
		.data_rd_data(dma_fab_data_rd_data)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The scheduler
	
	//Command inputs
	wire[2:0]				sched_ctrl_opcode;
	wire[TID_BITS-1 : 0]	sched_ctrl_tid_in;
	wire[TID_BITS-1 : 0]	sched_ctrl_tid_out;
	wire					sched_ctrl_op_ok;
	wire					sched_ctrl_op_done;
	
	//Thread ID for each pipeline stage
	wire[TID_BITS-1 : 0]	ifetch0_tid;
	wire[TID_BITS-1 : 0]	ifetch1_tid;
	wire[TID_BITS-1 : 0]	decode0_tid;
	wire[TID_BITS-1 : 0]	decode1_tid;
	wire[TID_BITS-1 : 0]	exec0_tid;
	wire[TID_BITS-1 : 0]	exec1_tid;
	wire[TID_BITS-1 : 0]	exec2_tid;
	wire[TID_BITS-1 : 0]	exec3_tid;
	
	//Activity status for each pipeline stage
	//This indicates whether there is a thread active.
	//Note that each individual execution unit may or may not be doing anything even if the thread is active.
	wire					ifetch0_thread_active;
	wire					ifetch1_thread_active;
	wire					decode0_thread_active;
	wire					decode1_thread_active;
	wire					exec0_thread_active;
	wire					exec1_thread_active;
	wire					exec2_thread_active;
	wire					exec3_thread_active;
	
	SaratogaCPUThreadScheduler #(
		.MAX_THREADS(MAX_THREADS)
	) scheduler (
		.clk(clk),
		
		.ifetch0_tid(ifetch0_tid),
		.ifetch0_thread_active(ifetch0_thread_active),
		.ifetch1_tid(ifetch1_tid),
		.ifetch1_thread_active(ifetch1_thread_active),
		.decode0_tid(decode0_tid),
		.decode0_thread_active(decode0_thread_active),
		.decode1_tid(decode1_tid),
		.decode1_thread_active(decode1_thread_active),
		.exec0_tid(exec0_tid),
		.exec0_thread_active(exec0_thread_active),
		.exec1_tid(exec1_tid),
		.exec1_thread_active(exec1_thread_active),
		.exec2_tid(exec2_tid),
		.exec2_thread_active(exec2_thread_active),
		.exec3_tid(exec3_tid),
		.exec3_thread_active(exec3_thread_active),
		
		.ctrl_opcode(sched_ctrl_opcode),
		.ctrl_tid_in(sched_ctrl_tid_in),
		.ctrl_tid_out(sched_ctrl_tid_out),
		.ctrl_op_ok(sched_ctrl_op_ok),
		.ctrl_op_done(sched_ctrl_op_done)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The program counters for each thread context
	
	wire		ifetch0_iside_rd;
	wire[31:0]	ifetch0_iside_addr;
	
	wire[31:0]	ifetch1_pc;
	wire[31:0]	decode0_pc;
	wire[31:0]	decode1_pc;
	wire[31:0]	exec0_pc;
	wire[31:0]	exec0_pcp4;
	wire[31:0]	exec1_pc;
	wire[31:0]	exec2_pc;
	wire[31:0]	exec3_pc;
	
	reg			exec2_pc_we		= 0;
	(* REGISTER_BALANCING = "yes" *)
	reg[31:0]	exec2_pc_wdata	= 0;
	
	wire		exec2_mem_stall;
		
	SaratogaCPUProgramCounters #(
		.MAX_THREADS(MAX_THREADS)
	) pcs (
		.clk(clk),
		.ifetch0_thread_active(ifetch0_thread_active),
		.ifetch0_tid(ifetch0_tid),
		
		.ifetch0_iside_rd(ifetch0_iside_rd),
		.ifetch0_iside_addr(ifetch0_iside_addr),
		
		.ifetch1_pc(ifetch1_pc),
		.decode0_pc(decode0_pc),
		.decode1_pc(decode1_pc),
		.exec0_pc(exec0_pc),
		.exec0_pcp4(exec0_pcp4),
		.exec1_pc(exec1_pc),
		.exec2_pc(exec2_pc),
		.exec3_pc(exec3_pc),
		
		.exec2_tid(exec2_tid),
		.exec2_pc_we(exec2_pc_we && !exec2_mem_stall),		//Inhibit writes entirely if D-side cache miss
															//(this works since misses always come from unit 0)
		.exec2_pc_wdata(exec2_pc_wdata),
		
		.bootloader_pc_wr(bootloader_pc_wr),
		.bootloader_pc_tid(bootloader_pc_tid),
		.bootloader_pc_addr(bootloader_pc_addr)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA arbiter between bootloader and L1 cache
	
	wire		cache_dma_fab_tx_en;
	wire		cache_dma_fab_tx_done;
	wire		cache_dma_fab_rx_en;
	wire		cache_dma_fab_rx_done;
	wire		cache_dma_fab_rx_inbox_full;
	wire[15:0]	cache_dma_fab_rx_dst_addr;
	wire		cache_dma_fab_header_wr_en;
	wire[1:0]	cache_dma_fab_header_wr_addr;
	wire[31:0]	cache_dma_fab_header_wr_data;
	wire		cache_dma_fab_header_rd_en;
	wire[1:0]	cache_dma_fab_header_rd_addr;
	wire[31:0]	cache_dma_fab_header_rd_data;
	wire		cache_dma_fab_data_wr_en;
	wire[8:0]	cache_dma_fab_data_wr_addr;
	wire[31:0]	cache_dma_fab_data_wr_data;
	wire		cache_dma_fab_data_rd_en;
	wire[8:0]	cache_dma_fab_data_rd_addr;
	wire[31:0]	cache_dma_fab_data_rd_data;
	
	wire		bootloader_dma_fab_tx_en;
	wire		bootloader_dma_fab_tx_done;
	wire		bootloader_dma_fab_rx_en;
	wire		bootloader_dma_fab_rx_done;
	wire		bootloader_dma_fab_rx_inbox_full;
	wire[15:0]	bootloader_dma_fab_rx_dst_addr;
	wire		bootloader_dma_fab_header_wr_en;
	wire[1:0]	bootloader_dma_fab_header_wr_addr;
	wire[31:0]	bootloader_dma_fab_header_wr_data;
	wire		bootloader_dma_fab_header_rd_en;
	wire[1:0]	bootloader_dma_fab_header_rd_addr;
	wire[31:0]	bootloader_dma_fab_header_rd_data;
	wire		bootloader_dma_fab_data_wr_en;
	wire[8:0]	bootloader_dma_fab_data_wr_addr;
	wire[31:0]	bootloader_dma_fab_data_wr_data;
	wire		bootloader_dma_fab_data_rd_en;
	wire[8:0]	bootloader_dma_fab_data_rd_addr;
	wire[31:0]	bootloader_dma_fab_data_rd_data;
	
	wire		cache_read_pending;
	wire		bootloader_read_pending;
	
	SaratogaCPUDMAArbiter dma_arbiter(
		.clk(clk),
		
		//Status flags
		.bootloader_read_pending(bootloader_read_pending),
		.cache_read_pending(cache_read_pending),
		
		//Real DMA bus
		.dma_fab_tx_en(dma_fab_tx_en),
		.dma_fab_tx_done(dma_fab_tx_done),
		.dma_fab_rx_en(dma_fab_rx_en),
		.dma_fab_rx_done(dma_fab_rx_done),
		.dma_fab_rx_inbox_full(dma_fab_rx_inbox_full),
		.dma_fab_rx_dst_addr(dma_fab_rx_dst_addr),
		.dma_fab_header_wr_en(dma_fab_header_wr_en),
		.dma_fab_header_wr_addr(dma_fab_header_wr_addr),
		.dma_fab_header_wr_data(dma_fab_header_wr_data),
		.dma_fab_header_rd_en(dma_fab_header_rd_en),
		.dma_fab_header_rd_addr(dma_fab_header_rd_addr),
		.dma_fab_header_rd_data(dma_fab_header_rd_data),
		.dma_fab_data_wr_en(dma_fab_data_wr_en),
		.dma_fab_data_wr_addr(dma_fab_data_wr_addr),
		.dma_fab_data_wr_data(dma_fab_data_wr_data),
		.dma_fab_data_rd_en(dma_fab_data_rd_en),
		.dma_fab_data_rd_addr(dma_fab_data_rd_addr),
		.dma_fab_data_rd_data(dma_fab_data_rd_data),
		
		//L1 cache interface
		.cache_dma_fab_tx_en(cache_dma_fab_tx_en),
		.cache_dma_fab_tx_done(cache_dma_fab_tx_done),
		.cache_dma_fab_rx_en(cache_dma_fab_rx_en),
		.cache_dma_fab_rx_done(cache_dma_fab_rx_done),
		.cache_dma_fab_rx_inbox_full(cache_dma_fab_rx_inbox_full),
		.cache_dma_fab_rx_dst_addr(cache_dma_fab_rx_dst_addr),
		.cache_dma_fab_header_wr_en(cache_dma_fab_header_wr_en),
		.cache_dma_fab_header_wr_addr(cache_dma_fab_header_wr_addr),
		.cache_dma_fab_header_wr_data(cache_dma_fab_header_wr_data),
		.cache_dma_fab_header_rd_en(cache_dma_fab_header_rd_en),
		.cache_dma_fab_header_rd_addr(cache_dma_fab_header_rd_addr),
		.cache_dma_fab_header_rd_data(cache_dma_fab_header_rd_data),
		.cache_dma_fab_data_wr_en(cache_dma_fab_data_wr_en),
		.cache_dma_fab_data_wr_addr(cache_dma_fab_data_wr_addr),
		.cache_dma_fab_data_wr_data(cache_dma_fab_data_wr_data),
		.cache_dma_fab_data_rd_en(cache_dma_fab_data_rd_en),
		.cache_dma_fab_data_rd_addr(cache_dma_fab_data_rd_addr),
		.cache_dma_fab_data_rd_data(cache_dma_fab_data_rd_data),

		//Bootloader interface
		.bootloader_dma_fab_tx_en(bootloader_dma_fab_tx_en),
		.bootloader_dma_fab_tx_done(bootloader_dma_fab_tx_done),
		.bootloader_dma_fab_rx_en(bootloader_dma_fab_rx_en),
		.bootloader_dma_fab_rx_done(bootloader_dma_fab_rx_done),
		.bootloader_dma_fab_rx_inbox_full(bootloader_dma_fab_rx_inbox_full),
		.bootloader_dma_fab_rx_dst_addr(bootloader_dma_fab_rx_dst_addr),
		.bootloader_dma_fab_header_wr_en(bootloader_dma_fab_header_wr_en),
		.bootloader_dma_fab_header_wr_addr(bootloader_dma_fab_header_wr_addr),
		.bootloader_dma_fab_header_wr_data(bootloader_dma_fab_header_wr_data),
		.bootloader_dma_fab_header_rd_en(bootloader_dma_fab_header_rd_en),
		.bootloader_dma_fab_header_rd_addr(bootloader_dma_fab_header_rd_addr),
		.bootloader_dma_fab_header_rd_data(bootloader_dma_fab_header_rd_data),
		.bootloader_dma_fab_data_wr_en(bootloader_dma_fab_data_wr_en),
		.bootloader_dma_fab_data_wr_addr(bootloader_dma_fab_data_wr_addr),
		.bootloader_dma_fab_data_wr_data(bootloader_dma_fab_data_wr_data),
		.bootloader_dma_fab_data_rd_en(bootloader_dma_fab_data_rd_en),
		.bootloader_dma_fab_data_rd_addr(bootloader_dma_fab_data_rd_addr),
		.bootloader_dma_fab_data_rd_data(bootloader_dma_fab_data_rd_data)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MMU arbiter between bootloader and RPC subsystem
	
	wire					mmu_mgmt_wr_en;
	wire[TID_BITS-1 : 0]	mmu_mgmt_wr_tid;
	wire					mmu_mgmt_wr_valid;
	wire[2:0]				mmu_mgmt_wr_perms;
	wire[31:0]				mmu_mgmt_wr_vaddr;
	wire[15:0]				mmu_mgmt_wr_nocaddr;
	wire[31:0]				mmu_mgmt_wr_phyaddr;
	wire					mmu_mgmt_wr_done;
	
	wire					bootloader_mmu_wr_en;
	wire[TID_BITS-1 : 0]	bootloader_mmu_wr_tid;
	wire					bootloader_mmu_wr_valid;
	wire[2:0]				bootloader_mmu_wr_perms;
	wire[31:0]				bootloader_mmu_wr_vaddr;
	wire[15:0]				bootloader_mmu_wr_nocaddr;
	wire[31:0]				bootloader_mmu_wr_phyaddr;
	wire					bootloader_mmu_wr_done;
	 
	wire					rpc_mmu_wr_en;
	wire[TID_BITS-1 : 0]	rpc_mmu_wr_tid;
	wire					rpc_mmu_wr_valid;
	wire[2:0]				rpc_mmu_wr_perms;
	wire[31:0]				rpc_mmu_wr_vaddr;
	wire[15:0]				rpc_mmu_wr_nocaddr;
	wire[31:0]				rpc_mmu_wr_phyaddr;
	wire					rpc_mmu_wr_done;
	
	SaratogaCPUMMUArbiter #(
		.MAX_THREADS(MAX_THREADS)
	) mmu_arbiter (
		.clk(clk),

		.mmu_mgmt_wr_en(mmu_mgmt_wr_en),
		.mmu_mgmt_wr_tid(mmu_mgmt_wr_tid),
		.mmu_mgmt_wr_valid(mmu_mgmt_wr_valid),
		.mmu_mgmt_wr_perms(mmu_mgmt_wr_perms),
		.mmu_mgmt_wr_vaddr(mmu_mgmt_wr_vaddr),
		.mmu_mgmt_wr_nocaddr(mmu_mgmt_wr_nocaddr),
		.mmu_mgmt_wr_phyaddr(mmu_mgmt_wr_phyaddr),
		.mmu_mgmt_wr_done(mmu_mgmt_wr_done),
		
		.bootloader_mmu_wr_en(bootloader_mmu_wr_en),
		.bootloader_mmu_wr_tid(bootloader_mmu_wr_tid),
		.bootloader_mmu_wr_valid(bootloader_mmu_wr_valid),
		.bootloader_mmu_wr_perms(bootloader_mmu_wr_perms),
		.bootloader_mmu_wr_vaddr(bootloader_mmu_wr_vaddr),
		.bootloader_mmu_wr_nocaddr(bootloader_mmu_wr_nocaddr),
		.bootloader_mmu_wr_phyaddr(bootloader_mmu_wr_phyaddr),
		.bootloader_mmu_wr_done(bootloader_mmu_wr_done),
			
		.rpc_mmu_wr_en(rpc_mmu_wr_en),
		.rpc_mmu_wr_tid(rpc_mmu_wr_tid),
		.rpc_mmu_wr_valid(rpc_mmu_wr_valid),
		.rpc_mmu_wr_perms(rpc_mmu_wr_perms),
		.rpc_mmu_wr_vaddr(rpc_mmu_wr_vaddr),
		.rpc_mmu_wr_nocaddr(rpc_mmu_wr_nocaddr),
		.rpc_mmu_wr_phyaddr(rpc_mmu_wr_phyaddr),
		.rpc_mmu_wr_done(rpc_mmu_wr_done)
	);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The bootloader
	
	wire				bootloader_start_en;
	wire[TID_BITS-1:0]	bootloader_start_tid;
	wire[15:0]			bootloader_start_nocaddr;
	wire[31:0]			bootloader_start_phyaddr;
	wire				bootloader_start_done;
	wire				bootloader_start_ok;
	wire[7:0]			bootloader_start_errcode;
	
	wire				bootloader_pc_wr;
	wire[TID_BITS-1:0]	bootloader_pc_tid;
	wire[31:0]			bootloader_pc_addr;
	
	wire				signature_buf_inc;
	wire				signature_buf_wr;
	wire[31:0]			signature_buf_wdata;
	wire[2:0]			signature_buf_waddr;
	wire[TID_BITS-1:0]	signature_buf_tid;
	
	SaratogaCPUELFLoader #(
		.MAX_THREADS(MAX_THREADS),
		.NOC_ADDR(NOC_ADDR),
		.HMAC_KEY_0(HMAC_KEY_0),
		.HMAC_KEY_1(HMAC_KEY_1),
		.HMAC_KEY_2(HMAC_KEY_2),
		.HMAC_KEY_3(HMAC_KEY_3),
		.HMAC_KEY_4(HMAC_KEY_4),
		.HMAC_KEY_5(HMAC_KEY_5),
		.HMAC_KEY_6(HMAC_KEY_6),
		.HMAC_KEY_7(HMAC_KEY_7),
		.HMAC_KEY_8(HMAC_KEY_8),
		.HMAC_KEY_9(HMAC_KEY_9),
		.HMAC_KEY_A(HMAC_KEY_A),
		.HMAC_KEY_B(HMAC_KEY_B),
		.HMAC_KEY_C(HMAC_KEY_C),
		.HMAC_KEY_D(HMAC_KEY_D),
		.HMAC_KEY_E(HMAC_KEY_E),
		.HMAC_KEY_F(HMAC_KEY_F)
		
	) bootloader (
		.clk(clk),
		
		.read_pending(bootloader_read_pending),
		
		.start_en(bootloader_start_en),
		.start_tid(bootloader_start_tid),
		.start_nocaddr(bootloader_start_nocaddr),
		.start_phyaddr(bootloader_start_phyaddr),
		.start_done(bootloader_start_done),
		.start_ok(bootloader_start_ok),
		.start_errcode(bootloader_start_errcode),
		
		.pc_wr(bootloader_pc_wr),
		.pc_tid(bootloader_pc_tid),
		.pc_addr(bootloader_pc_addr),
		
		.mmu_wr_en(bootloader_mmu_wr_en),
		.mmu_wr_tid(bootloader_mmu_wr_tid),
		.mmu_wr_valid(bootloader_mmu_wr_valid),
		.mmu_wr_perms(bootloader_mmu_wr_perms),
		.mmu_wr_vaddr(bootloader_mmu_wr_vaddr),
		.mmu_wr_nocaddr(bootloader_mmu_wr_nocaddr),
		.mmu_wr_phyaddr(bootloader_mmu_wr_phyaddr),
		.mmu_wr_done(bootloader_mmu_wr_done),
		
		.signature_buf_inc(signature_buf_inc),
		.signature_buf_wr(signature_buf_wr),
		.signature_buf_wdata(signature_buf_wdata),
		.signature_buf_waddr(signature_buf_waddr),
		.signature_buf_tid(signature_buf_tid),
		
		.dma_fab_tx_en(bootloader_dma_fab_tx_en),
		.dma_fab_tx_done(bootloader_dma_fab_tx_done),
		
		.dma_fab_rx_en(bootloader_dma_fab_rx_en),
		.dma_fab_rx_done(bootloader_dma_fab_rx_done),
		.dma_fab_rx_inbox_full(bootloader_dma_fab_rx_inbox_full),
		.dma_fab_rx_dst_addr(bootloader_dma_fab_rx_dst_addr),
		
		.dma_fab_header_wr_en(bootloader_dma_fab_header_wr_en),
		.dma_fab_header_wr_addr(bootloader_dma_fab_header_wr_addr),
		.dma_fab_header_wr_data(bootloader_dma_fab_header_wr_data),
		.dma_fab_header_rd_en(bootloader_dma_fab_header_rd_en),
		.dma_fab_header_rd_addr(bootloader_dma_fab_header_rd_addr),
		.dma_fab_header_rd_data(bootloader_dma_fab_header_rd_data),
		
		.dma_fab_data_wr_en(bootloader_dma_fab_data_wr_en),
		.dma_fab_data_wr_addr(bootloader_dma_fab_data_wr_addr),
		.dma_fab_data_wr_data(bootloader_dma_fab_data_wr_data),
		.dma_fab_data_rd_en(bootloader_dma_fab_data_rd_en),
		.dma_fab_data_rd_addr(bootloader_dma_fab_data_rd_addr),
		.dma_fab_data_rd_data(bootloader_dma_fab_data_rd_data)
	);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The L1 cache and related logic
	
	wire[63:0]	decode0_insn;
	wire[1:0]	decode0_iside_hit;
	
	wire					l1_miss_rd;
	wire[TID_BITS-1 : 0]	l1_miss_tid;
	wire[31:0]				l1_miss_addr;
	wire[2:0]				l1_miss_perms;
	
	wire					l1_push_wr;
	wire[TID_BITS-1 : 0]	l1_push_tid;
	wire[31:0]				l1_push_addr;
	wire[63:0]				l1_push_data;
	
	wire					mmu_translate_en;
	wire[TID_BITS-1 : 0]	mmu_translate_tid;
	wire[31:0]				mmu_translate_vaddr;
	wire[2:0]				mmu_translate_perms;
	wire[15:0]				mmu_translate_nocaddr;
	wire[31:0]				mmu_translate_phyaddr;
	wire					mmu_translate_done;
	wire					mmu_translate_failed;

	wire					exec0_dside_rd;
	wire					exec0_dside_wr;
	wire[3:0]				exec0_dside_wmask;
	wire[31:0]				exec0_dside_addr;
	wire[31:0]				exec0_dside_wdata;
	wire[63:0]				exec2_dside_rdata;
	wire[1:0]				exec2_dside_hit;
	
	wire					l1_flush_en;
	wire[TID_BITS-1 : 0]	l1_flush_tid;
	wire[31:0]				l1_flush_addr;
	wire[63:0]				l1_flush_data;
	wire					l1_flush_done;

	SaratogaCPUL1Cache #(
		.MAX_THREADS(MAX_THREADS),
		.ASSOC_WAYS(2),
		.WORDS_PER_LINE(WORDS_PER_LINE),
		.LINES_PER_BANK(LINES_PER_BANK)
	) l1_cache(
		.clk(clk),
		
		//I-side bus
		.ifetch0_thread_active(ifetch0_thread_active),
		.ifetch0_tid(ifetch0_tid),
		.ifetch0_iside_rd(ifetch0_iside_rd),
		.ifetch0_iside_addr(ifetch0_iside_addr),
		.ifetch1_thread_active(ifetch1_thread_active),
		.ifetch1_tid(ifetch1_tid),
		.decode0_tid(decode0_tid),
		.decode0_insn(decode0_insn),
		.decode0_iside_hit(decode0_iside_hit),
		
		//D-side bus
		.exec0_tid(exec0_tid),
		.exec0_thread_active(exec0_thread_active),
		.exec0_dside_rd(exec0_dside_rd),
		.exec0_dside_wr(exec0_dside_wr),
		.exec0_dside_wmask(exec0_dside_wmask),
		.exec0_dside_addr(exec0_dside_addr),
		.exec0_dside_din(exec0_dside_wdata),
		.exec1_tid(exec1_tid),
		.exec1_thread_active(exec1_thread_active),
		.exec2_tid(exec2_tid),
		.exec2_dside_dout(exec2_dside_rdata),
		.exec2_dside_hit(exec2_dside_hit),
		
		//Miss requests
		.miss_rd(l1_miss_rd),
		.miss_tid(l1_miss_tid),
		.miss_addr(l1_miss_addr),
		.miss_perms(l1_miss_perms),
		
		//Push requests
		.push_wr(l1_push_wr),
		.push_tid(l1_push_tid),
		.push_addr(l1_push_addr),
		.push_data(l1_push_data),
		
		//Flush requests
		.flush_en(l1_flush_en),
		.flush_tid(l1_flush_tid),
		.flush_addr(l1_flush_addr),
		.flush_dout(l1_flush_data),
		.flush_done(l1_flush_done)
	);
	
	SaratogaCPUL1CacheMissHandling #(
		.MAX_THREADS(MAX_THREADS),
		.NOC_ADDR(NOC_ADDR),
		.WORDS_PER_LINE(WORDS_PER_LINE)
	) miss_handler (
		.clk(clk),
		
		//Miss requests
		.miss_rd(l1_miss_rd),
		.miss_tid(l1_miss_tid),
		.miss_addr(l1_miss_addr),
		.miss_perms(l1_miss_perms),
		
		//Push requests
		.push_wr(l1_push_wr),
		.push_tid(l1_push_tid),
		.push_addr(l1_push_addr),
		.push_data(l1_push_data),
		
		//Flush requests
		.flush_en(l1_flush_en),
		.flush_tid(l1_flush_tid),
		.flush_addr(l1_flush_addr),
		.flush_data(l1_flush_data),
		.flush_done(l1_flush_done),
		
		//MMU interface
		.mmu_translate_en(mmu_translate_en),
		.mmu_translate_tid(mmu_translate_tid),
		.mmu_translate_vaddr(mmu_translate_vaddr),
		.mmu_translate_perms(mmu_translate_perms),
		.mmu_translate_nocaddr(mmu_translate_nocaddr),
		.mmu_translate_phyaddr(mmu_translate_phyaddr),
		.mmu_translate_done(mmu_translate_done),
		.mmu_translate_failed(mmu_translate_failed),
		
		//Flags to arbiter
		.read_pending(cache_read_pending),
		
		//DMA interface
		.dma_fab_tx_en(cache_dma_fab_tx_en),
		.dma_fab_tx_done(cache_dma_fab_tx_done),
		
		.dma_fab_rx_en(cache_dma_fab_rx_en),
		.dma_fab_rx_done(cache_dma_fab_rx_done),
		.dma_fab_rx_inbox_full(cache_dma_fab_rx_inbox_full),
		.dma_fab_rx_dst_addr(cache_dma_fab_rx_dst_addr),
		
		.dma_fab_header_wr_en(cache_dma_fab_header_wr_en),
		.dma_fab_header_wr_addr(cache_dma_fab_header_wr_addr),
		.dma_fab_header_wr_data(cache_dma_fab_header_wr_data),
		.dma_fab_header_rd_en(cache_dma_fab_header_rd_en),
		.dma_fab_header_rd_addr(cache_dma_fab_header_rd_addr),
		.dma_fab_header_rd_data(cache_dma_fab_header_rd_data),
		
		.dma_fab_data_wr_en(cache_dma_fab_data_wr_en),
		.dma_fab_data_wr_addr(cache_dma_fab_data_wr_addr),
		.dma_fab_data_wr_data(cache_dma_fab_data_wr_data),
		.dma_fab_data_rd_en(cache_dma_fab_data_rd_en),
		.dma_fab_data_rd_addr(cache_dma_fab_data_rd_addr),
		.dma_fab_data_rd_data(cache_dma_fab_data_rd_data)
	);
	
	SaratogaCPUMMU #(
		.MAX_THREADS(MAX_THREADS)
	) mmu (
		.clk(clk),
		
		.translate_en(mmu_translate_en),
		.translate_tid(mmu_translate_tid),
		.translate_vaddr(mmu_translate_vaddr),
		.translate_perms(mmu_translate_perms),
		.translate_nocaddr(mmu_translate_nocaddr),
		.translate_phyaddr(mmu_translate_phyaddr),
		.translate_done(mmu_translate_done),
		.translate_failed(mmu_translate_failed),
		
		.mgmt_wr_en(mmu_mgmt_wr_en),
		.mgmt_wr_tid(mmu_mgmt_wr_tid),
		.mgmt_wr_valid(mmu_mgmt_wr_valid),
		.mgmt_wr_perms(mmu_mgmt_wr_perms),
		.mgmt_wr_vaddr(mmu_mgmt_wr_vaddr),
		.mgmt_wr_nocaddr(mmu_mgmt_wr_nocaddr),
		.mgmt_wr_phyaddr(mmu_mgmt_wr_phyaddr),
		.mgmt_wr_done(mmu_mgmt_wr_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Instruction decode logic
	
	wire[4:0]	decode0_unit0_rs_id;
	wire[4:0]	decode0_unit0_rt_id;
	wire[4:0]	decode0_unit1_rs_id;
	wire[4:0]	decode0_unit1_rt_id;
	
	wire[4:0]	exec0_unit0_rd_id;
	wire[4:0]	exec0_unit1_rd_id;
	
	wire		exec0_unit0_en;
	wire		exec0_unit1_en;
	
	wire		exec0_unit0_rtype;
	wire		exec0_unit0_itype;
	wire		exec0_unit0_jtype;
	wire[5:0]	exec0_unit0_opcode;
	wire[5:0]	exec0_unit0_func;
	wire[15:0]	exec0_unit0_immval;
	wire[25:0]	exec0_unit0_jtype_addr;
	wire[4:0]	exec0_unit0_shamt;
	wire		exec0_unit0_syscall;
	wire		exec0_unit0_mem;
	wire[4:0]	exec0_unit0_branch_op;
	wire		exec0_unit0_div;
	wire		exec0_unit0_div_sign;
	
	wire		exec0_unit1_rtype;
	wire		exec0_unit1_itype;
	wire		exec0_unit1_jtype;
	wire[5:0]	exec0_unit1_opcode;
	wire[5:0]	exec0_unit1_func;
	wire[15:0]	exec0_unit1_immval;
	wire[25:0]	exec0_unit1_jtype_addr;
	wire[4:0]	exec0_unit1_shamt;
	wire		exec0_unit1_syscall;
	wire		exec0_unit1_mem;
	wire[4:0]	exec0_unit1_branch_op;
	wire		exec0_unit1_div;
	wire		exec0_unit1_div_sign;
	
	SaratogaCPUInstructionDecoder decode(
		.clk(clk),
	
		.decode0_thread_active(decode0_thread_active),
		.decode0_insn(decode0_insn),
		.decode0_iside_hit(decode0_iside_hit),
	
		.decode0_unit0_rs_id(decode0_unit0_rs_id),
		.decode0_unit0_rt_id(decode0_unit0_rt_id),
		.decode0_unit1_rs_id(decode0_unit1_rs_id),
		.decode0_unit1_rt_id(decode0_unit1_rt_id),
		
		.exec0_unit0_rd_id(exec0_unit0_rd_id),
		.exec0_unit0_en(exec0_unit0_en),
		.exec0_unit0_rtype(exec0_unit0_rtype),
		.exec0_unit0_itype(exec0_unit0_itype),
		.exec0_unit0_jtype(exec0_unit0_jtype),
		.exec0_unit0_opcode(exec0_unit0_opcode),
		.exec0_unit0_func(exec0_unit0_func),
		.exec0_unit0_immval(exec0_unit0_immval),
		.exec0_unit0_jtype_addr(exec0_unit0_jtype_addr),
		.exec0_unit0_shamt(exec0_unit0_shamt),
		.exec0_unit0_syscall(exec0_unit0_syscall),
		.exec0_unit0_mem(exec0_unit0_mem),
		.exec0_unit0_branch_op(exec0_unit0_branch_op),
		.exec0_unit0_div(exec0_unit0_div),
		.exec0_unit0_div_sign(exec0_unit0_div_sign),
		
		.exec0_unit1_rd_id(exec0_unit1_rd_id),
		.exec0_unit1_en(exec0_unit1_en),
		.exec0_unit1_rtype(exec0_unit1_rtype),
		.exec0_unit1_itype(exec0_unit1_itype),
		.exec0_unit1_jtype(exec0_unit1_jtype),
		.exec0_unit1_opcode(exec0_unit1_opcode),
		.exec0_unit1_func(exec0_unit1_func),
		.exec0_unit1_immval(exec0_unit1_immval),
		.exec0_unit1_jtype_addr(exec0_unit1_jtype_addr),
		.exec0_unit1_shamt(exec0_unit1_shamt),
		.exec0_unit1_syscall(exec0_unit1_syscall),
		.exec0_unit1_mem(exec0_unit1_mem),
		.exec0_unit1_branch_op(exec0_unit1_branch_op),
		.exec0_unit1_div(exec0_unit1_div),
		.exec0_unit1_div_sign(exec0_unit1_div_sign)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Multiply/divide unit registers

	//m[f|t][lo|hi]
	wire		exec1_mdu_wr_lo;
	wire		exec1_mdu_wr_hi;
	wire[31:0]	exec1_mdu_wdata;
	wire[31:0]	exec2_mdu_rdata_lo;
	wire[31:0]	exec2_mdu_rdata_hi;
	
	//mul (cannot stall)
	wire		decode1_mdu_wr;
	wire[31:0]	decode1_mdu_wdata_lo;
	wire[31:0]	decode1_mdu_wdata_hi;
	
	//div
	wire[31:0]				unit0_div_rem;
	wire[31:0]				unit0_div_quot;
	wire					unit0_div_done;
	wire[TID_BITS-1 : 0]	unit0_div_done_tid;
	
	MultiportMemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(3),
		.USE_BLOCK(0),
		.OUT_REG(1)
	) mdu_lo_mem (
		.clk,
		.wr_en(  {exec1_mdu_wr_lo,	decode1_mdu_wr,			unit0_div_done}),
		.wr_addr({exec1_tid, 		decode1_tid,			unit0_div_done_tid}),
		.wr_data({exec1_mdu_wdata,	decode1_mdu_wdata_lo,	unit0_div_quot}),
		.rd_en(1'b1),
		.rd_addr(exec1_tid),
		.rd_data(exec2_mdu_rdata_lo)
	);
	
	MultiportMemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(3),
		.USE_BLOCK(0),
		.OUT_REG(1)
	) mdu_hi_mem (
		.clk,
		.wr_en(  {exec1_mdu_wr_hi,	decode1_mdu_wr,			unit0_div_done}),
		.wr_addr({exec1_tid, 		decode1_tid,			unit0_div_done_tid}),
		.wr_data({exec1_mdu_wdata,	decode1_mdu_wdata_hi,	unit0_div_rem}),
		.rd_en(1'b1),
		.rd_addr(exec1_tid),
		.rd_data(exec2_mdu_rdata_hi)
	);
	
	//Keep track of which threads have a divide in progress
	wire					exec0_unit0_div_start		= exec0_unit0_en && exec0_unit0_div;
	wire					exec0_div_busy;
	MultiportMemoryMacro #(
		.WIDTH(1),
		.DEPTH(MAX_THREADS),
		.NREAD(1),
		.NWRITE(2),
		.USE_BLOCK(0),
		.OUT_REG(1)
	) div_active_mem (
		.clk,
		.wr_en(  {exec0_unit0_div_start,	unit0_div_done}),
		.wr_addr({exec0_tid, 				unit0_div_done_tid}),
		.wr_data({1'b1,						1'b0}),
		.rd_en(1'b1),
		.rd_addr(decode1_tid),
		.rd_data(exec0_div_busy)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The register file
	
	//Signals for read are set during DECODE0	
	//Signals for writeback are set during EXEC3
	
	wire		exec3_unit0_wr_en;
	wire		exec3_unit1_wr_en;
	wire[31:0]	exec3_unit0_wr_data;
	wire[31:0]	exec3_unit1_wr_data;
	
	wire[4:0]	exec3_unit0_wr_id;
	wire[4:0]	exec3_unit1_wr_id;

	wire[31:0]	exec0_unit0_rs;
	wire[31:0]	exec0_unit0_rt;
	wire[31:0]	exec0_unit1_rs;
	wire[31:0]	exec0_unit1_rt;
	
	MultiportMemoryMacro #(
		.WIDTH(32),
		.DEPTH(MAX_THREADS * 32),
		.NREAD(4),
		.NWRITE(2),
		.USE_BLOCK(1),
		.OUT_REG(2),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) regfile (
		.clk(clk),
		
		.wr_en(  {exec3_unit1_wr_en,	exec3_unit0_wr_en }),
		.wr_addr(
		{
			{exec3_tid, exec3_unit1_wr_id},
			{exec3_tid, exec3_unit0_wr_id}
		}
		),
		.wr_data( {exec3_unit1_wr_data, exec3_unit0_wr_data} ),
		
		.rd_en(4'b1111),
		.rd_addr({
			{decode0_tid, decode0_unit0_rs_id},
			{decode0_tid, decode0_unit0_rt_id},
			
			{decode0_tid, decode0_unit1_rs_id},
			{decode0_tid, decode0_unit1_rt_id}
		}),
		.rd_data({exec0_unit0_rs, exec0_unit0_rt, exec0_unit1_rs, exec0_unit1_rt})
	);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transmit FIFO
	
	localparam RPC_TX_FIFO_DEPTH	= 512;
	localparam TX_FIFO_BITS			= clog2(RPC_TX_FIFO_DEPTH);
	
	//Read port
	wire						rpc_tx_fifo_rd;
	wire						rpc_tx_fifo_empty;
	wire[127:0]					rpc_tx_fifo_dout;
	
	//Write port
	wire						exec1_rpc_tx_fifo_wr;
	wire[TX_FIFO_BITS : 0]		exec0_rpc_tx_fifo_wsize;
	
	SaratogaCPURPCTransmitFifo #(
		.NOC_ADDR(NOC_ADDR),
		.MAX_THREADS(MAX_THREADS),
		.RPC_TX_FIFO_DEPTH(RPC_TX_FIFO_DEPTH)
	) rpc_tx_fifo (
		.clk(clk),
		.rpc_tx_fifo_rd(rpc_tx_fifo_rd),
		.rpc_tx_fifo_empty(rpc_tx_fifo_empty),
		.rpc_tx_fifo_dout(rpc_tx_fifo_dout),
		.exec1_rpc_tx_fifo_wr(exec1_rpc_tx_fifo_wr),
		.exec0_rpc_tx_fifo_wsize(exec0_rpc_tx_fifo_wsize),
		.exec0_tid(exec0_tid),
		.exec0_unit0_rs(exec0_unit0_rs),
		.exec0_unit0_rt(exec0_unit0_rt),
		.exec0_unit1_rs(exec0_unit1_rs),
		.exec0_unit1_rt(exec0_unit1_rt)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The RPC subsystem (includes the OOB logic, bootloader, and arbiter for firmware RPC stuff)
	
	wire					exec0_rpc_rx_en;
	wire					exec1_rpc_rx_valid;
	wire[63:0]				exec2_rpc_rx_data;
	
	wire					exec0_syscall_repeat;
	
	SaratogaCPURPCSubsystem #(
		.NOC_ADDR(NOC_ADDR),
		.MAX_THREADS(MAX_THREADS)
	) rpc_subsystem (
		.clk(clk),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(rpc_fab_tx_src_addr),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		
		.rpc_fab_inbox_full(rpc_fab_inbox_full),
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		
		.bootloader_start_en(bootloader_start_en),
		.bootloader_start_tid(bootloader_start_tid),
		.bootloader_start_nocaddr(bootloader_start_nocaddr),
		.bootloader_start_phyaddr(bootloader_start_phyaddr),
		.bootloader_start_done(bootloader_start_done),
		.bootloader_start_ok(bootloader_start_ok),
		.bootloader_start_errcode(bootloader_start_errcode),
		
		.sched_ctrl_opcode(sched_ctrl_opcode),
		.sched_ctrl_tid_in(sched_ctrl_tid_in),
		.sched_ctrl_tid_out(sched_ctrl_tid_out),
		.sched_ctrl_op_ok(sched_ctrl_op_ok),
		.sched_ctrl_op_done(sched_ctrl_op_done),
		
		.signature_buf_inc(signature_buf_inc),
		.signature_buf_wr(signature_buf_wr),
		.signature_buf_wdata(signature_buf_wdata),
		.signature_buf_waddr(signature_buf_waddr),
		.signature_buf_tid(signature_buf_tid),
		
		.rpc_tx_fifo_rd(rpc_tx_fifo_rd),
		.rpc_tx_fifo_empty(rpc_tx_fifo_empty),
		.rpc_tx_fifo_dout(rpc_tx_fifo_dout),
		
		.rpc_rx_fifo_rd_en(exec0_rpc_rx_en),
		.rpc_rx_fifo_rd_tid(exec0_tid),
		.rpc_rx_fifo_rd_valid(exec1_rpc_rx_valid),
		.rpc_rx_fifo_rd_data_muxed(exec2_rpc_rx_data),
		
		.decode1_tid(decode1_tid),
		.exec0_syscall(exec0_unit0_en && exec0_unit0_syscall),
		.exec0_syscall_repeat(exec0_syscall_repeat),
		.exec1_unit0_en(exec1_unit0_en),
		.exec1_tid(exec1_tid),

		.mmu_mgmt_wr_en(rpc_mmu_wr_en),
		.mmu_mgmt_wr_tid(rpc_mmu_wr_tid),
		.mmu_mgmt_wr_valid(rpc_mmu_wr_valid),
		.mmu_mgmt_wr_perms(rpc_mmu_wr_perms),
		.mmu_mgmt_wr_vaddr(rpc_mmu_wr_vaddr),
		.mmu_mgmt_wr_nocaddr(rpc_mmu_wr_nocaddr),
		.mmu_mgmt_wr_phyaddr(rpc_mmu_wr_phyaddr),
		.mmu_mgmt_wr_done(rpc_mmu_wr_done)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The execution units
	
	//Branch stuff
	wire		exec1_unit0_branch_en;
	wire[31:0]	exec1_unit0_branch_addr;
	wire		exec1_unit1_branch_en;
	wire[31:0]	exec1_unit1_branch_addr;
	wire		exec1_unit0_stall;
	wire		exec1_unit1_stall;
	
	//Status flags
	//TODO: Don't just ignore these
	wire		exec1_unit0_bad_instruction;
	wire		exec1_unit1_bad_instruction;
	
	//Execution unit 0 (master, does RPC stuff etc)
	SaratogaCPUExecutionUnit #(
		.NOC_ADDR(NOC_ADDR),
		.RPC_TX_FIFO_DEPTH(RPC_TX_FIFO_DEPTH),
		.MAX_THREADS(MAX_THREADS),
		.UNIT_NUM(0)
	) exec_unit0(
		.clk(clk),
		.exec0_tid(exec0_tid),
		.exec0_en(exec0_unit0_en),
		.exec0_rs(exec0_unit0_rs),
		.exec0_rt(exec0_unit0_rt),
		.exec0_rd_id(exec0_unit0_rd_id),
		.exec0_rtype(exec0_unit0_rtype),
		.exec0_itype(exec0_unit0_itype),
		.exec0_jtype(exec0_unit0_jtype),
		.exec0_mem(exec0_unit0_mem),
		.exec0_opcode(exec0_unit0_opcode),
		.exec0_func(exec0_unit0_func),
		.exec0_immval(exec0_unit0_immval),
		.exec0_jtype_addr(exec0_unit0_jtype_addr),
		.exec0_shamt(exec0_unit0_shamt),
		.exec0_syscall(exec0_unit0_syscall),
		.exec0_syscall_repeat(exec0_syscall_repeat),
		.exec0_branch_op(exec0_unit0_branch_op),
		.exec0_pc(exec0_pc),
		.exec0_div(exec0_unit0_div),
		.exec0_div_sign(exec0_unit0_div_sign),
		.exec1_branch_en(exec1_unit0_branch_en),
		.exec1_branch_addr(exec1_unit0_branch_addr),
		.exec1_stall(exec1_unit0_stall),
		.exec3_wr_en(exec3_unit0_wr_en),
		.exec3_wr_id(exec3_unit0_wr_id),
		.exec3_wr_data(exec3_unit0_wr_data),
		
		.exec0_rpc_tx_fifo_wsize(exec0_rpc_tx_fifo_wsize),
		.exec1_rpc_tx_fifo_wr(exec1_rpc_tx_fifo_wr),
		
		.exec0_rpc_rx_en(exec0_rpc_rx_en),
		.exec0_rpc_rx_en_master(1'b0),
		.exec1_rpc_rx_valid(exec1_rpc_rx_valid),
		.exec2_rpc_rx_data(exec2_rpc_rx_data[63:32]),
		
		.exec0_div_busy(exec0_div_busy),
		.exec1_mdu_wr_lo(exec1_mdu_wr_lo),
		.exec1_mdu_wr_hi(exec1_mdu_wr_hi),
		.exec1_mdu_wdata(exec1_mdu_wdata),
		.exec2_mdu_rdata_lo(exec2_mdu_rdata_lo),
		.exec2_mdu_rdata_hi(exec2_mdu_rdata_hi),
		.div_quot(unit0_div_quot),
		.div_rem(unit0_div_rem),
		.div_done(unit0_div_done),
		.div_done_tid(unit0_div_done_tid),
		
		.decode1_mdu_wr(decode1_mdu_wr),
		.decode1_mdu_wdata_lo(decode1_mdu_wdata_lo),
		.decode1_mdu_wdata_hi(decode1_mdu_wdata_hi),
		
		.exec0_dside_rd(exec0_dside_rd),
		.exec0_dside_wr(exec0_dside_wr),
		.exec0_dside_wmask(exec0_dside_wmask),
		.exec0_dside_addr(exec0_dside_addr),
		.exec0_dside_wdata(exec0_dside_wdata),
		.exec2_dside_rdata(exec2_dside_rdata),
		.exec2_dside_hit(exec2_dside_hit),
		.exec2_mem_stall(exec2_mem_stall),
		
		.trace_flag(trace_flag),
		
		.exec1_bad_instruction(exec1_unit0_bad_instruction)
	);
	
	//Execution unit 1 (slave, some stuff missing)
	SaratogaCPUExecutionUnit #(
		.NOC_ADDR(NOC_ADDR),
		.MAX_THREADS(MAX_THREADS),
		.UNIT_NUM(1)
	) exec_unit1(
		.clk(clk),
		.exec0_tid(exec0_tid),
		.exec0_en(exec0_unit1_en),
		.exec0_rs(exec0_unit1_rs),
		.exec0_rt(exec0_unit1_rt),
		.exec0_rd_id(exec0_unit1_rd_id),
		.exec0_rtype(exec0_unit1_rtype),
		.exec0_itype(exec0_unit1_itype),
		.exec0_jtype(exec0_unit1_jtype),
		.exec0_mem(exec0_unit1_mem),
		.exec0_opcode(exec0_unit1_opcode),
		.exec0_func(exec0_unit1_func),
		.exec0_immval(exec0_unit1_immval),
		.exec0_jtype_addr(exec0_unit1_jtype_addr),
		.exec0_shamt(exec0_unit1_shamt),
		.exec0_syscall(exec0_unit1_syscall),
		.exec0_syscall_repeat(exec0_syscall_repeat),
		.exec0_branch_op(exec0_unit1_branch_op),
		.exec0_pc(exec0_pcp4),
		.exec0_div(1'b0),								//never dividing in the slave unit
		.exec0_div_sign(1'b0),
		.exec1_branch_en(exec1_unit1_branch_en),
		.exec1_branch_addr(exec1_unit1_branch_addr),
		.exec1_stall(exec1_unit1_stall),
		.exec3_wr_en(exec3_unit1_wr_en),
		.exec3_wr_id(exec3_unit1_wr_id),
		.exec3_wr_data(exec3_unit1_wr_data),
		
		.exec0_rpc_tx_fifo_wsize(10'b0),
		.exec1_rpc_tx_fifo_wr(),
		
		.exec0_rpc_rx_en(),
		.exec0_rpc_rx_en_master(exec0_rpc_rx_en),
		.exec1_rpc_rx_valid(exec1_rpc_rx_valid),
		.exec2_rpc_rx_data(exec2_rpc_rx_data[31:0]),
		
		.exec0_div_busy(exec0_div_busy),
		.exec1_mdu_wr_lo(),
		.exec1_mdu_wr_hi(),
		.exec1_mdu_wdata(),
		.exec2_mdu_rdata_lo(exec2_mdu_rdata_lo),
		.exec2_mdu_rdata_hi(exec2_mdu_rdata_hi),
		.div_quot(),
		.div_rem(),
		.div_done(),
		.div_done_tid(),
		
		.decode1_mdu_wr(),
		.decode1_mdu_wdata_lo(),
		.decode1_mdu_wdata_hi(),
		
		.exec0_dside_rd(),
		.exec0_dside_wr(),
		.exec0_dside_wmask(),
		.exec0_dside_addr(),
		.exec0_dside_wdata(),
		.exec2_dside_rdata(64'h0),
		.exec2_dside_hit(2'b0),
		.exec2_mem_stall(),
		
		.trace_flag(),
		
		.exec1_bad_instruction(exec1_unit1_bad_instruction)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// PC update logic (TODO: move to a module)
	
	reg		exec1_unit0_en	 = 0;
	reg		exec1_unit1_en	 = 0;
	reg		exec1_unit0_syscall	= 0;
	
	always @(posedge clk) begin
		
		exec1_unit0_en		<= exec0_unit0_en;
		exec1_unit1_en		<= exec0_unit1_en;
		exec1_unit0_syscall	<= exec0_unit0_syscall;

		//Always write to $pc if a thread is active
		exec2_pc_we			<= exec1_thread_active;
		
		//If both execution units are disabled (L1 miss etc), repeat this instruction
		if(!exec1_unit0_en)
			exec2_pc_wdata	<= exec1_pc;
			
		//If stalling due to a D-side cache miss, divide, etc repeat this instruction
		//This must be done before jumps so that a jump in unit 1 doesn't skip a stalled instruction
		//from unit 0
		else if(exec1_unit0_stall)
			exec2_pc_wdata	<= exec1_pc;
			
		//TODO: Stalls from unit 1
		
		//If we are taking a jump, go to the target
		else if(exec1_unit0_branch_en)
			exec2_pc_wdata	<= exec1_unit0_branch_addr;
		else if(exec1_unit1_branch_en)
			exec2_pc_wdata	<= exec1_unit1_branch_addr;
		
		//TODO: If unit 1 has a conditional that's not being taken, skip the delay slot insn
			
		//If processing a syscall, bump by 4 even though both units are active
		else if(exec1_unit0_en && exec1_unit0_syscall)
			exec2_pc_wdata	<= exec1_pc + 32'h4;
		
		//Nope, normal instruction - just keep counting
		else if(exec1_unit0_en && exec1_unit1_en)
			exec2_pc_wdata	<= exec1_pc + 32'h8;	//two instructions
		else
			exec2_pc_wdata	<= exec1_pc + 32'h4;	//one instruction
		
	end
	
endmodule
