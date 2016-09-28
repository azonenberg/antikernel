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
	@brief Declaration of DigilentJtagInterface
 */

#ifndef DigilentJtagInterface_h
#define DigilentJtagInterface_h

#include "JtagInterface.h"

#ifdef HAVE_DJTG

/**
	@brief A JTAG adapter exposed through the Digilent Adept SDK
	
	\ingroup libjtaghal
 */
class DigilentJtagInterface : public JtagInterface
{
public:
	DigilentJtagInterface(int ndev);
	virtual ~DigilentJtagInterface();

	static std::string GetAPIVersion();
	static int GetInterfaceCount();
	
	static std::string GetName(int i);
	static std::string GetSerial(int i);
	static std::string GetUserID(int i);
	static int GetDefaultFrequency(int i);
	
	//Setup stuff
	virtual std::string GetName();
	virtual std::string GetSerial();
	virtual std::string GetUserID();
	virtual int GetFrequency();
	
	//Low-level JTAG interface
	virtual void ShiftData(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count);	
	virtual void ShiftTMS(bool tdi, const unsigned char* send_data, int count);
	virtual void SendDummyClocks(int n);
	
protected:

	///@brief The adapter's name
	std::string m_name;
	
	///@brief The adapter's serial number
	std::string m_serial;
	
	///@brief The adapter's user ID
	std::string m_userid;
	
	static std::string GetLibraryError();
	
	///@brief Digilent API interface handle
	unsigned int m_hif;
	
	///@brief The adapter's clock frequency
	int m_freq;
};

#endif	//#ifdef HAVE_DJTG

#endif
