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
	@brief Implementation of ICMPv4 API
 */

#include "PDUFirmware.h"

#include <IPProtocols_constants.h>

enum ICMP_Types
{
	ICMP_TYPE_ECHO_REPLY	= 0,
	ICMP_TYPE_ECHO_REQUEST	= 8
};

//packet subtypes
enum ICMP_Codes
{
	ICMP_CODE_ECHO_REPLY	= 0,
	ICMP_CODE_ECHO_REQUEST	= 0
};

/**
	@brief Processes an ICMP packet
	
	@param frame	Pointer to frame body
	@param srcip	Source IPv4 address
	@param body_len	Length of the packet body, in words (including ICMP headers)
 */
void ICMPv4ProcessPacket(unsigned int* frame, unsigned int srcip, unsigned int body_len)
{
	unsigned int type = frame[0] >> 24;
	unsigned int code = (frame[0] >> 16) & 0xff;
	//unsigned int checksum = (frame[0] & 0xffff);

	//Length of the body, in halfwords
	unsigned int body_len_halfwords = body_len >> 1;
	if(body_len & 1)
		body_len_halfwords ++;
		
	//Length of the body, in words
	unsigned int body_len_words = (body_len >> 2);
	if(body_len & 3)
		body_len_words ++;
	
	//TODO: Verify checksum (code not quite finished)
	/*
	frame[0] = 0;
	unsigned int good_checksum = InternetChecksum(body_len_halfwords*2, (unsigned short*)frame);
	if(good_checksum != checksum)
	{
		//TODO: drop packet
	}
	*/
	
	if( (type == ICMP_TYPE_ECHO_REQUEST) && (code == ICMP_CODE_ECHO_REQUEST) )
	{		
		//Send the echo reply
		
		//Allocate
		unsigned int* txframe = EthernetAllocateFrame();
		if(!txframe)
			return;	//out of memory
		unsigned int* txbody = IPv4GetTxBodyPtr(txframe);
		
		//Fill headers
		txbody[0] = (ICMP_TYPE_ECHO_REPLY << 24) | (ICMP_CODE_ECHO_REPLY << 16);	//leave checksum at 0 for now
		txbody[1] = frame[1];		//Copy ID and sequence number
		
		//Fill data
		for(unsigned int i=2; i<body_len_words; i++)
			txbody[i] = frame[i];
			
		//Compute checksum
		txbody[0] |= InternetChecksum(body_len_halfwords, (unsigned short*)txbody);
		
		//Send the packet
		IPv4SendFrame(
			txframe,
			g_ipAddress,
			srcip,
			IP_PROTOCOL_ICMP,
			body_len);
	}
	
	else
	{
		//unknown ICMP type, ignore it
	}
}
