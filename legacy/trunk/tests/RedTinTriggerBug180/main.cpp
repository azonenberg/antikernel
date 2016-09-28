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
	@brief Test case for bug #180
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
		
		//Trigger when uart_rpc_rx_data is 'hxxxx8010
		std::vector<Oscilloscope::TriggerType> triggers;
		for(int i=0; i<32; i++)
			triggers.push_back(Oscilloscope::TRIGGER_TYPE_DONTCARE);
		
		//For now, look for 'bxxxx...10
		//0:15 are don't cares since they change
		triggers[16] = Oscilloscope::TRIGGER_TYPE_HIGH;
		for(int i=17; i<=32; i++)
			triggers[i] = Oscilloscope::TRIGGER_TYPE_LOW;
		triggers[30] = Oscilloscope::TRIGGER_TYPE_HIGH;
		scope.SetTriggerForChannel(scope.GetChannel("uart_rpc_rx_data"), triggers);
		
		std::vector<Oscilloscope::TriggerType> triggers2;
		triggers2.push_back(Oscilloscope::TRIGGER_TYPE_HIGH);	//Bit 127
		scope.SetTriggerForChannel(scope.GetChannel("uart_rpc_rx_en"), triggers2);

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
		
		//Got the data, now try to make sense of it
		//Just decode one channel of the UART traffic for now, other stuff will use other tests
		printf("Running protocol decode...\n");
		NameServer namesrvr(&scope.m_iface);
		UARTDecoder decoder("uart", "#00ff00", namesrvr);
		decoder.SetInput(0, scope.GetChannel("uart_rx"));
		decoder.GetParameter("Baud rate").SetIntVal(115200);
		decoder.Refresh();
		
		//Get the data
		AsciiCapture* capture = dynamic_cast<AsciiCapture*>(decoder.GetData());
		if(capture == NULL)
		{
			throw JtagExceptionWrapper(
				"Data is null or not a valid ASCII capture",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Print it out and validate
		std::string message = "";
		for(size_t i=0; i<capture->m_samples.size(); i++)
		{
			const AsciiSample& sample = capture->m_samples[i];
			message += sample.m_sample;
			unsigned long long time = capture->m_timescale * sample.m_offset;
			unsigned long long len = capture->m_timescale * sample.m_duration;
			printf("    Byte %zu: '%c', starting at %llu ps, %llu ps long\n",
				i, sample.m_sample, time, len);
		}
		printf("Full message: %s\n", message.c_str());
		if(message != "Test Message")
		{
			throw JtagExceptionWrapper(
				"Message does not match expected value",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
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
