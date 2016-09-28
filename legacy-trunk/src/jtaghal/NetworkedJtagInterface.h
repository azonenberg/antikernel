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
	@file NetworkedJtagInterface.h
	@author Andrew D. Zonenberg
	@brief Declaration of NetworkedJtagInterface
 */
 
#ifndef NetworkedJtagInterface_h
#define NetworkedJtagInterface_h

#include "JtagInterface.h"
#include <math.h>

/**
	@brief Thin wrapper around TCP sockets for talking to a jtagd instance
	
	\ingroup libjtaghal
 */
class NetworkedJtagInterface
	: public JtagInterface
	, public GPIOInterface
{
public:
	NetworkedJtagInterface();
	virtual ~NetworkedJtagInterface();
	
	void Connect(const std::string& server, uint16_t port);

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
	
	//Socket wrappers (used server-side too)
	static int read_looped(int fd, unsigned char* buf, int count);
	static int write_looped(int fd, const unsigned char* buf, int count);
	static void SendString(int fd, std::string str);
	static void RecvString(int fd, std::string& str);
	
	//GPIO stuff
	virtual void ReadGpioState();
	virtual void WriteGpioState();
	bool IsGPIOCapable();
	
	//Explicit TMS shifting is no longer allowed, only state-level interface
private:
	virtual void ShiftTMS(bool tdi, const unsigned char* send_data, int count);
	
protected:
	
	/// Our socket
	Socket m_socket;
	
	virtual size_t GetShiftOpCount();
	virtual size_t GetRecoverableErrorCount();
	virtual size_t GetDataBitCount();
	virtual size_t GetModeBitCount();
	virtual size_t GetDummyClockCount();
	
	void BufferedSend(const unsigned char* buf, int count);
	void SendFlush();
	std::vector<unsigned char> m_sendbuf;
};

#endif
