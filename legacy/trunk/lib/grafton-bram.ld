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
	@brief Linker script for GRAFTON with code in block RAM
 */

MEMORY
{
	/* Main program/data ROM (16KB) */
	rom		(rx)  : ORIGIN = 0x40000000, LENGTH = 16K
	
	/* Free space to allow code size to change without other addresses needing recalculation */
	
	/* Unmapped (guard) page to keep user data from hitting code */
	guard_page_1	: ORIGIN = 0x4007F800, LENGTH = 2K
	
	/* This space for rent. Dynamic memory, I/O, etc can be mapped here at runtime */
	user_mem		: ORIGIN = 0x40080000, LENGTH = 502K
	
	/* Unmapped (guard) page to keep user data from hitting globals */
	guard_page_2	: ORIGIN = 0x400FD800, LENGTH = 2K
		
	/* Global variables */
	globals	(rw) 	: ORIGIN = 0x400FE000, LENGTH = 2K
	
	/* Unmapped (guard) page to keep globals from hitting stack */
	guard_page_3	: ORIGIN = 0x400FE800, LENGTH = 2K
	
	/* Stack */
	stack(rw)		: ORIGIN = 0x400FF800, LENGTH = 2K
}

/* Base settings shared by all GRAFTON linker scripts */
INCLUDE grafton-base.ld
