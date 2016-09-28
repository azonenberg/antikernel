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
	@brief Implementation of ARMDebugAccessPort
 */

#include "jtaghal.h"
#include "ARMDebugPort.h"
#include "ARMDebugAccessPort.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

ARMDebugAccessPort::ARMDebugAccessPort(ARMDebugPort* dp, uint8_t apnum, ARMDebugPortIDRegister id)
	: m_dp(dp)
	, m_apnum(apnum)
	, m_id(id)
{
	m_daptype = (dap_type)id.bits.type;
	
	//Sanity checks
	switch(id.bits.type)
	{
	case ARMDebugAccessPort::DAP_JTAG:
		if(id.bits.is_mem_ap)
		{
			throw JtagExceptionWrapper(
				"JTAG-AP cannot be a MEM-AP",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		break;
	
	case ARMDebugAccessPort::DAP_AHB:
		
		if(!id.bits.is_mem_ap)
		{
			throw JtagExceptionWrapper(
				"AHB bus must be a MEM-AP",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		break;
		
	case ARMDebugAccessPort::DAP_APB:
		
		if(!id.bits.is_mem_ap)
		{
			throw JtagExceptionWrapper(
				"APB bus must be a MEM-AP",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
		
		break;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown bus type",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
		break;
		}
}

ARMDebugAccessPort::~ARMDebugAccessPort()
{
	
}
