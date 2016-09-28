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
	@brief GF(2^n) math routines
	
	All routines assume n <= 32.
 */

#include "GF2NMath.h"

/**
	@brief GF(2^n) addition
 */
unsigned int GF2NAdd(unsigned int a, unsigned int b)
{
	return a ^ b;
}

/**
	@brief GF(2^n) subtraction (same as addition)
 */
unsigned int GF2NSub(unsigned int a, unsigned int b)
{
	return a ^ b;
}

/**
	@brief GF(2^n) multiplication for an arbitrary field
	
	Polynomial's highest-order term is implicit and should not be specified.
 */
unsigned int GF2NMultiply(unsigned int a, unsigned int b, unsigned int n, unsigned int poly)
{
	unsigned int mask = ~(0xffffffff << n);
	
	unsigned int p = 0;
	for(unsigned int i=0; i<n; i++)
	{
		if(b & 1)
			p ^= a;
		b >>= 1;
		
		unsigned int carry = a >> (n-1);	//MSB
		a = (a << 1) & mask;
		
		if(carry)
			a ^= poly;
	}

	return p;
}

/**
	@brief Polynomial long division using shift-and-subtract
 */
unsigned int GF2NMod(unsigned int a, unsigned int b)
{
	//Find degree of each
	unsigned int digits_a = 31;
	for(; !(a >> digits_a); digits_a--);
	unsigned int digits_b = 31;
	for(; !(b >> digits_b); digits_b--);

	//Early out
	if(digits_b > digits_a)
		return a;
	
	return GF2NModFast(a, b, digits_a, digits_b);
}

/**
	@brief Polynomial long division using shift-and-subtract with degree of each known in advance
 */
unsigned int GF2NModFast(unsigned int a, unsigned int b, unsigned int deg_a, unsigned int deg_b)
{
	//Long division
	unsigned int shift = deg_a - deg_b;	
	do
	{
		if(a >> (shift + deg_b))
			a ^= b << shift;
	} while(shift-- != 0);
	
	return a;
}
