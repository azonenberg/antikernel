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
	@brief CR2 GPIO test.
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"

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
		
		//Sanity check that the interface is GPIO capable
		printf("Initializing GPIO interface...\n");
		if(!iface.IsGPIOCapable())
		{
			throw JtagExceptionWrapper(
				"JTAG interface should be GPIO capable, but isn't",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		printf("    Interface is GPIO capable (%d GPIO pins)\n", iface.GetGpioCount());
		
		//Print out pin state
		for(int i=0; i<iface.GetGpioCount(); i++)
			printf("    Pin %2d: %6s (%d)\n", i, iface.GetGpioDirection(i) ? "output" : "input", iface.GetGpioValueCached(i));
		
		/*
			Set up pin configuration
			
			gpio[0] = output
			gpio[1] = input
			
			The CPLD should function as a simple inverter.
		 */
		iface.SetGpioDirectionDeferred(0, true);
		iface.SetGpioDirectionDeferred(1, false);
		
		for(int i=0; i<10; i++)
		{
			printf("    Testing dout=0\n");
			iface.SetGpioValue(0, false);
			if(!iface.GetGpioValue(1))
			{
				throw JtagExceptionWrapper(
					"    Expected din=1, got 0\n",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
			usleep(100 * 1000);
			
			printf("    Testing dout=1\n");
			iface.SetGpioValue(0, true);
			if(iface.GetGpioValue(1))
			{
				throw JtagExceptionWrapper(
					"    Expected din=0, got 1\n",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
			usleep(100 * 1000);
		}
		printf("OK\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}
