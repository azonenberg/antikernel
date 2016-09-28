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
	@brief Victim firmware for SARATOGA demo
 */

#include <saratoga/saratoga.h>
#include <rpc.h>

#include <unistd.h>
#include <sys/mman.h>
#include <errno.h>

int DoCrypto(int fd, unsigned int len, unsigned int key);

/**
	@brief Simulated crypto coprocessor for demo
 */
int main()
{
	//Initialize the POSIX compatibility library
	//TODO: call from _start()?
	posix_init();
	
	//Register us with the name server
	unsigned int hostname[] = { 0x76696374, 0x696d0000 }; //"victim"
	unsigned int signature[] = 
	{ 0xa9c5780c, 0xcf595275, 0x61ca6b33, 0xa796508c, 0x51cc22c4, 0xd4476def, 0xa46b0c03, 0x0e86bc34 };
	if(0 != RegisterHost(hostname, signature))
		return -1;
	
	unsigned int shift_key = 3;	//default to Caesar cipher
	
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
		
		//Default to successful return
		msg.type = RPC_TYPE_RETURN_SUCCESS;
			
		//Decide what to do
		switch(msg.callnum)
		{
			
		//Ping, verify that we're alive
		case 0:	
			msg.data[0] = 42;
			msg.data[1] = 0;
			msg.data[2] = 0;
			SendRPCMessage(&msg);
			break;
			
		//Set key
		case 1:
			shift_key = msg.data[0];
			SendRPCMessage(&msg);
			break;
			
		//Encrypt data
		case 2:
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
		
				//Do the encryption
				if(0 != DoCrypto(fd, msg.data[2], shift_key))
				{
					msg.type = RPC_TYPE_RETURN_FAIL;
					msg.data[0] = 2;
					msg.data[1] = errno;
					SendRPCMessage(&msg);
					break;
				}
				
				//Chown the page back to the sender and clean up
				fchown(fd, msg.to, msg.to);
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

int DoCrypto(int fd, unsigned int len, unsigned int key)
{
	//Attempt to map the page
	unsigned char* str = (unsigned char*)mmap(NULL, len, PROT_READ, MAP_SHARED, fd, 0);
	if(str == NULL)
		return 1;
	
	//Encrypt it
	for(unsigned int i=0; i<len; i++)
	{
		//Get letter index (0...25)
		unsigned char ch = str[i];
		unsigned int index = 0;
		if( (ch >= 'a') && (ch <= 'z') )
			index = ch - 'a';
		else if( (ch >= 'A') && (ch <= 'Z') )
			index = ch - 'A';
		else
			continue;
			
		//Encrypt it
		index = index + key;
		if(index >= 26)
			index -= 26;
			
		str[i] = 'A' + index;
	}
	
	//Unmap the page and clean up (flushes caches automatically)
	munmap(str, len);
	return 0;
}
