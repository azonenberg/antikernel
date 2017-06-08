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

float RunTest(
	NOCSwitchInterface& iface,
	uint16_t ouraddr,
	uint16_t dutaddr,
	unsigned int drive,
	unsigned int sample,
	unsigned int polarity);

int main(int argc, char* argv[])
{
	try
	{
		Severity console_verbosity = Severity::NOTICE;
		string server;
		int port = 0;
		int lport = 53000;

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--lport")
				lport = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
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

		LogVerbose("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);

		//Allocate an address for us
		uint16_t ouraddr;
		if(!iface.AllocateClientAddress(ouraddr))
		{
			LogError("Couldn't allocate an address\n");
			return 1;
		}
		LogVerbose("Got address %04x\n", ouraddr);

		//Address lookup
		//printf("Looking up address of RPC pinger\n");
		//NameServer nameserver(&iface);
		//uint16_t pingaddr = nameserver.ForwardLookup("rpcping");
		uint16_t dutaddr = 0x8000;
		LogVerbose("DUT is at %04x\n", dutaddr);

		//Create our listening socket
		Socket sock(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
		if(!sock.DisableNagle())
		{
			LogError("Couldn't disable Nagle\n");
			return 1;
		}
		if(!sock.Bind(lport))
		{
			LogError("Couldn't bind socket\n");
			return 1;
		}
		if(!sock.Listen())
		{
			LogError("Couldn't listen to socket\n");
			return 1;
		}

		//Wait for connections and crunch them
		while(true)
		{
			Socket client = sock.Accept();
			if(!client.DisableNagle())
			{
				LogError("Couldn't disable Nagle\n");
				return 1;
			}
			while(true)
			{
				/*
				Read test parameters
					uint8_t		drive_channel
					uint8_t		sample_channel
					uint8_t		test_polarity
									0 = drive low, expect low
									1 = drive low, expect high
									2 = drive high, expect low
									3 = drive high, expect high
				*/
				uint8_t rxbuf[3];
				if(!client.RecvLooped(rxbuf, sizeof(rxbuf)))
					break;

				//Run the actual test
				float latency = RunTest(iface, ouraddr, dutaddr, rxbuf[0], rxbuf[1], rxbuf[2]);

				/*
				Send results back to the server
					uint8_t		ok
					float		latency
				*/
				uint8_t		ok = (latency > 0);
				if(!client.SendLooped(&ok, 1))
					break;
				if(!client.SendLooped((unsigned char*)&latency, sizeof(latency)))
					break;
			}
		}
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	//Done
	return 0;
}

float RunTest(
	NOCSwitchInterface& iface,
	uint16_t ouraddr,
	uint16_t dutaddr,
	unsigned int drive,
	unsigned int sample,
	unsigned int polarity)
{
	LogVerbose("Running test: drive pin %u, sample pin %u, drive value %d, expect value %d\n",
		drive, sample, polarity >> 1, polarity & 1);

	//Map pin to channel numbers
	int ndrive = 0;
	int nsample = 0;
	switch(drive)
	{
		case 3:
			ndrive = 0;
			break;
		case 5:
			ndrive = 1;
			break;
		case 4:
			ndrive = 2;
			break;
		case 13:
			ndrive = 3;
			break;
		case 15:
			ndrive = 4;
			break;
		case 14:
			ndrive = 5;
			break;
		default:
			LogError("Invalid drive pin\n");
			break;
	}
	switch(sample)
	{
		case 3:
			nsample = 0;
			break;
		case 5:
			nsample = 1;
			break;
		case 4:
			nsample = 2;
			break;
		case 13:
			nsample = 3;
			break;
		case 15:
			nsample = 4;
			break;
		case 14:
			nsample = 5;
			break;
		default:
			LogError("Invalid sample pin\n");
			break;
	}

	//Sanity check
	if(ndrive == nsample)
	{
		LogError("Cannot drive and sample same channel number\n");
		return -1;
	}

	//Measure round trip time with each delay
	float nmin = 10000;
	float nmax = 0;
	float nsum = 0;
	int navg = 100;
	bool fail = false;
	for(int j = 0; j < navg; j ++)
	{
		const float ns_per_sample = 2.5;
		const float ns_per_tap = ns_per_sample / 32;
		float delay_ns = 10000000;

		//Send the single test request
		RPCMessage msg;
		msg.from = ouraddr;
		msg.to = dutaddr;
		msg.type = RPC_TYPE_CALL;
		msg.callnum = 0;
		msg.data[0] = polarity;
		msg.data[1] = (ndrive << 3) | nsample;
		msg.data[2] = 0;
		iface.SendRPCMessage(msg);

		//then receive the results in sequence
		bool skipping = false;
		for(int ntap=0; ntap<32; ntap++)
		{
			RPCMessage rxm;
			if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 5))
			{
				LogError("no response\n");
				return -1;
			}

			//need to still read and discard the message!
			if(skipping)
				continue;

			//Record the position of the edge
			int edgepos = rxm.data[1];
			float new_delay = edgepos * ns_per_tap;

			if(j == 0)
				LogDebug("Tap %d: sample %d (%.3f ns)\n", ntap, edgepos, delay_ns);

			//If it failed, we have an open circuit (or stupidly long wire) - complain!
			if( (rxm.type != RPC_TYPE_RETURN_SUCCESS) || (rxm.data[1] == 0) || (rxm.data[1] >= 0x1fffff) )
			{
				LogError("No edge found within 64k clocks (open circuit?)\n");
				fail = true;
				skipping = true;
				continue;
			}

			//Stop if we hit the edge
			if(new_delay > delay_ns)
			{
				if(j == 0)
					LogDebug("Stopping (edgepos = %d)\n", edgepos);
				skipping = true;
				continue;
			}

			//Apply the correction for the delay tap
			delay_ns = new_delay;
		}

		if(delay_ns < nmin)
			nmin = delay_ns;
		if(delay_ns > nmax)
			nmax = delay_ns;
		nsum += delay_ns;
	}

	if(fail)
		return -1;

	LogNotice("rtt min/avg/max = %.3f / %.3f / %.3f ns\n", nmin, nmax, nsum/navg);
	return nsum / navg;
}
