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
	@brief NOCSysinfo test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/UART.h"
#include "../../src/jtagboards/jtagboards.h"

#include <NOCSysinfo_constants.h>
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

#include <signal.h>

using namespace std;

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
		NetworkedJtagInterface iface;
		iface.Connect(server, port);
		
		//Initialize the board
		LX9MiniBoard board(&iface);
		board.InitializeBoard(true);
		
		//Get a few pointers
		//No need to validate at this point, InitializeBoard() made sure everything is OK
		FPGA* pfpga = dynamic_cast<FPGA*>(board.GetDefaultDevice());
		pfpga->Erase();
		sleep(2);

		//Verify there is a serial number
		if(!pfpga->HasSerialNumber())
		{
			throw JtagExceptionWrapper(
				"Device should have a unique serial number, but none reported",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		int len = pfpga->GetSerialNumberLength();
		int bitlen = pfpga->GetSerialNumberLengthBits();
		printf("    Device has unique serial number (%d bits long)\n", bitlen);
		if( (len != 8) || (bitlen != 57))
		{
			throw JtagExceptionWrapper(
				"Expected 57 bit serial number",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		printf("Reading serial number via JTAG...\n");
		unsigned char* serial = new unsigned char[len];
		memset(serial, 0, len);
		pfpga->GetSerialNumber(serial);
		
		//Load the bitstream
		printf("Loading bitstream...\n");
		FirmwareImage* bit = pfpga->LoadFirmwareImage("../../xilinx-fpga-spartan6-xc6slx9-2tqg144/JtagPingTestBitstream.bit");
		
		//Load it onto the FPGA
		printf("Configuring FPGA...\n");
		pfpga->Program(bit);
		printf("Configuration successful\n");
				
		//Probe the FPGA and see if it has any virtual TAPs on board
		pfpga->ProbeVirtualTAPs();
		if(!pfpga->HasRPCInterface())
		{
			throw JtagExceptionWrapper(
				"No RPC interface found, no NoC connection possible",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		RPCAndDMANetworkInterface* pif = dynamic_cast<RPCAndDMANetworkInterface*>(pfpga->GetRPCNetworkInterface());
		
		//Address lookup
		printf("Looking up address of system info node...\n");
		NameServer nameserver(pif);
		uint16_t saddr = nameserver.ForwardLookup("sysinfo");
		printf("   Sysinfo is at %04x\n", saddr);
		
		//Ask the sysinfo node for the device DNA
		printf("Testing device serial numbers\n");
		printf("    Reading serial number via sysinfo server...\n");
		RPCMessage rmsg;
		pif->RPCFunctionCall(saddr, SYSINFO_CHIP_SERIAL, 0, 0, 0, rmsg);
				
		//Print out the serial number
		printf("    JTAG serial number:    ");
		for(int j=0; j<bitlen; j++)
			printf("%d", PeekBit(serial, j));
		uint64_t jtag_serial = 0;
		for(int j=0; j<len; j++)
			jtag_serial = (jtag_serial << 8) | (0xff & serial[j]);
		printf(" = 0x%016lx\n", jtag_serial);
		delete[] serial;
		serial = NULL;
		
		//Print out the other serial number
		printf("    Sysinfo serial number: ");
		uint32_t sysnum[2] = {rmsg.data[2], rmsg.data[1] };
		unsigned char* pdat = (unsigned char*)(&sysnum[0]);
		MirrorBitArray(pdat, bitlen);
		for(int j=0; j<bitlen; j++)
			printf("%d", PeekBit(pdat, j));
		uint64_t sysinfo_serial = 0;
		for(int j=0; j<len; j++)
			sysinfo_serial = (sysinfo_serial << 8) | (0xff & pdat[j]);
		printf(" = 0x%016lx\n", sysinfo_serial);
		
		//Sanity check that they match
		if(jtag_serial != sysinfo_serial)
		{
			throw JtagExceptionWrapper(
				"Serial numbers do not match",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		printf("    OK\n");
		
		//Get device clock frequency
		printf("Looking up system clock frequency...\n");
		pif->RPCFunctionCall(saddr, SYSINFO_QUERY_FREQ, 0, 0, 0, rmsg);
				
		//Validate it
		uint32_t sysclk_period = rmsg.data[1];
		float mhz = 1000000.0f / sysclk_period;
		printf("    System clock period is %d ps (%.2f MHz)\n", sysclk_period, mhz);
		if( (mhz >= 10) && (mhz <= 500) )
		{
			//relatively sane frequency, assume it's OK
		}
		
		//Totally whacko, throw error
		else
		{
			throw JtagExceptionWrapper(
				"Invalid clock frequency",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}

		int baud_values[]=
		{
			115200,
			57600,
			38400,
			19200,
			9600,
			4800,
			2400,
			1800,
			1200,
			600,
			300,
			233,
			232,
			231,
			230,
			200,
			150,
			134,
			110,
			75,
			50
		};

		for(size_t i=0; i<sizeof(baud_values)/sizeof(baud_values[0]); i++)
		{
			//Calculate the number of cycles for the baud rate and sanity check it
			int requested_baud = baud_values[i];
			printf("Requesting cycles for %d baud...\n", requested_baud);
			pif->RPCFunctionCall(saddr, SYSINFO_GET_CYCFREQ, 0, requested_baud, 0, rmsg);
			
			//Sanity check
			float baud_calculated = (mhz * 1E6f) / rmsg.data[1];
			float baud_error_percent = (fabs(requested_baud - baud_calculated) / requested_baud) * 100;
			printf("    %d cycles (calculated %.2f baud, %.2f %% error)\n", rmsg.data[1], baud_calculated, baud_error_percent);
			
			if(baud_error_percent > 1)
			{
				throw JtagExceptionWrapper(
					"Baud rate error is too large",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
		}
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
