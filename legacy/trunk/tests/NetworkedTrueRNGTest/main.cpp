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
	@brief NetworkedTrueRNGTest test
	
	Runs a bunch of randomness tests on the RNG
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtaghal/UART.h"
#include "../../src/jtagboards/jtagboards.h"

#include <NetworkedTrueRNG_opcodes_constants.h>

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
		
		//Needs to be deterministic for testing
		srand(0);
		
		//Address lookup
		printf("Looking up address of RNG\n");
		NameServer nameserver(&iface);
		uint16_t raddr = nameserver.ForwardLookup("rng");
		printf("RNG is at %04x\n", raddr);
		
		//Reset
		printf("Resetting RNG...\n");
		RPCMessage rmsg;
		iface.RPCFunctionCall(raddr, RNG_OP_RESET, 0, 0, 0, rmsg);
		
		//Store some parameters for the RNG lookup
		const size_t nbuffers = 128*1;
		const size_t dma_wordsize = 512;
		const size_t dma_bytesize = 2048;
		const size_t nbytes = dma_bytesize * nbuffers;
		
		//Histogram of byte frequency
		size_t byte_freq_histogram[256] = {0};
		
		//Read some buffers of random data and write them to the filesystem so we can run external tests
		uint32_t rdbuf[dma_wordsize];
		printf("Reading random data...\n");
		//FILE* fp = fopen("/tmp/foobar.bin", "wb");
		unsigned char* bptr = reinterpret_cast<unsigned char*>(&rdbuf[0]);
		for(size_t j=0; j<nbuffers; j++)
		{
			//Read and write the data
			iface.DMARead(raddr, 0x00000000, dma_wordsize, rdbuf, 0, 5);
			//fwrite(rdbuf, sizeof(uint32_t), dma_wordsize, fp);
			
			//Update the histogram
			for(size_t k=0; k<dma_bytesize; k++)
				byte_freq_histogram[bptr[k]] ++;
		}
		//fclose(fp);
		
		//Print out the histogram
		printf("Histogram: \n");
		for(size_t i=0; i<256; i++)
		{
			printf("%7zu ", byte_freq_histogram[i]);
			if( (i & 15) == 15)
				printf("\n");
		}
		
		//Check the histogram
		size_t expected_histval = nbytes / 256;
		ssize_t maxdev = expected_histval / 5;
		printf("Expected histogram bin size: %zu\n", expected_histval);
		for(int i=0; i<256; i++)
		{
			ssize_t delta = static_cast<ssize_t>(byte_freq_histogram[i]) - static_cast<ssize_t>(expected_histval);
			if(delta > maxdev)
			{
				printf("Max deviation exceeded in bin %d (delta %zd, expected <%zd)\n", i, delta, maxdev);
				return -1;
			}
		}
		
		printf("OK\n");
		
		//TODO: Maybe add more randomness checks?
		
		return 0;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}
