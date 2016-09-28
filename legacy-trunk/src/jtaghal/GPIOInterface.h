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
	@brief Declaration of GPIOInterface
 */

#ifndef GPIOInterface_h
#define GPIOInterface_h

#include <vector>

class GPIOInterface
{
public:
	virtual ~GPIOInterface();
	
	/**
		@brief Gets the number of GPIO pins on the device.
	 */
	int GetGpioCount()
	{
		return static_cast<int>(m_gpioValue.size());
	}
	
	/**
		@brief Reads all of the device's GPIO pins into the internal buffer.
	 */
	virtual void ReadGpioState() =0;
	
	/**
		@brief Writes all of the device's GPIO pin values to the device.
	 */
	virtual void WriteGpioState() =0;
	
	/**
		@brief Updates the direction of a GPIO pin but does not push the changes to the device
	 */
	void SetGpioDirectionDeferred(int pin, bool output)
	{
		m_gpioDirection[pin] = output;
	}
	
	/**
		@brief Updates the value of a GPIO pin but does not push the changes to the device
	 */
	void SetGpioValueDeferred(int pin, bool value)
	{
		m_gpioValue[pin] = value;
	}
	
	/**
		@brief Reads the cached value of a GPIO pin but does not poll the device
	 */
	bool GetGpioValueCached(int pin)
	{
		return m_gpioValue[pin];
	}
	
	/**
		@brief Updates the direction of a GPIO pin and pushes changes to the device immediately
	 */
	void SetGpioDirection(int pin, bool output)
	{
		SetGpioDirectionDeferred(pin, output);
		WriteGpioState();
	}
	
	/**
		@brief Updates the value of a GPIO pin and pushes changes to the device immediately
	 */
	void SetGpioValue(int pin, bool value)
	{
		SetGpioValueDeferred(pin, value);
		WriteGpioState();
	}
	
	/**
		@brief Reads the current value of a GPIO pin, polling the device
	 */
	bool GetGpioValue(int pin)
	{
		ReadGpioState();
		return GetGpioValueCached(pin);
	}
	
	/**
		@brief Reads the current direction of a GPIO pin
	 */
	bool GetGpioDirection(int pin)
	{
		return m_gpioDirection[pin];
	}
	
protected:

	///Value bits (1=high, contains the read value for inputs and the write value for outputs)
	std::vector<bool> m_gpioValue;
	
	///Direction bits (1=output)
	std::vector<bool> m_gpioDirection;
};

#endif
