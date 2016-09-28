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
	@brief Common / shared linker script components
 */

/* Program entry point */
ENTRY(_start)

/* Stack starts at the end of RAM and goes back from there */
_stack_low = ORIGIN(stack);
_stack_high = _stack_low + LENGTH(stack) - 8;

/* Memory available for mapping stuff */
_user_mem_low = ORIGIN(user_mem);
_user_mem_high = _user_mem_low + LENGTH(user_mem) - 1;

/* Section map */
SECTIONS
{
	/* Application code */
	.text :
	{
		. = ALIGN(4);
		*(.text)
		*(.text*)
	} > rom
	
	/* Read-only data in flash */
	.rodata :
	{
		. = ALIGN(4);
		*(.rodata)
		*(.rodata*)
	} > rom

	/* Initialized data in RAM */
	.data :
	{
		. = ALIGN(4);
		_globals_start = .;
		*(.data)
	} > globals
	ASSERT(SIZEOF(.data) == 0, "initialized RAM data not yet supported")
	
	/*
		Uninitialized data in RAM
	 */
	.bss :
	{
		. = ALIGN(4);
		*(.bss)
		*(.bss.*)
		*(.scommon)
	} > globals
	_globals_end  = _globals_start + SIZEOF(.data) + SIZEOF(.bss);
	
	/*
		Stack
	 */
	.stack _stack_low :
	{
	} > stack
	
	/*
		Build ID
	 */
	.note.gnu.build-id 0 : { *(.note.gnu.build-id) }
	
	/* Debug info */
	.debug          0 : { *(.debug) }
	.line           0 : { *(.line) }
	.debug_srcinfo  0 : { *(.debug_srcinfo) }
	.debug_sfnames  0 : { *(.debug_sfnames) }
	.debug_aranges  0 : { *(.debug_aranges) }
	.debug_pubnames 0 : { *(.debug_pubnames) }
	.debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
	.debug_abbrev   0 : { *(.debug_abbrev) }
	.debug_line     0 : { *(.debug_line) }
	.debug_frame    0 : { *(.debug_frame) }
	.debug_str      0 : { *(.debug_str) }
	.debug_loc      0 : { *(.debug_loc) }
  
	/*
		Throw away other sections we don't use.
		Most of these are used for C++ and we're not supporting it yet.
	*/
	/DISCARD/ : { *(.ctors) }
	/DISCARD/ : { *(.dtors) }
	/DISCARD/ : { *(.eh_frame) }
	/DISCARD/ : { *(.jcr) }
	/DISCARD/ : { *(.init) }
	/DISCARD/ : { *(.fini) }
	/DISCARD/ : { *(.reginfo) }
	/DISCARD/ : { *(.comment) }
	/DISCARD/ : { *(.gnu.attributes) }
}
