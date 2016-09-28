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
	@brief NetworkedReconfigurablePLL test
	
	Tests the reconfigurable PLL
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"

#include "NetworkedReconfigurablePLL_opcodes_constants.h"
#include "NetworkedReconfigurablePLL_errcodes_constants.h"
#include "FrequencyCounter_opcodes_constants.h"

#include <signal.h>

using namespace std;

float ps_to_mhz(unsigned int ps);
void VerifyPeriod(unsigned int ps, unsigned int expected, unsigned int tolerance);

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
				i++;	//ignored
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
		
		//Register us in the name table
		NameServer nameserver(&iface, "ThisIsALongAndComplicatedPassword");
		nameserver.Register("testcase");
		
		//Address lookup
		printf("Looking up address of PLL\n");
		uint16_t paddr = nameserver.ForwardLookup("pll");
		printf("PLL is at %04x\n", paddr);
		uint16_t fcaddrs[6] = {0};
		char name[9];
		for(int i=0; i<6; i++)
		{
			snprintf(name, sizeof(name), "freqcnt%d", i);
			fcaddrs[i] = nameserver.ForwardLookup(name);
			printf("Frequency counter for channel %d is at %04x\n", i, fcaddrs[i]);
		}
		
		//Measure for 100K clk_noc cycles (~0.5 ms)
		//Note that this time cannot exceed 2^32 ps (about 4 ms) due to possible overflow errors
		int nmeasure = 100000;
		
		//Record the initial clock frequencies
		printf("Measuring initial clock frequencies...\n");
		RPCMessage rxm;
		for(int i=0; i<6; i++)
		{
			iface.RPCFunctionCall(fcaddrs[i], FREQCNT_OP_MEASURE, 0, nmeasure, 0, rxm);
			float mhz = ps_to_mhz(rxm.data[2]);
			printf("    Channel %d: %.2f MHz\n", i, mhz);
			VerifyPeriod(rxm.data[2], 5000, 50);
		}
		
		//Make all outputs the same
		printf("Reconfiguring all outputs to 100 MHz...\n");
		for(int i=0; i<6; i++)
			iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (i << 10) | 100, 10000, 0, rxm);	//100 MHz +/- 100 ps
		iface.RPCFunctionCall(paddr, PLL_OP_RESTART, 0, 0, 0, rxm);
		
		//Verify everything is good
		printf("Testing...\n");
		for(int i=0; i<6; i++)
		{
			iface.RPCFunctionCall(fcaddrs[i], FREQCNT_OP_MEASURE, 0, nmeasure, 0, rxm);
			float mhz = ps_to_mhz(rxm.data[2]);
			printf("    Channel %d: %.2f MHz\n", i, mhz);
			VerifyPeriod(rxm.data[2], 10000, 50);
		}
		
		//Try a couple different frequencies
		const int target_periods[6] =
		{ 5000, 10000, 20000, 40000, 10000, 80000 };
		printf("Reconfiguring to mixed frequencies...\n");
		for(int i=0; i<6; i++)
			iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (i << 10) | 100, target_periods[i], 0, rxm);
		iface.RPCFunctionCall(paddr, PLL_OP_RESTART, 0, 0, 0, rxm);
		
		//Make sure this worked
		printf("Testing...\n");
		for(int i=0; i<6; i++)
		{
			iface.RPCFunctionCall(fcaddrs[i], FREQCNT_OP_MEASURE, 0, nmeasure, 0, rxm);
			float mhz = ps_to_mhz(rxm.data[2]);
			printf("    Channel %d: %.2f MHz\n", i, mhz);
			VerifyPeriod(rxm.data[2], target_periods[i], 100);
		}
		
		//Do a weird mix of clock frequencies that isn't satisfiable
		printf("Trying un-satisfiable combination of outputs\n");
		iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (0 << 10) | 100,  8000, 0, rxm);	//125 MHz +/- 100 ps
		iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (1 << 10) | 100,  6667, 0, rxm);	//150 MHz +/- 100 ps
		iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (2 << 10) | 100, 10000, 0, rxm);	//100 MHz +/- 100 ps
		iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (3 << 10) | 100, 13333, 0, rxm);	// 75 MHz +/- 100 ps
		iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (4 << 10) | 100, 20000, 0, rxm);	// 50 MHz +/- 100 ps
		iface.RPCFunctionCall(paddr, PLL_OP_RECONFIG, (5 << 10) | 100,  5000, 0, rxm);	//200 MHz +/- 100 ps
		try
		{
			iface.RPCFunctionCall(paddr, PLL_OP_RESTART, 0, 0, 0, rxm);
			printf("Should have failed to reconfigure, but didn't\n");
			err_code = 1;
		}
		catch(const JtagException& ex)
		{
			printf("Got expected exception\n");
		}
		
		printf("All good\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

float ps_to_mhz(unsigned int ps)
{
	return 1000000.0f / ps;
}

void VerifyPeriod(unsigned int ps, unsigned int expected, unsigned int tolerance)
{
	long delta = abs(static_cast<long>(ps) - static_cast<long>(expected));
	if(delta > tolerance)
	{
		printf("Got period of %u ps, expected %u ± %u (delta=%ld)\n", ps, expected, tolerance, delta);
		throw JtagExceptionWrapper(
			"Clock period is out of tolerance",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}
