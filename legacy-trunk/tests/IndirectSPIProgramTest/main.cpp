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
	@brief Indirect SPI flash programming test
	
	Connect to the board and try programming it.
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"
#include "../../src/jtaghal/XilinxSpartan6Device.h"

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
		XilinxSpartan6Device* pfpga = dynamic_cast<XilinxSpartan6Device*>(board.GetDefaultDevice());
		ProgrammableDevice* pdev = dynamic_cast<ProgrammableDevice*>(board.GetDefaultDevice());
		
		//Load the firmware image and program the device
		printf("Loading firmware image...\n");
		FirmwareImage* img = pdev->LoadFirmwareImage("../../xilinx-fpga-spartan6-xc6slx9-2tqg144/JtagPingTestBitstream.bit");
		printf("Programming device (using indirect quad SPI programming)...\n");
		ByteArrayFirmwareImage* bi = dynamic_cast<ByteArrayFirmwareImage*>(img);
		if(bi)
			pfpga->ProgramIndirect(bi, 4);
		else
		{
			throw JtagExceptionWrapper(
				"Cannot indirectly program non-byte-array firmware images",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		printf("Configuration complete\n");
		delete img;
		
		//Sanity check
		iface.ResetToIdle();
				
		//Verify that it's configured
		if(!pfpga->IsProgrammed())
		{
			throw JtagExceptionWrapper(
				"FPGA should be configured but isn't",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Need to do this at the end
		pfpga->ProbeVirtualTAPs();
		
		//FPGA is programmed, test it
		printf("Looking up address of RPC pinger\n");
		NameServer nameserver(pfpga);
		uint16_t pingaddr = nameserver.ForwardLookup("rpcping");
		printf("Pinger is at %04x\n", pingaddr);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}
