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
	@brief Test of the JTAG master
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"

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
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Register us with the name server
		NameServer nsvr(&iface, "ThisIsALongAndComplicatedPassword");
		nsvr.Register("testcase");
		
		//Create the tunneled JTAG adapter
		printf("Connecting to JTAG adapter...\n");
		NocJtagInterface jface(iface, "jtag");
		
		//Run through the scan chain
		printf("Initializing scan chain...\n");
		jface.InitializeChain();
		for(size_t i=0; i<jface.GetDeviceCount(); i++)
			jface.GetDevice(i)->PrintInfo();
			
		//We should have one device, and it should be an XC2C32A
		if(jface.GetDeviceCount() != 1)
		{
			throw JtagExceptionWrapper(
				"Expected one device in scan chain",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		XilinxCoolRunnerIIDevice* pcpld = dynamic_cast<XilinxCoolRunnerIIDevice*>(jface.GetDevice(0));
		if(pcpld == NULL)
		{
			throw JtagExceptionWrapper(
				"Expected a CoolRunner-II device",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Try erasing the CPLD
		printf("Erasing CPLD...\n");
		fflush(stdout);
		pcpld->Erase();
		
		//Try programming it
		std::string fname = "../../xilinx-cpld-cr2-xc2c32a-6-vq44/MinimalCR2Bitstream.jed";
		FirmwareImage* bit = static_cast<ProgrammableDevice*>(pcpld)->LoadFirmwareImage(fname, false);
		
		//Load it onto the device
		printf("Configuring CPLD...\n");
		pcpld->Program(bit);
		
		//Verify that it's configured
		if(!pcpld->IsProgrammed())
		{
			throw JtagExceptionWrapper(
				"CPLD should be configured but isn't",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Clean up, normal termination
		delete bit;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
