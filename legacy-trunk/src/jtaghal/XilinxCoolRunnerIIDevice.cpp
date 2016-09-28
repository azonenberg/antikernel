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
	@brief Implementation of XilinxCoolRunnerIIDevice
 */

#include "jtaghal.h"
#include "XilinxCoolRunnerIIDevice.h"
#include "XilinxCPLDBitstream.h"
#include "memory.h"

using namespace std;

XilinxCoolRunnerIIDevice::XilinxCoolRunnerIIDevice(
	unsigned int devid, unsigned int package_decoded, unsigned int stepping,
	unsigned int idcode, JtagInterface* iface, size_t pos)
 : XilinxCPLD(idcode, iface, pos)
{
	m_devid = devid;
	m_package = package_decoded;
	m_stepping = stepping;
	m_irlength = 8;
}

/**
	@brief Destructor
 */
XilinxCoolRunnerIIDevice::~XilinxCoolRunnerIIDevice()
{
}

JtagDevice* XilinxCoolRunnerIIDevice::CreateDevice(unsigned int idcode, JtagInterface* iface, size_t pos)
{
	//Parse the ID code
	unsigned int stepping = idcode >> 28;				//ignore for now
	unsigned int arch = (idcode >> 25) & 0x3;			//must always be 3
	unsigned int tech = (idcode >> 22) & 0x3;			//must always be 3
	unsigned int devid = (idcode >> 16) & 0x3f;			//device ID
	unsigned int volt = (idcode >> 15) & 0x1;			//must always be 1
	unsigned int package = (idcode >> 12) & 0x7;		//device-dependent package ID
	unsigned int manuf = (idcode >> 1) & 0x3FF;			//must always be IDCODE_XILINX
	unsigned int always_one = (idcode & 1);				//must always be 1

	//Sanity check constant fields
	if( (arch != 3) || (tech != 3) || (volt != 1) || (manuf != IDCODE_XILINX) || (always_one != 1))
	{
		throw JtagExceptionWrapper(
			"Invalid ID code (constant fields do not match expected CoolRunner-II values)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Decode package info
	int package_decoded = -1;
	switch(devid)
	{
	case XC2C32:
	case XC2C32A:
		{
			switch(package)
			{
			case 1:
				package_decoded = QFG32;
				break;
			case 3:
				package_decoded = CPG56;
				break;
			case 4:
				package_decoded = VQG44;
				break;
			default:
				throw JtagExceptionWrapper(
					"Device is an XC2C32 or 32A but the package ID was not recognized",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
				break;
			}
		}
		break;
		
	case XC2C64:
	case XC2C64A:
		{
			switch(package)
			{
			case 6:
				package_decoded = VQG44;
				break;
			case 1:
				package_decoded = QFG48;
				break;
			case 5:
				package_decoded = CPG56;
				break;
			case 4:
				package_decoded = VQG100;
				break;
			case 3:
				package_decoded = CPG132;
				break;
			default:
				throw JtagExceptionWrapper(
					"Device is an XC2C64 or 64A but the package ID was not recognized",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
				break;
			}
		}
		break;
	
	case XC2C128:
		{
			switch(package)
			{
			case 2:
				package_decoded = VQG100;
				break;
			case 3:
				package_decoded = CPG132;
				break;
			case 4:
				package_decoded = TQG144;
				break;
			case 6:
				package_decoded = FTG256;
				break;
			default:
				throw JtagExceptionWrapper(
					"Device is an XC2C128 but the package ID was not recognized",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
				break;
			}
		}
		break;
	
	case XC2C256:
		{
			switch(package)
			{
			case 2:
				package_decoded = VQG100;
				break;
			case 3:
				package_decoded = CPG132;
				break;
			case 4:
				package_decoded = TQG144;
				break;
			case 5:
				package_decoded = PQG208;
				break;
			case 6:
				package_decoded = FTG256;
				break;
			default:
				throw JtagExceptionWrapper(
					"Device is an XC2C256 but the package ID was not recognized",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
				break;
			}
		}
		break;
	
	case XC2C384:
		{
			switch(package)
			{
			case 4:
				package_decoded = TQG144;
				break;
			case 5:
				package_decoded = PQG208;
				break;
			case 7:
				package_decoded = FTG256;
				break;
			case 2:
				package_decoded = FGG324;
				break;
			default:
				throw JtagExceptionWrapper(
					"Device is an XC2C384 but the package ID was not recognized",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
				break;
			}
		}
		break;
	
	case XC2C512:
		{
			switch(package)
			{
			case 4:
				package_decoded = PQG208;
				break;
			case 6:
				package_decoded = FTG256;
				break;
			case 2:
				package_decoded = FGG324;
				break;
			default:
				throw JtagExceptionWrapper(
					"Device is an XC2C512 but the package ID was not recognized",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
				break;
			}
		}
		break;
	
	default:
		throw JtagExceptionWrapper(
			"Invalid device ID (not a known CoolRunner-II part)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
		break;
	}
	
	return new XilinxCoolRunnerIIDevice(devid, package_decoded, stepping, idcode, iface, pos);
}

std::string XilinxCoolRunnerIIDevice::GetDescription()
{	
	char srev[16];
	snprintf(srev, 15, "%u", m_stepping);
	
	return string("Xilinx ") + GetDeviceName() + " in " + GetDevicePackage() + " package, stepping " + srev;
}

bool XilinxCoolRunnerIIDevice::HasRPCInterface()
{
	return false;
}

bool XilinxCoolRunnerIIDevice::HasDMAInterface()
{
	return false;
}

/** 
	@brief Returns the device status register
 */
XilinxCoolRunnerIIDeviceStatusRegister XilinxCoolRunnerIIDevice::GetStatusRegister()
{
	unsigned char irval = INST_BYPASS;
	XilinxCoolRunnerIIDeviceStatusRegister ret;
	JtagDevice::SetIR(&irval, &ret.word, 8);
	
	if( (ret.bits.padding_one != 1) || (ret.bits.padding_zero != 0) )
	{
		printf("Got: %02x\n", ret.word & 0xff);
		throw JtagExceptionWrapper(
			"Invalid status register (padding bits don't make sense)",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	
	return ret;
}

bool XilinxCoolRunnerIIDevice::IsProgrammed()
{
	XilinxCoolRunnerIIDeviceStatusRegister reg = GetStatusRegister();
	/*
	printf("Padding zero: %d\n", reg.bits.padding_zero);
	printf("isc_dis: %d\n", reg.bits.isc_dis);
	printf("isc_en: %d\n", reg.bits.isc_en);
	printf("sec: %d\n", reg.bits.sec);
	printf("done: %d\n", reg.bits.done);
	printf("Padding one: %d\n", reg.bits.padding_one);
	*/
	return reg.bits.done;
}

void XilinxCoolRunnerIIDevice::Erase(bool /*bVerbose*/)
{
	/*
		XILINX PROGRAMMER QUALIFICATION SPECIFICATION table 19
	
		1.  Ensure device is in test-logic/reset state
		2.  Shift in the ENABLE instruction
		3.  Shift in the ERASE instruction
		4.  Execute the instruction (erase the contents of the EEPROM array)
		5.  Shift in the DISCHARGE instruction
		6. Execute the instruction (discharge high voltage)
		7. Shift in the INIT instruction
		8. Execute the instruction (activate the contents of the EEPROM array)
		9. Shift in the DISABLE instruction
		10. Execute the instruction (activate the contents of the EEPROM array)
		11. Shift in the BYPASS instruction
	*/
	
	ResetToIdle();
	SetIR(INST_ISC_ENABLE);
	usleep(800);				//wait for device to initialize
	SetIR(INST_ISC_ERASE);
	usleep(100 * 1000);			//wait for erase cycle (100ms)
	SetIR(INST_ISC_INIT);
	usleep(20);					//wait for charge pump to drain
	SetIR(INST_ISC_INIT);
	unsigned char zero = 0;
	ScanDR(&zero, NULL, 8);		//apparently we need to do something to DR to cause an ISP_INIT pulse
								//(programming algorithm step 28 of table 20)
	usleep(800);				//wait for device to initialize
	SetIR(INST_ISC_DISABLE);	//Leave ISC mode
	
	SetIR(INST_BYPASS);			//Done
	
	//Quick blank check
	if(IsProgrammed())
	{
		throw JtagExceptionWrapper(
			"Device reports that it is still programmed after a bulk erase cycle",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	
	//Blank check
	printf("    Blank checking...\n");
	ResetToIdle();
	SetIR(INST_ISC_ENABLE);
	usleep(800);				//wait for device to initialize
	SetIR(INST_ISC_READ);
	usleep(20);					//wait for voltages to settle
	unsigned char* vaddr = GenerateVerificationTable();
	int nbits = GetShiftRegisterWidth() + 12;
	int nshort = nbits - GetPaddingSize();
	int nbytes = ceil(nshort / 8.0f);
	int nregbytes = ceil(GetShiftRegisterWidth() / 8.0f);
	unsigned char* vdata_out = new unsigned char[nbytes];
	unsigned char* zeros = new unsigned char[nbytes];
	unsigned char addr_out=0;
	memset(zeros, 0, nbytes);
	ScanDR(zeros, &addr_out, GetAddressSize());				//Bootstrap the process by shifting in the zero address
	for(int y=0; y<GetShiftRegisterDepth(); y++)
	{
		//Wait for data to settle
		usleep(100);
		
		//Read back the data
		ScanDR(zeros, vdata_out, GetShiftRegisterWidth());
		FlipByteArray(vdata_out, nregbytes);
			
		//Sanity check output
		//Mask off the address bits per chip
		int mask = 0;
		switch(m_devid)
		{
			case XC2C32:
			case XC2C32A:
				mask = 0x0F;
				break;								
				
			case XC2C64:
			case XC2C64A:
				mask = 0x03;
				break;
				
			default:
				throw JtagExceptionWrapper(
					"Unknown CoolRunner-II device (not implemented)",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
		}
		vdata_out[0] &= mask;
		
		/*
		//Print it out
		printf("    [BLANKCHK] %2d (%02x):   ", y, vaddr[y]);
		for(int i=0; i<nregbytes; i++)
			printf("%02x", vdata_out[i] & 0xFF);
		printf("\n");
		*/
		
		if(vdata_out[0] != mask)
		{
			printf("Got 0x%02x, expected 0x%02x\n", vdata_out[0], mask);
			
			delete[] vaddr;
			throw JtagExceptionWrapper(
				"Device is NOT blank after a bulk erase!",
				"",
				JtagException::EXCEPTION_TYPE_BOARD_FAULT);
		}
		for(int x=1; x<nregbytes; x++)
		{			
			if(vdata_out[x] != 0xFF)
			{
				printf("Got 0x%02x, expected 0xff at x=%d\n", vdata_out[x], x);
				
				delete[] vaddr;
				throw JtagExceptionWrapper(
					"Device is NOT blank after a bulk erase!",
					"",
					JtagException::EXCEPTION_TYPE_BOARD_FAULT);
			}
		}
		
		//Send the next address
		if((y+1) < GetShiftRegisterDepth())
			ScanDR(vaddr+(y+1), &addr_out, GetAddressSize());
	}
	printf("    Device is blank\n");
	SetIR(INST_ISC_DISABLE);
	SetIR(INST_BYPASS);
	
	delete[] vaddr;
	delete[] vdata_out;
	delete[] zeros;
}

FirmwareImage* XilinxCoolRunnerIIDevice::LoadFirmwareImage(const unsigned char* data, size_t len, bool /*bVerbose*/)
{
	XilinxCPLDBitstream* bit = new XilinxCPLDBitstream;
	ParseJEDFile(bit, data, len);
	return static_cast<FirmwareImage*>(bit);
}

void XilinxCoolRunnerIIDevice::Program(FirmwareImage* image)
{
	XilinxCPLDBitstream* bit = dynamic_cast<XilinxCPLDBitstream*>(image);
	if(bit == NULL)
	{
		throw JtagExceptionWrapper(
			"Invalid firmware image (not a XilinxCPLDBitstream)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	printf("    Using %s\n", bit->GetDescription().c_str());
	
	//Parse the device ID
	char devname[32] = {0};
	int speedgrade;
	char package[32] = {0};
	sscanf(bit->devname.c_str(), "%31[^-]-%1d-%31s", devname, &speedgrade, package);
	printf("    Device %s, speed %d, package %s\n", devname, speedgrade, package);
	
	//Normalize the package name
	string package_normalized;
	for(size_t i=0; i<sizeof(package); i++)
	{
		if(toupper(package[i]) == 'G')
			continue;
		if(package[i] == '\0')
			break;
		package_normalized += toupper(package[i]);
	}
	
	//Sanity check that the device matches
	if(0 != strcasecmp(GetDeviceName().c_str(), devname))
	{
		printf("GetDeviceName() = \"%s\", devname = \"%s\"\n",
			GetDeviceName().c_str(), devname);
		throw JtagExceptionWrapper(
			"Device name does not match provided bitfile",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	if(GetDevicePackage() != package_normalized)
	{
		printf("GetDeviceName() = \"%s\", package = \"%s\"\n",
			GetDevicePackage().c_str(), package_normalized.c_str());
		throw JtagExceptionWrapper(
			"Device package does not match provided bitfile",
			"",
			JtagException::EXCEPTION_TYPE_UNIMPLEMENTED);
	}
	printf("    Device name / package check OK\n");
	
	//Erase even if the device doesn't report being programmed, just to make sure it's totally blank
	printf("    Erasing device...\n");
	Erase();
	usleep(500 * 1000);
		
	//Generate the permuted fuse data
	//Shift register width + 12 bits for address and padding is total JTAG register width
	int* table = GeneratePermutationTable();
	int nbits = GetShiftRegisterWidth() + 12;
	int nshort = nbits - GetPaddingSize();
	int nbytes = ceil(nshort / 8.0f);
	int nregbytes = ceil(GetShiftRegisterWidth() / 8.0f);
	unsigned char* permuted_data = GeneratePermutedFuseData(bit, table);	
	
	/*
		Table 23
		1. Ensure device is in Test-Logic/Reset state
		2. Shift in the ENABLE instruction
		3. Shift in the PROGRAM instruction
		4. Shift in the address and data for the EEPROM row being programmed.
		5. Execute the command (Program the data into the selected EEPROM row)
		6. Repeat steps 4 and 6 until all EEPROM rows have been programmed
		7. Shift in the address and data for the EEPROM row 96 1010000
		8. Execute the command (Program the DONE bits)
		9.  Shift in the DISCHARGE instruction
		10. Execute the instruction (discharge high voltage)
		11. Shift in the INIT instruction
		12. Execute the instruction (activate the contents of the EEPROM array)
		13. Shift in the DISABLE instruction
		14. Execute the instruction (activate the contents of the EEPROM array)
		15. Shift in the BYPASS instruction
	 */
	
	//Generate the verification address table early so we can use it in debug print statements
	unsigned char* vaddr = GenerateVerificationTable();
	
	//Mask off the address bits
	unsigned int mask = 0;
	switch(m_devid)
	{
		case XC2C32:
		case XC2C32A:
			mask = 0x0F;
			break;
		
		case XC2C64:
		case XC2C64A:
			mask = 0x03;
			break;
			
		default:
			delete[] permuted_data;
			delete[] vaddr;
			throw JtagExceptionWrapper(
				"Unknown CoolRunner-II device (not implemented)",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	//Main programming operation
	printf("    Programming main array (shift register size = %d, nbytes=%d)...\n", nshort, nbytes);
	ResetToIdle();
	SetIR(INST_ISC_ENABLE);
	usleep(800);				//wait for device to initialize
	SetIR(INST_ISC_PROGRAM);	//Enter program mode
	for(int y=0; y<GetShiftRegisterDepth(); y++)
	{					
		//Get the row data and shift
		//Flip the bytes around since the data in the permutation was assembled reversed
		//(modeled on SVF, which sends LSB of rightmost byte first)
		unsigned char* row = permuted_data + (nbytes * y);
		
		/*
		//Print it out
		printf("    [PROGRAM]  %2d (%02x): ", y, vaddr[y]);
		for(int i=0; i<nbytes; i++)
			printf("%02x", row[i] & 0xFF);
		printf("\n");
		*/
		
		//Send
		usleep(10*1000);
		FlipByteArray(row, nbytes);
		ScanDR(row, NULL, nshort);
		
		//Flip the row back so it'll verify properly
		FlipByteArray(row, nbytes);
		
		//Wait 10ms for this EEPROM row to program as per programming spec
		usleep(10 * 1000);
	}

	//Standard init process
	SetIR(INST_ISC_INIT);		//Discharge high voltage
	usleep(20);					//wait for charge pump to drain
	SetIR(INST_ISC_INIT);
	unsigned char zero = 0;
	ScanDR(&zero, NULL, 1);		//apparently we need to do something to DR to cause an ISP_INIT pulse
								//(programming algorithm step 28 of table 20)
	usleep(800);				//wait for device to initialize
	
	//The done bits are not yet programmed, but don't set them until we've verified the rest of the device
	/*
		1. Ensure device is in Test-Logic/Reset state
		2. Shift in BYPASS instruction to flush out Status Register and check for Security and Done status
		3. Shift in the ENABLE instruction
		4. Shift in the VERIFY instruction
		5. Shift to RTI and loop 20us for voltages to settle
		6. Shift in the address of the EEPROM row being verified.
		7. Execute the command (this transfers the row data into the ISC Shift Register)
		8. Shift out the data from the ISC Shift Register
		9. Compare the shifted-out data to the expected data
		10. Repeat step 4 though 8 until all EEPROM rows have been verified
		11. Make sure the DONE bits are verifyed (Done0=Bit8=1, Done1=Bit9=0)= programming DONE
		12. Shift in the DISCHARGE instruction
		13. Execute the instruction (discharge high voltage)
		14. Shift in the INIT instruction
		15. Execute the instruction (activate the contents of the EEPROM array)
		16. Shift in the DISABLE instruction
		17. Execute the instruction (activate the contents of the EEPROM array)
		18. Shift in the BYPASS instruction
	*/
	
	//Reset the TAP and sanity check that we're programmed, then start readback process
	ResetToIdle();
	printf("    Verifying main array...\n");
	SetIR(INST_ISC_ENABLE);
	usleep(800);			//wait for device to initialize
	SetIR(INST_ISC_READ);
	usleep(20);				//wait for voltages to settle
	
	/*
		Verification loop
		
		There are two possible algorithms which differ subtly. The one in the programmer spec seems to work
		(successfully validated a urJTAG-programmed device).
		
		Algorithm in programmer spec:
			Go to shift-DR
			Shift in 6 address bits
			Update-DR
			Wait 20us in RTI
			Go to shift-DR
			Shift in GetShiftRegisterWidth() 1 bits
			Shift in next address bits
			Update-DR
			repeat
			
		Algorithm in iMPACT-generated SVF file:
			Go to shift-DR
			Shift in 6 address bits
			DR-Pause
			Wait 20us in DR-Pause
			Go back to ShiftDR
			Shift in GetShiftRegisterWidth() 1 bits
			Shift in next address bits
			Update-DR
			repeat
	 */
	unsigned char* vdata_out = new unsigned char[nbytes];
	unsigned char* zeros = new unsigned char[nbytes];
	unsigned char addr_out=0;
	memset(zeros, 0, nbytes);
	ScanDR(zeros, &addr_out, GetAddressSize());				//Bootstrap the process by shifting in the zero address
	bool ok = true;
	for(int y=0; y<GetShiftRegisterDepth() && ok; y++)
	{
		//Wait for data to settle
		usleep(100);
		
		//Read back the data
		ScanDR(zeros, vdata_out, GetShiftRegisterWidth());
		FlipByteArray(vdata_out, nregbytes);
			
		//Sanity check output against what we wrote
		unsigned char* row = permuted_data + (nbytes * y);

		vdata_out[0] &= mask;
		row[1] &= mask;
		for(int x=0; x<nregbytes; x++)
		{
			if(row[x+1] != vdata_out[x])
			{
				ok = false;
				printf("    Verify FAILED at row %d, byte %d (expected %02x, found %02x)\n", y, x, row[x+1], vdata_out[x]);
				break;
			}
		}
		
		/*
		//Print it out
		printf("    [READBACK] %2d (%02x):  ", y, vaddr[y]);
		for(int i=0; i<nregbytes; i++)
			printf("%02x", vdata_out[i] & 0xFF);
		printf("\n");
		*/
		
		//Send the next address
		if((y+1) < GetShiftRegisterDepth())
			ScanDR(vaddr+(y+1), &addr_out, GetAddressSize());
	}
	if(!ok)
	{
		throw JtagExceptionWrapper(
			"Verification FAILED",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	printf("    Readback successful\n");
	
	//Reset
	SetIR(INST_ISC_INIT);
	usleep(20);					//wait for HV to discharge
	SetIR(INST_ISC_INIT);
	usleep(800);				//wait for boot
	SetIR(INST_ISC_DISABLE);	//Leave ISC mode	
	SetIR(INST_BYPASS);			//Done
	
	//If all is well, keep going
	//Prepare to program DONE / security bits
	//TODO: move to a separate function to keep things nice and clean
	//Address bits are mirrored right-to-left
	bool* scratch = new bool[nbits];
	unsigned char* scratch_bytes = new unsigned char[nbytes];
	int addr = GrayEncode(GetShiftRegisterDepth());
	for(int x=0; x<12; x++)
		scratch[x] = false;
	for(int x=12; x<GetShiftRegisterWidth()+12; x++)
		scratch[x] = true;
	for(int i=GetPaddingSize(); i<12; i++)
	{
		scratch[i] = (addr & 1);
		addr >>= 1;
	}
	int fusebase = 11;
	if( (m_devid != XC2C64) && (m_devid != XC2C64A))
	{
		//skip transfer bit
		fusebase ++;
		scratch[fusebase] = false;
		scratch[GetShiftRegisterWidth() + 11] = false;
	}
	
	//Leave security bits as 1
	scratch[fusebase+9] = false;	//Done1
	scratch[fusebase+8] = true;		//Done0
	for(int base=nbits-1; base >= 0; base -= 8)
	{
		int temp = 0;
		for(int j=0; j<8; j++)
		{
			int nbit = base - j;
			if(nbit < 0)
				break;
			if(scratch[nbit])
				temp |= (1 << j);
		}
		scratch_bytes[base/8] = temp;
	}
	FlipByteArray(scratch_bytes, nbytes);
	ResetToIdle();
	SetIR(INST_ISC_ENABLE);
	usleep(800);				//wait for device to initialize
	SetIR(INST_ISC_PROGRAM);	//Enter program mode
	ScanDR(scratch_bytes, NULL,  nshort);
	usleep(10 * 1000);			//Wait 10ms for this EEPROM row to program
	
	//Standard init process
	SetIR(INST_ISC_INIT);		//Discharge high voltage
	usleep(20);					//wait for charge pump to drain
	SetIR(INST_ISC_INIT);
	usleep(100);
	ScanDR(&zero, NULL, 1);		//apparently we need to do something to DR to cause an ISP_INIT pulse
								//(programming algorithm step 28 of table 20)
	usleep(800);				//wait for device to initialize
	
	SetIR(INST_ISC_DISABLE);	//Leave ISC mode
	SetIR(INST_BYPASS);			//Done
	
	//Clean up
	delete[] scratch_bytes;
	delete[] scratch;
	
	//Sanity check that we're programmed
	if(!IsProgrammed())
	{
		throw JtagExceptionWrapper(
			"Configuration failed (unknown reason)",
			"",
			JtagException::EXCEPTION_TYPE_BOARD_FAULT);
	}
	
	ResetToIdle();
	
	//Clean up
	delete[] zeros;
	delete[] vdata_out;
	delete[] vaddr;
	delete[] permuted_data;
	delete[] table;
}

/**
	@brief Gets the number of padding bits to add
	
	See table 10 of programmer spec
 */
int XilinxCoolRunnerIIDevice::GetPaddingSize()
{
	return 12 - GetAddressSize();
}

/**
	@brief Gets the number of address bits
 */
int XilinxCoolRunnerIIDevice::GetAddressSize()
{
	switch(m_devid)
	{
		case XC2C32:
		case XC2C32A:
			return 6;
		
		case XC2C64:
		case XC2C64A:
		case XC2C128:
		case XC2C256:
		case XC2C384:
			return 7;
			
		case XC2C512:
			return 8;
			
		default:
			throw JtagExceptionWrapper(
				"Unknown CoolRunner-II device (not implemented)",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Generates the verification table
 */
unsigned char* XilinxCoolRunnerIIDevice::GenerateVerificationTable()
{
	//Allocate the raw binary output buffer (data ready to send)
	unsigned char* bindata = new unsigned char[GetShiftRegisterDepth()];
	
	//Generate each row
	for(int y=0; y<GetShiftRegisterDepth(); y++)
	{
		unsigned int addr = GrayEncode(y);
		
		unsigned int bits[8];
		for(int i=0; i<8; i++)
			bits[i] = (addr >> i) & 1;
		
		switch(m_devid)
		{
			case XC2C32:
			case XC2C32A:
				bindata[y] = bits[5] | (bits[4] << 1) | (bits[3] << 2) |
							(bits[2] << 3) | (bits[1] << 4) | (bits[0] << 5);
				break;
			
			case XC2C64:
			case XC2C64A:
				bindata[y] = bits[6] | (bits[5] << 1) | (bits[4] << 2) | (bits[3] << 3) |
							(bits[2] << 4) | (bits[1] << 5) | (bits[0] << 6);
				break;
			
			default:
				delete[] bindata;
				throw JtagExceptionWrapper(
					"Unknown CoolRunner-II device (not implemented)",
					"",
					JtagException::EXCEPTION_TYPE_GIGO);
		}
	}
	
	//Done, clean up and return	
	return bindata;
}

/**
	@brief Permutes the bitstream and adds transfer bits if the device needs them
 */
unsigned char* XilinxCoolRunnerIIDevice::GeneratePermutedFuseData(XilinxCPLDBitstream* bit, int* permtable)
{
	//Width of one row
	//Shift register width + 12 bits for address and padding
	int nbits = GetShiftRegisterWidth() + 12;
	int nbytes = ceil(nbits / 8.0f);
	int nmax = GetPaddingSize();
	
	//Allocate the raw binary output buffer (data ready to send)
	unsigned char* bindata = new unsigned char[nbytes * GetShiftRegisterDepth()];
	
	//Scratch buffer for one row
	bool* scratch = new bool[nbits];
	
	//Generate each row
	for(int y=0; y<GetShiftRegisterDepth(); y++)
	{
		//Get the permutation table for this row
		int* rowperm = permtable + y*GetShiftRegisterWidth();
		
		//Generate the gray-code address
		int addr = GrayEncode(y);
		
		//Zero out the row buffer
		for(int x=0; x<nbits; x++)
			scratch[x] = false;
			
		//Address calculation is wrong! Doesn't match the SVF, seems to be shifted by a bit or two
		
		//Address bits are mirrored right-to-left
		for(int i=nmax; i<12; i++)
		{
			scratch[i] = (addr & 1);
			addr >>= 1;
		}
		
		//Build the row buffer
		for(int x=0; x<GetShiftRegisterWidth(); x++)
		{			
			//Transfer bits
			if(rowperm[x] == FUSE_VALUE_TRANSFER)
				scratch[x+12] = 0;
				
			//Don't cares
			else if(rowperm[x] == FUSE_VALUE_DONTCARE)
				scratch[x+12] = 1;
				
			//Data bits
			else
				scratch[x+12] = bit->fuse_data[rowperm[x]];
		}
		
		//Generate packed binary
		//BUGFIX: This needs to be *right* aligned so start conversion from the right
		unsigned char* outrow = bindata + nbytes*y;
		for(int base=nbits-1; base >= 0; base -= 8)
		{
			int temp = 0;
			for(int j=0; j<8; j++)
			{
				int nbit = base - j;
				if(nbit < 0)
					break;
				if(scratch[nbit])
					temp |= (1 << j);
			}
			outrow[base/8] = temp;
		}
	}
	
	//Done, clean up and return	
	delete[] scratch;
	return bindata;
}

/**
	@brief Returns the device name
 */
string XilinxCoolRunnerIIDevice::GetDeviceName()
{
	string devname;
	
	//Look up device name
	switch(m_devid)
	{
	case XC2C32:
		devname = "XC2C32";
		break;
	case XC2C32A:
		devname = "XC2C32A";
		break;
	case XC2C64:
		devname = "XC2C64";
		break;
	case XC2C64A:
		devname = "XC2C64A";
		break;
	case XC2C128:
		devname = "XC2C128";
		break;
	case XC2C256:
		devname = "XC2C256";
		break;
	case XC2C384:
		devname = "XC2C384";
		break;
	case XC2C512:
		devname = "XC2C512";
		break;
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (ID code not in database)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	return devname;
}

/**
	@brief Gets the name of a given package enum
 */
std::string XilinxCoolRunnerIIDevice::GetPackageName(int pknum)
{
	//Look up package
	string package;	
	switch(pknum)
	{
	case QFG32:	//lead-free only so G is included
		package = "QFG32";
		break;
	case VQG44:
		package = "VQ44";
		break;
	case QFG48:
		package = "QF48";
		break;
	case CPG56:
		package = "CP56";
		break;
	case VQG100:
		package = "VQ100";
		break;
	case CPG132:
		package = "CP132";
		break;
	case TQG144:
		package = "TQ144";
		break;
	case PQG208:
		package = "PQ208";
		break;
	case FTG256:
		package = "FT256";
		break;
	case FGG324:
		package = "FG324";
		break;
	default:
		throw JtagExceptionWrapper(
			"Unknown package",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	
	return package;
}

/**
	@brief Returns the device package
 */
string XilinxCoolRunnerIIDevice::GetDevicePackage()
{
	return GetPackageName(m_package);
}

/**
	@brief Generates the permutation table.
	
	The table is generated in *row major* order to simplify the code,
	but for typical use should probably be column major.
 */
int* XilinxCoolRunnerIIDevice::GeneratePermutationTable()
{
	//Allocate memory for the table (one int per fuse position plus transfer bits)
	const int fuse_count = GetShiftRegisterWidth() * GetShiftRegisterDepth();
	int* permutation_table = new int[fuse_count];
	for(int i=0; i<fuse_count; i++)
		permutation_table[i] = 0;
	
	//Sizes of various blocks of interest
	const int fb_andblksize	= 20;						//number of rows in a FB block
	const int fb_androws	= fb_andblksize * 2;		//number of rows in a FB
	const int fb_orrows		= 8;						//same for all CR-II devices
	const int fb_rows		= fb_androws + fb_orrows;	//AND and OR arrays stack
	const int fb_pterms		= 56;						//same for all CR-II devices
	const int fb_pla_width	= fb_pterms*2;				//PLA has 2 bits per pterm per row
	const int fb_orterms	= fb_orrows * 2;			//2 or terms per row
	const int pla_and_size	= fb_androws*fb_pla_width;	//AND array is a nice little grid
	const int pla_or_size	= fb_pla_width*fb_orrows;	//so is the OR array
	const int mcell_rsize	= 9;						//this applies only to "small" devices (32/64/a)
	const int mcell_size	= mcell_rsize * 3;			//total config bits per macrocell
	const int mcell_config_size = mcell_size			//Devices with buried macrocells get really funky
									* fb_orterms;		//since they have multiple size depending on if
														//the MC is bonded out or not
	const int zia_width = GetZIAWidth();
	const int zia_size = zia_width * fb_androws;		//Depth is constant, width varies per device
	const int fb_width		= mcell_rsize +				//Offset from one FB to the east-side partner
								fb_pla_width + 
								zia_width*2;
	
	const int fb_config_size =							//Total number of config bits for a single FB
		pla_and_size +									//Just add up the parts
		pla_or_size +
		zia_size +
		mcell_config_size;
	
	const int global_config_base =						//Fuse index for global configuration data
		fb_config_size * GetFunctionBlockCount();
												
	//Cache some array dimensions
	const int w = GetShiftRegisterWidth();
	const int d = GetShiftRegisterDepth();
	
	//Fill the entire array with garbage
	for(int i=0; i<fuse_count; i++)
		permutation_table[i] = FUSE_VALUE_DONTCARE;
		
	//Write transfer bits iff we have a chip that uses them
	bool left_transfer_bit = false;
	switch(m_devid)
	{
		case XC2C32:
		case XC2C32A:
			{
				left_transfer_bit = true;
				for(int y=0; y<d; y++)
				{
					int* row = permutation_table + (y*w);
					row[0] = FUSE_VALUE_TRANSFER;
					row[259] = FUSE_VALUE_TRANSFER;
				}
			}
			break;
		
		//no transfer bits
		case XC2C64:
		case XC2C64A:
			break;
			
		//invalid
		default:
			throw JtagExceptionWrapper(
				"Unknown CoolRunner-II device (not implemented)",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
			break;
	}

	/*
		Write PLA bits
		Structure of a single function block pair is as follows
		W MC	NW AND		N ZIA		NE AND		E MC
		W MC	W OR		Unused		E OR		E MC
		W MC	SW AND		S ZIA		SE AND		E MC
		
		The ZIA is interleaved from E/W
		The E side is mirrored relative to W.
		
		The "unused" block may later be partially filled in with global config bits.
		Most of these bits appear to be physically unimplemented.
	 */
	const int fw = GetFunctionBlockGridWidth();
	const int fh = GetFunctionBlockGridHeight();
	if(fw != 1)
	{
		throw JtagExceptionWrapper(
			"Devices with more than one column of FBs not yet supported",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
	for(int yblock = 0; yblock < fh; yblock ++)
	{
		for(int xblock = 0; xblock < fw; xblock ++)
		{
			//Get indexes of east and west function blocks
			//This is known to work for the 32/64 cell devices but not sure about multiple cols
			int w_fb = yblock*fw*2 + xblock;
			int e_fb = w_fb + 1;

			//Get base fuse indexes for each FB
			int w_base		= w_fb * fb_config_size;
			int w_andbase	= w_base + zia_size;
			int w_orbase	= w_andbase + pla_and_size;
			int w_mcbase	= w_orbase + pla_or_size;
			int e_base		= e_fb * fb_config_size;
			int e_andbase	= e_base + zia_size;
			int e_orbase	= e_andbase + pla_and_size;
			int e_mcbase	= e_orbase + pla_or_size;
			
			//Row to start writing to
			int ybase = yblock*fb_rows;
			
			//Left starting points for each PLA block
			//TODO: Support multi-column devices (middle transfer bits?)
			int w_left = 0;
			if(left_transfer_bit)
				w_left += 1;
			int e_left = w_left + fb_width;
			
			//Write the macrocell configs
			//This seems to be super duper device dependent
			static const int pattern[2][3][9]=
			{
				//XC2C32/A
				//This actually makes sense, just take each group of 9 bits and spam it in order
				{
					{0, 1, 2, 3, 4, 5, 6, 7, 8},
					{0, 1, 2, 3, 4, 5, 6, 7, 8},
					{0, 1, 2, 3, 4, 5, 6, 7, 8}
				},
				
				//XC2C64/A
				//WTF is up with this layout? Need to look at M2 and M3 of the config area and find out
				{
					{ 7, 8, 5, 6, 4, 2, 3,  1, 0},
					{10, 7, 6, 4, 5, 2, 3,  0, 1},
					{ 8, 7, 6, 2, 3, 4, 5, -1, 0}
				}
			};
			int npattern = 0;
			switch(m_devid)
			{
				case XC2C32:
				case XC2C32A:
					npattern = 0;
					break;
					
				case XC2C64:
				case XC2C64A:
					npattern = 1;
					break;
					
				default:
					throw JtagExceptionWrapper(
						"Unknown CoolRunner-II device (not implemented)",
						"",
						JtagException::EXCEPTION_TYPE_GIGO);
					break;
			}
			for(int y=0; y<fb_rows; y++)
			{
				//West side
				int xoff = w_mcbase + y*mcell_rsize;
				int* row = permutation_table + ((y+ybase)*w) + w_left;
				for(int x=0; x<9; x++)
					row[x] = xoff + pattern[npattern][y%3][x];
					
				//East side
				xoff = e_mcbase + y*mcell_rsize;
				row = permutation_table + ((y+ybase)*w) + e_left + fb_pla_width;
				for(int x=0; x<9; x++)
					row[8-x] = xoff + pattern[npattern][y%3][x];
			}
			
			//Write the PLA AND array
			for(int y=0; y<fb_androws; y++)
			{
				int yout = y;
				if(y >= fb_andblksize)
					yout += fb_orrows;
				
				int* row = permutation_table + ((yout+ybase)*w);
				
				//West side
				//Grab two bits at a time for X and !X
				int xbase = w_left + mcell_rsize;
				for(int x=0; x<fb_pla_width; x+=2)
				{
					int nfuse = w_andbase + 2*y + fb_androws*x;
					row[xbase+x] 	= nfuse + 1;
					row[xbase+x+1]	= nfuse;
				}
				
				//East side
				//Grab two bits at a time for X and !X
				//Mirrored vs left side
				xbase = e_left;
				for(int x=0; x<fb_pla_width; x+=2)
				{
					int nfuse = e_andbase + 2*y + pla_and_size - fb_androws*(x+2);
					row[xbase+x]	= nfuse;
					row[xbase+x+1] 	= nfuse + 1;
				}
			}
			
			//Write the PLA OR array
			for(int y=0; y<fb_orrows; y++)
			{
				int* row = permutation_table + ((y+ybase+fb_andblksize)*w);
				
				//West side
				//Grab two bits at a time (interleaved for two OR terms)
				int xbase = w_left + mcell_rsize;
				for(int x=0; x<fb_pla_width; x+=2)
				{
					int nfuse = w_orbase + 2*y + fb_orrows*x;
					row[xbase+x] 	= nfuse;
					row[xbase+x+1]	= nfuse+1;
				}
				
				//East side
				//Grab two bits at a time (interleaved for two OR terms)
				//Mirrored vs left side
				xbase = e_left;
				for(int x=0; x<fb_pla_width; x+=2)
				{
					int nfuse = e_orbase + 2*y + pla_or_size - fb_orrows*(x+2);
					row[xbase+x]	= nfuse + 1;
					row[xbase+x+1] 	= nfuse;
				}
			}
			
			//Write the ZIA
			//Need to interleave this so it's a pain in the butt
			for(int y=0; y<fb_androws; y++)
			{
				int yout = y;
				if(y >= fb_andblksize)
					yout += fb_orrows;
				
				int* row = permutation_table + ((yout+ybase)*w);
				int xbase = w_left + mcell_rsize + fb_pla_width;
				
				for(int x=0; x<zia_width; x++)
				{
					int offset = zia_width*y + (zia_width-1) - x;
					row[xbase+x*2] 		= w_base + offset;
					row[xbase+x*2 + 1]	= e_base + offset;
				}
			}
		}
	}
	
	//Global config fuses
	//VERY chip specific, doesn't seem to be any way to predict what goes where yet.
	//* They're always in the middle of the ZIA gap.
	//* Most stuff is usually the middle of the top left FB array, it seems
	//* Global OE mux bits are usually split up (does this hint at something? which controls what?)
	switch(m_devid)
	{
		case XC2C32:
		case XC2C32A:
			{				
				//Offset from start of the row to global config area
				int xoff = fb_pla_width + mcell_rsize + 5;
				
				//Global clock and set/reset mux are continuous
				int ystart = 23;
				for(int x=0; x<5; x++)
					permutation_table[ystart*w + xoff + x] = global_config_base + x;
					
				//Then skip the OE mux and jump to global termination flag	
				permutation_table[ystart*w + xoff + 5] = global_config_base + 13;
				
				//Global OE mux (8 bits, 4 across each of 2 columns)
				ystart = 24;
				for(int x=0; x<4; x++)
				{
					permutation_table[ystart*w + xoff + x]   = global_config_base + 5 + x;
					permutation_table[(ystart+1)*w + xoff + x] = global_config_base + 9 + x;
				}
					
				//Legacy I/O voltage bits span columns too
				permutation_table[ystart*w + xoff + 4]   = global_config_base + 14;
				permutation_table[(ystart+1)*w + xoff + 4] = global_config_base + 15;
				
				//Global input pin
				permutation_table[ystart*w + xoff + 5] = global_config_base + 16;
				permutation_table[ystart*w + xoff + 6] = global_config_base + 17;
				
				//32A-specific I/O banking fuses
				ystart = 25;
				if(m_devid == XC2C32A)
				{
					for(int x=0; x<4; x++)
						permutation_table[ystart*w + xoff + 5 + x] = global_config_base + 18 + x;
				}
			}
			break;
			
		case XC2C64:
		case XC2C64A:
			{
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// This stuff lives in the FB0/1 config hole
				
				//Offset from start of the row to global config area
				int xoff = fb_pla_width + mcell_rsize + 12;
				
				//Global clock mux
				int ystart = 23;
				for(int x=0; x<3; x++)
					permutation_table[ystart*w + xoff + x] = global_config_base + x;
					
				//Skip set/reset and OE mux, global termination comes next
				//immediately followed by legacy I/O voltage configuration
				//and bank voltage configuration
				for(int x=0; x<7; x++)
					permutation_table[ystart*w + xoff + 3 + x] = global_config_base + 13 + x;
					
				//Global OE mux (kinda split up)
				ystart = 24;
				for(int x=0; x<4; x++)
					permutation_table[ystart*w + xoff + x]   = global_config_base + 5 + x;
				for(int x=0; x<2; x++)
					permutation_table[ystart*w + xoff + x + 4]   = global_config_base + 11 + x;
				
				////////////////////////////////////////////////////////////////////////////////////////////////////////
				// This stuff lives in the FB2/3 config hole
				
				//Global set/reset mux
				ystart = 73;
				for(int x=0; x<2; x++)
					permutation_table[ystart*w + xoff + x + 2] = global_config_base + x + 3;
				
				//More global OE mux bits
				for(int x=0; x<2; x++)
					permutation_table[ystart*w + xoff + x + 4]   = global_config_base + 9 + x;
			}
			break;
			
		default:
			throw JtagExceptionWrapper(
				"Unknown CoolRunner-II device (not implemented)",
				"",
				JtagException::EXCEPTION_TYPE_GIGO);
			break;		
	}
	
	//Done
	return permutation_table;
}

/**
	@brief Mirrors a coordinate within a certain range
 */
int XilinxCoolRunnerIIDevice::MirrorCoordinate(int x, int end, bool mirror)
{
	if(!mirror)
		return x;
	else
		return end - x - 1;
}

/**
	@brief Returns the width of the FB grid, in FB pairs
 */
int XilinxCoolRunnerIIDevice::GetFunctionBlockGridWidth()
{
	switch(m_devid)
	{
	case XC2C32:
	case XC2C32A:
		return 1;
		
	case XC2C64:
	case XC2C64A:
		return 1;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Returns the height of the FB grid, in FBs
 */
int XilinxCoolRunnerIIDevice::GetFunctionBlockGridHeight()
{
	switch(m_devid)
	{
	case XC2C32:
	case XC2C32A:
		return 1;
		
	case XC2C64:
	case XC2C64A:
		return 2;
	
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Returns the width of one function block's ZIA in bits
 */
int XilinxCoolRunnerIIDevice::GetZIAWidth()
{
	switch(m_devid)
	{
	case XC2C32A:
		return 8;
		
	case XC2C64A:
		return 16;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Returns the number of function blocks in the device
 */
int XilinxCoolRunnerIIDevice::GetFunctionBlockCount()
{
	switch(m_devid)
	{
	case XC2C32:
	case XC2C32A:
		return 2;
		
	case XC2C64:
	case XC2C64A:
		return 4;
		
	case XC2C128:
		return 8;
		
	case XC2C256:
		return 16;
		
	case XC2C384:
		return 24;
	
	case XC2C512:
		return 32;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Returns the number of function block pairs in the device
 */
int XilinxCoolRunnerIIDevice::GetFunctionBlockPairCount()
{
	return GetFunctionBlockCount() / 2;
}

/**
	@brief Gets the number of fuses in the device
 */
int XilinxCoolRunnerIIDevice::GetFuseCount()
{
	switch(m_devid)
	{
	case XC2C32:
		return 12274;
	case XC2C32A:
		return 12278;
	case XC2C64:
		return 25808;
	case XC2C64A:
		return 25812;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Gets the depth of the shift register for this device.
	
	Does not include sec/done or UES words.
 */
int XilinxCoolRunnerIIDevice::GetShiftRegisterDepth()
{
	switch(m_devid)
	{
	case XC2C32:
	case XC2C32A:
		return 48;
	case XC2C64:
	case XC2C64A:
		return 96;
	case XC2C128:
		return 80;
	case XC2C256:
		return 96;
	case XC2C384:
		return 120;
	case XC2C512:
		return 160;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Gets the width of the shift register for this device.
	
	Includes transfer bits.
 */
int XilinxCoolRunnerIIDevice::GetShiftRegisterWidth()
{
	switch(m_devid)
	{
	case XC2C32:
	case XC2C32A:
		return 260;
	case XC2C64:
	case XC2C64A:
		return 274;
	case XC2C128:
		return 752;
	case XC2C256:
		return 1364;
	case XC2C384:
		return 1868;
	case XC2C512:
		return 1980;
		
	default:
		throw JtagExceptionWrapper(
			"Unknown CoolRunner-II device (not implemented)",
			"",
			JtagException::EXCEPTION_TYPE_GIGO);
	}
}

/**
	@brief Gray code encoder
 */
int XilinxCoolRunnerIIDevice::GrayEncode(int address)
{
	return (address >> 1) ^ address;
}
