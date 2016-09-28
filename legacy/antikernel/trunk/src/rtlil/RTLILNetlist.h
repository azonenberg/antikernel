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
	@brief Declaration of RTLILNetlist
	
	IMPORTANT NOTE - this code only works on FLATTENED netlists with black-box cells and one parent module
 */
#ifndef RTLILNetlist_h
#define RTLILNetlist_h

class RTLILWire
{
public:

	enum directions
	{
		DIR_NONE = 0,
		DIR_IN = 1,
		DIR_OUT = 2,
		DIR_INOUT = 3
	};

	//default constructor for STL
	RTLILWire()
	{}
	
	RTLILWire(const RTLILWire& src);
	
	RTLILWire(
		std::string name, 
		std::map<std::string, std::string> attribs,
		int direction = RTLILWire::DIR_NONE,
		int npin=0);
		
	~RTLILWire();

	std::string		m_name;
	std::map<std::string, std::string> m_attributes;
	int				m_direction;
	int				m_npin;		//0 = not a top level port
	
	//Alternate names of this wire
	std::vector<RTLILWire*> m_altnames;
};

class RTLILModule;
class RTLILCellConnection;

class RTLILCell
{
public:

	//default constructor for STL
	RTLILCell()
	{}

	RTLILCell(std::string name, std::map<std::string, std::string> attribs, RTLILModule* module);
	~RTLILCell();
	
	std::string m_name;
	std::map<std::string, std::string> m_attributes;
	RTLILModule* m_module;
	
	//Local copies of the wires in the associated modules
	std::map<std::string, RTLILWire*> m_wires;
	
	//Connections to this cell from the parent module
	std::vector<RTLILCellConnection*> m_connections;
	
	bool IsBGA();
};

class RTLILCellConnection
{
public:
	RTLILCellConnection(RTLILWire* target, RTLILWire* parent);
	
	RTLILWire* m_cellWire;		//the wire in the target cell
	RTLILWire* m_parentWire;	//the wire in the parent module
};

class RTLILModule
{
public:
	RTLILModule(std::string name, std::map<std::string, std::string> attribs);
	~RTLILModule();
	
	std::string m_name;
	std::map<std::string, std::string> m_attributes;
	std::map<std::string, RTLILWire*> m_wires;
	std::map<std::string, RTLILCell*> m_cells;
	
	bool IsBGA();
};

/**
	@brief An RTLIL netlist
	
	Supports a limited subset of Yosys-generated RTLIL.
 */
class RTLILNetlist
{
public:
	RTLILNetlist(std::string fname);
	virtual ~RTLILNetlist();
	
	RTLILModule* m_top;
	std::map<std::string, RTLILModule*> m_modules;
	
	bool CompareNetNames(std::string a, std::string b);
	
	std::map<std::string, std::string> m_netpatches;
	
	std::string m_yosysVersion;
};

#endif
