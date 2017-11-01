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
	@brief SPI flash test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../../src/jtaghal/jtaghal.h"
#include "../../../src/xptools/UART.h"

using namespace std;

uint32_t GetCapacityMbits(UART& uart);
bool ReadData(UART& uart, uint32_t address, unsigned char* data, size_t len);
bool BulkErase(UART& uart);
bool SectorErase(UART& uart, uint32_t address);
bool Program(UART& uart, uint32_t address, unsigned char* data, size_t len);

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		Severity console_verbosity = Severity::NOTICE;
		string server;
		int port = 0;
		string tty;

		string mode;
		string file;

		//Parse command-line arguments
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);

			//Let the logger eat its args first
			if(ParseLoggerArguments(i, argc, argv, console_verbosity))
				continue;

			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				tty = argv[++i];
			else if(s == "--mode")
				mode = argv[++i];
			else if(s == "--file")
				file = argv[++i];
			else
			{
				printf("Unrecognized command-line argument \"%s\", expected --server or --port\n", s.c_str());
				return 1;
			}
		}

		//Set up logging
		g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

		//Connect to the server
		if( (server == "") || (port == 0) )
		{
			LogError("No server or port name specified\n");
			return 1;
		}

		//Connect to the server
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		LogDebug("Connected to JTAG daemon at %s:%d\n", server.c_str(), port);
		LogDebug("Querying adapter...\n");
		LogDebug("    Remote JTAG adapter is a %s (serial number \"%s\", userid \"%s\", frequency %.2f MHz)\n",
			iface.GetName().c_str(), iface.GetSerial().c_str(), iface.GetUserID().c_str(), iface.GetFrequency()/1E6);

		//Initialize the chain
		LogDebug("Initializing chain...\n");
		iface.InitializeChain();

		//Get device count and see what we've found
		LogDebug("Scan chain contains %d devices\n", (int)iface.GetDeviceCount());

		//Connect to the UART
		UART uart(tty, 115200);

		//Ask how big it is
		uint32_t capacity_mbits = GetCapacityMbits(uart);
		LogDebug("Memory has a capacity of %d Mb (%.2f MB)\n", capacity_mbits, capacity_mbits / 8.0f);

		//If reading, dump it to /tmp
		double start = GetTime();
		unsigned int kb_per_block = 32;
		unsigned int blocksize = 1024 * kb_per_block;
		if(mode == "read")
		{
			LogDebug("Reading...\n");

			uint32_t max_addr = capacity_mbits * 1024 * 1024 / 8;	//Kb Mb MB

			FILE* fp = fopen(file.c_str(), "wb");
			if(!fp)
			{
				LogError("fail to open\n");
				return 1;
			}

			unsigned char rxbuf[1024];
			for(uint32_t addr = 0; addr < max_addr; addr += 1024)
			{
				if(addr && ( (addr % blocksize) == 0) )
				{
					double now = GetTime();
					double dt = now - start;
					start = now;
					LogDebug("0x%08x / %08x (%.3f KB/s)\n", addr, max_addr, kb_per_block / dt);
				}

				if(!ReadData(uart, addr, rxbuf, 1024))
				{
					LogError("fail to read\n");
					return 1;
				}

				fwrite(rxbuf, 1, 1024, fp);
			}

			fclose(fp);
		}

		//Sector erase (first sector for now
		else if(mode == "erase")
		{
			LogDebug("Sector erase\n");
			if(!SectorErase(uart, 0x00000000))
				LogError("erase fail\n");
			LogDebug("Done\n");
		}

		//Full-chip erase
		else if(mode == "wipe")
		{
			LogDebug("Bulk erase...\n");
			if(!BulkErase(uart))
				LogError("erase fail\n");
			LogDebug("Done\n");
		}

		//Program
		else if(mode == "program")
		{
			FILE* fp = fopen(file.c_str(), "rb");
			const unsigned int txbufsize = 256;
			unsigned char txbuf[txbufsize];
			for(uint32_t address=0; ; address += txbufsize)
			{
				size_t len = fread(txbuf, 1, txbufsize, fp);
				if(len == 0)
					break;

				if(address && ( (address % blocksize) == 0) )
				{
					double now = GetTime();
					double dt = now - start;
					start = now;
					LogDebug("0x%08x (%.3f KB/s)\n", address, kb_per_block / dt);
				}

				if(!Program(uart, address, txbuf, len))
				{
					LogError("fail to program\n");
					return 1;
				}

				if(len < txbufsize)
					break;
			}
		}
	}

	catch(const JtagException& ex)
	{
		LogError("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

bool SectorErase(UART& uart, uint32_t address)
{
	//Send the read command
	unsigned char cmd[7] =
	{
		'e',

		static_cast<unsigned char>((address >> 24) & 0xff),
		static_cast<unsigned char>((address >> 16) & 0xff),
		static_cast<unsigned char>((address >> 8 ) & 0xff),
		static_cast<unsigned char>((address >> 0 ) & 0xff),

		0,	//TODO handle length
		0
	};
	if(!uart.Write(cmd, sizeof(cmd)))
		return false;

	unsigned char rxbuf;
	uart.Read(&rxbuf, 1);
	return (rxbuf == 1);
}

bool BulkErase(UART& uart)
{
	unsigned char cmd = 'b';
	uart.Write(&cmd, sizeof(cmd));

	unsigned char rxbuf;
	uart.Read(&rxbuf, 1);
	return (rxbuf == 1);
}

bool ReadData(UART& uart, uint32_t address, unsigned char* data, size_t len)
{
	if(len > 65535)
	{
		LogError("len too big\n");
		return false;
	}

	//Send the read command
	unsigned char cmd[7] =
	{
		'r',

		static_cast<unsigned char>((address >> 24) & 0xff),
		static_cast<unsigned char>((address >> 16) & 0xff),
		static_cast<unsigned char>((address >> 8 ) & 0xff),
		static_cast<unsigned char>((address >> 0 ) & 0xff),

		static_cast<unsigned char>((len >> 8) & 0xff),
		static_cast<unsigned char>((len >> 0) & 0xff)
	};
	if(!uart.Write(cmd, sizeof(cmd)))
		return false;

	//Read the data
	return uart.Read(data, len);
}

bool Program(UART& uart, uint32_t address, unsigned char* data, size_t len)
{
	if(len > 65535)
	{
		LogError("len too big\n");
		return false;
	}

	//Send the write command
	unsigned char cmd[7] =
	{
		'p',

		static_cast<unsigned char>((address >> 24) & 0xff),
		static_cast<unsigned char>((address >> 16) & 0xff),
		static_cast<unsigned char>((address >> 8 ) & 0xff),
		static_cast<unsigned char>((address >> 0 ) & 0xff),

		static_cast<unsigned char>((len >> 8) & 0xff),
		static_cast<unsigned char>((len >> 0) & 0xff)
	};
	if(!uart.Write(cmd, sizeof(cmd)))
		return false;

	//Send the data
	if(!uart.Write(data, len))
		return false;

	//Get status
	unsigned char rxbuf;
	uart.Read(&rxbuf, 1);
	return (rxbuf == 1);
}

uint32_t GetCapacityMbits(UART& uart)
{
	unsigned char sizeq = 's';
	unsigned char rxbuf[2];
	uart.Write(&sizeq, sizeof(sizeq));
	uart.Read(rxbuf, 2);
	return (rxbuf[0] << 8) | rxbuf[1];
}
