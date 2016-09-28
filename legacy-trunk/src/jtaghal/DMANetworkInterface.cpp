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
	@brief Implementation of DMANetworkInterface
 */

#include "jtaghal.h"
#include "DMANetworkInterface.h"

/**
	@brief Default virtual destructor
 */
DMANetworkInterface::~DMANetworkInterface()
{
	//nothing to do
}

/**
	@brief Polls RecvDMAMessage() until a message comes back
	
	@throw JtagException if one of the read operations fails
	
	@param rx_msg	Message buffer to read into
 */
void DMANetworkInterface::RecvDMAMessageBlocking(DMAMessage& rx_msg)
{
	while(true)
	{
		if(RecvDMAMessage(rx_msg))
			return;
	}
}

/**
	@brief Polls RecvDMAMessage() until a message comes out or the specified timeout period elapses
	
	@throw JtagException if one of the read operations fails
	
	@param rx_msg	Message buffer to read into
	@param timeout	Timeout, in seconds
	
	@return True if a message was received, false in case of timeout.
 */
bool DMANetworkInterface::RecvDMAMessageBlockingWithTimeout(DMAMessage& rx_msg, double timeout)
{
	double tend = GetTime() + timeout;
	while(true)
	{
		if(RecvDMAMessage(rx_msg))
			return true;
		if(GetTime() > tend)
			return false;
	}
}

/**
	@brief Wrapper around RecvDMAMessageBlockingWithTimeout() that throws an exception if no message arrives.
 */
void DMANetworkInterface::RecvDMAMessageBlockingWithTimeoutAndErrorCheck(DMAMessage& rx_msg, double timeout)
{
	if(!RecvDMAMessageBlockingWithTimeout(rx_msg, timeout))
	{
		throw JtagExceptionWrapper(
			"Expected DMA response but got nothing",
			"",
			JtagException::EXCEPTION_TYPE_FIRMWARE);	
	}
}
