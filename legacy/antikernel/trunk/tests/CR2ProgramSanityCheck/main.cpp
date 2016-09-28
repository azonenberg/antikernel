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
	@brief CR-II programming check.
	
	Connect to the board and try programming it.
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"

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
		
		//Initialize the scan chain
		iface.InitializeChain();
		int ndev = iface.GetDeviceCount();
		if(ndev != 1)
		{
			throw JtagExceptionWrapper(
				"Invalid scan chain (expected 1 device)",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		JtagDevice* pdev = iface.GetDevice(0);
		if(pdev == NULL)
		{
			throw JtagExceptionWrapper(
				"Invalid scan chain (expected a valid device)",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		XilinxCoolRunnerIIDevice* pcpld = dynamic_cast<XilinxCoolRunnerIIDevice*>(pdev);
		if(pcpld == NULL)
		{
			throw JtagExceptionWrapper(
				"Invalid scan chain (expected a CoolRunner-II device)",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Load the bitstream
		printf("Loading bitstream...\n");
		unsigned int density = pcpld->GetDensity();
		std::string fname = "../../xilinx-cpld-cr2-";
		switch(density)
		{
			case XilinxCoolRunnerIIDevice::XC2C32A:
				fname += "xc2c32a-6-vq44/MinimalCR2Bitstream.jed";
				break;
			
			case XilinxCoolRunnerIIDevice::XC2C64A:
				fname += "xc2c64a-7-vq44/MinimalCR2Bitstream_64a.jed";
				break;
				
			default:
				{
					throw JtagExceptionWrapper(
						"This test case does not support the selected device",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
		}
		FirmwareImage* bit = static_cast<ProgrammableDevice*>(pcpld)->LoadFirmwareImage(fname, false);
		
		//Load it onto the FPGA
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
	
	return err_code;
}
