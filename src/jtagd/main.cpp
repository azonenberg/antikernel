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
	@brief Entry point and main connection loop for jtag daemon
 */

#include "jtagd.h"

using namespace std;

void sig_handler(int sig);

bool g_quit = false;
Socket g_socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);

void ShowUsage();
void ShowVersion();
void ListAdapters();

int main(int argc, char* argv[])
{
	try
	{
		//Command-line flag data
		enum api_types
		{
			API_DIGILENT,
			API_FTDI,
			API_PIPE,
			API_UNSPECIFIED
		} api_type = API_UNSPECIFIED;
		string adapter_serial = "";
		unsigned short port = 0;		//random default port

		Severity console_verbosity = Severity::NOTICE;

		//Operations to do
		enum
		{
			OP_NORMAL,
			OP_LIST,
			OP_HELP,
			OP_VERSION
		} op = OP_NORMAL;

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

			if(s == "--api")
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"");
				}

				string sapi = argv[++i];
				if(sapi == "digilent")
					api_type = API_DIGILENT;
				else if(sapi == "ftdi")
					api_type = API_FTDI;
				else if(sapi == "pipe")
					api_type = API_PIPE;
				else
				{
					printf("Unrecognized interface API \"%s\", use --help\n", sapi.c_str());
					return 1;
				}
			}
			else if(s == "--help")
				op = OP_HELP;
			else if(s == "--list")
				op = OP_LIST;
			else if(s == "--port")
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"");
				}

				port = atoi(argv[++i]);
			}
			else if(s == "--serial")
			{
				if(i+1 >= argc)
				{
					throw JtagExceptionWrapper(
						"Not enough arguments",
						"");
				}

				adapter_serial = argv[++i];
			}
			else if(s == "--version")
				op = OP_VERSION;
			else
			{
				printf("Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
				return 1;
			}
		}

		//Set up logging
		g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

		//Do special operations if requested
		switch(op)
		{
			case OP_HELP:
				ShowUsage();
				return 0;

			case OP_LIST:
				ListAdapters();
				return 0;

			case OP_VERSION:
				ShowVersion();
				return 0;

			default:
				break;
		}

		//Print version number etc (if not in quiet mode)
		ShowVersion();

		//Sanity check
		if( (api_type == API_UNSPECIFIED) || (adapter_serial == "") )
		{
			LogError("ERROR: --api and --serial are required\n");
			return 1;
		}

		//Start up the requested API
		JtagInterface* iface = NULL;
		switch(api_type)
		{
			case API_FTDI:
				#ifdef HAVE_FTD2XX
					iface = new FTDIJtagInterface(adapter_serial);
				#else
					LogError("This jtagd was compiled without libftd2xx support\n");
					return 1;
				#endif
				break;

			case API_DIGILENT:
				#ifdef HAVE_DJTG
				{
					//Search for the interface
					int nif = -1;
					int ndigilent = DigilentJtagInterface::GetInterfaceCount();
					for(int i=0; i<ndigilent; i++)
					{
						try
						{
							DigilentJtagInterface iface_tmp(i);
							if(iface_tmp.GetSerial() == adapter_serial)
							{
								nif = i;
								break;
							}
						}
						catch(const JtagException& e)
						{
							//just write off this adapter - maybe someone else is using it!
						}
					}

					//Sanity check
					if(nif < 0)
					{
						LogError(
							"Requested Digilent adapter with serial number \"%s\" was not found!\n"
							"Use --list to see currently connected adapters\n",
							adapter_serial.c_str());
					}

					//Create the interface
					iface = new DigilentJtagInterface(nif);
				}
				#else	//#ifdef HAVE_DJTG
					LogError("This jtagd was compiled without Digilent API support\n");
				#endif
				break;

			case API_PIPE:
				iface = new PipeJtagInterface;
				break;

			default:
				LogError("Unrecognized API\n");
				return 1;
		}

		LogNotice("Connected to interface \"%s\" (serial number \"%s\")\n",
			iface->GetName().c_str(), iface->GetSerial().c_str());

		//Install signal handler
		signal(SIGINT, sig_handler);
		signal(SIGPIPE, sig_handler);

		//Create the socket server
		g_socket.Bind(port);

		//Figure out the port number
		if(port == 0)
		{
			sockaddr_in buf;
			socklen_t len = sizeof(buf);
			if(0 != getsockname(g_socket, reinterpret_cast<sockaddr*>(&buf), &len))
			{
				LogError("Failed to get port number!\n");
				delete iface;
				return 1;
			}
			FILE* fp = fopen("jtagd-port.txt", "w");
			if(!fp)
			{
				LogError("Failed to open port file\n");
				delete iface;
				return 1;
			}
			unsigned short port = ntohs(buf.sin_port);
			LogNotice("    Listening on port %u\n", port);
			fflush(stdout);
			fprintf(fp, "%us\n", port);
			fclose(fp);
		}

		//Wait for connections
		g_socket.Listen();
		while(true)
		{
			try
			{
				Socket client = g_socket.Accept();
				if(!client.IsValid())
					break;
				LogNotice("Client connected\n");
				ProcessConnection(iface, client);
				LogNotice("Client disconnected\n");
			}
			catch(const JtagException& ex)
			{
				break;
			}
		}

		//Print interface statistics
		LogNotice("Total number of shift operations:       %zu\n", iface->GetShiftOpCount());
		LogNotice("Total number of recoverable errors:     %zu\n", iface->GetRecoverableErrorCount());
		LogNotice("Total number of data bits:              %zu\n", iface->GetDataBitCount());
		LogNotice("Total number of mode bits:              %zu\n", iface->GetModeBitCount());
		LogNotice("Total number of dummy clocks:           %zu\n", iface->GetDummyClockCount());
		size_t cycles = iface->GetDataBitCount() + iface->GetModeBitCount() + iface->GetDummyClockCount();
		LogNotice("Total TCK cycles:                       %zu\n", cycles);
		LogNotice("Total host-side shift time:             %.2f ms\n", iface->GetShiftTime() * 1000);
		double boardtime = cycles / static_cast<double>(iface->GetFrequency());
		LogNotice("Calculated board-side shift time:       %.2f ms\n", boardtime * 1000);
		double latency = iface->GetShiftTime() - boardtime;
		LogNotice("Calculated total latency:               %.2f ms\n", latency * 1000);
		LogNotice("Calculated average latency:             %.2f ms\n", (latency * 1000) / iface->GetShiftOpCount());

		//Clean up
		delete iface;
	}
	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	return 0;
}

void sig_handler(int sig)
{
	switch(sig)
	{
		case SIGINT:
			g_quit = true;
			close(g_socket.Detach());	//forcibly close the socket to terminate all in-progress IO
			LogNotice("Quitting...\n");
			break;

		case SIGPIPE:
			//ignore
			break;
	}
}

/**
	@brief Prints usage information
 */
void ShowUsage()
{
	LogNotice(
		"Usage: jtagd [OPTION]\n"
		"\n"
		"Arguments:\n"
		"    --api digilent|ftdi                              Specifies whether to use the Digilent or FTDI API for connecting to the\n"
		"                                                       JTAG adapter. This argument is mandatory.\n"
		"    --help                                           Displays this message and exits.\n"
		"    --list                                           Prints a listing of connected adapters and exits.\n"
		"    --port PORT                                      Specifies the port number the daemon should listen on.\n"
		"    --serial SERIAL_NUM                              Specifies the serial number of the JTAG adapter. This argument is mandatory.\n"
		);
}

/**
	@brief Prints program version number
 */
void ShowVersion()
{
	LogNotice(
		"JTAG server daemon [git rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n",
		"TODO");
}

/**
	@brief Lists the connected JTAG adapters
 */
void ListAdapters()
{
	try
	{
		ShowVersion();

		//disable compiler warning if no APIs are found
		#if( defined(HAVE_DJTG) || defined(HAVE_FTD2XX) )
			string ver;
			int ndev = 0;
		#endif

		#ifdef HAVE_DJTG
			ver = DigilentJtagInterface::GetAPIVersion();
			LogNotice("Digilent API version: %s\n", ver.c_str());
			ndev = DigilentJtagInterface::GetInterfaceCount();
			LogNotice("    Enumerating interfaces... %d found\n", ndev);
			if(ndev == 0)
				LogNotice("No interfaces found\n");
			else
			{
				LogIndenter li;
				for(int i=0; i<ndev; i++)
				{
					try
					{
						DigilentJtagInterface iface(i);
						LogNotice("Interface %d: %s\n", i, iface.GetName().c_str());
						LogIndenter li;
						LogNotice("Serial number:  %s\n", iface.GetSerial().c_str());
						LogNotice("User ID:        %s\n", iface.GetUserID().c_str());
						LogNotice("Default clock:  %.2f MHz\n", iface.GetFrequency()/1000000.0f);
					}
					catch(const JtagException& e)
					{
						LogNotice("Interface %d: Could not be opened, maybe another jtagd instance is using it?\n", i);
					}
				}
			}
		#else	//#ifdef HAVE_DJTG
			printf("Digilent API version: not supported\n");
		#endif

		printf("\n");
		#ifdef HAVE_FTD2XX
			ver = FTDIJtagInterface::GetAPIVersion();
			LogNotice("FTDI API version: %s\n", ver.c_str());
			ndev = FTDIJtagInterface::GetInterfaceCount();
			LogNotice("    Enumerating interfaces... %d found\n", ndev);
			if(ndev == 0)
				LogNotice("No interfaces found\n");
			else
			{
				int idev = 0;
				LogIndenter li;
				for(int i=0; i<ndev; i++)
				{
					try
					{
						if(FTDIJtagInterface::IsJtagCapable(i))
						{
							LogNotice("Interface %d: %s\n", idev, FTDIJtagInterface::GetDescription(i).c_str());
							LogIndenter li;
							LogNotice("Serial number:  %s\n", FTDIJtagInterface::GetSerialNumber(i).c_str());
							LogNotice("User ID:        %s\n", FTDIJtagInterface::GetSerialNumber(i).c_str());
							LogNotice("Default clock:  %.2f MHz\n", FTDIJtagInterface::GetDefaultFrequency(i)/1000000.0f);
							idev++;
						}
					}
					catch(const JtagException& e)
					{
						LogNotice("Interface %d: Error getting device information\n", i);
					}
				}
			}
		#else	//#ifdef HAVE_FTD2XX
			LogNotice("FTDI API version: not supported\n");
		#endif
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		exit(1);
	}
}
