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
	@brief Software-emulated division
 */

//Friendly names for CPU registers
#include <grafton/registers.h>

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Software-emulated instruction handlers

/*
	@brief Entry point for software divide algorithm
		
	Returns to $k0 instead of $ra to avoid problems when called from "leaf" procedures.
	
	Inputs:  $hi = dividend,  $lo = divisor
	Outputs: $hi = remainder, $lo = quotient
	
	May not change any registers other than $k0 and $k1.
 */
.globl SignedSoftDivisionHandler
SignedSoftDivisionHandler:

	//Save registers
	addiu		sp, sp, -32
	sw			ra, 24(sp)
	sw			t0, 20(sp)
	sw			t1, 16(sp)
	sw			t2, 12(sp)
	sw			t3, 8(sp)
	sw			t4, 4(sp)
	sw			t5, 28(sp)
	
	//Get the input values
	mfhi		t0
	mflo		t1
	
	//Check sign bits
	move		t2, zero					//t2 = number of negative values
	bgtz		t0, PositiveDividend		//If dividend is negative, complement it
	nop
	subu		t0, zero, t0				//Flip
	addiu		t2, t2, 1					//Bump flip count
PositiveDividend:
	bgtz		t1, PositiveDivisor			//If divisor is negative, complement it
	nop
	subu		t1, zero, t1				//Flip
	addiu		t2, t2, 1					//Bump flip count
PositiveDivisor:

	//Both inputs are now positive
	//$t3 stores the "need to invert" flag for use after the division
	li			t3, 1
	beq			t2, t3, PositiveOutput		//One inversion? If so, we are inverting the output
	nop
	li			t3, 0						//Otherwise, do not invert
PositiveOutput:

	//Do the actual divide operation
	jal			CoreDivisionHandler
	nop
	
	//Flip the output if required
	beqz		t3, OutputFlippedIfNeeded
	nop
	mfhi		t0							//Flip $hi
	subu		t0, zero, t0
	mthi		t0
	mflo		t1							//Flip $lo
	subu		t1, zero, t0
	mtlo		t1
OutputFlippedIfNeeded:
	
	//Clean up stack and restore registers
	lw			t5, 28(sp)
	lw			t4, 4(sp)
	lw			t3, 8(sp)
	lw			t2, 12(sp)
	lw			t1, 16(sp)
	lw			t0, 20(sp)
	lw			ra, 24(sp)
	addiu		sp, sp, 32

	jr			k0
	nop

/*
	@brief Entry point for software divide algorithm
		
	Returns to $k0 instead of $ra to avoid problems when called from "leaf" procedures.
	
	Inputs:  $hi = dividend,  $lo = divisor
	Outputs: $hi = remainder, $lo = quotient
	
	May not change any registers other than $k0 and $k1.
 */
.globl UnsignedSoftDivisionHandler
UnsignedSoftDivisionHandler:

	//Save registers
	addiu		sp, sp, -24
	sw			ra, 20(sp)
	sw			t0, 16(sp)
	sw			t1, 12(sp)
	sw			t2, 8(sp)
	sw			t4, 4(sp)
	sw			t5, 0(sp)
	
	//Get the input values
	mfhi		t0
	mflo		t1

	//Do the actual divide operation
	jal			CoreDivisionHandler
	nop
	
	//Clean up stack and restore registers
	lw			t5, 0(sp)
	lw			t4, 4(sp)
	lw			t2, 8(sp)
	lw			t1, 12(sp)
	lw			t0, 16(sp)
	lw			ra, 20(sp)
	addiu		sp, sp, 24

	jr			k0
	nop
	
/*
	@brief Core of software divide algorithm
	
	Inputs:   t0 = dividend,   t1 = divisor
	Outputs: $hi = remainder, $lo = quotient
	
	May use only the following registers: $t0, $t1, $t2, $t4, $k1
	
	Register allocation:
		t0 = dividend
		t1 = divisor
		t2 = quotient
		t4 = remainder
		t5 = general purpose temporary
		k1 = loop counter
 */
CoreDivisionHandler:

	//Get input values (stored to $hi and $lo by trap hardware)
	mfhi		t0
	mflo		t1
	
	//Sanity check that we're not dividing by zero.
	//If we are, die.
	//TODO: Make syscall that hangs and provides debug output?
	beqz		t1, halt
	nop
	
	//If the dividend is zero, return zero and skip the loop
	beqz		t0, DivReturnZero
	nop	

	//Clear quotient and remainder registers
	li			t2, 0
	li			t4, 0
	
	//The actual division loop
	//Reference: http://en.wikipedia.org/wiki/Division_algorithm#Integer_division_.28unsigned.29_with_remainder
	li			k1, 31
DivideLoop:
	
	sll			t4, t4, 1			//Move remainder left one place
	
	srlv		t5, t0, k1			//Extract bit i of the dividend
	andi		t5, t5, 1
	or			t4, t4, t5			//Set the LSB of the remainder to the bit we just pulled.
									//Note that we just shifted left so this bit is guaranteed to be zero
									//thus no masking is required
	sub			t5, t4, t1			//Skip the rest of the inner loop if r < d
									//t5 is r-d so >=0 if r>=d
	bltz		t5, DivideSkip
	nop
	
	sub			t4, t4, t1			//Handle remainder overflow
	
	li			t5, 1				//Set quotient bit i
	sllv		t5, t5, k1
	or			t2, t2, t5
	
DivideSkip:
	beqz		k1, DivDone			//If we just did bit #0, stop
	nop
	li			t5, 1
	sub			k1, k1, t5			//Nope, i-- and continue
	j			DivideLoop
	nop

	//Save output in the result registers
DivDone:
	mthi		t4
	mtlo		t2

	//Done
	jr			ra
	nop
	
	//Early out, return zero
DivReturnZero:
	mthi		zero
	mtlo		zero

	jr			ra
	nop
	
