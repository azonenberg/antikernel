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
	@brief Declaration of ARMDebugPeripheralIDRegister
 */

#ifndef ARMDebugPeripheralIDRegister_h
#define ARMDebugPeripheralIDRegister_h

#include <stdlib.h>

/**
	@brief ADI component ID register bitfield
 */
class ARMDebugPeripheralIDRegisterBits
{
public:

	///Part number (TODO)
	unsigned int partnum:12;
	
	///JEP106 identity code
	unsigned int jep106_id:7;
	
	///Indicates if JEP106 code is valid
	unsigned int jep106_used:1;
	
	///Peripheral revision number
	unsigned int revnum:4;
	
	///Customer modification ID
	unsigned int cust_mod:4;
	
	///Manufacturer rev number (stepping)
	unsigned int revand:4;
	
	///JEP106 continuation code
	unsigned int jep106_cont:4;
	
	///Log2(#4K address space blocks)
	unsigned int log_4k_blocks:4;
	
	///Unmapped
	unsigned int reserved_zero:24;
	
} __attribute__ ((packed));

/**
	@brief ADI component ID register
 */
union ARMDebugPeripheralIDRegister
{
	///The bitfield
	ARMDebugPeripheralIDRegisterBits bits;
	
	///The raw status register value
	uint64_t word;
} __attribute__ ((packed));

#endif
