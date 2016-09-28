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
	@brief IPv6OffloadEngine test
	
	Performs various test operations on the JTAG server
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"

#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>

#include <signal.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netdb.h>

using namespace std;

int main(int /*argc*/, char* /*argv*/[])
{
	int err_code = 0;
	try
	{
		//Ignore the JTAG arguments for the node
		
		//Look up our hostname
		char* nodename = getenv("SLURM_NODELIST");
		string dns = string(nodename) + ".sandbox.bainbridge.antikernel.net";
		
		//Wait ten seconds for the board to respond to ping
		printf("Waiting for board to be pingable...\n");
		for(int i=0; i<10; i++)
		{
			char cmd[128];
			snprintf(cmd, sizeof(cmd), "ping6 -c 4 %s > /dev/null", dns.c_str());
			if(system(cmd) == 0)
				break;
		
			if(i == 9)
			{
				throw JtagExceptionWrapper(
					"Board did not respond to ping (waited 10 seconds)",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
			
			usleep(1000 * 1000);
		}
		
		//Wait 5 more seconds for SLAAC to complete (TODO: fix this?)
		usleep(5000 * 1000);
		
		const int port = 50100;			//port is hard coded in the test prorgam
		
		//Board is pingable, try to connect to it
		NetworkedJtagInterface iface;
		printf("Trying to connect...\n");
		iface.Connect(dns, port);
				
		//Get info about it
		printf("Connected to JTAG daemon at %s:%d\n", dns.c_str(), port);
		
		printf("Querying adapter...\n");
		printf("    Remote JTAG adapter is a %s (serial number \"%s\", userid \"%s\", frequency %.2f MHz)\n",
			iface.GetName().c_str(),
			iface.GetSerial().c_str(),
			iface.GetUserID().c_str(),
			iface.GetFrequency()/1E6
			);	
		
		//Try to initialize the scan chain and find what we have
		printf("Initializing chain...\n");
		double start = GetTime();
		iface.InitializeChain();
		double dt = GetTime() - start;
		printf("Scan chain contains %d devices (walked in %.3f ms)\n", (int)iface.GetDeviceCount(), dt*1000);
		for(size_t i=0; i<iface.GetDeviceCount(); i++)
		{
			auto dev = iface.GetDevice(i);
			if(dev != NULL)
				dev->PrintInfo();
		}

		//Verify there's 1 device, an xc2c32a
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
		
		//Program the device
		printf("Loading bitstream...\n");
		std::string fname = "../../xilinx-cpld-cr2-xc2c32a-6-vq44/MinimalCR2Bitstream.jed";
		FirmwareImage* bit = static_cast<ProgrammableDevice*>(pcpld)->LoadFirmwareImage(fname, false);
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
