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
	@brief CR-II bitstream diffing
	
	Equivalency checking between re-serialized CR-II bitstream and the original.
 */

#include <string.h>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"
#include "../../src/jtaghal/XilinxCPLDBitstream.h"
#include "../../src/crowbar/FCCoolRunnerIIDevice.h"
 
using namespace std;
 
void RunTest(const char* devname, int devnum, int package, int idcode, const char* jedfile, const char* temp_jedfile);

const char* rowname(int y, char* buf);
char* reverse(char* s);

int main()
{
	try
	{
		//Test for the XC2C32A
		RunTest(
			"xc2c32a-6-vq44",
			XilinxCoolRunnerIIDevice::XC2C32A,
			XilinxCoolRunnerIIDevice::VQG44,
			0x6E18093,
			"../../../testdata/xc2c32a_sample.jed",
			"test_xc2c32a.jed");
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		return 1;
	}
	
	return 0;
}

/**
	@brief Runs a single test case
 */
void RunTest(const char* devname, int devnum, int package, int idcode, const char* jedfile, const char* temp_jedfile)
{
	//Clean up old files
	unlink(temp_jedfile);
	
	//Initialize the device
	XilinxCoolRunnerIIDevice device(
		devnum,
		package,
		0,		//stepping number
		idcode,
		NULL,	//no JtagInterface, just for testing
		0);
	
	//Create the device and load/save the bitstream
	FCDevice* dev = FCDevice::CreateDevice(devname);
	dev->LoadFromBitstream(jedfile);
	dev->SaveToBitstream(temp_jedfile);
	
	//Load the JED files
	printf("Loading reference JED file...\n");
	FirmwareImage* refimg = dynamic_cast<ProgrammableDevice*>(&device)->LoadFirmwareImage(jedfile);
	printf("Loading reserialized JED file...\n");
	FirmwareImage* img = dynamic_cast<ProgrammableDevice*>(&device)->LoadFirmwareImage(temp_jedfile);
	
	//Diff them
	printf("Diffing...\n");
	CPLDBitstream* crefimg = static_cast<CPLDBitstream*>(refimg);
	CPLDBitstream* cimg = static_cast<CPLDBitstream*>(img);
	if(crefimg->fuse_count != cimg->fuse_count)
	{
		throw JtagExceptionWrapper(
				"Fuse count mismatch",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
	}
	for(size_t i=0; i<crefimg->fuse_count; i++)
	{
		if(crefimg->fuse_data[i] != cimg->fuse_data[i])
		{
			printf("Mismatch at bit %zu\n", i);
			throw JtagExceptionWrapper(
				"Fuse data mismatch",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
	}
	
	//Done
	printf("OK\n");
	
	//Print debug output
	dev->Dump();
	
	//Clean up
	delete dev;
	delete refimg;
	delete img;
}
