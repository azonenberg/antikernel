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
	@brief Implementation of JEDFileWriter
 */

#include "jtaghal.h"
#include "JEDFileWriter.h"
#include <string.h>

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Construction / destruction

JEDFileWriter::JEDFileWriter(const std::string& fname)
{
	//Open the output file
	m_fp = fopen(fname.c_str(), "w");
	if(!m_fp)
	{
		throw JtagExceptionWrapper(
			"Could not open output bitstream",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

JEDFileWriter::~JEDFileWriter()
{
	fclose(m_fp);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// File I/O functions

/**
	@brief Adds a header comment.
	
	This function can only be called before BeginFuseData() has been called.
 */
void JEDFileWriter::AddHeaderComment(const std::string& str)
{
	if(m_state != STATE_IN_HEADER)
	{
		throw JtagExceptionWrapper(
			"AddHeaderComment() cannot be called once BeginFuseData() has been called",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//No checksum required for header data, just output it
	if(str.length() != fwrite(str.c_str(), 1, str.length(), m_fp))
	{
		throw JtagExceptionWrapper(
			"Failed to write file",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Enters the fuse-data portion of the JED file
	
	This function can only be called once on a given instance.
 */
void JEDFileWriter::BeginFuseData(int fusecount, int pincount)
{
	if(m_state != STATE_IN_HEADER)
	{
		throw JtagExceptionWrapper(
			"BeginFuseData() can only be called while in the file header",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	m_state = STATE_IN_BODY;
	
	//Fuse-data header
	WriteBodyData("\x02\n");
	
	AddBodyComment("===========================================================================");
	AddBodyComment("=                               HEADER DATA                               =");
	AddBodyComment("===========================================================================");
	AddBodyBlankLine();
		
	//Fuse-count header
	char buf[32];
	snprintf(buf, sizeof(buf), "QF%d*\n", fusecount);
	AddBodyComment("Total number of fuses for this device (default state is 0 if not specified)");
	WriteBodyData(buf);
	WriteBodyData("F0*\n");
	AddBodyBlankLine();
	
	//Pin-count header
	snprintf(buf, sizeof(buf), "QP%d*\n", pincount);
	AddBodyComment("Total number of pins for this device, including power/ground/JTAG");
	WriteBodyData(buf);
	AddBodyBlankLine();
	
	//No test vectors
	AddBodyComment("Test vectors not supported");
	WriteBodyData("QV0*\nX0*\n");
	AddBodyBlankLine();
	
	//Device ID header (left default by Xilinx tools)
	AddBodyComment("JEDEC device ID header not implemented");
	snprintf(buf, sizeof(buf), "J0 0*\n");
	WriteBodyData(buf);
	AddBodyBlankLine();
}

/**
	@brief Adds a blank line to the body of the file
 */
void JEDFileWriter::AddBodyBlankLine()
{
	const char nl = '\n';
	WriteBodyData(&nl, 1);
}

/**
	@brief Adds a comment to the body of the file
 */
void JEDFileWriter::AddBodyComment(const std::string& str)
{
	char buf[1024];
	snprintf(buf, sizeof(buf), "N %s *\n", str.c_str());
	WriteBodyData(buf);
}

/**
	@brief Adds fuse data to the body of the file
 */
void JEDFileWriter::AddBodyFuseData(const bool* fuse_data, size_t len)
{
	//Write the chunk header
	char out_header[9];
	snprintf(out_header, sizeof(out_header), "L%06d ", m_rompos);
	WriteBodyData(out_header);
	
	//Write the fuse data
	for(size_t i=0; i<len; i++)
	{
		WriteBodyData(fuse_data[i] ? "1" : "0");
		m_fusedata.push_back(fuse_data[i]);
	}
	m_rompos += len;
	
	//Done
	WriteBodyData("*\n");
}

void JEDFileWriter::EndFuseData()
{
	//Compute fuse checksum
	uint16_t fuse_checksum = ComputeFuseChecksum();
	
	//Write closing data
	AddBodyBlankLine();
	char fsum[16];
	snprintf(fsum, sizeof(fsum), "C%04X*\n\x03", fuse_checksum & 0xFFFF);
	WriteBodyData(fsum);
	
	//Write file checksum
	snprintf(fsum, sizeof(fsum), "%04X", m_filechecksum & 0xFFFF);
	WriteBodyData(fsum);
}

/**
	@brief Writes data to the file body and updates the file checksum
 */
void JEDFileWriter::WriteBodyData(const char* str, size_t len)
{
	if(m_state != STATE_IN_BODY)
	{
		throw JtagExceptionWrapper(
			"WriteBodyData() can only be called while in the file body.",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Checksum
	for(size_t i=0; i<len; i++)
		m_filechecksum += str[i];
	
	//Write
	if(len != fwrite(str, 1, len, m_fp))
	{
		throw JtagExceptionWrapper(
			"Failed to write file",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Writes data to the file body and updates the file checksum
 */
void JEDFileWriter::WriteBodyData(const char* str)
{
	return WriteBodyData(str, strlen(str));
}
