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
	@brief Ethernet MAC address table
	
	--------------------------------------------------------------------------------------------------------------------
	LOOKUP INTERFACE
	--------------------------------------------------------------------------------------------------------------------
	
	When a new frame arrives, bring new_frame high for one cycle with src_mac, src_port, dst_mac set appropriately.
	
	8 clocks later, lookup_done will go high.
	* If lookup_hit is true then dst_port is the port number of that MAC.
	* Otherwise, the address is either an unknown unicast or a multicast. In either case, send it to everything
	
	--------------------------------------------------------------------------------------------------------------------
	MANAGEMENT INTERFACE
	--------------------------------------------------------------------------------------------------------------------
	
	Assert mgmt_en for one cycle with mgmt_op set to the desired operation.
	
	MACTBL_OP_FLUSH:
		Inputs: mgmt_inport
		Removes all MACs in the table belonging to the requested port
	
	MACTBL_OP_PORTDUMP:
		Inputs: mgmt_inport
		Returns the MAC address table for the requested port number.
		The order is dependent on internal hashing and should not be assumed to be deterministic.
		
		For each address, mgmt_outvalid will go high for one cycle indicating that mgmt_outmac is valid.
		Returned addresses are sorted by the last octet of the MAC address.
		
	MACTBL_OP_GC:
		Removes all MACs in the table which were not used since the last MACTBL_OP_GC operation.
		Should be issued at regular intervals by control logic.
	
	--------------------------------------------------------------------------------------------------------------------
	PERFORMANCE
	--------------------------------------------------------------------------------------------------------------------
	
	Throughput: 3 clk_250mhz cycles per lookup (83.3 Mpps)
	
	Latency:
		* 8 cycles (32 ns) from new_frame to lookup_done
		* FIXME cycles (FIXME ns) from new_frame until a lookup will return "hit" to a newly added MAC
	
	Required throughput is:
	* 2 Mpps per 1G link
	* 20 Mpps per 10G link
	
	This means we can handle up to 41.6 Gbps of traffic with minimum-size packets.
	
	--------------------------------------------------------------------------------------------------------------------
	THEORY OF OPERATION
	--------------------------------------------------------------------------------------------------------------------
		
	Hash block takes 1 cycles before memory block
		
	Timeline for memory operations
		Cycle		PA				PB				PC				PD		
		0			read src[0]		read src[1]		read src[2]		read src[3]
		1			read dst[0]		read dst[1]		read dst[2]		read dst[3]
		2			x				x				x				x
		
	The "x" operation can be one of the following:
	* processing inserts (top priority)
	* management traffic (including GC)
 */
module EthernetMACTable(
	clk_250mhz,
	
	new_frame, src_mac, src_port, src_vlan, dst_mac,
	lookup_done, lookup_hit, dst_port,
	
	mgmt_en, mgmt_op, mgmt_done,
	mgmt_inport, /* mgmt_inmac,*/
	mgmt_outvalid, mgmt_outmac, mgmt_outport, mgmt_outvlan
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Parameter declarations
	
	//TODO: make port ID width parameterizable? Can't imagine needing >256 ports on switching for a home LAN
	
	parameter NUM_SETS		= 256;
	
	localparam MACS_PER_SET	= 4;		//must be constant, just named for convenience
	
	//Total depth of the memory
	localparam MEM_DEPTH	= NUM_SETS*MACS_PER_SET;
	
	//Number of bits in an set ID
	`include "../util/clog2.vh"
	localparam SET_BITS		= clog2(NUM_SETS);
	localparam INDEX_BITS	= clog2(MACS_PER_SET);
	localparam ADDR_BITS	= SET_BITS + INDEX_BITS;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// I/O declarations
	
	input wire clk_250mhz;
			
	input wire			new_frame;
	input wire[47:0]	src_mac;
	input wire[7:0]		src_port;
	input wire[11:0]	src_vlan;
	input wire[47:0]	dst_mac;
	
	output reg			lookup_done	= 0;
	output reg			lookup_hit	= 0;
	output reg[7:0]		dst_port	= 0;
	
	input wire			mgmt_en;
	input wire[1:0]		mgmt_op;
	output reg			mgmt_done		= 0;
	input wire[7:0]		mgmt_inport;
	//input wire[47:0]	mgmt_inmac;
	output reg			mgmt_outvalid	= 0;
	output reg[47:0]	mgmt_outmac		= 0;
	output reg[7:0]		mgmt_outport	= 0;
	output reg[11:0]	mgmt_outvlan	= 0;
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Management interface hash calculation (TODO)
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Input hash calculation
		
	wire[15:0]			src_hash_raw;
	wire[SET_BITS-1:0]	src_hash		= src_hash_raw[SET_BITS-1:0];
	CRC16Hasher src_hasher(
		.clk(clk_250mhz),
		.din({4'h0, src_vlan, src_mac}),
		.clear(1'b1),		//clear CRC state across inputs
		.crc(src_hash_raw)
		);
		
	wire[15:0]			dst_hash_raw;
	wire[SET_BITS-1:0]	dst_hash		= dst_hash_raw[SET_BITS-1:0];
	CRC16Hasher dst_hasher(
		.clk(clk_250mhz),
		.din({4'h0, src_vlan, dst_mac}),
		.clear(1'b1),		//clear CRC state across inputs
		.crc(dst_hash_raw)
		);
		
	//Push everything down the pipe for a clock during CRC calculation
	reg			new_frame_posthash	= 0;
	reg[47:0]	src_mac_posthash	= 0;
	reg[7:0]	src_port_posthash	= 0;
	reg[11:0]	src_vlan_posthash	= 0;
	reg[47:0]	dst_mac_posthash	= 0;
	always @(posedge clk_250mhz) begin
		new_frame_posthash	<= new_frame;
		src_mac_posthash	<= src_mac;
		src_port_posthash	<= src_port;
		src_vlan_posthash	<= src_vlan;
		dst_mac_posthash	<= dst_mac;
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// The RAM

	//71:70		Reserved
	//69:58		VLAN number
	//57		GC mark bit
	//56		Valid bit
	//55:48		Port number
	//47:0		MAC address for tag comparisons
	
	//Shared write data
	reg					p_wvalid	= 0;
	reg[7:0]			p_wport		= 0;
	reg[47:0]			p_wmac		= 0;
	reg					p_wgcmark	= 0;
	reg[11:0]			p_wvlan		= 0;
	
	//Shared flags
	reg					p_en		= 0;
	reg					p_wr		= 0;
	
	//High buffer address (set ID) is always the same, low (word ID) can vary across banks
	reg[SET_BITS-1:0]	p_addr_hi	= 0;
	reg[INDEX_BITS-1:0]	p_addr_lo[3:0];
	
	//Address init
	integer i;
	initial begin
		for(i=0; i<4; i=i+1)
			p_addr_lo[i]	<= 0;
	end
	
	//Outputs
	wire[71:0]			p_dout[3:0];
	wire[3:0]			p_rgcmark;
	wire[3:0]			p_rvalid;
	wire[7:0]			p_rport[3:0];
	wire[47:0]			p_rmac[3:0];
	wire[11:0]			p_rvlan[3:0];
	
	//Unpack bitfields
	genvar g;
	generate
		for(g=0; g<4; g=g+1) begin : unpacking
			assign p_rvlan[g]	= p_dout[g][69:58];
			assign p_rgcmark[g]	= p_dout[g][57];
			assign p_rvalid[g]	= p_dout[g][56];
			assign p_rport[g]	= p_dout[g][55:48];
			assign p_rmac[g]	= p_dout[g][47:0];
		end
	endgenerate
	
	MemoryMacro #(
		.WIDTH(72),
		.DEPTH(MEM_DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.OUT_REG(2),
		.INIT_VALUE(0)
	) mac_table1 (
		
		//WRITE port
		.porta_clk(clk_250mhz),
		.porta_en(p_en),
		.porta_addr({p_addr_hi, p_addr_lo[0]}),
		.porta_we(p_wr),
		.porta_din({2'b0, p_wvlan, p_wgcmark, p_wvalid, p_wport, p_wmac}),
		.porta_dout(p_dout[0]),
		
		//READ port
		.portb_clk(clk_250mhz),
		.portb_en(p_en),
		.portb_addr({p_addr_hi, p_addr_lo[1]}),
		.portb_we(1'b0),
		.portb_din(72'h0),
		.portb_dout(p_dout[1])
	);
	
	MemoryMacro #(
		.WIDTH(72),
		.DEPTH(MEM_DEPTH),
		.DUAL_PORT(1),
		.TRUE_DUAL(0),
		.OUT_REG(2),
		.INIT_VALUE(0)
	) mac_table2 (
		
		//WRITE port
		.porta_clk(clk_250mhz),
		.porta_en(p_en),
		.porta_addr({p_addr_hi, p_addr_lo[2]}),
		.porta_we(p_wr),
		.porta_din({2'b0, p_wvlan, p_wgcmark, p_wvalid, p_wport, p_wmac}),
		.porta_dout(p_dout[2]),
		
		//READ port
		.portb_clk(clk_250mhz),
		.portb_en(p_en),
		.portb_addr({p_addr_hi, p_addr_lo[3]}),
		.portb_we(1'b0),
		.portb_din(72'h0),
		.portb_dout(p_dout[3])
	);
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Register input data
	
	//Note that register counts are relative to _posthash
	
	reg			new_frame_ff	= 0;
	
	reg[47:0]	src_mac_ff		= 0;
	reg[7:0]	src_port_ff		= 0;
	reg[47:0]	dst_mac_ff		= 0;
	reg[11:0]	src_vlan_ff		= 0;
	reg[SET_BITS-1:0]	src_hash_ff		= 0;
	
	reg[47:0]	src_mac_ff2		= 0;
	reg[7:0]	src_port_ff2	= 0;
	reg[47:0]	dst_mac_ff2		= 0;
	reg[11:0]	src_vlan_ff2	= 0;
	reg[SET_BITS-1:0]	src_hash_ff2	= 0;
	
	always @(posedge clk_250mhz) begin
	
		new_frame_ff		<= new_frame_posthash;
	
		if(new_frame_posthash) begin
			src_mac_ff		<= src_mac_posthash;
			src_port_ff		<= src_port_posthash;
			src_vlan_ff		<= src_vlan_posthash;
			dst_mac_ff		<= dst_mac_posthash;
			src_hash_ff		<= src_hash;
		end
		
		if(new_frame_ff) begin
			src_mac_ff2		<= src_mac_ff;
			src_port_ff2	<= src_port_ff;
			src_vlan_ff2	<= src_vlan_ff;
			dst_mac_ff2		<= dst_mac_ff;
			src_hash_ff2	<= src_hash_ff;
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// LFSR for cache eviction selector
	
	reg[31:0]	lfsr		= 1;
	always @(posedge clk_250mhz) begin
		lfsr <=
		{
			lfsr[30:0],
			lfsr[31] ^ lfsr[6] ^ lfsr[4] ^ lfsr[2] ^ lfsr[1] ^ lfsr[0]
		};
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Management state machine
	
	`include "EthernetMACTable_opcodes_constants.v"
	
	localparam		MGMT_STATE_IDLE		= 0;
	localparam		MGMT_STATE_DUMP_0	= 1;
	localparam		MGMT_STATE_NEXT		= 2;
	localparam		MGMT_STATE_MEMSEND	= 3;
	localparam		MGMT_STATE_FLUSH_0	= 4;
	localparam		MGMT_STATE_FLUSH_1	= 5;
	localparam		MGMT_STATE_GC_0		= 6;
	localparam		MGMT_STATE_GC_1		= 7;
	
	reg[2:0] 			mgmt_state		= MGMT_STATE_IDLE;
	reg[2:0]			mgmt_next_state = MGMT_STATE_IDLE;
	
	//Requests going to the main memory state machine
	reg					mgmt_mem_en			= 0;
	reg[ADDR_BITS-1:0]	mgmt_mem_addr		= 0;
	reg					mgmt_mem_done		= 0;
	reg					mgmt_mem_done_ff	= 0;
	reg					mgmt_mem_done_ff2	= 0;
	reg					mgmt_mem_done_ff3	= 0;
	reg					mgmt_mem_wr			= 0;
	reg					mgmt_mem_valid		= 0;
	reg[7:0]			mgmt_mem_port		= 0;
	reg[47:0]			mgmt_mem_mac		= 0;
	reg					mgmt_mem_gcmark		= 0;
	reg[11:0]			mgmt_mem_vlan		= 0;
	
	//Keep track of which sets need to be flushed
	reg[1:0]			mgmt_ports_to_flush	= 0;
	
	//Saved state
	reg[7:0]			mgmt_inport_ff		= 0;
	reg[11:0]			mgmt_invlan_ff		= 0;
	
	//Helper to indicate which ports are valid
	reg[3:0]			mgmt_port_match		= 0;
	reg[3:0]			mgmt_port_match_ff	= 0;
	always @(*) begin
		for(i=0; i<4; i=i+1) begin
			mgmt_port_match[i]	<=
				(mgmt_inport_ff == p_rport[i]) && 
				((mgmt_invlan_ff == p_rvlan[i]) || (mgmt_invlan_ff == 0) ) &&
				p_rvalid[i];
		end
	end
	
	//Port counter for internal debugging
	reg[1:0]			mgmt_count			= 0;
	
	always @(posedge clk_250mhz) begin
		
		mgmt_done	<= 0;
		
		mgmt_port_match_ff	<= mgmt_port_match;
		
		mgmt_mem_done_ff	<= mgmt_mem_done;
		mgmt_mem_done_ff2	<= mgmt_mem_done_ff;
		mgmt_mem_done_ff3	<= mgmt_mem_done_ff2;
		
		mgmt_outvalid		<= 0;
		
		if(mgmt_mem_done) begin
			mgmt_mem_wr		<= 0;
			mgmt_mem_en		<= 0;
		end
		
		case(mgmt_state)
		
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Wait for something to happen
			MGMT_STATE_IDLE: begin
			
				//Do stuff if a new command comes in
				if(mgmt_en) begin
					
					//TODO: add mgmt_invlan to allow filtering by vlan number
					mgmt_inport_ff	<= mgmt_inport;
					mgmt_invlan_ff	<= 0; //mgmt_invlan;
					mgmt_count		<= 0;
					mgmt_mem_wr		<= 0;
				
					mgmt_mem_en		<= 1;
					mgmt_mem_addr	<= 0;
					
					case(mgmt_op)
					
						//Delete all MACs on the port
						MACTBL_OP_FLUSH:	mgmt_state		<= MGMT_STATE_FLUSH_0;
												
						//List all MACs on the port
						MACTBL_OP_PORTDUMP: mgmt_state		<= MGMT_STATE_DUMP_0;
						
						//Delete all MACs which lack the GC mark
						MACTBL_OP_GC: 		mgmt_state		<= MGMT_STATE_GC_0;

					endcase
				
				end
			
			end	//end MGMT_STATE_IDLE
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Print cache contents for a given port
			
			MGMT_STATE_DUMP_0: begin
			
				//Save memory results when they're ready
				if(mgmt_mem_done_ff2) begin
					mgmt_outvlan		<= p_rvlan[mgmt_count];
					mgmt_outmac			<= p_rmac[mgmt_count];
				end
			
				//First mem operation is done
				if(mgmt_mem_done_ff3) begin
					
					//Update output regardless of hit/miss status to shorten the critical path
					mgmt_outport		<= mgmt_inport_ff;
						
					//If the current port matched, print output
					mgmt_outvalid		<= mgmt_port_match_ff[mgmt_count];
					
					//Time to look at the next cache slot
					mgmt_count			<= mgmt_count + 1'h1;
					
					//Wherever we go, come back here when it's done
					mgmt_next_state		<= MGMT_STATE_DUMP_0;
					
					//In any case, if we just processed the last port, move on
					if(mgmt_count == 3)
						mgmt_state		<= MGMT_STATE_NEXT;
					
					//Otherwise, skip the increment and re-read the same port with a new index
					else
						mgmt_state		<= MGMT_STATE_MEMSEND;
					
				end
			
			end	//end MGMT_STATE_DUMP_0
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Cache flush for a given port
			
			MGMT_STATE_FLUSH_0: begin
			
				//First mem operation is done
				if(mgmt_mem_done_ff3) begin
					
					//Time to look at the next cache slot
					mgmt_count			<= mgmt_count + 1'h1;

					//Prepare to dispatch an erase operation
					mgmt_mem_port		<= 0;
					mgmt_mem_mac		<= 0;
					mgmt_mem_valid		<= 0;
					mgmt_mem_gcmark		<= 0;
					mgmt_mem_vlan		<= 0;
					mgmt_mem_addr[1:0]	<= mgmt_count;
					
					mgmt_mem_wr			<= 1;
						
					//If it matches the target port number, queue an erase operation
					mgmt_mem_en			<= mgmt_port_match_ff[mgmt_count];
					
					mgmt_state			<= MGMT_STATE_FLUSH_1;
					
				end
			
			end	//end MGMT_STATE_FLUSH_0

			//Wait for the erase operation to finish
			MGMT_STATE_FLUSH_1: begin
	
				if(mgmt_mem_done || !mgmt_mem_en) begin
					
					mgmt_mem_wr		<= 0;
					
					mgmt_next_state	<= MGMT_STATE_FLUSH_0;
					
					//If we just processed the last entry (and mgmt_count wrapped), move on
					if(mgmt_count == 0)
						mgmt_state		<= MGMT_STATE_NEXT;
					
					//Otherwise, skip the increment and re-read the same entry with a new index
					else
						mgmt_state		<= MGMT_STATE_MEMSEND;
						
				end
					
			end	//end MGMT_STATE_FLUSH_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Cache flush for a given port
			
			MGMT_STATE_GC_0: begin
			
				//First mem operation is done
				if(mgmt_mem_done_ff2) begin
					
					//Time to look at the next cache slot
					mgmt_count			<= mgmt_count + 1'h1;

					//Push the existing values down the pipe for now
					mgmt_mem_port		<= p_rport[mgmt_count];
					mgmt_mem_mac		<= p_rmac[mgmt_count];
					mgmt_mem_valid		<= p_rvalid[mgmt_count];
					mgmt_mem_vlan		<= p_rvlan[mgmt_count];
					mgmt_mem_gcmark		<= 0;	//clear the GC flag
					mgmt_mem_addr[1:0]	<= mgmt_count;
					
					//default to not writing
					mgmt_mem_en			<= 1;
					mgmt_mem_wr			<= 0;
					
					//If GC mark is set, clear it
					if(p_rgcmark[mgmt_count] && p_rvalid[mgmt_count]) begin
					
						mgmt_mem_wr			<= 1;
						
						//synthesis translate_off
						$display("    clearing GC mark for %02x:%02x:%02x:%02x:%02x:%02x vlan %d on port %d set %d",
							p_rmac[mgmt_count][47:40], p_rmac[mgmt_count][39:32], p_rmac[mgmt_count][31:24],
							p_rmac[mgmt_count][23:16], p_rmac[mgmt_count][15:8], p_rmac[mgmt_count][7:0],
							p_rvlan[mgmt_count],
							p_rport[mgmt_count],
							mgmt_count);
						//synthesis translate_on
							
					end
					
					//GC mark is *not* set - time to get rid of this address
					else if(p_rvalid[mgmt_count]) begin
					
						mgmt_mem_wr			<= 1;
						mgmt_mem_valid		<= 0;
					
						//synthesis translate_off
						$display("    GC-ing address       %02x:%02x:%02x:%02x:%02x:%02x vlan %d on port %d set %d",
							p_rmac[mgmt_count][47:40], p_rmac[mgmt_count][39:32], p_rmac[mgmt_count][31:24],
							p_rmac[mgmt_count][23:16], p_rmac[mgmt_count][15:8], p_rmac[mgmt_count][7:0],
							p_rvlan[mgmt_count],
							p_rport[mgmt_count],
							mgmt_count);
						//synthesis translate_on
					
					end

					mgmt_state			<= MGMT_STATE_GC_1;
					
				end
			
			end	//end MGMT_STATE_GC_0

			//Wait for the erase operation to finish
			MGMT_STATE_GC_1: begin
	
				if(mgmt_mem_done_ff2 || !mgmt_mem_en) begin
					
					mgmt_next_state	<= MGMT_STATE_GC_0;
					
					//If we just processed the last entry (and mgmt_count wrapped), move on
					if(mgmt_count == 0)
						mgmt_state		<= MGMT_STATE_NEXT;
					
					//Otherwise, skip the increment and re-read the same entry with a new index
					else
						mgmt_state		<= MGMT_STATE_MEMSEND;
						
				end
					
			end	//end MGMT_STATE_GC_1
			
			////////////////////////////////////////////////////////////////////////////////////////////////////////////
			// Helper states
			
			//Bump address and move on
			MGMT_STATE_NEXT: begin
			
				//End of search?
				if(mgmt_mem_addr[ADDR_BITS-1:INDEX_BITS] == {SET_BITS{1'h1}}) begin
					mgmt_done		<= 1;
					mgmt_state		<= MGMT_STATE_IDLE;
				end
				
				//No, another address is ready to read
				else begin
					mgmt_mem_addr	<= {mgmt_mem_addr[ADDR_BITS-1 : INDEX_BITS] + 1'h1, 2'b0};
					mgmt_state		<= MGMT_STATE_MEMSEND;
				end
				
			end	//end MGMT_STATE_NEXT
			
			//Dispatch the read
			MGMT_STATE_MEMSEND: begin
				mgmt_mem_en		<= 1;
				mgmt_state		<= mgmt_next_state;
			end	//end MGMT_STATE_MEMSEND
			
		endcase
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Tag checking
	
	//Compare upper bits of tag and check if they're good
	reg[3:0]	src_hit = 0;
	reg[3:0]	dst_hit = 0;
	
	//Push status bits down the pipe
	reg[3:0]	src_valid	= 0;
	reg[3:0]	src_gcmark	= 0;
	reg[7:0]	p_rport_ff[3:0];
	
	initial begin
		for(i=0; i<4; i=i+1)
			p_rport_ff[i] <= 0;
	end
	
	//Check if we hit anywhere
	wire			src_hit_any	= (src_hit != 0);
	
	always @(posedge clk_250mhz) begin
	
		src_valid	<= p_rvalid;
		src_gcmark	<= p_rgcmark;
		
		for(i=0; i<4; i=i+1) begin
			src_hit[i]	<= (src_mac_ff2 == p_rmac[i]) && (src_vlan_ff2 == p_rvlan[i]) && p_rvalid[i];
			dst_hit[i]	<= (dst_mac_ff2 == p_rmac[i]) && (src_vlan_ff2 == p_rvlan[i]) && p_rvalid[i];
			
			p_rport_ff[i]	<= p_rport[i];
		end
		
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// RAM address controls
	
	reg[1:0]	state	= 0;
	
	reg			writeback_en	= 0;
	reg			writeback_done	= 0;
	reg[47:0]	writeback_mac	= 0;
	reg[7:0]	writeback_port	= 0;
	reg[1:0]	writeback_index	= 0;
	reg[11:0]	writeback_vlan	= 0;
	
	//now using FFs to deal with BRAM setup time
	always @(posedge clk_250mhz) begin
	
		p_en		<= 0;
		p_wr		<= 0;
		
		//Default: use management data
		p_wmac		<= mgmt_mem_mac;
		p_wport		<= mgmt_mem_port;
		p_wvalid	<= mgmt_mem_valid;
		p_wgcmark	<= mgmt_mem_gcmark;
		p_wvlan		<= mgmt_mem_vlan;
		
		//Default: use management address
		p_addr_hi	<= mgmt_mem_addr[ADDR_BITS-1:INDEX_BITS];
		
		//Default: low bits are a spread of all words
		for(i=0; i<4; i=i+1)
			p_addr_lo[i]	<= i[1:0];
		
		writeback_done	<= 0;
		mgmt_mem_done	<= 0;
		
		case(state)
		
			//Read source MAC entry from table
			0: begin
				p_addr_hi	<= src_hash;
				p_en		<= new_frame_posthash;
				
				/*
				if(new_frame_posthash) begin
					$display("        Looking up source addr %02x:%02x:%02x:%02x:%02x:%02x at hash %x",
						src_mac_posthash[47:40], src_mac_posthash[39:32], src_mac_posthash[31:24],
						src_mac_posthash[23:16], src_mac_posthash[15:8], src_mac_posthash[7:0],
						src_hash);
				end
				*/
				
			end
			
			//Read dest MAC entry from table
			1:  begin
				p_addr_hi	<= dst_hash;
				p_en		<= 1;
				
				/*
				$display("        Looking up dest addr %02x:%02x:%02x:%02x:%02x:%02x at hash %x",
						dst_mac_posthash[47:40], dst_mac_posthash[39:32], dst_mac_posthash[31:24],
						dst_mac_posthash[23:16], dst_mac_posthash[15:8], dst_mac_posthash[7:0],
						dst_hash);
				*/
			end
			
			//Fancy stuff happens here
			//This is really state 2, but 3 is a legal don't care to make the optimizer's job easier
			default: begin
			
				writeback_done	<= writeback_en;
				
				//Default to management stuff
			
				//Writeback logic
				//MUST be handled as first priority to avoid losing data if we have two inserts come back to back
				if(writeback_en) begin

					//synthesis translate_off
					$display("    Writeback: %02x:%02x:%02x:%02x:%02x:%02x to port %d vlan %d (hash %x set %d)",
						writeback_mac[47:40], writeback_mac[39:32], writeback_mac[31:24],
						writeback_mac[23:16], writeback_mac[15:8], writeback_mac[7:0],
						writeback_port,
						writeback_vlan,
						writeback_hash,
						writeback_index);
					//synthesis translate_on

					p_en			<= 1;
					p_wr			<= 1;
					
					p_addr_hi		<= writeback_hash;
					
					for(i=0; i<4; i=i+1)
						p_addr_lo[i]	<= writeback_index;
					
					p_wport			<= writeback_port;
					p_wvalid		<= 1;
					p_wgcmark		<= 1;					//any time we do writeback, set the GC mark
					p_wmac			<= writeback_mac;
					p_wvlan			<= writeback_vlan;
				
				end
				
				//Stuff for the management interface
				else if(mgmt_mem_en) begin

					p_en			<= 1;
					p_wr			<= mgmt_mem_wr;
					
					//use default mgmt address
					
					//synthesis translate_off
					if(mgmt_mem_wr) begin
						if(mgmt_mem_valid) begin
							$display("        Mgmt writeback of    %02x:%02x:%02x:%02x:%02x:%02x to port %d set %d vlan %d gc %d",
								mgmt_mem_mac[47:40], mgmt_mem_mac[39:32], mgmt_mem_mac[31:24],
								mgmt_mem_mac[23:16], mgmt_mem_mac[15:8], mgmt_mem_mac[7:0],
								mgmt_mem_port,
								mgmt_mem_addr[1:0],
								mgmt_mem_vlan,
								mgmt_mem_gcmark);
						end
						
						else begin
							$display("        Mgmt erase of row %x set %d",
								mgmt_mem_addr[ADDR_BITS-1:INDEX_BITS],
								mgmt_mem_addr[1:0]);
						end
					end
					else begin
						/*
						$display("        Mgmt read of row %x set %d",
								mgmt_mem_addr[ADDR_BITS-1:INDEX_BITS],
								mgmt_mem_addr[1:0]);
						*/
					end
					//synthesis translate_on
					
					//If writing, write only to the selected row
					if(mgmt_mem_wr) begin
						p_addr_lo[0]	<= mgmt_mem_addr[INDEX_BITS-1:0];
						p_addr_lo[2]	<= mgmt_mem_addr[INDEX_BITS-1:0];
					end
					
					mgmt_mem_done	<= 1;
				
				end
				
			end
			
		endcase
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// State counter
	
	reg[1:0]		state_ff	= 0;
	reg[1:0]		state_ff2	= 0;
	reg[1:0]		state_ff3	= 0;
	reg				wb_only		= 0;
	reg				wb_only_ff	= 0;
	reg				wb_only_ff2	= 0;
	reg				wb_only_ff3	= 0;
	
	always @(posedge clk_250mhz) begin
	
		//Clear flags
		wb_only		<= 0;
	
		//Save status
		state_ff	<= state;
		state_ff2	<= state_ff;
		state_ff3	<= state_ff2;
		wb_only_ff	<= wb_only;
		wb_only_ff2	<= wb_only_ff;
		wb_only_ff3	<= wb_only_ff2;
		
		//Advance to next state
		case(state)
			1:	state <= 2;
			2:	state <= 0;
		endcase
		
		//Move to new states as necessary
		if(new_frame_posthash)
			state	<= 1;
			
		//If we have non-packet traffic to handle, jump directly to state 2 UNLESS we have a new frame coming in
		//If there's a new frame then just wait 2 clocks and we can write back in the gap there
		//Need to remember this was special stuff, not done in the delay slot of a packet transaction
		if( (state == 0) && (writeback_en || mgmt_mem_en) && !new_frame_posthash ) begin
			wb_only	<= 1;
			state	<= 2;
		end
					
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Determine if we need to do a writeback (1 cycle after state 2 ends)
	
	reg			writeback_done_ff	= 0;
	reg[1:0]	writeback_index_ff	= 0;
	reg			writeback_macmatch	= 0;
	reg			writeback_setmatch	= 0;
	reg[7:0]	writeback_hash		= 0;
	
	always @(posedge clk_250mhz) begin
	
		//Forwarding for the most recent writeback
		writeback_done_ff		<= writeback_done;
		if(writeback_done) begin
			writeback_index_ff	<= writeback_index;
			writeback_macmatch	<= (writeback_mac == src_mac_ff);
		end
	
		if(writeback_done)
			writeback_en	<= 0;
		
		//TODO: need to redo this part to handle the hash
		//maybe add writeback_hash variable
		
		//Update set-match flag one cycle early
		if(state_ff == 2) begin
			writeback_setmatch	<= (writeback_hash == src_hash_ff);
		end
	
		//Don't need to do a writeback if we're not actually processing a packet
		if( (state_ff2 == 2) && !wb_only_ff2) begin
			
			//Save flags no matter what
			writeback_mac	<= src_mac_ff2;
			writeback_port	<= src_port_ff2;
			writeback_vlan	<= src_vlan_ff2;
			writeback_hash	<= src_hash_ff2;
			
			//Do NOT do writeback if we just did a writeback for this address
			if(writeback_macmatch && writeback_done_ff) begin
			end
			
			//Need to do a writeback if the address isn't in the table, and is a unicast address
			else if(!src_hit_any && !src_mac_ff2[40])
				writeback_en	<= 1;
				
			//If the address IS in the table, we might still have to do a writeback to set the GC mark
			if(src_hit_any) begin
				
				//Was our GC mark not set? Do writeback and set it
				for(i=0; i<4; i=i+1) begin
					
					if(src_hit[i] && !src_gcmark[i]) begin
						writeback_index		<= i;
						writeback_en		<= 1;
						
						//synthesis translate_off
						$display("    Source addr in table but no GC mark, doing writeback to set it");
						//synthesis translate_on
						
					end
					
				end
				
				//TODO: If port number mismatched, do a writeback (and maybe log a warning?)
								
			end
			
			//Write to first empty position in the set, if there is one
			//Forwarding to check if it's already in the table
			else begin
			
				//If all slots are taken, we need to write anyway.
				//Pick one at random (TODO: use oldest, or something?)
				writeback_index	<= lfsr[1:0];
			
				//But if there's a free slot, use that
				for(i=3; i>=0; i=i-1) begin
					if(!src_valid[i] && !(writeback_setmatch && writeback_index_ff == i))
						writeback_index	<= i;
				end
					
			end
			
		end
	
	end
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Update output state (three cycles after state 2 ends)
	
	always @(posedge clk_250mhz) begin
		
		lookup_done	<= 0;
		lookup_hit	<= 0;
		dst_port	<= 0;
		
		//Don't do anything if we just did a writeback without a packet
		if( (state_ff3 == 2) && !wb_only_ff3) begin
		
			lookup_done	<= 1;
			lookup_hit	<= (dst_hit != 0);
		
			//Check all ports for hit
			for(i=0; i<4; i=i+1) begin
				if(dst_hit[i])
					dst_port	<= p_rport_ff[i];
			end
		
		end
		
	end
	
endmodule
