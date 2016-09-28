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
	@brief Implementation of CR2DevBoard
 */
#include "CR2DevBoard.h"

CR2DevBoard::CR2DevBoard(JtagInterface* iface)
: JtagBoard(iface)
{
}

/**
	@brief Sanity check that the board has the right chip on it, the JTAG adapter is working, etc
 */
void CR2DevBoard::InitializeBoard(bool bVerbose)
{
	JtagBoard::InitializeBoard(bVerbose);
	
	//Verify that the board is an CR2DevBoard
	//Should have a single XC2C32A (JTAG ID code 0x*6e1f093)
	JtagDevice* pdev = m_iface->GetDevice(0);
	if(pdev == NULL)
	{
		throw JtagExceptionWrapper(
			"Device 0 is NULL - invalid scan chain?",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	CPLD* pcpld = dynamic_cast<CPLD*>(pdev);
	if(pcpld == NULL)
	{
		throw JtagExceptionWrapper(
			"Device does not appear to be an CPLD",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	if( (pdev->GetIDCode() & 0x0FFFFFFF) != 0x6e1c093)
	{
		printf("The CR2DevBoard contains a Xilinx XC2C32A in VQG44 package. This board has a \"%s\" instead. "
				"Verify the correct board is connected.\n",
			pdev->GetDescription().c_str());
		throw JtagExceptionWrapper(
			"Not a CR2DevBoard",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	printf("Found %s\n", pdev->GetDescription().c_str());
}

