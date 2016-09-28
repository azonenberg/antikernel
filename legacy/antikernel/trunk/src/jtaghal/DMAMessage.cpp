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
	@brief Implementation of DMAMessage
 */

#include <stdio.h>
#include "DMAMessage.h"
#include "JtagException.h"

/**
	@brief Packs this message into an array of 515 words suitable for sending via JTAG
	
	The data is byte-swapped, but the headers are kept in host endianness for ease of processing.
	TODO: decide if this makes sense
	
	@param buf Pointer to an array of 515 words
 */
void DMAMessage::Pack(uint32_t* buf) const
{
	buf[0] = (from << 16) | to;
	buf[1] = (opcode << 30) | len;
	buf[2] = address;
	for(int i=0; i<len; i++)
	{
		unsigned int d0 = data[i] & 0xff;
		unsigned int d1 = (data[i] >> 8) & 0xff;
		unsigned int d2 = (data[i] >> 16) & 0xff;
		unsigned int d3 = (data[i] >> 24) & 0xff;
		uint32_t dout = d3 | (d2 << 8) | (d1 << 16) | (d0 << 24);
		buf[3+i] = dout;
	}	
}

/**
	@brief Unpacks an array of 3 words into this object's headers, zeroizing the data if requested
	
	@param buf				Pointer to an array of 3 words
	@param zeroizedata		Set true (default) to clear data to zero
 */
void DMAMessage::UnpackHeaders(uint32_t* buf, bool zeroizedata)
{
	from = buf[0] >> 16;
	to = buf[0] & 0xffff;
	opcode = buf[1] >> 30;
	len = buf[1] & 0x3FF;
	address = buf[2];
	
	if(zeroizedata)
	{
		for(int i=0; i<512; i++)
			data[i] = 0;
	}
}

/**
	@brief Unpacks an array of 515 words into this object
	
	@param buf Pointer to an array of 515 words
 */
void DMAMessage::Unpack(uint32_t* buf)
{
	UnpackHeaders(buf, false);
	
	for(int i=0; i<len; i++)
	{
		unsigned int d0 = buf[3+i] & 0xff;
		unsigned int d1 = (buf[3+i] >> 8) & 0xff;
		unsigned int d2 = (buf[3+i] >> 16) & 0xff;
		unsigned int d3 = (buf[3+i] >> 24) & 0xff;
		uint32_t dout = d3 | (d2 << 8) | (d1 << 16) | (d0 << 24);
		data[i] = dout;
	}
	
	//zeroize data after the end of the packet
	for(int i=len; i<512; i++)
		data[i] = 0;
}

bool DMAMessage::operator==(const DMAMessage& rhs) const
{
	if(from != rhs.from)
		return false;
	if(to != rhs.to)
		return false;
	if(opcode != rhs.opcode)
		return false;
	if(address != rhs.address)
		return false;
	if(len != rhs.len)
		return false;
	for(uint16_t i=0; i<len; i++)
	{
		if(data[i] != rhs.data[i])
			return false;
	}
	return true;
}

