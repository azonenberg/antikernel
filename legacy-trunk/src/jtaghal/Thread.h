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
	@file Thread.cpp
	
	@brief Implementation of Thread class
 */

#ifndef _THREAD_H
#define _THREAD_H

#ifdef _WINDOWS
#include <windows.h>

/**
	@brief A thread handle
 */
typedef HANDLE ZTHREAD;

/**
	@brief A thread procedure
 */
typedef DWORD (WINAPI *ZTHREADPROC)(LPVOID lpThreadParameter);

/**
	@brief Prototype of a thread function
 */
#define THREAD_PROTOTYPE(func,param) DWORD __stdcall func(LPVOID param)

/**
	@brief Returns from a thread
 */
#define THREAD_RETURN(n) return n


#else

#include <unistd.h>
#include <pthread.h>

/**
	@brief A thread handle
 */
typedef pthread_t ZTHREAD;

/**
	@brief A thread procedure
 */
typedef void* (*ZTHREADPROC)(void* lpThreadParameter);

/**
	@brief Prototype of a thread function
 */
#define THREAD_PROTOTYPE(func,param) void* func(void* param)

/**
	@brief Returns from a thread
 */
#define THREAD_RETURN(n) return (void*)n

#endif

/**
	@brief A thread
 */
class Thread
{
public:

	Thread(ZTHREADPROC proc,void* param);
	~Thread(void);

	void WaitUntilTermination();

protected:
	/**
		@brief Our internal thread handle
	 */
	ZTHREAD m_hThread;
};

#endif
