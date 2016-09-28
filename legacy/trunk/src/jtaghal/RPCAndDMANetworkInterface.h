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
	@brief Declaration of RPCAndDMANetworkInterface
 */
#ifndef RPCAndDMANetworkInterface_h
#define RPCAndDMANetworkInterface_h

#include "RPCNetworkInterface.h"
#include "DMANetworkInterface.h"

#include <list>

/**
	@brief Abstract base class for all objects capable of sending and receiving both RPCMessage's and DMAMessage's
	
	WARNING: RecvRPCMessage() does not read from queues!
	
	\ingroup libjtaghal
 */
class RPCAndDMANetworkInterface : public RPCNetworkInterface
								, public DMANetworkInterface
{
public:
	virtual ~RPCAndDMANetworkInterface();
	
	/*
		RPC client functions
			Call function and block until return
	 */
	void RPCFunctionCallInternal(uint16_t addr, uint8_t callnum, const char* callname, uint32_t d0, uint32_t d1, uint32_t d2, RPCMessage& retval, float timeout=0.5);
	
	/*
		RPC server functions
			Nonblocking wait for function call
			Blocking wait for function call
			Return from function with status
	 */
	 
	/*
		Common RPC functions
			Send interrupt
			Nonblocking wait for interrupt
			Nonblocking wait for interrupt from host
			Blocking wait for interrupt
			Blocking wait for interrupt from host
	 */
	void WaitForInterruptFrom(uint16_t addr, RPCMessage& retval, float timeout = 0.5);
	 
	/*
		DMA functions
			Blocking write (wait for done / fail interrupt)
			Blocking read (wait for data / fail interrupt)
	 */
	void DMAWrite(uint16_t addr, uint32_t mem_addr, unsigned int len, uint32_t* data, uint8_t success_interrupt, uint8_t fail_interrupt);
	void DMARead(uint16_t addr, uint32_t mem_addr, unsigned int len, uint32_t* data, uint8_t fail_interrupt, float timeout = 0.5);
	
	///Push pending transmit data to the board and read stuff back, adding more dummy data if need be
		 
protected:
	std::list<RPCMessage> pending_function_calls;
	std::list<RPCMessage> pending_interrupts;
};

#define RPCFunctionCall(addr, callnum, d0, d1, d2, retval) \
	RPCFunctionCallInternal(addr, callnum, #callnum, d0, d1, d2, retval)
#define RPCFunctionCallWithTimeout(addr, callnum, d0, d1, d2, retval, timeout) \
	RPCFunctionCallInternal(addr, callnum, #callnum, d0, d1, d2, retval, timeout)

#endif

