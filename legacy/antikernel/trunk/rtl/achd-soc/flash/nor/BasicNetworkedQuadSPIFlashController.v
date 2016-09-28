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
	@brief Basic (no authentication or ownership) NoC wrapper around NativeQuadSPIFlashController
	
	@module
	@opcodefile		BasicNetworkedQuadSPIFlashController_opcodes.constants
	
	@rpcfn			NOR_RESET
	@brief			Resets the flash controller.
	
	@rpcfn_ok		NOR_RESET
	@brief			Controller initialized.
	
	@rpcfn			NOR_GET_SIZE
	@brief			Gets the size of the flash device.
	
	@rpcfn_ok		NOR_GET_SIZE
	@brief			Size of flash device retrieved.
	@param			size			d1[31:0]:hex		Size of the flash device, in bytes
	
	@rpcfn			NOR_PAGE_ERASE
	@brief			Erases a page of flash.
	@param			addr			d1[31:0]:hex		Address of the page to erase
	
	@rpcfn_ok		NOR_PAGE_ERASE
	@brief			Page erased.
	
	@rpcint			NOR_WRITE_DONE
	@brief			Write committed.
	@param			len				d0[15:0]:dec		Length of the written data
	@param			addr			d1[31:0]:hex		Address of written data
	
	@rpcint			NOR_OP_FAILED
	@brief			Access denied.
 */
module BasicNetworkedQuadSPIFlashController(

	//Clocks
	clk,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//Quad SPI interface
	spi_cs_n, spi_sck, spi_data
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
	
	//Quad SPI interface
	output wire spi_cs_n;
	output wire spi_sck;
	inout wire[3:0] spi_data;
	
	//Enable this to lock the controller into read-only mode. This will improve 
	parameter FORCE_READ_ONLY = 0;
	
	//Disable this to force the controller into x1 mode
	parameter ENABLE_QUAD_MODE = 1;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The actual controller
	
	wire busy;
	wire done;
	reg[31:0] addr = 0;
	reg[9:0] burst_size = 0;
	reg read_en = 0;
	wire read_data_valid;
	wire[31:0] read_data;
	reg erase_en = 0;
	reg write_en = 0;
	wire write_rden;
	wire[31:0] write_data;
	wire[31:0] max_address;
	reg reset = 0;
	
	NativeQuadSPIFlashController #(
		.ENABLE_QUAD_MODE(ENABLE_QUAD_MODE)
	) ctrl (
		.clk(clk),
		.reset(reset),
		
		.spi_cs_n(spi_cs_n),
		.spi_sck(spi_sck),
		.spi_data(spi_data),
		
		.busy(busy),
		.done(done),
		.addr(addr),
		.burst_size(burst_size),
		
		.read_en(read_en),
		.read_data_valid(read_data_valid),
		.read_data(read_data),
		
		.erase_en(erase_en),
		
		.write_en(write_en),
		.write_rden(write_rden),
		.write_data(write_data),
		
		.max_address(max_address)
	);
	
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
	wire[1:0] drx_op;
	wire[31:0] drx_addr;
	wire[9:0] drx_len;	
	reg[9:0] drx_buf_addr = 0;
	
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
		
		.rx_ready(drx_ready), .rx_en(drx_en), .rx_src_addr(drx_src_addr), .rx_dst_addr(),
		.rx_op(drx_op), .rx_addr(drx_addr), .rx_len(drx_len),
		.rx_buf_rd(write_rden), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(write_data), .rx_buf_rdclk(clk)
		);
	
	//The page ID of the current address
	//Bottom 11 bits 10:0 are the byte address within the page (last 3 must be zero for cache line alignment)
	//Next 16 26:11 are page ID
	//31:27 are unimplemented and must be zero
	wire[15:0] drx_page_id = drx_addr[26:11];
	wire[31:0] drx_end_addr = drx_addr + drx_len;
	wire[15:0] drx_end_page_id = drx_end_addr[26:11];
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transmit buffer
	
	reg dma_txbuf_addr_reset = 0;
	reg[8:0] dma_txbuf_addr = 0;
	
	reg[31:0] dma_tx_buffer[511:0];
	always @(posedge clk) begin
		
		if(dtx_rd)
			dtx_buf_out <= dma_tx_buffer[dtx_raddr];
		
		if(dma_txbuf_addr_reset)
			dma_txbuf_addr <= 0;
		
		if(read_data_valid) begin
			dma_tx_buffer[dma_txbuf_addr] <= read_data;
			dma_txbuf_addr <= dma_txbuf_addr + 9'h1;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA receive logic
	
	reg dma_rxbuf_addr_reset = 0;
	always @(posedge clk) begin
		if(dma_rxbuf_addr_reset)
			drx_buf_addr <= 0;
		if(write_rden)
			drx_buf_addr <= drx_buf_addr + 10'h1;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "BasicNetworkedQuadSPIFlashController_opcodes_constants.v"
	`include "BasicNetworkedQuadSPIFlashController_states_constants.v"

	reg[3:0] state = STATE_RESET;
	
	reg rpc_message_pending = 0;
	reg dma_message_pending = 0;
	
	wire rpc_rx_ready;
	assign rpc_rx_ready = rpc_fab_rx_en || rpc_message_pending;
	
	always @(posedge clk) begin

		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		dtx_en <= 0;
		dma_txbuf_addr_reset <= 0;
		dma_rxbuf_addr_reset <= 0;
		
		reset <= 0;
		erase_en <= 0;
		read_en <= 0;
		write_en <= 0;

		//When a message comes in and we're busy, make a note of it
		if(rpc_fab_rx_en)
			rpc_message_pending <= 1;
		if(drx_en) begin
			dma_message_pending <= 1;
			drx_ready <= 0;
		end
		
		case(state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Nothing to do

			STATE_IDLE: begin
				
				//See if any RPC commands are here
				if(rpc_rx_ready) begin
					
					rpc_message_pending <= 0;
					
					//Prepare to respond to whatever we got
					rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
					rpc_fab_tx_callnum <= rpc_fab_rx_callnum;
					
					case(rpc_fab_rx_type)
						
						//Remote procedure call - deal with it
						RPC_TYPE_CALL: begin
							case(rpc_fab_rx_callnum)
								
								//Reset
								NOR_RESET: begin
									reset <= 1;
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									rpc_fab_rx_done <= 1;
									state <= STATE_RESET;
								end	//end NOR_RESET
								
								//Get flash size
								NOR_GET_SIZE: begin
									
									rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= max_address + 32'h1;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									rpc_fab_rx_done <= 1;
									state <= STATE_RPC_TXHOLD;
									
								end	//end NOR_GET_SIZE
								
								//Erase a page of flash
								NOR_PAGE_ERASE: begin
									
									//Deny the write in read-only mode
									if(FORCE_READ_ONLY) begin
									
										rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
										rpc_fab_tx_d0 <= 0;
										rpc_fab_tx_d1 <= 0;
										rpc_fab_tx_d2 <= 0;
										rpc_fab_tx_en <= 1;
										
										rpc_fab_rx_done <= 1;
										
										state <= STATE_RPC_TXHOLD;
									
									end
									
									else begin
										rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
										rpc_fab_tx_d0 <= 0;
										rpc_fab_tx_d1 <= 0;
										rpc_fab_tx_d2 <= 0;
										
										erase_en <= 1;
										addr <= rpc_fab_rx_d1;
										
										state <= STATE_ERASE;
									end
									
								end	//end NOR_ERASE

								//Not implemented? Report failure right away
								default: begin								
									rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
									rpc_fab_tx_d0 <= 0;
									rpc_fab_tx_d1 <= 0;
									rpc_fab_tx_d2 <= 0;
									rpc_fab_tx_en <= 1;
									
									rpc_fab_rx_done <= 1;
									
									state <= STATE_RPC_TXHOLD;
								end
							endcase
						end
						
						default: begin
							rpc_fab_rx_done <= 1;
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
							//and the length is word aligned
							//For now, limit to 64 byte write transactions since the flash won't allow more than that
							//in a single page write
							if( (drx_page_id != drx_end_page_id) ||
								(drx_addr[31:27] != 0) ||
								(drx_addr[1:0] != 0) ||
								(drx_len > 64) ||
								FORCE_READ_ONLY
								) begin
								
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= NOR_OP_FAILED;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								
								drx_ready <= 1;
								state <= STATE_RPC_TXHOLD;
								
							end
							
							//Valid write request
							else begin
							
								//Reset the buffer address
								dma_rxbuf_addr_reset <= 1;
								
								//Dispatch the write request to the flash
								write_en <= 1;
								burst_size <= drx_len;
								addr <= drx_addr;
							
								//Prepare to send write-done message
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= NOR_WRITE_DONE;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;
								
								state <= STATE_WRITE;
							
							end

						end	//end DMA_OP_WRITE_REQUEST
						
						DMA_OP_READ_REQUEST: begin
						
							//Reads from memory cannot cross page boundaries.
							//While we're at it, verify the address is sane
							//and the length is word aligned
							if( (drx_page_id != drx_end_page_id) ||
								(drx_addr[31:27] != 0) ||
								(drx_addr[1:0] != 0) ||
								(drx_len[0] != 0)
								) begin
								
								rpc_fab_tx_dst_addr <= drx_src_addr;
								rpc_fab_tx_callnum <= NOR_OP_FAILED;
								rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
								rpc_fab_tx_d0 <= drx_len;
								rpc_fab_tx_d1 <= drx_addr;
								rpc_fab_tx_d2 <= 0;
								rpc_fab_tx_en <= 1;
								
								state <= STATE_RPC_TXHOLD;
								
							end
							
							//Valid read request
							else begin
							
								//Reset the buffer address
								dma_txbuf_addr_reset <= 1;
							
								//Dispatch the read request to the flash
								read_en <= 1;
								burst_size <= drx_len;
								addr <= drx_addr;
							
								//Save stuff
								dtx_addr <= drx_addr;
								dtx_len <= drx_len;
								dtx_dst_addr <= drx_src_addr;
								dtx_op <= DMA_OP_READ_DATA;
								
								state <= STATE_READ;
								
								//Immediately clear the ingress buffer to avoid potential send-during-receive
								//deadlocks
								drx_ready <= 1;
							
							end
						end	//end DMA_OP_READ_REQUEST
						
						//ignore other stuff
						default: begin

							rpc_fab_tx_dst_addr <= drx_src_addr;
							rpc_fab_tx_callnum <= NOR_OP_FAILED;
							rpc_fab_tx_type <= RPC_TYPE_INTERRUPT;
							rpc_fab_tx_d0 <= drx_len;
							rpc_fab_tx_d1 <= drx_addr;
							rpc_fab_tx_d2 <= 0;
							rpc_fab_tx_en <= 1;
							
							state <= STATE_RPC_TXHOLD;
							
						end

					endcase

				end	//end check for dma messages
				
			end	//end STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for reset
			
			STATE_RESET: begin
				if(!reset && !busy)
					state <= STATE_IDLE;
					
				//Allow RPC to request a reset
				if(rpc_rx_ready && (rpc_fab_rx_type == RPC_TYPE_CALL) && (rpc_fab_rx_callnum == NOR_RESET) ) begin
					reset <= 1;
					
					rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
					rpc_fab_tx_d0 <= 0;
					rpc_fab_tx_d1 <= 0;
					rpc_fab_tx_d2 <= 0;
					rpc_fab_tx_en <= 1;
					rpc_fab_rx_done <= 1;
					state <= STATE_RESET;
				end

			end	//end STATE_RESET
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for erase
			
			STATE_ERASE: begin
				if(done) begin
					rpc_fab_tx_en <= 1;
					rpc_fab_rx_done <= 1;
					state <= STATE_RPC_TXHOLD;
				end
			end	//end STATE_ERASE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Do a read
			
			STATE_READ: begin
			
				//Read data valid
				if(done) begin
					dtx_en <= 1;
					state <= STATE_DMA_TXHOLD;
				end
			
			end	//end STATE_READ
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Do a write
			
			STATE_WRITE: begin
				if(done) begin
					rpc_fab_tx_en <= 1;
					state <= STATE_RPC_TXHOLD;
				end
			end	//end STATE_WRITE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Helper states
			
			STATE_DMA_TXHOLD: begin
				if(!dtx_en && !dtx_busy) begin
					state <= STATE_IDLE;
				end
			end //end STATE_DMA_TXHOLD
			
			STATE_RPC_TXHOLD: begin
			
				if(rpc_fab_tx_done) begin
					if(!dma_message_pending)
						drx_ready <= 1;
					state <= STATE_IDLE;
				end
				
			end	//end STATE_RPC_TXHOLD

		endcase
	
	end
	
endmodule
