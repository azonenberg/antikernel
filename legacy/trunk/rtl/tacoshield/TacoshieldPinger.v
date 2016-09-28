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
	@brief Main pinger subsystem
 */
module TacoshieldPinger(
	
	//Clocks
	clk,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//Microphone interface
	mic_clk, mic_data,
	
	//DAC interface
	dac_mclk, dac_reset_n,
	dac_din, dac_wclk, dac_bclk,
	dac_spi_cs_n, dac_spi_mosi, dac_spi_miso, dac_spi_sck,
	
	//LEDs
	led_0, led_1,
	
	//Debug signals
	spi_shift_en, spi_shift_done, spi_tx_data, spi_rx_data, dac_init_state, 
	agc_update, agc_sample_shifted, i_shifted, q_shifted
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	`include "../achd-soc/util/clog2.vh"
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire			clk;
	
	//NoC interface
	output wire			rpc_tx_en;
	output wire[31:0]	rpc_tx_data;
	input wire[1:0]		rpc_tx_ack;
	input wire			rpc_rx_en;
	input wire[31:0]	rpc_rx_data;
	output wire[1:0]	rpc_rx_ack;
	
	output wire			dma_tx_en;
	output wire[31:0]	dma_tx_data;
	input wire			dma_tx_ack;
	input wire			dma_rx_en;
	input wire[31:0]	dma_rx_data;
	output wire			dma_rx_ack;
	
	//Microphone interface
	output reg			mic_clk;
	input wire			mic_data;
	
	//DAC control interface
	output reg			dac_mclk		= 0;	//master clock
	output reg			dac_reset_n		= 0;	//reset (hold in reset during boot)
	
	//DAC data interface
	output reg			dac_din			= 0;	//data in
	output reg			dac_bclk		= 0;	//bit clock
	output reg			dac_wclk		= 0;	//word clock
	
	//DAC config interface
	output wire			dac_spi_sck;
	output reg			dac_spi_cs_n	= 1;
	output wire			dac_spi_mosi;
	input wire			dac_spi_miso;
		
	//Debug LEDs
	output reg			led_0	= 0;
	output reg			led_1	= 0;		//doesn't work in current PCB for reasons unknown
	
	//DEBUG
	output	spi_shift_en;
	output	spi_shift_done;
	output	spi_tx_data;
	output	spi_rx_data;
	output	dac_init_state;
	output	agc_update;
	output	agc_sample_shifted;
	output	i_shifted;
	output	q_shifted;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transceiver
	
	parameter NOC_ADDR = 16'h0000;
	
	reg			rpc_fab_tx_en		= 0;
	reg[15:0]	rpc_fab_tx_dst_addr	= 0;
	reg[7:0]	rpc_fab_tx_callnum	= 0;
	reg[2:0]	rpc_fab_tx_type		= 0;
	reg[20:0]	rpc_fab_tx_d0		= 0;
	reg[31:0]	rpc_fab_tx_d1		= 0;
	reg[31:0]	rpc_fab_tx_d2		= 0;
	wire		rpc_fab_tx_done;
	wire		rpc_fab_inbox_full;
	
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
		.rpc_fab_inbox_full(rpc_fab_inbox_full)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA transceiver
	
	`include "DMARouter_constants.v"
	
	//DMA transmit signals
	wire		dtx_busy;
	reg[15:0]	dtx_dst_addr	= 0;
	reg[1:0]	dtx_op			= 0;
	reg[9:0]	dtx_len			= 0;
	reg[31:0]	dtx_addr		= 0;
	reg			dtx_en			= 0;
	wire		dtx_rd;
	wire[9:0]	dtx_raddr;
	wire[31:0]	dtx_buf_out;
	
	//DMA receive signals
	reg 		drx_ready		= 1;
	wire		drx_en;
	wire[15:0]	drx_src_addr;
	wire[1:0]	drx_op;
	wire[31:0]	drx_addr;
	wire[9:0]	drx_len;	
	reg			drx_buf_rd		= 0;
	reg[9:0]	drx_buf_addr	= 0;
	wire[31:0]	drx_buf_data;
	
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
		.rx_buf_rd(drx_buf_rd), .rx_buf_addr(drx_buf_addr[8:0]), .rx_buf_data(drx_buf_data), .rx_buf_rdclk(clk)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Dummy NoC interface just to make warnings go away
	
	always @(posedge clk) begin
		rpc_fab_tx_en		<= 0;
		rpc_fab_tx_dst_addr	<= 0;
		rpc_fab_tx_callnum	<= 0;
		rpc_fab_tx_type		<= 0;
		rpc_fab_tx_d0		<= 0;
		rpc_fab_tx_d1		<= 0;
		rpc_fab_tx_d2		<= 0;
		drx_ready			<= 1;
		drx_buf_rd			<= 0;
		drx_buf_addr		<= 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Microphone stuff
	
	//Generate a 5 MHz clock from the main clock (divided by 2)
	always @(posedge clk) begin
		mic_clk <= ~mic_clk;
	end
	
	//Decimate the 1-bit data
	//We have a 5 MHz 1-bit PDM stream, we want a lower data rate signal
	//5 MHz / 52 = ~96 kHz
	//Note that the output of this filer is unsigned
	wire		mic_update;
	wire[13:0]	mic_sample;
	CICDecimationFilter #(
		.IN_WIDTH(1),
		.TEMP_WIDTH(24),
		.OUT_WIDTH(14),
		.ORDER(3),
		.DECIMATION(52)
	) mic_decimator (
		.clk(clk),
		.din(mic_data),
		.din_valid(mic_clk),
		.dout(mic_sample),
		.dout_valid(mic_update)
		);
	
	//Next up, high-pass filter to remove the DC offset
	//Set cutoff at 6 kHz, well below our lower bound
	//We have 104 clocks per sample available but need way less than that
	wire		hpf_busy;
	wire[23:0]	hpf_dout_raw;
	wire		hpf_update;
	SymmetricFIRFilter #(
		.ORDER(31),
		.CYCLES_PER_SAMPLE(8),
		.DATA_WIDTH(24),
		.ADDER_TREE_WIDTH(2),
		.MULT_TYPE("DSP"),
		.FILTER_TYPE("HIGH_PASS"),
		.ATTEN_DB(50),
		.SAMPLE_FREQ(96),
		.CUTOFF_A(6),
		.CUTOFF_B(48)
	) dc_removal (
		.clk(clk),
		.in_data({mic_sample, 10'h0} - 24'h800000),	//Scale to +/- 2^23
														//since the FIR core expects signed inputs
		.in_valid(mic_update),
		.in_busy(hpf_busy),
		.out_data(hpf_dout_raw),
		.out_valid(hpf_update)
	);
	
	//Automatic gain control to normalize the amplitude
	//For now, AGC has to run on 32 bit data (TODO fix this)
	wire			agc_update;
	wire[31:0]		agc_sample;
	wire[31:0]		agc_gain;
	AutomaticGainControl #(
		.MIN_AMPLITUDE(32'h20000000),
		.MAX_AMPLITUDE(32'h40000000)
	) agc (
		.clk(clk),
		.din({hpf_dout_raw, 8'h00}),
		.din_valid(hpf_update),
		.dout(agc_sample),
		.dout_valid(agc_update),
		.agc_gain(agc_gain)
		);
		
	//Sine table for I/Q demodulation
	wire[15:0]		sin_wave;
	wire[15:0]		cos_wave;
	reg				carrier_update			= 0;
	reg[15:0]		carrier_phase			= 0;
	reg[15:0]		carrier_phase_internal	= 0;
	SineWaveGenerator #(
		.PHASE_SIZE(256),
		.FRAC_BITS(16)
	) carrier_sinetable (
		.clk(clk),
		.update(carrier_update),
		.phase(carrier_phase[15:6]),
		.sin_out(sin_wave),
		.cos_out(cos_wave)
	);
	
	//DDS to generate a nice clean ~96 kHz sinewave (5 MHz / 104)
	//We have 10 bits of phase resolution when reading the sine table, but use 16 internally to reduce error
	always @(posedge clk) begin
	
		carrier_update			<= 0;
		
		//Read the sine table when we get a new sample off the AGC
		if(agc_update) begin
			carrier_update		<= 1;
			carrier_phase		<= carrier_phase_internal;
		end

		//Bump phase by 630 each clock. This gives us a period of 104.025 clocks, or 96.13 kHz
		carrier_phase_internal	<= carrier_phase_internal + 12'h212;
	
	end
	
	//Multiply the AGC'd data by sin/cos to get I and Q
	(* MULT_STYLE = "pipe_block" *)
	reg[31:0]	i_unfiltered_raw		= 0;
	(* MULT_STYLE = "pipe_block" *)
	reg[31:0]	q_unfiltered_raw		= 0;
	reg[31:0]	i_unfiltered_raw_ff		= 0;
	reg[31:0]	q_unfiltered_raw_ff		= 0;
	reg[31:0]	i_unfiltered_raw_ff2	= 0;
	reg[31:0]	q_unfiltered_raw_ff2	= 0;
	
	//Truncate
	wire[15:0]	i_unfiltered			= i_unfiltered_raw_ff2[31:16];
	wire[15:0]	q_unfiltered			= q_unfiltered_raw_ff2[31:16];
	
	always @(posedge clk) begin
		i_unfiltered_raw 		<= $signed(agc_sample[31:16]) * $signed(sin_wave - 16'h8000);
		q_unfiltered_raw 		<= $signed(agc_sample[31:16]) * $signed(cos_wave - 16'h8000);
		
		i_unfiltered_raw_ff		<= i_unfiltered_raw;
		q_unfiltered_raw_ff		<= q_unfiltered_raw;
		
		i_unfiltered_raw_ff2	<= i_unfiltered_raw_ff;
		q_unfiltered_raw_ff2	<= q_unfiltered_raw_ff;
	end

	//DEBUG: apply DC offset so we can plot signals
	wire[31:0] agc_sample_shifted;
	assign agc_sample_shifted = agc_sample + 32'h80000000;
	
	wire[15:0] i_shifted = i_unfiltered + 16'h8000;
	wire[15:0] q_shifted = q_unfiltered + 16'h8000;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Speaker driver (for now, just a 1 kHz sinewave)
	
	reg			spi_shift_en	= 0;
	wire		spi_shift_done;
	reg[7:0]	spi_tx_data		= 0;
	wire[7:0]	spi_rx_data;
	
	//SPI transceiver for initializing the DAC
	SPITransceiver #(
		.SAMPLE_EDGE("FALLING"),
		.LOCAL_EDGE("NORMAL")
	) spi (
		.clk(clk),
		.clkdiv(16'h4),	//run at 2.5 MHz for now (DAC can theoretically go up to 10 though)
		
		.spi_sck(dac_spi_sck),
		.spi_mosi(dac_spi_mosi),
		.spi_miso(dac_spi_miso),
		
		.shift_en(spi_shift_en),
		.shift_done(spi_shift_done),
		.tx_data(spi_tx_data),
		.rx_data(spi_rx_data)
	);
	
	//ROM of register IDs/values for initialization
	//{reg ID, value}
	reg[15:0]	init_rom[7:0];
	initial begin
		
		//Omit soft reset as we just did a hard reset
		
		//TODO: Program dividers
		
		/*
			Program PLL
				
			PFD frequency (after pre-divider) must be 512 kHz - 20 MHz
			When using fractional divide, must be 10 MHz - 20 MHz

			R = 4, J = 12, D = 0, P = 5			
			PLL_CLK = 10 MHz * 4 * 12.0 / 5 = 96 MHz
		 */
		init_rom[0]	<= {8'h0, 8'h00};	//Select page 0
		init_rom[1]	<= {8'h4, 8'h03};	//Low PLL clock range
										//MCLK is input to PLL
										//CODEC_CLKIN comes from PLL
		init_rom[2] <= {8'h6, 8'h0c};	//Multiplier J = 12
		init_rom[3]	<= {8'h7, 8'h00};	//Divider D MSB = 0
		init_rom[4] <= {8'h8, 8'h00};	//Divider D LSB = 0
		
		init_rom[5]	<= {8'h5, 8'hd4};	//PLL powered up
										//Pre-divider = 5
										//Multiplier R = 4
		
		//PLL is now initialized! Need to wait for a little bit while it locks
		
		
		/*
			Initial bringup!!!
						
			PLL_CLK = 10 MHz * R * J.D / P
			
			in PLL mode 0
				PLL_CLK must be 80 - 132 MHz
			in mode 1
				PLL_CLK must be 92 - 137 MHz
						
			CLOCK STRUCTURE
				
				PLL_CLKIN = 10 MHz
				Set up PLL as 2x multiplier
				CODEC_CLKIN = PLL_CLK = 20 MHz
				NDAC = 1
				DAC_CLK = 20 MHz
				MDAC = 5
				DAC_MOD_CLK = 4 MHz
				DOSR = 80
				DAC_FS = DAC_MOD_CLK/DOSR = 50 kHz
				
			
			
			
			Use PRB_P25 to enable beep generator (bypasses most of the signal chain, so good for bringup)
			Filter A
			Resource class 12
			DOSR must be mul of 8
			DAC_FS = 48.08 kHz (10 MHz / 208)
			DOSR = 64
			DOSR*DAC_FS = 3.077 MHz
			MDAC=6
			NDAC=1
			CODEC_CLKIN = 1*6*(4/13) * 10 MHz = 18.46 MHz ??
			
			
			
			
			
			Master clock			x
			Select filter C			x
			DAC_FS = 96.15 kHz (10 MHz / 104)
			DOSR = 52
			DOSR * DAC_FS = 5 MHz
			NDAC = 1
			MDAC = 1
			DOSR = 52
			DAC_FS = 96.15 kHz
			CODEC_CLKIN = 5 MHz
			Use 
			
			PLL clock on MCLK		r4[3:2] = 2'b00
			Codec clock on MCLK		r4[1:0] = 2'b00
			I2S BCLK on BCLK		r27[3] = 1'b0
			I2S WCLK on WCLK		r27[2] = 1'b0
			I2S ADC clk on GPIO2	r52[5:2] = 4'b0001
									r31[2:1] = 2'b00
			I2S DIN on DIN			r54[2:1] = 2'b01
			Left volume = xx		r65[7:0] = xx
			Right volume = xx		r66[7:0] = xx
			Disable compression		r68[6:5] = xx
						
			Sine wave coefficient	r76/77
			Cosine coefficient		r78/79
			Sine length				r73/74/75
			Left sine volume		r71[5:0]
			Right sine volume		r72[5:0]
			Master sine volume		r72[7:6]
						
			Select page 1			r0[7:0] = 8'b00000001
			Rpop = 2K				r20[1:0] = 2'b00
			Slow charge time = 5	r20[5:2] = 4'b1001
			50ms soft step			r20[7:6] = 2'b01
			
			Beep enable				r71[7] = 1
		 */
		
		//init_rom[1]	<= {
		
	end
	
	reg[3:0]	dac_init_state	= 0;
	reg[15:0]	dac_init_count	= 0;
	
	always @(posedge clk) begin
	
		spi_shift_en	<= 0;
		
		case(dac_init_state)
		
			//Hold in reset for a millisecond, then start it
			0: begin
				dac_reset_n		<= 0;
				dac_init_count	<= dac_init_count + 1'h1;
				if(dac_init_count == 10000) begin
					dac_init_count	<= 0;
					dac_init_state	<= 1;
					dac_reset_n		<= 1;
				end
			end
			
			//Wait a millisecond for device to initialize
			1: begin
				if(dac_init_count == 10000) begin
					dac_init_count	<= 0;
					dac_init_state	<= 2;
				end
			end
			
			//Wait for client to connect before we do anything
			2: begin
				if(rpc_fab_inbox_full) begin
					dac_reset_n		<= 1;
					dac_init_state	<= 3;
				end
			end
			
			/*
			3: begin
							
			end
			*/
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DMA buffer for the microphone
	
	//We sample at 96.15 kHz (round to 96)
	//Pack one sample per byte (4 per word)
	//2048 samples (one BRAM) = 21.3 ms per block
	//Record four of them = ~84 ms
	
	reg			fifo_wr	= 0;
	reg[31:0]	fifo_wdata = 0;
	wire		fifo_full;
	wire[11:0]	fifo_rsize;

	reg			boot_wait	= 1;
	
	SingleClockFifo #(
		.WIDTH(32),
		.DEPTH(2048)
	) fifo (
		.clk(clk),
		.reset(1'b0),
		
		.wr(fifo_wr),
		.din(fifo_wdata),
		.full(fifo_full),
		.overflow(),
		.wsize(),
		
		.rd(dtx_rd),
		.dout(dtx_buf_out),
		.rsize(fifo_rsize),	
		.underflow(),
		.empty()
    );
    
    //Stage 4 samples at a time, then push
    reg[1:0] scount = 0;
    always @(posedge clk) begin
    
		rpc_fab_rx_done	<= 1;
		if(rpc_fab_inbox_full) begin
			rpc_fab_rx_done	<= 1;
			dtx_dst_addr	<= rpc_fab_rx_src_addr;
			boot_wait		<= 0;
		end
    
		fifo_wr			<= 0;
    
		if(mic_update && !fifo_full) begin
			scount		<= scount + 1'd1;
			fifo_wdata	<= {fifo_wdata[23:0], mic_sample[13:6]};	//TODO: mic sample stuff
			
			if(scount == 3 && !boot_wait)
				fifo_wr	<= 1;
			
		end
    end
    
    //Do the DMA stuff
    always @(posedge clk) begin
		dtx_en			<= 0;
		dtx_addr		<= 0;
		dtx_len			<= 512;
		dtx_op			<= DMA_OP_WRITE_REQUEST;
		
		//Busy? Handle reads
		if(dtx_en || dtx_busy) begin
			//combinatorial
		end
		
		//If we're not busy, and have at least 512 words to send, do it
		else if(fifo_rsize >= 512)
			dtx_en	<= 1;
		
    end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// LED blinky
	
	reg[20:0] count = 0;
	always @(posedge clk) begin
		count	<= count + 1'h1;
		if(count == 0)
			led_0 <= ~led_0;
	end
	
endmodule

