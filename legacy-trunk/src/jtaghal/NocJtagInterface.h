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
	@file NocJtagInterface.h
	@author Andrew D. Zonenberg
	@brief Declaration of NocJtagInterface
 */
 
#ifndef NocJtagInterface_h
#define NocJtagInterface_h

#include "JtagInterface.h"
#include <math.h>

#include "RPCAndDMANetworkInterface.h"

/**
	@brief jtaghal wrapper around the NetworkedJtagMaster core
	
	\ingroup libjtaghal
 */
class NocJtagInterface
	: public JtagInterface
	, public GPIOInterface
{
public:
	NocJtagInterface(RPCAndDMANetworkInterface& iface, std::string host);
	virtual ~NocJtagInterface();

	static std::string GetAPIVersion();
	static int GetInterfaceCount();

	//Setup stuff
	virtual std::string GetName();
	virtual std::string GetSerial();
	virtual std::string GetUserID();
	virtual int GetFrequency();
	
	//Low-level JTAG interface
	virtual void ShiftData(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count);	
	virtual void SendDummyClocks(int n);
	virtual void SendDummyClocksDeferred(int n);
	virtual void Commit();
	virtual bool IsSplitScanSupported();
	virtual bool ShiftDataWriteOnly(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count);
	virtual bool ShiftDataReadOnly(unsigned char* rcv_data, int count);
	
	//Mid level JTAG interface
	virtual void TestLogicReset();
	virtual void EnterShiftIR();
	virtual void LeaveExit1IR();
	virtual void EnterShiftDR();
	virtual void LeaveExit1DR();
	virtual void ResetToIdle();	
	
	//GPIO stuff
	virtual void ReadGpioState();
	virtual void WriteGpioState();
	bool IsGPIOCapable();
	
	//Explicit TMS shifting is no longer allowed, only state-level interface
private:
	virtual void ShiftTMS(bool tdi, const unsigned char* send_data, int count);
	
protected:
	
	RPCAndDMANetworkInterface&	m_iface;
	
	std::string		m_name;
	uint16_t		m_addr;

	//void BufferedSend(const unsigned char* buf, int count);
	void SendFlush();
	//std::vector<unsigned char> m_sendbuf;
};

#endif
