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
	@brief Declaration of DebuggerInterface
 */

#ifndef DebuggerInterface_h
#define DebuggerInterface_h

#include <stdlib.h>

class DebuggableDevice;

/**
	@brief Generic base class for all debugger interfaces (may connect to multiple DebuggableDevice's)
	
	\ingroup libjtaghal
 */
class DebuggerInterface
{
public:
	virtual ~DebuggerInterface();
	
	///Returns the number of DebuggableDevice's attached to this debugger
	virtual size_t GetNumTargets();
	
	///Returns a specific DebuggableDevice
	virtual DebuggableDevice* GetTarget(size_t i); 
	
	///Adds a new debuggable device to this interface (called during topology discovery)
	void AddTarget(DebuggableDevice* target);
	
	///Read a single 32-bit word of memory (TODO support smaller sizes)
	virtual uint32_t ReadMemory(uint32_t address) =0;
	
	///Writes a single 32-bit word of memory (TODO support smaller sizes)
	virtual void WriteMemory(uint32_t address, uint32_t value) =0;
	
protected:
	
	///The devices (NOT automatically deleted at destruction time)
	std::vector<DebuggableDevice*> m_targets;
};

#endif

