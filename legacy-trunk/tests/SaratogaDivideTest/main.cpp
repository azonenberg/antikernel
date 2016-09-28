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
	@brief SARATOGA integer division test
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
#include <SaratogaCPUManagementOpcodes_constants.h>

#include "../../src/scopehal/scopehal.h"
#include "../../src/scopehal/RedTinLogicAnalyzer.h"
#include "../../src/scopeprotocols/scopeprotocols.h"

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
		NameServer nameserver(&iface, "SampleNameServerPassword");
		nameserver.Register("testcase");
		uint16_t caddr = nameserver.ForwardLookup("cpu");
		printf("CPU is at %04x\n", caddr);
		uint16_t raddr = nameserver.ForwardLookup("rom");
		printf("ROM is at %04x\n", raddr);
		uint16_t taddr = iface.GetClientAddress();
		printf("We are at %04x\n", taddr);
		
		//Get some more info about the CPU
		uint16_t oaddr = caddr;
		printf("OoB address is %04x\n", oaddr);
		RPCMessage rxm;
		iface.RPCFunctionCallWithTimeout(oaddr, OOB_OP_GET_THREADCOUNT, 0, 0, 0, rxm, 5);
		printf("    CPU has %d threads\n", rxm.data[0]);
		
		//Spawn a new thread
		printf("Creating new process (ELF image at rom:00000000)\n");
		iface.RPCFunctionCallWithTimeout(oaddr, OOB_OP_CREATEPROCESS, 0, raddr, 0x00000000, rxm, 5);
		uint16_t paddr = rxm.data[1];
		uint16_t pid   = rxm.data[0];
		printf("    New process ID is %d (address %04x)\n", pid, paddr);

		//Needs to be deterministic for testing
		srand(0);
		
		//Send a bunch of messages and make sure we get the same thing back
		printf("Sending divide/mod test packets...\n");
		double start = GetTime();
		int npack = 1000;
		double sumping = 0;
		double minping = 999999;
		double maxping = 0;
		for(int i=0; i<npack; i++)
		{	
			if( (i % 100) == 0)
				printf("Message %d\n", i);
	
			RPCMessage msg;
			msg.from = taddr;
			msg.to = paddr;
			msg.type = RPC_TYPE_CALL;
			msg.callnum = 0;
			msg.data[0] = 0;
			msg.data[1] = rand();
			msg.data[2] = rand();
			double tsend = GetTime();
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
			
			double trcv = GetTime();
			double rtt = (trcv - tsend);
			sumping += rtt;
			if(minping > rtt)
				minping = rtt;
			if(maxping < rtt)
				maxping = rtt;			
			
			if( (rxm.from == paddr) &&
				(rxm.data[0] == 0) &&
				(rxm.data[1] == (msg.data[1] / msg.data[2])) &&
				(rxm.data[2] == (msg.data[1] % msg.data[2])) &&
				(rxm.type == RPC_TYPE_RETURN_SUCCESS)
			)
			{
				//printf("Message %d OK\n", i);
			}
			
			else
			{				
				printf("Message %d FAIL\n", i);
				printf("Sent:\n    %s\nReceived:\n    %s\n", msg.Format().c_str(), rxm.Format().c_str());
				throw JtagExceptionWrapper(
					"Invalid message came back",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		
		int packets_sent = npack * 2;
		int header_size = packets_sent * 32;
		int payload_size = packets_sent * 96;
		
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
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
