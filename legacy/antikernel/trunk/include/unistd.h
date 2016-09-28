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
	@brief Main header file for POSIX compatibility library
 */
#ifndef unistd_h
#define unistd_h

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// POSIX feature definitions

#define _POSIX_MAPPED_FILES 1

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// POSIX file API

int close(int fd);
int fchown(int fd, unsigned short owner, unsigned short group);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// POSIX compatibility stuff (not actually in POSIX standard)

#define MAX_FDS		16

void posix_init();

/**
	@brief The backing data for a POSIX file descriptor
 */
struct posix_file_descriptor
{
	///1 if allocated, 0 if free
	unsigned char valid;
	
	///NoC address of the backing device
	unsigned short noc_address;
	
	///Base physical address of this file within the backing device
	unsigned int base_address;
	
	///Current offset of the read/write pointer within the file
	unsigned int file_pos;
};

int posix_fd_alloc(unsigned short nocaddr, unsigned int phyaddr);

int posix_fd_valid(int fd);
unsigned short posix_fd_nocaddr(int fd);
unsigned int posix_fd_phyaddr(int fd);
unsigned int posix_fd_phyaddr_with_off(int fd);

#endif
