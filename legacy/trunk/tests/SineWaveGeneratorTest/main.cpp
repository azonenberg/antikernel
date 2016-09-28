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
	@brief Functional test for NetworkedSineWaveGenerator
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

#include <NetworkedSineWaveGenerator_opcodes_constants.h>

#include <signal.h>

using namespace std;

float Twos16BitToFloat(int x);

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
		
		//Address lookup
		printf("Looking up address of sinewave generator\n");
		NameServer nameserver(&iface);
		uint16_t saddr = nameserver.ForwardLookup("sine");
		printf("Table is at %04x\n", saddr);
		
		//Look up the sines of all angles from 0 to 360 degrees, in 12-bit fixed point
		printf("Running sine test\n");
		RPCMessage rxm;
		int nmax = 4096;
		for(int i=0; i<nmax; i++)
		{
			iface.RPCFunctionCall(saddr, TRIG_OP_SINCOS, i, 0, 0, rxm);
			
			//Convert everything to floating point
			//Special stuff needed since we have weird sized twos complement values			
			float theta = static_cast<float>(i) * M_PI * 2 / nmax;
			float theta_deg = static_cast<float>(i) * 360 / nmax;
			float sdat = Twos16BitToFloat(rxm.data[1]);
			float cdat = Twos16BitToFloat(rxm.data[2]);
			
			//Compute the actual trig functions and measure deltas
			float expected_sin = sin(theta);
			float expected_cos = cos(theta);
			float dsin = sdat - expected_sin;
			float dcos = cdat - expected_cos;
			
			//Verify they're good (within 0.025% of the actual value)
			const float tolerance = 0.0025f;
			if(fabs(dsin) > tolerance)
			{
				printf("Got sin(%f rad / %f deg) = %f, expected %f (delta = %f)\n",
					theta, theta_deg, sdat, expected_sin, dsin);
				err_code = 1;
			}
			if(fabs(dcos) > tolerance)
			{
				printf("Got cos(%f rad / %f deg) = %f, expected %f (delta = %f)\n",
					theta, theta_deg, cdat, expected_cos, dcos);
				err_code = 1;
			}
		}
		printf("OK\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

float Twos16BitToFloat(int x)
{
	//Negative? Flip it
	if(x & 0x8000)
		x = - ( (~x + 1) & 0xffff);
			
	//Scale
	return static_cast<float>(x) / 32767;
}
