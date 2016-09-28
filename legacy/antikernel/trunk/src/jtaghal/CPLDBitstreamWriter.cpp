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
	@brief Implementation of CPLDBitstreamWriter
 */

#include "jtaghal.h"
#include "CPLDSerializer.h"
#include "CPLDBitstreamWriter.h"
#include "CPLDBitstream.h"

using namespace std;

CPLDBitstreamWriter::CPLDBitstreamWriter(CPLDBitstream* bitstream, uint32_t idcode, string devname)
	: m_bitstream(bitstream)
{
	m_bitstream->fuse_checksum = 0;
	m_bitstream->file_checksum = 0;
	
	m_bitstream->idcode = idcode;
	m_bitstream->devname = devname;
}

CPLDBitstreamWriter::~CPLDBitstreamWriter()
{
	//nothing to do, caller frees bitstream
}

void CPLDBitstreamWriter::AddHeaderComment(const string& str)
{
	m_bitstream->header_comment += str;
}

void CPLDBitstreamWriter::BeginFuseData(int fusecount, int pincount)
{
	m_bitstream->fuse_count = fusecount;
	m_bitstream->pin_count = pincount;
	m_bitstream->fuse_data = new bool[fusecount];
}

void CPLDBitstreamWriter::AddBodyBlankLine()
{
	//no-op
}

void CPLDBitstreamWriter::AddBodyComment(const string& /*str*/)
{
	//no-op
}

void CPLDBitstreamWriter::WriteBodyData(const char* /*str*/)
{
	//no-op
}

void CPLDBitstreamWriter::WriteBodyData(const char* /*str*/, size_t /*len*/)
{
	//no-op
}

void CPLDBitstreamWriter::AddBodyFuseData(const bool* fuse_data, size_t len)
{
	for(size_t i=0; i<len; i++)
		m_fusedata.push_back(fuse_data[i]);
}

void CPLDBitstreamWriter::EndFuseData()
{
	for(size_t i=0; i<m_fusedata.size(); i++)
		m_bitstream->fuse_data[i] = m_fusedata[i];
	m_bitstream->fuse_checksum = ComputeFuseChecksum();
	
	for(size_t i=0; i<m_bitstream->header_comment.length(); i++)
	{
		if(m_bitstream->header_comment[i] == '\n')
			m_bitstream->header_comment[i] = '|';
	}
}
