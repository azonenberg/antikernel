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
	@brief Implementation of ARP
 */

#include "PDUFirmware.h"

#include <Ethertypes_constants.h>

//Each entry in the ARP table is ~11 bytes
//32 entries is 352 bytes
//TODO: Timeouts
typedef struct ARPTableEntry
{
	unsigned char valid;		//always 0 or 1
	unsigned short mac[3];
	unsigned int ip;
} ARPTableEntry_t;

unsigned char g_nextArpSet;

//Hash table is 2-way set associative
//Entries 2a, 2a+1 map to IPs of the form 0xNN.0xNN.0xNN.0xNa
#define ARP_TABLE_SIZE 32
ARPTableEntry_t g_arpTable[ARP_TABLE_SIZE];

/**
	@brief Clears the ARP table
 */
void ARPInitialize()
{
	g_nextArpSet = 0;
	
	for(int i=0; i<ARP_TABLE_SIZE; i++)
		g_arpTable[i].valid = 0;
}

/**
	@brief Looks up the MAC address for a given IP address
	
	@return 1 if the address is in the cache, 0 if not
 */

/**
	@brief Processes an inbound ARP frame
 */
void ARPProcessFrame(unsigned int* frame)
{	
	//Hardware type should be Ethernet, discard anything else
	unsigned short htype = frame[0] >> 16;
	if(htype != 1)
		return;
		
	//Protocol type should be IPv4
	unsigned short ptype = frame[0] & 0xffff;
	if(ptype != ETHERTYPE_IPV4)
		return;
		
	//Expect (hwlen 6, plen 4) for IPv4 over ethernet
	unsigned short lens = frame[1] >> 16;
	if(lens != (0x0604))
		return;
		
	//Get the opcode (1=request, 2=reply)
	unsigned char opcode = frame[1] & 0xffff;
	
	//Parse the rest of the packet
	unsigned short sender_mac[3];
	sender_mac[0] = frame[2] >> 16;
	sender_mac[1] = frame[2] & 0xffff;
	sender_mac[2] = frame[3] >> 16;
	unsigned int sender_ip = ((frame[3] & 0xffff) << 16) | (frame[4] >> 16);
	/*
	unsigned short target_mac[3];
	target_mac[0] = frame[4] & 0xffff;
	target_mac[1] = frame[5] >> 16;
	target_mac[2] = frame[5] & 0xffff;
	*/
	unsigned int target_ip = frame[6];
	
	//TODO: do something with target MAC?
	
	//Update the ARP table with the sender address regardless of opcode
	if(sender_ip != 0)
		ARPAddRecord(sender_mac[0], sender_mac[1], sender_mac[2], sender_ip);
	
	//Inbound ARP request
	if(opcode == 1)
	{
		//They're asking for us! Send a response
		if(target_ip == g_ipAddress)
			ARPSendProbeResponseTo(sender_ip, sender_mac);	
		
		//If not, do nothing
	}
	
	//ARP reply
	//We already updated the table, no action required
	else
	{
	}
}

/**
	@brief Adds an ARP record for the requested MAC/IP combination
 */
void ARPAddRecord(unsigned short mac0, unsigned short mac1, unsigned short mac2, unsigned int ip)
{
	//Verify we do not already have an entry for this IP or MAC
	for(int i=0; i<ARP_TABLE_SIZE; i++)
	{
		if(!g_arpTable[i].valid)
			continue;
			
		unsigned char ip_match = (g_arpTable[i].ip == ip);
		unsigned char mac_match =	(g_arpTable[i].mac[0] == mac0) &&
									(g_arpTable[i].mac[1] == mac1) &&
									(g_arpTable[i].mac[2] == mac2) ;
		
		//Matching entry? Cache is up to date, we're done
		if(ip_match && mac_match)
			return;
		
		//If the IP is there with a different MAC, update it and stop
		if(ip_match && !mac_match)
		{
			g_arpTable[i].mac[0] = mac0;
			g_arpTable[i].mac[1] = mac1;
			g_arpTable[i].mac[2] = mac2;
			return;
		}
		
		//If the MAC is there with a different IP, null out the entry
		if(mac_match && !ip_match)
			g_arpTable[i].valid = 0;
	}
	
	//If we get here, it's not in the cache
	int row = ((ip & 0xf) << 1) | g_nextArpSet;
	g_arpTable[row].valid = 1;
	g_arpTable[row].ip = ip;
	g_arpTable[row].mac[0] = mac0;
	g_arpTable[row].mac[1] = mac1;
	g_arpTable[row].mac[2] = mac2;
	
	//Swap sets
	g_nextArpSet = !g_nextArpSet;
}

/**
	@brief Looks up an ARP record for the requested IP
	
	@return 1 if found, 0 if not found
 */
int ARPLookupRecord(unsigned int ip, unsigned short* mac)
{
	//Broadcase address = broadcast MAC
	if(ip == 0xffffffff)
	{
		for(int i=0; i<3; i++)
			mac[i] = 0xffff;
		return 1;
	}
	
	//Nope, actual lookup needed
	int base = (ip & 0xf) << 1;
	for(int row=base; row<base+2; row++)
	{
		if(!g_arpTable[row].valid)
			continue;
		if(g_arpTable[row].ip == ip)
		{
			for(int i=0; i<3; i++)
				mac[i] = g_arpTable[row].mac[i];
			return 1;
		}
	}
	return 0;
}

/**
	@brief Sends an ARP response to the given IP address
 */
void ARPSendProbeResponseTo(unsigned int ip, unsigned short* mac)
{
	//Allocate the frame
	unsigned int* frame = EthernetAllocateFrame();
	if(!frame)
		return;	//out of memory

	//Hardware type = Ethernet, protocol = IPv4
	frame[0] = 0x00010000 | ETHERTYPE_IPV4;
	
	//Lengths 6 and 4 respectively, opcode 2 (reply)
	frame[1] = 0x06040002;
	
	//MAC and IP addresses
	frame[2] = (g_mac[0] << 16) | g_mac[1];
	frame[3] = (g_mac[2] << 16) | (g_ipAddress >> 16);
	frame[4] = (g_ipAddress << 16) | mac[0];
	frame[5] = (mac[1] << 16) | mac[2];
	frame[6] = ip;
	
	//Send it
	EthernetSendFrame(
		frame,
		mac[0],
		(mac[1] << 16) | mac[2],
		ETHERTYPE_ARP,
		7);
}

/**
	@brief Sends an ARP probe request to the given IP address
 */
void ARPSendProbeRequestTo(unsigned int ip)
{
	//Allocate the frame
	unsigned int* frame = EthernetAllocateFrame();
	if(!frame)
		return;	//out of memory

	//Hardware type = Ethernet, protocol = IPv4
	frame[0] = 0x00010000 | ETHERTYPE_IPV4;
	
	//Lengths 6 and 4 respectively, opcode 1 (request)
	frame[1] = 0x06040001;
	
	//MAC and IP addresses
	frame[2] = (g_mac[0] << 16) | g_mac[1];					//Sender hardware/protocol addr
	frame[3] = (g_mac[2] << 16) | (g_ipAddress >> 16);
	frame[4] = (g_ipAddress << 16) | 0x00;					//target MAC high
	frame[5] = 0x00000000;									//target MAC low
	frame[6] = ip;											//target IP
	
	//Send it
	EthernetSendFrame(
		frame,
		0xffff,
		0xffffffff,
		ETHERTYPE_ARP,
		7);
}
