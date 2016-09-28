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

using namespace std;

int main(int argc, char* argv[])
{
	JtagInterface* iface = NULL;
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
		
		//Wait a few seconds for the LA to see the event and finish capturing
		sleep(15);
		
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
		
		//Decode the DMA traffic
		NameServer namesrvr(&scope.m_iface);
		DMADecoder decoder("decoder", "#00ff00", namesrvr);
		decoder.SetInput("en", scope.GetChannel("uart_dma_rx_en"));
		decoder.SetInput("ack", scope.GetChannel("uart_dma_rx_ack"));
		decoder.SetInput("data", scope.GetChannel("uart_dma_rx_data"));
		decoder.Refresh();
		
		//Get the data
		DMACapture* capture = dynamic_cast<DMACapture*>(decoder.GetData());
		if(capture == NULL)
		{
			throw JtagExceptionWrapper(
				"Data is null or not a valid DMA capture",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}

		//Expect two messages (write and read request)
		if(capture->m_samples.size() !=2)
		{
			throw JtagExceptionWrapper(
				"Expected two messages but got something else",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Process it
		for(size_t i=0; i<capture->m_samples.size(); i++)
		{
			//Print
			const DMASample& sample = capture->m_samples[i];
			const DMAMessage& msg = sample.m_sample;
			printf("Message %d: from %04x to %04x\n", (int)i,
				msg.from, msg.to);
			printf("    Opcode: %d ", msg.opcode);
			switch(msg.opcode)
			{
				case DMA_OP_READ_REQUEST:
					printf("(read request)");
					break;
				case DMA_OP_READ_DATA:
					printf("(read data)");
					break;
				case DMA_OP_WRITE_REQUEST:
					printf("(write request)");
					break;
				default:
					printf("(invalid)");
					break;
			}
			printf("\n");
			printf("    Length: %d words\n", msg.len);
			unsigned long long time = capture->m_timescale * sample.m_offset;
			unsigned long long len = capture->m_timescale * sample.m_duration;
			printf("    Start:  %llu ps\n", time);
			printf("    Length: %llu ps (%llu clocks)\n", len, (unsigned long long)sample.m_duration);
			
			//Print data if not a read request
			if(msg.opcode != DMA_OP_READ_REQUEST)
			{
				for(int j=0; j<msg.len; j++)
					printf("    D[%d]:  %08x\n", j, msg.data[j]);
					
				//Length should be 3 header words plus body length
				if(sample.m_duration != (3 + msg.len) )
				{
					throw JtagExceptionWrapper(
						"Message duration is wrong",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
				
				//Validate content
				if( (msg.data[0] != 0x48656c6c) ||
					(msg.data[1] != 0x6f20576f) ||
					(msg.data[2] != 0x726c6400)
					)
				{
					throw JtagExceptionWrapper(
						"Message data is wrong",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
			}
			else
			{
				//Length should be 3 header words only
				if(sample.m_duration != 3)
				{
					throw JtagExceptionWrapper(
						"Message duration is wrong",
						"",
						JtagException::EXCEPTION_TYPE_FIRMWARE);
				}
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
	delete iface;
	iface = NULL;
	return err_code;
}
