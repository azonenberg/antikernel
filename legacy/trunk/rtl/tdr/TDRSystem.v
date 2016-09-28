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
	@brief TDR subsystem
 */
module TDRSystem(
	
	//Clocks
	clk, clk_serdes,
	
	//NoC interface
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack,
	dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
	
	//DAC
	dac_spi_sck, dac_spi_mosi, dac_spi_cs_n,
	
	//Preamplifiers
	pga_sck, pga_mosi, pga_miso, pga_cs_n,
	
	//Pulse generator
	ch1_pulse_p, ch1_pulse_n,
	
	//Incoming sample data
	ch1_sample_p, ch1_sample_n,
	
	//LEDs on the RJ45
	tdr_leds,
	
	//Debug stuff
	pga_shift_en, pga_shift_done, pga_tx_data, pga_rx_data,
	preamp_chan, preamp_reg, preamp_rd, preamp_rdata, preamp_done, preamp_wdata, preamp_wr
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	//Clocks
	input wire			clk;
	input wire			clk_serdes;
	
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
	
	//DAC
	output wire			dac_spi_sck;
	output wire			dac_spi_mosi;
	output reg			dac_spi_cs_n	= 1;
	
	//Preamplifiers
	output wire[3:0]	pga_sck;
	output wire[3:0]	pga_mosi;
	input wire[3:0]		pga_miso;
	output reg[3:0]		pga_cs_n	= 4'hf;	//default all chips to not selected
	
	//Pulse generation
	output wire			ch1_pulse_p;
	output wire			ch1_pulse_n;
	
	//Incoming sample data
	input wire			ch1_sample_p;
	input wire			ch1_sample_n;
	
	//LEDs on the RJ45
	output reg[1:0]		tdr_leds		= 0;
	
	//Debug stuff
	output pga_shift_en;
	output pga_shift_done;
	output pga_tx_data;
	output pga_rx_data;
	output preamp_chan;
	output preamp_reg;
	output preamp_rd;
	output preamp_wr;
	output preamp_rdata;
	output preamp_done;
	output preamp_wdata;
	
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
	// SPI interface for the DAC
	
	reg			dac_shift_en	= 0;
	wire		dac_shift_done;
	reg[7:0]	dac_tx_data		= 0;
	
	//Note that the DAC samples on the falling edge of SCK, not the rising
	SPITransceiver #(
		.SAMPLE_EDGE("FALLING")
	) dac_spi(
		.clk(clk),
		.clkdiv(16'd4),	//25 MHz for clk_noc = 100 MHz
						//TODO: Make this runtime adjustable
		.spi_sck(dac_spi_sck),
		.spi_mosi(dac_spi_mosi),
		.spi_miso(1'b0),
		.shift_en(dac_shift_en),
		.shift_done(dac_shift_done),
		.tx_data(dac_tx_data),
		.rx_data()
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// SPI interface for the PGAs
	
	//Packed tx/rx data for four channels
	reg[3:0]	pga_shift_en	= 0;
	wire[3:0]	pga_shift_done;
	reg[7:0]	pga_tx_data;
	wire[31:0]	pga_rx_data;
	
	genvar i;
	generate
		for(i=0; i<4; i=i+1) begin: preamp_spi
		
			SPITransceiver #(
				.SAMPLE_EDGE("RISING"),		//PGA samples data on the rising edge of SCK
				.LOCAL_EDGE("INVERTED")		//PGA drives data on the falling edge, and we sample the next rising
			) txvr (
				.clk(clk),
				.clkdiv(16'd4),	//25 MHz for clk_noc = 100 MHz
								//TODO: Make this runtime adjustable
				.spi_sck(pga_sck[i]),
				.spi_mosi(pga_mosi[i]),
				.spi_miso(pga_miso[i]),
				.shift_en(pga_shift_en[i]),
				.shift_done(pga_shift_done[i]),
				.tx_data(pga_tx_data),
				.rx_data(pga_rx_data[i*8 +: 8])
			);
		end
		
	endgenerate
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Differential I/O buffers
	
	wire ch1_pulse;
	OBUFDS ch1_obuf(.I(ch1_pulse), .O(ch1_pulse_p), .OB(ch1_pulse_n));
	
	wire ch1_sample;
	IBUFDS ch1_ibuf(.I(ch1_sample_p), .IB(ch1_sample_n), .O(ch1_sample));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pulse generation SERDES
	
	(* MAX_FANOUT = "REDUCE" *)
	reg		pulse_gen_en		= 0;
	
	OSERDESE2 #(
		.DATA_RATE_OQ("DDR"),
		.DATA_RATE_TQ("SDR"),
		.DATA_WIDTH(8),
		.INIT_OQ(1'b0),
		.INIT_TQ(1'b0),
		.SERDES_MODE("MASTER"),
		.SRVAL_OQ(1'b0),
		.SRVAL_TQ(1'b0),
		.TBYTE_CTL("FALSE"),
		.TBYTE_SRC("FALSE"),
		.TRISTATE_WIDTH(1)
	) ch1_oserdes (
		.CLK(clk_serdes),
		.CLKDIV(clk),
		.D1(1'b1),
		.D2(1'b0),
		.D3(1'b0),
		.D4(1'b0),
		.D5(1'b0),
		.D6(1'b0),
		.D7(1'b0),
		.D8(1'b0),
		.OCE(pulse_gen_en),
		.OFB(),
		.OQ(ch1_pulse),
		.RST(1'b0),
		.SHIFTIN1(),
		.SHIFTIN2(),
		.SHIFTOUT1(),
		.SHIFTOUT2(),
		.TBYTEIN(),
		.TBYTEOUT(),
		.TCE(),
		.TFB(),
		.TQ(),
		.T1(1'b0),
		.T2(1'b0),
		.T3(1'b0),
		.T4(1'b0)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Deserializers for incoming pulse data
	
	wire[7:0] ch1_sample_deserialized;
	
	ISERDESE2 #(
		.DATA_RATE("DDR"),
		.DATA_WIDTH(8),
		.DYN_CLKDIV_INV_EN("FALSE"),
		.DYN_CLK_INV_EN("FALSE"),
		.INIT_Q1(1'b0),
		.INIT_Q2(1'b0),
		.INIT_Q3(1'b0),
		.INIT_Q4(1'b0),
		.INTERFACE_TYPE("NETWORKING"),
		.NUM_CE(2),
		.OFB_USED("FALSE"),
		.SERDES_MODE("MASTER"),
		.SRVAL_Q1(1'b0),
		.SRVAL_Q2(1'b0),
		.SRVAL_Q3(1'b0),
		.SRVAL_Q4(1'b0)
	) ch1_iserdes (
		.BITSLIP(1'b0),
		.CE1(1'b1),
		.CE2(1'b1),
		.CLK(clk_serdes),
		.CLKB(~clk_serdes),
		.CLKDIV(clk),
		.CLKDIVP(1'b0),
		.D(ch1_sample),
		.DDLY(1'b0),
		.DYNCLKDIVSEL(1'b0),
		.DYNCLKSEL(1'b0),
		.O(),
		.OCLK(),
		.OCLKB(),
		.OFB(),
		.Q1(ch1_sample_deserialized[0]),
		.Q2(ch1_sample_deserialized[1]),
		.Q3(ch1_sample_deserialized[2]),
		.Q4(ch1_sample_deserialized[3]),
		.Q5(ch1_sample_deserialized[4]),
		.Q6(ch1_sample_deserialized[5]),
		.Q7(ch1_sample_deserialized[6]),
		.Q8(ch1_sample_deserialized[7]),
		.RST(1'b0),
		.SHIFTIN1(1'b0),
		.SHIFTIN2(1'b0),
		.SHIFTOUT1(),
		.SHIFTOUT2()
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Pulse receiving logic
	
	reg				pulse_gen_en_adv	= 0;
	
	reg[15:0]		host_address		= 0;	
	reg[1:0]		rx_state			= 0;
	
	reg				sample_buf_we		= 0;
	reg[5:0]		sample_buf_waddr	= 0;
	reg[1:0]		sample_buf_windex	= 0;
	reg[31:0]		sample_buf_wdata	= 0;
	
	reg[11:0] 		dac_voltage = 0;
	
	//Total sample range is 2K samples. 32 bits per word gives 64 words.
	MemoryMacro #(
		.WIDTH(32),
		.DEPTH(64),
		.OUT_REG(1),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.INIT_VALUE(0)
	) sample_mem(
		.porta_clk(clk),
		.porta_en(sample_buf_we),
		.porta_addr(sample_buf_waddr),
		.porta_we(1'b1),
		.porta_din(sample_buf_wdata),
		.porta_dout(),
		
		.portb_clk(clk),
		.portb_en(dtx_rd),
		.portb_addr(dtx_raddr[5:0]),
		.portb_we(1'b0),
		.portb_din(32'h0),
		.portb_dout(dtx_buf_out)
	);
	
	always @(posedge clk) begin
		
		//Constant parameters for outbound DMA messages
		dtx_dst_addr	<= host_address;
		dtx_addr		<= dac_voltage;
		dtx_len			<= 64;
		dtx_op			<= DMA_OP_WRITE_REQUEST;
		
		//Clear flags
		dtx_en			<= 0;
		sample_buf_we	<= 0;
		
		case(rx_state)
			
			//About to send a pulse? Get ready
			0: begin
			
				sample_buf_waddr	<= 0;
				sample_buf_windex	<= 0;
				sample_buf_wdata	<= 0;
			
				if(pulse_gen_en_adv)
					rx_state	<= 1;
			end
			
			//Capturing data
			1: begin
			
				//Bump on all but the first cycle
				if(!pulse_gen_en)
					sample_buf_windex	<= sample_buf_windex + 2'h1;
				
				//Write to the width conversion buffer
				//The FIRST bit we got is the MSB of the first word
				sample_buf_wdata	<= {sample_buf_wdata[23:0], ch1_sample_deserialized};
				
				//If we just wrote the last sample to the width conversion buffer, write it to the SRAM
				if(sample_buf_windex == 3)
					sample_buf_we		<= 1;
					
				//If we just wrote to the SRAM, bump addresses
				if(sample_buf_we) begin
					
					sample_buf_waddr	<= sample_buf_waddr + 6'h1;
					
					//If we just wrote the last word, send the DMA packet
					if(sample_buf_waddr == 6'h3f) begin
						dtx_en			<= 1;
						rx_state		<= 2;
					end
					
				end
					
			end
			
			//Sending DMA packet
			2: begin
				if(!dtx_busy && !dtx_en)
					rx_state			<= 0;
			end
		
		endcase
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Preamplifier register read/write API
	
	reg[1:0]	preamp_chan		= 0;
	reg[3:0]	preamp_reg		= 0;
	reg			preamp_rd		= 0;
	reg			preamp_wr		= 0;
	reg[7:0]	preamp_rdata	= 0;
	reg[7:0]	preamp_wdata	= 0;
	reg			preamp_done		= 0;
	
	reg[2:0] 	preamp_state	= 0;
	reg[2:0] 	preamp_count	= 0;
	
	reg			preamp_is_rd	= 0;
	
	always @(posedge clk) begin
	
		pga_shift_en	<= 0;
		preamp_done		<= 0;
		
		case(preamp_state)
			
			//Idle - wait for R/W transaction, then select the chip
			0: begin
				if(preamp_rd || preamp_wr) begin
					pga_cs_n[0]		<= 0;
					preamp_count	<= 1;
					preamp_state	<= 1;
					preamp_is_rd	<= preamp_rd;
				end
			end
			
			//Wait for select, then send write command
			1: begin
				preamp_count				<= preamp_count + 3'h1;
				
				if(preamp_count == 0) begin
					pga_shift_en[preamp_chan]			<= 1;
					pga_tx_data							<= {preamp_is_rd, 3'h0, preamp_reg};
					preamp_state						<= 2;
				end
			end
			
			//Wait for command shift, then shift data
			2: begin
				if(pga_shift_done[preamp_chan]) begin
					pga_shift_en[preamp_chan]			<= 1;
					if(preamp_is_rd)
						pga_tx_data						<= 0;
					else
						pga_tx_data						<= preamp_wdata;
					preamp_state						<= 3;
				end
			end
			
			//Wait for data shift, then deselect
			3: begin
				if(pga_shift_done[preamp_chan]) begin
					pga_cs_n[preamp_chan]				<= 1;
					preamp_count						<= 1;
					preamp_state						<= 4;
					if(preamp_is_rd)
						preamp_rdata					<= pga_rx_data[(preamp_chan*8) +: 8];
				end
			end
			
			//Keep CS high for a while before next op
			4: begin
				preamp_count						<= preamp_count + 3'h1;
				
				if(preamp_count == 0) begin
					preamp_done						<= 1;
					preamp_state					<= 0;
				end
			end
			
		endcase
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Preamplifier driver - set preamp gain based on (TBD) RPC message content
	
	reg[2:0]	gain_state	= 0;
	
	always @(posedge clk) begin
			
		preamp_rd	<= 0;
		preamp_wr	<= 0;
			
		case(gain_state)
		
			//Read IDCODE from each one
			0: begin
				if(rpc_fab_rx_en) begin
					preamp_chan		<= 0;
					gain_state		<= 1;					
				end
			end
			
			//Loop over channels and set gain for them all			
			1: begin
				preamp_rd		<= 1;
				preamp_reg		<= 1;
				gain_state		<= 2;
			end
			
			//Verify it's 'h20, then turn it on
			2: begin
				if(preamp_done) begin
					
					//hang if invalid
					if(preamp_rdata != 8'h20) begin
						gain_state	<= 7;
					end
					
					//no, all good
					else begin
						preamp_wr		<= 1;
						preamp_reg		<= 2;
						preamp_wdata	<= 0;
						gain_state		<= 3;
					end
					
				end
			end
			
			//Set the gain
			3: begin
				if(preamp_done) begin
					preamp_wr		<= 1;
					preamp_reg		<= 3;
					preamp_wdata	<= 8'h10;	//4 dB attenuation
												//gain = 26 - 4 = 22 dB
					
					gain_state		<= 4;
				end
			end
			
			//Move on depending on our channel
			4: begin
				if(preamp_done) begin
					if(preamp_chan == 3)
						gain_state		<= 5;
					else begin
						preamp_chan		<= preamp_chan + 2'h1;
						gain_state		<= 1;
					end
				end
			end
		
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// DAC driver - set reference voltage based on RPC message content
	
	reg[3:0] state = 0;
	reg[3:0] count = 0;
	
	always @(posedge clk) begin
		
		rpc_fab_rx_done		<= 0;
		dac_shift_en		<= 0;
		pulse_gen_en		<= pulse_gen_en_adv;
		pulse_gen_en_adv	<= 0;
		
		case(state)
		
			//Wait for a new message to come in
			0: begin
				if(rpc_fab_rx_en) begin
					host_address	<= rpc_fab_rx_src_addr;
					state			<= 1;
					dac_voltage		<= 1664;
				end
			end
			
			//Update the DAC
			1: begin
				dac_spi_cs_n	<= 0;
				count			<= count + 4'h1;
				if(count == 4'hf)
					state			<= 2;
			end
			
			2: begin
				dac_tx_data		<= {4'b0100, dac_voltage[11:8]};
				dac_shift_en	<= 1;
				state			<= 3;
			end
			
			3: begin
				if(dac_shift_done) begin
					dac_tx_data		<= dac_voltage[7:0];
					dac_shift_en	<= 1;
					state			<= 4;
				end
			end
			
			4: begin
				if(dac_shift_done)
					state			<= 5;
			end
			
			5: begin			
				count	<= count + 4'h1;
				if(count == 4'hf) begin
					state			<= 6;
					dac_spi_cs_n	<= 1;
				end
			end
			
			6: begin
				count	<= count + 4'h1;
				if(count == 4'hf) begin
					pulse_gen_en_adv	<= 1;
					state				<= 7;
				end
			end
			
			//Wait for the DMA message to be done sending
			7: begin
				if(dtx_en)
					state				<= 8;
			end
			8: begin
				if(!dtx_busy) begin
					
					//Full scale? Done, wait for another RPC
					if(dac_voltage == 2431) begin
						rpc_fab_rx_done		<= 1;
						state				<= 0;
					end
					
					//Not full scale... bump voltage and try again
					else begin
						dac_voltage			<= dac_voltage + 12'h1;
						state				<= 1;
					end
					
				end
			end
					
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// LED driver
	
	//Right is always off
	//Left is on once per scan
	
	reg[22:0] ledcount = 0;
	always @(posedge clk) begin
	
		tdr_leds[1] <= 0;
	
		if(ledcount)
			ledcount	<= ledcount + 23'h1;
		else
			tdr_leds[0]	<= 0;
	
		if(rpc_fab_rx_en) begin
			tdr_leds[0]	<= 1;
			ledcount	<= 1;
		end
	
	end
	
endmodule

