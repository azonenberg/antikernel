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
	@brief NoC switch board ping test
	
	Once DMAJtagTest is successful, repeat the test through nocswitch
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
		
		//Needs to be deterministic for testing
		//Seed chosen to ensure at least two 512-word and one 1-word packet with glibc rand()
		srand(915);
		
		//Send a bunch of messages and make sure we get the same thing back
		printf("Sending ping packets...\n");
		double start = GetTime();
		int npack = 50;
		int payload_size = 0;
		double sumping = 0;
		double minping = 999999;
		double maxping = 0;
		for(int i=0; i<npack; i++)
		{	
			//Send the message
			DMAMessage msg;
			msg.from = 0x0000;
			msg.to = pingaddr;
			msg.opcode = DMA_OP_WRITE_REQUEST;
			msg.len = 1 + (rand() % 512);	//[1, 512]
			msg.address = 0x00000000;
			for(int j=0; j<msg.len; j++)
				msg.data[j] = rand();
				
			//payload_size is total size including both directions, in bits
			payload_size += (2*msg.len) * 32;
			printf("Message %3d: write request (%d) of length %3d... ", i, msg.opcode, msg.len);
				
			double tsend = GetTime();
			iface.SendDMAMessage(msg);
			
			//Wait for the response	
			DMAMessage rxm;
			if(!iface.RecvDMAMessageBlockingWithTimeout(rxm, 5))
			{
				printf("Timeout on message %d - expected response within 5000ms but nothing arrived\n", i);
				
				throw JtagExceptionWrapper(
					"Message timeout",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);					
			}
			
			double trcv = GetTime();
			double rtt = (trcv - tsend);
			sumping += rtt;
			if(minping > rtt)
				minping = rtt;
			if(maxping < rtt)
				maxping = rtt;
			
			//Sanity check the result
			if( (rxm.from != pingaddr) || (rxm.opcode != msg.opcode) ||
				(rxm.len != msg.len) || (rxm.address != msg.address) )
			{
				printf("Message %d header FAIL\n", i);
			
				printf("Sent:\n"
					"    From     : %04x\n"
					"    To       : %04x\n"
					"    Op       : %d\n"
					"    Len      : %d\n"
					"    Address  : %08x\n"
					"Received:\n"
					"    From     : %04x\n"
					"    To       : %04x\n"
					"    Op       : %d\n"
					"    Len      : %d\n"
					"    Address  : %08x\n",
					msg.from,
					msg.to,
					msg.opcode,
					msg.len,
					msg.address,
					rxm.from,
					rxm.to,
					rxm.opcode,
					rxm.len,
					rxm.address);
					
				throw JtagExceptionWrapper(
					"Incorrect headers on received message",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}

			bool mismatch = false;
			for(unsigned int j=0; j<msg.len; j++)
			{
				if(msg.data[j] == rxm.data[j])
					continue;
					
				printf("  Mismatch in data at word %u: sent %08x, got back %08x\n", j, msg.data[j], rxm.data[j]);
				mismatch = true;
			}
			
			if(mismatch)
			{
				throw JtagExceptionWrapper(
					"Incorrect payload in received message",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			printf("    OK\n");
		}
		
		int packets_sent = npack * 2;
		int header_size = packets_sent * 96;
		
		//Print statistics
		double end = GetTime();
		double dt = end - start;	
		printf("Done, all OK\n");
		printf("%d packets sent in %.2f ms (%.2f Kbps raw, %.2f Kbps after overhead)\n",
			packets_sent,
			dt * 1000,
			(payload_size + header_size) / (1000 * dt),
			(payload_size) / (1000 * dt));
		printf("RTT latency: %.2f ms min / %.2f ms avg / %.2f max\n",
			minping * 1000,
			(sumping / npack) * 1000,
			maxping * 1000);
			
		fflush(stdout);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
