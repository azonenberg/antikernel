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

#include <rpc.h>

#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>

#include <NetworkedDDR2Controller_opcodes_constants.h>

//Pull in CPU driver functions (same for both cores)
#include <saratoga/saratoga.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Error handling stuff

int errno;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Internal file descriptor management

/**
	@brief Global table of file descriptors
 */
struct posix_file_descriptor g_fds[MAX_FDS];

/**
	@brief Initializes the POSIX compatibility library
 */
void posix_init()
{
	//Set up the interrupt queue for RPCFunctionCall() etc
	InterruptQueueInit();
	
	//Initialize the global list of file descriptors
	for(int i=0; i<MAX_FDS; i++)
		g_fds[i].valid = 0;
	
	//Set up the freelist of virtual pages
	mmap_init();
		
	//TODO: More init as needed...
}

/**
	@brief Allocates a new POSIX file descriptor
 */
int posix_fd_alloc(unsigned short nocaddr, unsigned int phyaddr)
{
	//Slow, but effective for a small number of FDs.
	for(int i=0; i<MAX_FDS; i++)
	{
		if(!g_fds[i].valid)
		{
			g_fds[i].valid = 1;
			g_fds[i].noc_address = nocaddr;
			g_fds[i].base_address = phyaddr;
			g_fds[i].file_pos = 0;
			
			return i;
		}
	}
	
	//out of file descriptors
	errno = ENFILE;
	return -1;
}

/**
	@brief Returns the NoC address associated with a given file descriptor.
 */
unsigned short posix_fd_nocaddr(int fd)
{
	if(!posix_fd_valid(fd))
		return 0;
	return g_fds[fd].noc_address;
}

/**
	@brief Returns the physical address associated with a given file descriptor.
 */
unsigned int posix_fd_phyaddr(int fd)
{
	if(!posix_fd_valid(fd))
		return 0;
	return g_fds[fd].base_address;
}

/**
	@brief Returns the physical address (including offset within the file) associated with a given file descriptor
 */
unsigned int posix_fd_phyaddr_with_off(int fd)
{
	if(!posix_fd_valid(fd))
		return 0;
	return g_fds[fd].base_address + g_fds[fd].file_pos;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// POSIX file API

/**
	Close an open file descriptor
 */
int close(int fd)
{
	if(!g_fds[fd].valid)
	{
		errno = EBADFD;
		return -1;
	}
		
	g_fds[fd].valid = 0;
	
	return 0;
}

/**
	@brief Checks if a provided file descriptor is valid.
 */
int posix_fd_valid(int fd)
{
	if(fd < 0)
		return 0;
	if(fd > MAX_FDS)
		return 0;
		
	return g_fds[fd].valid;
}

/**
	@brief Changes the ownership of the memory pointed to by a given file descriptor.
	
	TODO: Support for multiple pages (maybe create the fd with a given length?)
 */
int fchown(int fd, unsigned short owner, unsigned short group)
{
	//Sanity check
	if(!posix_fd_valid(fd))
	{
		errno = EBADFD;
		return -1;
	}
	
	//ignore group (needed as an arg for POSIX compliance)
	(void)group;
	
	//Try to chown it
	//TODO: Work for things other than RAM API
	RPCMessage_t rmsg;
	if(0 != RPCFunctionCall(
		posix_fd_nocaddr(fd),
		RAM_CHOWN,
		0,
		posix_fd_phyaddr(fd),
		owner,
		&rmsg))
	{
		errno = EPERM;
		return -1;
	}
	
	//If we get here, all is well
	return 0;		
}
