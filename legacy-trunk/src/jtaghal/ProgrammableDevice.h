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
	@brief Declaration of ProgrammableDevice
 */

#ifndef ProgrammableDevice_h
#define ProgrammableDevice_h

#include <stdlib.h>

#include "ByteArrayFirmwareImage.h"

/**
	@brief Generic base class for all programmable devices (PLD, MCU, flash, etc)
	
	\ingroup libjtaghal
 */
class ProgrammableDevice
{
public:
	virtual ~ProgrammableDevice();

	/**
		@brief Determines if this device is programmed or blank.
		
		@return true if programmed, false if blank
	 */
	virtual bool IsProgrammed() =0;
	
	/** 
		@brief Wrapper for LoadFirmwareImage().
		
		Loads the file and passes it to LoadFirmwareImage()
		
		@throw JtagException if the file could not be opened or the image is invalid
		
		@param	fname		Name of the image to load
		@param	bVerbose	Do very verbose parsing
		@return	Pointer to an FirmwareImage object suitable for passing to Program().
	 */
	FirmwareImage* LoadFirmwareImage(std::string fname, bool bVerbose = false);
	
	/**
		@brief Parses an in-memory image of a firmware image into a format suitable for loading into the device
		
		@throw JtagException if the image is malformed
		
		@param data	Pointer to the start of the firmware image, including headers
		@param len	Length of the firmware image
		@param	bVerbose	Do very verbose parsing
		
		@return	Pointer to an FirmwareImage object suitable for passing to Configure().
	 */
	virtual FirmwareImage* LoadFirmwareImage(const unsigned char* data, size_t len, bool bVerbose) =0;
	
	/**
		@brief Erases the device configuration and restores the device to a blank state.
		
		After this function is called, regardless of success or failure, all existing connections to on-chip code become invalid.
		
		@throw JtagException if the erase operation fails
		
		@param bVerbose		Set to true for extra-verbose debug output
	 */
	virtual void Erase(bool bVerbose = false) =0;
	
	/**
		@brief Loads a new firmware image onto the device.
		
		After this function is called, regardless of success or failure, all existing connections to on-chip code become invalid.
		
		@throw JtagException if the erase operation fails
		
		@param image	The parsed image to load
	 */
	virtual void Program(FirmwareImage* image) =0;
	
	/**
		@brief Checks if we support indirect flash programming.
	 */
	virtual bool HasIndirectFlashSupport() =0;
	
	/**
		@brief Uses indirect flash programming to load a bitstream onto the target device
		
		Bus width indicates boot mode: 1-2-4 are SPI, 8-16 are BPI. Other values reserved.
	 */
	virtual void ProgramIndirect(
		ByteArrayFirmwareImage* image,
		int buswidth,
		bool reboot=true,
		unsigned int base_address = 0,
		std::string prog_image = "") =0;
};

#endif

