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
	@brief NoC topology simulator
 */
#include "nocsim.h"

using namespace std;

unsigned int g_hostCount = 256;
unsigned int g_time = 0;

set<SimNode*> g_simNodes;

void CreateQuadtreeNetwork();
void RunSimulation();

int main(int argc, char* argv[])
{
	Severity console_verbosity = Severity::NOTICE;

	//Parse command-line arguments
	for(int i=1; i<argc; i++)
	{
		string s(argv[i]);

		//Let the logger eat its args first
		if(ParseLoggerArguments(i, argc, argv, console_verbosity))
			continue;

		if(false)
		{}
		else
		{
			printf("Unrecognized command-line argument \"%s\"\n", s.c_str());
			return 1;
		}
	}

	//Set up logging
	g_log_sinks.emplace(g_log_sinks.begin(), new ColoredSTDLogSink(console_verbosity));

	//Fun stuff here!
	CreateQuadtreeNetwork();
	RunSimulation();

	//Clean up
	for(auto p : g_simNodes)
		delete p;
	g_simNodes.clear();

	//All good
	return 0;
}

/**
	@brief Create a network using the quadtree topology
 */
void CreateQuadtreeNetwork()
{
	set<QuadtreeRouter*> routers;
	set<QuadtreeRouter*> new_routers;

	//Seed things by creating a root router
	unsigned int size = g_hostCount;
	unsigned int mask = 0xffff & ~(size - 1);
	unsigned int base = 0;
	auto root = new QuadtreeRouter(NULL, base, base + size - 1, mask);
	g_simNodes.emplace(root);
	routers.emplace(root);

	LogNotice("Creating network (quadtree topology) with %d hosts\n", root->GetSubnetSize());
	LogIndenter li;

	//Create each row of the tree
	bool done = false;
	int nrouters = 0;
	int nhosts = 0;
	while(!done)
	{
		new_routers.clear();

		//For each parent router in our list, add four child nodes
		for(auto r : routers)
		{
			//Figure out the new subnet size and mask
			size = r->GetSubnetSize() / 4;
			mask = 0xffff & ~(size - 1);
			base = r->GetSubnetBase();

			//Create the new routers
			for(int i=0; i<4; i++)
			{
				unsigned int cbase = base + i*size;

				//If child subnet size is 1, create hosts instead
				if(size == 1)
				{
					auto child = new NOCHost(cbase, r);
					g_simNodes.emplace(child);
					nhosts ++;
					//LogDebug("Creating host at %u\n", cbase);
				}

				else
				{
					auto child = new QuadtreeRouter(r, cbase, cbase + size - 1, mask);
					//LogDebug("Creating router at %u (size %u)\n", cbase, size);
					g_simNodes.emplace(child);
					new_routers.emplace(child);
					nrouters ++;
				}
			}

			//Finish after this iteration if we're creating hosts
			if(size == 1)
				done = true;
		}

		routers = new_routers;
	}

	LogVerbose("Created %d routers\n", nrouters);
	LogVerbose("Created %d hosts\n", nhosts);
}

/**
	@brief Run the discrete event simulation
 */
void RunSimulation()
{
	for(g_time = 0; g_time < 100; g_time ++)
	{
		for(auto n : g_simNodes)
			n->Timestep();
	}
}
