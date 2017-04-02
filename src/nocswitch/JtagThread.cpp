/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Main thread procedure for handling JTAG operations
 */
#include "nocswitch.h"
#include "../jtaghal/jtaghal.h"
#include "../nocbridge/nocbridge.h"

using namespace std;

/**
	@brief Thread for handling JTAG operations
 */
void JtagThread(JTAGNOCBridgeInterface* piface)
{
	try
	{
		while(!g_quitting)
		{
			//Push pending messages, get whatever comes back
			piface->Cycle();

			//Dispatch returned data to the various clients
			RPCMessage rxm;
			while(piface->RecvRPCMessage(rxm))
			{
				//Look up the context for this address
				lock_guard<mutex> mapmutex(g_contextMutex);
				if(g_contextMap.find(rxm.to) == g_contextMap.end())
				{
					LogWarning("Got a message addressed to 0x%04x, but we don't have an active client there\n", rxm.to);
					LogWarning("Message was: %s\n", rxm.Format().c_str());
					continue;
				}
				ConnectionContext* pctx = g_contextMap[rxm.to];

				//We found the context, map mutex is still locked (important, will prevent thread from terminating!)
				//Now we have to lock the socket (wait for any pending sends to finish) before sending our data
				lock_guard<mutex> sockmutex(pctx->m_mutex);

				//and now we can finally send the message
				uint8_t opcode = NOCSWITCH_OP_RPC;
				pctx->m_socket.SendLooped(&opcode, 1);
				unsigned char buf[16];
				rxm.Pack(buf);
				pctx->m_socket.SendLooped(buf, 16);
			}

			//TODO: Repeat for DMA
		}
	}
	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
	}
}

