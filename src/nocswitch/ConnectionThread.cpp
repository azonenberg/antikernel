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
	@brief Main thread procedure for handling connections from client
 */
#include "nocswitch.h"

/*
using namespace std;

extern Mutex g_sendmutex;
extern std::list<RPCMessage> g_sendqueue;
extern std::list<DMAMessage> g_dsendqueue;
extern Mutex g_recvmutex;
extern std::map<int, std::list<RPCMessage> > g_recvqueue;
extern std::map<int, std::list<DMAMessage> > g_drecvqueue;

extern bool g_quitting;
*/

/**
	@brief Thread for handling connections
 */
void ConnectionThread(int sock)
{
	Socket client(sock);

	//uint16_t sender = pData->addr;
	try
	{
		//Set no-delay flag
		if(!client.DisableNagle())
		{
			throw JtagExceptionWrapper(
				"Failed to set TCP_NODELAY",
				"");
		}
		/*
		//Sit around and wait for messages
		uint16_t opcode;
		while(true)
		{
			socket.RecvLooped((unsigned char*)&opcode, 2);

			bool quit = g_quitting;

			switch(opcode)
			{
			case NOCSWITCH_OP_SENDRPC:
				{
					//Read the message
					unsigned char buf[16];
					socket.RecvLooped(buf, 16);
					RPCMessage msg;
					msg.Unpack(buf);

					//Patch in source address
					if(msg.from == 0x0000)
						msg.from = sender;
					else if( (msg.from >> 14) != 3)
					{
						throw JtagExceptionWrapper(
							"Spoofed source address received on inbound packet, dropping connection",
							"",
							JtagException::EXCEPTION_TYPE_GIGO);
					}

					//If the message is destined for the debug subnet (0xC000/2) send it here instead
					if((msg.to >> 14) == 3)
					{
						MutexLock lock(g_recvmutex);
						g_recvqueue[msg.to].push_back(msg);
					}

					//Put it on the queue for the JTAG link
					else
					{
						MutexLock lock(g_sendmutex);
						g_sendqueue.push_back(msg);
					}
				}
				break;

			case NOCSWITCH_OP_RECVRPC:
				{
					//printf("%04x: polling for RPC messages\n", sender);

					//See if there are any messages to be found
					RPCMessage msg;
					uint8_t found = 0;
					{
						MutexLock lock(g_recvmutex);
						if(!g_recvqueue[sender].empty())
						{
							found = 1;
							msg = g_recvqueue[sender].front();
							g_recvqueue[sender].pop_front();
						}
					}

					socket.SendLooped(&found, 1);

					if(found)
					{
						unsigned char buf[16];
						msg.Pack(buf);
						socket.SendLooped(buf, 16);

						//printf("Sending RPC message to client (%s)\n", msg.Format().c_str());
					}

					//if(found)
					//	printf("%d: poll returned, found = %d\n", k, found);
				}
				break;

			case NOCSWITCH_OP_SENDDMA:
				{
					//Read the message
					uint32_t buf[515];
					socket.RecvLooped((unsigned char*)buf, 515*4);
					DMAMessage msg;
					msg.Unpack(buf);

					//Patch in source address
					if(msg.from == 0x0000)
						msg.from = sender;
					else if( (msg.from >> 14) != 3)
					{
						throw JtagExceptionWrapper(
							"Spoofed source address received on inbound packet, dropping connection",
							"",
							JtagException::EXCEPTION_TYPE_GIGO);
					}

					//If the message is destined for the debug subnet (0xC000/2) send it here instead
					if((msg.to >> 14) == 3)
					{
						MutexLock lock(g_recvmutex);
						g_drecvqueue[msg.to].push_back(msg);
					}

					//Put it on the queue for the JTAG link
					else
					{
						MutexLock lock(g_sendmutex);
						g_dsendqueue.push_back(msg);
					}
				}
				break;

			case NOCSWITCH_OP_RECVDMA:
				{
					static int k=0;
					k++;

					//See if there are any messages to be found
					DMAMessage msg;
					uint8_t found = 0;
					{
						MutexLock lock(g_recvmutex);
						if(!g_drecvqueue[sender].empty())
						{
							found = 1;
							msg = g_drecvqueue[sender].front();
							g_drecvqueue[sender].pop_front();
						}
					}

					socket.SendLooped(&found, 1);

					if(found)
					{
						uint32_t buf[515];
						msg.Pack(buf);
						socket.SendLooped((unsigned char*)buf, 515*4);
					}

					//if(found)
					//	printf("%d: poll returned, found = %d\n", k, found);
				}
				break;

			case NOCSWITCH_OP_GET_ADDR:
				socket.SendLooped((unsigned char*)&sender, 2);
				break;

			case NOCSWITCH_OP_QUIT:
				quit = true;
				return 0;

			default:
				{
					throw JtagExceptionWrapper(
						"Unrecognized opcode received from client",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
			}

			if(quit)
				break;
		}
		*/
	}
	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
	}

	LogNotice("Client quit\n");
}
