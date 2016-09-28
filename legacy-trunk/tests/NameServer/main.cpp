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
	@brief Name server test
	
	Sanity checks the name server
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
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		
		//Initialize the board
		LX9MiniBoard board(&iface);
		board.InitializeBoard(true);
		
		//Get a few pointers
		//No need to validate at this point, InitializeBoard() made sure everything is OK
		FPGA* pfpga = dynamic_cast<FPGA*>(board.GetDefaultDevice());
				
		//Probe the FPGA to find virtual TAPs
		pfpga->ProbeVirtualTAPs();
		
		//Set up the name server
		printf("Loading name table...\n");
		NameServer namesvr(
			dynamic_cast<RPCAndDMANetworkInterface*>(pfpga),
			"ThisIsALongAndComplicatedPassword");
		namesvr.LoadHostnames(true);

		//Verify that the RPC pinger exists
		int namesvr_addr = namesvr.ForwardLookup("rpcping");
		printf("Address = %04x\n", namesvr_addr);
		string rsvr = namesvr.ReverseLookup(namesvr_addr);
		printf("Reverse: %s\n", rsvr.c_str());
		if(rsvr != "rpcping")
		{
			throw JtagExceptionWrapper(
				"Consistency check on RPC pinger failed",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}

		//Do the same thing with an uncached lookup
		namesvr_addr = namesvr.ForwardLookupUncached("rpcping");
		printf("Uncached address = %04x\n", namesvr_addr);
		rsvr = namesvr.ReverseLookupUncached(namesvr_addr);
		printf("Uncached reverse: %s\n", rsvr.c_str());
		if(rsvr != "rpcping")
		{
			throw JtagExceptionWrapper(
				"Consistency check on RPC pinger failed",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Register us in the name table
		namesvr.Register("testcase");
		
		//Do a lookup and verify it's good
		if(namesvr.ForwardLookupUncached("testcase") != 0xc000)
		{
			throw JtagExceptionWrapper(
				"Sanity check on our own address failed",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Attempt to register us again (should fail)
		try
		{
			namesvr.Register("testcase");
			
			printf("Second name registration should have failed, but did not!\n");
			printf("Dumping name table again for debugging\n");
			err_code = 1;
		}
		catch(const JtagException& ex)
		{
			printf("Duplicate name registration failed, as it should have\n");
		}
		
		//Dump the name table again
		printf("Reloading name table...\n");
		namesvr.LoadHostnames(true);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
