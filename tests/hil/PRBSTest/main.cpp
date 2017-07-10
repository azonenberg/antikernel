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
	@brief PRBS loopback etc test
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

		//LogNotice("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);

		//Allocate an address for us
		uint16_t ouraddr;
		if(!iface.AllocateClientAddress(ouraddr))
		{
			LogError("Couldn't allocate an address\n");
			return 1;
		}
		//LogNotice("Got address %04x\n", ouraddr);

		//Address lookup
		//printf("Looking up address of RPC pinger\n");
		//NameServer nameserver(&iface);
		//uint16_t pingaddr = nameserver.ForwardLookup("rpcping");
		uint16_t scopeaddr = 0xfe00;
		//LogNotice("Scope is at %04x\n", scopeaddr);

		//Sweep the DAC in a sawtooth pattern
		//(note: actual DAC resolution is 12 bits, we send 16 for future proofing.
		const unsigned int num_ypoints = 4096;
		const unsigned int codemax = 65536;
		const unsigned int codestep = codemax / num_ypoints;
		const unsigned int navg = 4;
		const unsigned int nphase = 40;
		const unsigned int sync_taps = 3;
		const bool eye_plot = true;
		unsigned int sample_values[num_ypoints][nphase][navg] = {0};
		//unsigned int sample_blocks[num_ypoints][nphase][navg] = {0};
		for(unsigned int adc_code=0; adc_code<codemax; adc_code += codestep)
		{
			//Set up the DAC
			RPCMessage msg;
			msg.from = ouraddr;
			msg.to = scopeaddr;
			msg.type = RPC_TYPE_CALL;
			msg.callnum = 0;
			msg.data[0] = adc_code;
			msg.data[1] = 0;
			msg.data[2] = 0;
			iface.SendRPCMessage(msg);
			//LogDebug("Sending: %s\n", msg.Format().c_str());

			RPCMessage rxm;
			if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 1))
			{
				LogError("Timeout! expected response within 1 sec but nothing arrived\n");
				LogVerbose("Sent:\n    %s\n\n", msg.Format().c_str());
				return -1;
			}
			//should just be an acknowledgement
			//LogDebug("Got: %s\n", rxm.Format().c_str());

			//Set up the PLL
			//VCO runs at 1.25 GHz for now (800 ps)
			//Sample clock is 250 MHz (4000 ps)
			//Measurement unit is 1/8 VCO period (100 ps)
			//Total sweep range is 0...40
			for(unsigned int phase = 0; phase < nphase; phase ++)
			{
				//Set up the PLL
				msg.callnum = 2;
				msg.data[0] = phase;
				msg.data[1] = 0;
				msg.data[2] = 0;
				iface.SendRPCMessage(msg);
				//LogDebug("Sending: %s\n", msg.Format().c_str());

				if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 1))
				{
					LogError("Timeout! expected response within 1 sec but nothing arrived\n");
					LogVerbose("Sent:\n    %s\n\n", msg.Format().c_str());
					return -1;
				}
				//should just be an acknowledgement
				//LogDebug("Got: %s\n", rxm.Format().c_str());

				//Repeat for a couple of averages
				for(unsigned int avg_pass=0; avg_pass<navg; avg_pass++)
				{
					//DAC is set up! Send a PRBS and return the results
					//Record for 64 samples in one RPC message
					msg.callnum = 1;
					msg.data[0] = 0;
					msg.data[1] = 0;
					msg.data[2] = 0;
					iface.SendRPCMessage(msg);

					//Read 4 blocks of samples
					for(int nblock=0; nblock<4; nblock++)
					{
						if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 1))
						{
							LogError("Timeout! expected response %d within 1 sec but nothing arrived\n", nblock);
							LogVerbose("Sent:\n    %s\n\n", msg.Format().c_str());
							return -1;
						}

						//This is the readings from our current test! Record them
						int base = 64*nblock;				//Number of samples per RPC result
						for(int nbit=0; nbit<32; nbit++)
						{
							int bk = base + nbit;		//Number of the sample we're looking at
														//(within this phase)
							if( (rxm.data[1] >> nbit) & 1 )
								sample_values[bk][phase][avg_pass] = adc_code / codestep;
							if( (rxm.data[2] >> nbit) & 1 )
								sample_values[bk + 32][phase][avg_pass] = adc_code / codestep;

							//sample_blocks[bk][phase][avg_pass] = nblock*2;
							//sample_blocks[bk + 32][phase][avg_pass] = nblock*2 + 1;
						}
					}
				}
			}
		}

		//DAC code scale: 3.3V is full scale DAC output
		//Input is attenuated by a factor of 2 (3 dB) so compensate for that
		//(but we also have a 20x probe)
		//float scale = 1.0f / num_ypoints;
		float scale = 1.0f;

		//Do final CSV export
		//LogDebug("time (ps),voltage\n");
		LogDebug("time (ns), voltage, nscan, phase\n");
		for(unsigned int t=0; t<num_ypoints; t++)
		{
			for(unsigned int phase=0; phase<nphase; phase++)
			{
				//Raw time for a waveform plot instead of an eye
				float ns = 4*t + phase * 0.1f;

				//DEBUG WORKAROUND: Shift first few phases by one full cycle
				//TODO: seems like variable synchronizer latency? Have to calibrate somehow
				if(phase < sync_taps)
					ns += 4;

				//There's some delay in the wires etc. Add a further phase shift to center our eye in the plot
				ns -= 1;

				//float ns = (phase * 0.1f) - 1.7;
				//float ns = (t%4)*4 + phase*0.1f;
				//ns -= 6;

				const float eye_width = 2;	//2 ns = 500 Mbps
				const float halfwidth = eye_width / 2;
				if(eye_plot)
				{
					//Convert time to UIs
					ns = fmodf(ns, eye_width);

					//Center it fully
					ns -= halfwidth;
				}

				//Convert to picoseconds so we have a nicer looking label
				//float ps = ns * 1000;

				for(unsigned int n=0; n<navg; n++)
				{
					LogDebug("%.3f, %.3f, %d, %d\n",
						ns,
						sample_values[t][phase][n] * scale,
						n,
						phase);

					if(eye_plot)
					{
						//Make copies left and right to complete the eye
						LogDebug("%.3f, %.3f, %d, %d\n",
							ns - eye_width,
							sample_values[t][phase][n] * scale,
							n,
							phase);

						LogDebug("%.3f, %.3f, %d, %d\n",
							ns + eye_width,
							sample_values[t][phase][n] * scale,
							n,
							phase);
					}
				}
			}
		}
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
