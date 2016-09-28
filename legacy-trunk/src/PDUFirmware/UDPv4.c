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
	@brief Implementation of UDPv4 API
 */

#include "PDUFirmware.h"

#include <IPProtocols_constants.h>

/**
	@brief Sends a UDPv4 packet
	
	@param frame			Start of the frame
	@param to_addr			Destination IPv4 address
	@param srcport			Source UDP port number
	@param dstport			Destination UDP port number
	@param payload_length	Length of the UDP packet body, in bytes
 */
void UDPv4SendPacket(
	unsigned int* frame,
	unsigned int to_addr,
	unsigned short srcport,
	unsigned short dstport,
	unsigned int payload_length
	)
{
	unsigned int* body = IPv4GetTxBodyPtr(frame);
	
	//Add headers to total packet size
	payload_length += 8;
	
	//Write initial headers
	body[0] = (srcport << 16) | dstport;
	body[1] = (payload_length << 16);
	
	//TODO: Compute checksum (for now use zero, checksums are optional)
	
	//Send the frame
	IPv4SendFrame(
		frame,
		g_ipAddress,
		to_addr,
		IP_PROTOCOL_UDP,
		payload_length);
}

/**
	@brief Gets a pointer to the body of a UDP packet
 */
unsigned int* UDPv4GetTxBodyPtr(unsigned int* frame)
{
	return IPv4GetTxBodyPtr(frame) + 2;
}

void UDPv4ProcessPacket(unsigned int* packet, unsigned int srcip)
{
	unsigned short srcport = packet[0] >> 16;
	unsigned short dstport = packet[0] & 0xffff;
	unsigned short bytelen = packet[1] >> 16;
	//unsigned short checksum = packet[1] & 0xff;

	//TODO: Validate checksum
	
	//Process stuff
	switch(dstport)
	{
	case DHCP_CLIENT_PORT:
		DHCPProcessPacket(packet+2, srcip, srcport, bytelen);
		break;
		
	case SNMP_AGENT_PORT:
		SNMPProcessPacket(packet+2, srcip, srcport, bytelen);
		break;
		
	default:
		//unknown port number
		break;
	}
}
