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
	@brief Main source file for bitparser
	
	\ingroup bitparser
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>

#include "../jtaghal/jtaghal.h"
#include <svnversion.h>

#include <signal.h>

using namespace std;

/**
	@brief Program entry point

	\ingroup bitparser
 */
int main(int argc, char* argv[])
{
	try
	{
		if(argc != 3)
		{
			printf("Usage: bitparser [hex JTAG ID code] [filename]\n");
			return 0;
		}

		unsigned int idcode;
		sscanf(argv[1], "%8x", &idcode);
		string bitfile = argv[2];
		
		//Create the device
		JtagDevice* device = JtagDevice::CreateDevice(idcode, NULL, 0);
		if(device == NULL)
		{
			throw JtagExceptionWrapper(
				"Device is null, cannot continue",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}

		//Make sure it's a programmable device
		ProgrammableDevice* pdev = dynamic_cast<ProgrammableDevice*>(device);
		if(pdev == NULL)
		{
			throw JtagExceptionWrapper(
				"Device is not a programmable device, cannot continue",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		printf("JTAG ID code is: %s\n", device->GetDescription().c_str());
		
		//Load the firmware image
		printf("Loading firmware image...\n");
		FirmwareImage* img = pdev->LoadFirmwareImage(bitfile, true);
		
		delete img;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	//Done
	return 0;
}
