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

module SaratogaCPURPCTransmitFifo(
	clk,
	rpc_tx_fifo_rd, rpc_tx_fifo_empty, rpc_tx_fifo_dout,
	exec1_rpc_tx_fifo_wr, exec0_rpc_tx_fifo_wsize, exec0_tid,
	exec0_unit0_rs, exec0_unit0_rt, exec0_unit1_rs, exec0_unit1_rt
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../util/clog2.vh"
	
	//Our address
	parameter NOC_ADDR				= 16'h0;
	
	//Number of thread contexts
	parameter MAX_THREADS			= 32;
	
	//Number of bits in a thread ID
	localparam TID_BITS				= clog2(MAX_THREADS);
	
	//Write depth
	parameter RPC_TX_FIFO_DEPTH		= 512;
	localparam TX_FIFO_BITS			= clog2(RPC_TX_FIFO_DEPTH);
	
	//Base address for threads
	localparam TBASE_ADDR = NOC_ADDR + MAX_THREADS;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clock
	input wire						clk;
	
	//Read port
	input wire						rpc_tx_fifo_rd;
	output wire						rpc_tx_fifo_empty;
	output wire[127:0]				rpc_tx_fifo_dout;
	
	//Write port
	input wire						exec1_rpc_tx_fifo_wr;
	output wire[TX_FIFO_BITS : 0]	exec0_rpc_tx_fifo_wsize;
	input wire[TID_BITS-1 : 0]		exec0_tid;
	input wire[31:0]				exec0_unit0_rs;
	input wire[31:0]				exec0_unit0_rt;
	input wire[31:0]				exec0_unit1_rs;
	input wire[31:0]				exec0_unit1_rt;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO stuff
	
	reg[127:0]						exec1_rpc_tx_fifo_din = 0;
		
	//Transmit FIFO is four 18kbit block RAMs
	SingleClockFifo #(
		.WIDTH(128),
		.DEPTH(RPC_TX_FIFO_DEPTH),
		.USE_BLOCK(1),
		.OUT_REG(1),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_FULL(0)
	) fifo (
		.clk(clk),
		.reset(1'b0),
		
		.wr(exec1_rpc_tx_fifo_wr),
		.din(exec1_rpc_tx_fifo_din),
		.rd(rpc_tx_fifo_rd),
		.dout(rpc_tx_fifo_dout),
		
		.overflow(),
		.underflow(),
		.empty(rpc_tx_fifo_empty),
		.full(),
		.rsize(),
		.wsize(exec0_rpc_tx_fifo_wsize)
	);
	
	//Combinatorial FIFO write logic (EXEC0 stage)
	always @(posedge clk) begin
	
		exec1_rpc_tx_fifo_din[127:112]			<= TBASE_ADDR;	//subnet prefix
		exec1_rpc_tx_fifo_din[112 +: TID_BITS]	<= exec0_tid;	//thread ID
	
		exec1_rpc_tx_fifo_din[111:96]			<= exec0_unit0_rs[15:0];
		exec1_rpc_tx_fifo_din[95:64]			<= exec0_unit0_rt;
		exec1_rpc_tx_fifo_din[63:32]			<= exec0_unit1_rs;
		exec1_rpc_tx_fifo_din[31:0]				<= exec0_unit1_rt;
	end

endmodule
