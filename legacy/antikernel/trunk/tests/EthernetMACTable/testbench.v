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
	@brief Testbench for EthernetMACTable
 */

module testbench();

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Oscillator
	
	reg clk_250mhz = 0;
	reg ready = 0;
	initial begin
		#100;
		ready = 1;
	end
	always begin
		#2;
		clk_250mhz = 0;
		#2;
		clk_250mhz = ready;
	end

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The DUT
	
	reg			new_frame	= 0;
	reg[47:0]	src_mac		= 0;
	reg[7:0]	src_port	= 0;
	reg[11:0]	src_vlan	= 1;
	reg[47:0]	dst_mac		= 0;
	
	wire		lookup_done;
	wire		lookup_hit;
	wire[7:0]	dst_port;
	
	`include "EthernetMACTable_opcodes_constants.v"
	reg			mgmt_en		= 0;
	reg[1:0]	mgmt_op		= MACTBL_OP_NOP;
	reg[7:0]	mgmt_inport	= 0;
	//reg[47:0]	mgmt_inmac	= 0;
	wire		mgmt_done;
	wire		mgmt_outvalid;
	wire[47:0]	mgmt_outmac;
	wire[7:0]	mgmt_outport;
	wire[11:0]	mgmt_outvlan;
	
	EthernetMACTable #(
		.NUM_SET(256),
		.AGE_TIMER_MAX(31)		//bump timer every 32 clocks
	) mactable (
		.clk_250mhz(clk_250mhz),
		
		.new_frame(new_frame),
		.src_mac(src_mac),
		.src_vlan(src_vlan),
		.src_port(src_port),
		.dst_mac(dst_mac),
	
		.lookup_done(lookup_done),
		.lookup_hit(lookup_hit),
		.dst_port(dst_port),
		
		.mgmt_en(mgmt_en),
		.mgmt_op(mgmt_op),
		.mgmt_done(mgmt_done),
		.mgmt_inport(mgmt_inport),
		//.mgmt_inmac(mgmt_inmac),
		.mgmt_outvalid(mgmt_outvalid),
		.mgmt_outmac(mgmt_outmac),
		.mgmt_outport(mgmt_outport),
		.mgmt_outvlan(mgmt_outvlan)
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Test logic
	
	reg[15:0] state	= 0;
	reg[3:0] count = 0;
	
	wire[47:0] src_mac_delayed;
	wire[47:0] dst_mac_delayed;
	wire[7:0] src_port_delayed;
	wire[11:0] src_vlan_delayed;
	ShiftRegisterMacro #(
		.WIDTH(116),
		.DEPTH(32)
	) input_delay (
		.clk(clk_250mhz),
		.addr(5'd6),
		.din({src_mac, src_port, src_vlan, dst_mac}),
		.ce(1'b1),
		.dout({src_mac_delayed, src_port_delayed, src_vlan_delayed, dst_mac_delayed})
	);
	
	//Helpers
	task assert_miss();
		input lookup_done;
		input lookup_hit;
		if(!lookup_done || lookup_hit) begin
			$display("ERROR: Lookup should have finished with a miss");
			$finish;
		end
	endtask
	
	task assert_hit();
		input lookup_done;
		input lookup_hit;
		input[7:0] dst_port;
		input[7:0] expected_port;
		if(!lookup_done || !lookup_hit || (dst_port != expected_port) ) begin
			$display("ERROR: Lookup should have finished with a hit to port %d", expected_port);
			$finish;
		end
	endtask
	
	always @(posedge clk_250mhz) begin
	
		new_frame	<= 0;
		
		state		<= state + 1'h1;
		
		mgmt_en		<= 0;
		mgmt_op		<= MACTBL_OP_NOP;
	
		//Print out last two octets of MAC when a write comes in
		if(new_frame) begin
			$display("Lookup: %02x:%02x -> %02x:%02x vlan %2d port %2d",
				src_mac[15:8], src_mac[7:0],
				dst_mac[15:8], dst_mac[7:0],
				src_vlan,
				src_port);
		end
		
		//Print out result when a lookup finishes
		if(lookup_done) begin
			$display("    Complete: %02x:%02x -> %02x:%02x vlan %d port %d: hit=%d, dport=%d (at state %d)",
				src_mac_delayed[15:8], src_mac_delayed[7:0],
				dst_mac_delayed[15:8], dst_mac_delayed[7:0],
				src_vlan_delayed,
				src_port_delayed,
				lookup_hit,
				dst_port,
				state);
		end
	
		case(state)
			
			//Test message going to broadcast
			0: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'hff_ff_ff_ff_ff_ff;
			end
			
			//Wait 2 clocks between lookups
			
			//Another packet came in, also going to broadcast
			3: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_cc_cc_cc_cc_cc;
				src_port	<= 5;
				src_vlan	<= 1;
				dst_mac		<= 48'hff_ff_ff_ff_ff_ff;
			end
			
			//No lookup during this state.
			//While it would be legal to do so at cycle 6
			//we wouldn't see the new MAC yet as the write is still committing
			
			//First lookup is done. Should be a miss
			8: assert_miss(lookup_done, lookup_hit);

			//Second lookup is done. Should be a miss
			11: begin
				assert_miss(lookup_done, lookup_hit);
			
				//Test message going to a known node
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Wait 2 clocks between lookups
			
			14: begin
			
				//Nothing to test here
			
				//Look up the other MAC
				new_frame	<= 1;
				src_mac		<= 48'h02_cc_cc_cc_cc_cc;
				src_port	<= 5;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_01_23_45_67_89;
			
			end
			
			//Wait for writes to commit
			
			19: begin

				//Do a lookup that collides with an existing one, but isn't yet in the table
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cd_cc;

				//Third lookup is done. Should be a hit on port 5
				assert_hit(lookup_done, lookup_hit, dst_port, 5);
				
			end
			
			//Fourth lookup is done. Should be a hit on port 3
			22:	assert_hit(lookup_done, lookup_hit, dst_port, 3);
			
			//Insert the colliding address into the table
			24: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_cc_cc_cc_cd_cc;
				src_port	<= 7;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_01_23_45_67_89;
			end
			
			//Colliding lookup is done. Should be a miss
			27: assert_miss(lookup_done, lookup_hit);
			
			32: begin
				
				//Insertion lookup is done. Should be a hit on port 3.
				assert_hit(lookup_done, lookup_hit, dst_port, 3);
			
				//Look up the colliding address again (this one should hit)
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cd_cc;
			end
			
			//Look up the original address again to make sure we didn't overwrite it
			35: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Add an address to port 3 we can use for flush testing
			38: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_01;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Colliding lookup is done. Should be a hit on port 7
			40: assert_hit(lookup_done, lookup_hit, dst_port, 7);
			
			//Add another address
			41: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_68_01;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Sanity check lookup is done. Should be a hit on port 5
			43:	assert_hit(lookup_done, lookup_hit, dst_port, 5);
			
			//Insertion lookup is done. Should be a hit on port 5
			46: assert_hit(lookup_done, lookup_hit, dst_port, 5);
			
			49: begin
			
				//Insertion lookup is done. Should be a hit on port 5
				assert_hit(lookup_done, lookup_hit, dst_port, 5);
				
				//Look up all MACs on port 3
				$display("Dumping MAC table for port 3...");
				mgmt_en		<= 1;
				mgmt_op		<= MACTBL_OP_PORTDUMP;
				mgmt_inport	<= 3;
				count		<= 0;
			
			end
		
			//Block until the operation is done
			50: begin
			
				if(mgmt_outvalid) begin
					count	<= count + 1;
					
					$display("    %02x:%02x:%02x:%02x:%02x:%02x (vlan %d)",
						mgmt_outmac[47:40],
						mgmt_outmac[39:32],
						mgmt_outmac[31:24],
						mgmt_outmac[23:16],
						mgmt_outmac[15:8],
						mgmt_outmac[7:0],
						mgmt_outvlan
						);
				
					//Verify we got the right MAC
					if(
						( (mgmt_outmac == 48'h02_01_23_45_68_01) && (count == 2) ) ||
						( (mgmt_outmac == 48'h02_01_23_45_67_01) && (count == 1) ) ||
						( (mgmt_outmac == 48'h02_01_23_45_67_89) && (count == 0) )
						) begin
						
						//all good
						
					end
					
					//Bad MAC
					else begin
						$display("FAIL: Got a bad MAC address");
						$finish;
					end	
					
					//Verify they're all on vlan 1
					if(mgmt_outvlan != 1) begin
						$display("FAIL: Got a bad vlan");
						$finish;
					end
					
					//WTF, we tried to dump port 3 and got a MAC for something else! Shouldn't ever happen
					if(mgmt_outport != 3) begin
						$display("FAIL: Should have been on port 3 but got something else");
						$finish;
					end
						
				end
			
				if(!mgmt_done)
					state	<= 50;
			end

			//Sanity check
			51: begin
				$display("    Done (%d addresses total)", count);
				
				if(count != 3) begin
					$display("FAIL: expected 3 addresses");
					$finish;
				end
				
			end
	
			//Delete all MACs from port 3			
			52: begin
				$display("Purging all MACs from port 3");
				mgmt_en		<= 1;
				mgmt_op		<= MACTBL_OP_FLUSH;
				mgmt_inport	<= 3;
			end
			53: begin
				if(!mgmt_done)
					state	<= 53;
				else
					$display("    Done");
			end
			
			//Try reading a MAC that used to be on port 3
			54: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_cc_cc_cc_cc_cc;
				src_port	<= 5;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_01_23_45_67_89;				
			end

			//Verify that other MAC entries weren't screwed with
			57: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Should be a miss, since we flushed the address
			62: assert_miss(lookup_done, lookup_hit);
			
			//Should be a hit on port 5
			65: assert_hit(lookup_done, lookup_hit, dst_port, 5);
				
			//Garbage collect (should not delete anything)
			66: begin
				$display("Garbage collecting...");
				mgmt_en		<= 1;
				mgmt_op		<= MACTBL_OP_GC;
				mgmt_inport	<= 3;
			end
			67: begin
				if(!mgmt_done)
					state	<= 67;
				else
					$display("    Done");
			end
			
			//Read one particular MAC entry to touch the GC mark
			68: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_01_23_45_67_89;
				src_port	<= 3;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Should be a hit on port 5
			76:  assert_hit(lookup_done, lookup_hit, dst_port, 5);
			
			//GC again (should delete all but 67:89)
			77: begin
				$display("Garbage collecting...");
				mgmt_en		<= 1;
				mgmt_op		<= MACTBL_OP_GC;
				mgmt_inport	<= 3;
			end

			78: begin
				if(!mgmt_done)
					state	<= 78;
				else
					$display("    Done");
			end
			
			//Verify cc:cc is not in the table
			79: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_aa_aa_aa_aa_aa;
				src_port	<= 9;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_cc_cc_cc_cc_cc;
			end
			
			//Verify 67:89 is still in the table
			82: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_aa_aa_aa_aa_aa;
				src_port	<= 9;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_01_23_45_67_89;
			end
			
			//Should be a miss, since we flushed the address
			87: assert_miss(lookup_done, lookup_hit);
			
			//Should be a hit on port 3
			90: assert_hit(lookup_done, lookup_hit, dst_port, 3);
			
			//Look up 67:89 on a second vlan
			91: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_aa_aa_aa_aa_cc;
				src_port	<= 14;
				src_vlan	<= 2;
				dst_mac		<= 48'h02_01_23_45_67_89;
			end
			
			//Should be a miss, vlan 2 is empty
			99: assert_miss(lookup_done, lookup_hit);
			
			//Verify aa:cc is now present in vlan 2
			100: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_aa_aa_aa_aa_ee;
				src_port	<= 6;
				src_vlan	<= 2;
				dst_mac		<= 48'h02_aa_aa_aa_aa_cc;
			end
			
			//Verify aa:cc is NOT present in vlan 1
			103: begin
				new_frame	<= 1;
				src_mac		<= 48'h02_aa_aa_aa_aa_aa;
				src_port	<= 9;
				src_vlan	<= 1;
				dst_mac		<= 48'h02_aa_aa_aa_aa_cc;
			end
			
			//aa:cc should be a hit on port 14 in vlan 2
			108: assert_hit(lookup_done, lookup_hit, dst_port, 14);
			
			//aa:cc should be a miss in vlan 1
			111: assert_miss(lookup_done, lookup_hit);

			//TODO: test what happens when an address jumps to another port

			//DONE
			112: begin
				$display("PASS");
				$finish;
			end

		endcase
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Stop the test after 150us and declare fail if we haven't finished yet
	initial begin
		#150000;
		$display("FAIL (timeout)");
		$finish;
	end
	

endmodule
