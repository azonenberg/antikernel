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
	@brief Startup / initialization code for SARATOGA softcore
 */

//Friendly names for CPU registers
#include <saratoga/registers.h>

#include <rpc_asm.h>

//Syscall numbers etc
#include <NetworkedDDR2Controller_opcodes_constants.h>
#include <NOCNameServer_constants.h>
#include <RPCv2Router_type_constants.h>
#include <SaratogaCPUManagementOpcodes_constants.h>
#include <SaratogaCPUSyscalls_constants.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// HMAC signature (placeholder for actual signature, just need to take up 32 bytes of space)

.section .signature
	.ascii "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CPU reset vector

.section .startup
.set noreorder				//REQUIRED for Saratoga since delay slot is never executed
.set noat
.globl _start
_start:
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General setup for RAM operations
	
	//Look up the RAM
	li			a0, 0x72616d00					//"ram\0"
	move		a1, zero						//4-character string, d2 isn't used
	jal			__LookupHost
	nop
	
	//If failed, abort
	li			t0, 1
	bne			t0, v1, halt
	
	//Save the address of RAM in a saved-temp register
	//No need to preserve $s since we have no caller
	move		s0, v0
		
	//Get the OoB management address of our host CPU
	lui			a0, SYS_GET_OOB
	syscall
	move		s1, v0
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Stack setup

	//s0 = address of ram
	//Go allocate a page of RAM
	move		a0, s0
	jal			__PageMalloc
	nop
	
	//If failed, abort
	li			t0, 1
	bne			t0, v1, halt
	
	//Send the RPC
	lui			a0, SYS_SEND_RPC_BLOCKING
	or			a0, a0, s1
	li			a1, RPC_OP_WORD(OOB_OP_MMAP, RPC_TYPE_CALL, 0);
	or			a1, a1, s0		//NoC address
	move		a2, v0			//Physical address
	la			a3, _stack_low	//Virtual address
	syscall
	
	//Wait for a response
	move		t1, s1
	la			a1, __stacksetup_done
	j			__WaitForMessageFrom
	nop
__stacksetup_done:
	
	//Update the stack pointer
	la			sp, _stack_high
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Allocate a page for global variables in .bss and .data

	//Figure out how many pages of globals we actually need to allocate space for.
	//This is just bss for now but will eventually include initialized data.
	la			t0, _globals_end
	la			s3, _globals_start
	sub			s2, t0, s3						//Size of global space in bytes
	srl			s2, s2, 11						//Size of global space in pages
	addi		s2, s2, 1						//Round up to next full page
	
GlobalMallocLoop:

	//Allocate a new page of RAM
	move		a0, s0							//Need to supply RAM address
	jal			__PageMalloc
	nop
	
	//If failed, abort.
	beq			v1, zero, halt
	nop
	
	//Send the RPC
	lui			a0, SYS_SEND_RPC_BLOCKING
	or			a0, a0, s1
	li			a1, RPC_OP_WORD(OOB_OP_MMAP, RPC_TYPE_CALL, 0);
	or			a1, a1, s0			//NoC address
	move		a2, v0				//Physical address
	move		a3, s3				//Virtual address
	syscall
	
	//Wait for a response
	move		t1, s1
	la			a1, __globsetup_done
	j			__WaitForMessageFrom
	nop
__globsetup_done:
	
	//Bump page count and increment pointer
	addi		s3, s3, 2048					//+1 page
	addi		s2, s2, -1						//-1 page to go
	
	//Stop if we're done, otherwise allocate another page
	bne			s2, zero, GlobalMallocLoop
	nop
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// All good, go run the application
		
	jal			main
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Infinite loop for fatal errors
// If main() ever returns, hang in an infinite loop
// Must be located right after _start() ends

.globl halt
halt:
	j			halt
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Nameserver lookup 

/*
	@brief Pre-stack nameserver querying
	
	No use of data RAM (and, consequentially, saved-temp registers) is permitted.
	
	@param a0 		hostname left half
	@param a1		hostname right half
	
	@return			v0 = address
					v1 = 1 on success, 0 on failure
 */
__LookupHost:

	//Move hostname to the right registers
	move		a3, a1
	move		a2, a0
	
	//Sending RPC message to the nameserver
	lui			a0, SYS_SEND_RPC_BLOCKING
	ori			a0, NAMESERVER_ADDR
	
	//Forward query call
	li			a1, RPC_OP_WORD(NAMESERVER_FQUERY, RPC_TYPE_CALL, 0);
	
	//Send the message
	syscall
	
	//Wait for a response
	li			t1, NAMESERVER_ADDR
	la			a1, __LookupHost_recvdone
	j			__WaitForMessageFrom
__LookupHost_recvdone:
	
	//Default to failure
	li			v1, 0
		
	//Pull out the return code
	srl			t0, rpc_d0, 21
	andi		t0, t0, 7
	li			t2, RPC_TYPE_RETURN_SUCCESS
	bne			t0, t2, __LookupHost_fail
	
	//If we get here, it was a success
	li			v1, 1
	
	//return either way
__LookupHost_fail:
	
	//Pull out the address
	andi		v0, rpc_d0, 0xffff
		
	//Done
	jr			ra
	nop
	
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Page allocation

/*
	@brief Allocate a page of RAM
	
	No use of data RAM (and, consequentially, saved-temp registers) is permitted.
	
	@param a0 		NoC address of RAM
	
	@return			v0 = physical address
					v1 = 1 on success, 0 on failure
 */
__PageMalloc:
	
	//Save the address
	move		t1, a0
	
	//Send the request
	lui			a0, SYS_SEND_RPC_BLOCKING
	or			a0, a0, t1
	li			a1, RPC_OP_WORD(RAM_ALLOCATE, RPC_TYPE_CALL, 0);
	move		a2, zero
	move		a3, zero
	syscall
	
	//Wait for a response
	la			a1, __PageMalloc_recvdone
	j			__WaitForMessageFrom
__PageMalloc_recvdone:
		
	//Default to failure
	li			v1, 0
		
	//Pull out the return code
	srl			t0, rpc_d0, 21
	andi		t0, t0, 7
	li			t2, RPC_TYPE_RETURN_SUCCESS
	bne			t0, t2, __PageMalloc_fail
	
	//If we get here, it was a success
	li			v1, 1
	
	//return either way
__PageMalloc_fail:
	
	//Pull out the address
	move		v0, rpc_d1
		
	//Done
	jr			ra
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Shared helper routines

/*
	@brief Waits for an RPC message from a particular address
	
	No use of data RAM (and, consequentially, saved-temp registers) is permitted.
	
	@param t1		Expected source address of the message
	@param a1		Address to jump to upon return
 */
__WaitForMessageFrom:
	
	//Blocking RPC receive
	lui			a0, SYS_RECV_RPC_BLOCKING
	syscall
	
	//Check who it's from
	//If not the expected target, drop it and try again
	srl			t0, rpc_header, 16
	bne			t0, t1, __WaitForMessageFrom
	nop
	
	//Hit, return
	jr			a1
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Public APIs used by user applications

//Asserts the trace flag for one cycle
.globl DebugTracePoint
DebugTracePoint:
	lui			a0, SYS_TRACE
	syscall
	
	jr			ra
	nop

//Wrapper around SYS_GET_OOB for C code
.globl GetCPUManagementAddress
GetCPUManagementAddress:

	lui			a0, SYS_GET_OOB
	syscall

	jr			ra
	nop

//Gets the low end of user address space
.globl GetUserMemLow
GetUserMemLow:
	la			v0, _user_mem_low;
	jr			ra
	nop
	
//Gets the low end of user address space
.globl GetUserMemHigh
GetUserMemHigh:
	la			v0, _user_mem_high;
	jr			ra
	nop
