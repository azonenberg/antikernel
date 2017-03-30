/***********************************************************************************************************************
*                                                                                                                      *
* ANTIKERNEL v0.1                                                                                                      *
*                                                                                                                      *
* Copyright (c) 2012-2017 Andrew D. Zonenberg                                                                          *
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
	@brief Implementation of RPCMessage
 */

#include "nocbridge.h"
#include "RPCv3Transceiver_types_enum.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RPCMessage

RPCMessage::RPCMessage()
{
	from = 0;
	to = 0;
	callnum = 0;
	type = RPC_TYPE_CALL;
	data[0] = 0;
	data[1] = 0;
	data[2] = 0;
}

bool RPCMessage::operator==(const RPCMessage& rhs) const
{
	return
		(from == rhs.from) &&
		(to == rhs.to) &&
		(callnum == rhs.callnum) &&
		(type == rhs.type) &&
		(data[0] == rhs.data[0]) &&
		(data[1] == rhs.data[1]) &&
		(data[2] == rhs.data[2]);
}
/*
void RPCMessage::Pack(unsigned char* buf) const
{
	//Sanity check the high bits of d0 are all zero since only the low 21 are actually valid.
	if( (data[0] & 0x1fffff) != data[0])
	{
		throw JtagExceptionWrapper(
			"The high 11 bits of data[0] in an RPC message must be all zero.",
			"");
	}

	buf[0] = from >> 8;
	buf[1] = from & 0xff;
	buf[2] = to >> 8;
	buf[3] = to & 0xff;
	buf[4] = callnum;
	buf[5] = ( (data[0] >> 16) & 0x1f) | ( (type & 0x7) << 5);
	buf[6] = (data[0] >> 8) & 0xff;
	buf[7] = data[0] & 0xff;
	buf[8] = data[1] >> 24;
	buf[9] = (data[1] >> 16) & 0xff;
	buf[10] = (data[1] >> 8) & 0xff;
	buf[11] = data[1] & 0xff;
	buf[12] = data[2] >> 24;
	buf[13] = (data[2] >> 16) & 0xff;
	buf[14] = (data[2] >> 8) & 0xff;
	buf[15] = data[2] & 0xff;
}
*/

void RPCMessage::Pack(uint32_t* buf) const
{
	buf[0] = (from << 16) | to;
	buf[1] = (callnum << 24) | (type << 21) | data[0];
	buf[2] = data[1];
	buf[3] = data[2];
}

void RPCMessage::Unpack(uint32_t* buf)
{
	from = buf[0] >> 16;
	to = buf[0] & 0xffff;
	callnum = buf[1] >> 24;
	type = (buf[1] >> 21) & 7;
	data[0] = buf[1] & 0x1fffff;
	data[1] = buf[2];
	data[2] = buf[3];
}
/*
void RPCMessage::Unpack(unsigned char* buf)
{
	from = (buf[0] << 8) | buf[1];
	to = (buf[2] << 8) | buf[3];
	callnum = buf[4];
	type = (buf[5] >> 5);
	data[0] = ( ( buf[5] & 0x1F) << 16) | (buf[6] << 8) | buf[7];
	data[1] = (buf[8] << 24) | (buf[9] << 16) | (buf[10] << 8) | buf[11];
	data[2] = (buf[12] << 24) | (buf[13] << 16) | (buf[14] << 8) | buf[15];
}
*/
/**
	@brief Returns a printable version of the message
 */
/*
std::string RPCMessage::Format() const
{
	const char* stype = "Reserved";
	switch(type)
	{
	case RPC_TYPE_CALL:
		stype = "Function call";
		break;
	case RPC_TYPE_RETURN_SUCCESS:
		stype = "Function return (success)";
		break;
	case RPC_TYPE_RETURN_FAIL:
		stype = "Function return (fail)";
		break;
	case RPC_TYPE_RETURN_RETRY:
		stype = "Function return (retry)";
		break;
	case RPC_TYPE_INTERRUPT:
		stype = "Interrupt";
		break;
	case RPC_TYPE_HOST_PROHIBITED:
		stype = "Host prohibited";
		break;
	case RPC_TYPE_HOST_UNREACH:
		stype = "Host unreachable";
		break;
	}

	char outbuf[1024];
	snprintf(
		outbuf,
		sizeof(outbuf),
		"From: %04x | To  : %04x | Type: %s | Call: %d | Data : %08x %08x %08x",
		from,
		to,
		stype,
		callnum,
		data[0],
		data[1],
		data[2]);

	return std::string(outbuf);
}
*/
