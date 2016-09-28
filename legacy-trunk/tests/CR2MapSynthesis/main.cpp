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
	@brief CR-II map synthesis test
	
	Equivalency checking between synthesized fuse map data and the gold standard.
 */

#include <string.h>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/XilinxCoolRunnerIIDevice.h"
 
using namespace std;
 
void RunTest(int devnum, int package, int idcode, const char* mapfile);

int* ReadPermutationTable(const char* fname, int width, int depth);
 
int main()
{
	try
	{
		//TODO: Update for generic ISE using Splash integration or something
		//so we dont hard-code 14.7?
		//Although this is the last ISE release ever so it's a pretty safe guess...
		
		//Test for the XC2C32A
		RunTest(
			XilinxCoolRunnerIIDevice::XC2C32A,
			XilinxCoolRunnerIIDevice::VQG44,
			0x6E18093,
			"/opt/Xilinx/14.7/ISE_DS/ISE/xbr/data/xc2c32a.map");
	
		//Test for the XC2C64A
		RunTest(
			XilinxCoolRunnerIIDevice::XC2C64A,
			XilinxCoolRunnerIIDevice::VQG44,
			0x6E58093,
			"/opt/Xilinx/14.7/ISE_DS/ISE/xbr/data/xc2c64a.map");
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
void RunTest(int devnum, int package, int idcode, const char* mapfile)
{
	//Initialize the device
	XilinxCoolRunnerIIDevice device(
		devnum,
		package,
		0,		//stepping number
		idcode,
		NULL,	//no JtagInterface, just for testing
		0);
		
	printf("Testing model \"%s\" against fuse map file \"%s\"\n", device.GetDescription().c_str(), mapfile);
	
	//Read in the permutation table from the map file for debugging
	double start = GetTime();
	int* ref_permutation_table = ReadPermutationTable(
		mapfile, device.GetShiftRegisterWidth(), device.GetShiftRegisterDepth());
	double dt = GetTime() - start;
	printf("    Reference permutatation loaded in %.2f ms\n", dt*1000);

	//Generate the table
	start = GetTime();
	int* permutation_table = device.GeneratePermutationTable();
	dt = GetTime() - start;
	printf("    Procedural permutatation loaded in %.2f ms\n", dt*1000);
	
	//Compare them
	for(int y=0; y<device.GetShiftRegisterDepth(); y++)
	{
		int* refrow = ref_permutation_table + y*device.GetShiftRegisterWidth();
		int* row = permutation_table + y*device.GetShiftRegisterWidth();
		
		for(int x=0; x<device.GetShiftRegisterWidth(); x++)
		{
			if(refrow[x] != row[x])
			{
				//Consider -2 and -1 equivalent (-2 in model means don't care)
				//Mismatches here will be caught in CR2JtagData test
				if( (refrow[x] == XilinxCoolRunnerIIDevice::FUSE_VALUE_TRANSFER) && (row[x] == XilinxCoolRunnerIIDevice::FUSE_VALUE_DONTCARE) )
					continue;
				
				printf("    Mismatch at (column %d, row %d): model predicted %d, gold standard is %d\n",
					x, y, row[x], refrow[x]);
					
				throw JtagExceptionWrapper(
					"Bad model data",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
		}
	}
	printf("    OK\n");
	
	//Clean up
	delete[] permutation_table;
	delete[] ref_permutation_table;
}

int* ReadPermutationTable(const char* fname, int width, int depth)
{
	FILE* fp = fopen(fname, "r");
	if(!fp)
	{
		throw JtagExceptionWrapper(
			"Failed to open reference permutation table",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	int* ref_permutation_table = new int[width*depth];
	
	/*
		Output array
		
		Width = 260
		Depth = 48
		
		2D array
			0...259 are first row of data to process
			260...519 are second row
	 */
	
	//Data is tab-separated values
	char line[32768];
	for(int y=0; y<width; y++)
	{		
		//Read the line 
		fgets(line, 32767, fp);
		
		//Parse it
		char* sline = line;
		for(int x=0; x<depth; x++)
		{
			//Default to transfer bit
			int value = -1;
			if(*sline != '\t')
			{
				value = 0;
				
				//No, data - read it
				while(*sline != '\t' && *sline != '\0' && *sline != '\n')
					value = (value * 10) + (*(sline++) - '0');
				sline++;
			}
			else
				sline++;		//skip the transfer bit
			
			//Transpose and store
			ref_permutation_table[x*width + y] = value;
		}		
	}
	
	fclose(fp);
	return ref_permutation_table;
}
