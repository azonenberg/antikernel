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
	@brief Formal validation test harness for RPCv2Arbiter

	Properties to prove:
		* When not transmitting, tx_en is 0 and selected_sender is 5
		* tx_en goes true for one cycle when all of the below are true:
			* We're idle
			* At least one port has a full inbox
			* Their destination address matches us
		* selected_sender is the index of a port that was sending to us. Make no assumptions about tie-breaking if
		  multiple packets are destined to us.
		* While packet is being transmitted, selected_sender does not change and tx_en stays low
		* When tx_done goes high, return to idle state
 */
module main(
	clk,
	port_rx_en,
	port_addr,
	tx_done);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations

	input wire clk;

	input wire[4:0] port_rx_en;
	input wire[79:0] port_addr;
	input wire tx_done;

	parameter THIS_PORT = 3'h2;
	localparam EXPECTED_ADDRESS = 16'h8000 | THIS_PORT;

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT

	reg[4:0] port_inbox_full	= 0;
	reg[79:0] port_dst_addr		= 0;

	wire tx_en;
	wire[2:0] selected_sender;

	RPCv2Arbiter #(
		.THIS_PORT(THIS_PORT),
		.SUBNET_MASK(16'hfffc),
		.SUBNET_ADDR(16'h8000),
		.HOST_BIT_HIGH(1)
	) uut (
		.clk(clk),
		.port_inbox_full(port_inbox_full),
		.port_dst_addr(port_dst_addr),
		.tx_en(tx_en),
		.tx_done(tx_done),
		.selected_sender(selected_sender)
	);

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test code

	reg[1:0] state = 0;
	
	reg[2:0] expected_selected_sender = 5;

	integer i;

	//Figure out which of the inboxes are directed at us
	reg[4:0] sending_to_us;
	always @(*) begin

		for(i=0; i<5; i=i+1) begin

			sending_to_us[i] <= 0;

			if(	 port_inbox_full[i] &&						//port is valid
				(port_dst_addr[i*16 +: 3] == THIS_PORT) &&	//port match
				(port_dst_addr[i*16 + 3 +: 13] == 13'h1000)	//subnet match
				) begin
				sending_to_us[i] <= 1;
			end

		end

	end

	//Look up the actual address we're trying to send to
	reg[15:0] current_dst_address = 0;
	always @(*) begin
		current_dst_address <= 0;

		for(i=0; i<5; i=i+1) begin
			if(selected_sender == i)
				current_dst_address <= port_dst_addr[i*16 +: 16];
		end

	end

	always @(posedge clk) begin

		//If we just got a message, set the flags
		for(i=0; i<5; i=i+1) begin

			//Write to the address
			if(port_rx_en[i] && !port_inbox_full[i]) begin
				port_inbox_full[i] <= 1;
				port_dst_addr[i*16 +: 16] <= port_addr[i*16 +: 16];
			end

		end

		case(state)

			//Idle
			0: begin
			
				//If someone is sending to us, go to the "sending" state
				if(sending_to_us != 0)
					state <= 1;

				//Should not be sending. Should be reading from nowhere.
				assert(tx_en == 0);
				assert(selected_sender == 5);
			end

			//Should be sending!
			1: begin

				//We should be trying to send
				assert(tx_en == 1);

				//Verify that the selected sender is actually sending to us.
				//Note that we make no assumptions about the arbitration strategy here, since RPCv2Arbiter_NoStarve
				//is responsible for proving fairness. We're only trying to showthat  it picks *a* valid port,
				//where "valid" means:
				// * There is a packet in the buffer
				// * It's addressed to us
				assert(port_inbox_full[selected_sender]);
				assert(current_dst_address == {13'h1000, THIS_PORT[2:0]});
				
				//Keep track of which port was selected. This shouldn't change until the packet is sent.
				expected_selected_sender <= selected_sender;

				//If we get tx_done this cycle, go back to idle.
				//This should never happen in the real system as tx_en was asserted this cycle
				//and the other end presumably doesn't have ESP. We need to demonstrate sane behavior
				//in the formal model, though.
				if(tx_done)
					state <= 0;
					
				//Wait until the packet has been processed.	
				else
					state <= 2;

			end

			//Packet is in progress
			//Wait for the send to complete, then reset
			2: begin
			
				//We should still be sending from the same port
				assert(expected_selected_sender == selected_sender);
				
				//Should not be starting a new packet
				assert(tx_en == 0);

				if(tx_done) begin

					//Inbox is now empty
					port_inbox_full[selected_sender] <= 0;

					//Reset and get ready for the next packet
					state <= 0;

				end

			end

		endcase

	end

endmodule
