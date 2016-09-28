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
	@brief Implementation of CPLDSerializer
 */

#include "jtaghal.h"
#include "CPLDSerializer.h"

using namespace std;

CPLDSerializer::CPLDSerializer()
{
	m_state = STATE_IN_HEADER;
	m_rompos = 0;
	m_filechecksum = 0;
}

CPLDSerializer::~CPLDSerializer()
{
}

/**
	@brief Adds the default (device-agnostic) header comment
 */
void CPLDSerializer::AddDefaultHeaderComment()
{
	AddHeaderComment("Programmer JEDEC Bit Map\n");
	AddHeaderComment(string("Generated on ") + pipe_get_contents("date") + " by " + pipe_get_contents("whoami") +
						" using libcrowbar\n");
}

/**
	@brief Returns the output of a program as a std::string.
	
	The trailing newline, if present, is stripped.
 */
string CPLDSerializer::pipe_get_contents(const string& command)
{
	FILE* fp = popen(command.c_str(), "r");
	if(!fp)
	{
		throw JtagExceptionWrapper(
			"Could not open file",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	string retval = "";
	
	char read_buf[1024];
	while(NULL != fgets(read_buf, sizeof(read_buf), fp))
		retval += read_buf;
		
	int end = retval.length()-1;
	if(retval[end] == '\n')
		retval.erase(end);
	
	pclose(fp);
	return retval;
}

uint16_t CPLDSerializer::ComputeFuseChecksum()
{
	uint16_t fuse_checksum = 0;
	for(size_t i=0; i<m_fusedata.size(); i+=8)
	{
		uint8_t bval = 0;
		for(size_t j=0; j<8; j++)
		{
			if(i+j >= m_fusedata.size())
				break;
			if(m_fusedata[i+j])
				bval |= (1 << j);
		}
		fuse_checksum += bval;
	}
	return fuse_checksum;
}
