/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2018 Andrew D. Zonenberg                                                                          *
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
	@brief Main source file for svfdumper
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>

#include "../../../src/jtaghal/jtaghal.h"
#include <signal.h>

using namespace std;

void PrintDeviceInfo(JtagDevice* pdev);

#ifndef _WIN32
void sig_handler(int sig);
#endif

/**
	@brief Program entry point
 */
int main(int argc, char* argv[])
{
#ifndef _WINDOWS
	signal(SIGPIPE, sig_handler);
#endif

	try
	{
		Severity console_verbosity = Severity::NOTICE;

		//Global settings
		unsigned short port = 0;
		string server = "";
		string svfpath;

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

			if(s == "--port")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --port\n");
					return 1;
				}

				port = atoi(argv[++i]);
			}
			else if(s == "--server")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --server\n");
					return 1;
				}

				server = argv[++i];
			}
			else if(s == "--svfpath")
			{
				//Expect device index and bitfile
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --svfpath\n");
					return 1;
				}
				svfpath = argv[++i];
			}
			else
			{
				fprintf(stderr, "Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
				return 1;
			}
		}

		//Set up logging
		g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

		//Abort cleanly if no server specified
		if( (port == 0) || (server.empty()) || (svfpath.empty()) )
		{
			LogWarning("Missing required argument (server, port, or SVF path)\n");
			return 0;
		}

		//Connect to the server
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		LogNotice("Connected to JTAG daemon at %s:%d\n", server.c_str(), port);
		LogNotice("Querying adapter...\n");
		LogNotice("    Remote JTAG adapter is a %s (serial number \"%s\", userid \"%s\", frequency %.2f MHz)\n",
			iface.GetName().c_str(), iface.GetSerial().c_str(), iface.GetUserID().c_str(), iface.GetFrequency()/1E6);

		//Initialize the chain
		LogNotice("Initializing chain...\n");
		iface.InitializeChain();

		//Get device count and see what we've found
		LogNotice("Scan chain contains %d devices\n", (int)iface.GetDeviceCount());

		if(iface.GetDeviceCount() != 1)
		{
			LogWarning("svfdumper requires a chain with exactly one device\n");
			return 0;
		}
		auto target = iface.GetDevice(0);
		if(target == NULL)
		{
			LogWarning("null target\n");
			return 0;
		}
		target->PrintInfo();

		//Verify it's an Ultrascale device for now
		XilinxUltrascaleDevice* utarget = dynamic_cast<XilinxUltrascaleDevice*>(target);
		if(utarget == NULL)
		{
			LogWarning("not ultrascale\n");
			return 0;
		}

		utarget->AnalyzeSVF(svfpath);
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	//Done
	return 0;
}

#ifndef _WIN32
/**
	@brief SIGPIPE handler

	\ingroup jtagclient
 */
void sig_handler(int sig)
{
	switch(sig)
	{
		case SIGPIPE:
			//ignore
			break;
	}
}
#endif

