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
	@brief Flying Crowbar manual bitstream generation test
	
	Creates a bitstream in memory without using any Xilinx tools, writes it to the device, and verifies proper functionality.
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxCPLDBitstream.h"
#include "../../src/jtaghal/CPLDSerializer.h"
#include "../../src/jtaghal/CPLDBitstreamWriter.h"
#include "../../src/jtagboards/jtagboards.h"
#include "../../src/crowbar/crowbar.h"
#include "../../src/crowbar/FCCoolRunnerIIDevice.h"
#include "../../src/crowbar/FCCoolRunnerIINetlist.h"

using namespace std;

FCCoolRunnerIINetlist* GenerateNetlist(FCCoolRunnerIIDevice& device);
 
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
		CR2DevBoard board(&iface);
		board.InitializeBoard(true);
		
		//Sanity check that the interface is GPIO capable
		printf("Initializing GPIO interface...\n");
		if(!iface.IsGPIOCapable())
		{
			throw JtagExceptionWrapper(
				"JTAG interface should be GPIO capable, but isn't",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		printf("    Interface is GPIO capable (%d GPIO pins)\n", iface.GetGpioCount());
		
		//Get a few pointers
		//No need to validate at this point, InitializeBoard() made sure everything is OK
		CPLD* pcpld = dynamic_cast<CPLD*>(board.GetDefaultDevice());
		
		//Create the device
		printf("Initializing device...\n");
		string devname = "xc2c32a-6-vqg44";
		FCCoolRunnerIIDevice device(devname);
		
		//Generate the netlist programmatically
		printf("Generating netlist...\n");
		FCCoolRunnerIINetlist* netlist = GenerateNetlist(device);
		
		//Fit the netlist
		double start = GetTime();
		device.Fit(netlist);
		double dt = GetTime() - start;
		printf("Fitting complete (in %.2f ms)\n", dt*1000);
		
		//Make a bitstream from the device
		printf("Generating bitstream...\n");
		start = GetTime();
		XilinxCPLDBitstream bitstream;
		CPLDBitstreamWriter writer(&bitstream, board.GetDefaultDevice()->GetIDCode(), devname);
		device.SaveToBitstream(&writer);
		dt = GetTime() - start;
		printf("Bitstream generation complete (in %.2f ms)\n", dt*1000);
		
		//Configure the device
		printf("Configuring device...\n");
		pcpld->Program(&bitstream);
		
		//Verify that it's configured
		if(!pcpld->IsProgrammed())
		{
			throw JtagExceptionWrapper(
				"CPLD should be configured but isn't",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		/*
			Set up pin configuration
			
			gpio[0] = output
			gpio[1] = input
			
			The CPLD should function as a simple inverter.
		 */
		iface.SetGpioDirectionDeferred(0, true);
		iface.SetGpioDirectionDeferred(1, false);
		
		for(int i=0; i<10; i++)
		{
			printf("    Testing dout=0\n");
			iface.SetGpioValue(0, false);
			if(!iface.GetGpioValue(1))
			{
				throw JtagExceptionWrapper(
					"    Expected din=1, got 0\n",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
			usleep(100 * 1000);
			
			printf("    Testing dout=1\n");
			iface.SetGpioValue(0, true);
			if(iface.GetGpioValue(1))
			{
				throw JtagExceptionWrapper(
					"    Expected din=0, got 1\n",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
			usleep(100 * 1000);
		}
		printf("OK\n");
		
		//DEBUG: Dump the resulting netlist somewhere
		//printf("\n\n\n");
		//device.Dump();
		//device.DumpRTL();
		
		//Clean up
		delete netlist;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}

/**
	@brief Generates a netlist as follows:
	
	input wire din;
	output wire dout;
	output wire led1;
	output wire led2;
	
	assign dout = ~din;
	assign led1 = din;
	assign led2 = ~din;
 */
FCCoolRunnerIINetlist* GenerateNetlist(FCCoolRunnerIIDevice& device)
{
	//Get the IOBs
	FCCoolRunnerIIIOB* iob_gpiol0 = static_cast<FCCoolRunnerIIIOB*>(device.GetIOBForPin("P8"));
	FCCoolRunnerIIIOB* iob_gpiol1 = static_cast<FCCoolRunnerIIIOB*>(device.GetIOBForPin("P6"));
	FCCoolRunnerIIIOB* iob_led1 = static_cast<FCCoolRunnerIIIOB*>(device.GetIOBForPin("P38"));
	FCCoolRunnerIIIOB* iob_led2 = static_cast<FCCoolRunnerIIIOB*>(device.GetIOBForPin("P37"));
	printf("IOB assignment\n");
	printf("    IOB for FTDI_GPIOL0 is at %s\n", iob_gpiol0->GetNamePrefix().c_str());
	printf("    IOB for FTDI_GPIOL1 is at %s\n", iob_gpiol1->GetNamePrefix().c_str());
	printf("    IOB for LED1 is at %s\n", iob_led1->GetNamePrefix().c_str());
	printf("    IOB for LED2 is at %s\n", iob_led2->GetNamePrefix().c_str());
	
	//GPIOL0: LVCMOS33 input
	iob_gpiol0->m_iostandard = FCCoolRunnerIIIOB::LVCMOS33;
	iob_gpiol0->SetInZ(FCCoolRunnerIIIOB::INZ_INPUT);
	iob_gpiol0->SetOE(FCCoolRunnerIIIOB::OE_FLOAT);
	iob_gpiol0->SetTerminationMode(FCCoolRunnerIIIOB::TERM_FLOAT);
	iob_gpiol0->m_bSchmittTriggerEnabled = false;
	
	//GPIOL1: unregistered LVCMOS33 output
	iob_gpiol1->m_iostandard = FCCoolRunnerIIIOB::LVCMOS33;
	iob_gpiol1->SetInZ(FCCoolRunnerIIIOB::INZ_FLOAT);
	iob_gpiol1->SetOE(FCCoolRunnerIIIOB::OE_OUTPUT);
	iob_gpiol1->m_outmode = FCCoolRunnerIIIOB::OUTPUT_DIRECT;
	iob_gpiol1->SetTerminationMode(FCCoolRunnerIIIOB::TERM_FLOAT);
	iob_gpiol1->SetSlewRate(FCCoolRunnerIIIOB::SLEW_FAST);
	iob_gpiol1->m_bSchmittTriggerEnabled = false;
	
	//LED1: unregistered LVCMOS33 output
	iob_led1->m_iostandard = FCCoolRunnerIIIOB::LVCMOS33;
	iob_led1->SetInZ(FCCoolRunnerIIIOB::INZ_FLOAT);
	iob_led1->SetOE(FCCoolRunnerIIIOB::OE_OUTPUT);
	iob_led1->m_outmode = FCCoolRunnerIIIOB::OUTPUT_DIRECT;
	iob_led1->SetTerminationMode(FCCoolRunnerIIIOB::TERM_FLOAT);
	iob_led1->SetSlewRate(FCCoolRunnerIIIOB::SLEW_SLOW);
	iob_led1->m_bSchmittTriggerEnabled = false;
	
	//LED2: unregistered LVCMOS33 output
	iob_led2->m_iostandard = FCCoolRunnerIIIOB::LVCMOS33;
	iob_led2->SetInZ(FCCoolRunnerIIIOB::INZ_FLOAT);
	iob_led2->SetOE(FCCoolRunnerIIIOB::OE_OUTPUT);
	iob_led2->m_outmode = FCCoolRunnerIIIOB::OUTPUT_DIRECT;
	iob_led2->SetTerminationMode(FCCoolRunnerIIIOB::TERM_FLOAT);
	iob_led2->SetSlewRate(FCCoolRunnerIIIOB::SLEW_SLOW);
	iob_led2->m_bSchmittTriggerEnabled = false;
	
	//Create the netlist
	FCCoolRunnerIINetlist* netlist = new FCCoolRunnerIINetlist(&device);
	
	//Product terms
	FCCoolRunnerIIProductTerm* pterm_din = netlist->CreateProductTerm();
	FCCoolRunnerIIProductTerm* pterm_din_n = netlist->CreateProductTerm();
	pterm_din->AddInput(iob_gpiol0, false);
	pterm_din_n->AddInput(iob_gpiol0, true);
	
	//OR terms
	FCCoolRunnerIIOrTerm* orterm_dout = netlist->CreateOrTerm();
	FCCoolRunnerIIOrTerm* orterm_led1 = netlist->CreateOrTerm();
	FCCoolRunnerIIOrTerm* orterm_led2 = netlist->CreateOrTerm();
	orterm_dout->m_pterms.push_back(pterm_din_n);
	orterm_led1->m_pterms.push_back(pterm_din);
	orterm_led2->m_pterms.push_back(pterm_din_n);
	
	//Macrocells
	FCCoolRunnerIINetlistMacrocell* mcell_dout = netlist->CreateMacrocell(orterm_dout, iob_gpiol1);
	FCCoolRunnerIINetlistMacrocell* mcell_led0 = netlist->CreateMacrocell(orterm_led1, iob_led1);
	FCCoolRunnerIINetlistMacrocell* mcell_led1 = netlist->CreateMacrocell(orterm_led2, iob_led2);
	
	//Macrocell configuration - XOR passthrough, ignore the flipflop
	mcell_dout->m_xorin = FCCoolRunnerIIMacrocell::XORIN_ZERO;
	mcell_led0->m_xorin = FCCoolRunnerIIMacrocell::XORIN_ZERO;
	mcell_led1->m_xorin = FCCoolRunnerIIMacrocell::XORIN_ZERO;
	
	//Done
	return netlist;
}
