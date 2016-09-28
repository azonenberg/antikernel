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
	@brief ASN.1 BER encode/decode logic
 */

#ifndef ber_h
#define ber_h

#ifdef __cplusplus
extern "C"
{
#endif

enum ASN1_TYPES
{
	ASN1_TYPE_INTEGER				= 0x02,
	ASN1_TYPE_OCTET_STRING			= 0x04,
	ASN1_TYPE_NULL					= 0x05,
	ASN1_TYPE_OID					= 0x06,
	ASN1_TYPE_SEQUENCE_CONSTRUCTED	= 0x30,
	
	ASN1_TYPE_SNMP_NO_SUCH_OBJECT	= 0x80,
	ASN1_TYPE_SNMP_END_OF_MIB		= 0x82,
	
	ASN1_TYPE_SNMP_GETREQUEST		= 0xA0,
	ASN1_TYPE_SNMP_GETNEXTREQUEST	= 0xA1,
	ASN1_TYPE_SNMP_GETRESPONSE		= 0xA2,
	ASN1_TYPE_SNMP_SETREQUEST		= 0xA3
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PARSING packets
  
//Decode a chunk header
int BERDecodeChunkHeader(
	unsigned char* message,
	unsigned int* startpos,
	
	unsigned int* type,
	unsigned int* length
	);
		
//Decode an integer
int BERDecodeInteger(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int length,
	
	unsigned int* dout
	);
	
//Decode a chunk which is expected to be an integer and fail if it's not
int BERDecodeExpectedInteger(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int* dout);
	
//Decode a string
int BERDecodeString(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int length,
	unsigned int maxlen,
	unsigned char* dout
	);
	
//Decode an OID
int BERDecodeOID(
	unsigned char* message,
	unsigned int* startpos,
	unsigned int length,
	
	unsigned int* buflen,
	unsigned int* dout
	);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GENERATING packets

unsigned int BEREncodeInteger(
	unsigned char* message,
	unsigned int startpos,
	unsigned int data);
	
unsigned int BEREncodeString(
	unsigned char* message,
	unsigned int startpos,
	const char* data);
	
unsigned int BEREncodeSequenceHeader(
	unsigned char* message,
	unsigned int startpos,
	unsigned int* len_ptr,
	unsigned char type);

unsigned int BEREncodeOID(
	unsigned char* message,
	unsigned int startpos,
	const unsigned short* oid_entry
	);
	
void BEREndSequence(
	unsigned char* message,
	unsigned int startpos,
	unsigned int lenptr);

#ifdef __cplusplus
}
#endif

#endif
