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
	@brief UART loopback test
	
	Sends data to and from the UART and verifies correctness of the data.
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

#include <signal.h>

using namespace std;

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		string tty;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
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
		if( (server == "") || (port == 0) )
		{
			throw JtagExceptionWrapper(
				"No server or port name specified",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Connect to the UART
		UART uart(tty, 115200);
		
		//PRBS loopback testing
		//High-speed sends more than ~64 bytes can overrun buffers if there's no flow control
		const size_t ntests = 500;
		const size_t buflen = 64;
		char charset[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_+{}:\"M<>?-=[];'m,./\\|";
		for(size_t i=0; i<ntests; i++)
		{
			if( (i % 20) == 0)
				printf("Loopback test [i=%zu]\n", i);
			
			//Generate PRBS
			char send_data[buflen+1] = {0};
			for(size_t j=0; j<buflen; j++)
				send_data[j] = charset[rand() % (sizeof(charset) - 1)];
				
			//Send and read back
			char read_data[buflen+1] = {0};
			uart.Write((unsigned char*)send_data, buflen);
			uart.Read((unsigned char*)read_data, buflen);
			
			//Sanity check
			if(0 != strcmp(read_data, send_data))
			{
				printf("Send: %s\n", send_data);
				for(size_t j=0; j<buflen; j++)
				{
					printf("%02x ", send_data[j] & 0xff);
					if( (j & 31) == 31)
						printf("\n");
				}
				printf("\n");
				
				printf("Read: %s\n", read_data);
				for(size_t j=0; j<buflen; j++)
				{
					printf("%02x ", read_data[j] & 0xff);
					if( (j & 31) == 31)
						printf("\n");
				}
				printf("\n");
				
				throw JtagExceptionWrapper(
					"Bad data received in loopback test",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
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
