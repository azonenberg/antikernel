#!/usr/bin/php5
<?php
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
	@brief Munin plugin for PDU
 */

/*
MAGIC MARKERS
#%# family=snmpauto
#%# capabilities=snmpconf
*/
 
main();

function main()
{
	global $argc;
	global $argv;
	if($argc == 2)
	{
		switch($argv[1])
		{
			case 'config':
				PrintConfig();
				break;
			case 'snmpconf':
				echo "require 1.3.6.1.6.4.1.42453.2.1.1. [0-9]\n";
				break;
		}
	}
	else
		PrintStats();
}

function PrintConfig()
{
	echo "graph_category Sensors\n";
	echo "graph_title Chassis temperature\n";
	echo "graph_vlabel Temperature (C)\n";
	echo "graph_args -l 0 --upper-limit 70\n";
	echo "graph_info Temperature of the PDU board\n";
	for($i=1; $i<=2; $i++)
	{
		echo "t$i.label Temp$i\n";
		//echo "t$i.warning 50\n";
		//echo "t$i.critical 60\n";
		echo "t$i.info Chassis temperature\n";
	}
}

function PrintStats()
{
	global $_ENV;
	
	//Load the MIB
	snmp_read_mib("/nfs4/home/azonenberg/code/antikernel/trunk/src/PDUFirmware/DRAWERSTEAK-MIB.my");
	snmp_read_mib("/nfs4/home/azonenberg/code/antikernel/trunk/src/PDUFirmware/PDU-MIB.my");
	
	//Get script name from symlink path
	sscanf(basename($_SERVER['PHP_SELF']), "snmp_%[^_]_temps.php", $host);
	
	//Default community string, load custom one if needed
	$community = "public";
	if(isset($_ENV['community']))
		$community = $_ENV['community'];

	//Don't return type hints
	snmp_set_valueretrieval(SNMP_VALUE_PLAIN);

	//Get the sensor stuff
	for($i=1; $i<=2; $i++)
		echo "t$i.value " . snmp2_get($host, $community, "PDU-MIB::tempSensors.$i") . "\n";
}
?>
