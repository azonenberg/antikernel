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
	@brief GRAFTON 32-bit MCU core
	
	5-stage pipeline, area optimized, simple direct-mapped cache.
	
	Simple programmable MMU.
	
	Binary compatible with "mips-elf" gcc target if the appropriate libc and flags (-mips1) are used.
	
	@module
	@opcodefile		GraftonCPURPCDebugOpcodes.constants
	
	@rpcfn			DEBUG_CONNECT
	@brief			Connect to the debugger
	
	@rpcfn_ok		DEBUG_CONNECT
	@brief			GDB bridge connected
	
	@rpcfn			DEBUG_HALT
	@brief			Halt the target
	
	@rpcfn_ok		DEBUG_HALT
	@brief			Target halted
	
	@rpcfn			DEBUG_GET_STATUS
	@brief			Query status
	
	@rpcfn_ok		DEBUG_GET_STATUS
	@param 			freeze		d0[0:0]:dec					Freeze flag
	@param 			bad_insn	d0[1:1]:dec					Bad-instruction flag
	@param 			segfault	d0[2:2]:dec					Segfault flag
	@param			pc			d1[31:0]:hex				Program counter
	@param			badvaddr	d2[31:0]:hex				Bad virtual address
	@brief			Status retrieved
	
	@rpcfn			DEBUG_GET_MDU
	@brief			Query multiply/divide unit status
	
	@rpcfn_ok		DEBUG_GET_MDU
	@param			lo			d1[31:0]:hex				Low register
	@param			hi			d2[31:0]:hex				High register
	@brief			MDU status
	
	@rpcfn			DEBUG_READ_REGISTERS
	@param			ra			d1[4:0]:enum				GraftonCPURegisterIDs.constants
	@param			rb			d1[4:0]:enum				GraftonCPURegisterIDs.constants
	@brief			Read registers
	
	@rpcfn_ok		DEBUG_READ_REGISTERS
	@param			ra			d1[31:0]:hex				Register A
	@param			rb			d2[31:0]:hex				Register B
	@brief			Register values
	
	@rpcfn			DEBUG_RESUME
	@brief			Resume a halted target
	
	@rpcfn_ok		DEBUG_RESUME
	@brief			Target resumed
	
	@rpcfn			DEBUG_READ_MEMORY
	@param			addr		d1[31:0]:hex				Address to read
	@brief			Read memory from the target
	
	@rpcfn_ok		DEBUG_READ_MEMORY
	@param			data		d1[31:0]:hex				Data read from memory
	@brief			Memory read
	
	@rpcfn			DEBUG_CLEAR_SEGFAULT
	@brief			Clear the "segfault" flag
	
	@rpcfn_ok		DEBUG_CLEAR_SEGFAULT
	@brief			Segfault flag cleared
	
	@rpcfn			DEBUG_SET_HWBREAK
	@param			addr		d1[31:0]:hex				Breakpoint address
	@brief			Set a hardware breakpoint
	
	@rpcfn_ok		DEBUG_SET_HWBREAK
	@brief			Hardware breakpoint set
	
	@rpcfn			DEBUG_CLEAR_HWBREAK
	@param			addr		d1[31:0]:hex				Breakpoint address
	@brief			Clear a hardware breakpoint
	
	@rpcfn_ok		DEBUG_CLEAR_HWBREAK
	@brief			Hardware breakpoint cleared
	
	@rpcfn			DEBUG_SINGLE_STEP
	@brief			Step by one instruction
	
	@rpcfn_ok		DEBUG_SINGLE_STEP
	@brief			Step completed
	
	@rpcint			DEBUG_SEGFAULT
	@brief			Segfault hit
	
	@rpcint			DEBUG_BREAKPOINT
	@brief			Segfault hit
 */
module GraftonCPU(
	
	//Clocks
	clk,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack/*,

	//Status outputs
	segfault, bad_instruction,
	
	//Debug signals
	trace_flag,
	execute_pc,
	writeback_we, writeback_regid, writeback_regval*/
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire clk;

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
	/*
	//Status outputs
	output segfault;
	output bad_instruction;

	//Debug signals
	output trace_flag;
	output execute_pc;
	output writeback_we;
	output writeback_regid;
	output writeback_regval;
	*/
	//Parameters to be passed through to the MMU
	parameter bootloader_host = 16'h0000;
	parameter bootloader_addr = 32'h00000000;
	
	//Debug-enable parameters
	parameter debug_mode				=	0;
	
	//Profiling parameters
	parameter profiling					= 0;
	
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
		.rpc_fab_inbox_full()
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// L1 cache and MMU
	
	//I-side L1 cache interface
	wire iside_rd_en;
	wire[31:0] iside_rd_addr;
	wire[31:0] iside_rd_data;
	wire iside_rd_valid;
	
	//D-side L1 cache interface
	wire dside_wr_en;
	wire[31:0] dside_cpu_addr;
	wire[31:0] dside_wr_data;
	wire[3:0] dside_wr_mask;
	wire dside_wr_done;
	wire dside_rd_en;
	wire[31:0] dside_rd_data;
	wire dside_rd_valid;
	
	//CPU control interface
	wire flush_en;
	wire segfault;
	wire[31:0] badvaddr;
	
	wire mmu_wr_en;
	wire[8:0] mmu_wr_page_id;
	wire[31:0] mmu_wr_phyaddr;
	wire[15:0] mmu_wr_nocaddr;
	wire[2:0] mmu_wr_permissions;
	
	wire dma_op_active; 
	wire[15:0] dma_op_addr;
	
	//Debugger override interface
	wire debug_mem_active;
	wire debug_dside_rd_en;
	wire debug_dside_wr_en;
	wire[31:0] debug_dside_cpu_addr;
	
	//D-side bus after mux for debugger
	reg dside_rd_en_final = 0;
	reg dside_wr_en_final = 0;
	reg[31:0] dside_cpu_addr_final = 0;
	generate
		always @(*) begin
			
			//Use default stuff
			dside_rd_en_final <= dside_rd_en;
			dside_wr_en_final <= dside_wr_en;
			dside_cpu_addr_final <= dside_cpu_addr;
			
			//Debug override
			if(debug_mode) begin
				
				if(debug_mem_active) begin
					dside_cpu_addr_final <= debug_dside_cpu_addr;
					dside_rd_en_final <= 0;
					dside_wr_en_final <= 0;
			
					if(debug_dside_rd_en)
						dside_rd_en_final <= 1;

				end
				
			end
			
		end
	endgenerate
	
	//The actual cache block
	wire dma_op_cleared;
	wire dma_op_segfaulted;
	wire debug_clear_segfault;
	
	wire bootloader_start;
	wire[31:0] bootloader_rd_addr;
	wire bootloader_rd_en;
	wire[31:0] bootloader_rd_data;
	
	wire bootloader_mmu_wr_en;
	wire[8:0] bootloader_mmu_wr_page_id;
	wire[31:0] bootloader_mmu_wr_phyaddr;	//Note that phyaddr is relative to start of the ELF file in ROM
											//and is not an absolute address
											
	wire bootloader_pc_wr;
	wire[31:0] bootloader_pc_out;
	
	`include "GraftonCPUPagePermissions_constants.v"
									
	wire[8:0] mmu_wr_page_id_final;
	assign mmu_wr_page_id_final = bootloader_mmu_wr_en ?
		bootloader_mmu_wr_page_id :
		mmu_wr_page_id;
	wire[31:0] mmu_wr_phyaddr_final;
	assign mmu_wr_phyaddr_final = bootloader_mmu_wr_en ?
		(bootloader_mmu_wr_phyaddr + bootloader_addr) :
		mmu_wr_phyaddr;
	wire[15:0] mmu_wr_nocaddr_final;
	assign mmu_wr_nocaddr_final = bootloader_mmu_wr_en ?
		bootloader_host :
		mmu_wr_nocaddr;
	wire[2:0] mmu_wr_permissions_final;
	assign mmu_wr_permissions_final = bootloader_mmu_wr_en ?
		PAGE_READ_EXECUTE :
		mmu_wr_permissions;
		
	wire	imiss_start;
	wire	imiss_done;
	wire	dmiss_start;
	wire	dmiss_done;
	
	GraftonCPUL1Cache #(
			.bootloader_addr(bootloader_addr),
			.bootloader_host(bootloader_host),
			.NOC_ADDR(NOC_ADDR)
		) cache (
		
			//Clocking
			.clk(clk),
			
			//NoC interface
			.dma_tx_en(dma_tx_en),
			.dma_tx_data(dma_tx_data),
			.dma_tx_ack(dma_tx_ack),
			.dma_rx_en(dma_rx_en),
			.dma_rx_data(dma_rx_data),
			.dma_rx_ack(dma_rx_ack),
			
			//I-side interface
			.iside_rd_en(iside_rd_en),
			.iside_cpu_addr(iside_rd_addr),
			.iside_rd_data(iside_rd_data),
			.iside_rd_valid(iside_rd_valid),
			
			//D-side interface
			.dside_cpu_addr(dside_cpu_addr_final),
			.dside_wr_en(dside_wr_en_final),
			.dside_wr_data(dside_wr_data),
			.dside_wr_mask(dside_wr_mask),
			.dside_wr_done(dside_wr_done),
			.dside_rd_en(dside_rd_en_final),
			.dside_rd_data(dside_rd_data),
			.dside_rd_valid(dside_rd_valid),
			
			//CPU control interface
			.flush_en(flush_en),
			.mmu_wr_en(mmu_wr_en || bootloader_mmu_wr_en),
			.mmu_wr_page_id(mmu_wr_page_id_final),
			.mmu_wr_phyaddr(mmu_wr_phyaddr_final),
			.mmu_wr_nocaddr(mmu_wr_nocaddr_final),
			.mmu_wr_permissions(mmu_wr_permissions_final),
			.segfault(segfault),
			.badvaddr(badvaddr),
			.debug_clear_segfault(debug_clear_segfault),
			
			//Status interface
			.dma_op_active(dma_op_active),
			.dma_op_addr(dma_op_addr),
			.dma_op_cleared(dma_op_cleared),
			.dma_op_segfaulted(dma_op_segfaulted),
			
			//Bootloader interface
			.bootloader_start(bootloader_start),
			.bootloader_rd_addr(bootloader_rd_addr),
			.bootloader_rd_en(bootloader_rd_en),
			.bootloader_rd_data(bootloader_rd_data),
			.bootloader_pc_wr(bootloader_pc_wr),
			
			//Profiling
			.imiss_start(imiss_start),
			.imiss_done(imiss_done),
			.dmiss_start(dmiss_start),
			.dmiss_done(dmiss_done)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Debug stuff needed before everything else
	
	//Combinatorially set if the current RPC message should be sent to the debug system
	wire debug_message;
	
	//Set if a debug message is pending but not processed
	wire debug_message_pending;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The register file
	
	wire[4:0] decode_regid_a;
	wire[4:0] decode_regid_b;
	
	//If processing a DEBUG_READ_REGISTERS call, read those regs instead
	reg[4:0] decode_regid_a_final = 0;
	reg[4:0] decode_regid_b_final = 0;
	generate
		always @(*) begin
		
			//Normal stuff
			decode_regid_a_final <= decode_regid_a;
			decode_regid_b_final <= decode_regid_b;
		
			if(debug_mode) begin
				if(freeze) begin
					decode_regid_a_final <= rpc_fab_rx_d1[4:0];
					decode_regid_b_final <= rpc_fab_rx_d2[4:0];
				end
			end
		end
	endgenerate
	
	wire[31:0] execute_regval_a;
	wire[31:0] execute_regval_b;
	
	wire writeback_we;
	wire[4:0] writeback_regid;
	wire[31:0] writeback_regval;
	
	wire decode_stallin;
	
	GraftonCPURegisterFile regfile(
		.clk(clk),
		
		.decode_stallin(decode_stallin),
		.decode_regid_a(decode_regid_a_final),
		.decode_regid_b(decode_regid_b_final),
		
		.execute_regval_a(execute_regval_a),
		.execute_regval_b(execute_regval_b),
		
		.writeback_we(writeback_we),
		.writeback_regid(writeback_regid),
		.writeback_regval(writeback_regval)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FETCH stage of the pipeline
	
	wire freeze;
	
	wire decode_stallout;
	wire execute_stallout;
	wire mem_stallout;
	
	wire		execute_jumping;
	wire[31:0]	execute_jump_address;
	
	wire		step_en;
	wire		step_done;
	
	GraftonCPUFetchStage fetch(
		.clk(clk),
		
		.iside_rd_en(iside_rd_en),
		.iside_rd_addr(iside_rd_addr),
		.iside_rd_valid(iside_rd_valid),
		
		.execute_jumping(execute_jumping),
		.execute_jump_address(execute_jump_address),
		
		.bootloader_pc_wr(bootloader_pc_wr),
		.bootloader_pc_out(bootloader_pc_out),
		
		.step_en(step_en),
		.step_done(step_done),
		
		.freeze(freeze),
		.stall_in(decode_stallout || execute_stallout || mem_stallout)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DECODE stage of the pipeline
	
	wire execute_bubble;
	wire execute_rtype;
	wire[5:0] execute_opcode;
	wire[5:0] execute_func;
	wire[4:0] execute_regid_d;
	wire[15:0] execute_immval;
	wire[4:0] execute_regid_a;
	wire[4:0] execute_regid_b;
	wire[4:0] execute_shamt;
	wire[4:0] execute_coproc_op;
	wire[4:0] execute_branch_op;
		
	wire[31:0] execute_pc;
	wire[25:0] execute_jump_offset;
	
	assign decode_stallin = execute_stallout  || mem_stallout;
	
	GraftonCPUDecodeStage decode(
		.clk(clk),
		
		.iside_rd_data(iside_rd_data),
		.iside_rd_valid(iside_rd_valid),
		.iside_rd_addr(iside_rd_addr),
		
		.decode_regid_a(decode_regid_a),
		.decode_regid_b(decode_regid_b),
		.execute_regid_d(execute_regid_d),
		
		.execute_bubble(execute_bubble),
		.execute_rtype(execute_rtype),
		.execute_opcode(execute_opcode),
		.execute_func(execute_func),
		.execute_immval(execute_immval),
		.execute_regid_a(execute_regid_a),
		.execute_regid_b(execute_regid_b),
		.execute_shamt(execute_shamt),
		.execute_coproc_op(execute_coproc_op),
		.execute_branch_op(execute_branch_op),
		
		.bootloader_pc_wr(bootloader_pc_wr),
		.bootloader_pc_out(bootloader_pc_out),
		
		.execute_pc(execute_pc),
		.execute_jump_offset(execute_jump_offset),
		
		.stall_out(decode_stallout),
		.stall_in(decode_stallin),
		
		.freeze(freeze)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// EXECUTE stage of the pipeline
	
	wire mem_regwrite;
	wire[4:0] mem_regid_d;
	wire[31:0] mem_regval;
	
	wire[31:0] execute_regval_a_fwd;
	wire[31:0] execute_regval_b_fwd;
	
	wire cp0_wr_en;
	wire cp0_rd_en;
	wire[31:0] cp0_rd_data;
	
	wire[1:0] mem_read_size;	//0=byte, 1=halfword, 2=word, 3=undefined
	wire mem_read_sx;			//1 = sign extend, 0 = zero extend
	wire[1:0] mem_read_lsb;		//LSBs of read address
	
	wire trace_flag;
	
	wire rpc_fab_tx_en_cpu;
	
	wire bad_instruction;
	wire[5:0] bad_instruction_opcode;
	wire[5:0] bad_instruction_func;
	wire[31:0] bad_instruction_pc;
	
	wire[31:0] execute_mem_addr;
	
	wire rpc_fab_rx_en_cpu;
	wire rpc_fab_rx_done_cpu;
	
	wire[31:0] mdu_lo;
	wire[31:0] mdu_hi;
	
	//True if an instruction was ISSUED this cycle.
	//This will over-count missed D-side reads, etc.
	wire	execute_instruction_issued	= !mem_stallout && !execute_bubble;
	
	GraftonCPUExecuteStage execute(
		.clk(clk),
		
		.execute_regval_a(execute_regval_a_fwd),
		.execute_regval_b(execute_regval_b_fwd),
		.execute_regid_d(execute_regid_d),
		
		.execute_rtype(execute_rtype),
		.execute_bubble(execute_bubble),
		.execute_opcode(execute_opcode),
		.execute_func(execute_func),
		.execute_immval(execute_immval),
		.execute_jump_offset(execute_jump_offset),
		.execute_pc(execute_pc),
		.execute_shamt(execute_shamt),
		.execute_coproc_op(execute_coproc_op),
		.execute_branch_op(execute_branch_op),
		
		.stall_in(mem_stallout),
		.stall_out(execute_stallout),
		
		.mem_regid_d(mem_regid_d),
		.mem_regval(mem_regval),
		.mem_regwrite(mem_regwrite),
		
		.mem_read_size(mem_read_size),
		.mem_read_sx(mem_read_sx),
		.mem_read_lsb(mem_read_lsb),
		
		.cp0_wr_en(cp0_wr_en),
		.cp0_rd_en(cp0_rd_en),
		.cp0_rd_data(cp0_rd_data),
		
		.rpc_fab_tx_en(rpc_fab_tx_en_cpu),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		.rpc_fab_rx_en(rpc_fab_rx_en_cpu),
		.rpc_fab_rx_done(rpc_fab_rx_done_cpu),
		
		.dside_cpu_addr(dside_cpu_addr),
		.dside_rd_en(dside_rd_en),
		.dside_wr_en(dside_wr_en),
		.dside_wr_data(dside_wr_data),
		.dside_wr_mask(dside_wr_mask),
		
		.mmu_wr_en(mmu_wr_en),
		.cache_flush_en(flush_en),
		
		.mdu_lo(mdu_lo),
		.mdu_hi(mdu_hi),
		
		.trace_flag(trace_flag),
		
		.execute_jumping(execute_jumping),
		.execute_jump_address(execute_jump_address),
		
		.freeze(freeze),
		.bad_instruction(bad_instruction),
		.bad_instruction_opcode(bad_instruction_opcode),
		.bad_instruction_func(bad_instruction_func),
		.bad_instruction_pc(bad_instruction_pc)
		);
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// MEM stage of the pipeline
	
	GraftonCPUMemStage mem(
		.clk(clk),
		
		.stall_out(mem_stallout),
		
		.mem_regwrite(mem_regwrite),
		.mem_regid_d(mem_regid_d),
		.mem_regval(mem_regval),
		
		.mem_read_size(mem_read_size),
		.mem_read_sx(mem_read_sx),
		.mem_read_lsb(mem_read_lsb),
		
		.dside_wr_en(dside_wr_en),
		.dside_wr_done(dside_wr_done),
		
		.dside_cpu_addr(dside_cpu_addr),
		.dside_rd_en(dside_rd_en),
		.dside_rd_data(dside_rd_data),
		.dside_rd_valid(dside_rd_valid),
		
		.writeback_regwrite(writeback_we),
		.writeback_regid_d(writeback_regid),
		.writeback_regval(writeback_regval),
		
		.freeze(freeze)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// WRITEBACK stage of the pipeline
	
	//Nothing here
	
	//synthesis translate_off
	/*
	reg[31:0] mem_pc = 0;
	reg[31:0] writeback_pc = 0;
	always @(posedge clk) begin
		if(!mem_stallout && !execute_bubble)
			mem_pc <= execute_pc;
		if(!mem_stallout)
			writeback_pc <= mem_pc;
		if(writeback_we && (writeback_regid != 1) && !segfault)
			$display("Setting r%d to %x (%x)", writeback_regid, writeback_regval, writeback_pc);
	end
	*/
	//synthesis translate_on
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Combinatorial forwarding for EXECUTE stage from later in the pipeline
	
	//Cache the most recent write to avoid problems during the last cycle of a stall
	reg[4:0] post_wb_regid = 0;
	reg[31:0] post_wb_regval = 0;
	always @(posedge clk) begin
		if(writeback_we) begin
			post_wb_regid <= writeback_regid;
			post_wb_regval <= writeback_regval;
		end
	end
	
	//If processing a DEBUG_READ_REGISTERS call, read those regs instead
	reg[4:0] execute_regid_a_final = 0;
	reg[4:0] execute_regid_b_final = 0;
	generate
		always @(*) begin
		
			//Normal stuff
			execute_regid_a_final <= execute_regid_a;
			execute_regid_b_final <= execute_regid_b;
		
			if(debug_mode) begin
				if(freeze) begin
					execute_regid_a_final <= rpc_fab_rx_d1[4:0];
					execute_regid_b_final <= rpc_fab_rx_d2[4:0];
				end
			end
		end
	endgenerate
	
	GraftonCPUPipelineForwarding fwd_a(
		.execute_regval(execute_regval_a),
		.execute_regid(execute_regid_a_final),
		
		.mem_regwrite(mem_regwrite),
		.mem_regid_d(mem_regid_d),
		.mem_regval(mem_regval),
		
		.writeback_regwrite(writeback_we),
		.writeback_regid_d(writeback_regid),
		.writeback_regval(writeback_regval),
		
		.post_wb_regid(post_wb_regid),
		.post_wb_regval(post_wb_regval),
	
		.execute_regval_fwd(execute_regval_a_fwd)
	);
	
	GraftonCPUPipelineForwarding fwd_b(
		.execute_regval(execute_regval_b),
		.execute_regid(execute_regid_b_final),
		
		.mem_regwrite(mem_regwrite),
		.mem_regid_d(mem_regid_d),
		.mem_regval(mem_regval),
		
		.writeback_regwrite(writeback_we),
		.writeback_regid_d(writeback_regid),
		.writeback_regval(writeback_regval),
		
		.post_wb_regid(post_wb_regid),
		.post_wb_regval(post_wb_regval),
	
		.execute_regval_fwd(execute_regval_b_fwd)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Boot loader
	
	GraftonCPUELFLoader bootloader (
		.clk(clk),
		
		.start(bootloader_start),
		
		.rd_addr(bootloader_rd_addr),
		.rd_en(bootloader_rd_en),
		.rd_data(bootloader_rd_data),
		
		.mmu_wr_en(bootloader_mmu_wr_en),
		.mmu_wr_page_id(bootloader_mmu_wr_page_id),
		.mmu_wr_phyaddr(bootloader_mmu_wr_phyaddr),
		.pc_wr(bootloader_pc_wr),
		.pc_out(bootloader_pc_out)/*,
		
		.state(bootloader_state)*/
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Coprocessor 0 - RPC transceiver and debug monitor
	
	GraftonCPUCoprocessor0 #(
		.debug_mode(debug_mode),
		.bootloader_host(bootloader_host),
		.bootloader_addr(bootloader_addr),
		.profiling(profiling)
	) cp0 (
		.clk(clk),
		
		.cp0_rd_en(cp0_rd_en),
		.cp0_rd_data(cp0_rd_data),
		.cp0_wr_en(cp0_wr_en),
		
		.mmu_wr_page_id(mmu_wr_page_id),
		.mmu_wr_phyaddr(mmu_wr_phyaddr),
		.mmu_wr_nocaddr(mmu_wr_nocaddr),
		.mmu_wr_permissions(mmu_wr_permissions),
		
		.debug_mem_active(debug_mem_active),
		.debug_message(debug_message),
		.debug_message_pending(debug_message_pending),
		.debug_dside_rd_en(debug_dside_rd_en),
		.debug_dside_wr_en(debug_dside_wr_en),
		.debug_dside_cpu_addr(debug_dside_cpu_addr),
		.debug_clear_segfault(debug_clear_segfault),
		
		.dside_rd_valid(dside_rd_valid),
		.dside_rd_data(dside_rd_data),
		
		.dma_op_active(dma_op_active),
		.dma_op_addr(dma_op_addr),
		.dma_op_cleared(dma_op_cleared),
		.dma_op_segfaulted(dma_op_segfaulted),
		
		.freeze(freeze),
		.bad_instruction(bad_instruction),
		.badvaddr(badvaddr),
		.segfault(segfault),
		
		.step_en(step_en),
		.step_done(step_done),
		
		.execute_pc(execute_pc),
		.execute_regid_b(execute_regid_b),
		.execute_regval_a_fwd(execute_regval_a_fwd),
		.execute_regval_b_fwd(execute_regval_b_fwd),
		
		.mem_regval(mem_regval),
		.mem_regid_d(mem_regid_d),
		
		.mdu_lo(mdu_lo),
		.mdu_hi(mdu_hi),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_type(rpc_fab_rx_type),
		.rpc_fab_rx_src_addr(rpc_fab_rx_src_addr),
		.rpc_fab_rx_dst_addr(rpc_fab_rx_dst_addr),
		.rpc_fab_rx_callnum(rpc_fab_rx_callnum),
		.rpc_fab_rx_d0(rpc_fab_rx_d0),
		.rpc_fab_rx_d1(rpc_fab_rx_d1),
		.rpc_fab_rx_d2(rpc_fab_rx_d2),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_rx_en_cpu(rpc_fab_rx_en_cpu),
		.rpc_fab_rx_done_cpu(rpc_fab_rx_done_cpu),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		.rpc_fab_tx_dst_addr(rpc_fab_tx_dst_addr),
		.rpc_fab_tx_callnum(rpc_fab_tx_callnum),
		.rpc_fab_tx_type(rpc_fab_tx_type),
		.rpc_fab_tx_d0(rpc_fab_tx_d0),
		.rpc_fab_tx_d1(rpc_fab_tx_d1),
		.rpc_fab_tx_d2(rpc_fab_tx_d2),
		.rpc_fab_tx_en_cpu(rpc_fab_tx_en_cpu),
		
		.bootloader_pc_wr(bootloader_pc_wr),
		
		//profiling
		.execute_instruction_issued(execute_instruction_issued),
		.imiss_start(imiss_start),
		.imiss_done(imiss_done),
		.dmiss_start(dmiss_start),
		.dmiss_done(dmiss_done),
		.iside_rd_valid(iside_rd_valid)
		);
	
endmodule
