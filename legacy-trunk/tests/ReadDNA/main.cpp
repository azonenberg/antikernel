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
	@brief Tests reading Device DNA from a Spartan-6 device
 */
#include <string>
#include <memory.h>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"

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
		
		printf("    Device serial number is ");
		unsigned char* serial = new unsigned char[len];
		memset(serial, 0, len);
		pfpga->GetSerialNumber(serial);
		for(int j=0; j<bitlen; j++)
			printf("%d", PeekBit(serial, j));
		printf(" = 0x");
		for(int j=0; j<len; j++)
			printf("%02x", 0xff & serial[j]);
		printf("\n");
		
		//Sanity check serial number begins in 10 as per UG380
		if( (PeekBit(serial, 1) != 0) || (PeekBit(serial, 0) != 1))
		{
			throw JtagExceptionWrapper(
				"Serial number should begin with 10",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Clean up
		delete[] serial;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}
