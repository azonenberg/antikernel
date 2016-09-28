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
	@brief SFP test
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <memory.h>
#include <string>
#include <list>
#include <map>

#include "../../src/jtaghal/jtaghal.h"
#include "../../src/jtagboards/jtagboards.h"
#include <RPCv2Router_type_constants.h>
#include <RPCv2Router_ack_constants.h>
#include <NetworkedI2CTransceiver_opcodes_constants.h>
#include <NOCSysinfo_constants.h>

#include <Ethertypes_constants.h>
#include <IPProtocols_constants.h>
#include <ICMPv6_types_constants.h>

#include <IPv6OffloadEngine_opcodes_constants.h>

#include <signal.h>

using namespace std;

void DecodeEEPROM(unsigned char* eeprom);

int main(int argc, char* argv[])
{
	int err_code = 0;
	try
	{
		//Connect to the server
		string server;
		int port = 0;
		for(int i=1; i<argc; i++)
		{
			string s(argv[i]);
			
			if(s == "--port")
				port = atoi(argv[++i]);
			else if(s == "--server")
				server = argv[++i];
			else if(s == "--tty")
				++i;
			else
			{
				printf("Unrecognized command-line argument \"%s\", expected --server or --port\n", s.c_str());
				return 1;
			}
		}
		if( (server == "") || (port == 0) )
		{
			throw JtagExceptionWrapper(
				"No server or port name specified",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}		
		printf("Connecting to nocswitch server...\n");
		NOCSwitchInterface iface;
		iface.Connect(server, port);
		
		//Address lookup
		printf("Looking up addresses...\n");
		NameServer nameserver(&iface);
		uint16_t iaddr = nameserver.ForwardLookup("i2c");
		printf("    i2c is at %04x\n", iaddr);
		uint16_t saddr = nameserver.ForwardLookup("sysinfo");
		printf("    sysinfo is at %04x\n", saddr);
		uint16_t vaddr = nameserver.ForwardLookup("ipv6");
		printf("    ipv6 is at %04x\n", vaddr);
		
		//Set the clock divider
		printf("Requesting divider for I2C clock...\n");
		RPCMessage rxm;
		iface.RPCFunctionCall(saddr, SYSINFO_GET_CYCFREQ, 0, 100000, 0, rxm);
		printf("    clkdiv is %d\n", rxm.data[1]);
		iface.RPCFunctionCall(iaddr, I2C_SET_CLKDIV, rxm.data[1], 0, 0, rxm);
		
		//Set up the bus mux
		printf("Bux mux setup\n");
		uint8_t busmux_addr = 0x74;
		iface.RPCFunctionCall(iaddr, I2C_SEND_START, 0, 0, 0, rxm);
		iface.RPCFunctionCall(iaddr, I2C_SEND_BYTE, (busmux_addr << 1), 0, 0, rxm);
		iface.RPCFunctionCall(iaddr, I2C_SEND_BYTE, 0x10, 0, 0, rxm);		//select SFP+
		iface.RPCFunctionCall(iaddr, I2C_SEND_STOP, 0, 0, 0, rxm);
		
		//Read the SFP EEPROM
		unsigned char eeprom[256];
		printf("sfp eeprom read\n");
		uint8_t eeprom_addr = 0x50;
		iface.RPCFunctionCall(iaddr, I2C_SEND_START, 0, 0, 0, rxm);
		iface.RPCFunctionCall(iaddr, I2C_SEND_BYTE, (eeprom_addr << 1), 0, 0, rxm);
		iface.RPCFunctionCall(iaddr, I2C_SEND_BYTE, 0, 0, 0, rxm);
		iface.RPCFunctionCall(iaddr, I2C_SEND_RESTART, 0, 0, 0, rxm);
		iface.RPCFunctionCall(iaddr, I2C_SEND_BYTE, (eeprom_addr << 1) | 1, 0, 0, rxm);
		for(int i=0; i<256; i++)
		{
			iface.RPCFunctionCall(iaddr, I2C_RECV_BYTE, 1, 0, 0, rxm);
			eeprom[i] = rxm.data[0];
		}
		iface.RPCFunctionCall(iaddr, I2C_SEND_STOP, 0, 0, 0, rxm);
		DecodeEEPROM(eeprom);
	}
	
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		err_code = 1;
	}

	//Done
	return err_code;
}

void DecodeEEPROM(unsigned char* eeprom)
{
	//Transceiver type
	bool ok = true;
	switch(eeprom[0])
	{
	case 0:
		printf("Transceiver type: Unspecified\n");
		ok = false;
		break;
	
	case 1:
		printf("Transceiver type: GBIC\n");
		ok = false;
		break;
	
	case 2:
		printf("Transceiver type: Soldered to motherboard\n");
		ok = false;
		break;
		
	case 3:
		printf("Transceiver type: SFP\n");
		break;
		
	default:
		printf("Transceiver type: Invalid/reserved (%02x)\n", eeprom[0] & 0xff);
		ok = false;
		break;
		
	}
	if(eeprom[1] != 0x04)
	{
		printf("Bad extended identifier\n");
		ok = false;
	}
	
	//Connector
	switch(eeprom[2])
	{
	case 0:
		printf("Connector type:   Unspecified\n");
		ok = false;
		break;
		
	case 1:
		printf("Connector type:   SC\n");
		ok = false;
		break;
	
	case 2:
		printf("Connector type:   FC style 1 copper\n");
		ok = false;
		break;
		
	case 3:
		printf("Connector type:   FC style 2 copper\n");
		ok = false;
		break;
		
	case 4:
		printf("Connector type:   BNC/TNC\n");
		ok = false;
		break;
		
	case 5:
		printf("Connector type:   FC coax\n");
		ok = false;
		break;
		
	case 6:
		printf("Connector type:   FiberJack\n");
		ok = false;
		break;
		
	case 7:
		printf("Connector type:   LC\n");
		break;
		
	case 8:
		printf("Connector type:   MT-RJ\n");
		ok = false;
		break;
		
	case 9:
		printf("Connector type:   MU\n");
		ok = false;
		break;
		
	case 0x0a:
		printf("Connector type:   SG\n");
		ok = false;
		break;
		
	case 0x0b:
		printf("Connector type:   Optical pigtail\n");
		ok = false;
		break;
		
	case 0x20:
		printf("Connector type:   HSSDC II\n");
		ok = false;
		break;
		
	case 0x21:
		printf("Connector type:   Copper pigtail\n");
		ok = false;
		break;
		
	default:
		printf("Connector type:   Unknown (0x%02x)\n", eeprom[2] & 0xff);
		ok = false;
		break;
	}
	
	//3-10 is a 64-bit one-hot code
	uint32_t txvr_lo = eeprom[3] | (eeprom[4] << 8) | (eeprom[5] << 16) | (eeprom[6] << 24);
	uint32_t txvr_hi = eeprom[7] | (eeprom[8] << 8) | (eeprom[9] << 16) | (eeprom[10] << 24);
		
	if(txvr_lo & 0x01000000)
		printf("Transceiver type: 1000base-SX\n");
	else if(txvr_lo & 0x02000000)
		printf("Transceiver type: 1000base-LX\n");
	else if(txvr_lo & 0x04000000)
		printf("Transceiver type: 1000base-CX\n");
	else if(txvr_lo & 0x08000000)
		printf("Transceiver type: 1000base-T\n");
	else
	{
		printf("Transceiver type: Not supported (%08x %08x)\n", txvr_hi, txvr_lo);
		ok = false;
	}
		
	switch(eeprom[11])
	{
	case 0:
		printf("Encoding:         Unspecified\n");
		ok = false;
		break;
		
	case 1:
		printf("Encoding:         8b10b\n");
		break;
		
	case 2:
		printf("Encoding:         4b5b\n");
		ok = false;
		break;
		
	case 3:
		printf("Encoding:         NRZ\n");
		ok = false;
		break;
		
	case 4:
		printf("Encoding:         Manchester\n");
		ok = false;
		break;
		
	default:
		printf("Encoding:         Unknown (%02x)\n", eeprom[11] & 0xff);
		ok = false;
		break;
	}
	
	unsigned int bitrate = eeprom[12] * 100;
	printf("Bit rate:         %u Mbps\n", bitrate);
	
	if(eeprom[14])
		printf("Singlemode range: %u km\n", eeprom[14]);
	else
		printf("Singlemode range: not supported\n");
		
	if(eeprom[15] == 255)
		printf("Singlemode range: >25.4 km\n");
	else if(eeprom[15])
		printf("Singlemode range: %u m\n", eeprom[15]*100);
	else
		printf("Singlemode range: not supported\n");
		
	if(eeprom[16] == 255)
		printf("50/125 range:     >2.54 km\n");
	else if(eeprom[16])
		printf("50/125 range:     %u m\n", eeprom[16]*10);
	else
		printf("50/125 range:     not supported\n");
		
	if(eeprom[17] == 255)
		printf("62.5/125 range:   >2.54 km\n");
	else if(eeprom[17])
		printf("62.5/125 range:   %u m\n", eeprom[17]*10);
	else
		printf("62.5/125 range:   not supported\n");
		
	if(eeprom[18] == 255)
		printf("copper range:     >254 m\n");
	else if(eeprom[18])
		printf("copper range:     %u m\n", eeprom[18]);
	else
		printf("copper range:     not supported\n");
	
	//20-35 is SFP vendor name
	char vendor[17] = {0};
	memcpy(vendor, eeprom+20, 16);
	printf("Vendor name:      %s\n", vendor);
		
	printf("Vendor OUI:       %02x%02x%02x\n", eeprom[37] & 0xff, eeprom[38] & 0xff, eeprom[39] & 0xff);
	
	//40-55 is SFP vendor part number
	char part[17] = {0};
	memcpy(part, eeprom+40, 16);
	printf("Vendor part:      %s\n", part);
	
	//Revision number
	char rev[5] = {0};
	memcpy(rev, eeprom+56, 4);
	printf("Vendor rev:       %s\n", rev);
	
	//Checksum
	uint8_t checksum_expected = 0;
	for(int i=0; i<63; i++)
		checksum_expected += eeprom[i];
	printf("Checksum:         %02x (expected: %02x)\n", eeprom[63] & 0xff, checksum_expected & 0xff);
	if(checksum_expected != eeprom[63])
		ok = false;
		
	//Extended info
	printf("Options:          %02x%02x\n", eeprom[64] & 0xff, eeprom[65] & 0xff);
	printf("Bitrate margin:   +%d%% / -%d%%\n", eeprom[66] & 0xff, eeprom[67] & 0xff);
	
	//68-83 is serial number
	char serial[17] = {0};
	memcpy(serial, eeprom+68, 16);
	printf("Vendor serial:    %s\n", serial);
	
	//84-91 is date code
	char date[9] = {0};
	memcpy(date, eeprom+84, 8);
	printf("Vendor date:      %s\n", date);
	
	//Checksum
	checksum_expected = 0;
	for(int i=64; i<95; i++)
		checksum_expected += eeprom[i];
	printf("Option checksum:  %02x (expected: %02x)\n", eeprom[95] & 0xff, checksum_expected & 0xff);
	if(checksum_expected != eeprom[95])
		ok = false;
	
	if(!ok)
	{
		throw JtagExceptionWrapper(
			"Found bad data in SFDP",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);
	}
}
