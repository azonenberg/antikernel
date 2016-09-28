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
	@brief Basic ELF parsing test
	
	Reads a random mips-elf executable and parses the structure, applying some basic sanity checks
 */
#include <string>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include "../../src/jtaghal/jtaghal.h"

using namespace std;
 
int main()
{
	int err_code = 0;
	
	try
	{
		//Mmap the file
		//Use PDU firmware image for this test since it's decently large
		int fd = open("../../mips-elf/PDUFirmware", O_RDONLY);
		if(fd < 0)
		{
			throw JtagExceptionWrapper(
				"Failed to open ELF image",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		uint32_t len = lseek(fd, 0, SEEK_END);
		lseek(fd, 0, SEEK_SET);
		printf("File opened, length is %d bytes\n", len);
		uint32_t* base = reinterpret_cast<uint32_t*>( mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, 0) );
		//uint8_t* cbase = reinterpret_cast<uint8_t*>(base);
		if(base == MAP_FAILED)
		{
			throw JtagExceptionWrapper(
				"Failed to map file",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Read the ELF magic number and sanity check it
		if(ntohl(base[0]) != 0x7f454c46)
		{
			throw JtagExceptionWrapper(
				"Bad magic number",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Read entry point
		uint32_t entry = ntohl(base[6]);
		printf("Entry point = virtual 0x%08x\n", entry);
		
		//Read program headers
		uint32_t phoff = ntohl(base[7]);
		if(phoff & 3)
		{
			throw JtagExceptionWrapper(
				"Bad (unaligned) phoff",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		uint32_t phwordoff = phoff/4;
		printf("Program headers are located at byte offset %d (word offset %d)\n", phoff, phwordoff);
		uint16_t phentsize = ntohl(base[10]) & 0xffff;
		uint16_t phnum = ntohl(base[11]) >> 16;
		uint16_t phwordsize = phentsize / 4;
		printf("    phentsize = %d words, %d program headers total\n", phwordsize, phnum);
		if(phentsize & 3)
		{
			throw JtagExceptionWrapper(
				"Bad (unaligned) phentsize",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Read each program header
		for(uint16_t i=0; i<phnum; i++)
		{
			printf("Program header %u\n", i);
			uint32_t off = phwordoff + (i*phwordsize);
			printf("    Offset: %d (bytes), %d (words)\n", off*4, off);
			
			//Verify it's loadable
			uint32_t type = ntohl(base[off]);
			if(type != 1)
			{
				printf("    Not a PT_LOAD type, ignoring it\n");
				continue;
			}
			
			//File offset
			printf("    File offset: 0x%x\n", ntohl(base[off+1]));
			
			//Virtual address
			printf("    Virtual addr: 0x%08x\n", ntohl(base[off+2]));
			
			//Ignore physical address
			
			//File size
			printf("    Size on disk: %d bytes\n", ntohl(base[off+4]));
			
			//Memory size
			printf("    Size in mem: %d bytes\n", ntohl(base[off+5]));
			
			//Flags
			
			//Alignment
			printf("    Alignment: %d\n", ntohl(base[off+7]));
		}
		
		//Clean up
		munmap(base, len);
		close(fd);
		err_code = 0;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}
