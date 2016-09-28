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
	@brief Implementation of MicrochipPIC32Device
 */

#include "jtaghal.h"
#include "MicrochipPIC32Device.h"
#include "XilinxCPLDBitstream.h"
#include "memory.h"

using namespace std;

//IDCODE, name, family, cpu, sram, flash, bootflash
static const MicrochipPIC32DeviceInfo g_devinfo[] =
{
	//MX1xx series
	{ MicrochipPIC32Device::PIC32MX110F016B, "PIC32MX110F016B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   4,  16,  3 },
	{ MicrochipPIC32Device::PIC32MX110F016C, "PIC32MX110F016C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   4,  16,  3 },
	{ MicrochipPIC32Device::PIC32MX110F016D, "PIC32MX110F016D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   4,  16,  3 },
	
	{ MicrochipPIC32Device::PIC32MX120F032B, "PIC32MX120F032B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   8,  32,  3 },
	{ MicrochipPIC32Device::PIC32MX120F032C, "PIC32MX120F032C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   8,  32,  3 },
	{ MicrochipPIC32Device::PIC32MX120F032D, "PIC32MX120F032D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   8,  32,  3 },
	
	{ MicrochipPIC32Device::PIC32MX130F064B, "PIC32MX130F064B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  16,  64,  3 },
	{ MicrochipPIC32Device::PIC32MX130F064C, "PIC32MX130F064C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  16,  64,  3 },
	{ MicrochipPIC32Device::PIC32MX130F064D, "PIC32MX130F064D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  16,  64,  3 },
	
	{ MicrochipPIC32Device::PIC32MX150F128B, "PIC32MX150F128B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  32, 128,  3 },
	{ MicrochipPIC32Device::PIC32MX150F128C, "PIC32MX150F128C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  32, 128,  3 },
	{ MicrochipPIC32Device::PIC32MX150F128D, "PIC32MX150F128D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  32, 128,  3 },
	
	//MX2xx series
	{ MicrochipPIC32Device::PIC32MX210F016B, "PIC32MX210F016B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   4,  16,  3 },
	{ MicrochipPIC32Device::PIC32MX210F016C, "PIC32MX210F016C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   4,  16,  3 },
	{ MicrochipPIC32Device::PIC32MX210F016D, "PIC32MX210F016D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   4,  16,  3 },
	
	{ MicrochipPIC32Device::PIC32MX220F032B, "PIC32MX220F032B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   8,  32,  3 },
	{ MicrochipPIC32Device::PIC32MX220F032C, "PIC32MX220F032C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   8,  32,  3 },
	{ MicrochipPIC32Device::PIC32MX220F032D, "PIC32MX220F032D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,   8,  32,  3 },
	
	{ MicrochipPIC32Device::PIC32MX230F064B, "PIC32MX230F064B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  16,  64,  3 },
	{ MicrochipPIC32Device::PIC32MX230F064C, "PIC32MX230F064C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  16,  64,  3 },
	{ MicrochipPIC32Device::PIC32MX230F064D, "PIC32MX230F064D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  16,  64,  3 },
	
	{ MicrochipPIC32Device::PIC32MX250F128B, "PIC32MX250F128B",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  32, 128,  3 },
	{ MicrochipPIC32Device::PIC32MX250F128C, "PIC32MX250F128C",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  32, 128,  3 },
	{ MicrochipPIC32Device::PIC32MX250F128D, "PIC32MX250F128D",
		MicrochipPIC32Device::FAMILY_MX12,  MicrochipPIC32Device::CPU_M4K,  32, 128,  3 },
	
	//MX3xx series
	{ MicrochipPIC32Device::PIC32MX330F064H, "PIC32MX330F064H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	{ MicrochipPIC32Device::PIC32MX330F064L, "PIC32MX330F064L",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	
	{ MicrochipPIC32Device::PIC32MX340F512H, "PIC32MX340F512H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  32, 512, 12 },
	
	{ MicrochipPIC32Device::PIC32MX350F128H, "PIC32MX350F128H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	//{ MicrochipPIC32Device::PIC32MX350F128L, "PIC32MX350F128L",
	//	MicrochipPIC32Device::FAMILY_MX34, MicrochipPIC32Device::CPU_M4K, 32, 128, 12 },
	
	{ MicrochipPIC32Device::PIC32MX350F256H, "PIC32MX350F256H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  64, 256, 12 },
	{ MicrochipPIC32Device::PIC32MX350F256L, "PIC32MX350F256L",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  64, 256, 12 },
	
	//MX4xx series
	{ MicrochipPIC32Device::PIC32MX430F064H, "PIC32MX430F064H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	{ MicrochipPIC32Device::PIC32MX430F064L, "PIC32MX430F064L",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	
	{ MicrochipPIC32Device::PIC32MX450F128H, "PIC32MX450F128H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	{ MicrochipPIC32Device::PIC32MX450F128L, "PIC32MX450F128L",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	
	{ MicrochipPIC32Device::PIC32MX450F256H, "PIC32MX450F256H",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  64, 256, 12 },
	{ MicrochipPIC32Device::PIC32MX450F256L, "PIC32MX450F256L",
		MicrochipPIC32Device::FAMILY_MX34,  MicrochipPIC32Device::CPU_M4K,  64, 256, 12 },
	
	//MX5xx series
	{ MicrochipPIC32Device::PIC32MX534F064H, "PIC32MX534F064H",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	//{ MicrochipPIC32Device::PIC32MX534F064L, "PIC32MX534F064L",
	//	MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K, 16,  64, 12 },
	
	{ MicrochipPIC32Device::PIC32MX564F064H, "PIC32MX564F064H",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	{ MicrochipPIC32Device::PIC32MX564F064L, "PIC32MX564F064L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  16,  64, 12 },
	
	{ MicrochipPIC32Device::PIC32MX564F128H, "PIC32MX564F128H",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	{ MicrochipPIC32Device::PIC32MX564F128L, "PIC32MX564F128L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	
	//MX6xx series
	{ MicrochipPIC32Device::PIC32MX664F064H, "PIC32MX664F064H",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32,  64, 12 },
	{ MicrochipPIC32Device::PIC32MX664F064L, "PIC32MX664F064L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32,  64, 12 },
	
	{ MicrochipPIC32Device::PIC32MX664F128H, "PIC32MX664F128H",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	{ MicrochipPIC32Device::PIC32MX664F128L, "PIC32MX664F128L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	
	{ MicrochipPIC32Device::PIC32MX695F512L, "PIC32MX695F512L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K, 128, 512, 12 },
	
	//MX7xx series
	{ MicrochipPIC32Device::PIC32MX764F128H, "PIC32MX764F128H",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	{ MicrochipPIC32Device::PIC32MX764F128L, "PIC32MX764F128L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K,  32, 128, 12 },
	
	{ MicrochipPIC32Device::PIC32MX795F512L, "PIC32MX795F512L",
		MicrochipPIC32Device::FAMILY_MX567, MicrochipPIC32Device::CPU_M4K, 128, 512, 12 },
};

MicrochipPIC32Device::MicrochipPIC32Device(
	unsigned int devid, unsigned int stepping,
	unsigned int idcode, JtagInterface* iface, size_t pos)
 : MicrochipMicrocontroller(idcode, iface, pos)
{
	m_devid = devid;
	m_stepping = stepping;
	m_irlength = 5;
	
	//Look up device info in the table and make sure it exists
	m_devinfo = NULL;
	for(auto& x : g_devinfo)
	{
		if(x.devid == devid)
			m_devinfo = &x;
	}

	if(!m_devinfo)
	{
		throw JtagExceptionWrapper(
			"Invalid PIC32MX JTAG IDCODE",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}	
}

/**
	@brief Destructor
 */
MicrochipPIC32Device::~MicrochipPIC32Device()
{
}

JtagDevice* MicrochipPIC32Device::CreateDevice(
	unsigned int devid, unsigned int stepping, unsigned int idcode, JtagInterface* iface, size_t pos)
{
	//TODO: Sanity checks
	return new MicrochipPIC32Device(devid, stepping, idcode, iface, pos);
}

std::string MicrochipPIC32Device::GetDescription()
{	
	char srev[256];
	snprintf(srev, sizeof(srev), "Microchip %s (%u KB SRAM, %u KB code flash, %u KB boot flash, stepping %u)",
		m_devinfo->name,
		m_devinfo->sram_size,
		m_devinfo->program_flash_size,
		m_devinfo->boot_flash_size,
		m_stepping);
		
	return string(srev);
}

bool MicrochipPIC32Device::HasRPCInterface()
{
	return false;
}

bool MicrochipPIC32Device::HasDMAInterface()
{
	return false;
}

bool MicrochipPIC32Device::IsProgrammed()
{
	EnterMtapMode();
	
	//MCHP_STATUS is a nop that just returns status in the capture value
	uint8_t status = SendMchpCommand(MCHP_STATUS);
	printf("Status = %02x\n", status);
	
	//Look up the MTAP status
	/*
	uint8_t zero = 0;
	uint8_t mtap_status = 0;
	//EJTAG_IDCODE
	*/
	
	throw JtagExceptionWrapper(
		"Not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

void MicrochipPIC32Device::Erase(bool /*bVerbose*/)
{
	throw JtagExceptionWrapper(
		"Not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

FirmwareImage* MicrochipPIC32Device::LoadFirmwareImage(const unsigned char* /*data*/, size_t /*len*/, bool /*bVerbose*/)
{
	throw JtagExceptionWrapper(
		"Not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

void MicrochipPIC32Device::Program(FirmwareImage* /*image*/)
{
	throw JtagExceptionWrapper(
		"Not implemented",
		"",
		JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// JTAG support stuff, mode switching, etc

void MicrochipPIC32Device::EnterMtapMode()
{
	SetIR(INST_MTAP_SW_MCHP);
}

/**
	@brief Sends a MTAP command. Requires TAP to be in MCHP mode, not EJTAG mode.
 */
uint8_t MicrochipPIC32Device::SendMchpCommand(uint8_t cmd)
{
	unsigned char capture;
	SetIR(INST_MTAP_COMMAND);
	ScanDR(&cmd, &capture, 8);
	return capture;
}

void MicrochipPIC32Device::EnterEjtagMode()
{
	SetIR(INST_MTAP_SW_EJTAG);
}
