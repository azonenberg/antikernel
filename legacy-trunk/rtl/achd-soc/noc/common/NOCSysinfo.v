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
	@brief System information server
	
	@module
	@opcodefile		NOCSysinfo.constants
	
	@rpcfn			SYSINFO_CHIP_SERIAL
	@brief			Gets the FPGA die serial number as a 64-bit integer. Serials <64 bits are zero-padded at right.
	
	@rpcfn_ok		SYSINFO_CHIP_SERIAL
	@brief			FPGA serial number retrieved successfully
	@param			serial			{d2[31:0],d1[31:0]}:hex			The serial number
		
	@rpcfn			SYSINFO_QUERY_FREQ
	@brief			Queries the current clock period
	
	@rpcfn_ok		SYSINFO_QUERY_FREQ
	@brief			Current clock period
	@param			sysclk_period	d1[31:0]:dec					System clock period, in picoseconds
	
	@rpcfn			SYSINFO_GET_CYCFREQ	
	@brief			Gets the cycle count required for a given clock frequency
	@param			freq			d1[31:0]:dec					Desired frequency, in Hz
	
	@rpcfn_ok		SYSINFO_GET_CYCFREQ	
	@brief			Cycle count obtained
	@param			cycles			d1[31:0]:dec					Cycle count
	
	@rpcfn			SYSINFO_GET_TEMP
	@brief			Gets FPGA die temperature, if sensor is present
	
	@rpcfn_ok		SYSINFO_GET_TEMP
	@brief			Die temperature retrieved
	@param			temp			d1[15:0]:fx8					Die temperature, in C
	
	@rpcfn_fail		SYSINFO_GET_TEMP
	@brief			Die temperature sensor not present
	
	@rpcfn			SYSINFO_GET_VCORE
	@brief			Gets FPGA core voltage, if sensor is present
	
	@rpcfn_ok		SYSINFO_GET_VCORE
	@brief			Core voltage retrieved
	@param			volt			d1[15:0]:fx8					Core voltage
	@param			volt_hi			d2[31:16]:fx8					Minimum legal core voltage
	@param			volt_lo			d2[15:0]:fx8					Maximum legal core voltage
	
	@rpcfn_fail		SYSINFO_GET_VCORE
	@brief			Core voltage sensor not present
	
	@rpcfn			SYSINFO_GET_VRAM
	@brief			Gets FPGA block RAM voltage, if sensor is present (may be same rail as VCORE on some FPGAs)
	
	@rpcfn_ok		SYSINFO_GET_VRAM
	@brief			Block RAM voltage retrieved
	@param			volt			d1[15:0]:fx8					Block RAM voltage
	@param			volt_hi			d2[31:16]:fx8					Minimum legal block RAM voltage
	@param			volt_lo			d2[15:0]:fx8					Maximum legal block RAM voltage
	
	@rpcfn_fail		SYSINFO_GET_VRAM
	@brief			Block RAM voltage sensor not present
	
	@rpcfn			SYSINFO_GET_VAUX
	@brief			Gets FPGA auxiliary voltage, if sensor is present
	
	@rpcfn_ok		SYSINFO_GET_VAUX
	@brief			Auxiliary voltage retrieved
	@param			volt			d1[15:0]:fx8					auxiliary voltage
	@param			volt_hi			d2[31:16]:fx8					Minimum legal auxiliary voltage
	@param			volt_lo			d2[15:0]:fx8					Maximum legal auxiliary voltage
	
	@rpcfn_fail		SYSINFO_GET_VAUX
	@brief			Auxiliary voltage sensor not present
 */
module NOCSysinfo(
	clk,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// IO declarations
	input wire clk;

	output wire rpc_tx_en;
	output wire[31:0] rpc_tx_data;
	input wire[1:0] rpc_tx_ack;
	input wire rpc_rx_en;
	input wire[31:0] rpc_rx_data;
	output wire[1:0] rpc_rx_ack;
	
	parameter sysclk_period = 0;	//clock period, measured in ps
	parameter sysclk_hz = 0;		//clock frequency, measured in Hz
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transceiver
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	
	parameter NOC_ADDR = 16'h0000;
	
	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= RPC_TYPE_RETURN_RETRY;	//default until boot is done
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
		.rpc_fab_inbox_full()
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DNA port (for serial number)
	
	//DNA port max switching frequency is 2 MHz on Spartan-6 (can be super fast on 7 series)
	//Fclk = Fin / (dna_clk_count period*4)
	//Fclk max 2 MHz when clk_noc = 200 MHz so 1 MHz @ 100 MHz
	//If timer is 32 cycles then we get 200/(32*4) = 200/128 = 1.56 MHz
	reg[4:0]	dna_clk_count	= 0;
	reg			dna_nextphase	= 0;
	always @(posedge clk) begin
		dna_clk_count 	<= dna_clk_count + 5'h1;
		dna_nextphase	<= dna_clk_count[4];
	end

	reg			dna_clk			= 0;
	reg[1:0]	dna_phase		= 0;
	
	//The actual DNA access primitive
	wire dna_out;
	reg dna_shift = 0;
	reg dna_read = 0;
	DNA_PORT dna_port(.DOUT(dna_out), .DIN(1'b0), .READ(dna_read), .SHIFT(dna_shift), .CLK(dna_clk));

	//Data buffer (57 bits padded with zeros on to 64)
	reg[63:0] dna_data = 0;
	
	//Read the DNA data
	localparam DNA_READ_STATE_BOOT_0 = 0;
	localparam DNA_READ_STATE_BOOT_1 = 1;
	localparam DNA_READ_STATE_READ = 2;
	localparam DNA_READ_STATE_DONE = 3;
	reg[1:0] dna_read_state = DNA_READ_STATE_BOOT_0;
	
	reg[6:0] dna_read_count = 0;
	reg boot_done			= 0;
	
	always@(posedge clk) begin
	
		//Done? Hold everything low
		if(dna_read_state == DNA_READ_STATE_DONE) begin
			dna_shift	<= 0;
			dna_phase	<= 0;
			dna_clk		<= 0;
			dna_read	<= 0;
		end
	
		//Time to toggle the clock (ignore everythign else)
		else if(dna_nextphase) begin
			
			dna_phase	<= dna_phase + 2'b1;
			
			case(dna_phase)
			
				//Low period before rising edge - drive new inputs to DNA port
				0: begin
				
					case(dna_read_state)
					
						//Wait 128 clocks during boot to be REALLY sure everything is fully reset
						DNA_READ_STATE_BOOT_0: begin
						
							dna_read_count	<= dna_read_count + 7'h1;
							
							if(dna_read_count == 127) begin
								dna_read		<= 1;
								dna_read_count	<= 0;
								dna_read_state	<= DNA_READ_STATE_BOOT_1;
							end
						end
						
						//Read is done, start shifting data
						DNA_READ_STATE_BOOT_1: begin
							dna_shift <= 1;
							dna_read_state <= DNA_READ_STATE_READ;
						end
						
						//Shift the data
						DNA_READ_STATE_READ: begin
							dna_shift <= 1;
						end
					
					endcase
					
				end
				
				//Rising edge of clock
				1: begin
					dna_clk		<= 1;
				end
				
				//High period before falling edge - read outputs
				2: begin
				
					//Clear enables
					dna_read	<= 0;
					dna_shift	<= 0;
					
					//Read outputs
					if(dna_read_state == DNA_READ_STATE_READ) begin
						dna_read_count	<= dna_read_count + 7'h1;
						dna_data		<= {dna_data[62:0], dna_out};
						
						//Done?
						if(dna_read_count == 55) begin
							dna_read_state	<= DNA_READ_STATE_DONE;
							boot_done	<= 1;
							
							//Have to do this to match up with JTAG data (why is this not being kept?)
							dna_data[56]	<= 1'b1;
							
						end
					end
				
				end
				
				//Falling edge of clock
				3: begin
					dna_clk		<= 0;
				end
			
			endcase

		end
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// On-die sensors
	
	reg			sensors_present		= 0;
	wire[15:0]	die_temp;
	wire[15:0]	volt_core;
	wire[15:0]	volt_ram;
	wire[15:0]	volt_aux;
	
	//7-series XADC
	`ifdef XILINX_7SERIES
		OnDieSensors_7series #(
			.sysclk_hz(sysclk_hz)
		) sensors(
			.clk(clk),
			.die_temp(die_temp),
			.volt_core(volt_core),
			.volt_ram(volt_ram),
			.volt_aux(volt_aux)
		);
		
		always @(posedge clk) begin
			sensors_present	<= 1;
		end
	
	//TODO: Other FPGA families here
	`else
		always @(posedge clk) begin
			sensors_present	<= 0;
		end
		
		assign volt_core = 0;
		assign volt_ram = 0;
		assign volt_aux = 0;
		assign die_temp = 0;
	`endif
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The divider
	
	reg divstart = 0;
	wire[31:0] quot;
	wire[31:0] rem;
	wire divbusy;
	wire divdone;
	UnsignedNonPipelinedDivider divider(
		.clk(clk),
		.start(divstart),
		.dend(sysclk_hz),	//constant for now
		.dvsr(rpc_fab_rx_d1),
		.quot(quot),
		.rem(rem),
		.busy(divbusy),
		.done(divdone));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Main state machine
	
	`include "NOCSysinfo_constants.v"	//Pull in autogenerated constant table
	
	localparam STATE_BOOTING 			= 'h0;
	localparam STATE_IDLE				= 'h1;
	localparam STATE_TX					= 'h2;
	localparam STATE_QUERY_CYCFREQ		= 'h3;
	reg[1:0] state = STATE_BOOTING;
	
	//DNA reading
	always @(posedge clk) begin
	
		rpc_fab_tx_en <= 0;
		rpc_fab_rx_done <= 0;
		divstart <= 0;
	
		case(state)
			
			//Load the DNA
			STATE_BOOTING: begin
			
				rpc_fab_tx_callnum <= rpc_fab_tx_callnum;
				rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
			
				if(boot_done)
					state <= STATE_IDLE;
					
				//Can't handle calls just yet - send retry to make them back off
				if(rpc_fab_rx_en) begin
					if(rpc_fab_rx_type == RPC_TYPE_CALL)
						rpc_fab_tx_en <= 1;
					rpc_fab_rx_done <= 1;
				end
			end
			
			STATE_IDLE: begin
			
				//Default to returning success with no data
				rpc_fab_tx_type <= RPC_TYPE_RETURN_SUCCESS;
				rpc_fab_tx_dst_addr <= rpc_fab_rx_src_addr;
				rpc_fab_tx_callnum[7:2] <= 0;							//only low bits of callnum are used for now
				rpc_fab_tx_callnum[2:0] <= rpc_fab_rx_callnum[2:0];
				rpc_fab_tx_d0 <= 0;
				rpc_fab_tx_d1 <= 0;
				rpc_fab_tx_d2 <= 0;
				
				//Function call? Process the opcode
				if(rpc_fab_rx_en && (rpc_fab_rx_type == RPC_TYPE_CALL)) begin
					
					//only low bits of callnum are used for now
					case(rpc_fab_rx_callnum[2:0])
										
						//Read the device DNA
						SYSINFO_CHIP_SERIAL: begin
							rpc_fab_tx_d1 <= dna_data[63:32];
							rpc_fab_tx_d2 <= dna_data[31:0];						
							rpc_fab_tx_en <= 1;
							state <= STATE_TX;
						end
						
						//Query the clock frequency
						SYSINFO_QUERY_FREQ: begin
							rpc_fab_tx_d1 <= sysclk_period;
							rpc_fab_tx_en <= 1;
							state <= STATE_TX;
						end

						/*
							Query the number of clock cycles needed to get a certain frequency
							Input (d1):  frequency in Hz
							Output (d1): cycle count
						 */
						SYSINFO_GET_CYCFREQ: begin
							divstart <= 1;
							state <= STATE_QUERY_CYCFREQ;
						end
						
						//Return the die temperature
						SYSINFO_GET_TEMP: begin
							if(!sensors_present)
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								
							rpc_fab_tx_d1	<= die_temp;
							rpc_fab_tx_en	<= 1;
							state <= STATE_TX;
						end
						
						//Return the core voltage
						SYSINFO_GET_VCORE: begin
							if(!sensors_present)
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								
							rpc_fab_tx_d1	<= volt_core;
							
							//Legal range for 7 series VCCINT: 0.95 - 1.05
							//TODO: Support -2L/2LI devices
							`ifdef XILINX_7SERIES
								rpc_fab_tx_d2	<= {16'h010d, 16'h00f3};
							`endif
							
							rpc_fab_tx_en	<= 1;
							state <= STATE_TX;
						end
						
						//Return the block RAM voltage
						SYSINFO_GET_VRAM: begin
							if(!sensors_present)
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								
							rpc_fab_tx_d1	<= volt_ram;
							
							//Legal range for 7 series VCCBRAM: 0.95 - 1.05
							//TODO: Support -2L/2LI devices
							`ifdef XILINX_7SERIES
								rpc_fab_tx_d2	<= {16'h010d, 16'h00f3};
							`endif
							
							rpc_fab_tx_en	<= 1;
							state <= STATE_TX;
						end
						
						//Return the auxiliary voltage
						SYSINFO_GET_VAUX: begin
							if(!sensors_present)
								rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
								
							rpc_fab_tx_d1	<= volt_aux;
							
							//Legal range for 7 series VCCAUX: 1.7 - 1.9
							//TODO: Support -2L/2LI devices
							`ifdef XILINX_7SERIES
								rpc_fab_tx_d2	<= {16'h01e6, 16'h01b3};
							`endif
							
							rpc_fab_tx_en	<= 1;
							state <= STATE_TX;
						end
						
						/*
							TODO: Query the number of clock cycles needed to get a certain period
							Input (d1): period in ps
							Output (d0): cycle count
							
							cycles_out = requested_period / clock_period
						 */
						 
						 //Unknown opcode, return failure
						 default: begin
							rpc_fab_tx_en <= 1;
							rpc_fab_tx_type <= RPC_TYPE_RETURN_FAIL;
							state <= STATE_TX;
						end
						
					endcase				
				end
				
			end
			
			//Process frequency-to-cycle conversion
			STATE_QUERY_CYCFREQ: begin
				if(divdone) begin
					rpc_fab_tx_d1 <= quot;
					rpc_fab_tx_en <= 1;
					state <= STATE_TX;
				end
			end
			
			//Send the message
			STATE_TX: begin
				if(rpc_fab_tx_done) begin
					rpc_fab_rx_done <= 1;
					state <= STATE_IDLE;
				end
			end
			
		endcase
	
	end
	
endmodule
