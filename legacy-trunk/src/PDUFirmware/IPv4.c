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
	@brief Implementation of IPv4
 */

#include "PDUFirmware.h"

#include <Ethertypes_constants.h>
#include <IPProtocols_constants.h>

#include <GraftonCPURPCDebugOpcodes_constants.h>

unsigned int g_ipAddress;
unsigned int g_broadcastAddress;
unsigned int g_subnetMask;
unsigned int g_routerAddress;

void IPv4Initialize()
{
	//We have no IP address initially
	g_ipAddress = 0;
	g_broadcastAddress = 0;
	g_subnetMask = 0;
	g_routerAddress = 0;
}

//Sample code from RFC1071
unsigned short InternetChecksum (int count, unsigned short * addr)
{
    unsigned long sum = 0;

    while (count > 1)
    {
        sum += *addr++;
        count -= 2;
    }
    if (count > 0)
        sum += * (unsigned char *) addr;
    while (sum >> 16)
        sum = (sum & 0xffff) + (sum >> 16);
    return (unsigned short)sum;
}

/**
	@brief Adds IPv4 headers to a packet
	
	@param frame			Pointer to the frame being assembled
	@param from_addr		Source IP address
	@param to_addr			Destination IP address
	@param payload_length	
 */
void IPv4AddHeaders(
	unsigned int* frame,
	unsigned int from_addr,
	unsigned int to_addr,
	unsigned int ip_protocol,
	unsigned int payload_length)
{
	unsigned int packet_bytesize = payload_length + 20;		//Add size of IP header
	
	frame[0] = 0x45000000 | packet_bytesize;				//IPv4, minimal length header, length
	frame[1] = 0x00004000;									//ID 0, no frag offset, don't fragment
	frame[2] = 0xFF000000 | (ip_protocol << 16);			//Hop count 255, header checksum not known yet
	frame[3] = from_addr;
	frame[4] = to_addr;
	
	//Compute IPv4 header checksum
	unsigned short header_checksum = ~InternetChecksum(20, (unsigned short*)(frame));
	frame[2] = (frame[2] & 0xFFFF0000) | header_checksum;
}

/**
	@brief Sends an IPv4 frame
	
	@param frame			Pointer to the frame being assembled
	@param from_addr		Source IP address
	@param to_addr			Destination IP address
	@param payload_length	Length of the packet body, in bytes
 */

void IPv4SendFrame(
	unsigned int* frame,
	unsigned int from_addr,
	unsigned int to_addr,
	unsigned int ip_protocol,
	unsigned int payload_length)
{
	//Add the headers
	IPv4AddHeaders(frame, from_addr, to_addr, ip_protocol, payload_length);
	
	//Size of the packet, in words (rounded up to nearest word)
	unsigned int packet_wordsize = (payload_length >> 2) + 5;
	if(payload_length & 0x3)
		packet_wordsize ++;
	
	//Default MAC address is broadcast
	unsigned short dest_mac[3];
	dest_mac[0] = 0xffff;
	dest_mac[1] = 0xffff;
	dest_mac[2] = 0xffff;

	//Send to router's MAC if not in our subnet
	if( (g_ipAddress != 0) &&
		( (to_addr & g_subnetMask) != (g_ipAddress & g_subnetMask) ) 
		)
	{
		if(!ARPLookupRecord(g_routerAddress, dest_mac))
		{
			//TODO: We don't know the MAC of our default gateway. This is a big problem but should only happen if
			//we had packet loss right after DHCP.
			//For now, drop the packet and send out another ARP probe.
			ARPSendProbeRequestTo(g_routerAddress);
			
			//BUGFIX: Free the frame
			EthernetFreeFrame(frame);			
			return;
		}
	}
	
	//Look up destination MAC address
	else if(!ARPLookupRecord(to_addr, dest_mac))
	{
		//Address not found
		//Send out an ARP probe so we can do unicast the next time around, but send this frame to the broadcast MAC to
		//avoid delays. Not quite RFC compliant but saves memory buffering the packet until we know the MAC.
		ARPSendProbeRequestTo(to_addr);
	}
	
	//Send it
	EthernetSendFrame(
		frame,
		dest_mac[0],
		(dest_mac[1] << 16) | (dest_mac[2]),
		ETHERTYPE_IPV4,
		packet_wordsize);
}

/**
	@brief Gets a pointer to the body of the frame (after headers)
 */
unsigned int* IPv4GetTxBodyPtr(unsigned int* frame)
{
	return frame+5;
}

/**
	Process a newly arrived IPv4 frame
	
	@param frame		Pointer to the frame
	@param frame_len	Frame length, in words
 */
void IPv4ProcessFrame(unsigned int* frame)
{
	//Verify the frame is actually IPv4; drop it if not 
	unsigned int ip_version = (frame[0] >> 28);
	if(ip_version != 4)
		return;
	
	//Drop fragmented packets (not implemented)
	if( (frame[1] & 0x00002000)	||		//more fragments
		(frame[1] & 0x00001FFF) )		//fragment offset
	{
		return;
	}
	
	//TODO: Verify header checksum and drop invalid packets
	
	//Read the other important headers
	unsigned int header_len = (frame[0] >> 24) & 0xF;
	unsigned int protocol = (frame[2] >> 16) & 0xFF;
	unsigned int srcip = frame[3];
	unsigned int dstip = frame[4];
	unsigned int* frame_body = frame + header_len;
	
	//Total length of the frame, in bytes
	unsigned int total_length = (frame[0] & 0xff);
	
	//Total length of the packet body
	unsigned int body_length = total_length - 4*header_len;
	
	//Ignore unicast packets not for our IP.
	//If we have no IP yet, accept all unicast packets
	if( (g_ipAddress != 0) &&
		(dstip != 0xffffffff) &&
		(dstip != g_ipAddress) )
	{
		return;
	}
	
	//Read the header and do stuff
	switch(protocol)
	{
		
	case IP_PROTOCOL_ICMP:
		ICMPv4ProcessPacket(frame_body, srcip, body_length);
		break;
		
	case IP_PROTOCOL_UDP:
		UDPv4ProcessPacket(frame_body, srcip);
		break;
		
	default:
		//Drop unknown protocols
		break;
	}
}
