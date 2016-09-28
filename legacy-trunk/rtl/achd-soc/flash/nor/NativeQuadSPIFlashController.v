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
	@brief Native (not NOC interface) quad SPI controller.
	
	The SPI clock is hard-coded to half the NoC frequency in the current system. Example bandwidth figures:
		clk_noc (MHz)	bw (MT/s)	bw (Mb/s)	bw (MB/s)
		40				20			80			10
		
	Interface signals (other than flags) must be held constant until the relevant operation has completed.
	
	Includes some auto-discovery code for SFDP. Tested against the following flash memories:
	* Macronix MX25U6435F (hardware)
	* Micron N25Q256A (hardware)
	* Spansion S25FL008K (simulation)
	* Winbond W25Q80BV (hardware)
	* Winbond W25Q16DW (hardware)
	
	Burst length is in 32-bit words.
	
	Read addresses must be 32-bit aligned.
	
	Assumes the following geometry:
		4KB erase blocks
		256 byte write sectors
		
	Writes:
		assert write_en to start
		Controller asserts write_rden when needed and expects 32 bits on write_data the next cycle
		write_data cannot change until next write_rden cycle
 */
module NativeQuadSPIFlashController(
	clk,
	spi_cs_n, spi_sck, spi_data,
	busy, done, addr, burst_size,
	read_en, read_data_valid, read_data,
	erase_en,
	write_en, write_rden, write_data,
	max_address,
	reset
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	
	//Module clock
	input wire clk;
	
	//Quad SPI interface
	output reg spi_cs_n = 1;
	output wire spi_sck;
	inout wire[3:0] spi_data;
	
	//Controller interface
	input wire reset;
	output reg busy = 1;
	output reg done = 0;
	input wire[31:0] addr;
	input wire[9:0] burst_size;
	input wire read_en;
	output reg read_data_valid = 0;
	output reg[31:0] read_data = 0;
	input wire erase_en;
	input wire write_en;
	output reg write_rden = 0;
	input wire[31:0] write_data;
	
	//Memory size is this + 1
	output reg[31:0] max_address					= 0;

	//Set these high to dump lots of verbose info during development and testing
	parameter SIM_DEBUG_INIT	= 0;
	parameter SIM_DEBUG_READS	= 0;
	parameter SIM_DEBUG_ERASE	= 0;
	parameter SIM_DEBUG_WRITES	= 0;
	
	//Set high if quad mode is bonded out
	parameter ENABLE_QUAD_MODE	= 1;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The transceiver
	
	wire spi_busy;
	wire spi_done;
	reg spi_tx_en_single = 0;
	reg spi_tx_en_quad = 0;
	reg[7:0] spi_tx_data;
	reg spi_rx_en_single = 0;
	reg spi_rx_en_quad = 0;
	wire[7:0] spi_rx_data;
	reg dummy_en_single = 0;
	
	QuadSPITransceiver txvr(
		.clk(clk),
		.busy(spi_busy),
		.done(spi_done),
		.spi_sck(spi_sck),
		.spi_data(spi_data),
		.dummy_en_single(dummy_en_single),
		.tx_en_single(spi_tx_en_single),
		.tx_en_quad(spi_tx_en_quad),
		.tx_data(spi_tx_data),
		.rx_en_single(spi_rx_en_single),
		.rx_en_quad(spi_rx_en_quad),
		.rx_data(spi_rx_data)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Flash configuration table
	
	/*
		This table stores the configuration parameters for each known flash memory device.
		
		
		63:56			Opcode to read NV config reg
		55				1 if flash has nonvolatile config register
		54:50			log2(flash size in bytes)
		49:47			1-4-4 quad read mode bit count
		46:42			1-4-4 quad read wait state count
		41				1 if addresses are 4 words, 0 if 3 words
		40				1 if 1-4-4 quad capable		
		39:32			1-4-4 read opcode
		31:24			4KB erase opcode
		23:16			JEDEC vendor ID
		15:0			JEDEC device ID
	 */
	
	reg[63:0] flash_config_table[255:0];
	
	integer i;
	initial begin
		for(i=0; i<256; i = i+1)
			flash_config_table[i] <= 0;
		
		flash_config_table[0] <=
		{
			8'h00, 1'b0,		//No NVCR
			5'd23,				//Flash size (8 Mb)
			3'h2, 5'h05,		//Mode bits and wait states
			1'b0,				//3-byte addressing
			1'b1, 8'heb,		//1-4-4- quad read capable
			8'h20,				//4KB erase opcode
			8'hef, 16'h4014		//Winbond W25Q80BV
		};
		
		flash_config_table[1] <= {
			8'hb5, 1'b1,		//Nonvolatile config register
			5'd28,				//Flash size (256 Mb)
			3'h2, 5'h08,		//Mode bits and wait states
			1'b0,				//3-byte addressing
			1'b0, 8'heb,		//1-4-4 quad read capable with this opcode
			8'h20,				//4KB erase opcode
			8'h20, 16'hba19		//Micron N25Q256A in 3-byte mode
								//(Current controller doesn't support the top half of flash)
		};
		
		flash_config_table[2] <=
		{
			8'h00, 1'b0,		//No NVCR
			5'd24,				//Flash size (16 Mb)
			3'h2, 5'h05,		//Mode bits and wait states
			1'b0,				//3-byte addressing
			1'b1, 8'heb,		//1-4-4- quad read capable
			8'h20,				//4KB erase opcode
			8'hef, 16'h6015		//Winbond W25Q16DW
		};
		
		flash_config_table[3] <=
		{
			8'h00, 1'b0,		//No NVCR
			5'd26,				//Flash size (64 Mb)
			3'h2, 5'h04,		//Mode bits and wait states
			1'b0,				//3-byte addressing
			//1'b1, 8'heb,		//1-4-4- quad read capable
			//Can't enable this until we add support for setting the QE bit (gonna need more tweaking)
			1'b0, 8'h00,		//debug: no quad read
			8'h20,				//4KB erase opcode
			8'hc2, 16'h2537		//Macronix MX25U6435F
		};
		
	end
	
	reg flash_config_rd = 0;
	reg[7:0] flash_config_rd_addr = 0;
	reg[63:0] flash_config_table_out = 0;
	always @(posedge clk) begin
		if(flash_config_rd)
			flash_config_table_out <= flash_config_table[flash_config_rd_addr];
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Opcode storage	

	//Read JEDEC ID
	localparam opcode_read_jedec_id	= 8'h9f;

	//Constant opcode for reading flash descriptor table (see JEDEC JESD216 page 10 section 4.1)
	localparam opcode_sfdp_read		= 8'h5a;
	
	//Constant opcode for x1 fast read
	localparam opcode_fast_read		= 8'h0b;
	
	//Constant opcode for enabling writes
	localparam opcode_we			= 8'h06;
	
	//Constant opcode for writing to status register
	localparam opcode_status_wr		= 8'h01;
	
	//Constant opcode for reading first status register
	localparam opcode_status_rd_1	= 8'h05;
	
	//Constant opcode for writing to a single page
	localparam opcode_page_program	= 8'h02;

	//Flags indicating support of optional instructions
	wire has_144_read						= flash_config_table_out[40];
	
	//Configuration for optional instructions
	wire[2:0] mode_144_count				= flash_config_table_out[49:47];
	wire[4:0] wait_144_count				= flash_config_table_out[46:42];
	
	//Address length
	wire four_word_address					= flash_config_table_out[41];
	
	//Indexes for configurable opcodes
	wire[7:0] opcode_4kb_erase				= flash_config_table_out[31:24];
	wire[7:0] opcode_144_read				= flash_config_table_out[39:32];
	
	reg[23:0] jedec_id = 0;
	
	wire[4:0] log2_flash_size				= flash_config_table_out[54:50];
	
	//Nonvolatile config reg
	wire[7:0] opcode_read_nvconfig			= flash_config_table_out[63:56];
	wire has_nvconfig						= flash_config_table_out[55];
		
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Controller logic

	`include "NativeQuadSPIFlashController_states_constants.v"
	
	reg[4:0] state		= STATE_BOOT_0;
	reg[4:0] state_ret 	= STATE_BOOT_0;
	
	reg[15:0] count = 0;
	
	always @(posedge clk) begin
		
		spi_tx_en_single <= 0;
		spi_tx_en_quad <= 0;
		spi_rx_en_single <= 0;
		spi_rx_en_quad <= 0;
		dummy_en_single <= 0;
		
		done <= 0;
		read_data_valid <= 0;
		
		write_rden <= 0;
		
		flash_config_rd <= 0;
		
		case(state)

			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// BOOT logic
			// Read JEDEC ID and figure out what the flash device is
			
			//Boot delay
			STATE_BOOT_0: begin
				count <= count + 16'h1;
				if(count == 8192) begin
					state <= STATE_BOOT_1;
					count <= 0;
				end
			end	//end STATE_BOOT_0
			
			//Send 0xFF FF FF FF reset to leave continous read mode if we booted the FPGA off this flash
			STATE_BOOT_1: begin
				case(count)
					
					0: begin
						spi_cs_n <= 0;
						count <= count + 16'h1;
					end
					
					3: begin
						spi_tx_en_single <= 1;
						spi_tx_data <= 8'hff;
						count <= count + 16'h1;
					end
					
					4: begin
						if(spi_done) begin
							spi_tx_en_single <= 1;
							spi_tx_data <= 8'hff;
							count <= count + 16'h1;
						end
					end
					
					5: begin
						if(spi_done) begin
							spi_tx_en_single <= 1;
							spi_tx_data <= 8'hff;
							count <= count + 16'h1;
						end
					end
					
					6: begin
						if(spi_done) begin
							spi_tx_en_single <= 1;
							spi_tx_data <= 8'hff;
							count <= count + 16'h1;
						end
					end
					
					7: begin
						if(spi_done) begin
							spi_cs_n <= 1;
							count <= count + 16'h1;
						end
					end
					
					10: begin
						spi_cs_n <= 0;
						state <= STATE_BOOT_2;
					end
					
					//just keep counting
					default: begin
						count <= count + 16'h1;
					end
					
				endcase
			end
			
			//Opcode
			STATE_BOOT_2: begin
				spi_tx_en_single <= 1;
				spi_tx_data <= opcode_read_jedec_id;
				count <= 0;
				state <= STATE_BOOT_3;
			end	//end STATE_BOOT_2
			
			//Three address and one dummy byte (all zero)
			STATE_BOOT_3: begin
				if(spi_done) begin
					jedec_id <= {jedec_id[15:0], spi_rx_data};
				
					if(count == 3) begin		//state 0 is tx, 1...3 are rx
						count <= 0;
						flash_config_rd_addr <= 0;
						flash_config_rd <= 1;
						state <= STATE_BOOT_4;
						
						//synthesis translate_off
						$display("[NativeQuadSPIFlashController] JEDEC ID = %x", {jedec_id[15:0], spi_rx_data});
						//synthesis translate_on
						
						spi_cs_n <= 1;
						
					end

					else begin
						count <= count + 16'h1;
						spi_rx_en_single <= 1;
					end
				end
			end	//end STATE_BOOT_3
			
			//Search for the flash data
			STATE_BOOT_4: begin

				if(flash_config_rd) begin
					//wait for read
				end
				
				else begin

					//Hit?
					if(flash_config_table_out[23:0] == jedec_id) begin
					
						//synthesis translate_off
						if(SIM_DEBUG_INIT)
							$display("[NativeQuadSPIFlashController] Found JEDEC ID at %d", flash_config_rd_addr);
						//synthesis translate_on
						
						//Save flash size
						max_address = ({32'h1} << log2_flash_size) - 1;
						
						//Enable quad-read mode if necessary
						if(has_144_read) begin
							state <= STATE_WE_0;
							state_ret <= STATE_BOOT_5;
						end
						else begin
							
							//Debug
							if(has_nvconfig) begin
								state <= STATE_DEBUG_0;
							end
							else begin
								state <= STATE_IDLE;
								busy <= 0;
							end
						end
						
					end
					
					//Not yet
					else begin
					
						//End of list?
						if(flash_config_rd_addr == 255) begin
							
							//synthesis translate_off
							if(SIM_DEBUG_INIT)
								$display("[NativeQuadSPIFlashController] Failed to find flash ID in table");
							//synthesis translate_on
							state <= STATE_BOOT_HANG;
							
						end
					
						else begin
							flash_config_rd <= 1;
							flash_config_rd_addr <= flash_config_rd_addr + 8'h1;
						end
					end
				end
			
			end	//end STATE_BOOT_4
			
			/*
				How to handle varying device configurations?
				
				W25Q80BV		Single 2-byte status/config register with some nv bits
				N25Q256			1-byte status register and 2-byte config register
			 */
			
			//Status register is now writable... reselect the device
			STATE_BOOT_5: begin
				//synthesis translate_off
				if(SIM_DEBUG_INIT)
					$display("[NativeQuadSPIFlashController] Setting quad-enable bit");
				//synthesis translate_on
			
				spi_cs_n <= 0;
				state <= STATE_BOOT_6;
			end	//end STATE_BOOT_5
			
			//Start the write
			STATE_BOOT_6: begin
				spi_tx_en_single <= 1;
				spi_tx_data <= opcode_status_wr;
				state <= STATE_BOOT_7;
				count <= 0;
			end	//end STATE_BOOT_6
			
			//Send the low half of the status register first, then the high half
			
			STATE_BOOT_7: begin
				if(spi_done) begin
					if(count == 0) begin
					
						//	7 		SRP0	= 0
						//	6 		SEC		= 0
						//	5		TB		= 0
						//	4:2		BP0		= 0
						//	1		WEL		= 0
						//	0		BUSY	= x			
						spi_tx_en_single <= 1;
						spi_tx_data <= 8'h00;
					
						count <= 1;
					end
					else begin
					
						//	15		SUS		= x
						//	14		CMP		= 0
						//	13:11	LB[3:1]	= 0
						//	10		RSVD	= 0
						//	9		QE		= 1
						//	8		SRP1	= 0
						 
						spi_tx_en_single <= 1;
						spi_tx_data <= 8'h02;
					
						state <= STATE_BOOT_8;
					end
				end
			end	//end STATE_BOOT_7
			
			//Done with the write, need to sit back and wait for the write to complete
			STATE_BOOT_8: begin
				if(spi_done) begin
					spi_cs_n <= 1;
					state_ret <= STATE_IDLE;
					state <= STATE_BUSY_WAIT_0;
					count <= 0;
				end
			end	//end STATE_BOOT_8
			
			//stick here on boot failure
			STATE_BOOT_HANG: begin
				//state	<= STATE_IDLE;
			end	//STATE_BOOT_HANG
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Poll the status register until the busy flag is cleared
			
			STATE_BUSY_WAIT_0: begin
				count <= count + 16'h1;
				if(count == 7) begin			//need to wait a few cycles before re-selecting
					spi_cs_n <= 0;
					state <= STATE_BUSY_WAIT_1;
				end
			end //end STATE_BUSY_WAIT_0
			
			STATE_BUSY_WAIT_1: begin
				spi_tx_en_single <= 1;
				spi_tx_data <= opcode_status_rd_1;
				state <= STATE_BUSY_WAIT_2;
			end	//end STATE_BUSY_WAIT_1
			
			STATE_BUSY_WAIT_2: begin
				if(spi_done) begin
					spi_rx_en_single <= 1;
					state <= STATE_BUSY_WAIT_3;
				end
			end	//end STATE_BUSY_WAIT_2
			
			STATE_BUSY_WAIT_3: begin
				if(spi_done) begin
					
					//Still busy?
					if(spi_rx_data[0]) begin
						spi_rx_en_single <= 1;
					end
					
					//Nope, done
					else begin
						spi_cs_n <= 1;
						state <= state_ret;
					end
					
					
				end
			end	//end STATE_BUSY_WAIT_3
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Write enable
			
			//Enter write enable mode (CS_N must have been deasserted already)
			STATE_WE_0: begin
				state <= STATE_WE_1;
				count <= 0;
			end	//end STATE_WE_0
			
			STATE_WE_1: begin
				count <= count + 16'h1;
				spi_cs_n <= 0;
				if(count == 7) begin
					spi_tx_en_single <= 1;
					spi_tx_data <= opcode_we;
				end
				
				if(spi_done) begin
					count <= 0;
					state <= STATE_WE_2;
				end
				
			end	//end STATE_WE_1;
			
			STATE_WE_2: begin
			
				count <= count + 16'h1;
			
				if(count == 0)
					spi_cs_n <= 1;
				
				if(count == 7)
					spi_cs_n <= 0;
				
				if(count == 15) begin
					count <= 0;
					state <= state_ret;
				end
				
			end	//end STATE_WE_2
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// IDLE state - wait for commands
			
			STATE_IDLE: begin
				busy <= 0;
				spi_cs_n <= 1;
			
				//READ
				if(read_en) begin
					busy <= 1;
				
					//synthesis translate_off
					if(SIM_DEBUG_READS) begin
						$display("[NativeQuadSPIFlashController] Read requested (addr %x, blen %d)",
							addr, burst_size);
					end
					//synthesis translate_on
					
					//Select the chip and request a the appropriate read opcode
					spi_cs_n <= 0;
					if(has_144_read)
						spi_tx_data <= opcode_144_read;
					else
						spi_tx_data <= opcode_fast_read;
					state	<= STATE_READ_CS;
					
					count	<= 0;
					
				end
				
				//ERASE
				//For now, only support erasing single 4KB blocks. In the future, we want to support doing
				//32/64 and full chip blocks since that can be considerably faster.
				else if(erase_en) begin
					busy <= 1;
					
					//synthesis translate_off
					if(SIM_DEBUG_ERASE) begin
						$display("[NativeQuadSPIFlashController] Erase requested (addr %x)", addr);
					end
					//synthesis translate_on
					
					//Start the erase
					spi_cs_n <= 0;
					state <= STATE_WE_0;
					state_ret <= STATE_ERASE_0;
					
				end
				
				//WRITE
				else if(write_en) begin
				
					busy <= 1;
					
					//synthesis translate_off
					if(SIM_DEBUG_WRITES) begin
						$display("[NativeQuadSPIFlashController] Write requested (addr %x, blen %d)",
							addr, burst_size);
					end
					//synthesis translate_on
					
					//Start the write
					spi_cs_n <= 0;
					state <= STATE_WE_0;
					state_ret <= STATE_WRITE_0;
				
				end
			
			end	//end STATE_IDLE
			
			STATE_READ_CS: begin
				count	<= count + 16'h1;
				
				if(count == 3) begin
					
					//Skip the first address byte if we're in 3-byte address mode
					count <= 0;
					if(!four_word_address)
						count <= 1;
				
					spi_tx_en_single <= 1;
					state <= STATE_READ_0;
				end
			end
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Shared address-bit-generation state
			
			//Send address bits
			STATE_ADDRESS: begin
				if(spi_done) begin			
					count <= count + 16'h1;
					
					case(count)
					
						//Address bits, shared by all modes
						0: begin
							spi_tx_en_single <= 1;
							spi_tx_data <= addr[31:24];
						end
						
						1: begin
							spi_tx_en_single <= 1;
							spi_tx_data <= addr[23:16];
						end
						
						2: begin
							spi_tx_en_single <= 1;
							spi_tx_data <= addr[15:8];
						end
						
						3: begin
							spi_tx_en_single <= 1;
							spi_tx_data <= addr[7:0];
							
							count <= 0;
							state <= state_ret;
						end						
					endcase
					
				end
			end	//end STATE_ADDRESS
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Write path
			
			STATE_WRITE_0: begin
				spi_tx_en_single <= 1;
				spi_tx_data <= opcode_page_program;
				state_ret <= STATE_WRITE_1;
				state <= STATE_ADDRESS;
				
				//Ask for the data now so it'll be ready by the next cycle
				write_rden <= 1;
			
				//Skip the first address byte if we're in 3-byte address mode
				count <= 0;
				if(!four_word_address)
					count <= 1;

			end	//end STATE_WRITE_0

			STATE_WRITE_1: begin
				if(spi_done) begin
					
					//Done?
					if((count >> 2) == burst_size) begin
						spi_cs_n <= 1;
						count <= 0;
						state_ret <= STATE_OP_DONE;
						state <= STATE_BUSY_WAIT_0;
					end
					
					//Send this word
					else begin
						spi_tx_en_single <= 1;
						case(count[1:0])
							0: spi_tx_data <= write_data[31:24];
							1: spi_tx_data <= write_data[23:16];
							2: spi_tx_data <= write_data[15:8];
							
							//Last byte in the word? See what comes next
							3: begin
								spi_tx_data <= write_data[7:0];
								
								//Not done? Ask for more data
								if(count[11:2] != (burst_size - 1))
									write_rden <= 1;
								
							end
						endcase
					
						count <= count + 16'h1;
					end
					
				end				
			end	//end STATE_WRITE_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Erase path
			
			//Send write opcode
			STATE_ERASE_0: begin
			
				spi_tx_data <= opcode_4kb_erase;
				spi_tx_en_single <= 1;
				state <= STATE_ADDRESS;
				state_ret <= STATE_ERASE_1;
				
				//Skip the first address byte if we're in 3-byte address mode
				count <= 0;
				if(!four_word_address)
					count <= 1;
				
			end	//end STATE_ERASE_0;
					
			STATE_ERASE_1: begin
				if(spi_done) begin
				
					//synthesis translate_off
					if(SIM_DEBUG_ERASE)
						$display("[NativeQuadSPIFlashController] Erase dispatched");
					//synthesis translate_on
				
					count <= 0;
					spi_cs_n <= 1;
					state_ret <= STATE_OP_DONE;
					state <= STATE_BUSY_WAIT_0;
				end
			end	//end STATE_ERASE_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Indicates an operation is done
			
			STATE_OP_DONE: begin
				
				done <= 1;
				busy <= 0;
				state <= STATE_IDLE;
				
			end	//end STATE_ERASE_2
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Read path
			
			//Send address bits
			//TODO: STATE_ADDRESS should do this
			STATE_READ_0: begin
				if(spi_done) begin
					
					count <= count + 16'h1;
					
					case(count)
					
						//Address bits, shared by all modes
						0: begin
							spi_tx_en_single <= !has_144_read;
							spi_tx_en_quad <= has_144_read;
							spi_tx_data <= addr[31:24];
						end
						
						1: begin
							spi_tx_en_single <= !has_144_read;
							spi_tx_en_quad <= has_144_read;
							spi_tx_data <= addr[23:16];
						end
						
						2: begin
							spi_tx_en_single <= !has_144_read;
							spi_tx_en_quad <= has_144_read;
							spi_tx_data <= addr[15:8];
						end
						
						3: begin
							spi_tx_en_single <= !has_144_read;
							spi_tx_en_quad <= has_144_read;
							spi_tx_data <= addr[7:0];
							
							count <= 0;
							
							if(has_144_read)
								state <= STATE_READ_1;
							else
								state <= STATE_READ_2;
						end						
					endcase
					
				end
			end	//end STATE_READ_0
			
			//Send mode bits (x4 only)
			STATE_READ_1: begin
				if(spi_done) begin
					
					spi_tx_en_quad <= 1;
					spi_tx_data <= 8'hff;
					count <= count + 16'h1;
					
					if( (count + 1) == mode_144_count[2:1]) begin
						state <= STATE_READ_2;
						count <= 0;
					end
				end
			end	//end STATE_READ_1
			
			//Send dummy bits
			STATE_READ_2: begin
				if(spi_done) begin
				
					//In quad read mode, we need to count
					if(has_144_read) begin
						dummy_en_single <= 1;
						count <= count + 16'h1;
						
						if( count == wait_144_count) begin
							count <= 0;
							state <= STATE_READ_4;
						end
					end

					//In single read mode, send the dummy word and continue
					else begin
						spi_rx_en_single <= 1;
						state <= STATE_READ_3;
					end

				end
			end
			
			//Issue the first read
			STATE_READ_3: begin
				if(spi_done) begin
					spi_rx_en_single <= !has_144_read;
					spi_rx_en_quad <= has_144_read;
					state <= STATE_READ_4;
					count <= 0;
				end
			end	//end STATE_READ_3
			
			//Read the data
			STATE_READ_4: begin
				if(spi_done) begin
					
					//Read the next byte of data
					spi_rx_en_single <= !has_144_read;
					spi_rx_en_quad <= has_144_read;
					count <= count + 16'h1;
					
					//$display("%x", spi_rx_data);
					
					//Store output data
					read_data <= {read_data[23:0], spi_rx_data};
					if(count[1:0] == 3) begin
					
						//synthesis translate_off
						if(SIM_DEBUG_READS)
							$display("[NativeQuadSPIFlashController] Got data %x", {read_data[23:0], spi_rx_data});
						//synthesis translate_on
					
						//Stop if we're at the end
						if(count[11:2] == (burst_size - 1)) begin
							done <= 1;
							busy <= 0;
							spi_rx_en_single <= 0;
							spi_rx_en_quad <= 0;
							spi_cs_n <= 1;
							state <= STATE_IDLE;
						end
					
						read_data_valid <= 1;
					end
					
				end
			end	//end STATE_READ_4

			//Debug stuff
			STATE_DEBUG_0: begin
				spi_cs_n <= 0;
				spi_tx_en_single <= 1;
				spi_tx_data <= opcode_read_nvconfig;
				count <= 0;
				state <= STATE_DEBUG_1;
			end
			STATE_DEBUG_1: begin
				if(spi_done) begin
					count <= count + 16'h1;
					if(count == 2) begin
						state <= STATE_IDLE;
						busy <= 0;
					end
					else
						spi_rx_en_single <= 1;
				end
			end

		endcase
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		//Reset logic
		
		if(reset) begin
			state <= STATE_BOOT_0;
			state_ret <= STATE_BOOT_0;
			count <= 0;
			spi_cs_n <= 1;
			busy <= 1;
		end
		
	end

endmodule
