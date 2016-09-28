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
	@brief NoC wrapper for a UART
	
	@module
	@opcodefile		NetworkedUART.constants
	
	@rpcfn			UART_SET_BAUD
	@brief			Update the baud rate of the UART
	@param			baud		d0[20:0]:dec		Requested baud rate
	
	@rpcfn_ok		UART_SET_BAUD
	@brief			Baud rate updated
	@param			divisor		d1[15:0]:dec		The selected clock divisor
	
	@rpcfn_fail		UART_SET_BAUD
	@brief			Baud rate could not be updated (problem with sysinfo?)
	
	@rpcfn			UART_RX_START
	@brief			Get the number of words in the input buffer
	
	@rpcfn_ok		UART_RX_START
	@brief			Input buffer size returned
	@param			count		d0[15:0]:dec		Number of bytes in the input buffer
	
	@rpcfn			UART_RX_DONE
	@brief			Finish reading the input buffer
	
	@rpcfn_ok		UART_RX_DONE
	@brief			Input buffer pointers updated
 */
module NetworkedUART(
	clk,
	uart_tx, uart_rx,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack
    );
	 
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Global clock
	input wire clk;
	
	//UART interface
	output wire uart_tx;
	input wire uart_rx;
	
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

	////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transceivers
	
	`include "DMARouter_constants.v"
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR = 16'h0000;
	
	reg			rpc_master_tx_en 		= 0;
	reg[15:0]	rpc_master_tx_dst_addr	= 0;
	reg[7:0]	rpc_master_tx_callnum	= 0;
	reg[2:0]	rpc_master_tx_type		= 0;
	reg[20:0]	rpc_master_tx_d0		= 0;
	reg[31:0]	rpc_master_tx_d1		= 0;
	reg[31:0]	rpc_master_tx_d2		= 0;
	wire		rpc_master_tx_done;
	
	wire		rpc_master_rx_en;
	wire[15:0]	rpc_master_rx_src_addr;
	wire[15:0]	rpc_master_rx_dst_addr;
	wire[7:0]	rpc_master_rx_callnum;
	wire[2:0]	rpc_master_rx_type;
	wire[20:0]	rpc_master_rx_d0;
	wire[31:0]	rpc_master_rx_d1;
	wire[31:0]	rpc_master_rx_d2;
	reg			rpc_master_rx_done		= 0;
	wire		rpc_master_inbox_full;
	
	reg			rpc_slave_tx_en 		= 0;
	reg[15:0]	rpc_slave_tx_dst_addr	= 0;
	reg[7:0]	rpc_slave_tx_callnum	= 0;
	reg[2:0]	rpc_slave_tx_type		= 0;
	reg[20:0]	rpc_slave_tx_d0			= 0;
	reg[31:0]	rpc_slave_tx_d1			= 0;
	reg[31:0]	rpc_slave_tx_d2			= 0;
	wire		rpc_slave_tx_done;
	
	wire		rpc_slave_rx_en;
	wire[15:0]	rpc_slave_rx_src_addr;
	wire[15:0]	rpc_slave_rx_dst_addr;
	wire[7:0]	rpc_slave_rx_callnum;
	//slave rx type is always RPC_TYPE_CALL
	wire[20:0]	rpc_slave_rx_d0;
	wire[31:0]	rpc_slave_rx_d1;
	wire[31:0]	rpc_slave_rx_d2;
	reg			rpc_slave_rx_done		= 0;
	wire		rpc_slave_inbox_full;
	
	RPCv2MasterSlave #(
		.LEAF_ADDR(NOC_ADDR),
		.DROP_MISMATCH_CALLS(1'b1)
	) rpc_txvr (
		//NoC interface
		.clk(clk),
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		//Master interface
		.rpc_master_tx_en(rpc_master_tx_en),
		.rpc_master_tx_dst_addr(rpc_master_tx_dst_addr),
		.rpc_master_tx_callnum(rpc_master_tx_callnum),
		.rpc_master_tx_type(rpc_master_tx_type),
		.rpc_master_tx_d0(rpc_master_tx_d0),
		.rpc_master_tx_d1(rpc_master_tx_d1),
		.rpc_master_tx_d2(rpc_master_tx_d2),
		.rpc_master_tx_done(rpc_master_tx_done),
		
		.rpc_master_rx_en(rpc_master_rx_en),
		.rpc_master_rx_src_addr(rpc_master_rx_src_addr),
		.rpc_master_rx_dst_addr(rpc_master_rx_dst_addr),
		.rpc_master_rx_callnum(rpc_master_rx_callnum),
		.rpc_master_rx_type(rpc_master_rx_type),
		.rpc_master_rx_d0(rpc_master_rx_d0),
		.rpc_master_rx_d1(rpc_master_rx_d1),
		.rpc_master_rx_d2(rpc_master_rx_d2),
		.rpc_master_rx_done(rpc_master_rx_done),
		.rpc_master_inbox_full(rpc_master_inbox_full),
		
		//Slave interface
		.rpc_slave_tx_en(rpc_slave_tx_en),
		.rpc_slave_tx_dst_addr(rpc_slave_tx_dst_addr),
		.rpc_slave_tx_callnum(rpc_slave_tx_callnum),
		.rpc_slave_tx_type(rpc_slave_tx_type),
		.rpc_slave_tx_d0(rpc_slave_tx_d0),
		.rpc_slave_tx_d1(rpc_slave_tx_d1),
		.rpc_slave_tx_d2(rpc_slave_tx_d2),
		.rpc_slave_tx_done(rpc_slave_tx_done),
		
		.rpc_slave_rx_en(rpc_slave_rx_en),
		.rpc_slave_rx_src_addr(rpc_slave_rx_src_addr),
		.rpc_slave_rx_dst_addr(rpc_slave_rx_dst_addr),
		.rpc_slave_rx_callnum(rpc_slave_rx_callnum),
		.rpc_slave_rx_d0(rpc_slave_rx_d0),
		.rpc_slave_rx_d1(rpc_slave_rx_d1),
		.rpc_slave_rx_d2(rpc_slave_rx_d2),
		.rpc_slave_rx_done(rpc_slave_rx_done),
		.rpc_slave_inbox_full(rpc_slave_inbox_full)
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
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transmit buffer
	
	reg[7:0] dma_txbuf_0[511:0];
	reg[7:0] dma_txbuf_1[511:0];
	reg[7:0] dma_txbuf_2[511:0];
	reg[7:0] dma_txbuf_3[511:0];
	
	//Fill with zero
	integer i;
	initial begin
		for(i=0; i<512; i = i+1) begin
			dma_txbuf_0[i] = 0;
			dma_txbuf_1[i] = 0;
			dma_txbuf_2[i] = 0;
			dma_txbuf_3[i] = 0;
		end
	end
	
	//Write logic
	reg[7:0] dma_txbuf_wdata = 0;
	reg[9:0] dma_txbuf_waddr = 0;
	reg[3:0] dma_txbuf_bwe = 0;
	always @(posedge clk) begin
		if(dma_txbuf_bwe[0])
			dma_txbuf_0[dma_txbuf_waddr] = dma_txbuf_wdata;
		if(dma_txbuf_bwe[1])
			dma_txbuf_1[dma_txbuf_waddr] = dma_txbuf_wdata;
		if(dma_txbuf_bwe[2])
			dma_txbuf_2[dma_txbuf_waddr] = dma_txbuf_wdata;
		if(dma_txbuf_bwe[3])
			dma_txbuf_3[dma_txbuf_waddr] = dma_txbuf_wdata;
	end
	
	//Saved pointers in the circular buffer
	//When we issue a flush command we commit current state here
	reg[9:0] uart_rxbuf_flushcount = 0;		//flushed data size, in words
	reg[8:0] uart_rxbuf_flushpos = 0;		//starting position
	
	//Read logic
	always @(posedge clk) begin
		if(dtx_rd)
			dtx_buf_out <=
			{
				dma_txbuf_0[dtx_raddr + uart_rxbuf_flushpos],
				dma_txbuf_1[dtx_raddr + uart_rxbuf_flushpos],
				dma_txbuf_2[dtx_raddr + uart_rxbuf_flushpos],
				dma_txbuf_3[dtx_raddr + uart_rxbuf_flushpos]
			};
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC transmit FIFO logic
	
	`include "NetworkedUART_constants.v"	//Pull in autogenerated constant table
	`include "NOCSysinfo_constants.v"
	`include "NOCNameServer_constants.v"
	
	//When a new byte comes in, write to the FIFO
	reg[11:0] uart_rxbuf_count = 0;
	reg[10:0] uart_rxbuf_wpos = 0;
	wire uart_rxrdy;
	wire[7:0] uart_rxdata;
	reg uart_rxrdy_buf = 0;
	
	localparam BOOT_STATE_QUERY_NAMESRVR 	= 0;
	localparam BOOT_STATE_NAMESRVR_WAIT		= 1;
	localparam BOOT_STATE_READY 			= 2;
	localparam BOOT_STATE_HANG	 			= 3;
	localparam BOOT_STATE_BAUD_WAIT			= 4;
	localparam BOOT_STATE_TX_HOLD			= 5;
	reg[2:0] boot_state = BOOT_STATE_QUERY_NAMESRVR;
	
	//The baud rate
	reg[15:0] clkdiv = 'd2;	//Default to the maximum legal rate
	
	//Address of the sysinfo node
	reg[15:0] sysinfo_addr = 0;
		
	always @(posedge clk) begin
		
		dma_txbuf_waddr <= 0;
		dma_txbuf_bwe <= 0;

		rpc_master_rx_done	<= 0;
		rpc_master_tx_en	<= 0;
		rpc_slave_rx_done	<= 0;
		rpc_slave_tx_en		<= 0;
		
		//Buffer data since we can't process it if an RPC receive is active
		if(uart_rxrdy) begin
			uart_rxrdy_buf <= 1;
			dma_txbuf_wdata <= uart_rxdata;
		end
		
		//Boot logic
		case(boot_state)
			
			//Step 1 - ask the nameserver where the sysinfo node is
			BOOT_STATE_QUERY_NAMESRVR: begin
				rpc_master_tx_en <= 1;
				rpc_master_tx_dst_addr <= NAMESERVER_ADDR;
				rpc_master_tx_type <= RPC_TYPE_CALL;
				rpc_master_tx_callnum <= NAMESERVER_FQUERY;
				rpc_master_tx_d0 <= 0;
				rpc_master_tx_d1 <= "sysi";
				rpc_master_tx_d2 <= {"nfo", 8'h0};
				boot_state <= BOOT_STATE_NAMESRVR_WAIT;
			end	//end BOOT_STATE_QUERY_NAMESRVR
			
			//Step 2 - wait for the nameserver to respond
			BOOT_STATE_NAMESRVR_WAIT: begin
			
				//New packet?
				if(rpc_master_inbox_full) begin
				
					//Clear rx buffer, everything finishes in one cycle
					rpc_master_rx_done <= 1;
					
					//Process it			
					case(rpc_master_rx_type)
						
						//Function call failed? Sysinfo doesn't exist and we've got a problem on our hands
						RPC_TYPE_RETURN_FAIL: begin
							boot_state			<= BOOT_STATE_HANG;
						end	//end RPC_TYPE_RETURN_FAIL
					
						//Function call succeeded? We're good
						RPC_TYPE_RETURN_SUCCESS: begin
							sysinfo_addr		<= rpc_master_rx_d0[15:0];
							boot_state 			<= BOOT_STATE_READY;								
						end	//end RPC_TYPE_RETURN_SUCCESS
						
						//Retry? Go send our request again
						RPC_TYPE_RETURN_RETRY: begin
							rpc_master_tx_en	<= 1;
						end	//end RPC_TYPE_RETURN_RETRY

						//ignore all other kinds of packet, we dont process interrupts etc
						//Master port cannot get incoming calls
						
					endcase
					
				end
			end	//end BOOT_STATE_NAMESRVR_WAIT
			
			//Ready to go
			BOOT_STATE_READY: begin
				
				//Process data if we have a new byte and there's no RPC traffic coming in
				//Guaranteed to be 1 or 2 cycle delay, never 4 so we will never get another RPC message before we can process it
				if(uart_rxrdy_buf && !rpc_slave_inbox_full) begin
				
					//Buffer is full! Drop data rather than corrupting what's already there
					if(uart_rxbuf_count == 2048) begin
					end
					
					//All good, let the write proceed
					else begin		
						//Set up pointers
						uart_rxbuf_count <= uart_rxbuf_count + 12'h1;
						uart_rxbuf_wpos <= uart_rxbuf_wpos + 11'h1;
						dma_txbuf_waddr <= uart_rxbuf_wpos[10:2];
						
						//Write to one of the four byte planes depending on the write pointer
						case(uart_rxbuf_wpos[1:0])
							0: dma_txbuf_bwe[0] <= 1;
							1: dma_txbuf_bwe[1] <= 1;
							2: dma_txbuf_bwe[2] <= 1;
							3: dma_txbuf_bwe[3] <= 1;
						endcase
					end
					
					//Clean up busy flag
					uart_rxrdy_buf <= 0;
				end
				
				//Handle commands
				//If it came on the slave port, it's always a call
				if(rpc_slave_inbox_full) begin
					
					//Default slave to returning from the call
					rpc_slave_tx_dst_addr	<= rpc_slave_rx_src_addr;
					rpc_slave_tx_callnum	<= rpc_slave_rx_callnum;
					rpc_slave_tx_type		<= RPC_TYPE_RETURN_SUCCESS;
					rpc_slave_tx_d0			<= rpc_slave_rx_d0;
					rpc_slave_tx_d1			<= rpc_slave_rx_d1;
					rpc_slave_tx_d2			<= rpc_slave_rx_d2;
					
					case(rpc_slave_rx_callnum)
						
						//Set baud rate
						UART_SET_BAUD: begin
							
							//Ask sysinfo to look up the necessary info
							rpc_master_tx_en		<= 1;
							rpc_master_tx_dst_addr	<= sysinfo_addr;
							rpc_master_tx_callnum	<= SYSINFO_GET_CYCFREQ;
							rpc_master_tx_type		<= RPC_TYPE_CALL;
							rpc_master_tx_d0		<= 0;
							rpc_master_tx_d1		<= rpc_slave_rx_d0;
							rpc_master_tx_d2		<= 0;
							
							boot_state				<= BOOT_STATE_BAUD_WAIT;

						end	//end UART_SET_BAUD
						
						//Begin a flush
						UART_RX_START: begin
							
							rpc_slave_rx_done		<= 1;
							
							//Send the count back
							rpc_slave_tx_d0 <= uart_rxbuf_count;
							rpc_slave_tx_d1 <= 0;
							rpc_slave_tx_d2 <= 0;
							rpc_slave_tx_en <= 1;
							
							//Save size
							if(uart_rxbuf_count[1:0] == 0)
								uart_rxbuf_flushcount <= uart_rxbuf_count[11:2];
							else
								uart_rxbuf_flushcount <= uart_rxbuf_count[11:2] + 10'h1;
							//Data is uart_rxbuf_flushcount words starting at uart_rxbuf_flushpos
								
							//Align the write pointer to a word boundary
							case(uart_rxbuf_count[1:0])
								0: begin
								end
								1: begin
									uart_rxbuf_count	<= uart_rxbuf_count + 12'h3;
									uart_rxbuf_wpos		<= uart_rxbuf_wpos + 11'h3;
								end
								2: begin
									uart_rxbuf_count	<= uart_rxbuf_count + 12'h2;
									uart_rxbuf_wpos		<= uart_rxbuf_wpos + 11'h2;
								end
								3: begin
									uart_rxbuf_count	<= uart_rxbuf_count + 12'h1;
									uart_rxbuf_wpos		<= uart_rxbuf_wpos + 11'h1;
								end
							endcase		
							
							//Wait for transmit
							boot_state				<= BOOT_STATE_TX_HOLD;
							
						end	//end UART_OP_RX_START
						
						//Finish up, reset the pointers for the next read
						UART_RX_DONE: begin
						
							rpc_slave_rx_done <= 1;
						
							uart_rxbuf_flushcount <= 0;
							uart_rxbuf_flushpos <=
								uart_rxbuf_flushpos + uart_rxbuf_flushcount[8:0];	//Count of 512 is equivalent to zero since
																					//that's the buffer size. 
																					//Explicitly truncate to avoid warning.
							uart_rxbuf_count <= uart_rxbuf_count - {uart_rxbuf_flushcount, 2'b00};	//Convert words to bytes
							
							//If we just got a new byte, add 1
							if(uart_rxrdy_buf && (uart_rxbuf_count == 2048))
								uart_rxbuf_count <= uart_rxbuf_count - uart_rxbuf_flushcount - 12'h1;
							
							//We're done
							rpc_slave_tx_en <= 1;
							
							//Wait for transmit
							boot_state				<= BOOT_STATE_TX_HOLD;
							
						end	//end UART_RX_DONE
						
						//Unknown operation, return error
						default: begin
							rpc_slave_tx_en		<= 1;
							rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;
							rpc_slave_rx_done	<= 1;
						end

					endcase

				end	//end rpc_rxv_en
				
			end	//end BOOT_STATE_READY
			
			//Waiting for baud rate divisor to be calculated
			BOOT_STATE_BAUD_WAIT: begin
			
				if(rpc_master_inbox_full) begin
				
					//Clear rx buffer, everything finishes in one cycle
					rpc_master_rx_done <= 1;
					
					//Process it			
					case(rpc_master_rx_type)
	
						//Function call failed? We're screwed, return fail
						RPC_TYPE_RETURN_FAIL: begin
							rpc_slave_tx_type	<= RPC_TYPE_RETURN_FAIL;								
							rpc_slave_rx_done	<= 1;

							rpc_slave_tx_en		<= 1;
							boot_state			<= BOOT_STATE_TX_HOLD;
						end	//end RPC_TYPE_RETURN_FAIL

						//Function call succeeded? Save settings and return
						RPC_TYPE_RETURN_SUCCESS: begin
							clkdiv				<= rpc_master_rx_d1[15:0];
							
							rpc_slave_rx_done	<= 1;
							rpc_slave_tx_d1		<= rpc_master_rx_d1[15:0];
							
							rpc_slave_tx_en		<= 1;
							boot_state			<= BOOT_STATE_TX_HOLD;
						end	//end RPC_TYPE_RETURN_SUCCESS
						
						//Need to retry the sysinfo call?
						//We already have all of the stuff in the master outbox, just re-send it
						RPC_TYPE_RETURN_RETRY: begin
							rpc_master_tx_en	<= 1;
						end	//end RPC_TYPE_RETURN_RETRY
						
					endcase
					
				end
				
			end	//end BOOT_STATE_BAUD_WAIT
			
			BOOT_STATE_TX_HOLD: begin
				if(rpc_slave_tx_done)
					boot_state	<= BOOT_STATE_READY;
			end	//end BOOT_STATE_TX_HOLD
			
			BOOT_STATE_HANG: begin
				//something went very wrong, hang
			end	//end BOOT_STATE_HANG
			
		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// NoC receiver / UART transmitter state machine
	// Data from NoC to UART

	reg[1:0] tx_current_byte = 0;
	reg[9:0] tx_wordlen = 0;
	
	reg[7:0] uart_tx_data = 0;
	reg uart_tx_en = 0;
	wire uart_tx_busy;
	
	//Exctract the current byte from the ram
	reg[7:0] tx_parsed_data = 0;
	always @(tx_current_byte, drx_buf_data) begin
		case(tx_current_byte)
			0: tx_parsed_data <= drx_buf_data[31:24];
			1: tx_parsed_data <= drx_buf_data[23:16];
			2: tx_parsed_data <= drx_buf_data[15:8];
			3: tx_parsed_data <= drx_buf_data[7:0];
		endcase
	end
	
	//DMA state machine
	localparam TX_STATE_IDLE 				= 'h00;
	localparam TX_STATE_READING				= 'h01;
	localparam TX_STATE_OUTPUT				= 'h02;
	reg[2:0] tx_state = TX_STATE_IDLE;
	always @(posedge clk) begin
	
		uart_tx_en <= 0;
		drx_buf_rd <= 0;
		dtx_en <= 0;
	
		case(tx_state)
			
			//Idle - wait for packet to arrive
			TX_STATE_IDLE: begin
			
				//Ready for new message
				drx_ready <= 1;
			
				//DMA receive
				if(drx_en) begin
				
					case(drx_op)
					
						//Write - send null-terminated string
						//Ignore writes not to address 0 for now
						DMA_OP_WRITE_REQUEST: begin
							if(drx_addr == 0) begin
								
								//Discard address info for now, maybe later we will figure out a use for it
								
								tx_current_byte <= 0;
								tx_wordlen <= drx_len;
								drx_buf_rd <= 1;
								drx_buf_addr <= 0;
								tx_state <= TX_STATE_READING;
								
								//Cannot receive new messages immediately
								drx_ready <= 0;
							end
						end
						
						//Read request - someone wants our data
						DMA_OP_READ_REQUEST: begin
							if(drx_addr == 0) begin
								dtx_dst_addr <= drx_src_addr;
								dtx_op <= DMA_OP_READ_DATA;
								dtx_len <= drx_len;
								dtx_addr <= 0;
								dtx_en <= 1;
							end
						end
						
						//ignore everything else
						default: begin
						end
						
					endcase
				end
				
				//TODO: Figure out some way of handling nulls in strings
				//TODO: RPC operations
				//Send single byte
				//TODO: Receive datapath
				//Read into a buffer
				//When DMA read request comes in, copy buffer into transceiver buffer and send out
				
			end	//end TX_STATE_IDLE

			//Delay by 1 cycle while waiting for buffer read
			TX_STATE_READING: begin
				tx_state <= TX_STATE_OUTPUT;
			end	//end TX_STATE_READING
			
			//Output stuff to the UART
			TX_STATE_OUTPUT: begin
			
				//Only proceed if UART is free
				if(!uart_tx_busy && !uart_tx_en) begin
				
					//If the byte is null, or we're at the end of the buffer, stop
					if( (tx_parsed_data == 0) || (drx_buf_addr == tx_wordlen) )begin
						tx_state <= TX_STATE_IDLE;
					end
				
					else begin
						//Send the byte
						uart_tx_en <= 1;
						uart_tx_data <= tx_parsed_data;
				
						//Just sent the last byte in the word? Go on to the next word
						if(tx_current_byte == 3) begin
							tx_current_byte <= 0;
							drx_buf_addr <= drx_buf_addr + 10'h1;
							drx_buf_rd <= 1;
							tx_state <= TX_STATE_READING;
						end
						
						//No, just bump the byte index
						else begin
							tx_current_byte <= tx_current_byte + 2'h1;
						end
					end
				
				end
			
			end	//end TX_STATE_OUTPUT

		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The UART

	UART uart (
		.clk(clk), 
		.clkdiv(clkdiv), 
		.tx(uart_tx), 
		.txin(uart_tx_data), 
		.txrdy(uart_tx_en), 
		.txactive(uart_tx_busy), 
		.rx(uart_rx), 
		.rxout(uart_rxdata), 
		.rxrdy(uart_rxrdy), 
		.rxactive(), 
		.overflow()
		);
		
endmodule
