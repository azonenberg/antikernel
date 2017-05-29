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
	@brief GreenPAK timing characterization
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../../src/jtaghal/jtaghal.h"
#include "../../../src/nocbridge/nocbridge.h"

#include "RPCv3Transceiver_types_enum.h"

using namespace std;

int main(int argc, char* argv[])
{
	try
	{
		Severity console_verbosity = Severity::NOTICE;
		string server;
		int port = 0;

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

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

		//Set up logging
		g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

		//Connect to the server
		if( (server == "") || (port == 0) )
		{
			LogError("No server or port name specified\n");
			return 1;
		}

		LogNotice("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);

		//Allocate an address for us
		uint16_t ouraddr;
		if(!iface.AllocateClientAddress(ouraddr))
		{
			LogError("Couldn't allocate an address\n");
			return 1;
		}
		LogNotice("Got address %04x\n", ouraddr);

		//Address lookup
		//printf("Looking up address of RPC pinger\n");
		//NameServer nameserver(&iface);
		//uint16_t pingaddr = nameserver.ForwardLookup("rpcping");
		uint16_t dutaddr = 0x8000;
		LogNotice("DUT is at %04x\n", dutaddr);

		//Send a hello message
		RPCMessage msg;
		msg.from = ouraddr;
		msg.to = dutaddr;
		msg.type = RPC_TYPE_CALL;
		msg.callnum = 0;
		msg.data[0] = 0;	//TODO: delay setting
		msg.data[1] = 0;
		msg.data[2] = 0;
		iface.SendRPCMessage(msg);

		RPCMessage rxm;
		if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 5))
		{
			LogError("no response\n");
			return 1;
		}
		LogDebug("Got: %s\n", rxm.Format().c_str());
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	//Done
	return 0;
}
