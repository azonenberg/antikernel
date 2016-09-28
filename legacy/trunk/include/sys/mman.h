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
	@brief POSIX memory mapping functions
 */
#ifndef mman_h
#define mman_h

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Type declarations

#include <stdio.h>
typedef unsigned int off_t;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// System configuration

#define PAGESIZE		2048
#define PAGE_MASK		0xFFFFF800
#define LOG_PAGESIZE	11

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Memory functions

//Pull in definitions for SARATOGA permissions (GRAFTON is the same)
#include <SaratogaCPUPagePermissions_constants.h>

//Rename them to match POSIX
#define PROT_NONE		0
#define PROT_READ		PAGE_READ
#define PROT_WRITE		PAGE_WRITE
#define PROT_EXEC		PAGE_EXECUTE

//Flags for mmap
#define MAP_SHARED		1
//MAP_PRIVATE not supported on Antikernel since we don't have CoW
#define MAP_FIXED		2

void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off);
int munmap(void* addr, size_t len);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Internal helpers

int mmap_verify_addr(void* addr, size_t len);

/*
struct vma_freelist
{
	
};
*/
void mmap_init();

#endif
