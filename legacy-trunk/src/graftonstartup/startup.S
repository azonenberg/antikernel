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
	@brief Startup / initialization code for GRAFTON softcore
 */

//Friendly names for CPU registers
#include <grafton/registers.h>

//Syscall numbers etc
#include <GraftonCPUPagePermissions_constants.h>
#include <GraftonCPUSyscalls_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>
#include <NOCNameServer_constants.h>
#include <RPCv2Router_type_constants.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CPU reset vector
// No longer needs to be in a separate section since ELF loader figures out entry point at load time

/*
	Register map:
		s0 = network address of RAM
		s1 = base physical address of stack
		s2 = number of global pages to allocate
 */

.set noreorder
.set noat
.globl _start
_start:

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Stack setup

	//Look up the RAM
	li			a0, 0x72616d00					//"ram\0"
	move		a1, zero						//4-character string, d2 isn't used
	jal			LookupHost
	nop
	beq			v1, zero, halt					//If the lookup failed, something is seriously wrong... hang
	move		s0, v0							//RAM's address is in $v0, save it

	//Allocate a new page of RAM for the stack
	move		a0, s0							//Need to supply RAM address
	jal			PageMalloc
	nop
	beq			v1, zero, halt					//If the allocation failed, something is seriously wrong... hang
	nop
	move		s1, v0							//Page address is in $v0, save it
	
	//Map the page into the stack segment
	la			a0, _stack_low					//Base address of stack
	move		a1, s1							//RAM address
	move		a2, s0							//Network address of RAM
	li			a3, PAGE_READ_WRITE				//Permissions for RAM
	jal			MmapHelper
	nop
	
	//Initialize the stack pointer
	la			sp, _stack_high					//LAST valid address in the stack segment; stack grows down
												//Stack should be 8-byte aligned
	
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
	jal			PageMalloc
	nop
	beq			v1, zero, halt					//If the allocation failed, something is seriously wrong... hang
												//Page address is now in $v0
	nop
	
	//Map the page
	move		a0, s3							//Start address of the page
	move		a1, v0							//RAM address
	move		a2, s0							//Network address of RAM
	li			a3, PAGE_READ_WRITE				//Permissions for RAM
	jal			MmapHelper
	nop
	
	//Bump page count and increment pointer
	addi		s3, s3, 2048					//+1 page
	addi		s2, s2, -1						//-1 page to go
	
	//Stop if we're done, otherwise allocate another page
	bne			s2, zero, GlobalMallocLoop
	nop
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Set up handlers for software-emulated instructions
	
	la			t0, SignedSoftDivisionHandler
	mtc0		t0, div_handler
	
	la			t0, UnsignedSoftDivisionHandler
	mtc0		t0, divu_handler
	
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
LookupHost:
	
	//Address of the name server (hard wired)
	li			t1, NAMESERVER_ADDR
	
	//Send a query to the name server asking for the address of the host
	mtc0		t1, rpc_dst_addr
	li			t0, RPC_TYPE_CALL
	mtc0		t0, rpc_type
	li			t0, NAMESERVER_FQUERY
	mtc0		t0, rpc_callnum
	mtc0		zero, rpc_d0					//d0 not used by NAMESERVER_FQUERY
	mtc0		a0, rpc_d1						//The hostname to look up
	mtc0		a1, rpc_d2
LookupHost_send:
	li			a0, SYS_SEND_RPC				//Blocking RPC send
	syscall

	//Wait for the response and process it
LookupHost_recvloop:
	li			a0, SYS_RECV_RPC				//Wait for the response
	syscall
	nop											//delay slot
	
	mfc0		t0, rpc_src_addr				//Load the entire message into registers
	mfc0		t2, rpc_type					//We don't care about the call number or data[1, 2].
												//If the message is from the name server, it has to be a response
												//to our lookup query.
	mfc0		v0, rpc_d0						//If the lookup was successful, we'll return the address in v0
												//Stick it in here immediately to save a move
	
	li			a0, SYS_RPC_DONE				//Pop the FIFO
	syscall

	bne			t0, t1, LookupHost_recvloop		//Make sure the message is from the name server
												//If not, throw it away and grab the next one
	
	li			t3, RPC_TYPE_RETURN_RETRY		//If the host is busy, re-send
	beq			t2, t3, LookupHost_send
	
	li			t3, RPC_TYPE_RETURN_SUCCESS		//Make sure the call was a success
	bne			t2, t3, LookupHost_fail			//if not, fail
	nop

LookupHost_ok:									//Hostname lookup successful - return address
												//v0 is the address of the core
	li			v1, 1	
	jr			ra
	nop
	
LookupHost_fail:								//Hostname lookup failed - return error code
												//v0 is undefined
	move		v1, zero
	jr			ra
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Allocate a new page of memory

/*
	@brief Pre-stack nameserver querying
	
	No use of data RAM (and, consequentially, saved-temp registers) is permitted.
	
	@param a0 		NoC address of RAM
	
	@return			v0 = address
					v1 = 1 on success, 0 on failure
 */
PageMalloc:

	//Save address for future use
	move		t1, a0

	//Send out the request
	mtc0		a0, rpc_dst_addr
	li			t0, RPC_TYPE_CALL
	mtc0		t0, rpc_type
	li			t0, RAM_ALLOCATE
	mtc0		t0, rpc_callnum
	mtc0		zero, rpc_d0					//No arguments
	mtc0		zero, rpc_d1
	mtc0		zero, rpc_d2
PageMalloc_send:
	li			a0, SYS_SEND_RPC
	syscall

	//Wait for the response and process it
PageMalloc_recvloop:
	li			a0, SYS_RECV_RPC				//Wait for the response
	syscall
	nop											//delay slot
	
	mfc0		t0, rpc_src_addr				//Load the entire message into registers
	mfc0		t2, rpc_type					//We don't care about the call number or data[0, 2].
												//If the message is from the RAM, it has to be a response
												//to our allocation query.
	mfc0		v0, rpc_d1						//If the allocation was successful, we'll return the address in v0
												//Stick it in here immediately to save a move
	
	li			a0, SYS_RPC_DONE				//Pop the FIFO
	syscall

	bne			t0, t1, PageMalloc_recvloop		//Make sure the message is from the RAM
												//If not, throw it away and grab the next one
	
	li			t3, RPC_TYPE_RETURN_RETRY		//If the host is busy, re-send
	beq			t2, t3, PageMalloc_send
	
	li			t3, RPC_TYPE_RETURN_SUCCESS		//Make sure the call was a success
	bne			t2, t3, PageMalloc_fail			//if not, fail
	nop

PageMalloc_ok:									//Allocation successful - return address
												//v0 is the address of the first page in RAM
	li			v1, 1	
	jr			ra
	nop
	
PageMalloc_fail:								//Hostname lookup failed - return error code
												//v0 is undefined
	move		v1, zero
	jr			ra
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Memory mapping

/*
	@brief Pre-stack memory mapping
	
	No use of data RAM (and, consequentially, saved-temp registers) is permitted.
	
	@param a0 		Virtual base address of page (automatically rounded down to 2KB boundary)
	@param a1		Physical address within the host to map (automatically rounded down to 2KB boundary)
	@param a2		Network address of the host to map
	@param a3		Permissions to map
	
	@return			No return value
 */
 
.globl MmapHelper
MmapHelper:

	mtc0		a0, mmu_page_id					//Move args to the coprocessor
	mtc0		a1, mmu_phyaddr
	mtc0		a2, mmu_nocaddr
	mtc0		a3, mmu_perms
	
	li			a0, SYS_MMAP					//Do the fun work
	syscall
	
	jr			ra
	nop

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Public APIs used by user applications

//Asserts the trace flag for one cycle
.globl DebugTracePoint
DebugTracePoint:
	li			a0, SYS_TRACE
	syscall
	
	jr			ra
	nop
	
//a0 = pointer to eight ints
.globl GetProfilingStats
GetProfilingStats:
	mfc0		t0, cp0_prof_clocks
	mfc0		t1, cp0_prof_insns
	mfc0		t2, cp0_prof_dmisses
	mfc0		t3, cp0_prof_dreads
	mfc0		t4, cp0_prof_imisses
	mfc0		t5, cp0_prof_ireads
	mfc0		t6, cp0_prof_dmisstime
	mfc0		t7, cp0_prof_imisstime
	
	sw			t0, 0(a0)
	sw			t1, 4(a0)
	sw			t2, 8(a0)
	sw			t3, 12(a0)
	sw			t4, 16(a0)
	sw			t5, 20(a0)
	sw			t6, 24(a0)
	sw			t7, 28(a0)
	
	jr			ra
	nop
