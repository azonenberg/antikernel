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
	@brief GRAFTON multiply/divide unit test
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

#include <signal.h>

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
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Address lookup
		printf("Looking up address of CPU\n");
		NameServer nameserver(&iface);
		uint16_t caddr = nameserver.ForwardLookup("cpu");
		printf("CPU is at %04x\n", caddr);
		uint16_t taddr = iface.GetClientAddress();
		printf("We are at %04x\n", taddr);
		
		//Needs to be deterministic for testing
		srand(0);

		//Send a bunch of messages and make sure we get the right thing back
		printf("Sending test packets...\n");
		int npack = 1000;
		for(int i=0; i<npack; i++)
		{	
			if( (i % 100) == 0)
				printf("Message %d\n", i);
			
			RPCMessage msg;
			msg.from = taddr;
			msg.to = caddr;
			msg.type = RPC_TYPE_CALL;
			msg.callnum = rand() & 0x1;				//randomly multiply or divide
			msg.data[0] = 0;
			msg.data[1] = rand();
			msg.data[2] = rand();
			iface.SendRPCMessage(msg);
			
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
			
			if(rxm.from != caddr)
			{
				throw JtagExceptionWrapper(
					"Invalid message sender",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			
			//Multiply
			if(msg.callnum == 0)
			{
				int a = msg.data[1];
				int b = msg.data[2];
				int expected = a*b;
				if(expected != (int)rxm.data[1])
				{				
					printf("Sent:\n    %s\nReceived:\n    %s\n", msg.Format().c_str(), rxm.Format().c_str());
					throw JtagExceptionWrapper(
						"Invalid message came back",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);					
				}
			}
			
			//Divide
			else
			{
				int a = msg.data[1];
				int b = msg.data[2];
				
				int quot = a / b;
				int rem = a % b;
				
				if( (quot != (int)rxm.data[1]) || (rem != (int)rxm.data[2]) )
				{				
					printf("Sent:\n    %s\nReceived:\n    %s\n", msg.Format().c_str(), rxm.Format().c_str());
					throw JtagExceptionWrapper(
						"Invalid message came back",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);					
				}
			}
		}
	
		printf("Done, all OK\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
