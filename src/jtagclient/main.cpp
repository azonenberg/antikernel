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
	@brief Main source file for jtagclient

	\ingroup jtagclient
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>

#include "../jtaghal/jtaghal.h"
//#include <svnversion.h>

#include <signal.h>

using namespace std;

void ShowUsage();
void ShowVersion();
void PrintDeviceInfo(JtagDevice* pdev);

#ifndef _WIN32
void sig_handler(int sig);
#endif

/**
	\defgroup jtagclient JTAGclient: command-line client to jtagd

	jtagclient provides a command-line interface for performing basic scan chain operations.

	JTAGclient is released under the same permissive 3-clause BSD license as the remainder of the project.
 */

/**
	\page jtagclient_usage Usage
	\ingroup jtagclient

	General arguments:

	\li --port NNN<br/>
	Specifies the TCP port that jtagclient should connect to (default 50123).

	\li --server HOST<br/>
	Specifies the hostname of the server that jtagclient should connect to (default localhost)

	\li --nobanner<br/>
	Run the requested operation without printing the program version/license banner.

	Exactly one of the following operations must be specified:

	\li --help<br/>
	Displays help and exits.

	\li --version<br/>
	Prints program version number and exits.

	\li --erase N<br/>
	Erases the device at position N in the scan chain (zero based)

	\li --info N<br/>
	Displays information about the device at position N in the scan chain (zero based)

	\li --program N fname
	Programs the device at position N in the scan chain with the firmware/bitstream image in the supplied file.

	\li --verbose
	Prints more debug info.
 */

/**
	@brief Program entry point

	\ingroup jtagclient
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

		//Mode switches
		enum modes
		{
			MODE_NONE,
			MODE_HELP,
			MODE_VERSION,
			MODE_PROGRAM,
			MODE_DEVINFO,
			MODE_ERASE,
			MODE_REBOOT,
			MODE_DUMP
		} mode = MODE_NONE;

		//Device index
		int devnum = 0;

		//Programming mode
		string bitfile;

		bool noreboot = false;
		int indirect_width = 0;
		unsigned int base = 0;
		bool raw = false;
		bool profile_init_time = false;
		string indirect_image = "";

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

			if(s == "--help")
				mode = MODE_HELP;
			else if(s == "--port")
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
			else if(s == "--program")
			{
				//Expect device index and bitfile
				mode = MODE_PROGRAM;
				if(i+2 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --program\n");
					return 1;
				}
				devnum = atoi(argv[++i]);
				bitfile = argv[++i];
			}
			else if(s == "--dump")
			{
				if(i+2 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --dump\n");
					return 1;
				}

				//Expect device index and bitfile
				mode = MODE_DUMP;
				devnum = atoi(argv[++i]);
				bitfile = argv[++i];
			}
			else if(s == "--indirect")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --indirect\n");
					return 1;
				}

				indirect_width = atoi(argv[++i]);
			}
			else if(s == "--indirect_image")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --indirect-image\n");
					return 1;
				}

				indirect_image = argv[++i];
			}
			else if(s == "--profile-init")
				profile_init_time = true;
			else if(s == "--info")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --info\n");
					return 1;
				}

				//Expect device index
				mode = MODE_DEVINFO;
				devnum = atoi(argv[++i]);
			}
			else if(s == "--erase")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --erase\n");
					return 1;
				}

				//Expect device index
				mode = MODE_ERASE;
				devnum = atoi(argv[++i]);
			}
			else if(s == "--reboot")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --reboot\n");
					return 1;
				}

				//Expect device index
				mode = MODE_REBOOT;
				devnum = atoi(argv[++i]);
			}
			else if(s == "--noreboot")
				noreboot = true;
			else if(s == "--raw")
				raw = true;
			else if(s == "--base")
			{
				if(i+1 >= argc)
				{
					fprintf(stderr, "Not enough arguments for --base\n");
					return 1;
				}

				sscanf(argv[++i], "%8x", &base);
			}
			else if(s == "--version")
				mode = MODE_VERSION;
			else
			{
				fprintf(stderr, "Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
				return 1;
			}
		}

		//Set up logging
		g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

		//Print header
		if(console_verbosity >= Severity::NOTICE)
		{
			ShowVersion();
			printf("\n");
		}

		//Process help/version requests
		if(mode == MODE_VERSION)
			return 0;
		else if(mode == MODE_HELP)
		{
			ShowUsage();
			return 0;
		}

		//Abort cleanly if no server specified
		if( (port == 0) || (server.empty()) )
		{
			ShowUsage();
			return 0;
		}

		//Connect to the server
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		printf("Connected to JTAG daemon at %s:%d\n", server.c_str(), port);
		printf("Querying adapter...\n");
		printf("    Remote JTAG adapter is a %s (serial number \"%s\", userid \"%s\", frequency %.2f MHz)\n",
			iface.GetName().c_str(), iface.GetSerial().c_str(), iface.GetUserID().c_str(), iface.GetFrequency()/1E6);

		//Initialize the chain
		printf("Initializing chain...\n");
		double start = GetTime();
		iface.InitializeChain();
		if(profile_init_time)
		{
			double dt = GetTime() - start;
			printf("    Chain walking took %.3f ms\n", dt*1000);
		}

		//Get device count and see what we've found
		printf("Scan chain contains %d devices\n", (int)iface.GetDeviceCount());

		//Walk the chain and see what we find
		//No need for mutexing here since the device will lock the high-level interface when necessary
		if(mode != MODE_DEVINFO)
		{
			for(size_t i=0; i<iface.GetDeviceCount(); i++)
				PrintDeviceInfo(iface.GetDevice(i));
		}

		//Do stuff
		switch(mode)
		{
			case MODE_NONE:
				//nothing to do
				break;

			case MODE_PROGRAM:
				{
					/*
					if(bitfile == "")
					{
						throw JtagExceptionWrapper(
							"No filename specified, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Get the device
					JtagDevice* device = iface.GetDevice(devnum);
					if(device == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is null, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Make sure it's a programmable device
					ProgrammableDevice* pdev = dynamic_cast<ProgrammableDevice*>(device);
					if(pdev == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is not a programmable device, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Load the firmware image and program the device
					printf("Loading firmware image...\n");
					FirmwareImage* img = NULL;
					if(raw)
						img = new RawBinaryFirmwareImage(bitfile, "flash");
					else
						img = pdev->LoadFirmwareImage(bitfile, verbose);

					if(indirect_width == 0)
					{
						printf("Programming device...\n");
						pdev->Program(img);
					}
					else
					{
						printf("Programming device (using indirect programming, bus width %d)...\n", indirect_width);
						ByteArrayFirmwareImage* bi = dynamic_cast<ByteArrayFirmwareImage*>(img);
						if(bi)
							pdev->ProgramIndirect(bi, indirect_width, !noreboot, base, indirect_image);
						else
						{
							throw JtagExceptionWrapper(
								"Cannot indirectly program non-byte-array firmware images",
								"",
								JtagException::EXCEPTION_TYPE_GIGO);
						}
					}
					printf("Configuration successful\n");
					delete img;
					*/
				}
				break;

			case MODE_DUMP:
				{
					/*
					//Get the device
					JtagDevice* device = iface.GetDevice(devnum);
					if(device == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is null, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Make sure it's a Xilinx FPGA (TODO: move this to base class)
					XilinxFPGA* pdev = dynamic_cast<XilinxFPGA*>(device);
					if(pdev == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is not a Xilinx FPGA, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					printf("Dumping flash...\n");
					pdev->DumpIndirect(indirect_width, bitfile);
					*/
				}
				break;

			case MODE_DEVINFO:
				PrintDeviceInfo(iface.GetDevice(devnum));
				break;

			case MODE_ERASE:
				{
					/*
					//Get the device
					JtagDevice* device = iface.GetDevice(devnum);
					if(device == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is null, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Make sure it's a programmable device
					ProgrammableDevice* pdev = dynamic_cast<ProgrammableDevice*>(device);
					if(pdev == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is not a programmable device, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Erase it
					printf("Erasing...\n");
					pdev->Erase();
					*/
				}
				break;

			case MODE_REBOOT:
				{
					/*
					//Get the device
					JtagDevice* device = iface.GetDevice(devnum);
					if(device == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is null, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Make sure it's a Xilinx FPGA (TODO: move this to base class)
					XilinxFPGA* pdev = dynamic_cast<XilinxFPGA*>(device);
					if(pdev == NULL)
					{
						throw JtagExceptionWrapper(
							"Device is not rebootable, cannot continue",
							"",
							JtagException::EXCEPTION_TYPE_BOARD_FAULT);
					}

					//Erase it
					printf("Rebooting...\n");
					pdev->Reboot();
					*/
				}
				break;

			default:
				break;
		}
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	//Done
	return 0;
}

/**
	@brief Prints info about a single device in the chain

	@param i		Device index
	@param pdev		The device

	\ingroup jtagclient
 */
void PrintDeviceInfo(JtagDevice* pdev)
{
	if(pdev == NULL)
	{
		throw JtagExceptionWrapper(
			"Device is null, cannot continue",
			"");
	}

	pdev->PrintInfo();
}

/**
	@brief Prints program usage

	\ingroup jtagclient
 */
void ShowUsage()
{
	LogNotice(
		"Usage: jtagclient [general args] [mode]\n"
		"\n"
		"General arguments:\n"
		"    --help                                             Displays this message and exits.\n"
		"    --nobanner                                         Do not print version number on startup.\n"
		"    --port PORT                                        Specifies the port number to connect to (defaults to 50123)\n"
		"    --server [hostname]                                Specifies the hostname of the server to connect to (defaults to localhost).\n"
		"    --version                                          Prints program version number and exits.\n"
		"\n"
		"Mode flags\n"
		"    --erase [device index]                             Erases the device at the specified index (zero based).\n"
		"    --info [device index]                              Displays information about the device at the specified index (zero based).\n"
		"    --program [device index] [bitfile] [--indirect N]  Programs the device at the specified index (zero based) with the supplied bitfile.\n"
		"                                                       If --indirect is specified, use indirect flash programming with bus width N\n"
		"                                                       Indirect programming will reboot the device unless --noreboot is specified.\n"
		"                                                       To load the bitfile at an address other than zero specify --base [hex address]\n"
		);
}

#ifndef _WINDOWS
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

/**
	@brief Prints program version number

	\ingroup jtagclient
 */
void ShowVersion()
{
	LogNotice(
		"JTAG client [git rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, "TODO");
}
