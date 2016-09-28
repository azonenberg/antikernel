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
	@brief Attacker firmware for SARATOGA demo
 */

#include <saratoga/saratoga.h>
#include <rpc.h>

#include <unistd.h>
#include <sys/mman.h>
#include <errno.h>

/**
	@brief Attack application
 */

int main()
{
	DebugTracePoint();
	
	//Set up the interrupt queue
	InterruptQueueInit();
	
	//Register us with the name server
	unsigned int hostname[] = { 0x61747461, 0x636b6572 }; //"attacker"
	unsigned int signature[] = 
	{ 0xd52c28de, 0x8da4e27d, 0x57a4ae95, 0x340fe794, 0x1adacc10, 0x21e1cf93, 0x5475f541, 0x9667af9a };
	if(0 != RegisterHost(hostname, signature))
		return -1;
	
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
			{		
				//Create a new POSIX file descriptor for the RAM page we're interested in
				int fd = posix_fd_alloc(msg.data[0], msg.data[1]);
				if(fd < 0)
				{
					msg.type = RPC_TYPE_RETURN_FAIL;
					msg.data[0] = 1;
					msg.data[1] = errno;
					SendRPCMessage(&msg);
					break;
				}
		
				//Attempt to map the page
				unsigned int* data = (unsigned int*)mmap(NULL, PAGESIZE, PROT_READ, MAP_SHARED, fd, 0);
				if(data == NULL)
				{
					msg.type = RPC_TYPE_RETURN_FAIL;
					msg.data[0] = 2;
					msg.data[1] = errno;
					SendRPCMessage(&msg);
					break;
				}
				
				//If we mapped it, actually read the data
				msg.data[0] = 0;
				msg.data[1] = data[0];
				msg.data[2] = data[1];
				
				//Clean up
				munmap(data, PAGESIZE);
				close(fd);
				
				//Done, return the result
				SendRPCMessage(&msg);
			}			
			
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
