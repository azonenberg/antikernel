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
	@brief Implementation of CPLD
 */

#include "jtaghal.h"
#include "CPLD.h"
#include "CPLDBitstream.h"

using namespace std;

/**
	@brief Empty virtual destructor
 */
CPLD::~CPLD()
{
}

/**
	@brief Parses a JED file
	
	Reference: JEDEC Standard 3-C
	
	@throw JtagException if the file is malformed
	
	@param bit		Output bitstream
	@param data		Data to load
	@param len		Length of the file
 */
void CPLD::ParseJEDFile(CPLDBitstream* bit, const unsigned char* data, size_t len)
{	
	const char* cdata = reinterpret_cast<const char*>(data);
	
	//Everything before the STX character (0x02) is a header comment
	size_t pos = 0;
	bit->header_comment = "";
	bool last_newline = false;
	for(; (pos < len) && (cdata[pos] != 0x02); pos++)
	{
		//replace newlines by pipes
		if(cdata[pos] == '\r' || cdata[pos] == '\n')
		{
			if(!last_newline)
				bit->header_comment += " | ";
			last_newline = true;
		}
		else
		{
			bit->header_comment += cdata[pos];
			last_newline = false;
		}
	}
	
	//Validate the checksum
	//See section 3.2
	uint16_t file_checksum = 0;
	uint16_t expected_checksum = 0;
	for(size_t cpos = pos; cpos < len; cpos ++)
	{
		file_checksum += cdata[cpos];
		
		//ETX? Done with data, read expected checksum
		if(cdata[cpos] == 0x03)
		{
			cpos++;
			unsigned int csum = 0;
			sscanf(cdata + cpos, "%4x", &csum);
			expected_checksum = (csum & 0xFFFF);
			break;
		}
	}
	if(file_checksum == expected_checksum)
	{}//	printf("    Validating file checksum... OK\n");
	else
	{
		throw JtagExceptionWrapper(
			"JED file checksum mismatch, aborting",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	bit->file_checksum = file_checksum;
	
	//Skip the STX
	pos ++;
	
	//Default fuse state
	bool default_fuse_state = false;

	//Read the data
	while(pos < len)
	{
		//Skip whitespace
		if(isspace(cdata[pos]))
		{
			pos++;
			continue;
		}
		
		//ETX - we're done
		if(cdata[pos] == 0x03)
			break;
		
		//Figure out the opcode
		switch(cdata[pos])
		{		
		case 'Q':
			{
				pos++;
				switch(cdata[pos])
				{
				//Number of fuses
				case 'F':
					if(bit->fuse_count != 0)
					{
						throw JtagExceptionWrapper(
							"Fuse count cannot be specified more than once",
							"",
							JtagException::EXCEPTION_TYPE_GIGO);
					}
				
					pos++;
					bit->fuse_count = ReadIntLine(cdata, pos, len);
					bit->fuse_data = new bool[bit->fuse_count];
					break;
				
				//Number of pins
				case 'P':
					pos++;
					bit->pin_count = ReadIntLine(cdata, pos, len);
					break;
				
				//Number of test vectors (must be zero)
				case 'V':
					pos++;
					if(0 != ReadIntLine(cdata, pos, len))
					{
						throw JtagExceptionWrapper(
							"JEDEC test vectors not implemented",
							"",
							JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
					}
					break;
					
				
				default:
					throw JtagExceptionWrapper(
						"Unknown Q-series opcode",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				
					break;
				}
			}
			break;

		//Default fuse state, if not specified
		case 'F':
			pos++;
			default_fuse_state = (bool)ReadIntLine(cdata, pos, len);
			if(bit->fuse_data == NULL)
			{
				throw JtagExceptionWrapper(
					"Cannot specify default fuse state if fuse count was not yet specified",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			//Fill fuse buffer
			for(size_t i=0; i<bit->fuse_count; i++)
				bit->fuse_data[i] = default_fuse_state;
			break;
			
		//Default test condition (ignore)
		case 'X':
			pos++;
			if(0 != ReadIntLine(cdata, pos, len))
			{
				throw JtagExceptionWrapper(
					"JEDEC test vectors not implemented",
					"",
					JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
			}
			break;
			
		//Device identification
		case 'J':
			//ignore, scan until we get a *
			pos++;
			for(; (pos < len) && (cdata[pos] != '*'); pos++)
			{}
			
			//skip the *
			pos++;
			break;
			
		//Comments
		case 'N':
			{
				pos++;
			
				//Find the end of the line
				const char* pend = strstr(cdata+pos, "*");
				if(pend == NULL)
				{
					throw JtagExceptionWrapper(
						"Unexpected end of file in comment",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
				size_t end_offset = pend - cdata;
							
				//Look for "VERSION" and "DEVICE" keywords added for Xilinx devices
				const char* nver = strstr(cdata+pos, " VERSION");
				if(nver != NULL)
				{
					//TODO: process this
				}
				
				const char* ndev = strstr(cdata+pos, " DEVICE");
				if(ndev == (cdata+pos))
				{
					char devname[128] = {0};
					sscanf(ndev, " DEVICE %127[^*]", devname);
					bit->devname = devname;
				}
				
				//skip the *
				pos = end_offset + 1;
			}
			break;
			
		//Actual fuse data
		case 'L':
			{
				pos++;
		
				if(bit->fuse_data == NULL)
				{
					throw JtagExceptionWrapper(
						"Cannot have a fuse data line until fuse count has been specified",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
				
				//Read fuse number
				int fuse_num = atoi(cdata+pos);
				
				//Skip the digits and the space
				while(isdigit(cdata[pos]))
					pos++;
				while(isspace(cdata[pos]))
					pos++;
					
				//Read the digits
				while(cdata[pos] != '*')
				{
					if( (cdata[pos] != '0') && (cdata[pos] != '1'))
					{
						throw JtagExceptionWrapper(
							"Expected 1 or 0 as fuse value, found something else",
							"",
							JtagException::EXCEPTION_TYPE_GIGO);
					}
					
					//Set the fuse
					if(cdata[pos] == '1')
						bit->fuse_data[fuse_num++] = true;
					else
						bit->fuse_data[fuse_num++] = false;
					
					pos++;
				}
				
				//Skip the *
				pos++;
			}
			
			break;
		
		//Fuse checksum
		case 'C':
			{
				pos++;
				
				unsigned int checksum;
				sscanf(cdata+pos, "%4x", &checksum);
				
				//Calculate the fuse checksum
				uint16_t calcsum = 0;
				for(size_t i=0; i<bit->fuse_count; i+= 8)
				{
					uint8_t bval = 0;
					for(size_t j=0; j<8; j++)
					{
						if(i+j >= bit->fuse_count)
							break;
						if(bit->fuse_data[i+j])
							bval |= (1 << j);
					}
					calcsum += bval;
				}
				if(calcsum != checksum)
				{
					throw JtagExceptionWrapper(
						"Fuse array checksum mismatch, aborting",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
				
				//Skip checksum data
				while(cdata[pos] != '*')
					pos++;
				pos++;
				
				bit->fuse_checksum = checksum;
			}
			break;
			
		default:
			throw JtagExceptionWrapper(
				string("Unknown JEDEC programming file opcode ") + cdata[pos],
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
	}
}

/**
	@brief Reads a line containing an integer terminated by a *
	
	@throw JtagException if malformed input
	
	@param cdata	Buffer to read
	@param pos		Position to read from (updated at function return)
	@param len		Length of the entire buffer
	
	@return The value
 */
int CPLD::ReadIntLine(const char* cdata, size_t& pos, size_t len)
{
	int retval = 0;
	
	while(pos < len)
	{
		//* is end of line character
		if(cdata[pos] == '*')
		{
			pos++;
			break;
		}
		
		//Digit? Read it
		if(isdigit(cdata[pos]))
			retval = (retval * 10) + (cdata[pos++] - '0');
			
		//No clue, give up
		else
		{			
			throw JtagExceptionWrapper(
				"Bad character in integer line",
				"",
				JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
		}
	}
	
	return retval;
}
