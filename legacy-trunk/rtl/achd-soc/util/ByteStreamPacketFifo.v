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
	@brief A FIFO for processing a stream of bytes in word-sized chunks, divided into packets
	
	To write a packet:
		Assert wr_start with wr_len set to the length of this TCP segment in bytes (must be <= MSS)
		Push data words into wr_data asserting wr_en for each one
			If wr_overflow is asserted during the push, the packet is invalid and must be rolled back
		At end of packet, do one of the following:
			Strobe wr_commit high for one cycle to commit the packet and allow reads
			Strobe wr_rollback high for one cycle to destroy the pending packet
	
	To read a packet
		Wait for rd_ready to go high
		rd_len is length of the current packet (FWFT)
		To read data
			Strobe rd_en for one cycle, rd_data is valid the next cycle
		At end of packet, do one of the following:
			Strobe rd_retransmit high for one cycle to send the next packet from the start of the window
			Strobe rd_next high for one cycle to send the next packet in the window
			Strobe rd_ack high for one cycle to clear the first packet in the window
			Wait one cycle for new packet metadata to be ready
 */
module ByteStreamPacketFifo(
	clk, reset,
	wr_start, wr_len, wr_en, wr_data, wr_commit, wr_rollback, wr_overflow, wr_mdfull,
	rd_len, rd_ready, rd_retransmit, rd_next, rd_en, rd_data, rd_ack
    );

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//1024 32-bit words = 4KB = two RAMB18
	parameter DEPTH			= 1024;
	
	//max number of packets in the metadata fifo
	parameter MAX_PACKETS	= 64;
	
	//number of bits in the address bus
	`include "clog2.vh"
	localparam ADDR_BITS		= clog2(DEPTH);
	localparam META_ADDR_BITS 	= clog2(MAX_PACKETS);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Global stuff
	input wire				clk;
	input wire				reset;
	
	//Write port
	input wire				wr_start;
	input wire[10:0]		wr_len;
	input wire				wr_en;
	input wire[31:0]		wr_data;
	input wire				wr_commit;
	input wire				wr_rollback;
	output reg				wr_overflow	= 0;
	output wire				wr_mdfull;
	
	//Read port
	output wire[10:0]		rd_len;
	output wire				rd_ready;
	input wire				rd_retransmit;
	input wire				rd_next;
	input wire				rd_en;
	output wire[31:0]		rd_data;
	input wire				rd_ack;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Packet metadata FIFO
	
	localparam METADATA_WIDTH = 11 + ADDR_BITS;	//width of a packet length ( ceil(log2(MTU)) )
	
	reg[10:0]				saved_packet_len	= 0;
	reg[ADDR_BITS:0]		saved_packet_start	= 0;
	
	reg[META_ADDR_BITS : 0]	metadata_wptr		= 0;
	reg[META_ADDR_BITS : 0]	metadata_rptr		= 0;
	reg[META_ADDR_BITS : 0]	metadata_baseptr	= 0;
	
	assign wr_mdfull = (metadata_wptr == metadata_baseptr + MAX_PACKETS);	//if write pointer is at
																			//far end of buffer, we're full
	assign rd_ready = (metadata_wptr != metadata_rptr);
	
	//Indicates the FIFO is currently empty (ignore potential for retransmits)
	wire wr_mdempty = (metadata_wptr == metadata_rptr);

	wire[ADDR_BITS-1 : 0]	current_packet_start;
	
	MemoryMacro #(
		.WIDTH(METADATA_WIDTH),
		.DEPTH(MAX_PACKETS),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.USE_BLOCK(0),
		.OUT_REG(0),
		.INIT_ADDR(0),
		.INIT_FILE(""),
		.INIT_VALUE(0)
	) metadata_mem (
	
		.porta_clk(clk),
		.porta_en(wr_commit),
		.porta_addr(metadata_wptr[META_ADDR_BITS-1 : 0]),
		.porta_we(wr_commit),
		.porta_din({saved_packet_len, saved_packet_start[ADDR_BITS-1:0]}),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(1'b1),
		.portb_addr(metadata_rptr[META_ADDR_BITS-1 : 0]),
		.portb_we(1'b0),
		.portb_din({METADATA_WIDTH{1'b0}}),
		.portb_dout({rd_len, current_packet_start})
	);
	
	//Indicates we need to reset the read pointer
	reg	reset_rdptr	= 0;
		
	always @(posedge clk) begin
	
		reset_rdptr				<= 0;

		//Save the current length
		if(wr_start)
			saved_packet_len	<= wr_len;
			
		//TODO: Committing without writing the right number of bytes should trigger a rollback
		if(wr_commit) begin
			saved_packet_start	<= wr_ptr;
			metadata_wptr		<= metadata_wptr + 1'h1;
		end
	
		if(rd_retransmit) begin
			metadata_rptr	<= metadata_baseptr;
			reset_rdptr		<= 1;
		end
		
		//TODO: Should not die if we read an empty fifo
		if(rd_next) begin
			metadata_rptr	<= metadata_rptr + 1'h1;
			reset_rdptr		<= 1;
		end
		
		if(rd_ack) begin
			metadata_baseptr	<= metadata_baseptr + 1'h1;
			if(metadata_rptr == metadata_baseptr) begin
				metadata_rptr	<= metadata_rptr + 1'h1;
				reset_rdptr		<= 1;
			end
		end
		
		//If committing to the same slot in the metadata fifo that we're reading, current_packet_start will change
		//so reset the pointer
		if(wr_commit && wr_mdempty)
			reset_rdptr			<= 1;
			
		if(reset) begin
			saved_packet_len	<= 0;
			saved_packet_start	<= 0;
			metadata_rptr		<= 0;
			metadata_baseptr	<= 0;
		end

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Write logic
	
	//Write pointers
	reg[ADDR_BITS : 0]		wr_ptr			= 0;
	reg[ADDR_BITS : 0]		saved_wr_ptr	= 0;

	always @(posedge clk) begin
	
		wr_overflow			<= 0;
	
		if(wr_en) begin
			wr_ptr			<= wr_ptr + 1'h1;
			wr_overflow		<= (wr_ptr == rd_ptr + (DEPTH-1));
		end
			
		if(wr_rollback)
			wr_ptr			<= saved_wr_ptr;
			
		if(wr_commit)
			saved_wr_ptr	<= wr_ptr;
			
		if(reset) begin
			wr_ptr			<= 0;
			saved_wr_ptr	<= 0;
		end
			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Read logic
	
	//Read address
	reg[ADDR_BITS : 0]		rd_ptr			= 0;
	
	always @(posedge clk) begin
		if(reset_rdptr)
			rd_ptr		<= current_packet_start;
		if(rd_en)
			rd_ptr		<= rd_ptr + 1'h1;
			
		if(reset)
			rd_ptr		<= 0;
			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The memory
	
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
		.porta_en(wr_en),
		.porta_addr(wr_ptr[ADDR_BITS-1 : 0]),
		.porta_we(wr_en),
		.porta_din(wr_data),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(rd_en),
		.portb_addr(rd_ptr[ADDR_BITS-1 : 0]),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(rd_data)
	);

endmodule
