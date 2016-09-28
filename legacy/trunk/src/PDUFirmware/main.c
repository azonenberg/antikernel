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
	@brief Firmware entry point
 */

#include "PDUFirmware.h"
#include <NetworkedEthernetMAC_opcodes_constants.h>
#include <NOCSysinfo_constants.h>
#include <OutputStageController_opcodes_constants.h>
#include <PDUPeripheralInterface_opcodes_constants.h>

//Global addresses for various interesting RPC hosts
unsigned int g_periphAddr;
unsigned int g_ramAddr;
unsigned int g_sysinfoAddr;

//Uptime (in timer ticks)
unsigned int g_uptime;

//Nominal operating voltage
unsigned int g_vnom;

//Lockout status
unsigned int g_vlockout;

//Thermal shutdown
unsigned int g_faultled;
unsigned int g_thermalshutdown;

void ProcessInterrupt(RPCMessage_t* rmsg);
void OnTimer();
void Initialize();
void ErrorCheck();
void FaultLockout();

int main()
{
	//Do one-time setup
	Initialize();

	//Main message loop
	RPCMessage_t rmsg;
	while(1)
	{
		GetRPCInterrupt(&rmsg);
		ProcessInterrupt(&rmsg);
	}
	
	return 0;
}

/**
	@brief Interrupt dispatcher
 */
void ProcessInterrupt(RPCMessage_t* rmsg)
{
	if( (rmsg->from == g_periphAddr) && (rmsg->callnum == PERIPH_INT_TIMER) )
		OnTimer();

	else if(rmsg->from == g_ethAddr)
	{
		switch(rmsg->callnum)
		{
			//New frame arrived
			case ETH_FRAME_READY:	
				EthernetProcessFrame(rmsg);
				break;
			
			//Link state changed
			case ETH_LINK_STATE:
				{
					unsigned int linkState = rmsg->data[0] & 1;
		
					if(linkState)
						EthernetOnLinkUp();
					else
						EthernetOnLinkDown();

					//Done, link is up
					g_linkState = linkState;
					g_linkSpeed = (rmsg->data[0] >> 2) & 3;
				}
				break;
				
			default:
				//Unrecognized interrupt, ignore it
				break;
		}
	}

	else
	{
		//Unrecognized interrupt, ignore it
	}
}

/**
	@brief Timer interrupt
 */
void OnTimer()
{
	g_uptime ++;
	DHCPOnTimer();
		
	if(g_thermalshutdown)
	{
		GPIOSetFaultLED(g_faultled);
		g_faultled = !g_faultled;
	}
	else
		ErrorCheck();
}

/**
	@brief Checks for temperature- or voltage-out-of-range errors
 */
void ErrorCheck()
{
	for(int i=0; i<2; i++)
	{
		//Over/undervoltage shutdown
		unsigned int v = GetVoltage(i);
		unsigned int dv = (v > g_vnom) ? v - g_vnom : g_vnom - v;
		if(dv > 250)				//TODO: Make this configurable
		{
			FaultLockout();
			GPIOSetFaultLED(1);
		}
	
		//Thermal shutdown
		unsigned int t = GetTemperature(i);
		if( (t < 5) || (t > 60) )	//TODO: Make this configurable
		{
			g_thermalshutdown = 1;
			FaultLockout();
		}
	}
}

void FaultLockout()
{
	//Set lockout mode
	g_vlockout = 1;
	
	//Turn off all channels
	RPCMessage_t rmsg;
	for(unsigned int i=0; i<10; i++)
		RPCFunctionCall(g_outputStageAddr, OUTSTAGE_POWER_STATE, i, 0, 0, &rmsg);
}

/**
	@brief Initial one-time setup during boot
 */
void Initialize()
{
	//Reset the pending-interrupt queue
	InterruptQueueInit();
	
	//Generic hosts used by all subsystems
	g_periphAddr = LookupHostByName("periph");
	g_ramAddr = LookupHostByName("ram");
	g_sysinfoAddr = LookupHostByName("sysinfo");

	//Per-module init
	EthernetInitialize();
	ADCInitialize();
	I2CInitialize();	//must come before output stage
	OutputInitialize();
	GPIOInitialize();
	
	//Get the operating voltage
	RPCMessage_t rmsg;
	RPCFunctionCall(g_periphAddr, PERIPH_VOLTAGE_MODE, 0, 0, 0, &rmsg);
	g_vnom = rmsg.data[0];
	g_vlockout = 0;
	
	//Thermal shutdown sensor stuff
	g_faultled = 0;
	g_thermalshutdown = 0;

	//Set up the timer interrupt
	RPCFunctionCall(g_sysinfoAddr, SYSINFO_GET_CYCFREQ, 0, TIMER_HZ, 0, &rmsg);
	RPCFunctionCall(g_periphAddr, PERIPH_TIMER_SET_COUNT, 0, rmsg.data[1], 0, &rmsg);
	RPCFunctionCall(g_periphAddr, PERIPH_TIMER_START, 0, 0, 0, &rmsg);
	g_uptime = 0;
}
