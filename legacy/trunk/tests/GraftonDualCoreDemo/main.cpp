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
	@brief GRAFTON dual core unit test
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
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>

#include <signal.h>

using namespace std;

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

		//Wait for the RAM to initialize
		usleep(250 * 1000);

		//Run the actual tests
		NameServer nameserver(&iface);
		
		//Look up the addresses of each host
		uint16_t taddr = iface.GetClientAddress();
		printf("We are at %04x\n", taddr);
		uint16_t raddr = nameserver.ForwardLookup("ram");
		printf("ram is at %04x\n", raddr);
		uint16_t c0addr = nameserver.ForwardLookup("core0");
		printf("core0 is at %04x\n", c0addr);
		uint16_t c1addr = nameserver.ForwardLookup("core1");
		printf("core1 is at %04x\n", c1addr);
		
		//Wait for the RAM to initialize
		printf("Waiting for RAM to initialize...\n");
		RPCMessage rxm;
		double tstart = GetTime();
		iface.RPCFunctionCallWithTimeout(raddr, RAM_GET_STATUS, 0, 0, 0, rxm, 10);
		if( (rxm.data[0] & 0x10000) != 0x10000)
		{
			throw JtagExceptionWrapper(
				"RAM status is not \"ready\"",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		double dt = GetTime() - tstart;
		unsigned int free_pages = rxm.data[0] & 0xFFFF;
		printf("    RAM is ready (initialization took %.2f ms, %u pages / %.2f MB free)\n",
			dt*1000, free_pages, free_pages / 512.0f );
		
		//Verify both cores are alive and responding
		printf("Checking cores are alive...\n");
		iface.RPCFunctionCallWithTimeout(c0addr, 0, 0, 0, 0, rxm, 5);
		if(rxm.data[0] != 42)
		{
			throw JtagExceptionWrapper(
				"Core 0 status is not \"ready\"",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		printf("    Core 0 ready\n");
		iface.RPCFunctionCallWithTimeout(c1addr, 0, 0, 0, 0, rxm, 5);
		if(rxm.data[0] != 101)
		{
			throw JtagExceptionWrapper(
				"Core 1 status is not \"ready\"",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		printf("    Core 1 ready\n");
		
		//Allocate a page of memory and put some text in it
		printf("Doing crypto test...\n");
		iface.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
		uint32_t ptr = rxm.data[1];
		printf("    String is at 0x%08x\n", ptr);
		uint32_t data[512] = {0};
		strncpy((char*)data, "Hello World!", 2047);	//3 words
		iface.DMAWrite(raddr, ptr, 4, data, RAM_WRITE_DONE, RAM_OP_FAILED);
		
		//ROT13 it
		printf("    Setting crypto to ROT13\n");
		iface.RPCFunctionCallWithTimeout(c0addr, 1, 13, 0, 0, rxm, 5);
		printf("    Encrypting string\n");
		iface.RPCFunctionCallWithTimeout(raddr, RAM_CHOWN, 0, ptr, c0addr, rxm, 5);
		iface.RPCFunctionCallWithTimeout(c0addr, 2, raddr, ptr, 12, rxm, 5);
		
		//Read it back
		uint32_t rdata[512] = {0};
		iface.DMARead(raddr, ptr, 4, rdata, RAM_OP_FAILED);
		char* pstr = (char*)rdata;
		printf("    Encrypted string is %s\n", pstr);
		if(strcmp(pstr, "URYYB JBEYQ!") != 0)
		{
			throw JtagExceptionWrapper(
				"Got bad ciphertext back from board",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Tell the attack processor to try sniffing the data
		//Uncomment the line below to demonstrate what happens if we have permission
		//iface.RPCFunctionCallWithTimeout(raddr, RAM_CHOWN, 0, ptr, c1addr, rxm, 5);
		printf("Running attack...\n");
		try
		{
			iface.RPCFunctionCallWithTimeout(c1addr, 1, raddr, ptr, 0, rxm, 5);
			
			printf("Got return from attack (should not have!): %08x\n", rxm.data[1]);
			throw JtagExceptionWrapper(
				"Core 1 should have segfaulted, but didn't",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		catch(const JtagException& ex)
		{
			printf("    Got expected timeout exception from core 1  (should now be segfaulted)\n");
		}
		
		//Verify core 0 is still good
		printf("Checking cores are alive...\n");
		iface.RPCFunctionCallWithTimeout(c0addr, 0, 0, 0, 0, rxm, 5);
		if(rxm.data[0] != 42)
		{
			throw JtagExceptionWrapper(
				"Core 0 status is not \"ready\"",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		printf("    Core 0 ready\n");
				
		//Send it a hello and make sure it hangs
		try
		{
			iface.RPCFunctionCallWithTimeout(c1addr, 0, 0, 0, 0, rxm, 5);
			throw JtagExceptionWrapper(
				"Core 1 should have segfaulted, but didn't",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		catch(const JtagException& ex)
		{
			printf("    Got expected timeout exception from core 1 (should now be segfaulted)\n");
		}
		
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
