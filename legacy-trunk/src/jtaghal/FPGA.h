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
	@brief Declaration of FPGA
 */

#ifndef FPGA_h
#define FPGA_h

#include "ProgrammableLogicDevice.h"
#include "RPCNetworkInterface.h"
#include "DMANetworkInterface.h"
#include "FPGABitstream.h"

/**
	@brief Generic base class for all field-programmable gate array devices
	
	\ingroup libjtaghal
 */
class FPGA : public ProgrammableLogicDevice
{
public:
	virtual ~FPGA();
	
	/**
		@brief Determines if this device has a unique per-die serial number.
		
		@return true if a serial number is present, false if not
	 */
	virtual bool HasSerialNumber() =0;
	
	/**
		@brief Gets the length of the FPGA's unique serial number, in bytes (rounded up to the nearest whole byte).
		
		The result of calling this function if HasSerialNumber() returns false is undefined.
		
		@return Serial number length
	 */
	virtual int GetSerialNumberLength() =0;
	
	/**
		@brief Gets the length of the FPGA's unique serial number, in bits.
		
		The result of calling this function if HasSerialNumber() returns false is undefined.
		
		@return Serial number length
	 */
	virtual int GetSerialNumberLengthBits() =0;
	
	/**
		@brief Gets the FPGA's unique serial number.
		
		The result of calling this function if HasSerialNumber() returns false is undefined.
		
		Note that some architectures, such as Spartan-6, cannot read the serial number over JTAG without erasing the 
		FPGA configuration. If this is the case, calling this function will automatically erase the FPGA.
		
		A future libjtaghal version may allow querying if this is the case.
		
		@throw JtagException if an error occurs during the read operation
		
		@param data Buffer to store the serial number into. Must be at least as large as the size given by
		GetSerialNumberLength().
	 */
	virtual void GetSerialNumber(unsigned char* data) =0;
	
	/**
		@brief Determines if this FPGA is currently loaded with a bitstream that exposes an RPC network interface.
		
		ProbeVirtualTAPs() must be called before this function is called or the behavior is undefined. If the FPGA is
		reconfigured, ProbeVirtualTAPs() must be called again to determine if the new bitstream exposes any NoC
		interfaces.
		
		@return true if RPC interface is available, false if not
	 */
	virtual bool HasRPCInterface() =0;
	
	/**
		@brief Determines if this FPGA is currently loaded with a bitstream that exposes a DMA network interface.
		
		ProbeVirtualTAPs() must be called before this function is called or the behavior is undefined. If the FPGA is
		reconfigured, ProbeVirtualTAPs() must be called again to determine if the new bitstream exposes any NoC
		interfaces.
		
		@return true if DMAinterface is available, false if not
	 */
	virtual bool HasDMAInterface() =0;
	
	/**
		@brief Gets the FPGA's RPC network interface.
		
		The behavior of this function if HasRPCInterface() returns false is undefined.
		
		@return Pointer to an RPCNetworkInterface object
	 */
	virtual RPCNetworkInterface* GetRPCNetworkInterface();
	
	/**
		@brief Gets the FPGA's DMA network interface.
		
		The behavior of this function if HasDMAInterface() returns false is undefined.
		
		@return Pointer to an DMANetworkInterface object
	 */
	virtual DMANetworkInterface* GetDMANetworkInterface();
	
	/**
		@brief Probes the FPGA for NoC interfaces.
		
		WARNING: The exact implementation of this function is implementation-defined but normally involves scanning 
		a user-defined data register. If the FPGA is currently loaded with a bitstream that uses the custom JTAG 
		registers for something other than a NoC interface (such as firmware updates) this may result in the design 
		receiving invalid input and malfunctioning with potentially catastrophic results.
		
		When connecting to a completely unknown board, if it is not known whether the user-defined instructions are
		in use, it may be advisable to avoid using this function.
		
		@throw JtagException if the scan operation fails
	 */
	virtual void ProbeVirtualTAPs() =0;
};

#endif
