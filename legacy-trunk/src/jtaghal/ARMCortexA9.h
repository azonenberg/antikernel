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
	@brief Declaration of ARMCortexA9
 */

#ifndef ARMCortexA9_h
#define ARMCortexA9_h

#include <stdlib.h>

class DebuggableDevice;
class ARMAPBDevice;

enum ARMDebugArchVersion
{
	///ARMv6, v6 debug arch
	ARM_DEBUG_V6 = 1,
	
	///ARMv6, v6.1 debug arch
	ARM_DEBUG_V6_P1 = 2,
	
	///ARMv7, v7 debug, full CP14
	ARM_DEBUG_V7_FULL = 3,
	
	///ARMv7, v7 debug, only baseline cp14
	ARM_DEBUG_V7_MIN = 4,
	
	///ARMv7, v7.1 debug
	ARM_DEBUG_V7_P1 = 5
};

/**
	@brief ARM debug ID register (see ARMv7 ARM, C11.11.15)
 */
union ARMv7DebugIDRegister
{
	struct
	{
		///Implementation defined CPU revision
		unsigned int revision:4;
		
		///Implementation defined CPU variant
		unsigned int variant:4;
		
		///Reserved, undefined value
		unsigned int reserved:4;
		
		///Indicates if security extensions are implemented
		unsigned int sec_ext:1;
		
		///Indicates if PCSR is present at the legacy address
		unsigned int pcsr_legacy_addr:1;
		
		///NO secure halting debug
		unsigned int no_secure_halt:1;
		
		///True if DBGDEVID is implemented
		unsigned int has_dbgdevid:1;
		
		///Debug arch version
		ARMDebugArchVersion debug_arch_version:4;
		
		///Number of breakpoints supporting context matching, zero based (0 means 1 implemented, etc)
		unsigned int context_bpoints_minus_one:4;
		
		///Number of breakpoints, zero based (0 means 1 implemented, etc)
		unsigned int bpoints_minus_one:4;
		
		///Number of watchpoints, zero based (0 means 1 implemented, etc)
		unsigned int wpoints_minus_one:4;
		
	} __attribute__ ((packed)) bits;
	
	///The raw register value
	uint32_t word;
} __attribute__ ((packed));

/**
	ARM debug status/control register (see ARMv7 ARM, C11.11.20)
 */
union ARMv7DebugStatusControlRegister
{
	struct
	{
		///Set by the CPU when the processor is halted
		unsigned int halted:1;
		
		///Processor restarted flag
		unsigned int restarted:1;
		
		///Method of debug entry (TODO)
		unsigned int entry_method:4;
		
		///Sticky sync abort
		unsigned int sticky_sync_abt:1;
		
		///Sticky async abort
		unsigned int sticky_async_abt:1;
		
		///Sticky undefined instruction
		unsigned int sticky_undef_instr:1;
		
		///Reserved
		unsigned int reserved_sbz2:1;
		
		///Force debug acks regardless of cpu settings
		unsigned int force_dbg_ack:1;
		
		///Disable interrupts
		unsigned int int_dis:1;
		
		///Enable user-mode access to the debug channel
		unsigned int user_dcc:1;
		
		///Enable instruction transfer
		unsigned int inst_txfr:1;
		
		///Enable halting-mode debug
		unsigned int halting_debug:1;
		
		///Set high by the CPU if it allows monitor-mode debugging
		unsigned int monitor_debug:1;
		
		///Set high by the CPU if it allows invasive debug in secure mode
		unsigned int secure_ni_debug:1;
		
		///Deprecated "secure noninvasive debug" bit
		unsigned int deprecated:1;
		
		///Set high by the CPU if it is not in secure mode
		unsigned int nonsec:1;
		
		///Set high to discard async aborts
		unsigned int discard_async_abort:1;
		
		///DCC access mode (TODO enum)
		unsigned int ext_dcc_mode:2;
		
		///Latching instruction-complete bit for single instruction issue
		unsigned int instr_complete:1;
		
		///Sticky "pipeline advancing" bit, set at unpredictable intervals when not halted
		unsigned int pipelined_advancing:1;
		
		///Latching TX-full bit
		unsigned int tx_full_latch:1;
		
		///Latching RX-full bit
		unsigned int rx_full_latch:1;
		
		///Indicates DBGDTRTX has valid data
		unsigned int tx_full:1;
		
		///Indicates DBGDTRRX has valid data
		unsigned int rx_full:1;
		
		///Reserved, should be zero
		unsigned int reserved_sbz:1;
		
	} __attribute__ ((packed)) bits;
	
	///The raw register value
	uint32_t word;
} __attribute__ ((packed));

/**
	@brief Generic base class for all debuggable devices (MCUs etc)
	
	\ingroup libjtaghal
 */
class ARMCortexA9 	: public DebuggableDevice
					, public ARMAPBDevice
{
public:
	ARMCortexA9(ARMDebugMemAccessPort* ap, uint32_t address, ARMDebugPeripheralIDRegisterBits idreg);
	virtual ~ARMCortexA9();
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Registers
	
	//register numbers, multiply by 4 to get address
	//TODO: Move most of this stuff up to an ARMv7Processor class
	enum CORTEX_A9_DEBUG_REGISTERS
	{
		DBGDIDR			= 0,
		DBGDSCR_INT		= 1,
		DBGDTRRX_INT	= 5,
		DBGDTRTX_INT	= 5,
		DBGWFAR			= 6,
		DBGVCR			= 7,
		DBGECR			= 9,
		DBGDSCCR		= 10,
		DBGDSMCR		= 11,
		DBGDTRRX_EXT	= 32,
		DBGITR			= 33,
		DBGPCSR_LEGACY	= 33,
		DBGDSCR_EXT		= 34,
		DBGDTRTX_EXT	= 35,
		DBGDRCR			= 36,
		DBGEACR			= 37,
		DBGPCSR			= 40,
		DBGCIDSR		= 41,
		DBGVIDSR		= 42,
		DBGBVR_BASE		= 64,	//multiple breakpoint values
		DBGBCR_BASE		= 80,	//multiple breakpoint controls
		DBGWVR_BASE		= 96,	//multiple watchpoint values
		DBGWCR_BASE		= 112,	//multiple watchpoint controls
		DBGDRAR			= 128,
		DBGBXVR_BASE	= 144,	//multiple extended breakpoint values
		DBGOSLAR		= 192,
		DBGOSLSR		= 193,
		DBGOSSRR		= 194,
		DBGOSDLR		= 195,
		DBGPRCR			= 196,
		DBGPRSR			= 197,
		DBGDSAR			= 256,
		DBGPRID_BASE	= 832,	//processor ID address range
		DBGITCTRL		= 960,
		DBGCLAIMSET		= 1000,
		DBGCLAIMCLR		= 1001,
		DBGLAR			= 1004,
		DBGLSR			= 1005,
		DBGAUTHSTATUS	= 1006,
	};
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// General device info

	virtual std::string GetDescription();
	
	///Sample program counter (for sample-based profiling)
	uint32_t SampleProgramCounter()
	{ return ReadRegisterByIndex(m_pcsrIndex); }
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Memory access via the default (AHB) MEM-AP
	
	uint32_t ReadMemory(uint32_t addr);
	
protected:
	void PrintIDRegister(ARMv7DebugIDRegister did);
	
	unsigned int m_breakpoints;
	unsigned int m_context_breakpoints;
	unsigned int m_watchpoints;
	bool m_hasDevid;
	bool m_hasSecExt;
	bool m_hasSecureHalt;
	unsigned int m_revision;
	unsigned int m_variant;
	//TODO: arch version
	
	///Device-dependent address of the program counter sample register (PCSR)
	CORTEX_A9_DEBUG_REGISTERS m_pcsrIndex;	
};

#endif

