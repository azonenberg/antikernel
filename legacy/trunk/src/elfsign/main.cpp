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
	@brief Signing tool for ELF executables
	
	\ingroup elfsign
 */
 
/** 
	\defgroup elfsign elfsign: signing tool for ELF executables
	
	elfsign is released under the same permissive 3-clause BSD license as the remainder of the project.	
	
	The current ELF signature is computed over the following data:
		* e_entry
		* All program headers with PT_LOAD set, in the order that they appear in the file
		
	The signature is a HMAC-SHA256, with a fixed 512-bit key derived from the SHA-512 of the signing password.
 */
 
/**
	\page elfsign_usage Usage
	\ingroup elfsign
	
	TODO: Write stuff
	
	General arguments:
	
	\li --help<br/>
	Displays help and exits.
	
	\li --version<br/>
	Prints program version number and exits.
	
 */
 
#include "elfsign.h"

using namespace std;

void ShowUsage();
void ShowVersion();

/**
	@brief Program entry point
	
	\ingroup elfsign
 */
int main(int argc, char* argv[])
{
	int err_code = 0;

	bool nobanner = false;
	bool password_set = false;
	unsigned char hmac_key[64] = {0};
	string fname = "";
	bool sign = false;
	bool debug = false;
	
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
		else if(s == "--sign")
			sign = true;
		else if(s == "--debug")
			debug = true;
		else if(s == "--password")
		{
			password_set = true;
			const char* password = argv[++i];
			CryptoPP::SHA512().CalculateDigest(hmac_key, (unsigned char*)password, strlen(password));
		}
		else if(s == "--version")
		{
			ShowVersion();
			return 0;
		}
		else if(s[0] != '-')
			fname = argv[i];
		else
		{
			printf("Unrecognized command-line argument \"%s\", use --help\n", s.c_str());
			return 1;
		}
	}
	
	//Print version number by default
	if(!nobanner)
		ShowVersion();
		
	//Sanity check
	if(!password_set)
	{
		printf("HMAC password not specified\n");
		return 1;
	}
	if(fname == "")
	{
		printf("File not specified\n");
		return 1;
	}
	
	//Parse the ELF
	int fd = open(fname.c_str(), O_RDWR);
	if(fd < 0)
	{
		printf("Failed to open ELF image\n");
		return 1;
	}
	uint32_t len = lseek(fd, 0, SEEK_END);
	lseek(fd, 0, SEEK_SET);
	printf("File opened, length is %d bytes\n", len);
	uint32_t* base = reinterpret_cast<uint32_t*>( mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0) );
	if(base == MAP_FAILED)
	{
		printf("Failed to map file\n");
		return 1;
	}
	
	Elf32_Ehdr* ehdr = reinterpret_cast<Elf32_Ehdr*>(base);
	
	//Read the ELF magic number and sanity check it
	if(	(ehdr->e_ident[EI_MAG0] != ELFMAG0) ||
		(ehdr->e_ident[EI_MAG1] != ELFMAG1) ||
		(ehdr->e_ident[EI_MAG2] != ELFMAG2) ||
		(ehdr->e_ident[EI_MAG3] != ELFMAG3) 
		)
	{
		printf("Bad magic number (file doesn't seem to be a valid ELF)\n");
		return 1;
	}
	
	//Verify it's for MIPS
	if(ehdr->e_ident[EI_CLASS] != ELFCLASS32)
	{
		printf("Not a 32-bit ELF file\n");
		return 1;
	}
	if(ehdr->e_ident[EI_DATA] != ELFDATA2MSB)
	{
		printf("Not a big-endian ELF file\n");
		return 1;
	}
	if(ehdr->e_ident[EI_VERSION] != EV_CURRENT)
	{
		printf("Invalid ELF version\n");
		return 1;
	}
	if(ntohs(ehdr->e_type) != ET_EXEC)
	{
		printf("Not an executable\n");
		return 1;
	}
	if(ntohs(ehdr->e_machine) != EM_MIPS)
	{
		printf("Not a MIPS executable\n");
		return 1;
	}
	
	//Read entry point
	uint32_t entry = ntohl(ehdr->e_entry);
	printf("Entry point = virtual 0x%08x\n", entry);
	
	//Read program headers
	uint32_t phoff = ntohl(ehdr->e_phoff);
	if(phoff & 3)
	{
		printf("Bad (unaligned) phoff\n");
		return 1;
	}
	uint32_t phwordoff = phoff/4;
	printf("Program headers are located at byte offset %d (word offset %d)\n", phoff, phwordoff);
	uint16_t phentsize = ntohs(ehdr->e_phentsize) & 0xffff;
	uint16_t phnum = ntohs(ehdr->e_phnum);
	uint16_t phwordsize = phentsize / 4;
	printf("    phentsize = %d words, %d program headers total\n", phwordsize, phnum);
	if( (phentsize & 3) || (phentsize != sizeof(Elf32_Phdr)) )
	{
		printf("Bad phentsize\n");
		return 1;
	}
	
	//Data being signed is the entry point address (in target endianness)
	//plus the contents of all non-null loadable segments
	vector<uint32_t> data_to_sign;
	data_to_sign.push_back(ehdr->e_entry);
	
	//Read the program header table
	Elf32_Phdr* phdrs = reinterpret_cast<Elf32_Phdr*>(base + phwordoff);
	bool foundsig = false;
	uint32_t sigoff_bytes = 0;
	for(uint16_t i=0; i<phnum; i++)
	{
		printf("Program header %u\n", i);
				
		//Crunch loadable segments
		uint32_t type = ntohl(phdrs[i].p_type);
		if(type == PT_LOAD)
		{
			if(ntohl(phdrs[i].p_vaddr) == 0)
				printf("    Loadable but mapped at NULL address, ignoring\n");
			else
			{
				printf("    Loadable\n");
				printf("    File offset: 0x%x\n", ntohl(phdrs[i].p_offset));
				printf("    Virtual addr: 0x%08x\n", ntohl(phdrs[i].p_vaddr));
				printf("    Size on disk: %d bytes\n", ntohl(phdrs[i].p_filesz));
				printf("    Size in mem: %d bytes\n", ntohl(phdrs[i].p_filesz));
				printf("    Alignment: %d\n", ntohl(phdrs[i].p_align));
				
				uint32_t* sbase = base + (ntohl(phdrs[i].p_offset))/4;
				uint32_t diskwordsize = ntohl(phdrs[i].p_filesz) / 4;
				
				for(uint32_t j=0; j<diskwordsize; j++)
					data_to_sign.push_back(sbase[j]);
			}
		}
		else if(type == (PT_LOPROC + 5))		//SIGNATURE
		{
			printf("    Signature block\n");
			sigoff_bytes = ntohl(phdrs[i].p_offset);
			printf("    File offset: 0x%x\n", sigoff_bytes);
			uint32_t sigsize_bytes = ntohl(phdrs[i].p_filesz);
			printf("    Size on disk: %d bytes\n", sigsize_bytes);
			if(sigsize_bytes != 32)
			{
				printf("    Signature size should be 32 bytes, found something else\n");
				return 1;
			}
			foundsig = true;
		}
		else
			printf("    Type %x is not loadable\n", type);
	}
	
	//Print out data being hashed
	if(debug)
	{
		printf("Data being hashed:\n");
		for(size_t i=0; i<data_to_sign.size(); i++)
		{
			printf("%08x ", ntohl(data_to_sign[i]));
			if( (i & 15) == 15 )
				printf("\n");
		}
		printf("\n");
	}
	
	//Check the signature
	if(foundsig)
	{
		//Compute the expected signature
		unsigned char hmac[32];
		CryptoPP::HMAC<CryptoPP::SHA256> hasher(hmac_key, 64);
		hasher.CalculateDigest(hmac, (const unsigned char*)&data_to_sign[0], data_to_sign.size()*4);
		
		//Print it
		printf("Expected signature: ");
		for(int i=0; i<32; i+=2)
			printf("%02x%02x ", hmac[i] & 0xff, hmac[i+1] & 0xff);
		printf("\n");
		
		//Look up the actual signature in the file
		unsigned char* signature_base = reinterpret_cast<unsigned char*>(base) + sigoff_bytes;
		printf("Actual signature:   ");
		for(int i=0; i<32; i+=2)
			printf("%02x%02x ", signature_base[i] & 0xff, signature_base[i+1] & 0xff);
		printf("\n");
		
		//Determine current state of the signature
		if(memcmp(signature_base, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 32) == 0)
			printf("File is currently not signed\n");
		else if(memcmp(signature_base, hmac, 32) == 0)
			printf("Valid signature\n");
		else
			printf("Invalid signature\n");
			
		//Sign it if requested
		if(sign)
		{
			printf("Replacing signature with expected value\n");
			memcpy(signature_base, hmac, 32);
		}
	}
	
	else
		printf("No signature block found, cannot verify or update signature\n");


	//Done
	munmap(base, len);
	close(fd);
	return err_code;
}

/**
	@brief Prints program usage information
	
	\ingroup elfsign
 */
void ShowUsage()
{
	/*
	printf(
		"Usage: elnobannerfsign [args]\n"
		"\n"
		"General arguments:\n"
		"    --help                                           Displays this message and exits.\n"
		"    --nobanner                                       Do not print version number on startup.\n"
		"    --password [password]                            Specifies the signing key to use\n"
		"    --sign                                           Sign the file (and verify the previous signature, if any)\n"
		"    [filename]                                       Name of the file to sign\n"
		"    --version                                        Prints program version number and exits.\n"
		"\n"
		);
	*/
}

/**
	@brief Prints program version number
	
	\ingroup elfsign
 */
void ShowVersion()
{
	printf(
		"ELF signing tool [SVN rev %s] by Andrew D. Zonenberg.\n"
		"\n"
		"License: 3-clause (\"new\" or \"modified\") BSD.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n"
		"\n"
		, SVNVERSION);
}
