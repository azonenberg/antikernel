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

		int ndrive_raw = 3;
		int nsample_raw = 4;

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--drive")
				ndrive_raw = atoi(argv[++i]);
			else if(s == "--sample")
				nsample_raw = atoi(argv[++i]);
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

		//Map pin to channel numbers
		int ndrive = 0;
		int nsample = 0;
		switch(ndrive_raw)
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
			default:
				LogError("Invalid drive pin\n");
				break;
		}
		switch(nsample_raw)
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
			default:
				LogError("Invalid sample pin\n");
				break;
		}

		//Sanity check
		if(ndrive == nsample)
		{
			LogError("Cannot drive and sample same channel number\n");
			return 1;
		}

		//Measure round trip time with each delay
		float nmin = 10000;
		float nmax = 0;
		float nsum = 0;
		int navg = 25;
		for(int j = 0; j < navg; j ++)
		{
			const float ns_per_sample = 2.5;
			const float ns_per_delay = ns_per_sample / 32;
			int edge_tap = 0;
			int edge_sample = 0;
			float delay_ns = 0;
			for(int ntap=0; ntap<32; ntap++)
			{
				RPCMessage msg;
				msg.from = ouraddr;
				msg.to = dutaddr;
				msg.type = RPC_TYPE_CALL;
				msg.callnum = 0;
				msg.data[0] = ntap;
				msg.data[1] = (ndrive << 2) | nsample;
				msg.data[2] = 0;
				iface.SendRPCMessage(msg);

				RPCMessage rxm;
				if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 5))
				{
					LogError("no response\n");
					return 1;
				}

				//Record the position of the 0-to-1 edge
				int edge_w1 = 0;
				int edge_w2 = 0;
				for(int i = 0; i<32; i++)
				{
					if( (rxm.data[1] >> i) & 1)
						edge_w1 = 32 - i;

					if( (rxm.data[2] >> i) & 1 )
						edge_w2 = 32 - i;
				}

				//The two words are interleaved, d1 then d2
				//Find the full edge point
				int edgepos = edge_w1 * 2;
				if(edge_w2 > edge_w1)
					edgepos ++;

				//Apply the correction for the delay tap
				delay_ns = edge_sample * ns_per_sample;
				delay_ns += ns_per_delay * ntap;

				if(j == 0)
					LogDebug("Tap %d: sample %d (%.3f ns)\n", ntap, edgepos, delay_ns);

				if(ntap == 0)
					edge_sample = edgepos;
				edge_tap = ntap;

				if(edgepos > edge_sample)
					break;
			}

			//Convert sample number to ns
			LogDebug("Final edge found at tap %d, sample %d, delay = %.3f ns\n",
				edge_tap, edge_sample, delay_ns);

			if(delay_ns < nmin)
				nmin = delay_ns;
			if(delay_ns > nmax)
				nmax = delay_ns;
			nsum += delay_ns;
		}

		LogNotice("rtt min/avg/max = %.3f / %.3f / %.3f ns\n", nmin, nmax, nsum/navg);
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	//Done
	return 0;
}
