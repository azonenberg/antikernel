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
	@brief Core 1 firmware for GRAFTON dual core unit test
 */

#include <grafton/grafton.h>
#include <rpc.h>

#include <NOCNameServer_constants.h>
#include <GraftonCPUPagePermissions_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>

#define VADDR_BASE ((unsigned int*)0x40030800)

void RunAttack(RPCMessage_t* msg);

/**
	@brief Attack application
 */

int main()
{
	//Loop forever waiting for a message to show up, then process it
	RPCMessage_t msg;
	while(1)
	{
		//Get the message
		RecvRPCMessage(&msg);
		
		//Ignore anything that isn't a call
		if(msg.type != RPC_TYPE_CALL)
			continue;
			
		//Default to sending a response
		msg.to = msg.from;
		msg.from = 0;
			
		//Decide what to do
		switch(msg.callnum)
		{
			
		//Ping, verify that we're alive
		case 0:	
			msg.type = RPC_TYPE_RETURN_SUCCESS;
			msg.data[0] = 101;
			msg.data[1] = 0;
			msg.data[2] = 0;
			SendRPCMessage(&msg);
			break;
			
		//Try running the attack
		case 1:
			RunAttack(&msg);
			break;
		
		//Gibberish? Kick it back
		default:
			msg.type = RPC_TYPE_RETURN_FAIL;
			SendRPCMessage(&msg);
			break;
		}
	}
	return 0;
}

void RunAttack(RPCMessage_t* msg)
{
	//Map the new page
	unsigned int ramaddr = msg->data[0];
	unsigned int phyaddr = msg->data[1];
	unsigned int* vaddr = VADDR_BASE + phyaddr;
	FlushDsideL1Cache(vaddr, 2048);	
	MmapHelper(vaddr, phyaddr, ramaddr, PAGE_READ_WRITE);

	//Try reading some data from it
	msg->data[0] = 0;
	msg->data[1] = vaddr[0];
	msg->data[2] = 0;
	
	//Map it back
	RPCMessage_t rmsg;
	if(0 != RPCFunctionCall(ramaddr, RAM_CHOWN, 0, phyaddr, msg->to, &rmsg))
		return;
	MmapHelper(vaddr, 0, 0, PAGE_GUARD);
	
	//Send the response
	msg->type = RPC_TYPE_RETURN_SUCCESS;
	SendRPCMessage(msg);
}
