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
	@brief Low-level RPC API (chip-specific code)
 */

//Friendly names for CPU registers
#include <saratoga/registers.h>

//Syscall numbers etc
#include <SaratogaCPUSyscalls_constants.h>

//REQUIRED for Saratoga since delay slot is never executed
.set noreorder

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RPC stuff

/*
	@brief Sends an RPC message
	
	@param a0		Pointer to a RPCMessage_t object
 */
.globl SendRPCMessage
SendRPCMessage:

	//Load arguments from RAM
	//TODO: Support packed RPC stuff and benchmark the two side by side?
	lw			t0, 4(a0)	//dst addr
	lw			t1, 8(a0)	//callnum
	lw			t2, 12(a0)	//type
	lw			a1, 16(a0)	//d0
	lw			a2, 20(a0)	//d1
	lw			a3, 24(a0)	//d2

	//Pack into registers as necessary
	lui			a0, SYS_SEND_RPC_BLOCKING
	andi		t0, t0, 0xffff	//mask off valid addr bits
	andi		t1, t1, 0xff	//mask off valid callnum bits
	andi		t2, t2, 0x7		//mask off valid type bits
	or			a0, t0			//addr word
	sll			t1, t1, 24		//callnum
	sll			t2, t2, 21		//type
	or			a1, a1, t1		//shifted callnum | d0
	or			a1, a1, t2		//full op word
	
	//Do the actual operation
	syscall
	
	//Done
	jr			ra
	nop

/*
	@brief Receives an RPC message.
	
	Blocks until a message is available.
	
	@param a0		Pointer to an RPCMessage_t object for storing the result in
 */
.globl RecvRPCMessage
RecvRPCMessage:

	//Save the pointer
	move		t7, a0
	
	//Blocking RPC receive
	lui			a0, SYS_RECV_RPC_BLOCKING
	syscall
	
	//Extract fields and store to memory
	sw			rpc_d2, 24(t7)			//d2
	sw			rpc_d1, 20(t7)			//d1
	srl			t0, rpc_d0, 24			//shift out callnum
	srl			t1, rpc_d0, 21			//shift out type
	li			t2, 0x1FFFFF			//mask for d0
	and			t2, t2, rpc_d0			//mask out d0
	andi		t1, t1, 0x7				//mask for type
	srl			t3, rpc_header, 16		//mask for src addr
	andi		t4, rpc_header, 0xffff	//mask for dst addr
	sw			t2, 16(t7)				//d0
	sw			t1, 12(t7)				//type
	sw			t0, 8(t7)				//callnum
	sw			t4, 4(t7)				//dst addr
	sw			t3, 0(t7)				//src addr

	//Done
	jr			ra
	nop

