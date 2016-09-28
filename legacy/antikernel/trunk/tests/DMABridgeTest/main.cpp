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
	@brief DMA bridge test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"

#include <RPCv2Router_type_constants.h>
#include <DMABridge_opcodes_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>

#include <signal.h>

using namespace std;

void InboundTest(NOCSwitchInterface& iface, uint16_t baddr, NameServer& namesvr);
void OutboundTest(NOCSwitchInterface& iface, uint16_t baddr, NameServer& namesvr);

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
		
		//Register us
		printf("Name server registration\n");
		NameServer namesvr(&iface, "ThisIsALongAndComplicatedPassword");
		namesvr.Register("testcase");
		
		//Address lookup
		printf("Looking up address of bridge\n");
		uint16_t baddr = namesvr.ForwardLookup("bridge");
		printf("Bridge is at %04x\n", baddr);
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Register ourself as the target
		printf("Registering target\n");
		RPCMessage rxm;
		iface.RPCFunctionCall(baddr, BRIDGE_REGISTER_TARGET, 0, 0, 0, rxm);
		
		//Test inbound DMA
		InboundTest(iface, baddr, namesvr);
		
		//Test outbound DMA
		OutboundTest(iface, baddr, namesvr);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

void InboundTest(NOCSwitchInterface& iface, uint16_t baddr, NameServer& namesvr)
{
	//Go send a DMA message to it
	printf("Sending DMA message\n");
	DMAMessage msg;
	msg.from = 0x0000;
	msg.to = baddr;
	msg.opcode = DMA_OP_WRITE_REQUEST;
	msg.len = 32;
	msg.address = 0;
	for(int i=0; i<32; i++)
		msg.data[i] = rand();
	iface.SendDMAMessage(msg);
	
	//Expect to get an interrupt with a physical address
	RPCMessage rxm;
	iface.RecvRPCMessageBlockingWithTimeout(rxm, 2);
	if( (rxm.from != baddr) || (rxm.type != RPC_TYPE_INTERRUPT) || (rxm.callnum != BRIDGE_PAGE_READY) )
	{
		printf("Got: %s\n", rxm.Format().c_str());
		throw JtagExceptionWrapper(
			"Bad message",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	printf("Got a new page\n");
	uint16_t addr = rxm.data[0];
	printf("    Physical address: %s:%08x\n", namesvr.ReverseLookup(addr).c_str(), rxm.data[1]);
	unsigned int len = rxm.data[2] & 0x1FF;
	printf("    Length:           %u\n", len);
	addr = rxm.data[2] >> 16;
	printf("    Originally from:  %s\n", namesvr.ReverseLookup(addr).c_str());
	
	//Try reading the memory and verify it looks OK
	printf("Reading RAM\n");
	uint32_t rdata[512] = {0};
	iface.DMARead(rxm.data[0], rxm.data[1], len, rdata, RAM_OP_FAILED);
	for(int i=0; i<32; i++)
	{
		if(msg.data[i] != rdata[i])
		{
			printf("Mismatch at %d (got %08x, expected %08x)\n", i, msg.data[i], rdata[i]);
			throw JtagExceptionWrapper(
				"Bad message",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
	
	printf("Read data OK\n");
	
	//Free the memory
	printf("Freeing RAM\n");
	iface.RPCFunctionCall(rxm.data[0], RAM_FREE, 0, rxm.data[1], 0, rxm);
}

void OutboundTest(NOCSwitchInterface& iface, uint16_t baddr, NameServer& namesvr)
{
	//Address lookup
	printf("Looking up address of RAM\n");
	uint16_t raddr = namesvr.ForwardLookup("ram");
	printf("RAM is at %04x\n", raddr);
	
	//Allocate a page
	RPCMessage rxm;
	printf("Allocating RAM...\n");
	iface.RPCFunctionCall(raddr, RAM_ALLOCATE, 0, 0, 0, rxm);
	unsigned int page = rxm.data[1];
	printf("    Allocated page %08x\n", page);
	
	//Fill it with some random data
	printf("Filling RAM...\n");
	unsigned int data[32] = {0};
	for(int i=0; i<32; i++)
		data[i] = rand();
	iface.DMAWrite(raddr, page, 32, data, RAM_WRITE_DONE, RAM_OP_FAILED);
	
	//Chown the page to the bridge so it can use it
	iface.RPCFunctionCall(raddr, RAM_CHOWN, 0, page, baddr, rxm);
	
	//Send it
	printf("Sending message...\n");
	iface.RPCFunctionCall(baddr, BRIDGE_SEND_PAGE, raddr, page, (iface.GetClientAddress() << 16) | 32, rxm);
	
	//Verify we get something back
	printf("Waiting for response...\n");
	DMAMessage dxm;
	if(!iface.RecvDMAMessageBlockingWithTimeout(dxm, 1))
	{
		throw JtagExceptionWrapper(
			"Read timed out",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	
	//Crunch it
	printf("Checking result...\n");
	if( (dxm.from != baddr) || (dxm.opcode != DMA_OP_WRITE_REQUEST) || (dxm.len != 32) || (dxm.address != 0) )
	{
		printf("Got:\n"
			"    From     : %04x\n"
			"    To       : %04x\n"
			"    Op       : %d\n"
			"    Len      : %d\n"
			"    Address  : %08x\n",
			dxm.from,
			dxm.to,
			dxm.opcode,
			dxm.len,
			dxm.address);
		throw JtagExceptionWrapper(
			"Bad packet headers",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
	for(int i=0; i<32; i++)
	{
		if(dxm.data[i] != data[i])
		{
			throw JtagExceptionWrapper(
				"Bad message body",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
	}
}
