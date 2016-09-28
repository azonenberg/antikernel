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
	@brief RTLIL to KiCAD netlist converter
 */
 
#include "rtl2pcb.h"

using namespace std;

void ShowUsage();
void ShowVersion();

void DRC(RTLILNetlist& net);
void DRC(RTLILWire* wire);
void DRC_PowerVoltage(RTLILWire* wire, int power_voltage, string power_voltage_source);

void GenerateBOM(RTLILNetlist& net, FILE* fp);

void SaveToKicadNetlist(RTLILNetlist& net, string outfile, string infile);

string FixUpIdentifier(string name);

/**
	@brief Program entry point
 */
int main(int argc, char* argv[])
{
	bool nobanner = false;
	string infile = "";
	string outfile = "";
	
	//Parse command-line arguments
	for(int i=1; i<argc; i++)
	{
		string s(argv[i]);
		
		if(s == "--help")
		{
			ShowUsage();
			return 0;
		}
		else if(s == "--nobanner")
			nobanner = true;
		else if(s == "--version")
		{
			ShowVersion();
			return 0;
		}
		else if(s[0] != '-')
		{
			if(infile == "")
				infile = argv[i];
			else if(outfile == "")
				outfile = argv[i];
			else
			{
				printf("Only expected two file arguments\n");
				return 1;
			}
		}
		else
		{
			printf("Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
			return 1;
		}
	}
	
	if( (infile == "") || (outfile == "") )
	{
		ShowUsage();
		return 0;
	}
	
	//Print version number by default
	if(!nobanner)
		ShowVersion();
		
	try
	{		
		//Read the RTLIL netlist
		RTLILNetlist input_netlist(infile);
		
		//Run sanity checks on it
		DRC(input_netlist);
		
		//Save it
		SaveToKicadNetlist(input_netlist, outfile, infile);
		
		//Generate the BOM (TODO send to a file)
		GenerateBOM(input_netlist, stdout);
	}
	catch(const JtagException& ex)
	{
		printf("%s\n", ex.GetDescription().c_str());
		return 1;
	}

	
	return 0;
}

/**
	@brief Prints program usage information
	
	\ingroup elfsign
 */
void ShowUsage()
{
	printf(
		"Usage: rtl2pcb [args] infile.rtlil outfile.net\n"
		"\n"
		"General arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --version                                        Prints program version number and exits.\n"
		"\n"
		);
}

/**
	@brief Prints program version number
 */
void ShowVersion()
{
	printf(
		"RTLIL to KiCAD netlist converter [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}

void SaveToKicadNetlist(RTLILNetlist& net, string outfile, string infile)
{
	printf("Generating exported netlist\n");
	
	FILE* fp = fopen(outfile.c_str(), "w");
	if(!fp)
	{
		throw JtagExceptionWrapper(
			string("Failed to open file ") + outfile,
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Format the time
	time_t rtime;
	time(&rtime);
	tm* now = localtime(&rtime);
	char stime[128];
	strftime(stime, sizeof(stime), "%c %Z", now);
	char sdate[128];
	strftime(sdate, sizeof(sdate), "%Y-%m-%d", now);
	
	//Write the netlist header
	fprintf(fp, "(export (version D)\n");
	fprintf(fp, "  (design\n");
	fprintf(fp, "    (source %s)\n", infile.c_str());	
	fprintf(fp, "    (date \"%s\")\n", stime);
	fprintf(fp, "    (tool \"rtl2pcb rev %s, source netlist produced by %s\")\n",
		SVNVERSION, net.m_yosysVersion.c_str());
	fprintf(fp, "    (sheet (number 1) (name /) (tstamps /)\n");
	fprintf(fp, "      (title_block\n");
	fprintf(fp, "        (title \"rtl2pcb generated design\")\n");
	fprintf(fp, "        (company  \"Andrew Zonenberg\")\n");
	fprintf(fp, "        (rev 0.1)\n");
	fprintf(fp, "        (date %s)\n", sdate);
	fprintf(fp, "        (source %s)\n", infile.c_str());
	fprintf(fp, "        (comment (number 1) (value ""))\n");
	fprintf(fp, "        (comment (number 2) (value ""))\n");
	fprintf(fp, "        (comment (number 3) (value ""))\n");
	fprintf(fp, "        (comment (number 4) (value "")))))\n");
	
	//Write the components
	fprintf(fp, "  (components\n");
	for(auto x : net.m_top->m_cells)
	{
		RTLILCell* cell = x.second;
		RTLILModule* module = cell->m_module;
		const char* refdes = cell->m_name.c_str() + 1;
		
		//TODO: Find a better way to do this
		//For now, do a hash of the refdes
		unsigned char hash[32];
		CryptoPP::SHA256().CalculateDigest(hash, (const unsigned char*)&refdes[0], strlen(refdes));
		
		string value = cell->m_attributes["\\value"];
		string units = cell->m_attributes["\\units"];
		
		//TODO: Cleanup of weird integer units (like thousands of nF)
		
		fprintf(fp, "    (comp (ref %s)\n", refdes);
		fprintf(fp, "      (value \"%s%s\")\n",
			value.c_str(),
			units.c_str());
		fprintf(fp, "      (footprint %s:%s)\n",
			module->m_attributes["\\KICAD_LIBRARY"].c_str(),
			module->m_attributes["\\KICAD_MODULE_NAME"].c_str()
			);
		fprintf(fp, "      (libsource (lib hdl-autogenerated) (part \"%s\"))\n",
			FixUpIdentifier(module->m_name).c_str());
		fprintf(fp, "      (sheetpath (names /) (tstamps /))\n");
		fprintf(fp, "      (tstamp %08X))\n", (hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]);
	}
	fprintf(fp, "  )\n");
	
	//Generate a fictional schematic library
	fprintf(fp, "  (libparts\n");
	for(auto x : net.m_modules)
	{
		RTLILModule* module = x.second;
		
		//Don't make a library entry for the top-level module
		if(module == net.m_top)
			continue;
		
		//Header of the module
		fprintf(fp, "    (libpart (lib hdl-autogenerated) (part %s)\n",
			FixUpIdentifier(module->m_name).c_str());
		fprintf(fp, "      (description Verilog component declared at %s)\n",
			module->m_attributes["\\src"].c_str());
		fprintf(fp, "      (fields\n");
		fprintf(fp, "        (field (name Reference) V)\n");
		fprintf(fp, "        (field (name Value) \"%s\"))\n",
			module->m_attributes["\\value"].c_str());
			
		//The pins
		fprintf(fp, "      (pins\n");
		for(auto y : module->m_wires)
		{
			RTLILWire* wire = y.second;
			
			//If it's not a port, skip it
			if(wire->m_direction == RTLILWire::DIR_NONE)
				continue;
			
			//Find the direction
			string dir = "";
			switch(wire->m_direction)
			{
			case RTLILWire::DIR_IN:
				dir = "input";
				break;
			case RTLILWire::DIR_INOUT:
				dir = "BiDi";
				break;
			case RTLILWire::DIR_OUT:
				dir = "output";
				break;
			}
			
			//Get the pin name, stripping off the "P" prefix for non-BGA parts
			//Have to check if the next byte is a digit or we'll screw up 'PAD' / 'SHIELD' pin names
			const char* pin_name = wire->m_name.c_str() + 1;	
			if(!module->IsBGA() && isdigit(pin_name[1]))
				pin_name ++;
				
			fprintf(fp, "        (pin (num %s) (name %s) (type %s))\n",
				pin_name, wire->m_name.c_str(), dir.c_str());
		}
		fprintf(fp, "        ))\n");
	}
	fprintf(fp, "  )\n");
	
	//Write the libraries
	fprintf(fp, "  (libraries\n");
	fprintf(fp, "    (library (logical hdl-autogenerated)\n");
	fprintf(fp, "      (uri /dev/null))\n");
	fprintf(fp, "  )\n");
	
	//Make a list of pins that connect to each device
	typedef std::pair<RTLILCell*, RTLILWire*> CellToWirePair;
	std::map<RTLILWire*, std::vector< CellToWirePair > > cellmap;
	for(auto y : net.m_top->m_cells)
	{
		RTLILCell* cell = y.second;
		for(auto z : cell->m_connections)
			cellmap[z->m_parentWire].push_back(CellToWirePair(cell, z->m_cellWire));
	}
	
	//Write the nets and close the netlist
	fprintf(fp, "  (nets\n");
	int netnum = 1;
	for(auto x : net.m_top->m_wires)
	{
		RTLILWire* wire = x.second;
		fprintf(fp, "    (net (code %d) (name %s)\n",
			netnum, x.first.c_str() + 1);
		
		for(auto y : cellmap[wire])
		{
			RTLILCell* cell = y.first;
			const char* pin_name = y.second->m_name.c_str() + 1;
			if(!cell->IsBGA() && isdigit(pin_name[1]))
				pin_name ++;
			
			fprintf(fp, "      (node (ref %s) (pin %s))\n",
				cell->m_name.c_str() + 1, 
				pin_name
				);
		}		
		
		netnum ++;
		fprintf(fp, "      )\n");
	}
	fprintf(fp, "  ))\n");
	
	fclose(fp);
}

string FixUpIdentifier(string name)
{
	for(size_t i=0; i<name.length(); i++)
	{
		if( (name[i] == '\\') || (name[i] == '$') )
			name[i] = '_';
	}
	return name;
}

void DRC(RTLILNetlist& net)
{
	printf("Running post-synthesis DRC...\n");
	
	//Do separate DRCing for each net
	for(auto iw : net.m_top->m_wires)
		DRC(iw.second);
}

void DRC(RTLILWire* wire)
{	
	//Find interesting attributes on the signal, including alt names
	bool	has_power_voltage	= false;
	string	power_voltage_source	= "";
	int		power_voltage	= 0;
	if(wire->m_attributes.find("\\POWER_VOLTAGE") != wire->m_attributes.end())
	{
		has_power_voltage = true;
		power_voltage_source = wire->m_name;
		power_voltage = atoi(wire->m_attributes["\\POWER_VOLTAGE"].c_str());
	}
	for(auto x : wire->m_altnames)
	{
		if(x->m_attributes.find("\\POWER_VOLTAGE") != x->m_attributes.end())
		{
			int new_voltage = atoi(x->m_attributes["\\POWER_VOLTAGE"].c_str());
			
			//If we already have a POWER_VOLTAGE attribute, this is a problem!
			//TODO: Allow paralleling of SMPS outputs etc
			if(has_power_voltage)
			{	
				//If they are different voltages, that's an error
				if(new_voltage != power_voltage)
				{
					fprintf(stderr, "ERROR: Multiple power outputs with different voltage are connected!\n");
					fprintf(stderr, "    This will almost certainly result in a short circuit.\n");
					fprintf(stderr, "    %s (%.2f V)\n",
						power_voltage_source.c_str(),
						power_voltage * 0.001f);
					fprintf(stderr, "    %s (%.2f V)\n",
						x->m_name.c_str(),
						new_voltage*0.001f);
				}
				
				//Warn if they're the same
				//Don't warn about connecting grounds together, thoguh
				else if(new_voltage != 0)
				{
					fprintf(stderr, "WARNING: Multiple power outputs with same voltage are connected!\n");
					fprintf(stderr, "    This is probably not what you want.\n");
					fprintf(stderr, "    %s (%.2f V)\n",
						power_voltage_source.c_str(),
						power_voltage * 0.001f);
					fprintf(stderr, "    %s (%.2f V)\n",
						x->m_name.c_str(),
						new_voltage*0.001f);
				}
			}
			
			//Nope, save the new voltage
			has_power_voltage = true;
			power_voltage_source = x->m_name;
			power_voltage = new_voltage;
		}
	}
	
	//Check the list of found attributes against everything
	if(has_power_voltage)
	{
		DRC_PowerVoltage(wire, power_voltage, power_voltage_source);
		for(auto x : wire->m_altnames)
			DRC_PowerVoltage(x, power_voltage, power_voltage_source);
	}
}

void DRC_PowerVoltage(RTLILWire* wire, int power_voltage, string power_voltage_source)
{
	if(wire->m_attributes.find("\\MIN_POWER_VOLTAGE") != wire->m_attributes.end())
	{
		int min_voltage = atoi(wire->m_attributes["\\MIN_POWER_VOLTAGE"].c_str());
		if(power_voltage < min_voltage)
		{
			fprintf(
				stderr,
				"ERROR: Net %s supply voltage is too low\n"
				"    (driven with %.2f V by %s, datasheet minimum is %.2f V)\n",
				wire->m_name.c_str(), power_voltage*0.001f, power_voltage_source.c_str(), min_voltage*0.001f);
		}
	}
	
	if(wire->m_attributes.find("\\MAX_POWER_VOLTAGE") != wire->m_attributes.end())
	{
		int max_voltage = atoi(wire->m_attributes["\\MAX_POWER_VOLTAGE"].c_str());
		if(power_voltage > max_voltage)
		{
			fprintf(
				stderr,
				"ERROR: Net %s supply voltage is too high\n"
				"    (driven with %.2f V by %s, datasheet maximum is %.2f V)\n",
				wire->m_name.c_str(), power_voltage*0.001f, power_voltage_source.c_str(), max_voltage*0.001f);
		}
	}
}

void GenerateBOM(RTLILNetlist& /*net*/, FILE* /*fp*/)
{
	
}
