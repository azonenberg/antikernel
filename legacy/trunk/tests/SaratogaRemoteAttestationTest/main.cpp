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
	@brief Test of SARATOGA remote attestation functionality
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include <linux/elf.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <signal.h>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>
#include <SaratogaCPUManagementOpcodes_constants.h>

using namespace std;

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				++i;
			else
			{
				printf("Unrecognized command-line argument \"%s\", expected --server or --port\n", s.c_str());
				return 1;
			}
		}
		if( (server == "") || (port == 0) )
		{
			throw JtagExceptionWrapper(
				"No server or port name specified",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}		
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Address lookup
		printf("Looking up address of CPU\n");
		NameServer nameserver(&iface, "SampleNameServerPassword");
		nameserver.Register("testcase");
		uint16_t caddr = nameserver.ForwardLookup("cpu");
		printf("CPU is at %04x\n", caddr);
		uint16_t raddr = nameserver.ForwardLookup("rom");
		printf("ROM is at %04x\n", raddr);
		uint16_t taddr = iface.GetClientAddress();
		printf("We are at %04x\n", taddr);
		
		//Get some more info about the CPU
		uint16_t oaddr = caddr;
		printf("OoB address is %04x\n", oaddr);
		RPCMessage rxm;
		iface.RPCFunctionCallWithTimeout(oaddr, OOB_OP_GET_THREADCOUNT, 0, 0, 0, rxm, 5);
		printf("    CPU has %d threads\n", rxm.data[0]);
		
		//Spawn a new thread
		printf("Creating new process (ELF image at rom:00000000)\n");
		iface.RPCFunctionCallWithTimeout(oaddr, OOB_OP_CREATEPROCESS, 0, raddr, 0x00000000, rxm, 5);
		uint16_t paddr = rxm.data[1];
		uint16_t pid   = rxm.data[0];
		printf("    New process ID is %d (address %04x)\n", pid, paddr);

		//Try to get the signature, watching out for race conditions
		unsigned int attested[8];
		unsigned int version = 0;
		bool ok = true;
		for(int t=0; t<10; t++)
		{
			printf("Trying to get signature (%d/10)\n", t+1);
			ok = true;
			for(int i=0; i<8; i++)
			{
				iface.RPCFunctionCallWithTimeout(caddr, OOB_OP_ATTEST, (i<<16) | pid, 0, 0, rxm, 5);
				
				//Save initial version on the first word
				if(i == 0)
					version = rxm.data[1];
					
				//If we get another version, the process died and was replaced so we have to try again
				if(rxm.data[1] != version)
				{
					ok = false;
					break;
				}
				
				//Save the hash
				attested[i] = rxm.data[2];
			}
			
			if(ok)
				break;
		}
		if(!ok)
		{
			throw JtagExceptionWrapper(
				"Failed to get attestation signature (tried 10 times)",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Find the actual signature in the ELF
		bool foundsig = false;
		unsigned int found[8];
		printf("Reading ELF...\n");
		int fd = open("../../mips-elf/SaratogaRPCTestFirmware-signed", O_RDWR);
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
		uint32_t* base = reinterpret_cast<uint32_t*>( mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0) );
		if(base == MAP_FAILED)
		{
			throw JtagExceptionWrapper(
				"Failed to mmap ELF",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		Elf32_Ehdr* ehdr = reinterpret_cast<Elf32_Ehdr*>(base);
		uint32_t phwordoff = ntohl(ehdr->e_phoff) / 4;
		uint16_t phnum = ntohs(ehdr->e_phnum);
		Elf32_Phdr* phdrs = reinterpret_cast<Elf32_Phdr*>(base + phwordoff);
		for(uint16_t i=0; i<phnum; i++)
		{
			if(ntohl(phdrs[i].p_type) == (PT_LOPROC + 5))		//SIGNATURE
			{
				unsigned int* signature_base = base + ntohl(phdrs[i].p_offset)/4;
				uint32_t sigsize_bytes = ntohl(phdrs[i].p_filesz);
				if(sigsize_bytes != 32)
				{
					throw JtagExceptionWrapper(
						"Invalid signature size",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
				foundsig = true;
				for(int j=0; j<8; j++)
					found[j] = ntohl(signature_base[j]);
			}
		}
		munmap(base, len);
		close(fd);
		if(!foundsig)
		{
			throw JtagExceptionWrapper(
				"No signature found in reference ELF",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Print out the signatures
		printf("Attested signature: ");
		for(int i=0; i<8; i++)
			printf("%08x ", attested[i]);
		printf("\n");
		printf("Expected signature: ");
		for(int i=0; i<8; i++)
			printf("%08x ", found[i]);
		printf("\n");
		
		//Verify they match
		for(int i=0; i<8; i++)
		{
			if(found[i] != attested[i])
			{
				throw JtagExceptionWrapper(
					"Bad signature",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		
		//all good
		return 0;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
