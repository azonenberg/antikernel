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
	@brief Main firmware header file
 */

#ifndef PDUFirmware_h
#define PDUFirmware_h

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Library includes

#include <grafton/grafton.h>
#include <rpc.h>
#include <stdio.h>
#include <string.h>

#define UNREFERENCED_PARAMETER(x) (void)(x)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// System settings

#define TIMER_HZ 4

extern unsigned int g_uptime;
extern unsigned int g_vnom;
extern unsigned int g_vlockout;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Addressing

extern unsigned int g_periphAddr;
extern unsigned int g_outputStageAddr;
extern unsigned int g_ramAddr;
extern unsigned int g_sysinfoAddr;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Peripheral headers

#include "I2C.h"
#include "ADC.h"
#include "DAC.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ethernet subsystem headers

#include "ARP.h"
#include "DHCPv4.h"
#include "Ethernet.h"
#include "ICMPv4.h"
#include "IPv4.h"
#include "SNMP.h"
#include "UDPv4.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Other subsystem headers

#include "CurrentSensor.h"
#include "GPIO.h"
#include "Output.h"
#include "TempSensor.h"
#include "VoltageSensor.h"

#endif
