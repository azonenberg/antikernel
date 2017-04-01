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
#include "JtagDebugBridge_addresses_enum.h"

using namespace std;

bool IsInDebugSubnet(int addr);

bool IsInDebugSubnet(int addr)
{
	return (addr <= DEBUG_HIGH_ADDR) && (addr >= DEBUG_LOW_ADDR);
}

/**
	@brief Thread for handling connections
 */
void ConnectionThread(int sock, JTAGNOCBridgeInterface* iface)
{
	Socket client(sock);

	//The set of addresses assigned to THIS socket
	set<uint16_t> our_addresses;

	try
	{
		LogNotice("Got a connection\n");

		//Set no-delay flag
		if(!client.DisableNagle())
		{
			throw JtagExceptionWrapper(
				"Failed to set TCP_NODELAY",
				"");
		}

		//Sit around and wait for messages
		uint8_t opcode;
		while(true)
		{
			client.RecvLooped((unsigned char*)&opcode, 1);

			bool quit = g_quitting;

			switch(opcode)
			{
			case NOCSWITCH_OP_ALLOC_ADDR:
				{
					LogNotice("Allocate-address request\n");

					//Send back the opcode
					client.SendLooped((unsigned char*)&opcode, 1);

					//Try to allocate the address and tell the client how it went
					uint16_t addr;
					uint8_t ok = iface->AllocateClientAddress(addr);
					client.SendLooped(&ok, 1);

					//If it worked, send the actual data.
					//(Note that we don't send the address field if the allocation failed!)
					//Also record the address so we know to check stuff destined to it in the future
					if(ok)
					{
						client.SendLooped((unsigned char*)&addr, 2);
						our_addresses.emplace(addr);
					}
				}
				break;

			case NOCSWITCH_OP_FREE_ADDR:
				{
					//TODO: implement this
					LogWarning("NOCSWITCH_OP_FREE_ADDR not implemented yet\n");
				}
				break;

			case NOCSWITCH_OP_RPC:
				{
					//Read the message
					unsigned char buf[16];
					client.RecvLooped(buf, 16);
					RPCMessage msg;
					msg.Unpack(buf);

					//Patch in source address
					/*
					if(msg.from == 0x0000)
						msg.from = sender;
					else*/ if(!IsInDebugSubnet(msg.from))
					{
						throw JtagExceptionWrapper(
							"Spoofed source address received on inbound packet, dropping connection",
							"");
					}

					//If the message is destined for the debug subnet send it here instead
					if(IsInDebugSubnet(msg.to))
					{
						LogError("Loopback to debug addresses not yet implemented\n");
						//MutexLock lock(g_recvmutex);
						//g_recvqueue[msg.to].push_back(msg);
					}

					//Nope, put it on the queue for the JTAG link
					else
						iface->SendRPCMessage(msg);
				}
				break;

			/*
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
			*/
			case NOCSWITCH_OP_QUIT:
				LogVerbose("Client disconnecting\n");
				quit = true;
				break;

			default:
				{
					throw JtagExceptionWrapper(
						"Unrecognized opcode received from client",
						"");
				}
			}

			if(quit)
				break;
		}
	}
	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
	}

	LogNotice("Client quit\n");
}
