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
	@brief JTAG to RPC/DMA network bridge
 */
module JtagDebugController(
	clk_noc,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack
    );
	 
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Global clock
	input wire clk_noc;
	
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// JTAG interface modules
	
	wire jtag_reset;
	wire jtag_tck;
	wire jtag_tdi;
	//wire jtag_rti;
	wire jtag_shift_dr;
	wire jtag_capture_dr;
	wire jtag_update_dr;
	wire user1_active;
	wire user1_tdo;
	
	//Now using chip-agnostic primitives
	BscanMacro #(
		.USER_INSTRUCTION(1)
	) user1_bscan (
		.instruction_active(user1_active),
		
		.state_capture_dr(jtag_capture_dr),
		.state_reset(jtag_reset),
		.state_runtest(),
		.state_shift_dr(jtag_shift_dr),
		.state_update_dr(jtag_update_dr),
		
		.tck(jtag_tck),
		.tck_gated(),
		.tms(),
		.tdi(jtag_tdi),
		.tdo(user1_tdo)
	);

	//TODO: Spartan-3A support in BscanMacro (?)
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Local buffer for JTAG clock
	
	wire jtag_tck_bufh;
	
	ClockBuffer #(
		.TYPE("GLOBAL"),	//BUFH fails to route in Spartan-6 sometimes. Not sure why
		.CE("NO")
	) gmii_rxc_bufh (
		.clkin(jtag_tck),
		.clkout(jtag_tck_bufh),
		.ce(1'b1)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC network transceiver
	
	wire[31:0] tx_fifo_rdata;
	
	wire[1:0] rpc_txbuf_raddr;
	wire rpc_txbuf_rd;
	
	reg			rpc_fab_tx_en = 0;
	wire		rpc_fab_tx_done;

	wire		rpc_fab_rx_en;
	wire[1:0]	rpc_fab_rx_waddr;
	wire[31:0]	rpc_fab_rx_wdata;
	wire		rpc_fab_rx_we;
	wire		rpc_fab_rx_done;
	
	RPCv2RouterTransceiver #(
		.LEAF_PORT(0),
		.LEAF_ADDR(0)
	) rpc_txvr (
		
		.clk(clk_noc),
		
		.rpc_tx_en(rpc_tx_en),
		.rpc_tx_data(rpc_tx_data),
		.rpc_tx_ack(rpc_tx_ack),
		
		.rpc_rx_en(rpc_rx_en),
		.rpc_rx_data(rpc_rx_data),
		.rpc_rx_ack(rpc_rx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_rd_en(rpc_txbuf_rd),
		.rpc_fab_tx_raddr(rpc_txbuf_raddr),
		.rpc_fab_tx_rdata(tx_fifo_rdata),
		.rpc_fab_tx_done(rpc_fab_tx_done),
		
		.rpc_fab_rx_en(rpc_fab_rx_en),
		.rpc_fab_rx_dst_addr(),
		.rpc_fab_rx_we(rpc_fab_rx_we),
		.rpc_fab_rx_waddr(rpc_fab_rx_waddr),
		.rpc_fab_rx_wdata(rpc_fab_rx_wdata),
		.rpc_fab_rx_done(rpc_fab_rx_done),
		.rpc_fab_inbox_full()
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA network transceiver
	
	//Set this to disable the DMA network for small SoCs
	parameter 	DMA_DISABLE	= 0;
	
	//DMA transmit signals
	wire dtx_busy;
	reg[15:0] dtx_src_addr	= 0;
	reg[15:0] dtx_dst_addr	= 0;
	reg dtx_en				= 0;
	reg[1:0] dtx_op			= 0;
	reg[9:0] dtx_len		= 0;
	reg[31:0] dtx_addr		= 0;
	wire dtx_rd;
	wire[9:0] dtx_raddr;
	
	//DMA receive signals
	reg drx_ready			= 1;
	wire drx_en;
	wire[15:0] drx_src_addr;
	wire[15:0] drx_dst_addr;
	wire[1:0] drx_op;
	wire[31:0] drx_addr;
	wire[9:0] drx_len;	
	reg drx_buf_rd			= 0;
	reg[9:0] drx_buf_addr	= 0;
	wire[31:0] drx_buf_data;
	
	generate
		if(!DMA_DISABLE) begin
			DMATransceiver #(
				.LEAF_PORT(0),
				.LEAF_ADDR(16'h0000)
			) dma_txvr (
				.clk(clk_noc),
				.dma_tx_en(dma_tx_en), .dma_tx_data(dma_tx_data), .dma_tx_ack(dma_tx_ack),
				.dma_rx_en(dma_rx_en), .dma_rx_data(dma_rx_data), .dma_rx_ack(dma_rx_ack),
			
				.tx_done(), .tx_busy(dtx_busy), .tx_src_addr(dtx_src_addr), .tx_dst_addr(dtx_dst_addr), .tx_op(dtx_op),
				.tx_len(dtx_len), .tx_addr(dtx_addr), .tx_en(dtx_en), .tx_rd(dtx_rd), .tx_raddr(dtx_raddr),
				.tx_buf_out(tx_fifo_rdata),
				
				.rx_ready(drx_ready), .rx_en(drx_en), .rx_src_addr(drx_src_addr), .rx_dst_addr(drx_dst_addr),
				.rx_op(drx_op), .rx_addr(drx_addr), .rx_len(drx_len),
				.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data),
				.rx_buf_rdclk(jtag_tck_bufh)
				);
		end
		
		else begin
			assign dtx_rd		= 0;
			assign dtx_raddr	= 0;
			assign drx_src_addr	= 0;
			assign drx_dst_addr	= 0;
			assign drx_op		= 0;
			assign drx_addr		= 0;
			assign drx_len		= 0;
			assign drx_buf_data	= 0;
		end
	endgenerate	
	
	reg dtx_done_next					= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Shift register logic, JTAG clock domain
	
	reg[31:0] jtag_rx_shreg = 0;
	reg[31:0] jtag_tx_shreg = 0;
	reg[31:0] jtag_tx_next = 0;
	assign user1_tdo = jtag_tx_shreg[0];
	
	reg[4:0] jtag_bitcount = 0;
	
	//This is a streaming operation, not standard JTAG per se
	//We process data every 32 words
	wire jtag_new_word;
	assign jtag_new_word = (jtag_bitcount == 5'h1f);
	
	//True if we're writing the NoC header
	reg		writing_noc_header	= 0;
		
	//Pending value of the receive shift register
	reg[31:0] jtag_rx_shreg_fwd = 0;
	
	always @(*) begin
	
		//Default value
		jtag_rx_shreg_fwd <= { jtag_tdi, jtag_rx_shreg[31:1] };
		
		//If we're writing the NoC header, force the two upper address bits high
		//They should always be set when the PC is sending debug packets anyway
		//Force them high to prevent impersonation of on-chip addresses
		if(writing_noc_header)
			jtag_rx_shreg_fwd[31:30]	<= 2'b11;
		
	end
	
	always @(posedge jtag_tck_bufh) begin
		
		//Main JTAG processing
		if(user1_active) begin
		
			//Capture - start counting
			if(jtag_capture_dr) begin
				jtag_rx_shreg <= 0;
				jtag_bitcount <= 0;
			end
			
			//Shift operation
			if(jtag_shift_dr) begin
			
				//Shift the buffers and keep track of how many bits we've moved
				jtag_rx_shreg <= jtag_rx_shreg_fwd;
				jtag_tx_shreg <= {1'b0, jtag_tx_shreg[31:1] };
				jtag_bitcount <= jtag_bitcount + 5'h1;
				
				if(jtag_new_word)
					jtag_tx_shreg <= jtag_tx_next;
			end
			
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Cross-clock buffer for DMA/RPC transmit data
	
	reg tx_fifo_write					= 0;
	wire[10:0] tx_fifo_ready_count;
	wire[10:0] credits;
	reg tx_fifo_read					= 0;
	
	reg rd_en							= 0;
	reg[8:0] rd_offset					= 0;
	reg[9:0] rd_packet_size				= 0;
	reg rd_pop_packet					= 0;
	
	CrossClockPacketFifo tx_fifo (
		.wr_clk(jtag_tck_bufh),
		.wr_en(tx_fifo_write),
		.wr_data(jtag_rx_shreg_fwd),
		.wr_size(credits),
		.wr_reset(jtag_reset),
		
		.rd_clk(clk_noc),
		.rd_en(rd_en),
		.rd_offset(rd_offset),
		.rd_pop_single(tx_fifo_read),
		.rd_pop_packet(rd_pop_packet),
		.rd_packet_size(rd_packet_size),
		.rd_data(tx_fifo_rdata),
		.rd_size(tx_fifo_ready_count),
		.rd_reset(jtag_reset)			//TODO synchronize?
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// JTAG receive state machine, JTAG clock domain
	// All data going from the host to the device runs through here.
	
	`include "JtagDebugController_opcodes_constants.v"
	
	localparam RX_STATE_IDLE			= 0;
	localparam RX_STATE_HEADER			= 1;
	localparam RX_STATE_NOC_HEADER		= 2;
	localparam RX_STATE_BODY			= 3;
	
	reg[1:0] jtag_rx_state				= RX_STATE_IDLE;
	reg[1:0] jtag_rx_state_next			= RX_STATE_IDLE;
	
	//Handshaking for IDCODE frames
	reg pending_idcode_flag 			= 0;
	reg pending_idcode_clear			= 0;
	reg pending_idcode_flag_next;
	
	//Most recently processed sequence number
	reg[7:0] sequence					= 0;
	reg[7:0] sequence_next				= 0;
	
	//Set to 1 to drop the current frame (no buffer space)
	reg dropping_frame					= 0;
	reg dropping_frame_next				= 0;
	
	//Length field for the current packet
	reg[9:0] frame_length				= 0;
	reg[9:0] frame_length_next			= 0;
	
	//Fields of the incoming frame (only valid in RX_STATE_HEADER)
	wire[2:0] incoming_frame_op			= jtag_rx_shreg_fwd[31:29];
	wire[9:0] incoming_frame_length		= jtag_rx_shreg_fwd[28:19];

	//Combinatorial logic for protocol handling
	always @(*) begin
	
		//Hold state if no new data arriving
		jtag_rx_state_next			<= jtag_rx_state;
		pending_idcode_flag_next	<= pending_idcode_flag;
		sequence_next				<= sequence;
		tx_fifo_write				<= 0;
		dropping_frame_next			<= dropping_frame;
		frame_length_next			<= frame_length;
		
		//Not writing the NoC header yet
		writing_noc_header			<= 0;
		
		//Clear state on reset
		if(pending_idcode_clear)
			pending_idcode_flag_next <= 0;

		//New data!
		if(jtag_new_word) begin
		
			case(jtag_rx_state)
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// Idle, wait for a frame to start
				
				RX_STATE_IDLE: begin
				
					dropping_frame_next <= 0;
				
					if(jtag_rx_shreg_fwd == JTAG_FRAME_PREAMBLE)
						jtag_rx_state_next <= RX_STATE_HEADER;						
				end
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// Encapsulation header
				
				RX_STATE_HEADER: begin
					
					//Save the sequence number and size
					sequence_next <= jtag_rx_shreg_fwd[18:11];
					frame_length_next <= incoming_frame_length - 10'd1;
					
					//First 3 bits are the type
					case(incoming_frame_op)
						
						//IDCODE? Set flag and ignore the rest of the frame
						//(assume frame length is zero)
						JTAG_FRAME_TYPE_IDCODE: begin
							pending_idcode_flag_next <= 1;
							jtag_rx_state_next <= RX_STATE_IDLE;
						end
						
						//RPC packet? Save the whole frame
						//(assume frame length is 4 for now).
						JTAG_FRAME_TYPE_RPC: begin
						
							//If we lack sufficient buffer space, abort
							if(credits < 5)
								dropping_frame_next <= 1;
								
							//otherwise save the frame
							else
								tx_fifo_write <= 1;
								
							jtag_rx_state_next <= RX_STATE_NOC_HEADER;
							
						end
						
						//DMA packet? Save the whole frame
						JTAG_FRAME_TYPE_DMA: begin
						
							//If we lack sufficient buffer space, abort
							if(credits <= incoming_frame_length )
								dropping_frame_next <= 1;
						
							//otherwise save the frame
							else
								tx_fifo_write <= 1;
																							
							jtag_rx_state_next <= RX_STATE_NOC_HEADER;
							
						end
						
						//Bad opcode? Ignore and go back to idle
						default: begin
							jtag_rx_state_next <= RX_STATE_IDLE;
						end
						
					endcase
										
					//Ignore inbound credit count for now, assume PC has unlimited storage

				end
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// Network header
				
				RX_STATE_NOC_HEADER: begin
					
					writing_noc_header	<= 1;
					
					tx_fifo_write <= !dropping_frame;
					
					if(frame_length == 0)
						jtag_rx_state_next <= RX_STATE_IDLE;
						
					else begin
						jtag_rx_state_next <= RX_STATE_BODY;
						frame_length_next <= frame_length - 10'd1;
					end
					
				end
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// Packet body
				
				RX_STATE_BODY: begin
					tx_fifo_write <= !dropping_frame;
					
					if(frame_length == 0)
						jtag_rx_state_next <= RX_STATE_IDLE;
						
					else begin
						jtag_rx_state_next <= RX_STATE_BODY;
						frame_length_next <= frame_length - 10'd1;
					end
						
				end
				
			endcase
		
		end
		
	end
	
	//Synchronous buffering and resets
	always @(posedge jtag_tck_bufh) begin
		
		//Apply states
		pending_idcode_flag <= pending_idcode_flag_next;
		jtag_rx_state <= jtag_rx_state_next;
		sequence <= sequence_next;
		dropping_frame <= dropping_frame_next;
		frame_length <= frame_length_next;
		
		//Clear everything on reset
		if(jtag_reset) begin
			jtag_rx_state <= RX_STATE_IDLE;
			pending_idcode_flag <= 0;
			sequence <= 0;
		end
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// JTAG transmit state machine, JTAG clock domain
	// All data from the network to the PC goes through here.
	
	localparam TX_STATE_IDLE				= 0;
	localparam TX_STATE_IDCODE_1			= 1;
	localparam TX_STATE_IDCODE_2			= 2;
	localparam TX_STATE_KEEPALIVE			= 3;
	localparam TX_STATE_RPC_1				= 4;
	localparam TX_STATE_RPC_2				= 5;
	localparam TX_STATE_DMA_1				= 6;
	localparam TX_STATE_DMA_2				= 7;
	localparam TX_STATE_DMA_3				= 8;
	localparam TX_STATE_DMA_4				= 9;
	localparam TX_STATE_DMA_5				= 10;
	
	reg[3:0] jtag_tx_state = TX_STATE_IDLE;
	
	//Interface from JTAG clock domain to RPC network receives
	wire rpc_rx_en_jtag;
	reg rpc_rx_ack_jtag = 0;
	reg[1:0] rpc_rxbuf_raddr = 0;
	wire[31:0] rpc_rxbuf_rdata;
	
	//Make a note of a pending receive
	reg rpc_rx_en_jtag_pending			= 0;
	reg dma_rx_en_jtag_pending			= 0;
	
	//Interface from DMA clock domain to RPC network receives
	wire drx_en_jtag;
	reg drx_done_jtag					= 0;
	
	reg[10:0] drx_buf_addr_buf			= 0;
	
	//Keep track of what type the last NoC frame was
	//so we don't have heavy RPC load DoS the DMA network
	reg		last_packet_was_rpc			= 0;

	always @(posedge jtag_tck_bufh) begin
	
		//Clear flags
		pending_idcode_clear <= 0;
		rpc_rx_ack_jtag <= 0;
		drx_done_jtag <= 0;
		if(drx_buf_rd)
			drx_buf_addr_buf <= drx_buf_addr;
		
		//Keep track of pending messages if we're busy
		if(rpc_rx_en_jtag)
			rpc_rx_en_jtag_pending <= 1;
		if(drx_en_jtag)
			dma_rx_en_jtag_pending <= 1;

		if(jtag_new_word) begin
			
			case(jtag_tx_state)
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// Idle? Wait for something to happen
				
				TX_STATE_IDLE: begin
				
					//We're sending something no matter what
					jtag_tx_next <= JTAG_FRAME_PREAMBLE;
				
					//Respond to the IDCODE request
					if(pending_idcode_flag)
						jtag_tx_state <= TX_STATE_IDCODE_1;
					
					//If we have a message to send from either network, pick one
					else if(rpc_rx_en_jtag_pending || rpc_rx_en_jtag || dma_rx_en_jtag_pending || drx_en_jtag) begin
					
						//Last packet RPC? DMA has priority
						if(last_packet_was_rpc) begin
							if(dma_rx_en_jtag_pending || drx_en_jtag)
								jtag_tx_state <= TX_STATE_DMA_1;
							else
								jtag_tx_state <= TX_STATE_RPC_1;						
						end
						
						//Nope, RPC has priority
						else begin
							if(rpc_rx_en_jtag_pending || rpc_rx_en_jtag)
								jtag_tx_state <= TX_STATE_RPC_1;
							else
								jtag_tx_state <= TX_STATE_DMA_1;
						end
					
					end					
						
					//Send keepalive if there's nothing else
					else
						jtag_tx_state <= TX_STATE_KEEPALIVE;
					
				end
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// IDCODE packet
				
				//op IDCODE, 1 data word, normal header stuff
				TX_STATE_IDCODE_1: begin
					pending_idcode_clear <= 1;
					jtag_tx_next <= { JTAG_FRAME_TYPE_IDCODE, 10'h1, sequence, credits };
					jtag_tx_state <= TX_STATE_IDCODE_2;
				end
				
				//Data is one word: magic deadc0de
				TX_STATE_IDCODE_2: begin
					jtag_tx_next <= JTAG_FRAME_MAGIC;
					jtag_tx_state <= TX_STATE_IDLE;
				end
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// KEEPALIVE packet
				
				//op KEEPALIVE, no data words, normal header stuff
				TX_STATE_KEEPALIVE: begin
					jtag_tx_next <= { JTAG_FRAME_TYPE_KEEPALIVE, 10'h0, sequence, credits };
					jtag_tx_state <= TX_STATE_IDLE;
				end
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// RPC packet
				
				//op RPC, 4 data words, normal header stuff
				TX_STATE_RPC_1: begin
					last_packet_was_rpc		<= 1;
					rpc_rx_en_jtag_pending	<= 0;
					jtag_tx_next			<= { JTAG_FRAME_TYPE_RPC, 10'h4, sequence, credits };
					
					rpc_rxbuf_raddr			<= 0;
					jtag_tx_state			<= TX_STATE_RPC_2;
				end
				
				//Send the actual frame
				TX_STATE_RPC_2: begin
					jtag_tx_next <= rpc_rxbuf_rdata;
					rpc_rxbuf_raddr <= rpc_rxbuf_raddr + 2'h1;
					
					if(rpc_rxbuf_raddr == 3) begin
						rpc_rx_ack_jtag <= 1;					
						jtag_tx_state <= TX_STATE_IDLE;
					end
				end
	
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// DMA packet
				
				//op DMA, ?? data words, normal header stuff
				TX_STATE_DMA_1: begin
					last_packet_was_rpc		<= 1;
					dma_rx_en_jtag_pending	<= 0;
					jtag_tx_next			<= { JTAG_FRAME_TYPE_DMA, drx_len + 10'h3, sequence, credits };
					jtag_tx_state			<= TX_STATE_DMA_2;
				end
				
				//DMA headers
				TX_STATE_DMA_2: begin
					jtag_tx_next <= { drx_src_addr, drx_dst_addr };
					jtag_tx_state <= TX_STATE_DMA_3;
				end
				TX_STATE_DMA_3: begin
					jtag_tx_next <= { drx_op, 20'h0, drx_len };
					jtag_tx_state <= TX_STATE_DMA_4;
				
				end				
				TX_STATE_DMA_4: begin
					jtag_tx_next <= drx_addr;
					jtag_tx_state <= TX_STATE_DMA_5;
					
					//Continue reading data
					drx_buf_addr <= 0;
					drx_buf_rd <= 1;
				end
				
				//DMA data
				TX_STATE_DMA_5: begin
				
					//Send this data word
					jtag_tx_next <= drx_buf_data;
			
					//Stop if we're at the end
					if((drx_buf_addr_buf + 10'd1) >= drx_len) begin
						drx_done_jtag <= 1;
						jtag_tx_state <= TX_STATE_IDLE;
					end
					
					//No, keep going and read the next word
					else begin
						drx_buf_addr <= drx_buf_addr + 10'h1;
						drx_buf_rd <= 1;
					end

				end
			
			endcase
			
		end
		
		//Clear everything on reset
		if(jtag_reset)
			jtag_tx_state <= TX_STATE_IDLE;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Network transmit logic, network clock domain
	
	localparam NET_TX_STATE_IDLE			= 0;
	localparam NET_TX_STATE_HEADER_WAIT_1	= 1;
	localparam NET_TX_STATE_HEADER_WAIT_2	= 2;
	localparam NET_TX_STATE_HEADER			= 3;
	localparam NET_TX_STATE_RPC_HOLD		= 4;
	localparam NET_TX_STATE_DMA_0			= 5;
	localparam NET_TX_STATE_DMA_1			= 6;
	localparam NET_TX_STATE_DMA_2			= 7;
	localparam NET_TX_STATE_DMA_3			= 8;
	localparam NET_TX_STATE_DMA_HOLD		= 9;
	
	reg[3:0] net_tx_state					= NET_TX_STATE_IDLE;
	reg[3:0] net_tx_state_next				= NET_TX_STATE_IDLE;
	
	reg[9:0] dtx_len_next					= 0;
	reg[15:0] dtx_src_addr_next				= 0;
	reg[15:0] dtx_dst_addr_next				= 0;
	reg[1:0] dtx_op_next					= 0;
	reg[31:0] dtx_addr_next					= 0;
	
	reg[31:0] tx_fifo_rdata_buf				= 0;
	reg[10:0] tx_fifo_ready_count_buf		= 0;
	always @(posedge clk_noc) begin
		tx_fifo_rdata_buf		<= tx_fifo_rdata;
		tx_fifo_ready_count_buf	<= tx_fifo_ready_count;
	end
	
	//Combinatorial state logic
	always @(*) begin
		
		net_tx_state_next <= net_tx_state;
		dtx_len_next <= dtx_len;
		dtx_src_addr_next <= dtx_src_addr;
		dtx_dst_addr_next <= dtx_dst_addr;
		dtx_done_next <= 0;
		dtx_op_next <= dtx_op;
		dtx_addr_next <= dtx_addr;
		tx_fifo_read <= 0;
		rpc_fab_tx_en <= 0;
		dtx_en <= 0;
		rd_pop_packet <= 0;
		rd_packet_size <= 0;
		rd_offset <= 0;
		rd_en <= 0;
		
		//FIFO reads can come from state machine, DMA transceiver, or RPC transceiver
		if(tx_fifo_read)
			rd_en <= 1;
		if(dtx_rd) begin
			rd_offset <= dtx_raddr[8:0];
			rd_en <= 1;
		end		
		if(rpc_txbuf_rd) begin
			rd_offset <= rpc_txbuf_raddr;
			rd_en <= 1;
		end

		case(net_tx_state)
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Nothing happening yet
			NET_TX_STATE_IDLE: begin
					
				//If there's enough data for a packet, read the first word and see
				if(tx_fifo_ready_count >= 4)			
					net_tx_state_next <= NET_TX_STATE_HEADER_WAIT_1;
				
			end
			
			///////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for read of packet header
			
			NET_TX_STATE_HEADER_WAIT_1: begin
				tx_fifo_read <= 1;
				net_tx_state_next <= NET_TX_STATE_HEADER_WAIT_2;
			end
			
			NET_TX_STATE_HEADER_WAIT_2: begin
				net_tx_state_next		<= NET_TX_STATE_HEADER;
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// We have a packet of some sort. Figure out what it is.
			NET_TX_STATE_HEADER: begin
				
				//Update dtx_len unconditionally to take the comparator off the critical path
				dtx_len_next <= tx_fifo_rdata_buf[28:19];
				
				//Check if we have at least len words of data in the FIFO
				if( tx_fifo_ready_count_buf >= (tx_fifo_rdata_buf[28:19]) ) begin
					
					//RPC packet, send it
					if(tx_fifo_rdata_buf[31:29] == JTAG_FRAME_TYPE_RPC) begin
						net_tx_state_next <= NET_TX_STATE_RPC_HOLD;
						rpc_fab_tx_en <= 1;
					end
					
					//DMA is only other valid opcode at this point, nothing else will make it into the fifo
					
					else /* if(tx_fifo_rdata_buf[31:29] == JTAG_FRAME_TYPE_DMA) */ begin
						net_tx_state_next <= NET_TX_STATE_DMA_0;						
						tx_fifo_read <= 1;
					end
					
				end
				
				//Not enough data is here.
				//Block in this state until it shows up.
				else begin
				end

			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Send an RPC message
			
			NET_TX_STATE_RPC_HOLD: begin
				
				if(rpc_fab_tx_done) begin
					rd_pop_packet <= 1;
					rd_packet_size <= 4;
					net_tx_state_next <= NET_TX_STATE_IDLE;
				end
			
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Send a DMA message
			
			//TODO: Figure out better DMA protocol that lets us stream more here? We're wasting flipflops serializing
			//and deserializing for no good reason.
			
			//Cycle 0: NoC header
			NET_TX_STATE_DMA_0: begin
				tx_fifo_read <= 1;
				dtx_src_addr_next <= tx_fifo_rdata[31:16];
				dtx_dst_addr_next <= tx_fifo_rdata[15:0];
				net_tx_state_next <= NET_TX_STATE_DMA_1;
			end
			
			//Cycle 1: Opcode/len
			NET_TX_STATE_DMA_1: begin
				tx_fifo_read <= 1;
				dtx_op_next <= tx_fifo_rdata[31:30];
				dtx_len_next <= tx_fifo_rdata[9:0];
				net_tx_state_next <= NET_TX_STATE_DMA_2;
			end
			
			//Cycle 2: Address
			NET_TX_STATE_DMA_2: begin
				dtx_addr_next <= tx_fifo_rdata;
				net_tx_state_next <= NET_TX_STATE_DMA_3;
			end
			
			//Hold for pop, then packet body
			NET_TX_STATE_DMA_3: begin
				net_tx_state_next <= NET_TX_STATE_DMA_HOLD;
				dtx_en <= 1;
			end
			
			NET_TX_STATE_DMA_HOLD: begin
				if( (!dtx_busy && !dtx_en) || DMA_DISABLE) begin
					net_tx_state_next <= NET_TX_STATE_IDLE;
					dtx_done_next <= 1;
					rd_pop_packet <= 1;
					rd_packet_size <= dtx_len;
				end
			end
			
		endcase

	end
	
	//Synchronous control and reset logic
	//TODO: Synchronize reset? May not be necessary since we're faster than TCK so we should get at least one good reset
	always @(posedge clk_noc) begin

		//Save states
		net_tx_state <= net_tx_state_next;
		
		//Save DMA transmit stuff
		dtx_len <= dtx_len_next;
		dtx_op <= dtx_op_next;
		dtx_addr <= dtx_addr_next;
		dtx_src_addr <= dtx_src_addr_next;
		dtx_dst_addr <= dtx_dst_addr_next;
		
		//Clear everything on reset
		if(jtag_reset)
			net_tx_state <= NET_TX_STATE_IDLE;
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Network receive logic, network clock domain
		
	localparam NET_RX_STATE_IDLE			= 0;
		
	reg[3:0] net_rx_state					= NET_RX_STATE_IDLE;
	reg[3:0] net_rx_state_next				= NET_RX_STATE_IDLE;
	
	//Buffer for RPC->JTAG transmits
	wire[3:0] unused_p2;
	LutramMacroSDP #(
		.WIDTH(36),
		.DEPTH(32)
	) rpc_rxbuf(
		.clk(clk_noc),
		.porta_we(rpc_fab_rx_we),
		.porta_addr({3'b0, rpc_fab_rx_waddr}),
		.porta_din({unused_p2, rpc_fab_rx_wdata}),
		
		.portb_addr({3'b0, rpc_rxbuf_raddr}),
		.portb_dout({unused_p2, rpc_rxbuf_rdata})
	);
	
	//Synchronization for RPC receives (no processing needed in this clock domain at all - transceiver does it all)
	HandshakeSynchronizer sync_rpc_rx(
		.clk_a(clk_noc),
		.busy_a(),
		.en_a(rpc_fab_rx_en),
		.ack_a(rpc_fab_rx_done),
		.clk_b(jtag_tck_bufh),
		.en_b(rpc_rx_en_jtag),
		.ack_b(rpc_rx_ack_jtag)
	);
	
	wire drx_done_net;
	generate
		if(!DMA_DISABLE) begin
		
			//Synchronization for DMA receives
			HandshakeSynchronizer sync_dma_rx(
				.clk_a(clk_noc),
				.busy_a(),
				.en_a(drx_en),
				.ack_a(drx_done_net),
				.clk_b(jtag_tck_bufh),
				.en_b(drx_en_jtag),
				.ack_b(drx_done_jtag)
			);
			
			//Done/ready flag stuff
			always @(posedge clk_noc) begin
				
				if(drx_done_net)
					drx_ready <= 1;
				if(drx_en)
					drx_ready <= 0;
					
				if(jtag_reset)
					drx_ready <= 1;
			end
			
		end
		else begin
			assign drx_en_jtag	= 0;
			assign drx_done_net = 1;
		end
	endgenerate
	
endmodule
