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
	@brief Cache-related code
 */

//Friendly names for CPU registers
#include <saratoga/registers.h>

.set noreorder
.set noat

/**
	Cache flushing is done by a simple brute-force method for now:
	read and discard a single word from each cache line.
	
	Repeat again, with different addresses, to flush the second level of associativity.
	
	TODO: Replace this with a proper RPC so we can be portable to multiple CPU configs
	
	Default SARATOGA cache config is 16 lines of 32 bytes (512 bytes) per way.
 */
.globl FlushDsideL1Cache
FlushDsideL1Cache:
	//a0 = addr
	//a1 = len
	//TODO: Only flush the lines we're interested in?

	//Pointer to the boot sector
	//We can use this as a reliable means of flushing the cache because it is
	// a) known to be mapped at this address, and
	// b) does not change at run time
	lui			t0, 0x4000
	move		t1, zero
	
	li			t2, 15
	
CacheFlushLoop:
	lw			t3, 0(t0)			//Read the first word in the cache line
	lw			t3, 512(t0)			//Read the first word colliding with this one
	
	addiu		t0, 32				//Skip to the next line
	addiu		t1, 1				//and bump counter
	
	bne			t1, t2, CacheFlushLoop
	nop

	jr			ra
	nop
