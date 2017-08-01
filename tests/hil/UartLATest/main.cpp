/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief UART logic analyzer test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../../src/scopehal/scopehal.h"
#include "../../../src/scopehal/RedTinLogicAnalyzer.h"

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
		string tty;

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
				tty = argv[++i];
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

		//Create the LA and connect to the DUT to download the channel configs
		LogNotice("Connecting to logic analyzer...\n");
		RedTinLogicAnalyzer la(tty, 115200);

		//See what we've got
		size_t count = la.GetChannelCount();
		LogNotice("LA has %zu channels\n", count);
		for(size_t i=0; i<count; i++)
		{
			auto channel = la.GetChannel(i);
			LogNotice("[%2zu] %16s: %2d bits, color %s\n",
				i,
				channel->m_displayname.c_str(),
				channel->GetWidth(),
				channel->m_displaycolor.c_str());
		}

		//Set up triggers
		LogNotice("Setting up triggers...\n");
		la.ResetTriggerConditions();
		vector<Oscilloscope::TriggerType> triggers;
		triggers.push_back(Oscilloscope::TRIGGER_TYPE_HIGH);
		la.SetTriggerForChannel(la.GetChannel("rpc_rx_en"), triggers);

		//Start the capture
		LogNotice("Starting LA...\n");
		la.StartSingleTrigger();

		//Needs to be deterministic for testing
		srand(0);

		//Generate some activity
		LogNotice("Generating some traffic to sniff...\n");
		RPCMessage msg;
		msg.from = ouraddr;
		msg.to = pingaddr;
		msg.type = RPC_TYPE_INTERRUPT;
		msg.callnum = rand() & 0xff;
		msg.data[0] = rand() & 0x001fffff;
		msg.data[1] = rand();
		msg.data[2] = rand();
		iface.SendRPCMessage(msg);

		//Don't care about reply, just throw it away
		RPCMessage rxm;
		if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 5))
		{
			LogError("Timeout on message - expected response within 5 sec but nothing arrived\n");
			LogVerbose("Sent:\n    %s\n\n", msg.Format().c_str());

			throw JtagExceptionWrapper(
				"Message timeout",
				"");
		}

		//Expect capture
		usleep(100 * 1000);
		LogNotice("Checking for trigger...\n");
		if(la.PollTrigger() != Oscilloscope::TRIGGER_MODE_TRIGGERED)
		{
			throw JtagExceptionWrapper(
				"Expected scope to trigger but it didn't",
				"");
		}

		//Pull the data
		sigc::slot1<int, float> null_callback;
		la.AcquireData(null_callback);

		//TODO: Do something with it
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
