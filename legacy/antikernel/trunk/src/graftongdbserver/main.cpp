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
	@brief Entry point for graftongdbserver
 */

#include "graftongdbserver.h"
#include <unistd.h>
#include <signal.h>

#include <GraftonCPURPCDebugOpcodes_constants.h>

using namespace std;

void ShowUsage();
void ShowVersion();

#ifndef _WINDOWS
void sig_handler(int sig);
#endif

Socket g_socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);

int main(int argc, char* argv[])
{
	unsigned short port = 0;
	unsigned short lport = 0;
	string server = "localhost";
	bool nobanner = false;
	string cpu = "asdf";
	
	#ifndef _WINDOWS
	signal(SIGINT, sig_handler);
	#endif
	
	//Parse command-line arguments
	for(int i=1; i<argc; i++)
	{
		string s(argv[i]);
		
		if(s == "--help")
		{
			ShowUsage();
			return 0;
		}
		else if(s == "--port")
			port = atoi(argv[++i]);
		else if(s == "--lport")
			lport = atoi(argv[++i]);
		else if(s == "--server")
			server = argv[++i];
		else if(s == "--nobanner")
			nobanner = true;
		else if(s == "--cpu")
			cpu = argv[++i];
		else if(s == "--version")
		{
			ShowVersion();
			return 0;
		}
		else
		{
			printf("Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
			return 1;
		}
	}
	
	//Print version number by default
	if(!nobanner)
		ShowVersion();
	
	int err_code = 0;	
	try
	{
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		printf("Looking up address of CPU...\n");
		NameServer nameserver(&iface);
		uint16_t caddr = nameserver.ForwardLookup(cpu);
		printf("CPU is at %04x\n", caddr);
		
		//Connect to the CPU (which should be in sleep mode) and send it the magic packet
		printf("Connecting to debug core...\n");
		RPCMessage rxm;
		iface.RPCFunctionCall(caddr, DEBUG_CONNECT, 0, 0, 0, rxm);
		if(rxm.data[1] == 0xdeadbeef)
			printf("Connected\n");
		else
		{
			throw JtagExceptionWrapper(
				"Didn't get valid response from debug core",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		#ifndef _WINDOWS
		//Set SO_LINGER so we can reuse the port immediately in case of a failed test
		struct linger sol;
		sol.l_onoff = 1;
		sol.l_linger = 0;	
		if(0 != setsockopt(g_socket, SOL_SOCKET, SO_LINGER, &sol, sizeof(sol)))
			printf("[graftongdbserver] WARNING: Failed to set SOL_LINGER, connection reuse may not be possible\n");
		#endif
			
		//Create the socket server
		g_socket.Bind(lport);
		g_socket.Listen();
		
		//Wait for connections (can only handle one at a time)
		while(true)
		{
			try
			{
				Socket csock = g_socket.Accept();
				GDBClient client(csock, caddr, iface);
				client.Run();
				//terminate after one connection for now
				break;
			}
			catch(const JtagException& ex)
			{
				printf("%s\n", ex.GetDescription().c_str());
				break;
			}			
		}
	}
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}

void ShowUsage()
{
	printf(
		"Usage: graftongdbserver [args]\n"
		"\n"
		"General arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --lport PORT                                     Specifies the port number to listen on\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --port PORT                                      Specifies the jtagd port number to connect to\n"
		"    --server [hostname]                              Specifies the hostname of the nocswitch server to connect to (defaults to localhost).\n"
		"    --device [index]                                 Specifies the NoC hostname of the CPU to debug.\n"
		"    --version                                        Prints program version number and exits.\n"
		"\n"
		);
}

void ShowVersion()
{
	printf(
		"GDB server for GRAFTON softcore [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}

#ifndef _WINDOWS
void sig_handler(int sig)
{
	switch(sig)
	{
		case SIGINT:
		
			printf("[graftongdbserver] Quitting...\n");		
			close(g_socket);
			g_socket = -1;
			break;
			
		case SIGPIPE:
			//ignore
			break;
	}
}
#endif
