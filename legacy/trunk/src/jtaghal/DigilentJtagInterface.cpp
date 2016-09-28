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
	@brief Implementation of DigilentJtagInterface
 */

#include "jtaghal.h"

#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <math.h>

#ifdef HAVE_DJTG

#include <digilent/adept/dpcdecl.h>
#include <digilent/adept/dpcdefs.h>
#include <digilent/adept/dpcutil.h>
#include <digilent/adept/djtg.h>
#include <digilent/adept/dmgr.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Device enumeration

/**	
	@brief Gets the version number of the Digilent JTAG API
 */
string DigilentJtagInterface::GetAPIVersion()
{
	char buf[cchVersionMax + 1] = {0};
	if(!DjtgGetVersion(buf))
	{
		throw JtagExceptionWrapper(
			"Failed to get Digilent API version",
			"",
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	return string(buf);
}

/** 
	@brief Gets the number of interfaces on the system
 */
int DigilentJtagInterface::GetInterfaceCount()
{
	int ndev;
	DmgrEnumDevices(&ndev);
	//TODO: need to DmgrFreeDvcEnum() at some point
	return ndev;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Connects to a Digilent JTAG interface
	
	@throw JtagException if the connection could not be establishes or the index is invalid
	
	@param ndev		Zero-based index of the device to connect to
 */
DigilentJtagInterface::DigilentJtagInterface(int ndev)
{
	DVC dvc;
	if(!DmgrGetDvc(ndev, &dvc))
	{
		throw JtagExceptionWrapper(
			"Failed to get Digilent device properties",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	m_name = dvc.szName;
	
	char serial[16] = {0};
	if(!DmgrGetInfo(&dvc, dinfoSN, serial))
	{
		throw JtagExceptionWrapper(
			"Failed to get device serial number",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	m_serial = serial;
	
	//TODO: Figure out how big this can be - not clear from docs.
	char userid[128] = {0};
	if(!DmgrGetInfo(&dvc, dinfoUsrName, userid))
	{
		throw JtagExceptionWrapper(
			"Failed to get device serial number",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	m_userid = userid;
	
	//Open the port after we got the info
	if(!DmgrOpen(&m_hif, dvc.szConn))
	{
		throw JtagExceptionWrapper(
			"Failed to connect to device",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	//Enable the port
	if(!DjtgEnable(m_hif))
	{
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Failed to enable port",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	//Verify we only have one port - >1 not supported now (TODO expose ports as separate interfaces?)
	INT32 pcount = 0;
	if(!DjtgGetPortCount(m_hif, &pcount))
	{
		DjtgDisable(m_hif);
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Failed to get device port count",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	if(pcount != 1)
	{
		DjtgDisable(m_hif);
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Devices with >1 port not supported",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	
	//Check required features
	DPRP portprops;
	if(!DjtgGetPortProperties(m_hif, 0, &portprops))
	{
		DjtgDisable(m_hif);
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Failed to get device port properties",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	/*
		TODO: See if any of these are needed
		const DPRP  dprpJtgSetSpeed         = 0x00000001; // port supports set speed call
		const DPRP  dprpJtgSetPinState      = 0x00000002; // device fully implements DjtgSetTmsTdiTck
		const DPRP  dprpJtgTransBuffering   = 0x00000004; // port supports transaction buffering
		const DPRP  dprpJtgWait             = 0x00000008; // port supports DjtgWait
		const DPRP  dprpJtgDelayCnt         = 0x00000010; // port supports DjtgSetDelayCnt and DjtgGetDelayCnt
		const DPRP  dprpJtgReadyCnt         = 0x00000020; // port supports DjtgSetReadyCnt and DjtgGetReadyCnt
		const DPRP  dprpJtgEscape           = 0x00000040; // port supports DjtgEscape
		const DPRP  dprpJtgMScan            = 0x00000080; // port supports the MScan format
		const DPRP  dprpJtgOScan0           = 0x00000100; // port supports the OScan0 format
		const DPRP  dprpJtgOScan1           = 0x00000200; // port supports the OScan1 format
		const DPRP  dprpJtgOScan2           = 0x00000400; // port supports the OScan2 format
		const DPRP  dprpJtgOScan3           = 0x00000800; // port supports the OScan3 format
		const DPRP  dprpJtgOScan4           = 0x00001000; // port supports the OScan4 format
		const DPRP  dprpJtgOScan5           = 0x00002000; // port supports the OScan5 format
		const DPRP  dprpJtgOScan6           = 0x00004000; // port supports the OScan6 format
		const DPRP  dprpJtgOScan7           = 0x00008000; // port supports the OScan7 format
		const DPRP  dprpJtgCheckPacket      = 0x00010000; // port supports DjtgCheckPacket
	 */
	DPRP required_portprops = dprpJtgSetPinState;
	if( (portprops & required_portprops) != required_portprops)
	{
		DjtgDisable(m_hif);
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Required properties missing",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	//Get the operating frequency
	DWORD freq;
	if(!DjtgGetSpeed(m_hif, &freq))
	{
		DjtgDisable(m_hif);
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Failed to get clock rate",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	m_freq = freq;
	
	//Set the timeout to much longer (60 seconds)
	//so we can configure larger devices
	if(!DmgrSetTransTimeout(m_hif, 1000 * 60))
	{
		DjtgDisable(m_hif);
		DmgrClose(m_hif);	//fixes #116, open handles cannot be allowed to survive to program quit or we segfault
		throw JtagExceptionWrapper(
			"Failed to set timeout",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
}

/**
	@brief Interface destructor
	
	Closes handles and disconnects from the adapter.
 */
DigilentJtagInterface::~DigilentJtagInterface()
{
	DjtgDisable(m_hif);
	DmgrClose(m_hif);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Adapter information

std::string DigilentJtagInterface::GetName()
{
	return m_name;
}

std::string DigilentJtagInterface::GetSerial()
{
	return m_serial;
}

std::string DigilentJtagInterface::GetUserID()
{
	return m_userid;
}

int DigilentJtagInterface::GetFrequency()
{
	return m_freq;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Error handling

/**
	@brief Gets the last-error code of the Digilent API
 */
string DigilentJtagInterface::GetLibraryError()
{
	char serc[cchErcMax + 1];
	char smsg[cchErcMsgMax + 1];
	DmgrSzFromErc(DmgrGetLastError(), serc, smsg);
	return string(smsg);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Low-level JTAG interface

void DigilentJtagInterface::ShiftData(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	double start = GetTime();
	
	m_perfShiftOps ++;
	m_perfDataBits += count;
	
	//Add TMS values
	int bytecount = ceil(count / 4.0f);						//TODO: optimize this? Slow
	unsigned char* data = new unsigned char[bytecount];
	for(int i=0; i<count; i++)
	{
		PokeBit(data, 2*i, PeekBit(send_data, i));
		if(i != (count-1))
			PokeBit(data, 2*i + 1, false);
		else
			PokeBit(data, 2*i + 1, last_tms);
	}
		
	if(!DjtgPutTmsTdiBits(m_hif, data, rcv_data, count, false))
	{
		throw JtagExceptionWrapper(
			"Failed to shift data",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	/*
	if(rcv_data != NULL)
	{
		printf("    ShiftData done!\n        ");
		for(int i=0; i<ceil(count/8.0f); i++)
		{
			printf("%02x ", rcv_data[i]);
			if( (i & 0xF) == 0xF)
				printf("\n        ");
		}
		printf("\n");
	}*/
	
	delete[] data;
	
	m_perfShiftTime += GetTime() - start;
}

void DigilentJtagInterface::ShiftTMS(bool tdi, const unsigned char* send_data, int count)
{
	double start = GetTime();
	
	m_perfShiftOps ++;
	m_perfModeBits += count;
	
	//Digilent API is brain-dead and does not make send_data const
	//so we have to copy it :(
	int bytecount = ceil(count / 8.0f);						//TODO: optimize this? Slow
	unsigned char* send_data_copy = new unsigned char[bytecount];
	memcpy(send_data_copy, send_data, bytecount);
	
	if(!DjtgPutTmsBits(m_hif, tdi, send_data_copy, NULL, count, false))
	{
		throw JtagExceptionWrapper(
			"Failed to shift TMS",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	delete[] send_data_copy;
	
	m_perfShiftTime += GetTime() - start;
}

void DigilentJtagInterface::SendDummyClocks(int n)
{
	double start = GetTime();
	
	m_perfShiftOps ++;
	m_perfDummyClocks += n;
	
	if(!DjtgClockTck(m_hif, 0, 0, n, 0))
	{
		throw JtagExceptionWrapper(
			"Failed to send dummy clocks",
			GetLibraryError(),
			JtagException::EXCEPTION_TYPE_ADAPTER);
	}
	
	m_perfShiftTime += GetTime() - start;
}

#endif	//#ifdef HAVE_DJTG
