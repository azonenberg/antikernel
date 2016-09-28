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
	@brief Driver for ENC624J600
 */
module ENCx24Controller(
	clk,
	
	enc_cs, enc_rd, enc_wrl, enc_wrh, enc_addr, enc_data, enc_int_n,
	
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	uart_tx, uart_rx,
	
	leds
    );

	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	input wire clk;
	
	//Network interface
	output reg rpc_tx_en = 0;
	output reg[31:0] rpc_tx_data = 0;
	input wire rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output reg rpc_rx_ack = 0;
	
	output reg dma_tx_en = 0;
	output reg[31:0] dma_tx_data = 0;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output reg dma_rx_ack = 0;
	
	//Ethernet controller bus	
	output reg enc_cs = 0;
	output reg enc_rd = 0;
	output reg enc_wrl = 0;
	output reg enc_wrh = 0;
	output reg[14:0] enc_addr = 0;
	inout wire[15:0] enc_data;
	input wire enc_int_n;
	
	//Debug bus
	input wire uart_rx;
	output wire uart_tx;
	
	output reg[7:0] leds = 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Pull in constants
	`include "SocketAPIDefs.v"
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Transceiver logic
	
	/*
		Read transaction
		1	Raise CS
		2	Send address immediately
		3	Assert RD after 1 clock
		4	Wait 7 clocks, read data
		
		Write transaction
		1	Raise CS
		2	Send address and data immediately
		3	Strobe WRL/WRH after 1 clock
		4	Wait 1 clock, lower WR*
		5	Wait 1 clock before changing addr/data
		6	Wait 1 clock before strobing write for next word (if SFRs)
			or 4 clocks (if SRAM)
	 */

	//Tristate stuff for data bus	
	reg tx_active = 0;
	reg[15:0] tx_data_raw = 0;
	wire[15:0] rx_data_raw;
	IobufMacro #(.WIDTH(16)) enc_data_tristate (.din(rx_data_raw), .dout(tx_data_raw), .oe(tx_active), .io(enc_data));
		
	//Transceiver control
	localparam TX_STATE_IDLE		= 4'b0000;
	localparam TX_STATE_TX_1		= 4'b0001;
	localparam TX_STATE_TX_2		= 4'b0010;
	localparam TX_STATE_TX_WAIT	= 4'b0011;
	localparam TX_STATE_RX_1		= 4'b0100;
	localparam TX_STATE_RX_2		= 4'b0101;
	reg[3:0] tx_state = TX_STATE_IDLE;
	
	//Transmit datapath stuff
	reg tx_en = 0;
	reg[1:0] tx_en_we = 0;
	reg[14:0] tx_addr = 0;
	reg[15:0] tx_data = 0;
	
	//Receive datapath stuff
	reg rx_en = 0;
	reg[14:0] rx_addr = 0;
	reg[15:0] rx_out = 0;
	reg rx_rdy = 0;
	
	//Status
	wire bus_busy;
	assign bus_busy = (tx_state != TX_STATE_IDLE) || tx_en || rx_en;
	
	reg[1:0] tx_en_we_buf = 0;
	
	reg[4:0] tx_count = 0;
	
	//We always get a link-state interrupt at time 0 saying "link down"
	//asserted once we got it
	reg got_init_linkif = 0;
	reg got_init_linkif_raw = 0;	//asserted 1 clock early
	
	reg read_in_progress = 0;

	always @(posedge clk) begin
		
		case(tx_state)
			
			//Wait for tx or rx command
			TX_STATE_IDLE: begin
			
				rx_rdy <= 0;
				rx_out <= 0;
				
				//Select chip immediately
				if(tx_en) begin
					tx_state <= TX_STATE_TX_1;
					
					enc_cs <= 1;
					tx_active <= 1;
					enc_addr <= tx_addr;
					tx_data_raw <= tx_data;
					tx_en_we_buf <= tx_en_we;
				end
				
				if(rx_en) begin
					tx_state <= TX_STATE_RX_1;
					
					enc_cs <= 1;
					tx_active <= 0;
					enc_addr <= rx_addr;
				end
				
			end
			
			//Strobe WRL and WRH
			TX_STATE_TX_1: begin
				enc_wrl <= tx_en_we_buf[0];
				enc_wrh <= tx_en_we_buf[1];
				tx_state <= TX_STATE_TX_2;
			end
			
			//Lower write strobes
			TX_STATE_TX_2: begin
				enc_wrl <= 0;
				enc_wrh <= 0;
				tx_state <= TX_STATE_TX_WAIT;
				tx_count <= 0;
			end
			
			//Clear data after 8 clocks
			TX_STATE_TX_WAIT: begin
				
				tx_count <= tx_count + 4'h1;
				if(tx_count == 7) begin
					enc_addr <= 0;
					tx_data_raw <= 0;
					tx_active <= 0;
					enc_cs <= 0;
					tx_state <= TX_STATE_IDLE;
				end
				
			end
			
			//Strobe rd the next cycle
			TX_STATE_RX_1: begin
				enc_rd <= 1;
				tx_state <= TX_STATE_RX_2;
				tx_count <= 0;
			end
			
			//Wait 15 clocks (~100ns) for data to go valid
			TX_STATE_RX_2: begin
				tx_count <= tx_count + 4'h1;
				
				//Check if we're done
				//Read data and then deassert the read strobe
				if(tx_count == 15) begin
					enc_cs <= 0;
					enc_rd <= 0;
					tx_state <= TX_STATE_IDLE;
					rx_rdy <= 1;
					rx_out <= rx_data_raw;
				end
			end
			
		endcase
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transmit logic - fire-and-forget
	localparam HEALTH_ADDRESS = 16'h8017;	
	
	localparam RPC_TX_IDLE = 0;
	localparam RPC_TX_HEADER = 1;
	localparam RPC_TX_DATA1 = 2;
	localparam RPC_TX_DATA2 = 3;
	
	reg[1:0] rpc_tx_state = RPC_TX_IDLE;	
	reg rpc_tx_start = 0;
	reg[15:0] rpc_tx_addr = 0;
	reg[31:0] rpc_tx_data0 = 0;
	reg[31:0] rpc_tx_data1 = 0;
	reg[31:0] rpc_tx_data2 = 0;
	wire rpc_tx_busy;
	assign rpc_tx_busy = (rpc_tx_en || (rpc_tx_state != RPC_TX_IDLE));
	always @(posedge clk) begin
		rpc_tx_en <= 0;
		rpc_tx_data <= 0;
		
		case(rpc_tx_state)
			
			RPC_TX_IDLE: begin
				if(rpc_tx_start) begin
					rpc_tx_en <= 1;
					rpc_tx_data <= {16'h0000, rpc_tx_addr };
					rpc_tx_state <= RPC_TX_HEADER;
				end
			end	//end RPC_TX_IDLE
			
			RPC_TX_HEADER: begin
				if(rpc_tx_ack) begin
					rpc_tx_data <= rpc_tx_data0;
					rpc_tx_state <= RPC_TX_DATA1;
				end
				else begin
					rpc_tx_en <= 1;
					rpc_tx_data <= {16'h0000, rpc_tx_addr };
				end
			end	//end RPC_TX_HEADER
			
			RPC_TX_DATA1: begin
				rpc_tx_data <= rpc_tx_data1;
				rpc_tx_state <= RPC_TX_DATA2;
			end	//end RPC_TX_DATA1
			
			RPC_TX_DATA2: begin
				rpc_tx_data <= rpc_tx_data2;
				rpc_tx_state <= RPC_TX_IDLE;
			end	//end RPC_TX_DATA2
			
		endcase
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// SFR address map
	
	/*
		Eeach address points to a 16-bit word (for 16-bit parallel modes only)
		
		0000 - 2FFF					SRAM
		3000 - 3EFF					Not mapped (on chip DMA only, or unimplemented)
		3F00 - 3F4F					SFRs
		3F80 - 3FBF					SFR set registers (reg + 80)
		3FC0 - 3FFF					SFR clear registers (reg + C0)
	 */
	localparam REG_SET_OFFSET		= 15'h0080;
	localparam REG_CLEAR_OFFSET	= 15'h00C0;
	 
	localparam REG_ETXST		= 15'h3F00;
	localparam REG_ETXLEN	= 15'h3F01;
	localparam REG_ERXST		= 15'h3F02;
	localparam REG_ERXTAIL	= 15'h3F03;
	localparam REG_ERXHEAD	= 15'h3F04;
	localparam REG_EDMAST	= 15'h3F05;
	localparam REG_EDMALEN	= 15'h3F06;
	localparam REG_EDMADST	= 15'h3F07;
	localparam REG_EDMACS	= 15'h3F08;
	localparam REG_ETXSTAT	= 15'h3F09;
	localparam REG_ETXWIRE	= 15'h3F0A;
	localparam REG_EUDAST	= 15'h3F0B;
	localparam REG_EUDAND	= 15'h3F0C;
	localparam REG_ESTAT		= 15'h3F0D;
	localparam REG_EIR		= 15'h3F0E;
	localparam REG_ECON1		= 15'h3F0F;
	
	localparam REG_EHT1		= 15'h3F10;
	localparam REG_EHT2		= 15'h3F11;
	localparam REG_EHT3		= 15'h3F12;
	localparam REG_EHT4		= 15'h3F13;
	localparam REG_EPMM1		= 15'h3F14;
	localparam REG_EPMM2		= 15'h3F15;
	localparam REG_EPMM3		= 15'h3F16;
	localparam REG_EPMM4		= 15'h3F17;
	localparam REG_EPMCS		= 15'h3F18;
	localparam REG_EPMO		= 15'h3F19;
	localparam REG_ERXFCON	= 15'h3F1A;
	//3F1B is alternate mapping of EUDAST
	//3F1C is alternate mapping of EUDAND
	//3F1D is alternate mapping of ESTATE
	//3F1E is alternate mapping of EIR
	//3F1F is alternate mapping of ECON1
	
	localparam REG_MACON1	= 15'h3F20;
	localparam REG_MACON2	= 15'h3F21;
	localparam REG_MABBIPG	= 15'h3F22;
	localparam REG_MAIPG		= 15'h3F23;
	localparam REG_MACLCON	= 15'h3F24;
	localparam REG_MAMXFL	= 15'h3F25;
	//3F26 is reserved
	//3F27 is reserved
	//3F28 is reserved
	localparam REG_MICMD		= 15'h3F29;
	localparam REG_MIREGADR	= 15'h3F2A;
	//3F2B is alternate mapping of EUDAST
	//3F2C is alternate mapping of EUDAND
	//3F2D is alternate mapping of ESTAT
	//3F2E is alternate mapping of EIR
	//3F2F is alternate mapping of ECON1
	
	localparam REG_MAADR3	= 15'h3F30;
	localparam REG_MAADR2	= 15'h3F31;
	localparam REG_MAADR1	= 15'h3F32;
	localparam REG_MIWR		= 15'h3F33;
	localparam REG_MIRD		= 15'h3F34;
	localparam REG_MISTAT	= 15'h3F35;
	localparam REG_EPAUS		= 15'h3F36;
	localparam REG_ECON2		= 15'h3F37;
	localparam REG_ERXWM		= 15'h3F38;
	localparam REG_EIE		= 15'h3F39;
	localparam REG_EIDLED	= 15'h3F3A;
	//3F3B is alternate mapping of EUDAST
	//3F3C is alternate mapping of EUDAND
	//3F3D is alternate mapping of ESTAT
	//3F3E is alternate mapping of EIR
	//3F3F is alternate mapping of ECON1
	
	localparam REG_EGPDATA	= 15'h3F40;
	localparam REG_ERXDATA	= 15'h3F41;
	localparam REG_EUDADATA	= 15'h3F42;
	localparam REG_EGPRDPT	= 15'h3F43;
	localparam REG_EGPWRPT	= 15'h3F44;
	localparam REG_ERXRDPT	= 15'h3F45;
	localparam REG_ERXWRPT	= 15'h3F46;
	localparam REG_EUDARDPT	= 15'h3F47;
	localparam REG_EUDAWRPT	= 15'h3F48;
	//3F49 is reserved
	//3F4A is reserved
	//3F4B is reserved
	//3F4C is reserved
	//3F4D is reserved
	//3F4E is reserved
	//3F4F is not implemented
	
	localparam REG_ECON2SET	= REG_ECON2 + REG_SET_OFFSET;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// PHY registers
	localparam REG_PHCON1		= 'h00;
	localparam REG_PHSTAT1		= 'h01;
	//02 is reserved
	//03 is reserved
	localparam REG_PHANA			= 'h04;
	localparam REG_PHANLPA		= 'h05;
	localparam REG_PHANE			= 'h06;
	//07 - 0F is not implemented
	//10 is reserved
	localparam REG_PHCON2		= 'h11;
	//12 is reserved
	//13 is unimplemented
	//14-17 is reserved
	//18-1A is unimplemented
	localparam REG_PHSTAT2		= 'h1B;
	//1C-1E is reserved
	localparam REG_PHSTAT3		= 'h1F;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Main control logic
	localparam STATE_POST_0 		= 'h00;
	localparam STATE_POST_1			= 'h01;
	localparam STATE_POST_2 		= 'h02;
	localparam STATE_POST_3 		= 'h03;
	localparam STATE_POST_4			= 'h04;
	localparam STATE_POST_5			= 'h05;
	localparam STATE_POST_6			= 'h06;
	localparam STATE_POST_7 		= 'h07;
	localparam STATE_POST_8 		= 'h08;
	localparam STATE_READY			= 'h09;
	//localparam STATE_MAC				= 'h0A;
	localparam STATE_INIT_1			= 'h0B;
	localparam STATE_INIT_2			= 'h0C;
	localparam STATE_INIT_3			= 'h0D;
	localparam STATE_HOLD			= 'h0E;
	localparam STATE_ISR				= 'h0F;
	localparam STATE_LINK_ISR		= 'h10;
	localparam STATE_PHY_READ		= 'h11;
	localparam STATE_PHY_READ_2	= 'h12;
	localparam STATE_PHY_READ_3	= 'h13;
	localparam STATE_PHY_READ_4	= 'h14;
	localparam STATE_PHY_READ_5	= 'h15;
	localparam STATE_PHY_READ_6	= 'h16;
	localparam STATE_LINK_ISR_2	= 'h17;
	localparam STATE_LINK_ISR_3	= 'h18;
	//localparam STATE_READ_START	= 'h19;
	//localparam STATE_READ_RSV		= 'h1A;
	localparam STATE_INIT_4			= 'h1B;
	//localparam STATE_READSTREAM_2	= 'h1C;
	//localparam STATE_PACKET_DONE	= 'h1D;
	localparam STATE_INIT_5			= 'h1E;
	//localparam STATE_SEND_1			= 'h1F;
	//localparam STATE_SEND_2			= 'h20;
	//localparam STATE_SEND_3			= 'h21;
	//localparam STATE_SEND_4			= 'h22;
	localparam STATE_LINK_ISR_4	= 'h23;
	
	reg[5:0] state = STATE_POST_0;	
	
	//state to return to upon completion of PHY read/write
	reg[4:0] phy_ret_state = STATE_POST_0;
	
	//PHY read/write parameters
	reg[4:0] phy_regid = 0;
	reg[15:0] phy_data = 0;

	reg[11:0] reset_count = 0;
	reg[3:0] reset_count_2 = 0;
	
	//Pointer to start of the read buffer
	/*
		The ENC624J600's total buffer goes from 0x0000 to 0x5FFF.
		
		The first 2K bytes (0x0000 - 0x07FF) are allocated for transmit buffer / scratch space.
		The remainder (0x0800 - 0x5FFF) are the receive buffer.
	 */
	reg[14:0] rx_buffer_start = 15'h0800;
	reg[14:0] next_packet_pointer = 15'h0000;
	
	//Pointer to the packet currently being read
	reg[14:0] current_packet_pointer = 15'h0000;
	
	//Incremented pointers before wraparound
	//Leave one extra bit to detect overflow
	wire[15:0] next_packet_pointer_inc_temp;
	wire[15:0] current_packet_pointer_inc_temp;
	assign next_packet_pointer_inc_temp = next_packet_pointer + 16'h0002;
	assign current_packet_pointer_inc_temp = current_packet_pointer + 16'h0002;
	
	//Incremented pointers after wraparound
	wire[14:0] next_packet_pointer_inc;
	wire[14:0] current_packet_pointer_inc;
	assign next_packet_pointer_inc = next_packet_pointer_inc_temp[15] ?
		rx_buffer_start : next_packet_pointer_inc_temp[14:0];
	assign current_packet_pointer_inc = current_packet_pointer_inc_temp[15] ?
		rx_buffer_start : current_packet_pointer_inc_temp[14:0];
		
	//Receive Status Vector
	reg[39:0] rsv = 0;
	reg[7:0] wordcount = 0;
	
	reg[9:0] tx_ptr = 0;		//points to up to 1k words (2k bytes); cannot write anywhere else
	
	reg link_state = 0;
	reg duplex_state = 0;
	
	always @(posedge clk) begin
	
		tx_en <= 0;
		tx_addr <= 0;
		tx_data <= 0;
		tx_en_we <= 0;

		rx_en <= 0;
		
		rpc_tx_start <= 0;
	
		case(state)
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// POST and initialization
			
			//POST is modeled on section 8.1 of the ENC624J600 datasheet
			//Write 1234 to EUDAST
			STATE_POST_0: begin
						
				//if(start) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_EUDAST;
					tx_data <= 16'h1234;
					state <= STATE_POST_1;
				//end
			end
			
			//Wait for transmit to finish, then read EUDAST
			STATE_POST_1: begin
				if(!bus_busy) begin
					rx_en <= 1;
					rx_addr <= REG_EUDAST;
					state <= STATE_POST_2;
				end
			end
			
			//Wait for EUDAST data to come back, then make sure it's correct
			STATE_POST_2: begin
				if(rx_rdy) begin
					
					//All is well, keep going
					if(rx_out == 16'h1234) begin
						state <= STATE_POST_3;
					end
					
					//No go, try again - chip might still be booting
					//TODO: put a timer in here to give up after 1ms
					else begin
						state <= STATE_POST_0;
					end
					
				end
			end
			
			//Poll ESTAT until bit 12 (CLKRDY) is set
			STATE_POST_3: begin
			
				rx_en <= 1;
				rx_addr <= REG_ESTAT;
				state <= STATE_POST_4;
			end
	
			STATE_POST_4: begin
				if(rx_rdy) begin
					if(rx_out[12])
						state <= STATE_POST_5;
					else
						state <= STATE_POST_3;
				end
			end
			
			//Reset the chip by setting ECON2[4] (ETHRST)
			STATE_POST_5: begin
				tx_en <= 1;
				tx_addr <= REG_ECON2SET;
				tx_en_we <= 2'b11;
				tx_data <= 16'h0010;
				state <= STATE_POST_6;
				reset_count <= 1;
			end
			
			//Wait at least 25us (4000 clocks). 4096 is such a nice round number, though...
			STATE_POST_6: begin
				reset_count <= reset_count + 12'h1;
				if(reset_count == 0) begin
					rx_en <= 1;
					rx_addr <= REG_EUDAST;
					state <= STATE_POST_7;
				end
			end
			
			//Verify reset took place
			STATE_POST_7: begin
	
				if(rx_rdy) begin
				
					//All is well
					//Need to wait a further 256us for PHY registers to become available
					//but the rest of the chip is available now
					if(rx_out == 0) begin
						state <= STATE_POST_8;
						reset_count <= 1;
						reset_count_2 <= 1;
					end
					
					//Reset failure, give up and try again
					else begin
						state <= STATE_POST_0;
					end
				end

			end
			
			//256 us @ 80 MHz = 20480 clocks
			//but 32768 is a nice round number
			STATE_POST_8: begin
				reset_count <= reset_count + 11'h1;
		
				if(reset_count == 0)
					reset_count_2 <= reset_count_2 + 4'h1;
					
				if(reset_count_2 == 0 ) begin
					state <= STATE_INIT_1;
					next_packet_pointer <= rx_buffer_start;
				end
			end
			
			//Initialize receive buffer pointer
			STATE_INIT_1: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_addr <= REG_ERXST;
					tx_en_we <= 2'b11;
					tx_data <= rx_buffer_start;
					state <= STATE_INIT_2;
				end
			end
			
			//Set up interrupt enables
			STATE_INIT_2: begin	
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_EIE;
					tx_data <= {
						1'b1,			//Interrupts enabled
						3'b0,			//Crypto interrupts disabled,
						1'b1,			//Link-state change interrupts enabled
						4'b0,			//Reserved, must be zero
						1'b1,			//Enable receive-packet-pending interrupt
						1'b0,			//Disable DMA interrupt
						1'b0,			//Reserved
						1'b1,			//Enable transmit-done interrupt
						2'b11,		//Enable transmit-error interrupts
						1'b1			//Enable packet-counter-full interrupt
						};
					state <= STATE_INIT_3;
				end
			end
			
			//Default receive filters are OK:
			//Reject bad CRC
			//Reject truncated packets
			//Accept unicast packets destined for our MAC
			//Accept broadcast packets
			//Set MTU
			STATE_INIT_3: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_MAMXFL;
					tx_data <= 16'd1518;		//default MTU from datasheet
					state <= STATE_INIT_4;
				end
			end
			
			//Set ERXTAIL
			STATE_INIT_4: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_ERXTAIL;
					tx_data <= 16'h5ffe;		//last valid address
					state <= STATE_INIT_5;
				end
			end
			
			//Enable receipt of layer 2 multicast
			STATE_INIT_5: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_ERXFCON + REG_SET_OFFSET;
					tx_data <= 16'h0002;
					state <= STATE_HOLD;
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Command processing
			/*
			//Read the MAC address
			STATE_MAC: begin
				if(rx_rdy) begin
					cmd_data_out <= {rx_out[7:0], rx_out[15:8]};	//byte swap
					cmd_data_valid <= 1;
					
					case(reset_count)
						0: begin
							rx_en <= 1;
							rx_addr <= REG_MAADR2;
							reset_count <= 1;
						end
						1: begin
							rx_en <= 1;
							rx_addr <= REG_MAADR3;
							reset_count <= 2;
						end
						2: begin
							state <= STATE_HOLD;
						end
						
					endcase
				end
			end
			*/
			
			//Go to STATE_READY once the current operation is done
			STATE_HOLD: begin
				if(!bus_busy) begin
					state <= STATE_READY;
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Interrupt processing
			STATE_ISR: begin

				if(rx_rdy) begin
					
					//Default to going back to ready state - some interrupts can be handled in one clock.
					//Any ISR that needs >1 clock should change these appropriately.
					state <= STATE_READY;
					
					//Dispatch one interrupt at a time below. Highest priority first.
					
					//PHY link state changed
					if(rx_out[11]) begin
					
						//Read ESTAT
						rx_en <= 1;
						rx_addr <= REG_ESTAT;
						
						state <= STATE_LINK_ISR;
					end
					
					//Packet received
					else if(rx_out[6]) begin
						//TODO: Send RPC notification to ethernet module
						leds[7] <= 1;
					end
					
				end
			end
			
			//Link status changed
			//Find out what the new link state is
			STATE_LINK_ISR: begin
				if(rx_rdy) begin
					link_state <= rx_out[8];
					duplex_state <= rx_out[10];
					
					//clear LINKIF
					tx_en <= 1;
					tx_addr <= REG_EIR + REG_CLEAR_OFFSET;
					tx_data <= 16'h0800;
					tx_en_we <= 2'b11;
					
					state <= STATE_LINK_ISR_2;
					
					//got_init_linkif_raw <= 1;
				end			
			end
			
			//Set duplex state in MAC
			STATE_LINK_ISR_2: begin
				if(!bus_busy) begin
				
					//Set or clear MACON2.FULDPX as appropriate
					tx_en <= 1;
					tx_en_we <= 2'b11;
					if(duplex_state)
						tx_addr <= REG_MACON2 + REG_SET_OFFSET;
					else
						tx_addr <= REG_MACON2 + REG_CLEAR_OFFSET;
					tx_data <= 16'h0001;
				
					state <= STATE_LINK_ISR_3;
				end
			end
			
			//Enable packet reception
			STATE_LINK_ISR_3: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_ECON1 + REG_SET_OFFSET;
					tx_data <= 16'h0001;

					state <= STATE_LINK_ISR_4;
				end
			end
			
			STATE_LINK_ISR_4: begin
			
				//TODO: send speed
				if(!rpc_tx_busy) begin
					rpc_tx_start <= 1;
					rpc_tx_addr <= HEALTH_ADDRESS;
					rpc_tx_data0 <= {8'h00, 16'h00, 6'h00, duplex_state, link_state};
				end
			
				state <= STATE_HOLD;
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Read from PHY
			
			//Set target address
			STATE_PHY_READ: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_MIREGADR;
					tx_data <= {8'h01, 3'h0, phy_regid};
					state <= STATE_PHY_READ_2;
				end
			end
			
			//Request the read
			STATE_PHY_READ_2: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_MICMD;
					tx_data <= 16'h0001;	//MII read
					state <= STATE_PHY_READ_3;
				end
			end
			
			//Poll MII busy bit
			STATE_PHY_READ_3: begin
				if(!bus_busy) begin
					rx_en <= 1;
					rx_addr <= REG_MISTAT;
					state <= STATE_PHY_READ_4;
				end
			end
			STATE_PHY_READ_4: begin
				if(rx_rdy) begin
					if(!rx_out[0]) begin
						//No longer busy
						//Clear MIIRD
						tx_en <= 1;
						tx_en_we <= 2'b11;
						tx_addr <= REG_MICMD;
						tx_data <= 16'h0000;	//no-op
						state <= STATE_PHY_READ_5;
					end
					else begin
						//Still busy, poll again
						state <= STATE_PHY_READ_3;
					end
				end
			end
			
			//Read from MIRD
			STATE_PHY_READ_5: begin
				if(!bus_busy) begin
					rx_en <= 1;
					rx_addr <= REG_MIRD;
					state <= STATE_PHY_READ_6;
				end
			end
			STATE_PHY_READ_6: begin
				if(rx_rdy) begin
					state <= phy_ret_state;
					phy_data <= rx_out;
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Reading a packet - initialization
			/*
			STATE_READ_START: begin
				if(rx_rdy) begin
					//Save address of next packet
					next_packet_pointer <= {1'b0, rx_out[14:0]};
					
					//Get ready to read the RSV
					wordcount <= 0;
					rsv <= 0;
					state <= STATE_READ_RSV;
					rx_addr <= {2'b0, current_packet_pointer[14:1]};
					rx_en <= 1;
					
					//Bump read pointer
					current_packet_pointer <= current_packet_pointer_inc;
				end
			end

			STATE_READ_RSV: begin
				if(rx_rdy) begin
					case(wordcount)
						
						//Store low-order chunk and read the next one
						0: begin
							rsv[15:0] <= rx_out;
							rx_en <= 1;
							rx_addr <= {2'b0, current_packet_pointer[14:1]};
							current_packet_pointer <= current_packet_pointer_inc;
							wordcount <= 1;
						end
						
						//Store middle chunk and read the last
						1: begin
							rsv[31:15] <= rx_out;
							rx_en <= 1;
							rx_addr <= {2'b0, current_packet_pointer[14:1]};
							current_packet_pointer <= current_packet_pointer_inc;
							wordcount <= 2;
						end
						
						//Store last chunk
						2: begin
							rsv[39:31] <= rx_out[7:0];
							
							//Output length
							cmd_data_out <= rsv[15:0];
							cmd_data_valid <= 1;
							cmd_busy <= 0;
							cmd_status <= STATUS_OK;
							state <= STATE_READY;
						end
						
					endcase
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Reading a packet - streaming
			STATE_READSTREAM_2: begin
				if(rx_rdy) begin
					cmd_data_valid <= 1;
					cmd_data_out <= {rx_out[7:0], rx_out[15:8]};	//swap endianness
					state <= STATE_READY;
					cmd_status <= STATUS_OK;
					cmd_busy <= 0;
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Reading a packet - finishing up
			
			//Set PKTDEC
			STATE_PACKET_DONE: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_ECON1 + REG_SET_OFFSET;
					tx_data <= 16'h0100;
					state <= STATE_HOLD;
					
					//Clear packet_ready now, if interrupt is still asserted it'll go high again
					packet_ready <= 0;
					read_in_progress <= 0;
					got_first_packet <= 1;
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Sending a packet
			
			STATE_SEND_1: begin
				if(!bus_busy) begin
					//Set transmit buffer start
					tx_en <= 1;
					tx_en_we <= 2'b11;
					tx_addr <= REG_ETXST;
					tx_data <= 16'h00;
					state <= STATE_SEND_2;
				end
			end
			
			//Actually send it
			STATE_SEND_2: begin
				if(!bus_busy) begin
					tx_en <= 1;
					tx_en_we <= 1;
					tx_addr <= REG_ECON1 + REG_SET_OFFSET;
					tx_data <= 16'h02;
					state <= STATE_SEND_3;
				end
			end
			
			//Wait until transmit is finished
			//TODO: something interrupt based so we can still receive during the transmit.
			//For now, polling will work.
			STATE_SEND_3: begin
				if(!bus_busy) begin
					rx_en <= 1;
					rx_addr <= REG_ECON1;
					state <= STATE_SEND_4;
				end
			end
			
			STATE_SEND_4: begin
				if(rx_rdy) begin
					
					//Transmit still active
					if(rx_out[1]) begin
						state <= STATE_SEND_3;
					end
					
					//Transmit done
					else begin
						state <= STATE_HOLD;
					end
					
				end
			end
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Idle state
			*/
			STATE_READY: begin
				
				leds[0] <= 1;
				
				if(rpc_rx_en) begin
					/*
					case(cmd_opcode)
						NIC_OP_GETMAC: begin
							rx_en <= 1;
							rx_addr <= REG_MAADR1;
							reset_count <= 0;
							state <= STATE_MAC;
							cmd_busy <= 1;
						end
						
						//Prepare to do a read
						NIC_OP_READSTART: begin
							
							//invalid read request - cant do a read during another read
							//or when no data is available
							if(read_in_progress || !packet_ready) begin
								cmd_data_out <= 0;
								cmd_data_valid <= 1;
							end
							
							//Valid read - start it
							else begin
								read_in_progress <= 1;
								rx_en <= 1;
								rx_addr <= {2'b0, next_packet_pointer[14:1]};		//pointer to words, not bytes
								current_packet_pointer <= next_packet_pointer_inc;
								
								state <= STATE_READ_START;
								cmd_busy <= 1;
							end
							
						end
						
						//Read the next word of the current packet
						NIC_OP_READSTREAM: begin
							
							//Make sure we haven't hit the end of the packet.
							//If so, pad with null bytes
							if(current_packet_pointer == next_packet_pointer) begin
								cmd_data_valid <= 1;
								cmd_data_out <= 0;
								state <= STATE_HOLD;
							end
							
							//Read the next word
							else begin
								rx_en <= 1;
								rx_addr <= {2'b0, current_packet_pointer[14:1]};
								current_packet_pointer <= current_packet_pointer_inc;
								cmd_busy <= 1;
								state <= STATE_READSTREAM_2;
							end
							
						end
						
						//Finish up reading
						NIC_OP_READDONE: begin
							tx_en <= 1;
							tx_en_we <= 2'b11;
							tx_addr <= REG_ERXTAIL;
							
							//next_packet_pointer - 2, with wraparound
							if(next_packet_pointer == rx_buffer_start)
								tx_data <= 16'h5FFE;
							else
								tx_data <= next_packet_pointer - 15'h2;
								
							state <= STATE_PACKET_DONE;
							cmd_busy <= 1;
						end
						
						//Reset write pointer
						NIC_OP_WRITESTART: begin
							cmd_busy <= 0;
							cmd_status <= STATUS_OK;
							tx_ptr <= 0;
						end
						
						//Streaming write
						NIC_OP_WRITESTREAM: begin
							cmd_busy <= 1;
							
							//Do the write. Make sure to swap endianness...
							//the ENCx24J600 is little-endian internally for some operations!
							tx_en <= 1;
							tx_en_we <= 2'b11;
							tx_addr <= {5'b0, tx_ptr};
							tx_data <= {cmd_data_in[7:0], cmd_data_in[15:8]};
							
							//Update the pointer
							tx_ptr <= tx_ptr + 10'd1;
							
							//and wait for it to finish
							state <= STATE_HOLD;
							
						end
						
						//Send the packet!
						NIC_OP_SEND: begin
							cmd_busy <= 1;
							
							//Set the transmit buffer length
							tx_en <= 1;
							tx_en_we <= 2'b11;
							tx_addr <= REG_ETXLEN;
							tx_data <= cmd_data_in;
							
							state <= STATE_SEND_1;
							
						end
						
						default: begin
						end
					endcase*/
				end
				
				else if(dma_rx_en) begin
					
				end
				
				//Process interrupts
				else if(!enc_int_n) begin
					//Read the interrupt register
					rx_en <= 1;
					rx_addr <= REG_EIR;
					state <= STATE_ISR;
				end
				
			end
			
		endcase
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////
	//Logic analyzer
	/*
	RedTinUARTWrapper la(
		.clk(clk), 
		.din({
			packet_ready,		//1		127
			state,				//6		121
			tx_active,			//1		120
			tx_data_raw,		//16		104
			rx_data_raw,		//16		88
			enc_cs,				//1		87
			enc_rd,				//1		86
			enc_wrl,				//1		85
			enc_wrh,				//1		84
			enc_int_n,			//1		83
			enc_addr,			//15		68
			
			cmd_enable,			//1		67
			cmd_busy,			//1		66
			cmd_opcode,			//4		62
			cmd_data_in,		//16		46
			cmd_data_out,		//16		30
			cmd_data_valid,	//1		29
			
			start,				//1		28
			
			got_first_packet,	//1		27
			
			27'b0
				}), 
				
		.uart_tx(uart_tx), 
		.uart_rx(uart_rx)
		);
	*/
	
endmodule
