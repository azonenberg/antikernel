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
	@brief Implementation of Ethernet API
 */

#include "PDUFirmware.h"

#include <Ethertypes_constants.h>
#include <GraftonCPUPagePermissions_constants.h>
#include <NetworkedDDR2Controller_opcodes_constants.h>
#include <NetworkedEthernetMAC_opcodes_constants.h>
#include <NOCSysinfo_constants.h>
#include <PDUPeripheralInterface_opcodes_constants.h>

#define ETH_VADDR_BASE ((unsigned int*)0x40030800)

//Current layer-2 link state
unsigned int g_linkState;
unsigned int g_linkSpeed;

unsigned short g_mac[3];

unsigned int g_ethAddr;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Initialization

void EthernetInitialize()
{
	RPCMessage_t rmsg;

	//No link initially
	g_linkSpeed = 0;
	g_linkState = 0;
	
	//Look up the address of the NIC
	g_ethAddr = LookupHostByName("eth0");

	//Reset the Ethernet interface early since it takes a while to come up
	RPCFunctionCall(g_ethAddr, ETH_RESET, 0, 0, 0, &rmsg);
	
	//Generate a locally assigned MAC address based on the die serial number
	//02:serial number
	RPCFunctionCall(g_sysinfoAddr, SYSINFO_CHIP_SERIAL, 0, 0, 0, &rmsg);
	g_mac[0] = (0x02 << 8) | (rmsg.data[2] & 0xff);
	g_mac[1] = rmsg.data[1] >> 16;
	g_mac[2] = rmsg.data[1] & 0xffff;
	RPCFunctionCall(
		g_ethAddr,
		ETH_SET_MAC,
		g_mac[0],
		(g_mac[1] << 16) | g_mac[2],
		0,
		&rmsg);
	
	//Request ownership of several interesting ethertypes
	RPCFunctionCall(g_ethAddr, ETH_REGISTER_TYPE, ETHERTYPE_ARP, 0, 0, &rmsg);
	RPCFunctionCall(g_ethAddr, ETH_REGISTER_TYPE, ETHERTYPE_IPV4, 0, 0, &rmsg);
	
	//Initialize protocol handlers
	IPv4Initialize();
	DHCPInitialize();
	ARPInitialize();
	SNMPInitialize();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Transmit logic

/**
	@brief Allocates a new page of RAM for an Ethernet frame
	
	@return Valid virtual address, or NULL if out of memory
 */
unsigned int* EthernetAllocateFrame()
{
	//Allocate a new page of memory for the Ethernet frame
	RPCMessage_t rmsg;
	if(0 != RPCFunctionCall(g_ramAddr, RAM_ALLOCATE, 0, 0, 0, &rmsg))
		return NULL;
			
	//Memory map it
	unsigned int phyaddr = rmsg.data[1];
	unsigned int* vaddr = ETH_VADDR_BASE + phyaddr;
	MmapHelper(vaddr, phyaddr, g_ramAddr, PAGE_READ_WRITE);

	//Done, all is well
	return vaddr;
}

/**
	@brief Sends an Ethernet frame (blocking send for now)
	
	@param packet		Virtual base address of the packet (must have been allocated by EthernetAllocateFrame)
	@param dstmac_hi	Destination MAC address (high 16 bits)
	@param dstmac_lo	Destination MAC address (low 48 bits)
	@param ethertype	EtherType of the frame
	@param wordlen		Length of the frame, in 32-bit words
	
	@return 0 if successful
 */
int EthernetSendFrame(
	unsigned int* packet,
	unsigned short dstmac_hi,
	unsigned int dstmac_lo,
	unsigned short ethertype,
	int wordlen)
{
	//Pad frame out to 13 words to meet minimum Ethernet frame size requirement
	while(wordlen < 13)
		packet[wordlen++] = 0x00000000;
	
	//Flush the cache to commit pending writes to external RAM
	FlushDsideL1Cache(packet, wordlen*4);
	
	//Get the physical address of the page
	unsigned int phyaddr = packet - ETH_VADDR_BASE;
	
	//Set the MAC address
	RPCMessage_t rmsg;
	if(0 != RPCFunctionCall(
		g_ethAddr,
		ETH_SET_DSTMAC,
		dstmac_hi,
		dstmac_lo,
		0,
		&rmsg))
	{
		EthernetFreeFrame(packet);
		return -1;
	}
	
	//Chown the page to the MAC, then unmap it since we no longer own it
	if(0 != RPCFunctionCall(g_ramAddr, RAM_CHOWN, 0, phyaddr, g_ethAddr, &rmsg))
	{
		EthernetFreeFrame(packet);
		return -1;
	}
	MmapHelper(packet, 0, 0, PAGE_GUARD);
		
	//Send the frame
	//Possible memory leak if this fails. Wut do?
	if(0 != RPCFunctionCall(
		g_ethAddr,
		ETH_SEND_FRAME,
		g_ramAddr,
		phyaddr,
		wordlen | (ethertype << 16),
		&rmsg))
	{
		return -1;
	}

	return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Receive logic

/**
	@brief Process a newly arrived ethernet frame
 */
void EthernetProcessFrame(RPCMessage_t* frame_msg)
{	
	//Get the vital statistics
	//unsigned int frame_len = frame_msg->data[0];
	unsigned int phyaddr = frame_msg->data[1];
	unsigned int noc_addr = frame_msg->data[2] & 0xFFFF;
	unsigned int ethertype = frame_msg->data[2] >> 16;

	//Pick the virtual address
	unsigned int* frame = ETH_VADDR_BASE + phyaddr;

	//Flush the cache to prevent stale data from sticking around
	FlushDsideL1Cache(frame, 2048);

	//Map the frame into RAM
	MmapHelper(frame, phyaddr, noc_addr, PAGE_READ_WRITE);

	//See what protocol the frame is
	switch(ethertype)
	{
	case ETHERTYPE_IPV4:
		IPv4ProcessFrame(frame);
		break;
		
	case ETHERTYPE_ARP:
		ARPProcessFrame(frame);
		break;
	
	//Unrecognized protocol? Skip it
	//This should never happen since the MAC filters out ethertypes we don't use
	default:
		break;
	}

	//Flush the cache to prevent stale data from sticking around
	//FlushDsideL1Cache();
	
	EthernetFreeFrame(frame);
}

/**
	@brief Frees a frame
 */
void EthernetFreeFrame(unsigned int* frame)
{	
	RPCMessage_t rmsg;
	RPCFunctionCall(g_ramAddr, RAM_FREE, 0, (unsigned int)(frame - ETH_VADDR_BASE), 0, &rmsg);
	MmapHelper(frame, 0, 0, PAGE_GUARD);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Link state interrupts

void EthernetOnLinkUp()
{
	//Send the discover query
	DHCPOnLinkUp();
}

void EthernetOnLinkDown()
{
	//Update protocol handlers
	DHCPOnLinkDown();
	
	//Clear out our IP address
	g_ipAddress = 0;
	
	//Clear ARP table
	ARPInitialize();
}
