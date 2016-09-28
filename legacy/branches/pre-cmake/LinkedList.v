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
	@brief A doubly linked list.
	
	Pointers only, no data. The user may optionally use these pointers as indexes to
	an external data array.
	
	For now, hard coded to 8 bits wide (times two pointers) and 128 entries.
	All values with the high-order bit set are considered NULL.
	
	Operations:
		Push back
			Given a pointer, mark it as the tail of the list and update pointers as necessary
		
		Remove
			Given a pointer, remove it from the list and update node pointers as necessary.
			If it's the head or tail, update the head or tail pointer as necessary.
 */
module LinkedList(
	clk,
	op_en, in_ptr, opcode,
	tail_ptr, head_ptr, busy
    );
	 
	///////////////////////////////////////////////////////////////////////////////////////////////
	// IO / parameter declarations

	input wire clk;

	localparam OP_PUSH_BACK = 0;
	localparam OP_REMOVE = 1;

	input wire op_en;
	input wire[6:0] in_ptr;
	input wire opcode;
	
	localparam NULL_PTR = 8'h80;

	output reg[7:0] tail_ptr = NULL_PTR;
	output reg[7:0] head_ptr = NULL_PTR; 
	 
	output reg busy = 0;

	///////////////////////////////////////////////////////////////////////////////////////////////
	// The actual memory array

	reg prev_ptr_we = 0;
	reg[6:0] prev_ptr_waddr = 0;
	reg[7:0] prev_ptr_in = 0;
	
	reg next_ptr_we = 0;
	reg[6:0] next_ptr_waddr = 0;
	reg[7:0] next_ptr_in = 0;
	
	reg[6:0] ptr_raddr = 0;
	wire[7:0] prev_ptr_out;
	wire[7:0] next_ptr_out;

	LutramMacroDP #(.WIDTH(8), .DEPTH(128)) prev_ptr (
		.clk(clk), 
		.porta_we(prev_ptr_we), 
		.porta_addr(prev_ptr_waddr), 
		.porta_din(prev_ptr_in), 
		.porta_dout(), 
		.portb_addr(ptr_raddr), 
		.portb_dout(prev_ptr_out)
		);
		
	LutramMacroDP #(.WIDTH(8), .DEPTH(128)) next_ptr (
		.clk(clk), 
		.porta_we(next_ptr_we), 
		.porta_addr(next_ptr_waddr), 
		.porta_din(next_ptr_in), 
		.porta_dout(), 
		.portb_addr(ptr_raddr), 
		.portb_dout(next_ptr_out)
		);
		
	///////////////////////////////////////////////////////////////////////////////////////////////
	// Control state machine
	
	localparam STATE_IDLE		= 0;
	localparam STATE_PUSH_2 	= 1;
	localparam STATE_REMOVE_2	= 2;
	
	reg[3:0] state = 0;
	
	always @(posedge clk) begin
	
		next_ptr_we <= 0;
		prev_ptr_we <= 0;
	
		case(state)
			
			//Wait for a request
			STATE_IDLE: begin
				busy <= 0;
				
				if(op_en) begin
					case(opcode)
						
						//Add a new item to the start of the list
						OP_PUSH_BACK: begin
							
							//If list is empty, just create the new list item
							if(head_ptr == NULL_PTR && tail_ptr == NULL_PTR) begin
							
								//head_ptr = tail_ptr = in_ptr
								head_ptr <= in_ptr;
								tail_ptr <= in_ptr;
								
								//in_ptr->next = NULL
								next_ptr_we <= 1;
								next_ptr_waddr <= in_ptr;
								next_ptr_in <= NULL_PTR;
								
								//in_ptr->prev = NULL
								prev_ptr_we <= 1;
								prev_ptr_waddr <= in_ptr;
								prev_ptr_in <= NULL_PTR;
							end
							
							//List not empty, update pointers
							else begin
								
								//tail_ptr->next = in_ptr
								next_ptr_we <= 1;
								next_ptr_waddr <= tail_ptr[6:0];
								next_ptr_in <= in_ptr;
								
								//in_ptr->prev = tail_ptr
								prev_ptr_we <= 1;
								prev_ptr_waddr <= in_ptr[6:0];
								prev_ptr_in <= tail_ptr;
								
								//We still need to set in_ptr->next to NULL
								//but cannot do that just yet because we can only write one next and one prev ptr
								//per clock cycle
								
								//In the meantime, update the tail pointer to our new tail.
								tail_ptr <= in_ptr;
								state <= STATE_PUSH_2;
								busy <= 1;
								
							end
							
						end
						
					OP_REMOVE: begin
						
						//Look up the target node's head and tail pointers
						ptr_raddr <= in_ptr;
						state <= STATE_REMOVE_2;
						busy <= 1;
						
					end
						
					endcase
				end
			end
			
			//Finish a push_back operation
			STATE_PUSH_2: begin
				
				//Null out the new tail pointer
				next_ptr_we <= 1;
				next_ptr_waddr <= tail_ptr[6:0];
				next_ptr_in <= NULL_PTR;
				
				//and we're done
				busy <= 0;
				state <= STATE_IDLE;
				
			end
			
			//Finish a remove operation
			STATE_REMOVE_2: begin
				
				//If the node being removed is the head, set the head to the removed node's next
				if(ptr_raddr == head_ptr)
					head_ptr <= next_ptr_out;
					
				//otherwise we have a node before us, so update its next pointer
				else begin
					next_ptr_we <= 1;
					next_ptr_waddr <= prev_ptr_out[6:0];
					next_ptr_in <= next_ptr_out;
				end
				
				//If the node being removed is the tail, set the tail to the removed node's prev
				if(ptr_raddr == tail_ptr)
					tail_ptr <= prev_ptr_out;
					
				//Otherwise we have a node after us, update its prev ptr
				else begin
					prev_ptr_we <= 1;
					prev_ptr_waddr <= next_ptr_out[6:0];
					prev_ptr_in <= prev_ptr_out;
				end
				
				//And now we're done
				busy <= 0;
				state <= STATE_IDLE;
				
			end
			
		endcase
	end

endmodule
