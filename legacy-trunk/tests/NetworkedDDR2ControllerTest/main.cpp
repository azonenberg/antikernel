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
	@brief NetworkedDDR2Controller loopback test
	
	Sends data to and from the DDR2 controller and verifies correctness
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

void PermissionsTest(NOCSwitchInterface& ifaceA, NOCSwitchInterface& ifaceB, uint16_t raddr);
void AllocatorTest(NOCSwitchInterface& ifaceA, NOCSwitchInterface& ifaceB, uint16_t raddr);
void ZeroizeTest(NOCSwitchInterface& ifaceA, NOCSwitchInterface& ifaceB, uint16_t raddr);

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
		NOCSwitchInterface ifaceA;
		ifaceA.Connect(server, port);
		NOCSwitchInterface ifaceB;
		ifaceB.Connect(server, port);
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Address lookup
		printf("Looking up address of RAM\n");
		NameServer nameserver(&ifaceA, "ThisIsALongAndComplicatedPassword");
		NameServer nameserver2(&ifaceB, "ThisIsALongAndComplicatedPassword");
		uint16_t raddr = nameserver.ForwardLookup("ram");
		printf("RAM is at %04x\n", raddr);
		
		//Register us
		nameserver.Register("test1");
		nameserver2.Register("test2");
		
		//Wait for the RAM to initialize
		printf("Waiting for RAM to initialize...\n");
		RPCMessage rxm;
		double tstart = GetTime();
		ifaceA.RPCFunctionCallWithTimeout(raddr, RAM_GET_STATUS, 0, 0, 0, rxm, 10);
		if( (rxm.data[0] & 0x10000) != 0x10000)
		{
			throw JtagExceptionWrapper(
				"RAM status is not \"ready\"",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		double dt = GetTime() - tstart;
		printf("    RAM is ready (initialization took %.2f ms, %d pages free)\n", dt*1000, rxm.data[0] & 0xFFFF);
		
		//Run the actual tests
		AllocatorTest(ifaceA, ifaceB, raddr);
		ZeroizeTest(ifaceA, ifaceB, raddr);
		PermissionsTest(ifaceA, ifaceB, raddr);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

void PermissionsTest(NOCSwitchInterface& ifaceA, NOCSwitchInterface& ifaceB, uint16_t raddr)
{
	RPCMessage rxm;
	
	//Allocate some memory
	uint32_t ptrA = 0;
	uint16_t addrA = 0;
	printf("Allocating 1 page of memory (node A)\n");
	ifaceA.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
	ptrA = rxm.data[1];
	addrA = rxm.to;
	printf("    Host A (%04x) owns page at 0x%08x\n", addrA, ptrA);
	uint32_t ptrB = 0;
	uint16_t addrB = 0;
	printf("Allocating 1 page of memory (node B)\n");
	ifaceB.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
	ptrB = rxm.data[1];
	addrB = rxm.to;
	printf("    Host B (%04x) owns page at 0x%08x\n", addrB, ptrB);
	
	//Write to it
	int blocksize = 16;
	uint32_t data[512] = {0};
	unsigned int len = blocksize;
	for(int j=0; j<blocksize; j++)
		data[j] = rand();
	printf("Issuing DMA write (%d words to %08x)...\n", blocksize, ptrA);
	ifaceA.DMAWrite(raddr, ptrA, len, data, RAM_WRITE_DONE, RAM_OP_FAILED);
			
	//Read from the first block
	printf("Issuing DMA read (%d words from %08x)...\n", blocksize, ptrA);
	uint32_t rdata[512] = {0};
	ifaceA.DMARead(raddr, ptrA, blocksize, rdata, RAM_OP_FAILED);
	printf("    Got the data, checking...\n");
	for(int i=0; i<blocksize; i++)
	{
		if(data[i] != rdata[i])
		{
			printf("    Mismatch (at i=%d, got %08x, expected %08x)\n", i, rdata[i], data[i]);
			throw JtagExceptionWrapper(
				"Got bad data back from board",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
	printf("    OK\n");
	
	//Try writing to A's memory from B
	uint32_t datab[512] = {0};
	for(int i=0; i<blocksize; i++)
		datab[i] = 0xcccccccc;
	printf("Issuing illegal DMA write (%d words to %08x)...\n", blocksize, ptrA);
	try
	{
		ifaceB.DMAWrite(raddr, ptrA, blocksize, datab, RAM_WRITE_DONE, RAM_OP_FAILED);
		
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
	ifaceA.DMARead(raddr, ptrA, blocksize, rdata, RAM_OP_FAILED);
	printf("    Got the data, checking...\n");
	for(int i=0; i<blocksize; i++)
	{
		if(data[i] != rdata[i])
		{
			printf("    Mismatch (at i=%d, got %08x, expected %08x)\n", i, rdata[i], data[i]);
			throw JtagExceptionWrapper(
				"Got bad data back from board",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
	printf("    OK\n");
	
	//Try reading A's memory from B
	memset(rdata, 0, sizeof(rdata));
	printf("Issuing illegal DMA read (%d words from %08x)...\n", blocksize, ptrA);
	try
	{
		ifaceB.DMARead(raddr, ptrA, blocksize, rdata, RAM_OP_FAILED);
		
		throw JtagExceptionWrapper(
			"DMA write should have been denied, but was not",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	catch(const JtagException& ex)
	{
		printf("    OK\n");
	}	
	
	//Change A's memory to be owned by B
	printf("Changing page ownership to B..\n");
	ifaceA.RPCFunctionCall(raddr, RAM_CHOWN, 0, ptrA, addrB, rxm);
	
	//Verify we get NAK'd when we try to read the memory which is no longer ours
	printf("Issuing illegal DMA read (%d words from %08x)...\n", blocksize, ptrA);
	try
	{
		ifaceA.DMARead(raddr, ptrA, blocksize, rdata, RAM_OP_FAILED);
		
		throw JtagExceptionWrapper(
			"DMA write should have been denied, but was not",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	catch(const JtagException& ex)
	{
		printf("    OK\n");
	}	
	
	//Verify B can now read it
	printf("Issuing DMA read (%d words from %08x)...\n", blocksize, ptrA);
	memset(rdata, 0, sizeof(rdata));
	ifaceB.DMARead(raddr, ptrA, blocksize, rdata, RAM_OP_FAILED);
	printf("    Got the data, checking...\n");
	for(int i=0; i<blocksize; i++)
	{
		if(data[i] != rdata[i])
		{
			printf("    Mismatch (at i=%d, got %08x, expected %08x)\n", i, rdata[i], data[i]);
			throw JtagExceptionWrapper(
				"Got bad data back from board",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
	printf("    OK\n");
	
	//Query RAM status
	ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
	int pagecount = rxm.data[0] & 0xFFFF;
	printf("Querying status... %d pages free\n", pagecount);
	
	//Free the memory
	printf("Freeing memory...\n");
	ifaceB.RPCFunctionCall(raddr, RAM_FREE, 0, ptrA, 0, rxm);
	ifaceB.RPCFunctionCall(raddr, RAM_FREE, 0, ptrB, 0, rxm);
	
	//Query status again
	ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
	int pagecount2 = rxm.data[0] & 0xFFFF;
	printf("Querying status... %d pages free\n", pagecount2);
	if(pagecount2 != (pagecount + 2) )
	{
		throw JtagExceptionWrapper(
			"Memory doesn't seem to have been freed",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}

void AllocatorTest(NOCSwitchInterface& ifaceA, NOCSwitchInterface& /*ifaceB*/, uint16_t raddr)
{
	printf("Allocator test\n");
	
	RPCMessage rxm;
	
	ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
	uint32_t free_pages_start = rxm.data[0] & 0xFFFF;

	//Cap test at 4k pages for speed reasons
	uint32_t pages_left = free_pages_start;
	if(pages_left > 4096)
		pages_left = 4096;

	//Allocate all of RAM one page at a time
	vector<unsigned int> page_addresses;	
	while(pages_left --)
	{	
		//Allocate it
		ifaceA.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		unsigned int page = rxm.data[1];
		
		//Search the list to make sure it's not there
		for(auto spage : page_addresses)
		{
			if(page == spage)
			{
				printf("    Allocated %zu pages so far, then got guard page %08x\n",
					page_addresses.size(), spage);
				
				throw JtagExceptionWrapper(
					"Guard page showed up in free list",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		
		//Add it to the list
		page_addresses.push_back(page);
	}
	
	//See how much ram is currently left
	ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
	uint32_t free_pages_mid = rxm.data[0] & 0xFFFF;
	printf("Allocated %zu additional pages (%u left)\n", page_addresses.size(), free_pages_mid);
	if( (free_pages_mid + page_addresses.size()) != free_pages_start)
	{
		throw JtagExceptionWrapper(
			"Free page count at start and middle don't match up",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	
	//Free it all
	for(size_t i=0; i<page_addresses.size(); i++)
		ifaceA.RPCFunctionCall(raddr, RAM_FREE, 0, page_addresses[i], 0, rxm);
	
	//Verify all pages are free
	ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
	uint32_t free_pages_end = rxm.data[0] & 0xFFFF;
	if(free_pages_start != free_pages_end)
	{
		throw JtagExceptionWrapper(
			"Free page count at start and end don't match up",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	
	printf("Allocator test passed\n");
}

void ZeroizeTest(NOCSwitchInterface& ifaceA, NOCSwitchInterface& /*ifaceB*/, uint16_t raddr)
{
	RPCMessage rxm;
	
	unsigned int filler[512];
	unsigned int readback[512];
		
	//Fill all of memory
	printf("Filling memory\n");
	vector<unsigned int> page_addresses;
	while(true)
	{
		if(page_addresses.size() >= 4096)
			break;
		
		//Make sure we have pages left
		ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
		int free_pages = rxm.data[0] & 0xFFFF;
		if(free_pages == 0)
			break;
			
		//Allocate it
		ifaceA.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		unsigned int page = rxm.data[1];
		printf("    allocated %08x\n", page);
		page_addresses.push_back(page);

		//Fill it
		for(int i=0; i<512; i++)
			filler[i] = 0xfeed0000 + page + i;
		ifaceA.DMAWrite(raddr, page, 512, filler, RAM_WRITE_DONE, RAM_OP_FAILED);
	}
	printf("Filled %zu pages, reading back\n", page_addresses.size());
	
	//Read each page back
	for(size_t i=0; i<page_addresses.size(); i++)
	{
		unsigned int page = page_addresses[i];
		for(int j=0; j<512; j++)
			filler[j] = 0xfeed0000 + page + j;
		ifaceA.DMARead(raddr, page, 512, readback, RAM_OP_FAILED, 1);

		for(size_t j=0; j<512; j++)
		{
			if(readback[j] == filler[j])
				continue;
				
			printf("Readback error (page 0x%08x, offset %zu: got %08x, expected %08x\n",
				page, j, readback[j], filler[j]);
			
			throw JtagExceptionWrapper(
				"Page corrupted",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
		
	//Free all but the first page
	printf("Freeing all but first page\n");
	for(size_t i=1; i<page_addresses.size(); i++)
	{
		//printf("    %08x\n", page_addresses[i]);
		ifaceA.RPCFunctionCall(raddr, RAM_FREE, 0, page_addresses[i], 0, rxm);
	}
	printf("    Memory freed\n");
	
	//Make sure the allocated page was NOT zeroized
	unsigned int page = page_addresses[0];
	printf("Verifying first page (%08x) has not been touched\n", page);
	for(int j=0; j<512; j++)
		filler[j] = 0xfeed0000 + page + j;
	ifaceA.DMARead(raddr, page, 512, readback, RAM_OP_FAILED);
	for(size_t j=0; j<512; j++)
	{
		if(readback[j] == filler[j])
			continue;
			
		printf("Readback error (page 0x%08x, offset %zu: got %08x, expected %08x\n",
			page, j, readback[j], filler[j]);
		
		throw JtagExceptionWrapper(
			"Non-freed page was cleared but shouldn't have been!",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}

	printf("    Freeing first page\n");
	ifaceA.RPCFunctionCall(raddr, RAM_FREE, 0, page_addresses[0], 0, rxm);
	page_addresses.clear();
	
	//Re-allocate all memory and verify it's been cleared to zero
	printf("Reallocating and verifying memory is wiped\n");
	while(true)
	{
		if(page_addresses.size() > 4096)
			break;
		
		//Make sure we have pages left
		ifaceA.RPCFunctionCall(raddr, RAM_GET_STATUS, 0, 0, 0, rxm);
		int free_pages = rxm.data[0] & 0xFFFF;
		if(free_pages == 0)
			break;
			
		//Allocate it
		ifaceA.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		unsigned int page = rxm.data[1];
		page_addresses.push_back(page);
		
		//Verify it's zero
		ifaceA.DMARead(raddr, page, 512, readback, RAM_OP_FAILED);
		for(int i=0; i<512; i++)
		{
			if(readback[i] == 0)
				continue;
			printf("Readback error (page 0x%08x, offset %d, got non-clear value %08x\n", page, i, readback[i]);
			
			throw JtagExceptionWrapper(
				"Memory wasn't cleared",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
	printf("    Done, freeing\n");
	for(size_t i=0; i<page_addresses.size(); i++)
		ifaceA.RPCFunctionCall(raddr, RAM_FREE, 0, page_addresses[i], 0, rxm);
	page_addresses.clear();
	printf("    All pages freed\n");
}
