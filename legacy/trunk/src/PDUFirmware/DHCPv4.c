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
	@brief Implementation of DHCPv4
 */

#include "PDUFirmware.h"

//debug only
#include <PDUPeripheralInterface_opcodes_constants.h>

enum
{
	DHCP_STATE_IDLE,			//Idle, not doing anything
	DHCP_STATE_LINK_UP_0,		//Link just came up, wait 1 timer tick before proceeding
	DHCP_STATE_LINK_UP_1,		//Link just came up, send discover next tick
	DHCP_STATE_WAIT_FOR_OFFER,	//DHCPDISCOVER sent, waiting for DHCPOFFER
	DHCP_STATE_WAIT_FOR_ACK,	//DHCPREQUEST sent, waiting for DHCPACK
	DHCP_STATE_BOUND			//Bound, valid IP
	
} g_dhcpState;

#define DHCP_XID				0xbaadc0de
#define DHCP_MAGIC_COOKIE		0x63825363

enum DHCP_OPTIONS
{
	DHCP_OPTION_PAD			= 0,
	DHCP_OPTION_SUBNET		= 1,
	DHCP_OPTION_ROUTER		= 3,
	DHCP_OPTION_HOSTNAME 	= 12,
	DHCP_OPTION_BCAST		= 28,
	DHCP_OPTION_TYPE		= 53,
	DHCP_OPTION_SERVER		= 54,
	DHCP_OPTION_END			= 255
};

unsigned int g_dhcpServerAddress;

char g_hostname[32];

/**
	@brief Initialize the DHCP protocol
 */
void DHCPInitialize()
{
	g_dhcpState = DHCP_STATE_IDLE;
	g_dhcpServerAddress = 0;
	strcpy(g_hostname, "pdu");
}

/**
	@brief Processes a packet from the DHCP server
 */
void DHCPProcessPacket(
	unsigned int* packet,
	unsigned int srcip,
	unsigned int srcport,
	unsigned short bytelen)
{
	//Bad packet (not from DHCP server)? Drop it
	if(srcport != DHCP_SERVER_PORT)
		return;
	
	//Get the opcode (should be a "boot reply")
	unsigned int opcode = packet[0] >> 24;
	if(opcode != 2)
		return;
	
	//If the XID doesn't match, drop if
	if(packet[1] != DHCP_XID)
		return;
	
	//Verify magic cookie
	if(packet[59] != DHCP_MAGIC_COOKIE)
		return;
		
	//Our IP address and subnet mask
	unsigned int our_ip = packet[4];
	unsigned int our_subnet = 0;
	
	//Router's IP address
	unsigned int router_ip = 0;
	
	//Broadcast IP address
	unsigned int bcast_addr = 0;
	
	//The DHCP message type
	unsigned char message_type = 0;
	
	//DHCP server's IP address
	//Default to SIADDR and overwrite if DHCP option is specified
	unsigned int dhcp_server_ip = packet[5];

	//Parse DHCP options
	unsigned char* options = (unsigned char*) (packet + 60);
	unsigned char* packet_end = ((unsigned char*)packet) + bytelen;
	while(options < packet_end)
	{
		//Parse option header
		unsigned char code = options[0];
		unsigned char len = options[1];
		unsigned char* body = options + 2;
		
		//Stop at end of options
		if(code == DHCP_OPTION_END)
			break;
			
		//Skip padding (not the normal format)
		if(code == DHCP_OPTION_PAD)
		{
			options ++;
			continue;
		}
		
		//Process it
		switch(code)
		{
		case DHCP_OPTION_SUBNET:
			our_subnet = (body[0] << 24) | (body[1] << 16) | (body[2] << 8) | body[3];
			break;
			
		case DHCP_OPTION_ROUTER:
			if(router_ip == 0)
				router_ip = (body[0] << 24) | (body[1] << 16) | (body[2] << 8) | body[3];
			//ignore additional routers if more than one is specified
			break;
			
		case DHCP_OPTION_HOSTNAME:
			if(len >= 32)		//clamp len to buffer size
				len = 31;
			for(unsigned char i=0; i<len; i++)
				g_hostname[i] = body[i];
			g_hostname[len] = 0;
			break;
			
		case DHCP_OPTION_TYPE:
			message_type = body[0];
			break;
			
		case DHCP_OPTION_BCAST:
			bcast_addr = (body[0] << 24) | (body[1] << 16) | (body[2] << 8) | body[3];
			break;
			
		case DHCP_OPTION_SERVER:
			dhcp_server_ip = (body[0] << 24) | (body[1] << 16) | (body[2] << 8) | body[3];
			break;
			
		//TODO: Renewal time
		
		//We don't care about DNS stuff as we never initiate contact with anything by hostname
		//so ignore those flags
		
		default:
			//ignore unrecognized options
			break;
		}
		
		//Skip this option and go on to the next
		options += (len + 2);
	}
		
	//Ignore CIADDR
	
	//State-dependent processing
	switch(g_dhcpState)
	{
	
	//Idle? We should not be getting DHCP packets; ignore it
	case DHCP_STATE_IDLE:
		break;
		
	//Expect a DHCPOFFER, drop anything else
	case DHCP_STATE_WAIT_FOR_OFFER:	
		
		//Not a DHCPOFFER, drop it
		if(message_type != 2)
			return;
			
		//TODO: if important settings are missing, figure out what to do
		 
		//Save IP address settings
		g_dhcpServerAddress = dhcp_server_ip;
		g_ipAddress = our_ip;
		g_subnetMask = our_subnet;
		g_broadcastAddress = bcast_addr;
		g_routerAddress = router_ip;
		
		//Immediately issue an ARP query for the router
		//TODO: handle packet loss
		ARPSendProbeRequestTo(router_ip);
		
		//TODO: Save broadcast address
		
		//Send a request to the server asking for the address officially
		DHCPSendRequest();
		break;
	
	case DHCP_STATE_WAIT_FOR_ACK:
		//Not a DHCPACK, drop it
		if(message_type != 5)
			break;

		//Make sure it's from the DHCP server
		if(srcip != g_dhcpServerAddress)
			break;
			
		//It's a valid ACK
		//Ignore the body, we got the address we asked for
		g_dhcpState = DHCP_STATE_BOUND;
	
		//Turn on the GPIO LEDs
		{
			RPCMessage_t rmsg;
			unsigned int leds = 0x2A0;
			RPCFunctionCall(g_periphAddr, PERIPH_GPIO_RDWR, 0x2AA, leds, 0, &rmsg);
		}
		
		break;
		
	case DHCP_STATE_BOUND:
		//Not expecting any DHCP messages, ignore them
		break;
		
	default:
		break;
	}
}

/**
	@brief Send a DHCPDISCOVER packet
 */
void DHCPSendDiscover()
{
	//Allocate the frame
	unsigned int* frame = EthernetAllocateFrame();
	if(!frame)
		return;	//out of memory
			
	unsigned int* body = UDPv4GetTxBodyPtr(frame);
		
	//DHCP stuff
	body[0] =	0x01010600;	//Op 1, htype 1, hlen 6, hops 0
	body[1] =	DHCP_XID;	//XID (TODO: random?)
	body[2] =	0x00000000;	//secs 0, flags 0
	body[3] = 0x00000000;	//CIADDR
	body[4] = 0x00000000;	//YIADDR
	body[5] = 0x00000000;	//SIADDR
	body[6] = 0x00000000;	//GIADDR
	body[7] = (g_mac[0] << 16) | g_mac[1];
	body[8] = g_mac[2] << 16;
	body[9] = 0x00000000;
	body[10] = 0x00000000;
	
	//48 words of padding
	for(int i=11; i<59; i++)
		body[i] = 0x00000000;
		
	//DHCP / BOOTP magic cookie
	body[59] = DHCP_MAGIC_COOKIE;
	
	//DHCP options
	body[60] = 0x350101ff;		//0x35 = DHCP message type, len 0x01, type 0x01 = DHCPDISCOVER
	
	//We're now waiting for an offer
	g_dhcpState = DHCP_STATE_WAIT_FOR_OFFER;
	
	//Send the frame
	UDPv4SendPacket(
		frame,
		0xffffffff,		//IPv4 broadcast
		DHCP_CLIENT_PORT,
		DHCP_SERVER_PORT,
		61*4			//packet size, in bytes
		);
}

/**
	@brief Sends a DHCPREQUEST
 */
void DHCPSendRequest()
{
	//We're now waiting for an ack
	g_dhcpState = DHCP_STATE_WAIT_FOR_ACK;
	
	//Allocate the frame
	unsigned int* frame = EthernetAllocateFrame();
	if(!frame)
		return;	//out of memory
		
	unsigned int* body = UDPv4GetTxBodyPtr(frame);
		
	//DHCP stuff
	body[0] =	0x01010600;	//Op 1, htype 1, hlen 6, hops 0
	body[1] =	DHCP_XID;	//XID (TODO: random?)
	body[2] =	0x00000000;	//secs 0, flags 0
	body[3] = g_ipAddress;	//CIADDR
	body[4] = 0x00000000;	//YIADDR
	body[5] = g_dhcpServerAddress;	//SIADDR
	body[6] = 0x00000000;	//GIADDR
	body[7] = (g_mac[0] << 16) | g_mac[1];
	body[8] = g_mac[2] << 16;
	body[9] = 0x00000000;
	body[10] = 0x00000000;
	
	//48 words of padding
	for(int i=11; i<59; i++)
		body[i] = 0x00000000;
		
	//DHCP / BOOTP magic cookie
	body[59] = DHCP_MAGIC_COOKIE;
	
	//DHCP options
	body[60] = 0x35010300;			//0x35 = DHCP message type, len 0x01, type 0x03 = DHCPREQUEST
									//plus 1 byte padding
	body[61] = 0x00003604;			//2 bytes padding, 0x36 = DHCP server address, len 0x04
	body[62] = g_dhcpServerAddress;	//Address of our chosen DHCP server
	body[63] = 0x00003204;			//2 bytes padding, 0x32 = requested IP, len 0x04
	body[64] = g_ipAddress;			//IP address we want
	body[65] = 0x000000ff;			//3 bytes padding, 0xFF = end
	
	//We're now waiting for an offer
	g_dhcpState = DHCP_STATE_WAIT_FOR_ACK;
	
	//Temporarily change our IP address to 0.0.0.0 for the source of this message
	unsigned int temp = g_ipAddress;
	g_ipAddress = 0;
	
	//Send the frame
	UDPv4SendPacket(
		frame,
		0xffffffff,		//IPv4 broadcast
		DHCP_CLIENT_PORT,
		DHCP_SERVER_PORT,
		66*4			//packet size, in bytes
		);
		
	//Restore our IP
	g_ipAddress = temp;
}

void DHCPOnLinkUp()
{
	g_dhcpState = DHCP_STATE_LINK_UP_0;
}

void DHCPOnLinkDown()
{
	g_dhcpState = DHCP_STATE_IDLE;
}

/**
	@brief Renewal timer
 */
void DHCPOnTimer()
{
	switch(g_dhcpState)
	{
		
	//TODO: Time out after N seconds if no packets
	case DHCP_STATE_LINK_UP_0:
		g_dhcpState = DHCP_STATE_LINK_UP_1;
		break;
	case DHCP_STATE_LINK_UP_1:
		DHCPSendDiscover();
		break;
	
	case DHCP_STATE_BOUND:
		//TODO: Check the timer and see if it's time to renew yet
		//TODO: If we've been in a "wait" state for too long, restart negotiation
		break;
		
	default:
		//Nothing to do
		break;
	}
}
