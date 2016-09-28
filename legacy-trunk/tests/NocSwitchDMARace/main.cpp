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
	@brief NoC switch race condition test.
	
	Generate many large packets such that one will be inbound and one will be outbound simultaneously.
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
		printf("Looking up address of DMA pinger\n");
		NameServer nameserver(&iface);
		uint16_t pingaddr = nameserver.ForwardLookup("dmaping");
		printf("Pinger is at %04x\n", pingaddr);
		
		//Once the capture is set up, send a test message to the echo node
		DMAMessage msgA;
		msgA.from = 0x0000;
		msgA.to = pingaddr;
		msgA.opcode = DMA_OP_WRITE_REQUEST;
		msgA.len = 512;
		uint32_t val = 0xAAAAAAAA;
		const int nmsg = 10;
		for(int i=0; i<nmsg; i++)
		{
			msgA.address = 0xdeadbee0 + i;
			for(int j=0; j<512; j++)
				msgA.data[j] = val;
			val += 0x11111111;
			iface.SendDMAMessage(msgA);
		}
		
		//Read back the echo messages
		for(int i=0; i<nmsg; i++)
		{
			DMAMessage rxm;
			if(!iface.RecvDMAMessageBlockingWithTimeout(rxm, 5))
			{
				printf("Expected response within 5000ms but nothing arrived\n");
				
				throw JtagExceptionWrapper(
					"Message timeout",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);					
			}
			
			//Sanity check
			printf("rxm: from %04x to %04x, address %08x, len %d\n", rxm.from, rxm.to, rxm.address, rxm.len);
			if(rxm.address != (0xdeadbee0 + i))
			{
				/*throw JtagExceptionWrapper(
					"Wrong address on received message - duplicate or dropped packet?",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
					*/
				printf("    FAIL\n");
			}
			
			/*for(int i=0; i<512; i++)
			{
				printf("%08x ", rxm.data[i]);
				if( (i & 0xF) == 0xF)
					printf("\n");
			}*/
		}
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
