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
	@brief Implementation of JtagBoard
 */
#include "JtagBoard.h"

JtagBoard::JtagBoard(JtagInterface* iface)
: m_iface(iface)
{
	if(iface == NULL)
	{
		throw JtagExceptionWrapper(
			"JTAG interface is null, cannot continue",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

JtagBoard::~JtagBoard()
{
	
}

/**
	@brief Sanity check that the board has the right chip on it, the JTAG adapter is working, etc
 */
void JtagBoard::InitializeBoard(bool bVerbose)
{
	//Get interface properties and print to stdout for debugging
	//(so we know which one was selected)
	if(bVerbose)
	{
		printf("Connected to interface \"%s\" (serial number \"%s\")\n",
			m_iface->GetName().c_str(), m_iface->GetSerial().c_str());
	}
	
	//Initialize the chain
	if(bVerbose)
		printf("Initializing chain...\n");
	m_iface->InitializeChain();
	
	//Get device count and see what we've found
	int ndev = m_iface->GetDeviceCount();
	if(bVerbose)
		printf("Scan chain contains %d devices\n", ndev);
	if(ndev == 0)
	{
		throw JtagExceptionWrapper(
			"No devices found - invalid scan chain?",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
}

/**
	@brief Gets the default device on the board
 */
JtagDevice* JtagBoard::GetDefaultDevice()
{
	return m_iface->GetDevice(0);
}
