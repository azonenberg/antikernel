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
	@brief Declaration of JtagInterface
 */

#ifndef JtagInterface_h
#define JtagInterface_h

#include <string>
#include <vector>

#include "JtagDevice.h"

/**
	@brief Abstract representation of a JTAG adapter.
	
	A JTAG adapter interfaces the PC to a single scan chain containing zero or more JTAG devices.
	
	To add support for a new JTAG adapter, create a new class derived from JtagInterface and implement the following
	functions:
		\li GetName()
		\li GetSerial()
		\li GetUserID()
		\li GetFrequency()
		\li ShiftData()
		\li ShiftTMS()
		\li SendDummyClocks()
	
	\ingroup libjtaghal
 */
class JtagInterface
{
public:
	JtagInterface();
	virtual ~JtagInterface();
	
	static JtagInterface* CreateDefaultInterface();
	
	//GetInterfaceCount() is a strongly recommended static member function for each derived class

	//Setup stuff
public:

	/**
		@brief Gets the manufacturer-assigned name for this programming adapter.
		
		This is usually the model number but is sometimes something more generic like "Digilent Adept USB Device".
		
		@return The device name
	 */
	virtual std::string GetName() =0;
	
	/**
		@brief Gets the manufacturer-assigned serial number for this programming adapter, if any.
		
		Derived classes may choose to return the user ID, an empty string, or another default value if no serial number
		has been assigned.
		
		@return The serial number
	 */
	virtual std::string GetSerial() =0;
	
	/**
		@brief Gets the user-assigned name for this JTAG adapter, if any.
		
		Derived classes may choose to return the serial number, an empty string, or another default value if no name
		has been assigned.
		
		@return The name for this adapter.
	 */
	virtual std::string GetUserID() =0;
	
	/** 
		@brief Gets the clock frequency, in Hz, of the JTAG interface
		
		@return The clock frequency
	 */
	virtual int GetFrequency() =0;
	
	virtual void Commit();
	
	//Low-level JTAG interface (wire level)
public:
	/**
		@brief Shifts data through TDI to TDO.
		
		The LSB of send_data[0] is sent first; the MSB of send_data[0] is followed by the LSB of send_data[1].
		
		@param last_tms		Different TMS value to use for last bit
		@param send_data	Data to shift into TDI
		@param rcv_data		Data to shift out of TDO (may be NULL)
		@param count		Number of bits to shift
	 */
	virtual void ShiftData(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count) =0;
	
	/** 
		@brief Sends the requested number of dummy clocks with TMS=0 and flushes the command to the interface.
		
		@throw JtagException may be thrown if the scan operation fails
		
		@param n			 Number of dummy clocks to send
	 */
	virtual void SendDummyClocks(int n) =0;
	
	/** 
		@brief Sends the requested number of dummy clocks with TMS=0 and does not flush the write pipeline.
		
		@throw JtagException may be thrown if the scan operation fails
		
		@param n			 Number of dummy clocks to send
	 */
	virtual void SendDummyClocksDeferred(int n);
	
protected:
	/**
		@brief Shifts data into TMS to change TAP state
			
		This is no longer a public API operation. It can only be accessed via the state-level interface.
		
		Implementations of this class may choose to implement EITHER this function (and use the default
		JtagInterface-provided state-level functions) OR override this function with a private no-op stub
		and override the state-level functions instead.
			
		@throw JtagException may be thrown if the scan operation fails
		
		@param tdi			Constant tdi value (normally 0)
		@param send_data	Data to shift into TMS. Bit ordering is the same as for ShiftData().
		@param count		Number of bits to shift
	 */
	virtual void ShiftTMS(bool tdi, const unsigned char* send_data, int count) =0;
	
	//High-performance pipelined scan interface (wire level)
public:
	/**
		@brief Shifts data through TDI to TDO.
		
		The LSB of send_data[0] is sent first; the MSB of send_data[0] is followed by the LSB of send_data[1].
		
		If split (pipelined) scanning is supported by the adapter, this function performs the write half of the shift 
		operation only; the read is buffered in the JTAG adapter and no readback is performed until ShiftDataReadOnly()
		is called. This allows several shift operations to occur in sequence without incurring a USB turnaround delay
		or other driver latency overhead for each shift operation. 
		
		If split scanning is not supported this call is equivalent to ShiftData() and ShiftDataReadOnly() is a no-op.
		
		This function MUST be followed by either another ShiftDataWriteOnly() call, a ShiftTMS() call, or a
		ShiftDataReadOnly() call. There must be exactly one ShiftDataReadOnly() call for each ShiftDataWriteOnly()
		call and they must be in order with the same rcv_data and count values. The result of doing otherwise is
		undefined.
		
		@return True if the read was deferred, false if not
		
		@param last_tms		Different TMS value to use for last bit
		@param send_data	Data to shift into TDI
		@param rcv_data		Data to shift out of TDO (may be NULL)
		@param count		Number of bits to shift
	 */
	virtual bool ShiftDataWriteOnly(bool last_tms, const unsigned char* send_data, unsigned char* rcv_data, int count);
	
	/**
		@brief Reads data from a ShiftDataWriteOnly() call.
		
		For more information on split (pipelined) scan operations see ShiftDataWriteOnly().
		
		@return True if the read was executed, false if a no-op
		
		@param rcv_data		Data to shift out of TDO (may be NULL)
		@param count		Number of bits to shift
	 */
	virtual bool ShiftDataReadOnly(unsigned char* rcv_data, int count);
	
	//Mid-level JTAG interface (state level)
public:
	virtual void TestLogicReset();
	virtual void EnterShiftIR();
	virtual void LeaveExit1IR();
	virtual void EnterShiftDR();
	virtual void LeaveExit1DR();
public:
	virtual void ResetToIdle();		//TODO: Make this protected as well? Not likely to be needed for anything in well-written code
	
	//High-level JTAG interface (register level)
	void InitializeChain();
	size_t GetDeviceCount();
	unsigned int GetIDCode(unsigned int device);
	JtagDevice* GetDevice(unsigned int device);
	void SetIR(unsigned int device, const unsigned char* data, int count);
	void SetIRDeferred(unsigned int device, const unsigned char* data, int count);
	void SetIR(unsigned int device, const unsigned char* data, unsigned char* data_out, int count);
	void ScanDR(unsigned int device, const unsigned char* send_data, unsigned char* rcv_data, int count);
	void ScanDRDeferred(unsigned int device, const unsigned char* send_data, int count);
	virtual bool IsSplitScanSupported();
	void ScanDRSplitWrite(unsigned int device, const unsigned char* send_data, unsigned char* rcv_data, int count);
	void ScanDRSplitRead(unsigned int device, unsigned char* rcv_data, int count);
	
protected:
	
	///@brief Number of devices in the scan chain
	size_t m_devicecount;
	
	///@brief Array of device ID codes
	std::vector<unsigned int> m_idcodes;
	
	///@brief Array of devices
	std::vector<JtagDevice*> m_devices;
	
	//Performance profiling
protected:
	///Number of shift operations performed on this interface
	size_t m_perfShiftOps;
	
	///Number of link errors successfully recovered from
	size_t m_perfRecoverableErrs;
	
	///Number of data bits shifted
	size_t m_perfDataBits;
	
	///Number of mode bits shifted
	size_t m_perfModeBits;
	
	///Number of dummy clocks shifted
	size_t m_perfDummyClocks;
	
	///Total time spent on shift operations
	double m_perfShiftTime;
	
public:
	virtual size_t GetShiftOpCount();
	virtual size_t GetRecoverableErrorCount();
	virtual size_t GetDataBitCount();
	virtual size_t GetModeBitCount();
	virtual size_t GetDummyClockCount();
	
	virtual double GetShiftTime();
};

#endif
