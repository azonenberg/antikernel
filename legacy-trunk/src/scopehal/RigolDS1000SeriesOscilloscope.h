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
	@brief Declaration of RigolDS1000SeriesOscilloscope
 */

#ifndef RigolDS1000SeriesOscilloscope_h
#define RigolDS1000SeriesOscilloscope_h

/**
	@brief A Rigol DS1000-series oscilloscope (DS1102E, DS1102D, etc)
 */
class RigolDS1000SeriesOscilloscope : public Oscilloscope
{
public:
	RigolDS1000SeriesOscilloscope(const char* fname, const char* serial);
	virtual ~RigolDS1000SeriesOscilloscope();
	
	//Device information
	virtual std::string GetName();
	virtual std::string GetVendor();
	virtual std::string GetSerial();
	
	//Triggering
	virtual Oscilloscope::TriggerMode PollTrigger();
	virtual void AcquireData(sigc::slot1<int, float> progress_callback);
	void AcquireAnalogData(int ch, bool lmem);
	virtual void Start();
	virtual void StartSingleTrigger();
	virtual void Stop();
	
	//Channel status
	bool IsLongMemoryEnabled();
	bool IsAnalogChannelEnabled(int ch);
	
protected:
	std::string m_serial;
	std::string m_model;
	
	int m_hfile;
	
	//Internal helpers
	float GetChannelScale(int ch);
	float GetChannelOffset(int ch);
	float GetTimeScale();
	float GetTimeOffset();
};

#endif
