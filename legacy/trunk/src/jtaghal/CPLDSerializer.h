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
	@brief Declaration of CPLDSerializer
 */

#ifndef CPLDSerializer_h
#define CPLDSerializer_h

class CPLDSerializer
{
public:
	CPLDSerializer();
	virtual ~CPLDSerializer();
	
	virtual void AddDefaultHeaderComment();
	virtual void AddHeaderComment(const std::string& str)=0;
	
	virtual void BeginFuseData(int fusecount, int pincount)=0;
	
	virtual void AddBodyBlankLine()=0;
	virtual void AddBodyComment(const std::string& str)=0;
	virtual void WriteBodyData(const char* str)=0;
	virtual void WriteBodyData(const char* str, size_t len)=0;
	virtual void AddBodyFuseData(const bool* fuse_data, size_t len)=0;
	
	virtual void EndFuseData()=0;

protected:

	uint16_t ComputeFuseChecksum();

	std::vector<bool> m_fusedata;
	
	enum states
	{
		STATE_IN_HEADER,
		STATE_IN_BODY,
		STATE_DONE
	} m_state;
	
	int m_rompos;
	uint16_t m_filechecksum;
	
	std::string pipe_get_contents(const std::string& command);
};

#endif

