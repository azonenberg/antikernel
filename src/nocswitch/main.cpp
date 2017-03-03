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
	@brief Main function for nocswitch
 */
#include "nocswitch.h"

using namespace std;

void ShowUsage();
void ShowVersion();

#ifndef _WINDOWS
void sig_handler(int sig);
#endif

Socket g_socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);

bool g_quitting = false;

int main(int argc, char* argv[])
{
	#ifndef _WINDOWS
	signal(SIGPIPE, sig_handler);
	signal(SIGINT, sig_handler);
	#endif

	int exit_code = 0;

	try
	{
		//Global settings
		unsigned short port = 0;
		unsigned short lport = 0;
		string server = "localhost";
		bool nobanner = false;

		//Device index
		int devnum = 0;

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
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"",
						JtagException::EXCEPTION_TYPE_BOARD_FAULT);
				}

				port = atoi(argv[++i]);
			}
			else if(s == "--lport")
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"",
						JtagException::EXCEPTION_TYPE_BOARD_FAULT);
				}

				lport = atoi(argv[++i]);
			}
			else if(s == "--server")
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"",
						JtagException::EXCEPTION_TYPE_BOARD_FAULT);
				}

				server = argv[++i];
			}
			else if(s == "--nobanner")
				nobanner = true;
			else if(s == "--device")
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"",
						JtagException::EXCEPTION_TYPE_BOARD_FAULT);
				}

				//TODO: sanity check
				devnum = atoi(argv[++i]);
			}
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

		//Connect to the server
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		printf("Connected to JTAG daemon at %s:%d\n", server.c_str(), port);
		printf("Querying adapter...\n");
		printf("    Remote JTAG adapter is a %s (serial number \"%s\", userid \"%s\", frequency %.2f MHz)\n",
			iface.GetName().c_str(), iface.GetSerial().c_str(), iface.GetUserID().c_str(), iface.GetFrequency()/1E6);

		//Initialize the chain
		printf("Initializing chain...\n");
		iface.InitializeChain();

		//Get device count and see what we've found
		printf("Scan chain contains %d devices\n", (int)iface.GetDeviceCount());

		//Walk the chain and see what we find
		//No need for mutexing here since the device will lock the high-level interface when necessary
		JtagDevice* pdev = iface.GetDevice(devnum);
		if(pdev == NULL)
		{
			throw JtagExceptionWrapper(
				"Device is null - unrecognized device ID?",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		printf("Device %2d is a %s\n", devnum, pdev->GetDescription().c_str());

		//Make sure it's an FPGA, if not something is wrong
		FPGA* pfpga = dynamic_cast<FPGA*>(pdev);
		if(pfpga == NULL)
		{
			throw JtagExceptionWrapper(
				"Device is not an FPGA, no NoC connection possible",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}

		//Make sure it's configured, if not something is wrong
		if(!pfpga->IsProgrammed())
		{
			throw JtagExceptionWrapper(
				"Device is blank, no NoC connection possible",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}

		//Probe the FPGA and see if it has any virtual TAPs on board
		pfpga->ProbeVirtualTAPs();
		if(!pfpga->HasRPCInterface())
		{
			throw JtagExceptionWrapper(
				"No RPC interface found, no NoC connection possible",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		if(!pfpga->HasDMAInterface())
		{
			throw JtagExceptionWrapper(
				"No DMA interface found, no NoC connection possible",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}

		//All is well
		//TODO: Figure out how to do name server caching

		//Sit back and listen for incoming connections
		//Create the socket server
		g_socket.Bind(lport);

		//Set SO_LINGER so we can reuse the port immediately in case of a failed test
		#ifndef _WINDOWS
		struct linger sol;
		sol.l_onoff = 1;
		sol.l_linger = 0;
		if(0 != setsockopt(g_socket, SOL_SOCKET, SO_LINGER, (const char*)&sol, sizeof(sol)))
			printf("[nocswitch] WARNING: Failed to set SOL_LINGER, connection reuse may not be possible\n");
		#endif

		//Figure out the port number
		if(lport == 0)
		{
			sockaddr_in buf;
			socklen_t len = sizeof(buf);
			if(0 != getsockname(g_socket, reinterpret_cast<sockaddr*>(&buf), &len))
			{
				throw JtagExceptionWrapper(
					"Failed to get port number",
					"",
					JtagException::EXCEPTION_TYPE_NETWORK);
			}
			FILE* fp = fopen("nocswitch-port.txt", "w");
			if(!fp)
			{
				throw JtagExceptionWrapper(
					"Failed to open port file",
					"",
					JtagException::EXCEPTION_TYPE_NETWORK);
			}
			unsigned short kport = ntohs(buf.sin_port);
			printf("    Listening on port %u\n", kport);
			fflush(stdout);
			fprintf(fp, "%u\n", kport);
			fclose(fp);
		}

		//Get ready to wait for connections
		g_socket.Listen();
		fflush(stdout);

		//Start the JTAG thread AFTER creating and binding the socket so we don't have problems with the JTAG interface
		//mysteriously disappearing on us if the port is already used. Fixes #31.
		Thread jtag_thread(JtagThreadProc, pdev);

		//Wait for connections
		std::vector<Thread> threads;
		std::vector<int> sockets;
		int cnocaddr = 0xc000;
		while(true)
		{
			try
			{
				Socket client = g_socket.Accept();

				//Allocate a new address to this node
				//TODO: Provide interface for querying this address
				int addr = cnocaddr;
				cnocaddr ++;
				if(cnocaddr >= 0xFFFF)
					printf("All addresses allocated, no new connections possible (see #147)\n");
				printf("Allocating address 0x%04x to new client\n", addr);
				fflush(stdout);

				//Spawn a thread to handle this connection
				ConnectionThreadProcData* data = new ConnectionThreadProcData;
				data->addr = addr;
				data->client_socket = client.Detach();
				#ifndef _WINDOWS
				if(0 != setsockopt(data->client_socket, SOL_SOCKET, SO_LINGER, &sol, sizeof(sol)))
					printf("[nocswitch] WARNING: Failed to set SOL_LINGER on client socket, connection reuse may not be possible\n");
				#endif
				sockets.push_back(data->client_socket);

				threads.push_back(Thread(ConnectionThreadProc, data));
			}
			catch(const JtagException& ex)
			{
				break;
			}
		}

		//We're terminating - wait for client threads to stop
		for(size_t i=0; i<threads.size(); i++)
			threads[i].WaitUntilTermination();

		//Wait for JTAG thread to stop
		jtag_thread.WaitUntilTermination();
	}

	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		exit_code = 1;
	}

	//Done
	close(g_socket);
	return exit_code;
}

void ShowUsage()
{
	printf(
		"Usage: nocswitch [args]\n"
		"\n"
		"General arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --lport PORT                                     Specifies the port number to listen on (defaults to 50124)\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --port PORT                                      Specifies the jtagd port number to connect to (defaults to 50123)\n"
		"    --server [hostname]                              Specifies the hostname of the jtagd server to connect to (defaults to localhost).\n"
		"    --device [index]                                 Specifies the index of the device to use.\n"
		"    --version                                        Prints program version number and exits.\n"
		"\n"
		);
}

#ifndef _WINDOWS
void sig_handler(int sig)
{
	switch(sig)
	{
		case SIGINT:

			printf("[nocswitch] Quitting...\n");
			close(g_socket);
			g_socket = -1;
			g_quitting = true;
			break;

		case SIGPIPE:
			//ignore
			break;
	}
}
#endif

/**
	@brief Prints program version number
 */
void ShowVersion()
{
	printf(
		"Emulated NoC switch [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}
