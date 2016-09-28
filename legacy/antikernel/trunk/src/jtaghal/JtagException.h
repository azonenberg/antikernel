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
	@brief Declaration of JtagException
 */
#ifndef JtagException_h
#define JtagException_h

#include <string>

/**
	@brief Base class for all exceptions thrown by libjtaghal
	
	\ingroup libjtaghal
 */
class JtagException
{
public:
	
	//All changes to this enum require updating the string table in JtagException::GetDescription()!
	enum ExceptionTypes
	{
		/**
			JTAG adapter hardware failure.<br/>
			The JTAG adapter, or its driver, failed to perform an operation.
		 */
		EXCEPTION_TYPE_ADAPTER,
		
		/**
			Target board fault.<br/>
			The target board is malfunctioning
		 */
		EXCEPTION_TYPE_BOARD_FAULT,
		
		/**
			Garbage in, garbage out.<br/>
			An invalid parameter was passed (device index greater than device count, etc)
		 */
		EXCEPTION_TYPE_GIGO,
		
		/**
			Unimplemented functionality used<br/>
			The calling code requested functionality which is planned for the future but not yet implemented.
		 */
		EXCEPTION_TYPE_UNIMPLEMENTED,
		
		/**
			Network communication failure<br/>
			A socket was closed unexpectedly, or a read error occurred
		 */
		EXCEPTION_TYPE_NETWORK,
		
		/**
			Firmware failure<br/>
			The FPGA design did not return a valid result to a query over the JTAG interface
		 */
		EXCEPTION_TYPE_FIRMWARE,
		
		/**
			Test exception<br/>
			Test of error handling capabilities, may be safely ignored
		 */
		EXCEPTION_TYPE_TEST
	};

	JtagException(
		std::string message,
		std::string library_error,
		JtagException::ExceptionTypes type,
		std::string prettyfunction,
		std::string file,
		int line);
	
	/**
		@brief Gets the type of this exception (so that calling code can determine whether to retry or abort, etc)
	 */
	JtagException::ExceptionTypes GetType() const
	{ return m_type; }
	
	std::string GetDescription() const;
	
	static void ThrowDummyException();
	
protected:

	///Error message
	std::string m_message;
	
	///String version of errno
	std::string m_system_error;
	
	///String version of library error
	std::string m_lib_error;
	
	///Exception type
	JtagException::ExceptionTypes m_type;
	
	///Pretty-printed function name
	std::string m_prettyfunction;
	
	///File name
	std::string m_file;
	
	///Line number
	int m_line;
};

/**
	@brief Wrapper for JtagException constructor that passes function, file, and line number automatically
	
	@param err			Human-readable error message. Include as much detail as reasonably possible.
	@param lib_err		Human-readable error string returned from a library (ex: libusb)
	@param type			Enumerated type of the exception. May be used by catching code to decide 
						whether the error is fatal or not.
 */
#define JtagExceptionWrapper(err, lib_err, type) JtagException(err, lib_err, type, __PRETTY_FUNCTION__, __FILE__, __LINE__)

#endif
