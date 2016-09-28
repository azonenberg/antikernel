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
	@brief Implementation of ARMDebugMemAccessPort
 */

#include "jtaghal.h"
#include "ARMAPBDevice.h"
#include "ARMCortexA9.h"
#include "ARMDebugPort.h"
#include "ARMDebugAccessPort.h"
#include "ARMDebugMemAccessPort.h"

static const char* g_cswLenNames[]=
{
	"byte",
	"halfword",
	"word"
};

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

ARMDebugMemAccessPort::ARMDebugMemAccessPort(ARMDebugPort* dp, uint8_t apnum, ARMDebugPortIDRegister id)
	: ARMDebugAccessPort(dp, apnum, id)
	, m_debugBusIsDedicated(false)
	, m_hasDebugRom(true)
{	
	if(m_daptype >= DAP_INVALID)
	{
		throw JtagExceptionWrapper(
			"Invalid DAP type",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	
	//If we're enabled, try to load the ROM (if any)
	ARMDebugMemAPControlStatusWord csw = GetStatusRegister();
	if(csw.bits.enable)
	{
		FindRootRomTable();
		if(m_hasDebugRom)
			LoadROMTable(m_debugBaseAddress);
	}
			
	//Looks like the AHB DAP for Zynq is used for main system memory access
	//and the APB DAP is used for CoreSight stuff
	//See UG585 page 718
}

ARMDebugMemAccessPort::~ARMDebugMemAccessPort()
{
	for(auto x : m_debugDevices)
		delete x;
	m_debugDevices.clear();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// General device info

bool ARMDebugMemAccessPort::IsEnabled()
{
	return GetStatusRegister().bits.enable;
}

void ARMDebugMemAccessPort::PrintStatusRegister()
{	
	ARMDebugMemAPControlStatusWord csw = GetStatusRegister();
	printf("    Status register for AP %u:\n", m_apnum);
	if(csw.bits.size >= ACCESS_INVALID)
		printf("        Size          : UNDEFINED\n");
	else
		printf("        Size          : %s\n", g_cswLenNames[csw.bits.size]);
	printf("        Auto inc      : %u\n", csw.bits.auto_increment);
	printf("        Enable        : %u\n", csw.bits.enable);
	printf("        Busy          : %u\n", csw.bits.busy);
	printf("        Mode          : %u\n", csw.bits.mode);
	printf("        Secure debug  : %u\n", csw.bits.secure_priv_debug);
	printf("        Bus protection: %u\n", csw.bits.bus_protect);
	printf("        Debug SW      : %u\n", csw.bits.debug_sw_enable);
}

string ARMDebugMemAccessPort::GetDescription()
{
	return "";
}

ARMDebugMemAPControlStatusWord ARMDebugMemAccessPort::GetStatusRegister()
{
	ARMDebugMemAPControlStatusWord csw;
	csw.word = m_dp->APRegisterRead(m_apnum, ARMDebugPort::REG_MEM_CSW);
	return csw;	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Memory access

uint32_t ARMDebugMemAccessPort::ReadWord(uint32_t addr)
{
	//Write the address
	m_dp->APRegisterWrite(m_apnum, ARMDebugPort::REG_MEM_TAR, addr);
	
	//Read the data back
	return m_dp->APRegisterRead(m_apnum, ARMDebugPort::REG_MEM_DRW);
}

void ARMDebugMemAccessPort::WriteWord(uint32_t /*addr*/, uint32_t /*value*/)
{
	throw JtagExceptionWrapper(
		"WriteWord() not yet implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Device enumeration

void ARMDebugMemAccessPort::FindRootRomTable()
{
	//Get the base address of the debug base
	uint32_t debug_base = m_dp->APRegisterRead(m_apnum, ARMDebugPort::REG_MEM_BASE);

	//If the debug base is 0xffffffff, then we can't do anything (no ROM)
	if(debug_base == 0xffffffff)
	{
		m_hasDebugRom = false;
		return;
	}

	//If bit 1 is set, then it's an ADIv5.1 address.
	//Mask off the low bits
	else if(debug_base & 2)
	{
		m_debugBaseAddress = debug_base & 0xfffff000;
		
		//If LSB not set, there's no ROM
		if(! (debug_base & 1) )
		{
			m_hasDebugRom = false;
			return;
		}
	}
	
	//Nope, it's a legacy address (no masking)
	else
		m_debugBaseAddress = debug_base;
}

void ARMDebugMemAccessPort::LoadROMTable(uint32_t baseAddress)
{
	//Read ROM table entries until we get to an invalid one
	for(int i=0; i<960; i++)
	{		
		//Read the next entry and stop if it's a terminator
		uint32_t entry = ReadWord(baseAddress + i*4);
		if(entry == 0)
			break;
		
		//If we hit 959 and it's not a terminator, something is wrong - should not be this many entries
		if(i == 959)
		{
			throw JtagExceptionWrapper(
				"Expected a terminator at end of ROM table, but none found",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
			
		//If it's not present, ignore it
		if(! (entry & 1) )
			continue;
			
		//If it's not a 32-bit entry fail (not yet implemented)
		if(! (entry & 2) )
		{
			throw JtagExceptionWrapper(
				"8-bit ROM tables not implemented",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//TODO: support this
		if(entry & 0x80000000)
		{
			throw JtagExceptionWrapper(
				"Negative offsets from ROM table not implemented",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		
		//Calculate the actual address of this node
		uint32_t offset = entry >> 12;
		uint32_t address = (offset << 12) | baseAddress;
		
		//Walk this table entry
		uint32_t compid_raw[4];
		for(int i=0; i<4; i++)
			compid_raw[i] = ReadWord(address + 0xff0 + 4*i);
		uint32_t compid =
			(compid_raw[3] << 24) |
			(compid_raw[2] << 16) |
			(compid_raw[1] << 8) |
			compid_raw[0];
			
		//Verify the mandatory component ID bits are in the right spots
		if( (compid & 0xffff0fff) != (0xb105000d) )
		{
			throw JtagExceptionWrapper(
				"Invalid ROM table ID (wrong preamble)",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
			
		//Figure out what it means
		unsigned int ccls = (compid >> 12) & 0xf;
		
		switch(ccls)
		{
			//Process CoreSight blocks
			case CLASS_CORESIGHT:
				ProcessDebugBlock(address);
				break;
				
			//Additional ROM table
			case CLASS_ROMTABLE:
				//printf("Found extra ROM table at 0x%08x, loading\n", address);
				LoadROMTable(address);
				break;
				
			//Don't know what to do with anything else
			default:
				printf("Found unknown component class 0x%x, skipping\n", ccls);
				throw JtagExceptionWrapper(
					"Unknown debug component class",
					"",
					JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
				break;
		}
	}
}

/**
	@brief Reads the ROM table for a debug block to figure out what's going on
 */
void ARMDebugMemAccessPort::ProcessDebugBlock(uint32_t base_address)
{
	//Read the rest of the ROM table header
	uint64_t periphid_raw[8];
	for(int i=0; i<4; i++)
		periphid_raw[i] = ReadWord(base_address + 0xfe0 + 4*i);
	for(int i=0; i<4; i++)
		periphid_raw[i+4] = ReadWord(base_address + 0xfd0 + 4*i);
	uint32_t memtype = ReadWord(base_address + 0xfcc);
	
	//See if the mem is dedicated or not
	m_debugBusIsDedicated = (memtype & 1) ? false : true;
	
	//Merge everything into a single peripheral ID register
	ARMDebugPeripheralIDRegister reg;
	reg.word =
		(periphid_raw[7] << 56) |
		(periphid_raw[6] << 48) |
		(periphid_raw[5] << 40) |
		(periphid_raw[4] << 32) |
		(periphid_raw[3] << 24) |
		(periphid_raw[2] << 16) |
		(periphid_raw[1] << 8)  |
		(periphid_raw[0] << 0);
	
	//TODO: handle legacy ASCII identity code
	if(!reg.bits.jep106_used)
	{
		throw JtagExceptionWrapper(
			"Bad ID in ROM (no JEP106 code)",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	
	//unsigned int blockcount = (1 << reg.bits.log_4k_blocks);
	//printf("Found debug component at %08x (rev/mod/step %u/%u/%u, %u 4KB pages)\n",
	//	base_address, reg.bits.revnum, reg.bits.cust_mod, reg.bits.revand, blockcount);
	
	//Check IDCODE for Xilinx
	if( (reg.bits.jep106_cont == 0x00) && (reg.bits.jep106_id == 0x49) )
	{

		//See if it's a FTM (Zynq)
		//See Xilinx UG585 page 729 table 28-5
		if(reg.bits.partnum == 0x001)
		{
			//printf("    Xilinx Fabric Trace Monitor\n");
		}
		
		//unknown, skip it
		else
			printf("    Unknown Xilinx device (part number 0x%x)\n", reg.bits.partnum);
		
	}
	
	//Check IDCODE for ARM
	else if( (reg.bits.jep106_cont == 0x04) && (reg.bits.jep106_id == 0x3b) )
	{
		switch(reg.bits.partnum)
		{
			case 0x906:
				//printf("    CoreSight Cross Trigger Interface\n");
				break;
			
			case 0x907:
				//printf("    CoreSight Embedded Trace Buffer\n");
				break;
			
			case 0x908:
				//printf("    CoreSight Trace Funnel\n");
				break;
								
			case 0x912:
				//printf("    CoreSight Trace Port Interface Unit\n");
				break;
			
			//ID is 913, not 914. CoreSight Components TRM is wrong.
			//See ARM #TAC650738
			case 0x913:
				//printf("    CoreSight Instrumentation Trace Macrocell\n");
				break;
				
			case 0x914:
				//printf("    CoreSight Serial Wire Output\n");
				break;
				
			case 0x950:
				//printf("    Cortex-A9 Program Trace Macrocell\n");
				break;
				
			case 0x9A0:
				//printf("    Cortex-A9 Performance Monitoring Unit\n");
				break;
				
			case 0xC09:
				{
					ARMCortexA9* cortex = new ARMCortexA9(this, base_address, reg.bits);
					m_dp->AddTarget(cortex);
					m_debugDevices.push_back(cortex);
				}
				break;
				
			default:
				printf("    Unknown ARM device (part number 0x%x)\n", reg.bits.partnum);
				break;
		}
	}
	
	//Check IDCODE for Switchcore (?)
	else if( (reg.bits.jep106_cont == 0x03) && (reg.bits.jep106_id == 0x09) )
	{
		//printf("    Unknown Switchcore device (part number 0x%x)\n", reg.bits.partnum);
	}
	
	//Unknown vendor
	else
	{
		printf("    Unknown device (JEP106 %u:%x, part number 0x%x)\n",
			reg.bits.jep106_cont, reg.bits.jep106_id, reg.bits.partnum);
	}
}
