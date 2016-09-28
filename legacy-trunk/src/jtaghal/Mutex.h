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
	@brief Cross-platform recursive mutex
 */

#ifndef zMutex_h
#define zMutex_h

#ifdef _WINDOWS
	typedef CRITICAL_SECTION ZMUTEX;
#else
	#include <pthread.h>
	typedef pthread_mutex_t ZMUTEX;
#endif

/**
	@brief A mutex.
 */
class Mutex
{
public:
	Mutex(void);
	~Mutex(void);

	void Lock();
	void Unlock();

protected:
	/**
		@brief The underlying handle.
	 */
	ZMUTEX m_mutex;
};

/**
	@brief Automatic mutex lock manager.
 */
class MutexLock
{
public:
	/**
		@brief Locks a mutex, blocking as needed.
		
		@param mutex The mutex to lock.
	 */
	MutexLock(Mutex& mutex)
	: m_pMutex(&mutex)
	{
		mutex.Lock();
	}

	/**
		@brief Unlocks the mutex.
	 */	
	~MutexLock()
	{
		m_pMutex->Unlock();
	}
	
protected:
	/**
		@brief Pointer to the mutex we have a lock on.
	 */
	Mutex* m_pMutex;
};

#endif
