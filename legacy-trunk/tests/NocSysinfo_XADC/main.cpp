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
	@brief NOCSysinfo ADC test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/UART.h"
#include "../../src/jtagboards/jtagboards.h"

#include <NOCSysinfo_constants.h>
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

#include <signal.h>

using namespace std;

float GetFixedPointValue(unsigned int din);

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
		printf("Looking up address of sysinfo\n");
		NameServer nameserver(&iface);
		uint16_t saddr = nameserver.ForwardLookup("sysinfo");
		printf("Sysinfo is at %04x\n", saddr);
		
		//Print out and verify the the die temp
		printf("Querying stuff...\n");
		RPCMessage rxm;
		iface.RPCFunctionCall(saddr, SYSINFO_GET_TEMP, 0, 0, 0, rxm);
		float temp = GetFixedPointValue(rxm.data[1]);
		printf("    Die temp = %.2f C\n", temp);
		if( (temp < 5) || (temp > 70) )
		{
			throw JtagExceptionWrapper(
				"Die temperature out of range",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Print out and verify VCCINT
		iface.RPCFunctionCall(saddr, SYSINFO_GET_VCORE, 0, 0, 0, rxm);
		float voltage = GetFixedPointValue(rxm.data[1]);
		float vmin = GetFixedPointValue(rxm.data[2] & 0xffff);
		float vmax = GetFixedPointValue(rxm.data[2] >> 16);
		printf("    VCCINT   = %.2f V (legal range = %.2f - %.2f)\n", voltage, vmin, vmax);
		if( (voltage < vmin) || (voltage > vmax) )
		{
			throw JtagExceptionWrapper(
				"VCCINT voltage out of range",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Print out and verify VCCBRAM
		iface.RPCFunctionCall(saddr, SYSINFO_GET_VRAM, 0, 0, 0, rxm);
		voltage = GetFixedPointValue(rxm.data[1]);
		vmin = GetFixedPointValue(rxm.data[2] & 0xffff);
		vmax = GetFixedPointValue(rxm.data[2] >> 16);
		printf("    VCCBRAM  = %.2f V (legal range = %.2f - %.2f)\n", voltage, vmin, vmax);
		if( (voltage < vmin) || (voltage > vmax) )
		{
			throw JtagExceptionWrapper(
				"VCCBRAM voltage out of range",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Print out and verify VCCAUX
		iface.RPCFunctionCall(saddr, SYSINFO_GET_VAUX, 0, 0, 0, rxm);
		voltage = GetFixedPointValue(rxm.data[1]);
		vmin = GetFixedPointValue(rxm.data[2] & 0xffff);
		vmax = GetFixedPointValue(rxm.data[2] >> 16);
		printf("    VCCAUX  = %.2f V (legal range = %.2f - %.2f)\n", voltage, vmin, vmax);
		if( (voltage < vmin) || (voltage > vmax) )
		{
			throw JtagExceptionWrapper(
				"VCCAUX voltage out of range",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//If we get here, we're good
		//TODO: Verify that limits are sane
		printf("All sensors within normal limits\n");
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

float GetFixedPointValue(unsigned int din)
{
	return static_cast<float>(din) / 256.0f;
}
