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
	@brief Test module for hardware simulation
 */
module CosimTest();

	////////////////////////////////////////////////////////////////////////////////////////////////
	// Clock generation

	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	
	reg clk_noc = 0;
	always begin
		#5;
		clk_noc = ready;
		#5;
		clk_noc = 0;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Debug bridge
	wire bridge_tx_en;
	wire[31:0] bridge_tx_data;
	wire[1:0] bridge_tx_ack;
	wire bridge_rx_en;
	wire[31:0] bridge_rx_data;
	wire[1:0] bridge_rx_ack;
	
	CosimBridge bridge (
		.clk_noc(clk_noc), 
		.rpc_tx_en(bridge_tx_en), 
		.rpc_tx_data(bridge_tx_data), 
		.rpc_tx_ack(bridge_tx_ack), 
		.rpc_rx_en(bridge_rx_en), 
		.rpc_rx_data(bridge_rx_data), 
		.rpc_rx_ack(bridge_rx_ack)//, 
		//.dma_tx_en(dma_tx_en), 
		//.dma_tx_data(dma_tx_data), 
		//.dma_tx_ack(dma_tx_ack), 
		//.dma_rx_en(dma_rx_en), 
		//.dma_rx_data(dma_rx_data), 
		//.dma_rx_ack(dma_rx_ack)
		);
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// The transceiver
	
	wire tx_ready_c;
	reg tx_en = 0;
	reg[31:0] tx_d0 = 0;
	reg[31:0] tx_d1 = 0;
	reg[31:0] tx_d2 = 0;
	reg[15:0] tx_dst_addr = 0;
	
	reg[15:0] ping_addr = 0;
	
	localparam OUR_ADDR = 16'hc000;

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
	
	RPCv2Transceiver #(
		.LEAF_PORT(1),
		.LEAF_ADDR(OUR_ADDR)
	) txvr(
		.clk(clk_noc),
		
		.rpc_tx_en(bridge_tx_en),
		.rpc_tx_data(bridge_tx_data),
		.rpc_tx_ack(bridge_tx_ack),
		
		.rpc_rx_en(bridge_rx_en),
		.rpc_rx_data(bridge_rx_data),
		.rpc_rx_ack(bridge_rx_ack),
		
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
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	// Test state machine
	
	`include "RPCv2Router_type_constants.v"	//Pull in autogenerated constant table
	`include "RPCv2Router_ack_constants.v"
	`include "NOCNameServer_constants.v"
	
	reg[7:0] state = 0;
	always @(posedge clk_noc) begin
		rpc_fab_tx_en <= 0;
		
		case(state)
		
			//Single-cycle startup wait for transceiver to initialize
			0: begin
				state <= 1;
			end
			
			//Query the name server
			1: begin
				$display("Querying name server for rpcping...");
				rpc_fab_tx_en <= 1;
				rpc_fab_tx_dst_addr <= 16'h8000;		//name server
				rpc_fab_tx_type <= RPC_TYPE_CALL;
				rpc_fab_tx_callnum <= NAMESERVER_FQUERY;
				rpc_fab_tx_d0 <= 0;
				rpc_fab_tx_d1 <= "rpcp";
				rpc_fab_tx_d2 <= {"ing", 8'h00};
				state <= 2;
			end
			
			//Wait for data to come back (since they responded, we know the transmit is done)
			2: begin
				if(rpc_fab_rx_en) begin
					
					case(rpc_fab_rx_type)
						
						//Name server is busy? Try again
						RPC_TYPE_RETURN_RETRY: begin
							$display("Name server is busy, retrying...\n");
							state <= 1;
						end
						
						//Success?
						RPC_TYPE_RETURN_SUCCESS: begin
							$display("RPC pinger is at %04x", rpc_fab_rx_d0[15:0]);
							ping_addr <= rpc_fab_rx_d0[15:0];	//save address					
							state <= 3;
						end
						
						default: begin
							$display("NAMESERVER_FQUERY() failed");
							$display("FAIL");
							$finish;
						end
						
					endcase

					rpc_fab_rx_done <= 1;
				end
			end
			
			//Send the echo packet
			3: begin
				$display("Sending first ping packet...");
				rpc_fab_tx_en <= 1;
				rpc_fab_tx_dst_addr <= ping_addr;
				rpc_fab_tx_type <= RPC_TYPE_CALL;
				rpc_fab_tx_callnum <= 8'hcd;
				rpc_fab_tx_d0 <= 21'h1dface;
				rpc_fab_tx_d1 <= 32'hdeadbeef;
				rpc_fab_tx_d2 <= 32'hbaadc0de;
				state <= 4;
			end

			//Wait for it to come back
			4: begin
				if(rpc_fab_rx_en) begin
					$display("    Got response (t = %d)", $time());
					
					if( (rpc_fab_rx_src_addr != ping_addr) || 
						(rpc_fab_rx_dst_addr != OUR_ADDR) || 
						(rpc_fab_rx_type != RPC_TYPE_CALL) ||
						(rpc_fab_rx_callnum != 8'hcd) ||
						(rpc_fab_rx_d0 != 21'h1dface) || 
						(rpc_fab_rx_d1 != 32'hdeadbeef) || 
						(rpc_fab_rx_d2 != 32'hbaadc0de)) begin
						$display("    FAIL: packet mismatch\n");
						$display("    From : %04x", rpc_fab_rx_src_addr);
						$display("    To   : %04x", rpc_fab_rx_dst_addr);
						$display("    Type : %04x", rpc_fab_rx_type);
						$display("    Call : %04x", rpc_fab_rx_callnum);
						$display("    Data0: %08x", rpc_fab_rx_d0);
						$display("    Data1: %08x", rpc_fab_rx_d1);
						$display("    Data2: %08x", rpc_fab_rx_d2);
					end
					else
						$display("    Looks good");
					
					rpc_fab_rx_done <= 1;
					state <= 5;					
				end
			end
			
			//Send a second echo packet
			5: begin
				$display("Sending second ping packet...");
				
				rpc_fab_tx_en <= 1;
				rpc_fab_tx_dst_addr <= ping_addr;
				rpc_fab_tx_type <= RPC_TYPE_CALL;
				rpc_fab_tx_callnum <= 8'hfe;
				rpc_fab_tx_d0 <= 20'hccccc;
				rpc_fab_tx_d1 <= 32'hdddddddd;
				rpc_fab_tx_d2 <= 32'hffffffff;
				state <= 6;
			end
			
			//Wait for it to come back
			6: begin
				if(rpc_fab_rx_en) begin
					$display("    Got response (t = %d)", $time());
					
					if( (rpc_fab_rx_src_addr != ping_addr) || 
						(rpc_fab_rx_dst_addr != OUR_ADDR) || 
						(rpc_fab_rx_type != RPC_TYPE_CALL) ||
						(rpc_fab_rx_callnum != 8'hfe) ||
						(rpc_fab_rx_d0 != 20'hccccc) || 
						(rpc_fab_rx_d1 != 32'hdddddddd) || 
						(rpc_fab_rx_d2 != 32'hffffffff)) begin
						$display("    FAIL: packet mismatch\n");
						$display("    From : %04x", rpc_fab_rx_src_addr);
						$display("    To   : %04x", rpc_fab_rx_dst_addr);
						$display("    Type : %04x", rpc_fab_rx_type);
						$display("    Call : %04x", rpc_fab_rx_callnum);
						$display("    Data0: %08x", rpc_fab_rx_d0);
						$display("    Data1: %08x", rpc_fab_rx_d1);
						$display("    Data2: %08x", rpc_fab_rx_d2);
					end
					else
						$display("    Looks good");
						
					rpc_fab_rx_done <= 1;
					state <= 7;
				end
			end
			
			7: begin
				$display("PASS");
				$finish;
			end
	
		endcase
	end

endmodule
