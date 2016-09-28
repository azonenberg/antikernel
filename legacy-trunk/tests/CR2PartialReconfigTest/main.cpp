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
	@brief CR2 partial-reconfiguratoin test.
 */
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"
#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"

using namespace std;

void VerifyOutput(NetworkedJtagInterface& iface, int chan, bool expected);
 
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
		
		//Print out pin state
		for(int i=0; i<iface.GetGpioCount(); i++)
			printf("    Pin %2d: %6s (%d)\n", i, iface.GetGpioDirection(i) ? "output" : "input", iface.GetGpioValueCached(i));
		
		/*
			Set up pin configuration
			
			gpio[0] = gpio_en (output)
			gpio[1] = gpio_out (input)
			gpio[2] = gpio_din (output)
		 */
		iface.SetGpioDirectionDeferred(0, true);
		iface.SetGpioDirectionDeferred(1, false);
		iface.SetGpioDirectionDeferred(2, true);
		iface.SetGpioValue(0, false);
		iface.SetGpioValue(2, false);
		
		//Get a few pointers
		//No need to validate at this point, InitializeBoard() made sure everything is OK
		CPLD* pcpld = dynamic_cast<CPLD*>(board.GetDefaultDevice());
	
		//Load the bitstream and verify
		printf("Loading bitstream...\n");
		FirmwareImage* bit = pcpld->LoadFirmwareImage(
			"../../xilinx-cpld-cr2-xc2c32a-6-vq44/CR2PartialReconfigTestBitstream.jed");
		printf("Configuring CPLD...\n");
		pcpld->Program(bit);
		if(!pcpld->IsProgrammed())
		{
			throw JtagExceptionWrapper(
				"CPLD should be configured but isn't",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		delete bit;
		bit = NULL;
		
		//Wait 250ms to make sure chip is fully booted even after usb latency etc
		usleep(250 * 1000);
		
		//Make sure output is currently low
		printf("Verifying firmware functionality...\n");
		VerifyOutput(iface, 1, false);
		
		//Strobe the flag high and verify that the CPLD noticed
		iface.SetGpioValue(2, true);	//din=1
		iface.SetGpioValue(0, true);	//en=1
		usleep(10 * 1000);
		iface.SetGpioValue(0, false);	//en=0
		iface.SetGpioValue(2, false);	//din=0
		VerifyOutput(iface, 1, true);
		usleep(10 * 1000);
		
		//Flag is now low again and will stay that way. If the chip were to be reset, output on gpio1 should go low.
		
		//Enter ISC mode without resetting
		printf("Preparing to apply firmware patch...\n");
		XilinxCoolRunnerIIDevice* pcr = dynamic_cast<XilinxCoolRunnerIIDevice*>(pcpld);
		pcr->SetIR(XilinxCoolRunnerIIDevice::INST_ISC_ENABLE);
		//pcr->SetIR(XilinxCoolRunnerIIDevice::INST_ISC_ENABLEOTF);
		usleep(800);		//wait for device to initialize
		
		//Set up some constants and allocate buffers
		const int shw = 260;
		const int nbits = shw + 12;
		const int nbytes = ceil(nbits / 8.0f);
		const int npad = 6;
		const int nshort = nbits - npad;
		bool* scratch = new bool[nbits];
		unsigned char* scratch_bytes = new unsigned char[nbytes];
		unsigned char* read_bytes = new unsigned char[nbytes];
		
		//The generated bitstream puts the AND cell of interest in row 3 of the FB2 PLA AND array. This should be
		//bitstream row 0x3 (binary) or 0x2 (gray code).
		const int baddr = 0x3;
		 
		//Prepare to read back the existing line of config so we can patch without
		//messing with ZIA or macrocell configuration.
		printf("    Reading existing bits in row 0x%x...\n", baddr);
			
		//Make readback command buffer
		for(int x=0; x<nbits; x++)
			scratch[x] = false;
		int addr = pcr->GrayEncode(baddr);
		for(int i=0; i<11; i++)
		{
			if( (i + 12 - npad) >= 12)
				break;
			scratch[i+(12 - npad)] = (addr & 1);
			addr >>= 1;
		}
		for(int x=0; x<nbits; x+=8)
		{
			int temp = 0;
			for(int i=0; i<8; i++)
				temp = (temp << 1) + scratch[i+x];
			scratch_bytes[x/8] = temp;
		}
		
		//Flip and send, then send anything (doesn't matter what) to flush the pipeline.
		//To simplify the code, we just send the same read again.
		FlipByteArray(scratch_bytes, nbytes);
		pcr->SetIR(XilinxCoolRunnerIIDevice::INST_ISC_SRAM_READ);
		pcr->ScanDR(scratch_bytes, read_bytes, nshort);
		pcr->ScanDR(scratch_bytes, read_bytes, nshort);
		FlipByteArray(read_bytes, nbytes);

		/*
			Create the actual config bitstream patch.
			
			Target flipflop is pin 6 in VQG44 which is FB2 macrocell 11, configured as a DFFCE:
				D = fb2_pterm[0] = fb2_10_ibuf = pin5 = gpio_din
				CE = fb2_ptc[10] = fb2_pterm[3*10 + 10] = fb2_pterm[40] = fb2_12_ibuf = pin8 = gpio_en
			
			We want to patch D to be ~gpio_din instead.
			
			The ISC register is structured as follows (leftmost bit is the rightmost on die)
				* 6 bits of padding
				* 6 bits of address
				* 1 transfer bit
				* 9 bits of FB1 macrocell data
				* 112 bits of FB1 PLA data
				* 16 bits of interleaved ZIA data
				* 112 bits of FB2 PLA data
				* 9 bits of FB2 macrocell data
				* 1 transfer bit
				= 272 bits / 34 bytes total
				
			The config bits of interest are for cell AND_FB1_X1Y4 which are the rightmost two bits of the FB2 PLA row.
			This comes out to bits 0x8 and 0x4 in byte 32 of the row. We can flip them by XORing with 0xC.
		 */

		//Copy readback data to write data
		memcpy(scratch_bytes, read_bytes, nbytes);
		
		//Set transfer bits to zero
		scratch_bytes[1] &= ~0x08;
		scratch_bytes[33] &= ~0x1;
		
		//Apply the actual patch.. just two bits ;)
		scratch_bytes[32] ^= 0xC;
		
		/*
		printf("patched\n");
		for(int i=0; i<nbytes; i++)
			printf("%02x ", scratch_bytes[i] & 0xff);
		printf("\n");
		*/
		
		//Write the patched data
		FlipByteArray(scratch_bytes, nbytes);
		pcr->SetIR(XilinxCoolRunnerIIDevice::INST_ISC_SRAM_WRITE);
		pcr->ScanDR(scratch_bytes, read_bytes, nshort);
		usleep(800);
		
		//Clean up
		delete[] read_bytes;
		delete[] scratch_bytes;
		delete[] scratch;
		
		//Done with config stuff
		pcr->SetIR(XilinxCoolRunnerIIDevice::INST_ISC_DISABLE);
		pcr->SetIR(XilinxCoolRunnerIIDevice::INST_BYPASS);
		usleep(800);
		
		//Wait 250ms to make sure chip is fully booted even after usb latency etc
		usleep(250 * 1000);
		
		//Verify output is still high
		printf("Verifying device was not reset...\n");
		VerifyOutput(iface, 1, true);
		
		//Strobe flag again. If the bitstream patch was successfully applied, the output should go low at this point
		//because we're now doing ~din instead of din.
		printf("Verifying patch was successfully applied...\n");
		iface.SetGpioValue(2, true);	//din=1
		iface.SetGpioValue(0, true);	//en=1
		usleep(10 * 1000);
		iface.SetGpioValue(0, false);	//en=0
		iface.SetGpioValue(2, false);	//din=0
		usleep(10 * 1000);
		
		VerifyOutput(iface, 1, false);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}

void VerifyOutput(NetworkedJtagInterface& iface, int chan, bool expected)
{
	bool val = iface.GetGpioValue(chan);
	printf("    Got value %d\n", val);
	if(val != expected)
	{
		throw JtagExceptionWrapper(
			"    Got bad GPIO value\n",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
}
