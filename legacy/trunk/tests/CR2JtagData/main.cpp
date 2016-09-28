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
	@brief CR-II JTAG data
	
	Equivalency checking between synthesized fuse map data and the gold standard.
 */

#include <string.h>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"
#include "../../src/jtaghal/XilinxCPLDBitstream.h"
 
using namespace std;
 
void RunTest(int devnum, int package, int idcode, const char* jedfile, const char* svffile);
unsigned char* LoadReferenceOutput(const char* fname, int width, int height);

unsigned char* LoadReferenceOutput(int width, int height);

const char* rowname(int y, char* buf);
char* reverse(char* s);

int main()
{
	try
	{
		//Test for the XC2C32A
		RunTest(
			XilinxCoolRunnerIIDevice::XC2C32A,
			XilinxCoolRunnerIIDevice::VQG44,
			0x6E18093,
			"../../../testdata/xc2c32a_sample.jed",
			"../../../testdata/xc2c32a_sample_data.txt");
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
void RunTest(int devnum, int package, int idcode, const char* jedfile, const char* svffile)
{
	//Initialize the device
	XilinxCoolRunnerIIDevice device(
		devnum,
		package,
		0,		//stepping number
		idcode,
		NULL,	//no JtagInterface, just for testing
		0);
		
	int nbits = device.GetShiftRegisterWidth() + 12;
	int nbytes = ceil(nbits / 8.0f);
		
	printf("Testing model \"%s\" against iMPACT-generated output SVF body\"%s\"\n", device.GetDescription().c_str(), svffile);

	//Generate the table
	printf("    Generating permutation...\n");
	int* permutation_table = device.GeneratePermutationTable();
		
	//Load the JED file
	printf("    Loading JED file...\n");
	FirmwareImage* img = dynamic_cast<ProgrammableDevice*>(&device)->LoadFirmwareImage(jedfile);
	
	//Apply the permutation
	printf("    Generating permuted output...\n");
	unsigned char* data = device.GeneratePermutedFuseData(dynamic_cast<XilinxCPLDBitstream*>(img), permutation_table);
	
	//Print out permutation output
	/*
	unsigned char* row = data;
	for(int y=0; y<device.GetShiftRegisterDepth(); y++)
	{
		for(int x=0; x<nbytes; x++)
			printf("%02x", row[x] & 0xff);
		printf("\n");		
		row += nbytes;
	}
	printf("\n");
	*/
	
	//Load the reference output
	printf("    Loading reference data...\n");
	unsigned char* refdata = LoadReferenceOutput(svffile, nbytes, device.GetShiftRegisterDepth());
	
	//Compare them
	bool mismatch = false;
	for(int y=0; y<device.GetShiftRegisterDepth(); y++)
	{
		unsigned char* refrow = refdata + y*nbytes;
		unsigned char* row = data + y*nbytes;
		
		for(int x=0; x<nbytes; x++)
		{
			if(refrow[x] != row[x])
			{
				//Do bit-level debugging
				char tempbuf[16];
				for(int nbit=7; nbit >= 0; nbit--)
				{
					int refbit = (refrow[x] >> nbit) & 1;
					int dbit = (row[x] >> nbit) & 1;
					if(refbit != dbit)
					{
						printf("    Mismatch at row %d (%s), bit %d (x=%d nbit=%d): model predicted %d, gold standard is %d\n",
							y, rowname(y, tempbuf), x*8 + (7 - nbit), x, nbit, dbit, refbit);
					}
				}
				mismatch = true;
			}
		}
	}
	
	//Throw exception at end after printing all errors
	if(mismatch)
	{
		throw JtagExceptionWrapper(
					"Bad model data",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
	}
	else
		printf("    OK\n");
	
	//Clean up
	delete[] data;
	delete[] permutation_table;
	delete img;
}

unsigned char* LoadReferenceOutput(const char* fname, int width, int height)
{
	FILE* fp = fopen(fname, "r");
	if(!fp)
	{
		throw JtagExceptionWrapper(
			"Couldn't open reference file",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}

	unsigned char* data = new unsigned char[width*height];
	
	//Read the data
	unsigned char* row = data;
	for(int y=0; y<height; y++)
	{
		int tmp;
		for(int x=0; x<width; x++)
		{
			fscanf(fp, "%02x", &tmp);
			row[x] = tmp;
		}
		row += width;
	}
	
	fclose(fp);
	return data;
}

const char* rowname(int y, char* buf)
{
	memset(buf, 0, 16);
	buf[0] = 'A' + (y % 26);
	if(y >= 26)
		buf[1] = 'A' + (((y-26)/26) % 26);
	//TODO: >2 char
	return reverse(buf);
}


/**
	@brief Reverses a string in-place (K&R implementation)
	
	@param s Input
	@return s after reversing
 */
char* reverse(char* s)
{
	int i, j;
	
	for (i = 0, j = strlen(s)-1; i<j; i++, j--)
	{
		char c = s[i];
		s[i] = s[j];
		s[j] = c;
	}
	return s;
}
