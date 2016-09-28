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
	@brief Linker script for SARATOGA with code in block RAM
 */

PHDRS
{
	signature	0x70000005;		/* HMAC-SHA256 signature of the loadable data and entry point (must be first) */
	program		PT_LOAD;		/* The main program */
	ramdata		PT_LOAD;		/* Data in RAM */
	others		PT_NOTE;		/* Debug info etc */
}

MEMORY
{
	/* HMAC-SHA256 signature */
	signature		: ORIGIN = 0x3FFFF800, LENGTH = 32
	
	/* Main program/data ROM (32KB) */
	rom		(rx)  	: ORIGIN = 0x40000000, LENGTH = 32K

	/* This space for rent. Dynamic memory, I/O, etc can be mapped here at runtime */
	user_mem		: ORIGIN = 0x40008000, LENGTH = 24K
	
	/* Global variables */
	globals	(rw) 	: ORIGIN = 0x4000E000, LENGTH = 4K
	
	/* Unmapped (guard) page to keep globals from hitting stack */
	guard_page_3	: ORIGIN = 0x4000F000, LENGTH = 2K
	
	/* Stack */
	stack(rw)		: ORIGIN = 0x4000F800, LENGTH = 2K
}

/* Base settings shared by all SARATOGA linker scripts */
INCLUDE saratoga-base.ld
