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
	@brief Implementation of systematic BCH code
 */

#include "GF2NMath.h"
#include "BCH.h"

/**
	@brief (n, k) BCH encoder for n <= 32
	
	@param data			Data word (up to k bits, zero-padded at left automatically)
	@param generator	Generator polynomial (of degree n-k)
	@param n			Number of bits in the code word
	@param k			Number of data bits
 */
unsigned int BCHEncode(unsigned int data, unsigned int generator, unsigned int n, unsigned int k)
{
	unsigned int gendeg = n-k;	//degree of generator polynomial 
	unsigned int sdata = data << gendeg;
	return (data << gendeg) | GF2NMod(sdata, generator);
}

/**
	@brief (n, k) error detection for BCH code (no correction)
	
	@param codeword		Received message codeword
	@param generator	Generator polynomial
	
	@return 1 if the code word is valid (syndrome = 0), 0 in case of errors
 */
unsigned int BCHValidate(unsigned int codeword, unsigned int generator)
{
	return GF2NMod(codeword, generator) ? 0 : 1;
}

/**
	@brief Recovers a BCH codeword assuming no errors occurred
	
	@param codeword		Received message codeword (must be valid)
	@param n			Number of bits in the code word
	@param k			Number of data bits
 */
unsigned int BCHRecoverErrorFreeCodeword(unsigned int codeword, unsigned int n, unsigned int k)
{
	return codeword >> (n-k);
}

/**
	@brief Recovers a BCH codeword, possibly with errors
	
	@param codeword		Received message codeword (must be valid)
	@param generator	Generator polynomial
	@param n			Number of bits in the code word
	@param k			Number of data bits
 */
unsigned int BCHDecode(unsigned int codeword, unsigned int generator, unsigned int n, unsigned int k)
{
	//Not yet working!!!
	(void)codeword;
	(void)generator;
	(void)n;
	(void)k;
	return 0;
	
	//unsigned int syndrome = GF2NMod(codeword, generator);
	//printf("    Syndrome = %08x\n", syndrome);
	
	/**
		Need to generate six syndrome polynomials
	 */
}
