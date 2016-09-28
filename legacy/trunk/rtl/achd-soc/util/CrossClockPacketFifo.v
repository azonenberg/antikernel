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
	@brief A cross-clock block RAM based FIFO with registered outputs intended for storing packetized data.
	
	Packets are pushed in one word at a time but can be read random-access at the other side and popped as a unit.
 */
module CrossClockPacketFifo(
	wr_clk, wr_en, wr_data, wr_reset, wr_size,
	rd_clk, rd_en, rd_offset, rd_pop_single, rd_pop_packet, rd_packet_size, rd_data, rd_size, rd_reset
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations

	parameter WIDTH 	= 32;
	parameter DEPTH		= 11'd1024;
	
	//number of bits in the address bus
	`include "clog2.vh"
	localparam ADDR_BITS = clog2(DEPTH);
	
	//WRITE port (all signals in wr_clk domain)
	input wire					wr_clk;			//Clock for write port
	input wire					wr_en;			//Assert wr_en and put data on wr_data to push
	input wire[WIDTH-1:0]		wr_data;
	input wire					wr_reset;		//Reset write side of the FIFO
	output wire[ADDR_BITS:0]	wr_size;		//needs to be one bigger than pointers to hold fully empty size
	
	//READ port (all signals in rd_clk domain)
	input wire					rd_clk;
	input wire					rd_en;			//Read a word
	input wire[8:0]				rd_offset;		//Offset from packet start for random access reads
	input wire					rd_pop_single;	//Pop one word (exclusive with rd_pop_packet)
	input wire					rd_pop_packet;	//Pop an entire packet (exclusive with rd_pop_single)
	input wire[9:0]				rd_packet_size;	//Size of the packet to pop
	output reg[WIDTH-1:0]		rd_data	= 0;
	output wire[ADDR_BITS:0]	rd_size;
	input wire					rd_reset;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory block

	(* RAM_STYLE="block" *) reg[WIDTH-1:0] data[DEPTH-1:0];
	
	//Initialization
	integer i;
	initial begin
		for(i=0; i<DEPTH; i = i+1)
			data[i] <= 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Write logic (input clock domain)
	
	reg[ADDR_BITS:0] data_wptr			= 0;							//extra bit for empty/full detect
	wire[ADDR_BITS-1:0] data_wptr_low	= data_wptr[ADDR_BITS-1:0];		//actual pointer
	
	always @(posedge wr_clk) begin
		if(wr_en) begin
			data[data_wptr_low] <= wr_data;
			data_wptr <= data_wptr + 1'h1;
		end
		
		if(wr_reset)
			data_wptr <= 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read logic (output clock domain)
	
	reg[ADDR_BITS:0] data_rptr		= 0;							//extra bit for empty/full detect
	
	wire[ADDR_BITS-1:0] data_rptr_off	= data_rptr[ADDR_BITS-1:0] + rd_offset;
	
	//Pointer manipulation
	always @(posedge rd_clk) begin
	
		if(rd_pop_single)
			data_rptr <= data_rptr + 1'h1;
		else if(rd_pop_packet)
			data_rptr <= data_rptr + rd_packet_size;
				
		if(rd_reset)
			data_rptr <= 0;
	end
	
	//Read logic
	always @(posedge rd_clk) begin
		if(rd_en)
			rd_data <= data[data_rptr_off];
	end
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Tail pointer synchronization from input to output clock domain
	
	//Tail pointer
	//This is the lowest address to which writes are guaranteed to have committed.
	reg[ADDR_BITS:0] data_tail					= 0;
	assign rd_size = data_tail - data_rptr;

	//Synchronization stuff
	wire tail_sync_busy;
	reg tail_wr_en								= 0;
	wire tail_wr_ack;
	wire tail_rd_en;
	HandshakeSynchronizer sync_tail(
		.clk_a(wr_clk),
		.en_a(tail_wr_en),
		.ack_a(tail_wr_ack),
		.busy_a(tail_sync_busy),
		.clk_b(rd_clk),
		.en_b(tail_rd_en),
		.ack_b(tail_rd_en)
	);
	
	//Write side state machine
	reg[ADDR_BITS:0] data_tail_wdata			= 0;
	always @(posedge wr_clk) begin
		
		tail_wr_en <= 0;
		
		//If a send isn't in progress, go send stuff
		if(!tail_sync_busy) begin
			data_tail_wdata <= data_wptr;
			tail_wr_en <= 1;
		end
		
	end
	
	//Read side
	always @(posedge rd_clk) begin
		if(tail_rd_en)
			data_tail <= data_tail_wdata;
		if(rd_reset)
			data_tail <= 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Head pointer synchronization from output to input clock domain
	
	//Head pointer
	//This is the highest address from which reads are guaranteed to have committed
	reg[ADDR_BITS:0] data_head					= 0;
	assign wr_size = DEPTH + data_head - data_wptr;
	
	//Synchronization stuff
	wire head_sync_busy;
	reg head_rd_en								= 0;
	wire head_rd_ack;
	wire head_wr_en;
	HandshakeSynchronizer sync_head(
		.clk_a(rd_clk),
		.en_a(head_rd_en),
		.ack_a(head_rd_ack),
		.busy_a(head_sync_busy),
		.clk_b(wr_clk),
		.en_b(head_wr_en),
		.ack_b(head_wr_en)
	);
	
	//Read side state machine
	reg[ADDR_BITS:0] data_head_wdata			= 0;
	always @(posedge rd_clk) begin
		
		head_rd_en <= 0;
		
		//Not waiting? Send
		if(!head_sync_busy) begin
			data_head_wdata <= data_rptr;
			head_rd_en <= 1;
		end
		
	end
	
	//Write side
	always @(posedge wr_clk) begin
		if(head_wr_en)
			data_head <= data_head_wdata;
		if(wr_reset)
			data_head <= 0;
	end

endmodule
