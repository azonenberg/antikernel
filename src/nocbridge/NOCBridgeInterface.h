/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Declaration of NOCBridgeInterface
 */
#ifndef NOCBridgeInterface_h
#define NOCBridgeInterface_h

/**
	@brief Abstract wrapper for a link to an Antikernel SoC
 */
class NOCBridgeInterface
{
public:
	virtual ~NOCBridgeInterface();

	/**
		@brief Sends an RPCMessage

		@throw JtagException if the send fails

		@param tx_msg	Message to send
	 */
	virtual void SendRPCMessage(const RPCMessage& tx_msg)=0;

	/**
		@brief Checks if any RPCMessage objects are ready to read and performs a read if so

		@throw JtagException if the read fails

		@param rx_msg	Message buffer to read into

		@return true if a message was received, false if no data was ready
	 */
	virtual bool RecvRPCMessage(RPCMessage& rx_msg) =0;

	//virtual bool RecvRPCMessageBlocking(RPCMessage& rx_msg) =0;
	//virtual bool RecvRPCMessageBlockingWithTimeout(RPCMessage& rx_msg, double timeout) =0;

	//TODO: blocking reads, timeouts, etc

	virtual bool AllocateClientAddress(uint16_t& addr) =0;
	virtual void FreeClientAddress(uint16_t addr) =0;
};

#endif
