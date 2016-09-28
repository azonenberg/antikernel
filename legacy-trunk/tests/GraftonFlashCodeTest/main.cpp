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
	@brief GRAFTON execute-from-flash test
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxFPGA.h"
#include "../../src/jtaghal/RawBinaryFirmwareImage.h"
#include "../../src/jtagboards/jtagboards.h"

#include <RPCv2Router_type_constants.h>

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
		SwitchBoard board(&iface);
		board.InitializeBoard(true);
		
		//Get a few pointers
		//No need to validate at this point, InitializeBoard() made sure everything is OK
		XilinxFPGA* pfpga = dynamic_cast<XilinxFPGA*>(board.GetDefaultDevice());
		
		//Load the indirect programming image and write the firmware to flash at the correct offset
		printf("Writing firmware to flash...\n");
		RawBinaryFirmwareImage* img = new RawBinaryFirmwareImage(
			"../../mips-elf/GraftonFlashCodeTestFirmware",
			"grafton");
		pfpga->ProgramIndirect(img, 4, false, 0x000E0000);
		delete img;
		printf("    done\n");
			
		//Load the bitstream
		printf("Loading bitstream...\n");
		FirmwareImage* bit = pfpga->LoadFirmwareImage(
			"../../xilinx-fpga-spartan6-xc6slx25-2ftg256/GraftonFlashCodeTestBitstream.bit");
		printf("Configuring FPGA...\n");
		pfpga->Program(bit);
		delete bit;
		
		//Verify that it's configured
		if(!pfpga->IsProgrammed())
		{
			throw JtagExceptionWrapper(
				"FPGA should be configured but isn't",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		pfpga->ProbeVirtualTAPs();
		if(!pfpga->HasRPCInterface())
		{
			throw JtagExceptionWrapper(
				"No RPC network interface found",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		RPCAndDMANetworkInterface* pif = dynamic_cast<RPCAndDMANetworkInterface*>(pfpga);
		if(pif == NULL)
		{
			throw JtagExceptionWrapper(
				"Not an RPCAndDMANetworkInterface",
				"",
				JtagException::EXCEPTION_TYPE_FIRMWARE);
		}
		
		//Bitstream is loaded
		printf("Bitstream should be loaded now\n");
		
		//Wait 250ms for CPU to boot.
		//Messages sent too early may be lost since CPU doesn't have rx queue set up yet
		usleep(250*1000);
		
		//Address lookup
		printf("Looking up address of CPU\n");
		NameServer nameserver(pif);
		uint16_t caddr = nameserver.ForwardLookup("cpu");
		printf("CPU is at %04x\n", caddr);
		uint16_t taddr = 0xc000;
		printf("We are at %04x\n", taddr);
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Send a bunch of messages and make sure we get the same thing back
		printf("Sending ping packets...\n");
		double start = GetTime();
		int npack = 1000;
		double sumping = 0;
		double minping = 999999;
		double maxping = 0;
		for(int i=0; i<npack; i++)
		{	
			if( (i % 100) == 0)
				printf("Message %d\n", i);
					
			RPCMessage msg;
			msg.from = taddr;
			msg.to = caddr;
			msg.type = RPC_TYPE_INTERRUPT;
			msg.callnum = rand() & 0xff;
			msg.data[0] = rand() & 0x001fffff;
			msg.data[1] = rand();
			msg.data[2] = rand();
			double tsend = GetTime();
			pif->SendRPCMessage(msg);
			
			RPCMessage rxm;
			if(!pif->RecvRPCMessageBlockingWithTimeout(rxm, 5))
			{
				printf("Timeout on message %d - expected response within 5 sec but nothing arrived\n", i);
				printf("Sent:\n    %s\n\n", msg.Format().c_str());
				
				throw JtagExceptionWrapper(
					"Message timeout",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);					
			}
			
			double trcv = GetTime();
			double rtt = (trcv - tsend);
			sumping += rtt;
			if(minping > rtt)
				minping = rtt;
			if(maxping < rtt)
				maxping = rtt;			
			
			if( (rxm.from == caddr) &&
				(rxm.data[0] == msg.data[0]) &&
				(rxm.data[1] == msg.data[1]) &&
				(rxm.data[2] == msg.data[2])
			)
			{
				//printf("Message %d OK\n", i);
			}
			
			else
			{				
				printf("Message %d FAIL\n", i);
				printf("Sent:\n    %s\nReceived:\n    %s\n", msg.Format().c_str(), rxm.Format().c_str());
				throw JtagExceptionWrapper(
					"Invalid message came back",
					"",
					JtagException::EXCEPTION_TYPE_FIRMWARE);
			}
		}
		
		int packets_sent = npack * 2;
		int header_size = packets_sent * 32;
		int payload_size = packets_sent * 96;
		
		//Print statistics
		double end = GetTime();
		double dt = end - start;	
		printf("Done, all OK\n");
		printf("%d packets sent in %.2f ms (%.2f Kbps raw, %.2f Kbps after overhead)\n",
			packets_sent,
			dt * 1000,
			(payload_size + header_size) / (1000 * dt),
			(payload_size) / (1000 * dt));
		printf("RTT latency: %.2f ms min / %.2f ms avg / %.2f max\n",
			minping * 1000,
			(sumping / npack) * 1000,
			maxping * 1000);
		
		return 0;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}
