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
	@brief SPI flash controller unit test
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

#include <BasicNetworkedQuadSPIFlashController_opcodes_constants.h>
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
		printf("Looking up address of flash\n");
		NameServer nameserver(&iface);
		uint16_t faddr = nameserver.ForwardLookup("flash");
		printf("Flash is at %04x\n", faddr);
		
		//Do the reset
		printf("Resetting flash...\n");
		RPCMessage rxm;
		iface.RPCFunctionCallWithTimeout(faddr, NOR_RESET, 0, 0, 0, rxm, 5);
				
		//Get the flash size
		printf("Getting info...\n");
		iface.RPCFunctionCallWithTimeout(faddr, NOR_GET_SIZE, 0, 0, 0, rxm, 5);
		unsigned int sector_count = rxm.data[1] / (4096*8);
		unsigned int read_count = sector_count * 2;
		unsigned int size_KB = rxm.data[1] / 8192;
		printf("    Flash size is %u KB (%u sectors, %u read blocks)\n", size_KB, sector_count, read_count);
		
		if(size_KB > 2048)
		{
			sector_count = 512;
			read_count = sector_count * 2;
			size_KB = 2048;
			printf("    Capping test to first 2048 KB\n");
		}
		
		//Erase the first sector
		printf("Erasing first sector...\n");
		iface.RPCFunctionCallWithTimeout(faddr, NOR_PAGE_ERASE, 0, 0x00000000, 0, rxm, 5);
		printf("    done\n");
		
		//Verify it's blank
		//4KB sector needs two 2KB read operations.
		uint32_t rdata[512] = {0};
		printf("Blank checking...\n");
		for(unsigned int sector=0; sector<2; sector++)
		{
			iface.DMARead(faddr, (sector*512*4), 512, rdata, NOR_OP_FAILED);
			
			for(unsigned int i=0; i<512; i++)
			{
				if(0xffffffff != rdata[i])
				{
					printf("    Mismatch (at sector %u, i=%u, got %08x, expected %08x)\n",
						sector, i, rdata[i], 0xffffffff);
					throw JtagExceptionWrapper(
						"Got bad data back from board",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			}
		}
		printf("    Block is blank\n");
		
		//Write a PRBS to the first half
		uint32_t data[2048] = {0};	//needs to be big enough that we can read beyond the end of
									//the array for DMAWrite() calls
		for(int i=0; i<1024; i++)
			data[i] = rand(); //0xffcc0000 | i;
		printf("Writing PRBS...\n");
		for(int i=0; i<1024; i += 64)
			iface.DMAWrite(faddr, i*4, 64, data+i, NOR_WRITE_DONE, NOR_OP_FAILED);
		printf("    done\n");
		
		//Reading the PRBS
		printf("Verifying PRBS...\n");
		for(unsigned int sector=0; sector<2; sector++)
		{
			unsigned int base = sector*512;
			iface.DMARead(faddr, base*4, 512, rdata, NOR_OP_FAILED);
			for(unsigned int i=0; i<512; i++)
			{
				if(data[i+base] != rdata[i])
				{
					printf("    Mismatch (at word address %d, got %08x, expected %08x)\n",
						 i+base, rdata[i], data[i+base]);
					throw JtagExceptionWrapper(
						"Got bad data back from board",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			}
		}
		printf("    OK\n");
		
		//Erase the entire device and measure performance
		double start = GetTime();
		printf("Erasing device (using sector erase)...\n");
		for(unsigned int sector=0; sector<read_count; sector += 2)
		{
			printf("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b%u / %u", sector, read_count);
			fflush(stdout);
			iface.RPCFunctionCallWithTimeout(faddr, NOR_PAGE_ERASE, 0, sector*512*4, 0, rxm, 5);
		}
		double dt = GetTime() - start;
		printf("\n    done (in %.2f sec, %.2f KB/s)\n", dt, size_KB / dt);
		
		//Blank check the entire device
		printf("Blank checking entire device...\n");
		start = GetTime();
		for(unsigned int sector=0; sector<read_count; sector++)
		{
			printf("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b%u / %u", sector, read_count);
			fflush(stdout);
			
			iface.DMARead(faddr, (sector*512*4), 512, rdata, NOR_OP_FAILED);
			
			for(unsigned int i=0; i<512; i++)
			{
				if(0xffffffff != rdata[i])
				{
					printf("    Mismatch (at sector %u, i=%u, got %08x, expected %08x)\n",
						sector, i, rdata[i], 0xffffffff);
					throw JtagExceptionWrapper(
						"Got bad data back from board",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			}
		}
		dt = GetTime() - start;
		printf("\n    done (in %.2f sec, %.2f KB/s)\n", dt, size_KB / dt);
		
		//Fill each cell of the device with its own address
		printf("Address filling entire device...\n");
		start = GetTime();
		for(unsigned int sector=0; sector<read_count; sector++)
		{
			printf("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b%u / %u", sector, read_count);
			fflush(stdout);
			
			unsigned int base = sector*512*4;
			for(unsigned int i=0; i<512; i++)
				data[i] = base+(i*4);
			
			for(unsigned int i=0; i<512; i += 64)
				iface.DMAWrite(faddr, base + (i*4), 64, data+i, NOR_WRITE_DONE, NOR_OP_FAILED);
			
		}
		dt = GetTime() - start;
		printf("\n    done (in %.2f sec, %.2f KB/s)\n", dt, size_KB / dt);
		
		//Verify
		printf("Verifying address fill...\n");
		start = GetTime();
		for(unsigned int sector=0; sector<read_count; sector++)
		{
			printf("\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b%u / %u", sector, read_count);
			fflush(stdout);
			
			unsigned int base = sector*512;
			
			for(unsigned int i=0; i<512; i++)
				data[i] = (base+i)*4;
			
			iface.DMARead(faddr, base*4, 512, rdata, NOR_OP_FAILED);
			for(int i=0; i<512; i++)
			{
				if(data[i] != rdata[i])
				{
					printf("    Mismatch (at word address %d, got %08x, expected %08x)\n",
						 i+base, rdata[i], data[i]);
					throw JtagExceptionWrapper(
						"Got bad data back from board",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			}
		}
		dt = GetTime() - start;
		printf("\n    done (in %.2f sec, %.2f KB/s)\n", dt, size_KB / dt);
		
		//Done
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
