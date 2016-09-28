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
	@brief Implementation of JtagInterface
 */

#include "jtaghal.h"
#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

/**
	@brief Default constructor
	
	Initializes the interface's mutex and creates an empty scan chain.
 */
JtagInterface::JtagInterface()
{
	m_devicecount = 0;
	
	m_perfShiftOps = 0;
	m_perfRecoverableErrs = 0;
	m_perfDataBits = 0;
	m_perfModeBits = 0;
	m_perfDummyClocks = 0;
	m_perfShiftTime = 0;
}

/**
	@brief Interface destructor
	
	Deletes the mutex and destroys all JtagDevice objects in the scan chain
 */
JtagInterface::~JtagInterface()
{
	//may not be equal to m_devicecount if we threw an exception during InitializeChain()
	//see bug #107
	for(size_t i=0; i<m_devices.size(); i++)
	{
		if(m_devices[i] != NULL)
			delete m_devices[i];
	}
}

/**
	@brief Creates a default JTAG interface on a best-effort basis.
	
	First, the JTAGD_HOST environment variable is checked. If it exists, and is a string of the form host:port, then
	a NetworkedJtagInterface is returned, connecting to that host:port.
	
	If it is not set, and there is at least one Digilent JTAG device present, a DigilentJtagInterface is returned,
	connecting to the first available interface.
	
	Future implementations will fall back to an FTDIJtagInterface, or other interfaces, if nothing is found at this
	point.
	
	If all attempts have failed, NULL is returned.
	
	@throw JtagException may be thrown by the constructor for a derived class if creation fails.
	
	@return The interface object, or NULL if no suitable interface could be found
 */
JtagInterface* JtagInterface::CreateDefaultInterface()
{
	//Check environment variable first
	char* jhost = getenv("JTAGD_HOST");
	if(jhost != NULL)
	{
		char host[1024];
		int port;
		if(2 == sscanf(jhost, "%1023[^:]:%5d", host, &port))
		{
			NetworkedJtagInterface* iface = new NetworkedJtagInterface;
			iface->Connect(host, port);
			return iface;
		}
	}
	
	#ifdef HAVE_DJTG
		//Create a DigilentJtagInterface on adapter 0 if we can find it
		int ndigilent = DigilentJtagInterface::GetInterfaceCount();
		if(ndigilent != 0)
			return new DigilentJtagInterface(0);
	#endif	//#ifdef HAVE_DJTG
	
	//TODO: Create FTDIJtagInterface
	
	//No interfaces found
	return NULL;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Low-level JTAG interface

// No code in this class, lives entirely in derived driver classes

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Mid-level JTAG interface

/**
	@brief Enters Test-Logic-Reset state by shifting six ones into TMS
	
	@throw JtagException if ShiftTMS() fails
 */
void JtagInterface::TestLogicReset()
{
	unsigned char all_ones = 0xff;
	ShiftTMS(false, &all_ones, 6);
}

/**
	@brief Resets the TAP and enters Run-Test-Idle state
	
	@throw JtagException if ShiftTMS() fails
 */
void JtagInterface::ResetToIdle()
{
	TestLogicReset();
	
	unsigned char zero = 0x00;
	ShiftTMS(false, &zero, 1);
}

/** 
	@brief Enters Shift-IR state from Run-Test-Idle state
	
	@throw JtagException if ShiftTMS() fails
 */
void JtagInterface::EnterShiftIR()
{
	//Shifted out LSB first:
	//1 - SELECT-DR-SCAN
	//1 - SELECT-IR-SCAN
	//0 - CAPTURE-IR
	//0 - SHIFT-IR
		
	unsigned char data = 0x03;
	ShiftTMS(false, &data, 4);
}

/** 
	@brief Leaves Exit1-IR state and returns to Run-Test-Idle
	
	@throw JtagException if ShiftTMS() fails
 */
void JtagInterface::LeaveExit1IR()
{
	//Shifted out LSB first:
	//1 - UPDATE-IR
	//0 - RUNTEST-IDLE
	
	unsigned char data = 0x1;
	ShiftTMS(false, &data, 2);
}
	
/** 
	@brief Enters Shift-DR state from Run-Test-Idle state
	
	@throw JtagException if ShiftTMS() fails
 */
void JtagInterface::EnterShiftDR()
{
	//Shifted out LSB first:
	//1 - SELECT-DR-SCAN
	//0 - CAPTURE-DR
	//0 - SHIFT-DR
	
	unsigned char data = 0x1;
	ShiftTMS(false, &data, 3);
}

/** 
	@brief Leaves Exit1-DR state and returns to Run-Test-Idle
	
	@throw JtagException if ShiftTMS() fails
 */
void JtagInterface::LeaveExit1DR()
{
	//Shifted out LSB first:
	//1 - UPDATE-IR
	//0 - RUNTEST-IDLE
	
	unsigned char data = 0x1;
	ShiftTMS(false, &data, 2);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// High-level JTAG interface

/**	
	@brief Initializes the scan chain and gets the number of devices present
	
	Assumes less than 1024 bits of total IR length.
	
	@throw JtagException if any of the scan operations fails.
 */
void JtagInterface::InitializeChain()
{	
	unsigned char lots_of_ones[128];
	memset(lots_of_ones, 0xff, sizeof(lots_of_ones));
	unsigned char lots_of_zeros[128];
	memset(lots_of_zeros, 0x00, sizeof(lots_of_zeros));
	unsigned char temp[128] = {0};
	
	//Reset the TAP to run-test-idle state
	ResetToIdle();
	
	//Flush the instruction registers with zero bits
	EnterShiftIR();
	ShiftData(false, lots_of_zeros, temp, 1024);
	if(0 != (temp[127] & 0x80))
	{
		throw JtagExceptionWrapper(
			"TDO is still 1 after 1024 clocks of TDI=0 in SHIFT-IR state, possible board fault",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	
	//Shift the BYPASS instruction into everyone's instruction register
	ShiftData(true, lots_of_ones, temp, 1024);
	if(0 == (temp[127] & 0x80))
	{
		throw JtagExceptionWrapper(
			"TDO is still 0 after 1024 clocks of TDI=1 in SHIFT-IR state, possible board fault",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	LeaveExit1IR();
	
	//Shift zeros into everyone's DR
	EnterShiftDR();
	ShiftData(false, lots_of_zeros, temp, 1024);
			
	//Sanity check that we got a zero bit back
	if(0 != (temp[127] & 0x80))
	{
		throw JtagExceptionWrapper(
			"TDO is still 1 after 1024 clocks in SHIFT-DR state, possible board fault",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	
	//Shift 1s into the DR one at a time and see when we get one back
	for(int i=0; i<1024; i++)
	{
		unsigned char one = 1;
		
		ShiftData(false, &one, temp, 1);
		if(temp[0] & 1)
		{
			m_devicecount = i;
			break;
		}
	}
	
	//printf("DEBUG: Got %d devices\n", (int)m_devicecount);
	
	//Now we know how many devices we have! Reset the TAP
	ResetToIdle();
	
	//Shift out the ID codes and reset the scan chain
	EnterShiftDR();
	for(size_t i=0; i<m_devicecount; i++)
	{
		unsigned int idcode;
		ShiftData(false, lots_of_zeros, (unsigned char*)&idcode, 32);
		m_idcodes.push_back(idcode);
		
		//printf("IDCODE = %08x\n", idcode);
		
		//ID code should always begin with a one
		//If we get a zero it's a bypass register
		//TODO: Support devices not implementing IDCODE
		if(!(idcode & 0x1))
		{
			throw JtagExceptionWrapper(
				"Devices without IDCODE are not supported",
				"",
				JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
		}
	}
	ResetToIdle();

	//Crack ID codes
	for(size_t i=0; i<m_devicecount; i++)
		m_devices.push_back(JtagDevice::CreateDevice(m_idcodes[i], this, i));
}

/** 
	@brief Returns the number of devices in the scan chain (only valid after InitializeChain() has been called)
	
	@return Device count
 */
size_t JtagInterface::GetDeviceCount()
{
	return m_devicecount;
}

/** 
	@brief Commits the outstanding transactions to the adapter.
	
	No-op unless the adapter supports queueing of multiple writes.
	
	@throw JtagException in case of error
 */
void JtagInterface::Commit()
{
	
}

/** 
	@brief Returns the ID for the supplied device (zero-based indexing)
	
	@throw JtagException if the index is out of range
	
	@param device Device index
	
	@return The 32-bit JTAG ID code
 */
unsigned int JtagInterface::GetIDCode(unsigned int device)
{
	if(device >= (unsigned int)m_devicecount)
	{
		throw JtagExceptionWrapper(
			"Device index out of range",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	return m_idcodes[device];
}

/**
	@brief Gets the Nth device in the chain.
	
	WARNING: If the device ID is unrecognized, this function will return NULL. It is the caller's responsibility
	to verify the pointer is non-NULL before using it.
	
	@throw JtagException if the index is out of range
	
	@param device Device index
	
	@return The device object
 */
JtagDevice* JtagInterface::GetDevice(unsigned int device)
{
	if(device >= (unsigned int)m_devicecount)
	{
		throw JtagExceptionWrapper(
			"Device index out of range",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	return m_devices[device];
}

/**
	@brief Sets the IR for a specific device in the chain.
	
	Starts and ends in Run-Test-Idle state.
	
	@throw JtagException if any shift operation fails.
	
	@param device	Zero-based index of the target device. All other devices are set to BYPASS mode.
	@param data		The IR value to scan (see ShiftData() for bit/byte ordering)
	@param count 	Instruction register length, in bits
 */
void JtagInterface::SetIR(unsigned int device, const unsigned char* data, int count)
{
	SetIRDeferred(device, data, count);
	Commit();
}

/**
	@brief Sets the IR for a specific device in the chain.
	
	Starts and ends in Run-Test-Idle state.
	
	@throw JtagException if any shift operation fails.
	
	@param device	Zero-based index of the target device. All other devices are set to BYPASS mode.
	@param data		The IR value to scan (see ShiftData() for bit/byte ordering)
	@param count 	Instruction register length, in bits
 */
void JtagInterface::SetIRDeferred(unsigned int /*device*/, const unsigned char* data, int count)
{
	if(m_devicecount != 1)
	{
		throw JtagExceptionWrapper(
			"Bypassing extra devices not yet supported!",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	
	EnterShiftIR();
	ShiftData(true, data, NULL, count);
	LeaveExit1IR();
}

/**
	@brief Sets the IR for a specific device in the chain and returns the IR capture value.
	
	Starts and ends in Run-Test-Idle state.
	
	@throw JtagException if any shift operation fails.
	
	@param device	Zero-based index of the target device. All other devices are set to BYPASS mode.
	@param data		The IR value to scan (see ShiftData() for bit/byte ordering)
	@param data_out	IR capture value
	@param count 	Instruction register length, in bits
 */
void JtagInterface::SetIR(unsigned int /*device*/, const unsigned char* data, unsigned char* data_out, int count)
{
	if(m_devicecount != 1)
	{
		throw JtagExceptionWrapper(
			"Bypassing extra devices not yet supported!",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	
	EnterShiftIR();
	ShiftData(true, data, data_out, count);
	LeaveExit1IR();
	
	Commit();
}

/**
	@brief Sets the DR for a specific device in the chain and optionally returns the previous DR contents.
	
	Starts and ends in Run-Test-Idle state.
	
	@throw JtagException if any shift operation fails.
	
	@param device		Zero-based index of the target device. All other devices are assumed to be in BYPASS mode and
						their DR is set to zero.
	@param send_data	The data value to scan (see ShiftData() for bit/byte ordering)
	@param rcv_data		Output data to scan, or NULL if no output is desired (faster)
	@param count 		Number of bits to scan
 */
void JtagInterface::ScanDR(unsigned int /*device*/, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	if(m_devicecount != 1)
	{
		throw JtagExceptionWrapper(
			"Bypassing extra devices not yet supported!",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
		
	EnterShiftDR();
	ShiftData(true, send_data, rcv_data, count);
	LeaveExit1DR();
	
	Commit();
}

/**
	@brief Sets the DR for a specific device in the chain and defers the operation if possible.
	
	The scan operation may not actually execute until Commit() is called. When the operation executes is dependent on
	whether the interface supports deferred writes, how full the interface's buffer is, and when the next operation
	forcing a commit (call to Commit() or a read operation) takes place.
	
	Starts and ends in Run-Test-Idle state.
	
	@throw JtagException if any shift operation fails.
	
	@param device		Zero-based index of the target device. All other devices are assumed to be in BYPASS mode and
						their DR is set to zero.
	@param send_data	The data value to scan (see ShiftData() for bit/byte ordering)
	@param count 		Number of bits to scan
 */
void JtagInterface::ScanDRDeferred(unsigned int /*device*/, const unsigned char* send_data, int count)
{
	if(m_devicecount != 1)
	{
		throw JtagExceptionWrapper(
			"Bypassing extra devices not yet supported!",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
		
	EnterShiftDR();
	ShiftData(true, send_data, NULL, count);
	LeaveExit1DR();
}

void JtagInterface::SendDummyClocksDeferred(int n)
{
	SendDummyClocks(n);
}

/**
	@brief Indicates if split (pipelined) DR scanning is supported.
	
	Split scanning allows the write halves of several scan operations to take place in one driver-level write call,
	followed by the read halves in order, to reduce the impact of driver/bus latency on throughput.
	
	If split scanning is not supported, ScanDRSplitWrite() will behave identically to ScanDR() and ScanDRSplitRead()
	will be a no-op.
 */
bool JtagInterface::IsSplitScanSupported()
{
	return false;
}

/**
	@brief Sets the DR for a specific device in the chain and optionally returns the previous DR contents.
	
	Starts and ends in Run-Test-Idle state.
	
	If split (pipelined) scanning is supported, this call performs the write half of the scan only; the read is
	performed by ScanDRSplitRead(). Several writes may occur in a row, and must be followed by an equivalent number of
	reads with matching length values.
	
	@throw JtagException if any shift operation fails.
	
	@param device		Zero-based index of the target device. All other devices are assumed to be in BYPASS mode and
						their DR is set to zero.
	@param send_data	The data value to scan (see ShiftData() for bit/byte ordering)
	@param rcv_data		Output data to scan, or NULL if no output is desired (faster)
	@param count 		Number of bits to scan
 */
void JtagInterface::ScanDRSplitWrite(unsigned int /*device*/, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	if(m_devicecount != 1)
	{
		throw JtagExceptionWrapper(
			"Bypassing extra devices not yet supported!",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
		
	EnterShiftDR();
	ShiftDataWriteOnly(true, send_data, rcv_data, count);
	LeaveExit1DR();
}

/**
	@brief Sets the DR for a specific device in the chain and optionally returns the previous DR contents.
	
	Starts and ends in Run-Test-Idle state.
	
	If split (pipelined) scanning is supported, this call performs the read half of the scan only/
	
	@throw JtagException if any shift operation fails.
	
	@param device		Zero-based index of the target device. All other devices are assumed to be in BYPASS mode and
						their DR is set to zero.
	@param rcv_data		Output data to scan, or NULL if no output is desired (faster)
	@param count 		Number of bits to scan
 */
void JtagInterface::ScanDRSplitRead(unsigned int /*device*/, unsigned char* rcv_data, int count)
{
	if(m_devicecount != 1)
	{
		throw JtagExceptionWrapper(
			"Bypassing extra devices not yet supported!",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	
	ShiftDataReadOnly(rcv_data, count);
}

bool JtagInterface::ShiftDataWriteOnly(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count)
{
	//default to ShiftData() in base class
	ShiftData(last_tms, send_data, rcv_data, count);
	return false;
}

bool JtagInterface::ShiftDataReadOnly(unsigned char* /*rcv_data*/, int /*count*/)
{
	//no-op in base class
	return false;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Performance profiling

/**
	@brief Gets the number of shift operations performed on this interface
	
	@throw JtagException on failure
	
	@return Number of shift operations
 */
size_t JtagInterface::GetShiftOpCount()
{
	return m_perfShiftOps;
}

/**
	@brief Gets the number of errors this interface has recovered from (USB retransmits, etc)
	
	@throw JtagException on failure
	
	@return Number of recoverable errors
 */
size_t JtagInterface::GetRecoverableErrorCount()
{
	return m_perfRecoverableErrs;
}

/**
	@brief Gets the number of data bits this interface has shifted
	
	@throw JtagException on failure
	
	@return Number of data bits shifted
 */
size_t JtagInterface::GetDataBitCount()
{
	return m_perfDataBits;
}

/**
	@brief Gets the number of mode bits this interface has shifted
	
	@throw JtagException on failure
	
	@return Number of mode bits shifted
 */
size_t JtagInterface::GetModeBitCount()
{
	return m_perfModeBits;
}

/**
	@brief Gets the number of dummy clocks this interface has sent
	
	@throw JtagException on failure
	
	@return Number of dummy clocks sent
 */
size_t JtagInterface::GetDummyClockCount()
{
	return m_perfDummyClocks;
}

/**
	@brief Gets the number of dummy clocks this interface has sent
	
	@throw JtagException on failure
	
	@return Number of dummy clocks sent
 */
double JtagInterface::GetShiftTime()
{
	return m_perfShiftTime;
}
