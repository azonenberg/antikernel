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
	@brief Implementation of SNMP API
 */

#include "PDUFirmware.h"
#include "../asn1/BER.h"
#include <OutputStageController_opcodes_constants.h>

//List of all OIDs we implement (in increasing order)
//Prefix 1.3.6.1 (iso.org.dod.internet) is implicit to save memory
//First value in each row is the length of the OID in words
#define DRAWERSTEAK_PEN 42453
static const unsigned short g_oids[][7]=
{
	//Standard SNMP OIDs
	//mgmt.mib-2.system.X.0
	{5, 2, 1, 1, 1, 0},	//software version (constant string)
	{5, 2, 1, 1, 2, 0},	//OID describing this device
	{5, 2, 1, 1, 3, 0},	//Uptime
	{5, 2, 1, 1, 5, 0},	//Hostname (from DHCP)
	{5, 2, 1, 1, 7, 0},	//Services offered (0x48 = transport + application layer)

	//Custom PDU OIDs
	//private.enterprises.drawersteak
	//1 = device ID descriptors
	//2 = root of PDU
	
	//pdu.1 = temp sensors
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 1, 1},	//Temperature A
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 1, 2},	//Temperature B
	
	//pdu.2 = current readings
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 1},	//CH0 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 2},	//CH1 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 3},	//CH2 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 4},	//CH3 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 5},	//CH4 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 6},	//CH5 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 7},	//CH6 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 8},	//CH7 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 9},	//CH8 current
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 2, 10},	//CH9 current
	
	//pdu.3 = voltage readings
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 3, 1},	//Voltage A
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 3, 2},	//Voltage B
	
	//pdu.4 = power switches
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 1},	//CH0 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 2},	//CH1 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 3},	//CH2 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 4},	//CH3 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 5},	//CH4 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 6},	//CH5 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 7},	//CH6 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 8},	//CH7 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 9},	//CH8 power switch
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 4, 10},	//CH9 power switch
	
	//pdu.5 = current limits
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 1},	//CH0 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 2},	//CH1 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 3},	//CH2 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 4},	//CH3 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 5},	//CH4 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 6},	//CH5 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 7},	//CH6 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 8},	//CH7 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 9},	//CH8 current limit
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 5, 10},	//CH9 current limit
	
	//pdu.6 = inrush timers
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 1},	//CH0 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 2},	//CH1 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 3},	//CH2 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 4},	//CH3 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 5},	//CH4 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 6},	//CH5 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 7},	//CH6 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 8},	//CH7 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 9},	//CH8 inrush timer
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 6, 10},	//CH9 inrush timer
	
	//pdu.7 = nominal voltage
	{6, 4, 1, DRAWERSTEAK_PEN, 2, 7, 1}		//Nominal voltage
};

//Nice human-readable names for each OID we implement
enum oid_names
{
	OID_SOFTWARE_VERSION,
	OID_DEVICE_OID,
	OID_UPTIME,
	OID_HOSTNAME,
	OID_SERVICES,
	
	OID_TEMP0,
	OID_TEMP1,
	
	OID_CUR0,
	OID_CUR1,
	OID_CUR2,
	OID_CUR3,
	OID_CUR4,
	OID_CUR5,
	OID_CUR6,
	OID_CUR7,
	OID_CUR8,
	OID_CUR9,
	
	OID_VOLT0,
	OID_VOLT1,
	
	OID_PWR0,
	OID_PWR1,
	OID_PWR2,
	OID_PWR3,
	OID_PWR4,
	OID_PWR5,
	OID_PWR6,
	OID_PWR7,
	OID_PWR8,
	OID_PWR9,
	
	OID_LIMIT0,
	OID_LIMIT1,
	OID_LIMIT2,
	OID_LIMIT3,
	OID_LIMIT4,
	OID_LIMIT5,
	OID_LIMIT6,
	OID_LIMIT7,
	OID_LIMIT8,
	OID_LIMIT9,
	
	OID_INRUSH0,
	OID_INRUSH1,
	OID_INRUSH2,
	OID_INRUSH3,
	OID_INRUSH4,
	OID_INRUSH5,
	OID_INRUSH6,
	OID_INRUSH7,
	OID_INRUSH8,
	OID_INRUSH9,
	
	OID_VNOM
};

//TODO
static const char g_communityString[] = "public";

//Our device OID is private.enterprises.drawersteak.mibs.1
static const unsigned short g_deviceOid[] = {5, 4, 1, DRAWERSTEAK_PEN, 1, 1};

static const unsigned int g_oidListSize = sizeof(g_oids)/sizeof(g_oids[0]);
static const unsigned int g_oidListMax = (sizeof(g_oids)/sizeof(g_oids[0])) - 1;

/**
	@brief Initialize the SNMP subsystem
 */
void SNMPInitialize()
{
	//Nothing to do
}

/**
	@brief Handle an incoming SNMP packet
 */
void SNMPProcessPacket(unsigned int* packet, unsigned int srcip, unsigned int srcport, unsigned short bytelen)
{
	//Top level packet should be a sequence, drop anything else
	//Save the top level length to avoid running off the end
	unsigned char* bpacket = (unsigned char*) packet;
	unsigned int pos = 0;
	unsigned int type;
	unsigned int len;
	if(0 != BERDecodeChunkHeader(bpacket, &pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return;
	//TODO: Actually check length against bytelen etc
	//unsigned int top_len = len;	
	UNREFERENCED_PARAMETER(bytelen);
		
	//Read the SNMP version
	//Only support SNMP version 2c for now
	unsigned int snmp_version;
	if(0 != BERDecodeExpectedInteger(bpacket, &pos, &snmp_version))
		return;
	if(snmp_version != SNMP_VERSION_2C)
		return;
	
	//Read the community string
	if(0 != BERDecodeChunkHeader(bpacket, &pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_OCTET_STRING)
		return;
	char community[32];
	if(0 != BERDecodeString(bpacket, &pos, len, sizeof(community), (unsigned char*)community))
		return;
		
	//See if it's a match for the saved string
	//TODO: make this configurable
	if(strcmp(community, g_communityString) != 0)
	{
		//bad community string, drop it
		return;
	}
		
	//Next chunk is the SNMP PDU body
	//Everything else is inside it
	if(0 != BERDecodeChunkHeader(bpacket, &pos,	&type, &len))
		return;
	unsigned int pdu_type = type;
	
	//Every PDU (other than traps, which we don't support) has the same structure
	//Do generic processing up here to avoid duplicated code
	
	//Read the request ID and error code/index
	unsigned int request_id;
	unsigned int error_id;
	unsigned int error_index;
	if(0 != BERDecodeExpectedInteger(bpacket, &pos, &request_id))
		return;
	if(0 != BERDecodeExpectedInteger(bpacket, &pos, &error_id))
		return;
	if(0 != BERDecodeExpectedInteger(bpacket, &pos, &error_index))
		return;
	
	//Discard error code and index values, we just need to know how big they are
	
	//Next we should get a varbind list header (sequence)
	if(0 != BERDecodeChunkHeader(bpacket, &pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return;
		
	//From here on, we have a list of varbinds
	//These are type dependent so process them in the lower level handlers

	switch(pdu_type)
	{
	case ASN1_TYPE_SNMP_GETREQUEST:
		SNMPProcessGetOrGetNextRequest(bpacket, &pos, srcip, srcport, request_id, 0);
		break;
		
	case ASN1_TYPE_SNMP_GETNEXTREQUEST:
		SNMPProcessGetOrGetNextRequest(bpacket, &pos, srcip, srcport, request_id, 1);
		break;
		
	//GetResponse, Trap, GetBulkRequest is not supported
		
	case ASN1_TYPE_SNMP_SETREQUEST:
		SNMPProcessSetRequest(bpacket, &pos, srcip, srcport, request_id);
		break;
		
	default:
		//unknown, drop it
		break;
	}
}

/**
	@brief Processes a get or get-next request
 */
void SNMPProcessGetOrGetNextRequest(
	unsigned char* bpacket,
	unsigned int* pos,
	unsigned int srcip,
	unsigned int srcport,
	unsigned int request_id,
	unsigned char getnext)
{
	//Read the body of the packet
	//A GetRequest should contain a single varbind
	unsigned int type;
	unsigned int len;
	if(0 != BERDecodeChunkHeader(bpacket, pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return;
		
	//Next value should be an OID
	if(0 != BERDecodeChunkHeader(bpacket, pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_OID)
		return;

	//Decode the OID
	unsigned int oidbuf[24];
	unsigned int oidlen = sizeof(oidbuf)/sizeof(oidbuf[0]);
	if(0 != BERDecodeOID(bpacket, pos, len, &oidlen, oidbuf) )
		return;
		
	//We have the OID, figure out what tree entry it is
	unsigned int oidpos = 0;
	unsigned int status = SNMPFindOID(oidbuf, oidlen, &oidpos);
	
	//Look up which OID to process
	int index = oidpos;
	if(getnext)
	{
		//If we requested an entry before the first one, return the first one
		if(status == OID_SEARCH_TOO_LOW)
			index = 0;
		
		// If we ran off the end of the list, send an end-of-list alert
		else if( (status == OID_SEARCH_TOO_HIGH) || (oidpos == g_oidListMax) )
			index = -1;
			
		//Nope, just send the entry after the one that was asked for
		else
			index ++;
	}
	else if(status != OID_SEARCH_HIT)	//If we requested GET of an entry that doesn't exist, complain
		index = -2;

	//Send the actual response
	SNMPSendGetResponse(srcip, srcport, request_id, index);
}

/*
	@brief Finds an OID that we implement
	
	If the OID searched for is before the first OID in the table, zero (the first table entry) is stored in oidpos,
	and OID_SEARCH_TOO_LOW is returned.
	
	If the OID searched for is found as an exact match in the table, the index is stored in oidpos,
	and OID_SEARCH_HIT is returned.
	
	If the OID searched for is not found as an exact match, but is between the upper and lower limits of the table,
	the index of the largest OID *before* the requested OID is stored in oidpos, and OID_SEARCH_MISS is returned.
	
	If the OID searched for is after the last OID in the table, N (the last table entry) is stored in oidpos,
	and OID_SEARCH_TOO_HIGH is returned.
	
	@param oid		[in]	The OID to look up
	@param oidlen	[in]	Number of words in the OID
	@param oidpos	[out]	Position of the OID in the table
 */
unsigned int SNMPFindOID(unsigned int* oid, unsigned int oidlen, unsigned int* oidpos)
{	
	//If oidA is not in 1.3.6.1 (iso.org.dod.internet)
	//then return off-end as needed
	static const unsigned char internet_oid[4] = {1,3,6,1};
	for(unsigned int i=0; i<4; i++)
	{
		//After end? Stop
		if(oid[i] > internet_oid[i])
		{
			*oidpos = g_oidListMax;
			return OID_SEARCH_TOO_HIGH;
		}
		
		//Before beginning, or truncated? Stop
		else if( (oid[i] < internet_oid[i]) || (oidlen < i+1) )
		{
			*oidpos = 0;
			return OID_SEARCH_TOO_LOW;
		}
	}
	
	//If it's off one of the ends, stop
	unsigned int* suboid = oid+4;
	unsigned int sublen = oidlen-4;
	if(SNMPCompareOIDs(suboid, sublen, g_oids[0] + 1, g_oids[0][0]) < 0)
	{
		*oidpos = 0;
		return OID_SEARCH_TOO_LOW;
	}
	if(SNMPCompareOIDs(suboid, sublen, g_oids[g_oidListMax] + 1, g_oids[g_oidListMax][0]) > 0)
	{
		*oidpos = g_oidListMax;
		return OID_SEARCH_TOO_HIGH;
	}

	//OID is in the "internet" domain and between the end caps of the list
	//Do a simple linear search of the OID table for now since it's short
	for(unsigned int i=0; i<g_oidListSize; i++)
	{
		int comp = SNMPCompareOIDs(suboid, sublen, g_oids[i]+1, g_oids[i][0]);
		
		//Exact match? Got it!
		if(comp == 0)
		{
			*oidpos = i;
			return OID_SEARCH_HIT;
		}
		
		//If we're less than the test value, we passed the target. Return miss on the previous entry
		if(comp < 0)
		{
			*oidpos = i-1;
			return OID_SEARCH_MISS;
		}
		
		//If we're greater than the test value, try the next biggest one
	}
	
	//We should never get here! If we somehow do, return the end of the list
	*oidpos = g_oidListMax;
	return OID_SEARCH_TOO_HIGH;
}

/**
	@brief Compares two OIDs for searching.
	
	The 1.3.6.1 prefix should be omitted from oidA since it's implicit in the table.
	
	Note that the second OID is a table entry and is using unsigned shorts since no OID we support contains
	values more than 65535.

	@return 1 if oidA > oidB
			0 if oidA == oidB
			-1 if oidA < oidB
 */
int SNMPCompareOIDs(const unsigned int* oidA, unsigned int lenA, const unsigned short* oidB, unsigned int lenB)
{
	for(unsigned int i=0; ; i++)
	{
		//This digit mismatch? Return > or < as appropriate
		unsigned int a = oidA[i];
		unsigned int b = oidB[i];
		if(a > b)
			return 1;
		if(a < b)
			return -1;
			
		//This digit is a match. If one of the OIDs is truncated, handle that
		unsigned char eoa = (lenA == (i+1));
		unsigned char eob = (lenB == (i+1));
		if(eoa && !eob)
		{
			//B is a sub-node of A, A is less
			return -1;
		}
		if(eob && !eoa)
		{
			//A is a sub-node of B, A is greater
			return 1;
		}
		if(eoa && eob)
		{
			//Perfect match, equal
			return 0;
		}
	}
}

/**
	@brief Sends a SNMP GetResponse packet
 */
void SNMPSendGetResponse(
	unsigned int srcip,
	unsigned int srcport,
	unsigned int request_id,
	int oid_index
	)
{
	//Allocate the frame
	unsigned int* frame = EthernetAllocateFrame();
	if(!frame)
		return;	//out of memory
	unsigned char* body = (unsigned char*)UDPv4GetTxBodyPtr(frame);
	
	//Declare all of the index variables for lengths etc
	unsigned int packlen = 0;
	unsigned int packet_len_ptr;
	unsigned int varbind_list_len_ptr;
	unsigned int varbind_len_ptr;
	unsigned int body_len_ptr;
	
	//Look up the OID for the body
	const unsigned short* oid_entry;
	if(oid_index < 0)
		oid_entry = g_oids[g_oidListMax];
	else
		oid_entry = g_oids[oid_index];
	
	packlen = BEREncodeSequenceHeader(body, packlen, &packet_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Top-level sequence header
	packlen = BEREncodeInteger(body, packlen, SNMP_VERSION_2C);					//SNMP version 2c
	packlen = BEREncodeString(body, packlen, g_communityString);				//Community string
	packlen = BEREncodeSequenceHeader(body, packlen, &body_len_ptr,				//PDU packet header
		ASN1_TYPE_SNMP_GETRESPONSE);
	packlen = BEREncodeInteger(body, packlen, request_id);						//Request ID
	packlen = BEREncodeInteger(body, packlen, 0);								//Error code and index (always zero for now)
	packlen = BEREncodeInteger(body, packlen, 0);
	packlen = BEREncodeSequenceHeader(body, packlen, &varbind_list_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Varbind list
	packlen = BEREncodeSequenceHeader(body, packlen, &varbind_len_ptr,
		ASN1_TYPE_SEQUENCE_CONSTRUCTED);										//Single varbind
	packlen = BEREncodeOID(body, packlen, oid_entry);							//The OID of this value
	packlen = SNMPGenerateGetPacketBody(body, packlen, oid_index);				//The packet body
	BEREndSequence(body, packlen, varbind_len_ptr);								//Patch up length fields
	BEREndSequence(body, packlen, varbind_list_len_ptr);
	BEREndSequence(body, packlen, body_len_ptr);
	BEREndSequence(body, packlen, packet_len_ptr);
	
	//Done, send it!
	UDPv4SendPacket(
		frame,
		srcip,
		SNMP_AGENT_PORT,
		srcport,
		packlen
		);
}

/**
	@brief Generates the value of the GET request
 */
unsigned int SNMPGenerateGetPacketBody(
	unsigned char* message,
	unsigned int startpos,
	int oid_index
	)
{
	//If we hit the end of the MIB list, return that
	if(oid_index < 0)
	{
		if(oid_index == -2)
		{
			message[startpos++] = ASN1_TYPE_SNMP_NO_SUCH_OBJECT;
			message[startpos++] = 0;
		}
		else
		{
			message[startpos++] = ASN1_TYPE_SNMP_END_OF_MIB;
			message[startpos++] = 0;
		}
	}
	
	//Store the value
	else
	{
		switch(oid_index)
		{

		//Software version
		case OID_SOFTWARE_VERSION:
			startpos = BEREncodeString(message, startpos,
				"5V/12V managed power distribution unit (firmware compiled " __DATE__ " " __TIME__ ")\n"
				"\n"
				"License: 3-clause (\"new\" or \"modified\") BSD.\n"
				"This is open hardware: you are free to change, clone, or redistribute it.\n"
				"There is NO WARRANTY, to the extent permitted by law.\n"
				"\n"
				"PCB design files: http://tinyurl.com/azboard005\n"
				"Firmware source: TODO\n"
				"Firmware source: http://redmine.drawersteak.com/projects/achd-soc/repository/show/trunk/src/PDUFirmware"
				);
			break;
			
		//Device OID
		case OID_DEVICE_OID:
			startpos = BEREncodeOID(message, startpos, g_deviceOid);
			break;
			
		//Uptime in 1/100 second units
		case OID_UPTIME:
			startpos = BEREncodeInteger(message, startpos, g_uptime * 100 / TIMER_HZ);
			break;
			
		//Hostname from DHCP
		case OID_HOSTNAME:
			startpos = BEREncodeString(message, startpos, g_hostname);
			break;
			
		//Supported services
		case OID_SERVICES:
			startpos = BEREncodeInteger(message, startpos, 0x48);
			break;
		
		//Temperature sensors
		case OID_TEMP0:
		case OID_TEMP1:
			startpos = BEREncodeInteger(message, startpos, GetTemperature(oid_index - OID_TEMP0));
			break;
			
		//Current sensors
		case OID_CUR0:
		case OID_CUR1:
		case OID_CUR2:
		case OID_CUR3:
		case OID_CUR4:
		case OID_CUR5:
		case OID_CUR6:
		case OID_CUR7:
		case OID_CUR8:
		case OID_CUR9:
			startpos = BEREncodeInteger(message, startpos, GetCurrent(oid_index - OID_CUR0));
			break;
			
		//Voltage sensors
		case OID_VOLT0:
		case OID_VOLT1:
			startpos = BEREncodeInteger(message, startpos, GetVoltage(oid_index - OID_VOLT0));
			break;
			
		//Power switches
		case OID_PWR0:
		case OID_PWR1:
		case OID_PWR2:
		case OID_PWR3:
		case OID_PWR4:
		case OID_PWR5:
		case OID_PWR6:
		case OID_PWR7:
		case OID_PWR8:
		case OID_PWR9:
			startpos = BEREncodeInteger(message, startpos, OutputGetStatus(oid_index - OID_PWR0));
			break;
			
		//Current limits
		case OID_LIMIT0:
		case OID_LIMIT1:
		case OID_LIMIT2:
		case OID_LIMIT3:
		case OID_LIMIT4:
		case OID_LIMIT5:
		case OID_LIMIT6:
		case OID_LIMIT7:
		case OID_LIMIT8:
		case OID_LIMIT9:
			startpos = BEREncodeInteger(message, startpos, g_currentLimits[oid_index - OID_LIMIT0]);
			break;
			
		//Inrush timers
		case OID_INRUSH0:
		case OID_INRUSH1:
		case OID_INRUSH2:
		case OID_INRUSH3:
		case OID_INRUSH4:
		case OID_INRUSH5:
		case OID_INRUSH6:
		case OID_INRUSH7:
		case OID_INRUSH8:
		case OID_INRUSH9:
			startpos = BEREncodeInteger(message, startpos, g_inrushTimers[oid_index - OID_INRUSH0]);
			break;
		
		//Nominal voltage
		case OID_VNOM:
			startpos = BEREncodeInteger(message, startpos, g_vnom);
			break;
			
		default:
			startpos = BEREncodeInteger(message, startpos, 42);
			break;
		}
	}
	
	return startpos;
}

/**
	@brief Process a SNMP set request
 */
void SNMPProcessSetRequest(
	unsigned char* bpacket,
	unsigned int* pos,
	unsigned int srcip,
	unsigned int srcport,
	unsigned int request_id)
{
	//Read the body of the packet
	//A SetRequest should contain a single varbind
	unsigned int type;
	unsigned int len;
	if(0 != BERDecodeChunkHeader(bpacket, pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_SEQUENCE_CONSTRUCTED)
		return;
		
	//Next value should be an OID
	if(0 != BERDecodeChunkHeader(bpacket, pos,	&type, &len))
		return;
	if(type != ASN1_TYPE_OID)
		return;

	//Decode the OID
	unsigned int oidbuf[24];
	unsigned int oidlen = sizeof(oidbuf)/sizeof(oidbuf[0]);
	if(0 != BERDecodeOID(bpacket, pos, len, &oidlen, oidbuf) )
		return;
		
	//We have the OID, figure out what tree entry it is
	unsigned int oidpos = 0;
	unsigned int status = SNMPFindOID(oidbuf, oidlen, &oidpos);
	
	//Look up which OID to process
	int index = oidpos;
	if(status != OID_SEARCH_HIT)	//If we requested GET of an entry that doesn't exist, complain
	{
		SNMPSendGetResponse(srcip, srcport, request_id, -2);
		return;
	}
	
	//Parse the body (we only allow setting integer values so discard anything else)
	//TODO: Return proper error code in this case
	unsigned int new_value;
	if(0 != BERDecodeExpectedInteger(bpacket, pos, &new_value))
	{
		SNMPSendGetResponse(srcip, srcport, request_id, -2);
		return;
	}

	//See what OID was requested
	switch(oidpos)
	{

	//Power switches
	case OID_PWR0:
	case OID_PWR1:
	case OID_PWR2:
	case OID_PWR3:
	case OID_PWR4:
	case OID_PWR5:
	case OID_PWR6:
	case OID_PWR7:
	case OID_PWR8:
	case OID_PWR9:
		{
			RPCMessage_t rmsg;
			if(!g_vlockout)
				RPCFunctionCall(g_outputStageAddr, OUTSTAGE_POWER_STATE, (oidpos - OID_PWR0), new_value, 0, &rmsg);
			//if OVLO/UVLO do nothing
		}
		break;
	
	//Current limits
	case OID_LIMIT0:
	case OID_LIMIT1:
	case OID_LIMIT2:
	case OID_LIMIT3:
	case OID_LIMIT4:
	case OID_LIMIT5:
	case OID_LIMIT6:
	case OID_LIMIT7:
	case OID_LIMIT8:
	case OID_LIMIT9:
		OutputSetCurrentLimit((oidpos - OID_LIMIT0), new_value);
		break;
	
	//Inrush timers
	case OID_INRUSH0:
	case OID_INRUSH1:
	case OID_INRUSH2:
	case OID_INRUSH3:
	case OID_INRUSH4:
	case OID_INRUSH5:
	case OID_INRUSH6:
	case OID_INRUSH7:
	case OID_INRUSH8:
	case OID_INRUSH9:
		OutputSetInrushTime((oidpos - OID_INRUSH0), new_value);
		break;
		
	//If it's something else, it must be read-only because it exists and isn't read-write
	//TODO: Send proper error code in this case
	default:
		SNMPSendGetResponse(srcip, srcport, request_id, -2);
		return;
	
	};
	
	//Send the actual response with the new value
	SNMPSendGetResponse(srcip, srcport, request_id, index);
}
