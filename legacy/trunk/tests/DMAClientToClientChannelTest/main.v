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
	@brief Formal validation test harness for DMATransceiver
	
	The goal of this test is to prove that when a DMATransceiverCore_tx talks to a DMATransceiverCore_rx
	the packets are always forwarded correctly and unchanged.
 */
module main(
	clk,
	tx_src_addr, tx_dst_addr, tx_op, tx_addr, tx_len, tx_en, tx_buf_out,
	rx_ready
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire			clk;
	
	input wire[15:0]	tx_src_addr;
	input wire[15:0]	tx_dst_addr;
	input wire[1:0]		tx_op;
	input wire[31:0]	tx_addr;
	input wire[9:0]		tx_len;
	input wire			tx_en;
	input wire[31:0]	tx_buf_out;
	
	input wire			rx_ready;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual transceivers
	
	//The DMA bus between endpoints
	wire		link_en;
	wire[31:0]	link_data;
	wire		link_ack;
	
	//Transmit status flags
	wire		tx_done;
	wire		tx_busy;
	wire		tx_rd;
	wire[9:0]	tx_raddr;

	DMATransceiverCore_tx #(
		.LEAF_PORT(1),
		.LEAF_ADDR(16'h8001)
	) txvr (
		.clk(clk),
		.dma_tx_en(link_en),
		.dma_tx_data(link_data),
		.dma_tx_ack(link_ack),
		.tx_done(tx_done),
		.tx_busy(tx_busy),
		.tx_src_addr(tx_src_addr),
		.tx_dst_addr(tx_dst_addr),
		.tx_op(tx_op),
		.tx_addr(tx_addr),
		.tx_len(tx_len),
		.tx_en(tx_en),
		.tx_rd(tx_rd),
		.tx_raddr(tx_raddr),
		.tx_buf_out(tx_buf_out)
	);
	
	//Receive status flags
	wire		rx_en;
	wire[15:0]	rx_src_addr;
	wire[15:0]	rx_dst_addr;
	wire[1:0]	rx_op;
	wire[31:0]	rx_addr;
	wire[9:0]	rx_len;
	wire		rx_we;
	wire[8:0]	rx_buf_waddr;
	wire[31:0]	rx_buf_wdata;
	wire		rx_state_header_2;
	DMATransceiverCore_rx rx (
		.clk(clk),
		.dma_rx_en(link_en),
		.dma_rx_data(link_data),
		.dma_rx_ack(link_ack),
		.rx_ready(rx_ready),
		.rx_en(rx_en),
		.rx_src_addr(rx_src_addr),
		.rx_dst_addr(rx_dst_addr),
		.rx_op(rx_op),
		.rx_addr(rx_addr),
		.rx_len(rx_len),
		.rx_we(rx_we),
		.rx_buf_waddr(rx_buf_waddr),
		.rx_buf_wdata(rx_buf_wdata),
		.rx_state_header_2(rx_state_header_2)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Transmit verification logic
	
	`include "DMARouter_constants.v"
	
	reg[2:0]	state	= 0;
	reg[5:0]	count	= 0;
	reg			hang	= 0;
	
	reg[31:0]	expected_header0	= 0;
	reg[31:0]	expected_header1	= 0;
	reg[31:0]	expected_header2	= 0;
	reg[31:0]	tx_buf_out_ff		= 0;
	
	wire		tx_has_body			= (tx_len != 0) && (tx_op != DMA_OP_READ_REQUEST);
	reg			tx_has_body_ff		= 0;
	reg[9:0]	tx_len_ff	= 0;
	reg[9:0]	tx_raddr_ff			= 0;
	
	always @(posedge clk) begin
		
		//cap length of test
		if(hang) begin
		end
		
		else begin
		
			tx_has_body_ff		<= tx_has_body;
			tx_len_ff	<= tx_len;
			tx_raddr_ff			<= tx_raddr;
			tx_buf_out_ff		<= tx_buf_out;
		
			//Limit the proof to 64 cycles in length for now
			count	<= count + 1;
			if(count == 63)
				hang	<= 1;
		
			//Write data is passthrough
			assert(rx_buf_wdata == link_data);
			
			//Expected headers
			expected_header0	<= {16'h8001, 		tx_dst_addr};
			if(tx_len > 512)
				expected_header1	<= {tx_op, 20'h0,	10'd512};
			else
				expected_header1	<= {tx_op, 20'h0,	tx_len};
			expected_header2	<= tx_addr;
			
			case(state)
				
				//IDLE - Wait for something to happen
				0: begin
				
					//Should not be sending, reading data, or done
					assert(link_en == 0);
					assert(tx_rd == 0);
					assert(tx_raddr == 0);
					assert(tx_busy == 0);
					assert(tx_done == 0);
					
					//value of data is undefined when idle
				
					//Start doing things if a transmit happens
					if(tx_en)
						state	<= 1;
				end
				
				//Transmit just started
				1: begin
				
					assert(tx_busy == 1);
				
					//sending first header
					assert(link_en == 1);
					assert(link_data == expected_header0);
					
					//not reading for a bit
					assert(tx_rd == 0);
					assert(tx_raddr == 0);
					assert(tx_done == 0);
					
					//Wait for ACK
					if(link_ack)
						state	<= 2;
				end
				
				//header word
				2: begin
					
					assert(tx_busy == 1);
					
					//sending second header, but no link_en flag
					assert(link_en == 0);
					assert(link_data == expected_header1);
					assert(tx_done == 0);
					
					//should be reading the 0th word
					assert(tx_rd == 1);
					assert(tx_raddr == 0);
					
					state	<= 3;
					
				end
				
				//last header word
				3: begin
					
					//sending third header, but no link_en flag
					assert(link_en == 0);
					assert(link_data == expected_header2);
					
					//prepare to read
					assert(tx_raddr == 1);
					
					//should be reading if length is > 1, and it's not a read or empty request (no body)
					if(tx_has_body_ff) begin
						if(tx_len_ff > 1)
							assert(tx_rd == 1);
						state	<= 4;
						assert(tx_busy == 1);
						assert(tx_done == 0);
					end
					
					//nope, done sending the packet
					else begin
						assert(tx_busy == 0);
						assert(tx_rd == 0);
						assert(tx_done == 1);
						state		<= 0;
						
						//if tx_en was asserted now, go straight back into the next packet (no IFG needed)
						if(tx_en)
							state	<= 1;
					end
				
				end
				
				//sending data, if any
				4: begin
					
					//Should be the data
					assert(link_data == tx_buf_out_ff);
					
					//Should be reading data
					assert(tx_raddr == tx_raddr_ff + 10'h1);
					
					//Stop if we just sent the last word
					if(tx_raddr_ff >= tx_len_ff) begin
						state 			<= 0;
						assert(tx_done == 1);
						assert(tx_busy == 0);
						assert(tx_rd == 0);
						
						//if tx_en was asserted now, go straight back into the next packet (no IFG needed)
						if(tx_en)
							state	<= 1;
					end
					else begin
						assert(tx_busy == 1);
						assert(tx_done == 0);
					
						//Should be reading, unless it's the last word
						if( (tx_raddr_ff + 1) < tx_len_ff)
							assert(tx_rd == 1);
						else
							assert(tx_rd == 0);
							
					end
				
				end
				
			endcase
		end

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Receive verification logic
	
	reg[2:0]	rxstate = 0;
	
	reg[15:0]	tx_dst_addr_ff			= 0;
	reg[15:0]	rx_dst_addr_expected	= 0;
	reg			rx_ready_ff				= 0;
	reg[1:0]	tx_op_ff				= 0;
	reg[1:0]	rx_op_expected			= 0;
	reg[9:0]	rx_len_expected			= 0;
	reg[31:0]	tx_addr_ff				= 0;
	reg[31:0]	rx_addr_expected		= 0;
	reg[31:0]	rx_buf_wdata_expected	= 0;
	reg[9:0]	rx_buf_waddr_ff			= 0;
	
	wire[9:0]	rx_buf_waddr_ff_inc		= rx_buf_waddr_ff + 1;
	
	always @(posedge clk) begin
	
		if(hang) begin
			
		end
		
		else begin
		
			assert(rx_buf_wdata == link_data);
		
			rx_ready_ff	<= 1;
		
			//We shouldn't ACK transmissions unless they were actually sent, and we're ready for them.
			//Should not be ACKing except when idle.
			if(link_ack) begin
				assert(link_en == 1);
				assert(rx_ready_ff == 1);
				assert(rxstate == 0);
			end
			
			case(rxstate)
				
				//Idle, wait for a new packet to arrive
				0: begin
				
					//Keep track of what the transmit address should be
					//Everything is delayed by two clocks
					tx_dst_addr_ff				<= tx_dst_addr;
					rx_dst_addr_expected		<= tx_dst_addr_ff;
					
					//Keep track of what the opcode header should be
					tx_op_ff					<= tx_op;
				
					//Idle, nothing going on
					//Can't make any assumptions about the header outputs since those hold values from the last message
					//rx_buf_waddr will be freely counting

					assert(rx_en == 0);
					assert(rx_we == 0);
					
					//If a transmit was acknowledged, we get the routing header next cycle
					if(link_ack)
						rxstate	<= 1;
					
				end
				
				//Routing header
				1: begin
					
					assert(rx_dst_addr == rx_dst_addr_expected);
					assert(rx_src_addr == 16'h8001);
					
					//Should not be writing to data memory yet, or done receiving
					assert(rx_en == 0);
					assert(rx_we == 0);
					
					//Push expected opcode header down the pipeline
					rx_op_expected				<= tx_op_ff;
					rx_len_expected				<= tx_len_ff;
					if(tx_len_ff > 512)
						rx_len_expected <= 512;
					
					//Save expected address header
					tx_addr_ff					<= tx_addr;
					
					rxstate	<= 2;
				end
				
				//Opcode header
				2: begin
				
					//Address should still be valid
					assert(rx_dst_addr == rx_dst_addr_expected);
					assert(rx_src_addr == 16'h8001);
				
					//but now opcode should be valid too
					assert(rx_op == rx_op_expected);
					assert(rx_len == rx_len_expected);
					
					//Should not be writing to data memory yet, or done receiving
					assert(rx_en == 0);
					assert(rx_we == 0);
					
					//Push expected address header down the pipeline
					rx_addr_expected			<= tx_addr_ff;
					rx_buf_wdata_expected		<= tx_buf_out_ff;
					
					//Drop the packet if the length is invalid
					if(rx_len > 512)
						rxstate	<= 0;
						
					//Nope, keep going
					else
						rxstate <= 3;
				end
				
				//Address header
				3: begin
					
					//Address and opcode should still be valid
					assert(rx_dst_addr == rx_dst_addr_expected);
					assert(rx_src_addr == 16'h8001);
					assert(rx_op == rx_op_expected);
					assert(rx_len == rx_len_expected);
					
					//as well as address
					assert(rx_addr == rx_addr_expected);
					
					rx_buf_waddr_ff	<= 0;

					//If we are sending a header-only packet, we're done
					if( (rx_len == 0) || (rx_op == DMA_OP_READ_REQUEST) ) begin
						assert(rx_en == 1);
						assert(rx_we == 0);
						rxstate	<= 0;
					end
					
					//If we have data, write the 0th word
					else begin
						assert(rx_en == 0);
						assert(rx_buf_waddr == 0);
						assert(rx_we == 1);
						rxstate	<= 4;
					end
					
				end
				
				//Data, if any
				4: begin
				
					//should be incrementing counter
					rx_buf_waddr_ff	<= rx_buf_waddr;
					assert(rx_buf_waddr_ff_inc == rx_buf_waddr);
					
					//If we wrote the last word LAST cycle, then THIS cycle is done
					if(rx_buf_waddr_ff_inc == rx_len) begin
						assert(rx_en == 1);
						assert(rx_we == 0);
						rxstate	<= 0;
					end
					
					//Nope, not done yet.
					//Should be writing
					else begin
						assert(rx_en == 0);
						assert(rx_we == 1);
					end
				
				end
				
			endcase
			
		end
	
	end
	
endmodule
