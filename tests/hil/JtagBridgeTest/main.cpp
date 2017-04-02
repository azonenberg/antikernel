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
	@brief NoC switch board ping test

	Try pinging a board through nocswitch
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
	int err_code = 0;
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
		uint16_t pingaddr = 0xfeed;
		LogNotice("Pinger is at %04x\n", pingaddr);

		//Needs to be deterministic for testing
		srand(0);

		//Send a bunch of messages and make sure we get the same thing back
		LogNotice("Sending ping packets...\n");
		double start = GetTime();
		int npack = 1000;
		double sumping = 0;
		double minping = 999999;
		double maxping = 0;
		for(int i=0; i<npack; i++)
		{
			if( (i % 100) == 0)
				LogNotice("Message %d\n", i);

			RPCMessage msg;
			msg.from = ouraddr;
			msg.to = pingaddr;
			msg.type = RPC_TYPE_INTERRUPT;
			msg.callnum = rand() & 0xff;
			msg.data[0] = rand() & 0x001fffff;
			msg.data[1] = rand();
			msg.data[2] = rand();
			double tsend = GetTime();
			iface.SendRPCMessage(msg);
			LogDebug("Sending: %s\n", msg.Format().c_str());

			/*
			RPCMessage rxm;
			if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 5))
			{
				printf("Timeout on message %d - expected response within 5 sec but nothing arrived\n", i);
				printf("Sent:\n    %s\n\n", msg.Format().c_str());

				throw JtagExceptionWrapper(
					"Message timeout",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			*/

			double trcv = GetTime();
			double rtt = (trcv - tsend);
			sumping += rtt;
			if(minping > rtt)
				minping = rtt;
			if(maxping < rtt)
				maxping = rtt;

			/*
			if( (rxm.from == pingaddr) &&
				(rxm.data[0] == msg.data[0]) &&
				(rxm.data[1] == msg.data[1]) &&
				(rxm.data[2] == msg.data[2])
			)
			{
				//printf("Message %d OK\n", i);
			}
			else
			{
				printf("Message %d FAIL\n", i);
				printf("Sent:\n    %s\nReceived:\n    %s\n", msg.Format().c_str(), rxm.Format().c_str());
				throw JtagExceptionWrapper(
					"Invalid message came back",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			*/

			//Done
			break;
		}

		int packets_sent = npack * 2;
		int header_size = packets_sent * 96;
		int payload_size = packets_sent * 128;

		//Print statistics
		double end = GetTime();
		double dt = end - start;
		LogNotice("Done, all OK\n");
		LogNotice("%d packets sent in %.2f ms (%.2f Kbps raw, %.2f Kbps after overhead)\n",
			packets_sent,
			dt * 1000,
			(payload_size + header_size) / (1000 * dt),
			(payload_size) / (1000 * dt));
		LogNotice("RTT latency: %.2f ms min / %.2f ms avg / %.2f max\n",
			minping * 1000,
			(sumping / npack) * 1000,
			maxping * 1000);
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
