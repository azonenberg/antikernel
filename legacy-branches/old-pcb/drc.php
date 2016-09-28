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
	@brief DRC for RTLIL containing PCB designs
 */

$g_genblocks = array();
$g_nextgenblock = 0;

//Sanity check and read the file
if($argc != 2)
	die("Usage: drc.php foo.rtlil\n");
$fname = $argv[1];
if(!file_exists($fname))
	die("input file doesn't exist\n");
main(file($fname), $fname);

function main($lines, $fname)
{
	$attributes = array();
	$modules = array();

	//Process top-level blocks and build the graph
	for($i=0; $i<count($lines); )
	{
		$str = trim($lines[$i]);
		
		//Skip comments and blank lines
		if( ($str == "") || ($str[0] == '#') )
		{
			$i++;
			continue;
		}
		
		//Process the keyword
		$words = explode(" ", $str);
		$keyword = $words[0];
		switch($keyword)
		{
		case 'attribute':
			$attributes[substr($words[1], 1)] = $words[2];
			$i++;
			break;
			
		case 'module':
			list($i, $mod) = ProcessModule($lines, $i + 1);
			$mod->attributes = $attributes;
			$attributes = array();
			
			$modules[$words[1]] = $mod;
			break;
			
		default:
			die("Unrecognized keyword $keyword\n");
		}
	}
	
	//Flatten the netlist, then run DRC and export
	$flat = FlattenNetlist($modules);
	//RunDRC($flat);
	WriteBOM($flat, "/nfs/home/azonenberg/Documents/local/temp/bom.txt", $fname);
	WriteCMP($flat, "/nfs/home/azonenberg/Documents/local/temp/test.cmp", $fname);
	WriteNET($flat, "/nfs/home/azonenberg/Documents/local/temp/test.net", $fname);
}

function ProcessModule($lines, $i)
{
	$attributes = array();
	$wires = array();
	$cells = array();
	$connections = array();
	
	for(; $i<count($lines); )
	{
		$str = trim($lines[$i]);
	
		//Skip comments and blank lines
		if( ($str == "") || ($str[0] == '#') )
		{
			$i++;
			continue;
		}
		
		//Process the keyword
		$words = explode(" ", $str);	
		$keyword = $words[0];
		switch($keyword)
		{
		case 'attribute':
			$aval = "";
			for($j=2; $j<count($words); $j++)
			{
				if($j != 2)
					$aval .= " ";
				$aval .= $words[$j];
			}
			$attributes[substr($words[1], 1)] = $aval;
			$i++;
			break;
			
		case 'wire':
		
			$w = new stdClass();
			$w->width = 1;
			$w->direction = 'local';
			$w->name = '';
			$w->pin = 0;
			$w->attributes = $attributes;
			$attributes = array();
			
			for($j=1; $j<count($words); $j++)
			{
				$s = $words[$j];
				
				if($s == 'inout')
					$w->direction = 'inout';
				else if($s == 'output')
					$w->direction = 'output';
				else if($s == 'input')
					$w->direction = 'input';
				else if($s == 'width')
				{
					$w->width = intval($words[$j+1]);
					$j++;
				}
				
				else if( $s[0] == '\\' )
					$w->name = substr($s, 1);
					
				else if(is_numeric($s))
					$w->pin = intval($s);
				
				else
					die("Unrecognized keyword $s in wire block\n");
			}
			$i ++;
			
			$wires[$w->name] = $w;
			
			break;
			
		case 'cell':
			list($i, $cell) = ProcessCell($lines, $i + 1);
			$cell->attributes = $attributes;
			$cell->modname = $words[1];
			$attributes = array();		
			$cells[ShortenIdentifier(substr($words[2], 1))] = $cell;
			break;
			
		case 'connect':
			if(substr_count($str, "{ }") != 0)
			{
			}
			else
			{		
				$wname = substr($words[2], 1);
				if(isset($words[3]))
					$wname .= ShortenIdentifier($words[3]);
				$connections[substr($words[1], 1)] = $wname;
			}
			$i ++;
			break;
			
		case 'end':
			$mod = new stdClass();
			$mod->wires = $wires;
			$mod->cells = $cells;
			$mod->connections = $connections;
			return array($i + 1, $mod);
			
		default:
			die("Unrecognized keyword $keyword in module (line $i)\n");
		}
	}
}

function ProcessCell($lines, $i)
{
	$parameters = array();
	$connections = array();
	
	for(; $i<count($lines); )
	{
		$str = trim($lines[$i]);
	
		//Skip comments and blank lines
		if( ($str == "") || ($str[0] == '#') )
		{
			$i++;
			continue;
		}
		
		//Process the keyword
		$words = explode(" ", $str);	
		$keyword = $words[0];
		switch($keyword)
		{
		case 'parameter':
			if($words[1] == "signed")
				$parameters[substr($words[2], 1)] = $words[3];
			else
				$parameters[substr($words[1], 1)] = $words[2];
			$i ++;
			break;
			
		case 'connect':
			if(substr_count($str, "{ }") != 0)
			{
			}
			else
			{		
				$wname = substr($words[2], 1);
				if(isset($words[3]))
					$wname .= $words[3];
				if(is_numeric($words[2][0]))
				{
					//Numeric value!
					//Should be 1' something because buses are split
					if(strpos($words[2], "1'") !== 0)
						die("Invalid numeric value " . $words[2] . "\n");
					
					$wname = '/supply/' . substr($words[2], 2);
				}
				$connections[substr($words[1], 1)] = $wname;
			}
			$i ++;
			break;
		
		case 'end':
			$cell = new stdClass();
			$cell->parameters = $parameters;
			$cell->connections = $connections;
			return array($i+1, $cell); 
		
		default:
			die("Unrecognized keyword $keyword in cell\n");
		}
	}
}

function FlattenNetlist($modules)
{
	//Find the top-level module
	$top = null;
	foreach($modules as $m)
	{
		if(isset($m->attributes['top']))
		{
			$top = $m;
			break;
		}
	}
	if(!$top)
		die("No top-level module specified");
	
	//Flatten the netlist hierarchy
	$changed = 1;
	while($changed)
	{
		//Make one pass over the list of cells
		$changed = 0;
		$newcells = array();
		
		foreach($top->cells as $name => $cell)
		{	
			//If the type is in the map, flatten it
			$type = $cell->modname;
			if(isset($modules[$type]))
			{						
				$cmod = $modules[$type];
				
				//See if the module is a black box
				//If so, don't flatten further
				if(isset($cmod->attributes['blackbox']))
					$newcells[$name] = $cell;
											
				//Nope, flatten
				else
				{				
					//Add all of its wires
					foreach($cmod->wires as $cname => $cval)
						$top->wires["$name/$cname"] = $cval;
					
					//Add all of its cells
					foreach($cmod->cells as $cname => $cval)
					{
						$ccval = clone $cval;
						foreach($cval->connections as $pname => $wname)
						{
							$old_wname = $wname;
							if($wname[0] != '/')
								$wname = "$name/$wname";						
							$ccval->connections[$pname] = $wname;
						}
						$newcells["$name/$cname"] = $ccval;
					}
					
					//Add all of its connections
					foreach($cmod->connections as $cname => $cval)
					{
						die("child module connections not implemented yet\n");
					}

					//Add parent connections
					foreach($cell->connections as $cname => $cval)
						$top->connections["$name/$cname"] = $cval;
						
					$changed = 1;
				}
			}
			
			//No, it's a primitive type - keep it
			else
				$newcells[$name] = $cell;
		}

		$top->cells = $newcells;
	}
	
	return $top;
}

function SortNets($a, $b)
{
	//Compare slashes first, higher level wins
	$sa = substr_count($a, "/");
	$sb = substr_count($b, "/");
	if($sa < $sb)
		return -1;
	else if($sa > $sb)
		return 1;
		
	//Nope, sort lexically
	return strcmp($sa, $sb);
}

function RunDRC($top)
{
	$has_error = 0;
	
	//Make a list of wires, alphabetically sorted
	$wirenames = array();
	foreach($top->wires as $name => $value)
		array_push($wirenames, $name);
	sort($wirenames);
	
	//Cell-level DRC
	foreach($top->cells as $name => $cell)
	{
		//Look for assertions
		if($cell->modname == "\$assert")
		{
			$a = $cell->connections['A'];
			$en = $cell->connections['EN'];
			$src = $cell->attributes['src'];
			
			if($en != '/supply/1')
			{
				echo "DRC ERROR: $src: Cannot evaluate assertion, enable condition is not constant\n";
				$has_error = 1;
			}
			if($a != '/supply/1')
			{
				echo "DRC ERROR: $src: Synthesis-time assertion failure\n";
				$has_error = 1;
			}
		}
		
		//Look for valueless cells
		else if(!isset($cell->parameters['value']))
		{
			echo "DRC error: Cell $name has no value\n";
			$has_error = 1;
		}
	}
	
	//Sort connections
	ksort($top->connections);
		
	//Make a list of connected wires
	$netgroups = array();
	foreach($wirenames as $name)
	{		
		//Do we have a connection?
		$conn = "";
		if(isset($top->connections[$name]))
			$conn = $top->connections[$name];
			
		//Get the wires connected to each endpoint
		$b1 = array();
		if(isset($netgroups[$conn]))
			$b1 = $netgroups[$conn];
		$b2 = array();
		if(isset($netgroups[$name]))
			$b2 = $netgroups[$name];
		
		//Merge the lists and remove duplicates
		$nwires = array_merge($b1, $b2);
		array_push($nwires, $name);
		if($conn != "")
			array_push($nwires, $conn);
		$nwires = array_unique($nwires);
			
		//See which bucket to use
		if( ($conn != "") && (SortNets($conn, $name) <= 0) )
		{
			$netgroups[$conn] = $nwires;
			unset($netgroups[$name]);
		}
		else
		{
			$netgroups[$name] = $nwires;
			unset($netgroups[$conn]);
		}
	}
	
	//Do consistency checking on each net group
	foreach($netgroups as $name => $group)
	{
		//Look up DRC type for each wire and assign default if not specified
		$wires = array();
		foreach($group as $wname)
		{
			$drc_type = 'unspecified';
			
			$wire = $top->wires[$wname];
			if(isset($wire->attributes['drc_type']))
				$drc_type = str_replace("\"", "", $wire->attributes['drc_type']);
			$wires[$wname] = $drc_type;
		}
		
		//Determine what kinds of nets we have
		$passives = array();	//save, but cannot conflict with anything
		$bidirs = array();
		$inputs = array();
		$outputs = array();
		$power_inputs = array();
		$power_outputs = array();
		$unspec = array();		//save, but cannot conflict with anything
		foreach($wires as $wname => $drc_type)
		{
			switch($drc_type)
			{
			case 'input':
				array_push($inputs, $wname);
				break;
			case 'bidir':
				array_push($bidirs, $wname);
				break;
			case 'output':
				array_push($outputs, $wname);
				break;
			case 'power_in':
				array_push($power_inputs, $wname);
				break;
			case 'power_out':
				array_push($power_outputs, $wname);
				break;
			case 'passive':
				array_push($passives, $wname);
				break;
			case 'unspecified':
				array_push($unspec, $wname);
				break;
			default:
				die("Unrecognized drc_type $drc_type\n");
				break;
			}
		}
		
		//Do class-level consistency checking
		$error = RunClassDRC($name, $passives, $bidirs, $inputs, $outputs, $power_inputs, $power_outputs, $unspec);

		//Print errors, if any
		if($error)
		{
			echo "    Nets connected to net group $name:\n";
			foreach($wires as $wname => $drc_type)
			{
				$src = '(unknown source file)';
				$wire = $top->wires[$wname];
				if(isset($wire->attributes['src']))
					$src = $wire->attributes['src'];
				printf("        %-20s (%12s) declared at %s\n", $wname, $drc_type, $src);
			}
			$has_error = 1;
		}
	}
	
	if($has_error)
	{
		echo "Aborting further processing due to DRC errors\n";
		//die;
	}
}

function RunClassDRC($name, $passives, $bidirs, $inputs, $outputs, $power_inputs, $power_outputs, $unspec)
{
	//Inputs must be driven (passives are OK - TODO trace fully)
	$error = 0;
	if(count($inputs))
	{
		if(
			(count($bidirs) == 0) &&
			(count($outputs) == 0) &&
			(count($power_outputs) == 0) &&
			(count($passives) == 0)
			)
		{
			echo "DRC ERROR: Net group $name contains an un-driven input\n";
			$error = 1;
		}
	}
	
	//Power inputs must be driven directly by power output
	$error = 0;
	if(count($inputs))
	{
		if(count($power_outputs) == 0)
		{
			echo "DRC ERROR: Net group $name contains an un-driven power input\n";
			$error = 1;
		}
	}
	
	//Power outputs can't short together
	if(count($power_outputs) > 1)
	{
		echo "DRC ERROR: Net group $name contains multiple power outputs\n";
		$error = 1;
	}
	
	//Outputs can't short together
	if(count($outputs) > 1)
	{
		echo "DRC ERROR: Net group $name contains multiple outputs\n";
		$error = 1;
	}
	
	//Passives must be connected to something else (unspecified nets don't count, they're just wires)
	if(count($passives) != 0)
	{
		$total =
			count($passives) + count($bidirs) + count($inputs) + count($outputs) + count($power_inputs) +
			count($power_outputs);
		if($total <= 1)
		{
			echo "DRC ERROR: Net group $name contains a floating passive\n";
			$error = 1;
		}
	}
	
	//TODO: Add additional design rules
	
	return $error;
}

function WriteBOM($netlist, $fname, $nlname)
{
	$fp = fopen($fname, "w");
	
	fprintf($fp, "BOM automatically generated from RTLIL netlist $nlname\n");
	fprintf($fp, "\n");
	
	ksort($netlist->cells);
	
	$distparts = array();
	
	//Print itemized BOM
	fprintf($fp, "===== Itemized BOM =====\n");
	foreach($netlist->cells as $name => $cell)
	{
		$dist = ReadStringParameter($cell->parameters['distributor']);
		$distpart = ReadStringParameter($cell->parameters['distributor_part']);
		$value = '';
		if(isset($cell->parameters['value']))
			$value = ReadStringParameter($cell->parameters['value']);
		
		//Print part info
		fprintf($fp, "Component %s\n", $name);
		fprintf($fp, "    Distributor:     %s\n", $dist);
		fprintf($fp, "    Distributor P/N: %s\n", $distpart);
		fprintf($fp, "    Value:           $value\n");
		fprintf($fp, "\n");
		
		//Add to inventory
		if(!isset($distparts[$dist]))
			$distparts[$dist] = array();
		if(!isset($distparts[$dist][$distpart]))
			$distparts[$dist][$distpart] = 1;
		else
			$distparts[$dist][$distpart] ++;
	}
	
	//Print shopping list
	fprintf($fp, "===== Shopping List =====\n");
	foreach($distparts as $distributor => $partlist)
	{
		fprintf($fp, "%s\n", $distributor);
		foreach($partlist as $part => $q)
			fprintf($fp, "    %-20s x%d\n", $part, $q);
	}
	
	fclose($fp);
}

function WriteNET($netlist, $fname, $nlname)
{
	$fp = fopen($fname, "w");
	
	fprintf($fp, "# EESchema Netlist Version 1.1 automatically generated from RTLIL netlist $nlname\n");
	fprintf($fp, "(\n");
	
	//Print out each cell's connections
	foreach($netlist->cells as $name => $cell)
	{
		$id = GenerateUniqueID($name);
		$type = str_replace("\\", "", $cell->modname);
		fprintf($fp, "    ( /$id \$noname $name $type {Lib=$type}\n");
		
		foreach($cell->connections as $pin => $net)
			fprintf($fp, "        ( $pin /$net )\n");

		fprintf($fp, "    )\n");
	}
	fprintf($fp, ")\n");
	
	//Footprint list
	fprintf($fp, "*\n");
	fprintf($fp, "{ Allowed footprints by component: \n");
	foreach($netlist->cells as $name => $cell)
	{
		fprintf($fp, "\$component $name\n");
		$type = str_replace("\\", "", $cell->modname);
		fprintf($fp, "    $type\n");
		fprintf($fp, "\$endlist\n");
	}
	fprintf($fp, "\$endfootprintlist\n");
	fprintf($fp, "}\n");
	
	//Pin list
	//fprintf($fp, "{ Pin List by Nets \n");
	//$count = 1;
	//foreach($netlist->connections as $
		/*
		{ Pin List by Nets
	Net 1 "" ""
	 R1 2
	 R2 2
	Net 2 "/TOP" "TOP"
	 R1 1
	 R2 1
	}
	#End
	*/
	
	fclose($fp);
}

function WriteCMP($netlist, $fname, $nlname)
{
	$fp = fopen($fname, "w");
	
	fprintf($fp, "Cmp-Mod V01 automatically generated from RTLIL netlist $nlname\n");
	fprintf($fp, "\n");
	
	foreach($netlist->cells as $name => $cell)
	{
		fprintf($fp, "BeginCmp\n");
		fprintf($fp, "TimeStamp = /%s\n", GenerateUniqueID($name));
		fprintf($fp, "Reference = %s\n", $name);
		$value = "";
		if(isset($cell->parameters['value']))
			$value = ReadStringParameter($cell->parameters['value']);
		fprintf($fp, "ValeurCmp = %s\n", $value);
		fprintf($fp, "IdModule  = %s\n", str_replace("\\", "", $cell->modname));
		fprintf($fp, "EndCmp\n\n");
	}
	
	fclose($fp);
	
	//print_r($netlist);
}

function GenerateUniqueID($name)
{
	//Use the first 32 bits of the MD5 of the string as a unique ID for now
	//TODO: High risk of collisions if we've got >2^16 components. Is this a problem for sane-sized schematics?
	return strtoupper(substr(md5($name), 0, 8));
}

function ShortenIdentifier($name)
{
	global $g_genblocks;
	global $g_nextgenblock;
	
	if(substr_count($name, '$genblock$') != 0)
	{
		//It's a "generate" block	
		//Format is $genblock$usb_hub_4port.v:111$1[0].port_ok_led_rs/dcell
		sscanf($name, '$genblock$%[^$]$%d%c%d%c.%s', $fname, $m, $ignore, $n, $ignore2, $iname);
		$search = "\$genblock\$$fname\$" . $m;
		
		//See if it's in the table already
		$replace = '';
		if(isset($g_genblocks[$fname]))
			$replace = $g_genblocks[$fname];
		else
		{
			$replace = '_gb' . $g_nextgenblock;
			$g_nextgenblock ++;
			$g_genblocks[$fname] = $replace;
		}
		
		$name = str_replace($search, $replace, $name);
		$name = str_replace("[", "!", $name);
		$name = str_replace("]", "!", $name);
	}
	
	return $name;
}

function ReadStringParameter($str)
{
	if($str[0] == '"')		//string
		return str_replace('"', '', $str);
	else if(substr_count($str, "'") != 0)
	{						//bit string
		$str = substr($str, strpos($str, "'") + 1);
		$ret = '';
		for($i=0; $i<strlen($str); $i += 8)
		{
			$ch = intval(substr($str, $i, 8), 2);
			if($ch != 0)
				$ret .= chr($ch);
		}
		return $ret;
	}
	else					//number
		return $str;
}

?>
