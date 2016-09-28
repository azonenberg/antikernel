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
	@brief Block ROM test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"

#include <NetworkedDDR2Controller_opcodes_constants.h>
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

#include <signal.h>

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
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Address lookup
		printf("Looking up address of ROM\n");
		NameServer nameserver(&iface);
		uint16_t raddr = nameserver.ForwardLookup("rom");
		printf("ROM is at %04x\n", raddr);
		
		//Read the first sector of the firmware image (the boot loader)
		const int blocksize = 512;
		FILE* fp = fopen("../../mips-elf/GraftonRPCTestFirmware", "rb");
		if(fp == NULL)
		{
			throw JtagExceptionWrapper(
				"Could not open firmware image",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		uint32_t expected_data[blocksize];
		fread(expected_data, 4, blocksize, fp);
		fclose(fp);

		//Do a DMA read from the ROM
		printf("Issuing DMA read (%d words)...\n", blocksize);
		uint32_t rdata[blocksize] = {0};
		iface.DMARead(raddr, 0, blocksize, rdata, RAM_OP_FAILED);
		printf("    Got the data, checking...\n");
		for(int i=0; i<blocksize; i++)
		{
			if(expected_data[i] != rdata[i])
			{
				printf("    Mismatch (at i=%d, got %08x, expected %08x)\n", i, rdata[i], expected_data[i]);
				throw JtagExceptionWrapper(
					"Got bad data back from board",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		printf("    OK\n");
		
		//Do a DMA write and verify it gets kicked back
		uint32_t datab[512] = {0};
		for(int i=0; i<blocksize; i++)
			datab[i] = 0xcccccccc;
		printf("Issuing illegal DMA write (%d words)...\n", blocksize);
		try
		{
			iface.DMAWrite(raddr, 0, blocksize, datab, RAM_WRITE_DONE, RAM_OP_FAILED);
			
			throw JtagExceptionWrapper(
				"DMA write should have been denied, but was not",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		catch(const JtagException& ex)
		{
			printf("    OK\n");
		}	
		
		//Verify it was not tampered with
		printf("Verifying data was not altered...\n");
		memset(rdata, 0, sizeof(rdata));
		iface.DMARead(raddr, 0, blocksize, rdata, RAM_OP_FAILED);
		printf("    Got the data, checking...\n");
		for(int i=0; i<blocksize; i++)
		{
			if(expected_data[i] != rdata[i])
			{
				printf("    Mismatch (at i=%d, got %08x, expected %08x)\n", i, rdata[i], expected_data[i]);
				throw JtagExceptionWrapper(
					"Got bad data back from board",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		printf("    OK\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
