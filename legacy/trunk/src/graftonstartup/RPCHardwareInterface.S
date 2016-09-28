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
#include <grafton/registers.h>

//Syscall numbers etc
#include <GraftonCPUSyscalls_constants.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RPC stuff

/*
	@brief Sends an RPC message
	
	@param a0		Pointer to a PackedRPCMessage object
 */
.globl SendRPCMessage
SendRPCMessage:

	//First load needs a nop to bootstrap
	lw			t0, 4(a0)
	nop
	
	//From here on, interleave to reduce need for nops
	lw			t1, 8(a0)
	mtc0		t0, rpc_dst_addr
	lw			t2, 12(a0)
	mtc0		t1, rpc_callnum
	lw			t3, 16(a0)
	mtc0		t2, rpc_type
	lw			t4, 20(a0)
	mtc0		t3, rpc_d0
	lw			t5, 24(a0)
	mtc0		t4, rpc_d1
	mtc0		t5, rpc_d2
	
	//Do the actual send
	li			a0, SYS_SEND_RPC
	syscall

	jr			ra
	nop

/*
	@brief Receives an RPC message.
	
	Blocks until a message is available.
	
	@param a0		Pointer to a PackedRPCMessage object for storing the result in
 */
.globl RecvRPCMessage
RecvRPCMessage:

	//Save the pointer
	move		t7, a0
	
	//Block until we get the message
	li			a0, SYS_RECV_RPC
	syscall
	nop			//delay slot
	
	//It is critical that no memory write transactions occur before we issue SYS_RPC_DONE
	//to avoid race conditions or message corruption. The CPU will automatically acknowledge these messages
	//and may overwrite the coprocessor registers in the process.
	
	//Store it into registers
	mfc0		t0, rpc_src_addr
	mfc0		t1, rpc_dst_addr
	mfc0		t2, rpc_callnum
	mfc0		t3, rpc_type
	mfc0		t4, rpc_d0
	mfc0		t5, rpc_d1
	mfc0		t6, rpc_d2
	
	//Pop the FIFO
	li			a0, SYS_RPC_DONE
	syscall
	
	//Write to memory
	sw			t0, 0(t7)
	sw			t1, 4(t7)
	sw			t2, 8(t7)
	sw			t3, 12(t7)
	sw			t4, 16(t7)
	sw			t5, 20(t7)
	sw			t6, 24(t7)
	nop
		
	jr			ra
	nop

