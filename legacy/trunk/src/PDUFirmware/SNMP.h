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
	@brief Declaration of SNMP API
 */

#ifndef snmp_h
#define snmp_h

#define SNMP_VERSION_2C		1
#define SNMP_AGENT_PORT 161

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// API

void SNMPInitialize();

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Interrupt handlers

void SNMPProcessPacket(unsigned int* packet, unsigned int srcip, unsigned int srcport, unsigned short bytelen);

void SNMPProcessGetOrGetNextRequest(
	unsigned char* bpacket,
	unsigned int* pos,
	unsigned int srcip,
	unsigned int srcport,
	unsigned int request_id,
	unsigned char getnext);
	
void SNMPProcessSetRequest(
	unsigned char* bpacket,
	unsigned int* pos,
	unsigned int srcip,
	unsigned int srcport,
	unsigned int request_id);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Internal functions

enum oidsearch_results
{
	OID_SEARCH_TOO_LOW,
	OID_SEARCH_HIT,
	OID_SEARCH_MISS,
	OID_SEARCH_TOO_HIGH
};

unsigned int SNMPFindOID(unsigned int* oid, unsigned int oidlen, unsigned int* oidpos);

int SNMPCompareOIDs(const unsigned int* oidA, unsigned int lenA, const unsigned short* oidB, unsigned int lenB);

void SNMPSendGetResponse(
	unsigned int srcip,
	unsigned int srcport,
	unsigned int request_id,
	int oid_index
	);
	
unsigned int SNMPGenerateGetPacketBody(
	unsigned char* message,
	unsigned int startpos,
	int oid_index
	);

#endif



