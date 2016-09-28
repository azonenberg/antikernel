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
	@brief Test of BCH coding in C
 */
 
#include <string>
#include "../../src/jtaghal/jtaghal.h"
#include "../../src/fec/BCH.h"
#include "../../src/fec/GF2NMath.h"

using namespace std;
 
int main()
{
	int err_code = 0;
	try
	{	
		//Systematic BCH(31, 16) encoding test
		//Generator polynomial is
		//x^15 + x^11 + x^10 + x^9 + x^8 + x^7 + x^5 + x^3 + x^2 + x + 1
		//= 1000111110101111
		unsigned int n = 31;
		unsigned int k = 16;
		unsigned int generator = 0x8FAF;
		unsigned int message = 'A';
		
		//Part 1 - encode a single value and verify it
		printf("BCH(%u, %u) encoding test\n", n, k);
		unsigned int codeword = BCHEncode(message, generator, n, k);
		printf("    Encoded value 0x%x = 0x%08x\n", message, codeword);
		if(codeword != 0x0020ca22)
		{
			throw JtagExceptionWrapper(
				"Sanity check of BCH encoding failed",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		if(BCHValidate(codeword, generator))
		{
			printf("    Generated codeword is valid, recovered plaintext is 0x%x\n",
				BCHRecoverErrorFreeCodeword(codeword, n, k));
		}
		else
		{
			throw JtagExceptionWrapper(
				"Unaltered message failed validation",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		//Part 2 - corrupt a bunch of random bits and verify that all errors are detected.
		printf("Error detection test\n");
		srand(0);
		const int num_tests = 500;
		for(int num_errors=1; num_errors<=7; num_errors++)
		{
			printf("    %d messages with %d random errors...\n", num_tests, num_errors);
			fflush(stdout);
			for(int i=0; i<num_tests; i++)
			{
				unsigned int corrupted_codeword = codeword;
				for(int j=0; j<num_errors; j++)
				{
					unsigned int bit_to_corrupt = rand() % n;
					corrupted_codeword ^= (1 << bit_to_corrupt);
				}
				
				//In rare cases if corrupting an even number of bits, we may flip a bit and then flip it back
				//This leads to no errors and shouldn't trip the detector.
				if(corrupted_codeword == codeword)
					continue;
				
				if(BCHValidate(corrupted_codeword, generator))
				{
					printf("    Corrupted codeword %08x passed syndrome validation\n", corrupted_codeword);
					throw JtagExceptionWrapper(
						"Corrupted message passed validation",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}

			}
		}
		
		//Part 3 - corrupt a bunch of random bits and try to decode the messages
		printf("Error correction test\n");
		unsigned int corrupted_codeword = codeword ^ 0xc0010000;
		printf("    Corrupted codeword = %08x\n", corrupted_codeword);
		/*unsigned int msg = */BCHDecode(corrupted_codeword, generator, n, k);
		
		printf("OK\n");
		
		return 1;
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}
	
	return err_code;
}
