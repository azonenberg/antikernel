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
	@brief MDIO transceiver for 10/100/1000 Ethernet
	
	To write a PHY register:
		Wait for mgmt_busy_fwd to be cleared
		Set phy_reg_addr and phy_wr_data, assert phy_reg_wr
		Wait for mgmt_busy_fwd to be cleared
		
	To read a PHY register:
		Wait for mgmt_busy_fwd to be cleared
		Set phy_reg_addr, assert phy_reg_rd
		Wait for mgmt_busy_fwd to be cleared
		Read phy_rd_data;
 */
module EthernetMDIOTransceiver(
	clk_125mhz,
	mdio, mdc,
	mgmt_busy_fwd, phy_reg_addr, phy_wr_data, phy_rd_data, phy_reg_wr, phy_reg_rd
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input	wire		clk_125mhz;
	
	inout	wire		mdio;
	output	reg			mdc = 0;
	
	output	wire		mgmt_busy_fwd;
	input	wire[4:0]	phy_reg_addr;
	input	wire[15:0]	phy_wr_data;
	output	reg[15:0]	phy_rd_data = 0;
	input	wire		phy_reg_wr;
	input	wire		phy_reg_rd;
	
	parameter PHY_MD_ADDR = 5'b00001;
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O tristates
	
	reg mdio_tx_en = 0;
	reg mdio_tx_data = 0;
	wire mdio_rx_data;
	
	IobufMacro #(.WIDTH(1)) mdio_tristate (.din(mdio_rx_data), .dout(mdio_tx_data), .oe(mdio_tx_en), .io(mdio));

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Slow clock generation for MDC
	
	//125 / 2.5 MHz = 50x slower (400 ns, minimum allowed period)
	//Slow down by 60x instead (30 cycles between rising/falling edges) just to be safe
	reg[5:0] mdc_count = 0;
	reg mdc_rising_edge = 0;
	reg mdc_falling_edge = 0;
	always @(posedge clk_125mhz) begin
		mdc_rising_edge <= 0;
		mdc_falling_edge <= 0;
		
		//Bump count, add an edge when it wraps
		mdc_count <= mdc_count + 6'd1;
		if(mdc_count == 6'd29) begin
			mdc_count <= 0;
			
			if(mdc)
				mdc_falling_edge <= 1;
			else
				mdc_rising_edge <= 1;
		end
		
		//Turn edges into a squarewave
		if(mdc_falling_edge)
			mdc <= 0;
		if(mdc_rising_edge)
			mdc <= 1;			
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Management I/O
	
	//Pull in constant tables
	`include "EthernetMDIOTransceiver_opcodes_constants.v";
	
	//State values for management interface
	localparam MGMT_STATE_IDLE		= 0;
	localparam MGMT_STATE_PRE		= 1;
	localparam MGMT_STATE_ST		= 2;
	localparam MGMT_STATE_OP		= 3;
	localparam MGMT_STATE_PHYAD		= 4;
	localparam MGMT_STATE_REGAD		= 5;
	localparam MGMT_STATE_TA		= 6;
	localparam MGMT_STATE_DATA		= 7;
	localparam MGMT_STATE_IFG		= 8;
	reg[3:0] mgmt_state = MGMT_STATE_IDLE;
	
	reg[5:0] mgmt_count = 0;					//internal counter, meaning depends on state
	
	reg[15:0] phy_wr_data_buf = 0;
	
	reg mgmt_op = MGMT_OP_RD;
	
	reg mgmt_busy = 0;
	assign mgmt_busy_fwd = mgmt_busy | phy_reg_wr | phy_reg_rd;
	
	//Internal read data buffer
	reg[15:0] phy_rd_data_raw = 0;
	
	always @(posedge clk_125mhz) begin
		case(mgmt_state)
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Idle
			MGMT_STATE_IDLE: begin
				
				//Tri-state I/Os during this time
				mdio_tx_en <= 0;
				
				//Wait for commands
				if(phy_reg_rd) begin
					mgmt_busy <= 1;
					mgmt_state <= MGMT_STATE_PRE;
					mgmt_op <= MGMT_OP_RD;
					mgmt_count <= 0;
				end
				else if(phy_reg_wr) begin
					mgmt_busy <= 1;
					mgmt_state <= MGMT_STATE_PRE;
					mgmt_op <= MGMT_OP_WR;
					mgmt_count <= 0;
					phy_wr_data_buf <= phy_wr_data;
				end
			end	//end MGMT_STATE_IDLE
			
			//////////////////////////////////////////////////////////////////////////////////////////
			// Generic PHY register operations
			
			//22.2.4.5.2 - preamble (32 contiguous 1 bits)
			MGMT_STATE_PRE: begin
				if(mdc_falling_edge) begin
					mdio_tx_en <= 1;
					mdio_tx_data <= 1;
					mgmt_count <= mgmt_count + 6'h1;
					if(mgmt_count == 'h32) begin
						mgmt_state <= MGMT_STATE_ST;
						mgmt_count <= 0;
					end
				end
			end	//end MGMT_STATE_PRE
			
			//22.2.4.5.3 - start of frame (01)
			MGMT_STATE_ST: begin
				if(mdc_falling_edge) begin
					mdio_tx_en <= 1;
					mdio_tx_data <= mgmt_count[0];
					if(mgmt_count == 0)
						mgmt_count <= 1;
					else begin
						mgmt_state <= MGMT_STATE_OP;
						mgmt_count <= 0;
					end
				end
			end	//end MGMT_STATE_ST
			
			//22.2.4.5.4 - opcode (read = 10, write = 01)
			MGMT_STATE_OP: begin
				if(mdc_falling_edge) begin
					mdio_tx_en <= 1;
					if(mgmt_op == MGMT_OP_RD)
						mdio_tx_data <= ~mgmt_count[0];
					else
						mdio_tx_data <= mgmt_count[0];
					
					if(mgmt_count == 0)
						mgmt_count <= 1;
					else begin
						mgmt_state <= MGMT_STATE_PHYAD;
						mgmt_count <= 0;
					end
				end
			end	//end MGMT_STATE_OP
			
			//22.2.4.5.5 - PHY address
			MGMT_STATE_PHYAD: begin
				if(mdc_falling_edge) begin
					mdio_tx_en <= 1;
					mgmt_count <= mgmt_count + 6'h1;
					
					case(mgmt_count)
						0: mdio_tx_data <= PHY_MD_ADDR[4];
						1: mdio_tx_data <= PHY_MD_ADDR[3];
						2: mdio_tx_data <= PHY_MD_ADDR[2];
						3: mdio_tx_data <= PHY_MD_ADDR[1];
						default: begin
							mdio_tx_data <= PHY_MD_ADDR[0];
							mgmt_state <= MGMT_STATE_REGAD;
							mgmt_count <= 0;
						end
					endcase
				end
				
			end	//end MGMT_STATE_PHYAD
			
			//22.2.4.5.6 - register address
			MGMT_STATE_REGAD: begin
				if(mdc_falling_edge) begin
					mdio_tx_en <= 1;
					mgmt_count <= mgmt_count + 6'h1;
					
					case(mgmt_count)
						0: mdio_tx_data <= phy_reg_addr[4];
						1: mdio_tx_data <= phy_reg_addr[3];
						2: mdio_tx_data <= phy_reg_addr[2];
						3: mdio_tx_data <= phy_reg_addr[1];
						default: begin
							mdio_tx_data <= phy_reg_addr[0];
							mgmt_state <= MGMT_STATE_TA;
							mgmt_count <= 0;
						end
					endcase
				end
			end	//end MGMT_STATE_REGAD
			
			//22.2.4.5.7 - turnaround period
			MGMT_STATE_TA: begin
				if(mdc_falling_edge) begin
					/*
						For a read transaction, both the STA and the PHY shall remain in a high-impedance
						state for the first bit time of the turnaround. The PHY shall drive a zero bit
						during the second bit time of the turnaround of a read transaction.
					 */
					if(mgmt_op == MGMT_OP_RD) begin
						mdio_tx_en <= 0;					
					end
					
					/*
						During a write transaction, the STA shall drive a one bit for the first bit time of
						the turnaround and a zero bit for the second bit time of the turnaround.
					 */
					else begin
						mdio_tx_en <= 1;
						mdio_tx_data <= ~mgmt_count[0];
					end
					
					//Go on to the next state
					if(mgmt_count == 0)
						mgmt_count <= 1;
					else begin
						mgmt_state <= MGMT_STATE_DATA;
						mgmt_count <= 0;
					end
					
				end
			end	//end MGMT_STATE_TA
			
			//22.2.4.5.8 - data
			MGMT_STATE_DATA: begin
				
				//Reads
				if(mgmt_op == MGMT_OP_RD) begin
					//Stay tri-stated in read mode
					mdio_tx_en <= 0;
					
					//Read on rising edge of clock as per 22.3.4
					//Bit 15 goes first
					//Read one extra bit because we start half a cycle early
					if(mdc_rising_edge) begin
						mgmt_count <= mgmt_count + 6'h1;
						phy_rd_data_raw <= {phy_rd_data_raw[14:0], mdio_rx_data};
						
						//Just read the last bit, we're done
						if(mgmt_count == 16) begin
							phy_rd_data <= {phy_rd_data_raw[14:0], mdio_rx_data};
							mgmt_state <= MGMT_STATE_IFG;
							mgmt_count <= 0;
						end
						
					end
				end
				
				//Writes
				else begin
					//Write on falling edge of clock as per 22.3.4
					if(mdc_falling_edge) begin
						mdio_tx_en <= 1;
						mdio_tx_data <= phy_wr_data_buf[15];
						mgmt_count <= mgmt_count + 6'h1;
						phy_wr_data_buf <= {phy_wr_data_buf[14:0], 1'b0};
						
						//Just wrote the last bit, we're done
						if(mgmt_count == 15) begin
							mgmt_state <= MGMT_STATE_IFG;
							mgmt_count <= 0;
						end
					end
				end
				
			end	//end MGMT_STATE_DATA
			
			//Add 16-cycle interframe gap in case the PHY doesn't like commands back to back
			MGMT_STATE_IFG: begin
				mgmt_count <= mgmt_count + 6'h1;
				if(mgmt_count == 'h0f) begin
					mgmt_state <= MGMT_STATE_IDLE;
					mgmt_busy <= 0;
				end
			end	//end MGMT_STATE_IFG
			
		endcase
	end
	
endmodule
	
