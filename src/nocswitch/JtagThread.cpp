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

/*
using namespace std;

//Send queue - just a FIFO
Mutex g_sendmutex;
std::list<RPCMessage> g_sendqueue;
std::list<DMAMessage> g_dsendqueue;

//Receive queue - map of FIFOs by destination address
Mutex g_recvmutex;
std::map<int, std::list<RPCMessage> > g_recvqueue;
std::map<int, std::list<DMAMessage> > g_drecvqueue;

extern bool g_quitting;
*/

/**
	@brief Thread for handling JTAG operations
 */
void JtagThread()
{
	LogDebug("hai from jtag thread\n");

	/*
	JtagDevice* pdev = reinterpret_cast<JtagDevice*>(_pData);
	FPGA* pfpga = dynamic_cast<FPGA*>(pdev);
	if(pfpga == NULL)
		THREAD_RETURN(0);
	RPCNetworkInterface* prif = pfpga->GetRPCNetworkInterface();
	DMANetworkInterface* pdif = pfpga->GetDMANetworkInterface();

	try
	{
		while(!g_quitting)
		{
			//Send data, if any is available
			{
				MutexLock lock(g_sendmutex);
				while(!g_sendqueue.empty())
				{
					RPCMessage msg = g_sendqueue.front();
					prif->SendRPCMessage(msg);
					g_sendqueue.pop_front();
				}
				while(!g_dsendqueue.empty())
				{
					DMAMessage msg = g_dsendqueue.front();

					//Sent, remove from the list
					if(pdif->SendDMAMessageNonblocking(msg))
						g_dsendqueue.pop_front();

					//Sender is busy, give up and try later
					else
						break;
				}
			}

			//Poll for receive data
			{
				RPCMessage msg;
				DMAMessage dmsg;

				if(prif->RecvRPCMessage(msg))
				{
					MutexLock lock(g_recvmutex);
					g_recvqueue[msg.to].push_back(msg);
				}

				if(pdif->RecvDMAMessage(dmsg))
				{
					MutexLock lock(g_recvmutex);
					g_drecvqueue[dmsg.to].push_back(dmsg);
				}
			}
		}
	}
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		exit(-1);
	}

	THREAD_RETURN(0);
	*/
}

