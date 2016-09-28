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
	@brief Packet sniffer core
	
	Operation:
		Sniffs all messages constantly, no filter support implemented yet.
		
		If words_ready is nonzero, there is data available to read.
		
		If overflow_alert is asserted, the capture buffer overflowed and data was lost.
			To read a word, assert read_en, data appears on read_data the following cycle.
 */
module RPCPacketSnifferCore(
	clk,
	
	sniff_rpc_en, sniff_rpc_data, sniff_rpc_ack,
	
	words_ready, read_en, read_data, overflow_alert
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Main system clock
	input wire clk;
	
	//Capture bus
	input wire sniff_rpc_en;
	input wire[31:0] sniff_rpc_data;
	input wire[1:0] sniff_rpc_ack;
	
	//Control signals
	output reg[8:0] words_ready		= 0;
	input wire read_en;
	output reg[31:0] read_data		= 0;
	output reg overflow_alert		= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Timestamp stuff
	
	reg[47:0] uptime = 0;
	reg[31:0] uptime_buf_lo = 0;
	
	//Increment timestamp every cycle.
	//Since it takes two cycles to write the uptime, save the low half to avoid overflow bugs
	always @(posedge clk) begin
		uptime <= uptime + 48'h1;
		if(sniff_rpc_en)
			uptime_buf_lo			<= uptime[31:0];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Capture memory
	
	//The buffer itself
	reg[31:0] capture_buffer[511:0];
	
	//Clear buffer to empty at bootup
	integer i;
	initial begin
		for(i=0; i<512; i=i+1)
			capture_buffer[i]		<= 32'h00000000;
	end
	
	//Buffer write logic
	reg write_en					= 0;
	reg[8:0] write_addr				= 0;
	reg[31:0] write_data			= 0;
	always @(posedge clk) begin
		if(write_en)
			capture_buffer[write_addr]	<= write_data;
	end
	
	//Buffer read logic
	reg[8:0] read_addr				= 0;
	always @(posedge clk) begin
		if(read_en)
			read_data				<= capture_buffer[read_addr];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Keep track of available data words
	
	always @(posedge clk)
		words_ready <= frame_ptr - read_addr;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO write logic
	
	`include "RPCv2Router_ack_constants.v"

	//Delay input data by two cycles
	reg[31:0] sniff_rpc_data_ff		= 0;
	reg[31:0] sniff_rpc_data_ff2	= 0;
	always @(posedge clk) begin
		sniff_rpc_data_ff			<= sniff_rpc_data;
		sniff_rpc_data_ff2			<= sniff_rpc_data_ff;
	end
	
	//Base pointer of the current buffer frame
	//Allows us to revert the write pointer if a message is NAK'd or not ACKed
	reg[8:0] frame_ptr				= 0;
	
	//Main write state machine
	reg[2:0] write_state			= 0;
	reg[2:0] next_write_state		= 0;
	always @(*) begin
		next_write_state			<= write_state;
	
		write_en					<= 0;
		write_data					<= 32'h0;
		
		case(write_state)
			
			//Idle
			//Write high half of timestamp as soon as a message comes in
			0: begin
				if(sniff_rpc_en) begin
					write_en			<= 1;
					write_data			<= {16'h0, uptime[47:32]};
					next_write_state	<= 1;
				end
			end
			
			//Write low half of timestamp
			1: begin
				write_en <= 1;
				write_data				<= uptime_buf_lo;
				next_write_state		<= 2;
			end
			
			//Write message data words
			2: begin
				write_en <= 1;
				write_data				<= sniff_rpc_data_ff2;
				next_write_state		<= 3;
			end
			3: begin
				write_en <= 1;
				write_data				<= sniff_rpc_data_ff2;
				next_write_state		<= 4;
			end
			4: begin
				write_en <= 1;
				write_data				<= sniff_rpc_data_ff2;
				next_write_state		<= 5;
			end
			5: begin
				write_en <= 1;
				write_data				<= sniff_rpc_data_ff2;
				next_write_state		<= 6;
			end
			
			//Wait for ACK/NAK
			default: begin
				//all processing in clocked block below
			end
			
		endcase
		
	end
	
	//Save state and write pointer manipulation
	wire[8:0] write_addr_inc		= write_addr + 9'h1;
	reg got_ack						= 0;
	reg got_nak						= 0;
	reg[4:0] timeout_count			= 0;
	always @(posedge clk) begin
		
		write_state					<= next_write_state;
		
		//Write processing
		if(write_en) begin
		
			//Automatically bump write pointer after each write.
			write_addr				<= write_addr_inc;
			
			//If we hit the end of the buffer, set the overflow warning flag and pop the incomplete frame.
			if( (write_addr_inc == read_addr) ) begin				
				overflow_alert		<= 1;
				write_addr			<= frame_ptr;
			end
		end
		
		//Clear ACK/NAK flags the first cycle
		if(write_state == 0) begin
			got_ack <= 0;
			got_nak <= 0;
			timeout_count <= 0;
		end

		//Wait for ACK / NAK
		if(write_state >= 4)
			timeout_count <= timeout_count + 5'h1;
			
		//ACK? Make a note of it
		if(sniff_rpc_ack == RPC_ACK_ACK)
			got_ack <= 1;
			
		//NAK (or timeout)? Pop the frame
		if( (sniff_rpc_ack == RPC_ACK_NAK) || (timeout_count == 31) ) begin
			write_addr		<= frame_ptr;
			write_state		<= 0;
		end	
		
		//Successfully received the whole message? Bump the frame pointer
		if( (write_state >= 5) && ( (sniff_rpc_ack == RPC_ACK_ACK) || got_ack ) ) begin
			if(write_en)
				frame_ptr		<= write_addr_inc;
			else
				frame_ptr		<= write_addr;
				
			write_state			<= 0;
		end

	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// FIFO read logic
	
	always @(posedge clk) begin
		if(read_en)
			read_addr			<= read_addr + 9'h1;
	end
	
endmodule

