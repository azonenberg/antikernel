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
	@brief Bridge for hardware co-simulation. Connect to the upstream port of the root NoC router for the simulation side
 */
module CosimBridge(
	clk_noc,
	rpc_tx_en, rpc_tx_data, rpc_tx_ack, rpc_rx_en, rpc_rx_data, rpc_rx_ack//,
	//dma_tx_en, dma_tx_data, dma_tx_ack, dma_rx_en, dma_rx_data, dma_rx_ack,
    );
    
    ////////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations
	
	//Global clock
	input wire clk_noc;
	
	//NoC interface
	input wire rpc_tx_en;
	input wire [31:0] rpc_tx_data;
	output wire[1:0] rpc_tx_ack;
	output wire rpc_rx_en;
	output wire [31:0] rpc_rx_data;
	input wire[1:0] rpc_rx_ack;
	
	/*
	output reg dma_tx_en = 0;
	output reg[31:0] dma_tx_data = 0;
	input wire dma_tx_ack;
	input wire dma_rx_en;
	input wire[31:0] dma_rx_data;
	output reg dma_rx_ack = 0;
	*/
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RPC transceiver
	
	reg			rpc_fab_tx_en 		= 0;
	reg[15:0]	rpc_fab_tx_src_addr	= 0;
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
	
	RPCv2Transceiver #(
		.LEAF_PORT(0)
	) txvr(
		.clk(clk_noc),
		
		//crossover port
		.rpc_tx_en(rpc_rx_en),
		.rpc_tx_data(rpc_rx_data),
		.rpc_tx_ack(rpc_rx_ack),
		
		.rpc_rx_en(rpc_tx_en),
		.rpc_rx_data(rpc_tx_data),
		.rpc_rx_ack(rpc_tx_ack),
		
		.rpc_fab_tx_en(rpc_fab_tx_en),
		.rpc_fab_tx_src_addr(rpc_fab_tx_src_addr),
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
	// RPC bridge
	
	integer wpipe;
	integer rpipe;
	initial begin
	
		wpipe = $fopen("writepipe", "w");
		rpipe = $fopen("readpipe", "r");
		if( (wpipe == 0) || (rpipe == 0) ) begin
			$display("Failed to open pipe, aborting");
			$display("FAIL");
			$finish;
		end

	end
	
	reg[23:0] msgtype = "";
	reg rpc_transmit_active = 0;
	always @(posedge clk_noc) begin
			
		rpc_fab_rx_done <= 0;
		rpc_fab_tx_en <= 0;
		
		if(rpc_fab_tx_done) begin
			rpc_transmit_active <= 0;
		end
			
		//New RPC message has arrived. Send it out the pipe.
		if(rpc_fab_rx_en) begin
			$fdisplay(wpipe, "RPC");
			$fdisplay(wpipe, "%04x", rpc_fab_rx_src_addr);
			$fdisplay(wpipe, "%04x", rpc_fab_rx_dst_addr);
			$fdisplay(wpipe, "%02x", rpc_fab_rx_callnum);
			$fdisplay(wpipe, "%02x", rpc_fab_rx_type);
			$fdisplay(wpipe, "%08x", rpc_fab_rx_d0);
			$fdisplay(wpipe, "%08x", rpc_fab_rx_d1);
			$fdisplay(wpipe, "%08x", rpc_fab_rx_d2);
			rpc_fab_rx_done <= 1;
		end
		
		//See if new RPC messages are available
		//Silly Verilog, only supporting blocking I/O is for... kids?
		else if(!rpc_transmit_active) begin
			//Poll for the data
			$fdisplay(wpipe, "POL");
			$fflush(wpipe);

			//Read message type
			$fscanf(rpipe, "%3s", msgtype[23:0]);
			
			//RPC message, process it
			if(msgtype == "RPC") begin
				$fscanf(rpipe, "%04x", rpc_fab_tx_src_addr);
				$fscanf(rpipe, "%04x", rpc_fab_tx_dst_addr);
				$fscanf(rpipe, "%02x", rpc_fab_tx_callnum);
				$fscanf(rpipe, "%02x", rpc_fab_tx_type);
				$fscanf(rpipe, "%08x", rpc_fab_tx_d0);
				$fscanf(rpipe, "%08x", rpc_fab_tx_d1);
				$fscanf(rpipe, "%08x", rpc_fab_tx_d2);
				rpc_fab_tx_en <= 1;
				rpc_transmit_active <= 1;
			end
			
			//No data ready for us
			else if(msgtype == "NAK") begin
			end
			
			//unknown, abort				
			else begin
				$display("Got gibberish over cosim pipe, aborting");
				$display("FAIL");
				$finish;
			end
		end
		
	end

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Ignore DMA for now
    
endmodule
