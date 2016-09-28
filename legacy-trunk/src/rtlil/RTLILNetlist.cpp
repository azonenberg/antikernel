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

#include "../jtaghal/jtaghal.h"
#include "RTLILNetlist.h"

using namespace std;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RTLILModule

RTLILModule::RTLILModule(string name, map<string, string> attribs)
	: m_name(name)
	, m_attributes(attribs)
{
	//Debug print
	/*
	printf("Found new module: %s\n", name.c_str());
	for(auto x : attribs)
		printf("    Attribute %s has value %s\n", x.first.c_str(), x.second.c_str());
	*/
}

RTLILModule::~RTLILModule()
{
	for(auto x : m_cells)
		delete x.second;
	m_cells.clear();
	
	for(auto x : m_wires)
		delete x.second;
	m_wires.clear();
}

bool RTLILModule::IsBGA()
{
	return (m_attributes["\\KICAD_PIN_NAMING"] == "BGA");
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RTLILWire

RTLILWire::RTLILWire(std::string name, std::map<std::string, std::string> attribs, int direction, int npin)
	: m_name(name),
	m_attributes(attribs), 
	m_direction(direction),
	m_npin(npin)
{	
	//Debug print
	/*
	printf("    Found new wire: name %s, direction %d, pin %d\n", name.c_str(), direction, npin);
	for(auto x : attribs)
		printf("        Attribute %s has value %s\n", x.first.c_str(), x.second.c_str());
	*/
}

RTLILWire::RTLILWire(const RTLILWire& src)
	: m_name(src.m_name),
	m_attributes(src.m_attributes),
	m_direction(src.m_direction),
	m_npin(src.m_npin)
{
}

RTLILWire::~RTLILWire()
{
	for(auto x : m_altnames)
		delete x;
	m_altnames.clear();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RTLILCell

RTLILCell::RTLILCell(std::string name, std::map<std::string, std::string> attribs, RTLILModule* module)
	: m_name(name),
	m_attributes(attribs),
	m_module(module)
{
	//Debug print
	/*
	printf("    Found new cell: name %s, type %s\n", name.c_str(), module->m_name.c_str());
	for(auto x : attribs)
		printf("        Attribute %s has value %s\n", x.first.c_str(), x.second.c_str());
	*/
		
	//Copy the wires
	for(auto x: module->m_wires)
		m_wires[x.first] = new RTLILWire(*x.second);
}

RTLILCell::~RTLILCell()
{
	for(auto x : m_connections)
		delete x;
	m_connections.clear();
	
	for(auto x : m_wires)
		delete x.second;
	m_wires.clear();
}

bool RTLILCell::IsBGA()
{
	return m_module->IsBGA();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RTLILCellConnection

RTLILCellConnection::RTLILCellConnection(RTLILWire* target, RTLILWire* parent)
	: m_cellWire(target),
	m_parentWire(parent)
{
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RTLILNetlist

RTLILNetlist::RTLILNetlist(string fname)
{
	bool verbose = false;
	
	m_top = NULL;
	
	//Open the file
	FILE* fp = fopen(fname.c_str(), "r");
	if(!fp)
	{
		throw JtagExceptionWrapper(
			string("Failed to open file ") + fname,
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Parse into lines, removing whitespace and comments
	char line[2048];
	vector<string> lines;
	while(NULL != fgets(line, sizeof(line), fp))
	{
		char* pline = line;
		while(isspace(*pline))
			pline++;
		for(int k=strlen(pline)-1; k>=0 && isspace(pline[k]); k--)
			pline[k] = '\0';			
		string sline(pline);
		
		//If this is the very first line of the file, and it begins with the standard Yosys comment
		//store the version number
		if(sline.find("# Generated by") != string::npos)
		{
			char tmp[128];
			if(1 == sscanf(sline.c_str(), "# Generated by %127[^\n]", tmp))
				m_yosysVersion = tmp;
		}
		
		if( (sline[0] != '#') && !sline.empty() )
			lines.push_back(sline);
	}
	
	enum
	{
		STATE_TOP,
		STATE_MODULE,
		STATE_CELL
	} state = STATE_TOP;
	
	//Process lines
	map<string, string> attributes;
	char name[128];
	char aval[512];
	RTLILModule* current_module = NULL;
	RTLILCell* current_cell = NULL;
	for(size_t i=0; i<lines.size(); i++)
	{	
		string& sline = lines[i];
		
		//Read opcode
		string opcode = sline;
		auto pos = sline.find(" ");
		if(pos != sline.npos)
			opcode = sline.substr(0, pos);
			
		//Save attributes
		if(opcode == "attribute")
		{
			if(2 != sscanf(sline.c_str(), "attribute %127s %511[^\n]", name, aval))
				continue;
			
			//strip quotes around string attributes
			char* sval = aval;
			if(sval[0] == '\"')
				sval ++;
			if(sval[strlen(sval)-1] == '\"')
				sval[strlen(sval)-1] = '\0';
				
			attributes[name] = sval;
		}
		
		//Process modules
		else if(opcode == "module")
		{
			//Sanity check scope
			if(state != STATE_TOP)
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Module declaration only valid at global scope"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			//Parse the name
			if(1 != sscanf(sline.c_str(), "module %127s", name))
				continue;
			
			//Create the module
			m_modules[name] = current_module = new RTLILModule(name, attributes);
			state = STATE_MODULE;
			
			//If the module has attribute "top" set then it's the top of the hierarchy
			if(attributes.find("\\top") != attributes.end())
				m_top = current_module;
			
			//Reset attributes
			attributes.clear();
		}
		
		//Process cells
		else if(opcode == "cell")
		{
			//Sanity check scope
			if(state != STATE_MODULE)
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Cell declaration only valid at module scope"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			state = STATE_CELL;
			
			char module_name[256];
			char instance_name[256];
			if(2 != sscanf(sline.c_str(), "cell %255s %255s", module_name, instance_name))
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Bad cell declaration"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			if(m_modules.find(module_name) == m_modules.end())
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Cell declared from invalid module type"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			RTLILModule* cell_module = m_modules[module_name];
			
			current_module->m_cells[instance_name] = current_cell = new RTLILCell(
				instance_name,
				attributes,
				cell_module);
			
			//Reset attributes
			attributes.clear();
		}
		
		//Process wires
		else if(opcode == "wire")
		{
			//Sanity check scope
			if(state != STATE_MODULE)
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Wire declaration only valid at module scope"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
			
			//Several different format types possible
			char wiretype[32];
			if(1 != sscanf(sline.c_str(), "wire %31s", wiretype))
				continue;
			string type(wiretype);
			
			//Inout wire (used on footprints)
			if(type == "inout")
			{
				int npin;
				char pinname[256];
				if(2 != sscanf(sline.c_str(), "wire inout %4d %255s", &npin, pinname))
				{
					fclose(fp);
					throw JtagExceptionWrapper(
						string("Bad wire inout declaratino"),
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
				}
				
				current_module->m_wires[pinname] = new RTLILWire(pinname, attributes, RTLILWire::DIR_INOUT, npin);
			}
			
			//Internal wire (not a port)
			else if(type[0] == '\\')
			{
				current_module->m_wires[type] = new RTLILWire(type, attributes);
			}
			
			//TODO
			else
			{
				printf("Wire type \"%s\" not implemented yet\n", wiretype);
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Unsupported wire type"),
					"",
					JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
			}
			
			attributes.clear();
		}
		
		//Process wires
		else if(opcode == "connect")
		{
			char from[256];
			char to[256];
			if(2 != sscanf(sline.c_str(), "connect %255s %255s", from, to))
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Invalid connect line"),
					"",
					JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
			}
			
			if(state == STATE_CELL)
			{
				//Look up the source wire
				if(current_cell->m_wires.find(from) == current_cell->m_wires.end())
				{
					fclose(fp);
					throw JtagExceptionWrapper(
						string("Invalid cell connection (expected a wire inside the cell)"),
						"",
						JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
				}
				RTLILWire* src = current_cell->m_wires[from];
				
				//Look up the dest wire
				if(current_module->m_wires.find(to) == current_module->m_wires.end())
				{
					fclose(fp);
					throw JtagExceptionWrapper(
						string("Invalid cell connection (expected a wire inside the parent module)"),
						"",
						JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
				}
				RTLILWire* dest = current_module->m_wires[to];
				
				//Hook it up
				current_cell->m_connections.push_back(new RTLILCellConnection(src, dest));
			}
			else if(state == STATE_MODULE)
			{
				//Connections within this module
				string sto = to;
				string sfrom = from;
				
				//If we have previous net-name changes to apply, do so
				while(m_netpatches.find(sto) != m_netpatches.end())
					sto = m_netpatches[sto];
				while(m_netpatches.find(sfrom) != m_netpatches.end())
					sfrom = m_netpatches[sfrom];
				
				//Look up the endpoint wires
				if(current_module->m_wires.find(sfrom) == current_module->m_wires.end())
				{
					fclose(fp);
					throw JtagExceptionWrapper(
						string("Invalid connection (expected a wire inside the parent module)"),
						"",
						JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
				}
				RTLILWire* src = current_module->m_wires[sfrom];
				if(current_module->m_wires.find(sto) == current_module->m_wires.end())
				{
					fclose(fp);
					throw JtagExceptionWrapper(
						string("Invalid connection (expected a wire inside the parent module)"),
						"",
						JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
				}
				RTLILWire* dest = current_module->m_wires[sto];
				
				//We've found the wires.
				//Decide which one should be kept
				if(!CompareNetNames(src->m_name, dest->m_name))
				{
					RTLILWire* tmp = dest;
					dest = src;
					src = tmp;
					
					sto = from;
					sfrom = to;
				}
				
				//Now src is the one we keep
				if(verbose)
					printf("Collapsing %s to %s\n", dest->m_name.c_str(), src->m_name.c_str());
				
				//If the wire being removed has alt names, add them to the one being kept
				for(auto x : dest->m_altnames)
					src->m_altnames.push_back(x);
				dest->m_altnames.clear();
				
				//Add the wire being removed as an alt name for the one being kept
				src->m_altnames.push_back(dest);
							
				//Go through all of our child cells and update connections from dest to src
				for(auto c : current_module->m_cells)
				{
					RTLILCell* cell = c.second;
					for(auto x : cell->m_connections)
					{
						if(x->m_parentWire == dest)
						{
							if(verbose)
							{
								printf("    Patching cell %s pin %s from %s to %s\n",
									cell->m_name.c_str(),
									x->m_cellWire->m_name.c_str(),
									dest->m_name.c_str(),
									src->m_name.c_str());
							}
							x->m_parentWire = src;
						}
					}
				}
				
				//Remove the wire being deleted from the netlist (don't erase it, though)
				current_module->m_wires.erase(sto);
				
				//Remember that we made this change
				m_netpatches[sto] = sfrom;
			}
			
			else
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("Connect declaration only valid at module/cell scope"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
		}
		
		//Done		
		else if(opcode == "end")
		{
			if(state == STATE_MODULE)
				state = STATE_TOP;
			else if(state == STATE_CELL)
				state = STATE_MODULE;
			else
			{
				fclose(fp);
				throw JtagExceptionWrapper(
					string("End declaration only valid at module/cell scope"),
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
			}
		}
		
		//ignore stuff we don't care about
		else if(opcode == "autoidx")
		{
			
		}
		
		//Done
		else
		{
			fclose(fp);
			throw JtagExceptionWrapper(
				string("Unknown opcode ") + opcode,
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
		}
	}
	
	//Done	
	fclose(fp);
	
	//If we don't have a top level module, complain
	if(m_top == NULL)
	{
		throw JtagExceptionWrapper(
			string("Netlist does not contain a top-level module"),
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

RTLILNetlist::~RTLILNetlist()
{
	for(auto x : m_modules)
		delete x.second;
	m_modules.clear();
}

//Determine which of two net names should be kept when simplifying
//returns true if a should be kept
bool RTLILNetlist::CompareNetNames(std::string a, std::string b)
{
	size_t dots_a = 0;	
	size_t dots_b = 0;
	for(size_t i=0; i<a.length(); i++)
	{
		if(a[i] == '.')
			dots_a ++;
	}
	for(size_t i=0; i<b.length(); i++)
	{
		if(b[i] == '.')
			dots_b ++;
	}
	
	//If B has more dots, A is the canonical name
	if(dots_b > dots_a)
		return true;
	
	//otherwise decide based on length (shorter is better)
	else if(b.length() > a.length())
		return true;
		
	return false;
}
