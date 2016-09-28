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
	@brief Register definitions for SARATOGA assembly
 */

#ifndef registers_h
#define registers_h

#ifdef __LANGUAGE_ASSEMBLY__

//CPU core registers
#define zero  				$0
#define at     				$1	/* assembler temporary */
#define v0					$2
#define v1					$3
#define a0					$4
#define a1					$5
#define a2					$6
#define a3					$7
#define t0					$8
#define t1					$9
#define t2					$10
#define t3					$11
#define t4					$12
#define t5					$13
#define t6					$14
#define t7					$15
#define t8					$24
#define t9					$25
#define s0					$16
#define s1					$17
#define s2					$18
#define s3					$19
#define s4					$20
#define s5					$21
#define s6					$22
#define s7					$23
#define s8					$30	/* s8 and fp are same register */
#define fp					$30
#define k0 					$26	/* officially reserved for kernel, but OK to use since SARATOGA lacks interrupts */
#define k1					$27
#define gp					$28
#define sp					$29
#define ra					$31

//Friendly names for registers used in syscalls
#define rpc_header			v1
#define rpc_d0				v0
#define rpc_d1				k0
#define rpc_d2				k1

#endif

#endif
