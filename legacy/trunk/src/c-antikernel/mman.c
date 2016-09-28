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
	@brief Name-server helpers
 */

#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>

//Pull in CPU driver functions (SARATOGA and GRAFTON should have same prototypes)
#include <saratoga/saratoga.h>

#include <rpc.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Virtual address freelist

//TODO make size configurable
#define VMEM_MAX_PAGES 12

//For now, use size of SARATOGA block RAM default user vmem
unsigned char page_in_use[VMEM_MAX_PAGES];

void mmap_init()
{
	for(int i=0; i<VMEM_MAX_PAGES; i++)
		page_in_use[i] = 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Sanity checking helpers

/**
	@brief Verifies that the supplied address and length are valid. Returns 1 if valid.
 */
int mmap_verify_addr(void* addr, size_t len)
{
	unsigned char* low = (unsigned char*)GetUserMemLow();
	unsigned char* high = (unsigned char*)GetUserMemHigh();
	
	if(((unsigned char*)addr < low) || ((unsigned char*)addr > high))
		return 0;
		
	unsigned char* end_addr = (unsigned char*)addr + len;
	if(end_addr > high)
		return 0;
		
	return 1;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Actual mmap functions

/**
	@brief POSIX mmap function - maps a provided file descriptor into virtual memory
 */
void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off)
{
	//Die if the length is invalid
	if(len == 0)
	{
		errno = EINVAL;
		return NULL;
	}
	
	//Look up the file descriptor
	if(!posix_fd_valid(fd))
	{
		errno = EBADFD;
		return NULL;
	}
	unsigned short nocaddr = posix_fd_nocaddr(fd);
	unsigned int phyaddr = posix_fd_phyaddr_with_off(fd);
	phyaddr += off;
	
	//Round physical and virtual address down to start of a page
	phyaddr = phyaddr & PAGE_MASK;
	addr = (void*) ((unsigned int)addr & PAGE_MASK);
	
	//Verify address is valid (if not null)
	if((addr != NULL) && !mmap_verify_addr(addr, len))
	{
		errno = EADDRNOTAVAIL;
		return NULL;
	}
	
	//Figure out how many pages we're mapping
	//Round up to next page size, then truncate
	size_t pagecount = (len + PAGESIZE) >> LOG_PAGESIZE;
	
	//If address isn't specified, choose an address
	if(addr == NULL)
	{
		//Find a valid set of pagecount free vmem pages
		for(int i=0; i<VMEM_MAX_PAGES; i++)
		{
			//Not enough consecutive free pages possible? Give up
			if( (i + pagecount) > VMEM_MAX_PAGES)
			{
				errno = ENOMEM;
				return NULL;
			}
			
			//Check if we have enough consecutive free pages
			unsigned char ok = 1;
			for(unsigned int j=i; j<i+pagecount; j++)
			{
				if(page_in_use[j])
				{
					ok = 0;
					break;
				}
			}
			
			//Some page in the range is used, try again
			if(!ok)
				continue;

			//Nope, all pages are free. Pick this as the address
			addr = (unsigned char*)GetUserMemLow() + (i << LOG_PAGESIZE);
			break;
		}
		
		//Verify that we found a valid address.
		if(addr == NULL)
		{
			errno = ENOMEM;
			return NULL;
		}
	}
	
	//Address WAS specified. 
	//Flags must specify MAP_FIXED
	else if(! (flags & MAP_FIXED) )
	{
		errno = EINVAL;
		return NULL;
	}
	
	unsigned char* addr_ch = (unsigned char*) addr;
	
	//Flush the D-cache for this address range
	//Need to do this BEFORE calling MmapHelper so that the old TLB entry, if any, is still valid
	FlushDsideL1Cache(addr_ch, len);
	
	//Cannot create new I-side memory mappings on SARATOGA at run time so no need to flush I-cache
	//TODO: Flush I-cache on GRAFTON if necessary?
	
	//If we get here, we have a valid virtual address.
	//Create the actual page table entries using a helper function from the CPU-specific hardware wrapper library.
	for(size_t i=0; i<pagecount; i++)
	{
		MmapHelper(
			addr_ch,
			phyaddr,
			nocaddr,
			prot);
			
		addr_ch += PAGESIZE;
		phyaddr += PAGESIZE;
	}
		
	//MmapHelper always succeeds for now so return address
	return addr;
}

int munmap(void* addr, size_t len)
{
	//Round virtual address down to start of page
	addr = (void*) ((unsigned int)addr & PAGE_MASK);
	
	//Verify address is valid
	if(!mmap_verify_addr(addr, len))
	{
		errno = EADDRNOTAVAIL;
		return 1;
	}
	
	//Figure out how many pages we're mapping
	//Round up to next page size, then truncate
	size_t pagecount = (len + PAGESIZE) >> LOG_PAGESIZE;
	
	//Flush the D-cache for this address range
	//Need to do this BEFORE calling MmapHelper so that the old TLB entry, if any, is still valid
	unsigned char* addr_ch = (unsigned char*) addr;
	FlushDsideL1Cache(addr_ch, len);
	
	//TODO: Actually delete the mapping
	//For now, just create an invalid mapping
	for(size_t i=0; i<pagecount; i++)
	{
		MmapHelper(
			addr_ch,
			0,
			0,
			PAGE_GUARD);
			
		addr_ch += PAGESIZE;
	}
	
	//Good
	return 0;
}
