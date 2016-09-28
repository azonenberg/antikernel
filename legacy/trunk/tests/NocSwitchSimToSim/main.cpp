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
	
	Ping between two PC-side node using nocswitch
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
	JtagInterface* iface = NULL;
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
		
		//Connect twice
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface ifaceA;
		ifaceA.Connect(server, port);
		uint16_t addrA = ifaceA.GetClientAddress();
		NOCSwitchInterface ifaceB;
		ifaceB.Connect(server, port);
		uint16_t addrB = ifaceB.GetClientAddress();
		printf("Interface A has address %02x\n", addrA);
		printf("Interface B has address %02x\n", addrB);
		
		//Send an RPC message
		RPCMessage msgSend;
		msgSend.from = 0;
		msgSend.to = addrB;
		msgSend.type = RPC_TYPE_INTERRUPT;
		msgSend.callnum = 0x41;
		msgSend.data[0] = 0x00111111;
		msgSend.data[1] = 0x23456789;
		msgSend.data[2] = 0xdeadbeef;
		double tsend = GetTime();
		ifaceA.SendRPCMessage(msgSend);
		
		//Read it back
		RPCMessage msgRecv;
		if(!ifaceB.RecvRPCMessageBlockingWithTimeout(msgRecv, 2))
		{
			throw JtagExceptionWrapper(
				"Expected message from other interface but it never arrived",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		double dt = GetTime() - tsend;
		printf("Message took %.2f ms to arrive\n", dt * 1000);
		
		//Check it
		if( (msgSend.callnum != msgRecv.callnum) || (msgSend.type != msgRecv.type) )
		{
			throw JtagExceptionWrapper(
				"Header mismatch",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		for(int i=0; i<3; i++)
		{
			if(msgSend.data[i] != msgRecv.data[i])
			{
				throw JtagExceptionWrapper(
					"Payload mismatch",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
		}	
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Send a DMA message
		DMAMessage msgDMASend;
		msgDMASend.from = 0;
		msgDMASend.to = addrB;
		msgDMASend.address = 0x0;
		msgDMASend.opcode = DMA_OP_WRITE_REQUEST;
		msgDMASend.len = 512;
		for(int i=0; i<512; i++)
			msgDMASend.data[i] = rand();
		tsend = GetTime();
		ifaceA.SendDMAMessage(msgDMASend);
		
		//Read it back
		DMAMessage msgDMARecv;
		if(!ifaceB.RecvDMAMessageBlockingWithTimeout(msgDMARecv, 2))
		{
			throw JtagExceptionWrapper(
				"Expected message from other interface but it never arrived",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		dt = GetTime() - tsend;
		printf("Message took %.2f ms to arrive\n", dt * 1000);
		
		//Check it
		if( (msgDMASend.opcode != msgDMARecv.opcode) ||
			(msgDMASend.len != msgDMARecv.len) ||
			(msgDMASend.address != msgDMARecv.address)
			)
		{
			throw JtagExceptionWrapper(
				"Header mismatch",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		for(int i=0; i<512; i++)
		{
			if(msgDMASend.data[i] != msgDMARecv.data[i])
			{
				throw JtagExceptionWrapper(
					"Payload mismatch",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
		}
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	delete iface;
	iface = NULL;
	return err_code;
}

