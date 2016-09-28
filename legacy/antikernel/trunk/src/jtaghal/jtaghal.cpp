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
	@brief Implementation of global functions
 */
 
/** 
	\defgroup libjtaghal libjtaghal: JTAG Hardware Abstraction Layer
	
	Libjtaghal is a hardware abstraction layer which presents a device-independent interface for manipulating devices in
	a JTAG scan chain.
	
	Libjtaghal is released under the same permissive 3-clause BSD license as the remainder of the project.
 */

#include "jtaghal.h"
#include <memory.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Byte manipulation

/**
	@brief Extracts a bit from a bit string
	
	(data[0] & 1) is considered to be the LSB.
	
	@param data		The bit string
	@param nbit		Index (zero based) of the bit to extract
	
	@return Value of the bit
	
	\ingroup libjtaghal
 */
bool PeekBit(const unsigned char* data, int nbit)
{
	unsigned char w = data[nbit/8];
	w >>= (nbit & 7);
	w &= 1;
	return w;
}

/**
	@brief Writes a bit to a bit string.
	
	(data[0] & 1) is considered to be the LSB.
	
	@param data		The bit string
	@param nbit		Index (zero based) of the bit to write
	@param val		The value to write at that bit
	
	\ingroup libjtaghal
 */
void PokeBit(unsigned char* data, int nbit, bool val)
{
	unsigned char w = data[nbit/8];
	int bitpos = nbit & 7;
	unsigned char mask = 1 << bitpos;
	w &= ~mask;
	w |= (val << bitpos);
	data[nbit/8] = w;
}

/**
	@brief Flips the bits in a byte
	
	@param c	Input byte
	@return		Output byte
	
	\ingroup libjtaghal
 */
unsigned char FlipByte(unsigned char c)
{
	return
		( ( (c >> 0) & 1) << 7 ) |
		( ( (c >> 1) & 1) << 6 ) |
		( ( (c >> 2) & 1) << 5 ) |
		( ( (c >> 3) & 1) << 4 ) |
		( ( (c >> 4) & 1) << 3 ) |
		( ( (c >> 5) & 1) << 2 ) |
		( ( (c >> 6) & 1) << 1 ) |
		( ( (c >> 7) & 1) << 0 );
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Array manipulation

/**
	@brief Reverses an array of bytes in place without changing bit ordering
	
	@param data		The buffer to manipulate
	@param len		Length, in bytes, of the buffer
	
	\ingroup libjtaghal
 */
void FlipByteArray(unsigned char* data, int len)
{
	unsigned char* temp = new unsigned char[len];
	memcpy(temp, data, len);
	for(int i=0; i<len; i++)
		data[i] = temp[len-i-1];
	delete[] temp;
}

/**
	@brief Reverses the bit ordering in an array of bytes, but does not change byte ordering
	
	@param data		The buffer to manipulate
	@param len		Length, in bytes, of the buffer
	
	\ingroup libjtaghal
 */
void FlipBitArray(unsigned char* data, int len)
{
	for(int i=0; i<len; i++)
		data[i] = FlipByte(data[i]);
}

/**
	@brief Reverses the bit ordering in an array of bits (need not be integer byte size)
	
	@param data		The buffer to manipulate
	@param bitlen	Length, in bits, of the buffer
	
	\ingroup libjtaghal
 */
void MirrorBitArray(unsigned char* data, int bitlen)
{
	int bytesize = ceil(bitlen / 8.0f);
	unsigned char* temp = new unsigned char[bytesize];
	memcpy(temp, data, bytesize);
	for(int i=0; i<bitlen; i++)
		PokeBit(data, i, PeekBit(temp, bitlen-(i+1)));
	delete[] temp;
}

/**
	@brief Swaps endianness in an array of 16-bit values
	
	@param data		The buffer to manipulate
	@param len		Length, in bytes, of the buffer (must be even)
	
	\ingroup libjtaghal
 */
void FlipEndianArray(unsigned char* data, int len)
{
	//make sure len is even
	len &= ~1;
	
	for(int i=0; i<len; i+= 2)
	{
		unsigned char temp = data[i];
		data[i] = data[i+1];
		data[i+1] = temp;
	}
}

/**
	@brief Swaps endianness in an array of 32-bit values
	
	@param data		The buffer to manipulate
	@param len		Length, in bytes, of the buffer (must be a multiple of 4)
	
	\ingroup libjtaghal
 */
void FlipEndian32Array(unsigned char* data, int len)
{
	//make sure len is even
	len &= ~3;
	
	for(int i=0; i<len; i+= 4)
	{
		unsigned char temp[4] = { data[i], data[i+1], data[i+2], data[i+3] };
		data[i]   = temp[3];
		data[i+1] = temp[2];
		data[i+2] = temp[1];
		data[i+3] = temp[0];
	}
}

/**
	@brief Reverses the bit ordering in an array of bytes, as well as 16-bit endianness
	
	@param data		The buffer to manipulate
	@param len		Length, in bytes, of the buffer
	
	\ingroup libjtaghal
 */
void FlipBitAndEndianArray(unsigned char* data, int len)
{
	FlipEndianArray(data, len);
	FlipBitArray(data, len);
}

/**
	@brief Reverses the bit ordering in an array of bytes, as well as 32-bit endianness
	
	@param data		The buffer to manipulate
	@param len		Length, in bytes, of the buffer
	
	\ingroup libjtaghal
 */
void FlipBitAndEndian32Array(unsigned char* data, int len)
{
	FlipEndian32Array(data, len);
	FlipBitArray(data, len);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Performance measurement

/**
	@brief Returns a timestamp suitable for performance measurement.
	
	The base unit is seconds.
	
	@return The timestamp.
	
	\ingroup libjtaghal
 */
double GetTime()
{
#ifdef _WINDOWS
	uint64_t tm;
	static uint64_t freq = 0;
	QueryPerformanceCounter(reinterpret_cast<LARGE_INTEGER*>(&tm));
	double ret = tm;
	if(freq == 0)
		QueryPerformanceFrequency(reinterpret_cast<LARGE_INTEGER*>(&freq));
	return ret / freq;
#else
	timespec t;
	clock_gettime(CLOCK_REALTIME,&t);
	double d = static_cast<double>(t.tv_nsec) / 1E9f;
	d += t.tv_sec;
	return d;
#endif
}
