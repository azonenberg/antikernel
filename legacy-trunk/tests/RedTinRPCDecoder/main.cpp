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
	@brief RED TIN sanity check
	
	Runs a logic analyzer capture and sniffs NetworkedUARTTest
 */
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <signal.h>

#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/UART.h"
#include "../../src/jtagboards/jtagboards.h"

#include "../../src/scopehal/scopehal.h"
#include "../../src/scopehal/RedTinLogicAnalyzer.h"
#include "../../src/scopeprotocols/scopeprotocols.h"

#include <NOCSysinfo_constants.h>
#include <NetworkedUART_constants.h>
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

using namespace std;

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		string tty;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				tty = argv[++i];
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

		//Initialize the protocol decoder library
		printf("Initializing...\n");
		ScopeProtocolStaticInit();

		//Create the logic analyzer
		RedTinLogicAnalyzer scope(server, port, "UartLA");
		
		//Clear out old triggers
		scope.ResetTriggerConditions();
		
		//Load new trigger
		std::vector<Oscilloscope::TriggerType> triggers;
		triggers.push_back(Oscilloscope::TRIGGER_TYPE_HIGH);
		scope.SetTriggerForChannel(scope.GetChannel("uart_rpc_rx_en"), triggers);

		//Start the capture
		printf("Starting LA...\n");
		scope.StartSingleTrigger();
		
		//Generate some activity
		printf("Running NetworkedUARTTest against DUT...\n");
		char cmdline[512];
		snprintf(cmdline, sizeof(cmdline), "../../x86_64-linux-gnu/NetworkedUARTTest --server %s --port %d --tty %s > testbed_log.txt\n",
			server.c_str(), port, tty.c_str());
		system(cmdline);
		
		//Wait a few seconds for the LA to see the event, etc
		sleep(20);
		
		//Verify the LA triggered
		printf("Checking for trigger...\n");
		if(scope.PollTrigger() != Oscilloscope::TRIGGER_MODE_TRIGGERED)
		{
			throw JtagExceptionWrapper(
				"Expected scope to trigger but it didn't",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Pull the data
		printf("Acquiring data...\n");
		sigc::slot1<int, float> null_callback;
		scope.AcquireData(null_callback);
		
		//Decode the RPC traffic
		NameServer namesrvr(&scope.m_iface);
		RPCDecoder decoder("decoder", "#00ff00", namesrvr);
		decoder.SetInput("en", scope.GetChannel("uart_rpc_rx_en"));
		decoder.SetInput("ack", scope.GetChannel("uart_rpc_rx_ack"));
		decoder.SetInput("data", scope.GetChannel("uart_rpc_rx_data"));
		decoder.Refresh();
		
		//Get the data
		RPCCapture* capture = dynamic_cast<RPCCapture*>(decoder.GetData());
		if(capture == NULL)
		{
			throw JtagExceptionWrapper(
				"Data is null or not a valid RPC capture",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Expect four messages (set baud request, cycle count flush, rxdone)
		if(capture->m_samples.size() != 4)
		{
			throw JtagExceptionWrapper(
				"Expected four messages but got something else",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Get the clock rate info
		printf("Querying system information...\n");
		uint32_t baud = 115200;
		uint16_t saddr = namesrvr.ForwardLookup("sysinfo");
		uint16_t uaddr = namesrvr.ForwardLookup("uart");
		printf("   Sysinfo is at %04x\n", saddr);
		printf("   UART is at %04x\n", uaddr);
		RPCAndDMANetworkInterface* iface = dynamic_cast<RPCAndDMANetworkInterface*>(&scope.m_iface);
		RPCMessage rmsg;
		iface->RPCFunctionCall(saddr, SYSINFO_GET_CYCFREQ, 0, baud, 0, rmsg);
		uint32_t brgen = rmsg.data[1];
		printf("    Baud rate divisor should be %08x\n", brgen);
		
		//Process it
		uint16_t test_node_addr = 0;
		for(size_t i=0; i<capture->m_samples.size(); i++)
		{
			//Print
			const RPCSample& sample = capture->m_samples[i];
			const RPCMessage& msg = sample.m_sample;
			printf("Message %d:\n    %s\n", (int)i, msg.Format().c_str());
			unsigned long long time = capture->m_timescale * sample.m_offset;
			unsigned long long len = capture->m_timescale * sample.m_duration;
			printf("    Start:  %llu ps\n", time);
			printf("    Length: %llu ps (%llu clocks)\n", len, (unsigned long long)sample.m_duration);
						
			//Length should be 4 clock cycles
			if(sample.m_duration != 4)
			{
				throw JtagExceptionWrapper(
					"Message duration is wrong",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
			
			//Sanity check
			switch(i)
			{
			
			//First message should be a function call to set the baud rate
			case 0:
				if(
					(msg.to != uaddr) ||
					(msg.type != RPC_TYPE_CALL) ||
					(msg.callnum != UART_SET_BAUD) ||
					(msg.data[0] != baud)
					/* data[1] and [2] are don't cares */
					)
				{
					throw JtagExceptionWrapper(
						"First message should be \"set baud rate\" but doesn't make sense",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			
				test_node_addr = msg.from;
				printf("    Test case was assigned ephemeral address %04x\n", test_node_addr);
				if( (test_node_addr & 0xC000) != 0xC000)
				{
					throw JtagExceptionWrapper(
						"Test case address is invalid (should be C000/2)",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			
				break;
			
			//followed by a return from the sysinfo node
			case 1:
				if(
					(msg.from != saddr) ||
					(msg.to != uaddr) ||
					(msg.type != RPC_TYPE_RETURN_SUCCESS) ||
					(msg.callnum != SYSINFO_GET_CYCFREQ) ||
					(msg.data[1] != brgen)
					/* data[0] and [2] are don't cares */
					)
				{
					throw JtagExceptionWrapper(
						"Second message should be successful baud rate return but doesn't make sense",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
				break;
				
			//Rx start
			case 2: 
				if(
					(msg.from != test_node_addr) ||
					(msg.to != uaddr) ||
					(msg.type != RPC_TYPE_CALL) ||
					(msg.callnum != UART_RX_START)
					/* data are don't cares */
					)
				{
					throw JtagExceptionWrapper(
						"Third message should be \"rx start\" but doesn't make sense",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
				break;	
				
			//Rx done
			case 3:
				if(
					(msg.from != test_node_addr) ||
					(msg.to != uaddr) ||
					(msg.type != RPC_TYPE_CALL) ||
					(msg.callnum != UART_RX_DONE)
					/* data are don't cares */
					)
				{
					throw JtagExceptionWrapper(
						"Third message should be \"rx done\" but doesn't make sense",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
				break;	
			}
		}
		
		printf("OK\n");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
