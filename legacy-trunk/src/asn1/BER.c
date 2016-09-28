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
	@brief ASN.1 BER encode/decode library
 */

#include "BER.h"
#include "string.h"

/**
	@brief Decodes the header for a single BER chunk
	
	@param message		[in]	Pointer to the START of the message being decoded
	@param startpos		[inout] Pointer to the current position in the message.
								Updated with the start of this chunk's data on successful return.
	@param type			[out]	Pointer to the ASN.1 message type.
	@param length		[out]	Pointer to the decoded length value
	
	@return 0 on success, -1 on fail
 */
int BERDecodeChunkHeader(
	unsigned char* message,
	unsigned int* startpos,
	
	unsigned int* type,
	unsigned int* length
	)
{
	//Read the type
	unsigned int pos = *startpos;
	unsigned int id = message[pos++];
	
	//Make sure the type is valid (we don't understand multi-octet types yet)
	if( (id & 0x1F) == 0x1F)
		return -1;
	
	//Read the length
	//Three possible encodings
	unsigned int len = message[pos++];
	if(len & 0x80)
	{
		//TODO: Implement indefinite form
		if(len == 0x80)
			return -1;
		
		//Long definite form
		else
		{
			//Number of octets in the length field
			unsigned int len_size = len & 0x7F;
			
			//If >2, panic (64KB is WAAY too big for an ethernet frame)
			if(len_size > 2)
				return -1;
				
			//Read the length
			len = 0;
			for(unsigned int i=0; i<len_size; i++)
			{
				len <<= 8;
				len |= message[pos++];
			}
		}
	}
	else
	{
		//Short form, length is good as is
	}
	
	//Save values and return
	*length = len;
	*type = id;
	*startpos = pos;
	return 0;
}

/**
	@brief Decodes a BER-encoded integer
	
	@param message		[in]	Pointer to the START of the message being decoded
	@param startpos		[inout] Pointer to the current position in the message.
								Updated with the start of this chunk's data on successful return.
	@param length		[in]	Length of the value (from chunk headers)
	@param dout			[out]	The resulting integer
	
	@return 0 on success, -1 on fail
 */
int BERDecodeInteger(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int length,
	unsigned int* dout
	)
{
	//Too big, give up
	if(length > 4)
		return -1;
	
	//Read it
	unsigned int rv = 0;
	int pos = *startpos;
	for(unsigned int i=0; i<length; i++)
	{
		rv <<= 8;
		rv |= message[pos++];
	}
	*startpos = pos;
	*dout = rv;
	
	//All good
	return 0;
}

/**
	@brief Decodes a BER chunk, expecting an integer.
	
	@param message		[in]	Pointer to the START of the message being decoded
	@param startpos		[inout] Pointer to the current position in the message.
								Updated with the start of this chunk's data on successful return.
	@param dout			[out]	Pointer to store the resulting integer to
	
	@return 0 on success, -1 on fail
 */
int BERDecodeExpectedInteger(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int* dout)
{
	unsigned int type;
	unsigned int len;
	if(0 != BERDecodeChunkHeader(message, startpos,	&type, &len))
		return -1;
	if(type != ASN1_TYPE_INTEGER)
		return -1;
	if(0 != BERDecodeInteger(message, startpos, len, dout))
		return -1;
	return 0;
}

/**
	@brief Decodes a BER-encoded string and null terminates it.
	
	@param message		[in]	Pointer to the START of the message being decoded
	@param startpos		[inout] Pointer to the current position in the message.
								Updated with the start of this chunk's data on successful return.
	@param length		[in]	Length of the ASN.1 data to decode
	@param maxlen		[in]	Length of the buffer pointed to by dout
	@param dout			[out]	Buffer in which to store the resulting data
	
	@return 0 on success, -1 on fail
 */
int BERDecodeString(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int length,
	unsigned int maxlen,
	unsigned char* dout
	)
{
	//Bounds check
	if(length >= maxlen)
		return -1;
	
	//Do the copy
	int pos = *startpos;
	for(unsigned int i=0; i<length; i++)
		dout[i] = message[pos++];
	dout[length] = 0;
	*startpos = pos;
	
	return 0;
}

/**
	@brief Decodes a BER-encoded OID
	
	@param message		[in]	Pointer to the START of the message being decoded
	@param startpos		[inout] Pointer to the current position in the message.
								Updated with the start of this chunk's data on successful return.
	@param length		[in]	Length of the ASN.1 data to decode, in bytes
	@param buflen		[inout]	Length of the buffer pointed to by dout, in words
								Updated with the actual length of the decoded message
	@param dout			[out]	Buffer to store the decoded OID into
	
	@return 0 on success, -1 on fail
 */
int BERDecodeOID(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int length,
	
	unsigned int* buflen,
	unsigned int* dout
	)
{
	//All SNMP OIDs are at least eight octets long, fail if the buffer is smaller than that
	unsigned int nbuflen = *buflen;
	if(nbuflen < 8)
		return -1;
	
	//First two octets of a valid OID are 0x2B and decode to {1, 3}
	unsigned int pos = *startpos;
	unsigned int end = pos + length;
	if(message[pos++] != 0x2b)
		return -1;
	dout[0] = 1;	//iso
	dout[1] = 3;	//org
	unsigned int outpos = 2;
	
	//Each subsequent number is a byte if 0x80 bit is not set, or a multibyte value if it is
	while(pos < end)
	{
		unsigned int fval = 0;
		
		//Read one octet at a time
		while(1)
		{
			unsigned char val = message[pos++];
			
			//Push it onto the end of the current OID value
			fval = (fval << 7) | (val & 0x7F);
			
			//Stop if this is the end
			if((val & 0x80) == 0)
				break;
		}
		
		//Append this value to the end of the OID if it'll fit
		if(outpos >= nbuflen)
			return -1;
		dout[outpos++] = fval;
	}
	
	//Update pointers and sizes
	*buflen = outpos;
	*startpos = pos;
	return 0;
}

/**
	@brief Encodes an integer using BER
	
	@param message	Pointer to the message buffer
	@param startpos	Address to write the integer to
	@param data		The value to write
	
	@return New write pointer
 */
unsigned int BEREncodeInteger(
	unsigned char* message,
	unsigned int startpos,
	unsigned int data)
{
	//Write the header
	message[startpos++] = ASN1_TYPE_INTEGER;
	unsigned int lenptr = startpos;
	message[startpos++] = 0xcc;		//length not known yet
			
	//Write the data
	//Avoid signedness errors! If the MSB is 1, zero extend
	if(data & 0xff800000)
		message[startpos++] = data >> 24;
	if(data & 0x00ff8000)
		message[startpos++] = (data >> 16) & 0xff;
	if(data & 0x0000ff80)
		message[startpos++] = (data >> 8) & 0xff;
	message[startpos++] = data & 0xff;
	
	//Write the length
	message[lenptr] = startpos - (lenptr + 1);
	return startpos;
}

/**
	@brief Encodes an octet string using BER
	
	@param message	Pointer to the message buffer
	@param startpos	Address to write the integer to
	@param data		The value to write
	
	@return New write pointer
 */
unsigned int BEREncodeString(
	unsigned char* message,
	unsigned int startpos,
	const char* data)
{
	unsigned int len = strlen(data);
	
	//Type
	message[startpos++] = ASN1_TYPE_OCTET_STRING;
	
	//Length
	if(len < 128)
		message[startpos++] = len;
	else
	{
		message[startpos++]	= 0x82;
		message[startpos++] = (len >> 8) & 0xff;
		message[startpos++] = len & 0xff;
	}
	
	//Data	
	strcpy((char*)(message+startpos), data);
	return startpos + len;
}

/**
	@brief Encodes a sequence header using BER
	
	@param message	[in]  Pointer to the message buffer
	@param startpos	[in]  Index to write the sequence header at
	@param len_ptr	[out] Pointer to the length value (since it's not known yet, needs to be updated later)
	@param type		[in]  The sequence type (defaults to ASN1_TYPE_SEQUENCE_CONSTRUCTED)
 */
unsigned int BEREncodeSequenceHeader(
	unsigned char* message,
	unsigned int startpos,
	unsigned int* len_ptr,
	unsigned char type)
{
	message[startpos++] = type;
	message[startpos++] = 0x82;
	*len_ptr = startpos;
	message[startpos++] = 0xCC;	//length not known yet
	message[startpos++] = 0xCC;
	return startpos;
}

/**
	@brief Updates the length field after finishing writing data into a sequence
	
	@param message		[in]  Pointer to the message buffer
	@param startpos		[in]  Current write address
	@param lenptr		[in]  Address of the start of the sequence's length value
 */
void BEREndSequence(unsigned char* message, unsigned int startpos, unsigned int lenptr)
{
	unsigned int slen = startpos - (lenptr + 2);
	message[lenptr] = slen >> 8;
	message[lenptr + 1] = slen & 0xFF;
}

/**
	@brief Encodes an OID using BER
	
	@param message		[in]  Pointer to the message buffer
	@param startpos		[in]  Index to write the sequence header at
	@param oid_entry	[out] Pointer to the OID table entry to write (see start of file for format)
 */
unsigned int BEREncodeOID(
	unsigned char* message,
	unsigned int startpos,
	const unsigned short* oid_entry
	)
{
	message[startpos++] = ASN1_TYPE_OID;
	message[startpos++] = 0x81;
	unsigned int oid_len_ptr = startpos;
	message[startpos++] = 0xCC;				//OID length not known yet
	message[startpos++] = 0x2b;				//1.3
	message[startpos++] = 0x6;				//Add the implicit 6.1
	message[startpos++] = 0x1;
	for(unsigned int i=0; i<oid_entry[0]; i++)
	{
		unsigned int digit = oid_entry[i+1];
		
		//Do not support any value more than 3 encoded bytes (larger than 1FFFFF) for now
		if(digit > 0x3FF)
			message[startpos++] = 0x80 | (digit >> 14);
		if(digit > 127)
			message[startpos++] = 0x80 | ( (digit >> 7) & 0x7F);
		message[startpos++] = digit & 0x7F;
	}
	message[oid_len_ptr] = startpos - (oid_len_ptr + 1);	//Store OID length
	
	return startpos;
}
