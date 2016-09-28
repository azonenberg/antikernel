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
	@brief GRAFTON Dhrystone benchmark
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>
#include <NOCSysinfo_constants.h>

#include <signal.h>

using namespace std;

void CheckValue(const char* name, int expected, int actual);

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				++i;
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
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Address lookup
		printf("Looking up address of CPU\n");
		NameServer nameserver(&iface);
		uint16_t caddr = nameserver.ForwardLookup("cpu");
		printf("CPU is at %04x\n", caddr);
		uint16_t taddr = iface.GetClientAddress();
		printf("We are at %04x\n", taddr);
		
		uint16_t saddr = nameserver.ForwardLookup("sysinfo");
		printf("Sysinfo is at %04x\n", saddr);
		printf("Looking up system clock frequency...\n");
		RPCMessage rxm;
		iface.RPCFunctionCall(saddr, SYSINFO_QUERY_FREQ, 0, 0, 0, rxm);
		uint32_t sysclk_period = rxm.data[1];
		float mhz = 1000000.0f / sysclk_period;
		printf("    System clock period is %d ps (%.2f MHz)\n", sysclk_period, mhz);
		
		//Configure the Dhrystone setup
		int num_runs = 30000;
		RPCMessage msg;
		msg.from = taddr;
		msg.to = caddr;
		msg.type = RPC_TYPE_INTERRUPT;
		msg.callnum = 0;
		msg.data[0] = num_runs;
		msg.data[1] = 0;
		msg.data[2] = 0;
		iface.SendRPCMessage(msg);
		
		//Get something back
		if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 25))
		{
			throw JtagExceptionWrapper(
				"Timeout on setup message (expected response within 25 sec but nothing arrived)",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);					
		}
		double start = GetTime();
		
		//Wait for the main loop to finish
		if(!iface.RecvRPCMessageBlockingWithTimeout(rxm, 10))
		{
			throw JtagExceptionWrapper(
				"Timeout on termination message (expected response within 10 sec but nothing arrived)",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);					
		}
		double dt = GetTime() - start;
		
		//Read back the computed values
		if(dt < 2)
		{
			throw JtagExceptionWrapper(
				"Benchmark finished too quickly to get meaningful results, need to use more runs",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Get all of the messages
		RPCMessage data_dumps[10];
		for(int i=0; i<10; i++)
		{
			if(!iface.RecvRPCMessageBlockingWithTimeout(data_dumps[i], 5))
			{
				throw JtagExceptionWrapper(
					"Timeout on data dump message (expected response within 5 sec but nothing arrived)",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);	
			}
			
			//Initial sanity check
			if( (data_dumps[i].callnum != (i+2)) || (data_dumps[i].type != RPC_TYPE_INTERRUPT) )
			{
				throw JtagExceptionWrapper(
					"Got invalid data dump message",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		
		//Sanity check
		CheckValue("Bool_Glob",			1,				data_dumps[0].data[0]);
		CheckValue("Int_Glob",			5, 				data_dumps[0].data[1]);
		CheckValue("Ch_1_Glob",			'A',			data_dumps[0].data[2]);
		CheckValue("Ch_2_Glob",			'B',			data_dumps[1].data[0]);
		CheckValue("Arr_1_Glob[8]",		7, 				data_dumps[1].data[1]);
		CheckValue("Arr_2_Glob[8][7]",	num_runs + 10,	data_dumps[1].data[2]);
		
		CheckValue("Ptr_Glob->Discr",					0,	data_dumps[2].data[0]);
		//Ptr_Glob->Ptr_Comp is implementation dependent
		CheckValue("Ptr_Glob->variant.var_1.Enum_Comp",	2,	data_dumps[2].data[2]);
		
		CheckValue("Ptr_Glob->variant.var_1.Int_Comp",			17,	data_dumps[3].data[0]);
		CheckValue("Next_Ptr_Glob->Discr",						0, 	data_dumps[3].data[1]);
		CheckValue("Next_Ptr_Glob->variant.var_1.Enum_comp",	1,	data_dumps[3].data[2]);
		
		CheckValue("Next_Ptr_Glob->variant.var_1.Int_Comp",		18,	data_dumps[4].data[0]);
		CheckValue("Int_1_Loc",									5, 	data_dumps[4].data[1]);
		CheckValue("Int_2_Loc",									13,	data_dumps[4].data[2]);
		CheckValue("Int_3_Loc",		7,	data_dumps[5].data[0]);
		CheckValue("Enum_Loc",		1, 	data_dumps[5].data[1]);
		
		//TODO: Strings
		
		//Print stats
		printf("\n\nFinished %d runs of Dhrystone loop in %.2f ms\n", num_runs, dt*1000);
		float dhrystones_per_sec = num_runs / dt;
		printf("%.2f Dhrystones/sec\n", dhrystones_per_sec);
		float dmips = dhrystones_per_sec / 1757.0f;
		float dmips_mhz = dmips / mhz;
		printf("%.2f DMIPS (%.3f DMIPS/MHz)\n", dmips, dmips_mhz);
		
		//Print profiling stats
		printf("Profiling counters:\n");
		printf("    cp0_prof_clocks    = %d\n", data_dumps[6].data[1]);
        printf("    cp0_prof_insns     = %d\n", data_dumps[6].data[2]);
        printf("        IPC            = %.2f\n", static_cast<float>(data_dumps[6].data[2]) / data_dumps[6].data[1]);
        printf("    cp0_prof_dmisses   = %d\n", data_dumps[7].data[1]);
        printf("    cp0_prof_dreads    = %d\n", data_dumps[7].data[2]);    
        float missrate = static_cast<float>(data_dumps[7].data[1]) / data_dumps[7].data[2];
        printf("        Miss rate      = %.2f %%\n", missrate * 100);
        printf("        Hit rate       = %.2f %%\n", (1.0f - missrate) * 100);
        printf("    cp0_prof_imisses   = %d\n", data_dumps[8].data[1]);
        printf("    cp0_prof_ireads    = %d\n", data_dumps[8].data[2]);
        missrate = static_cast<float>(data_dumps[8].data[1]) / data_dumps[8].data[2];
        printf("        Miss rate      = %.2f %%\n", missrate * 100);
        printf("        Hit rate       = %.2f %%\n", (1.0f - missrate) * 100);
        printf("    cp0_prof_dmisstime = %d\n", data_dumps[9].data[1]);
        printf("        Avg miss time  = %.2f clocks\n",
			static_cast<float>(data_dumps[9].data[1]) / data_dumps[7].data[1]);
        printf("    cp0_prof_imisstime = %d\n", data_dumps[9].data[2]);
        printf("        Avg miss time  = %.2f clocks\n",
			static_cast<float>(data_dumps[9].data[2]) / data_dumps[8].data[1]);
		
		return 0;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

void CheckValue(const char* name, int expected, int actual)
{
	printf("%-40s: %5d (should be %5d)\n", name, actual, expected);
	if(actual != expected)
	{
		throw JtagExceptionWrapper(
			"Incorrect results",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}
