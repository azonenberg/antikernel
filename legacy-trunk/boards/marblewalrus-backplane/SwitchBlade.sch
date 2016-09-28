EESchema Schematic File Version 2
LIBS:analog-azonenberg
LIBS:cmos
LIBS:cypress-azonenberg
LIBS:hirose-azonenberg
LIBS:memory-azonenberg
LIBS:microchip-azonenberg
LIBS:osc-azonenberg
LIBS:passive-azonenberg
LIBS:power-azonenberg
LIBS:special-azonenberg
LIBS:xilinx-azonenberg
LIBS:device
LIBS:conn
LIBS:marblewalrus-backplane-cache
EELAYER 25 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 4 7
Title "MARBLEWALRUS Backplane"
Date "2015-11-15"
Rev "$Rev: 2241 $"
Comp "Andrew Zonenberg"
Comment1 "Switch blade infrastructure"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L CONN_MW_SWITCH_BACKPLANE J10
U 1 1 56450FE7
P 3000 3950
F 0 "J10" H 3000 3900 60  0000 L CNN
F 1 "CONN_MW_SWITCH_BACKPLANE" H 3000 3800 60  0000 L CNN
F 2 "azonenberg_pcb:CONN_PCIE_X16_FCI_10018783_10203TLF" H 3000 3950 60  0001 C CNN
F 3 "" H 3000 3950 60  0000 C CNN
	1    3000 3950
	1    0    0    -1  
$EndComp
$Comp
L CONN_MW_SWITCH_BACKPLANE J10
U 2 1 56465897
P 6850 5150
F 0 "J10" H 6850 5100 60  0000 L CNN
F 1 "CONN_MW_SWITCH_BACKPLANE" H 6850 5000 60  0000 L CNN
F 2 "azonenberg_pcb:CONN_PCIE_X16_FCI_10018783_10203TLF" H 6850 5150 60  0001 C CNN
F 3 "" H 6850 5150 60  0000 C CNN
	2    6850 5150
	1    0    0    -1  
$EndComp
Text HLabel 2600 2800 0    60   Input ~ 0
GND
Text Label 2600 2500 2    60   ~ 0
SWITCH_JTAG_VDD
NoConn ~ 2800 2600
Text Label 4650 3500 0    60   ~ 0
SWITCH_JTAG_TCK
Text Label 4650 3600 0    60   ~ 0
SWITCH_JTAG_TDI
Text Label 4650 3700 0    60   ~ 0
SWITCH_JTAG_TDO
Text Label 4650 3800 0    60   ~ 0
SWITCH_JTAG_TMS
Text Label 2600 3000 2    60   ~ 0
GND
Text Label 6550 1800 2    60   ~ 0
GND
Text Label 7600 1800 0    60   ~ 0
GND
$Comp
L XILINX_JTAG J13
U 1 1 564689C7
P 3950 6550
F 0 "J13" H 4450 8100 60  0000 C CNN
F 1 "XILINX_JTAG" H 4450 8000 60  0000 C CNN
F 2 "azonenberg_pcb:XILINX_JTAG_PTH_MOLEX_0878311420" H 3950 6550 60  0001 C CNN
F 3 "" H 3950 6550 60  0000 C CNN
	1    3950 6550
	1    0    0    -1  
$EndComp
Text Label 3750 5450 2    60   ~ 0
SWITCH_JTAG_VDD
Text Label 3750 5550 2    60   ~ 0
GND
NoConn ~ 3950 6050
Text Label 3750 6250 2    60   ~ 0
SWITCH_JTAG_TCK
Text Label 3750 6450 2    60   ~ 0
SWITCH_JTAG_TDI
Text Label 3750 6350 2    60   ~ 0
SWITCH_JTAG_TDO
Text Label 3750 6150 2    60   ~ 0
SWITCH_JTAG_TMS
NoConn ~ 3950 6550
Text HLabel 4650 3300 2    60   BiDi ~ 0
I2C_SDA
Text HLabel 4650 3200 2    60   Input ~ 0
I2C_SCL
Text HLabel 2600 1800 0    60   Input ~ 0
SWITCH_12V0
Wire Wire Line
	2600 1800 2800 1800
Wire Wire Line
	2700 1800 2700 2300
Wire Wire Line
	2700 1900 2800 1900
Connection ~ 2700 1800
Wire Wire Line
	2700 2000 2800 2000
Connection ~ 2700 1900
Wire Wire Line
	2700 2100 2800 2100
Connection ~ 2700 2000
Wire Wire Line
	2700 2200 2800 2200
Connection ~ 2700 2100
Wire Wire Line
	2700 2300 2800 2300
Connection ~ 2700 2200
Wire Wire Line
	2600 2800 2800 2800
Wire Wire Line
	2700 2800 2700 3700
Wire Wire Line
	2700 2900 2800 2900
Connection ~ 2700 2800
Wire Wire Line
	2600 3000 2800 3000
Connection ~ 2700 2900
Wire Wire Line
	2700 3100 2800 3100
Connection ~ 2700 3000
Wire Wire Line
	2700 3200 2800 3200
Connection ~ 2700 3100
Wire Wire Line
	2700 3300 2800 3300
Connection ~ 2700 3200
Wire Wire Line
	2700 3400 2800 3400
Connection ~ 2700 3300
Wire Wire Line
	2700 3500 2800 3500
Connection ~ 2700 3400
Wire Wire Line
	2700 3600 2800 3600
Connection ~ 2700 3500
Wire Wire Line
	2700 3700 2800 3700
Connection ~ 2700 3600
Wire Wire Line
	2600 2500 2800 2500
Wire Wire Line
	4650 3500 4450 3500
Wire Wire Line
	4650 3600 4450 3600
Wire Wire Line
	4650 3700 4450 3700
Wire Wire Line
	4650 3800 4450 3800
Wire Wire Line
	6550 1800 6650 1800
Wire Wire Line
	6600 1800 6600 5100
Wire Wire Line
	6600 1900 6650 1900
Connection ~ 6600 1800
Wire Wire Line
	6600 2000 6650 2000
Connection ~ 6600 1900
Wire Wire Line
	6600 2100 6650 2100
Connection ~ 6600 2000
Wire Wire Line
	6600 2200 6650 2200
Connection ~ 6600 2100
Wire Wire Line
	6600 2300 6650 2300
Connection ~ 6600 2200
Wire Wire Line
	6600 2400 6650 2400
Connection ~ 6600 2300
Wire Wire Line
	6600 2500 6650 2500
Connection ~ 6600 2400
Wire Wire Line
	6600 2600 6650 2600
Connection ~ 6600 2500
Wire Wire Line
	6600 2700 6650 2700
Connection ~ 6600 2600
Wire Wire Line
	6600 2800 6650 2800
Connection ~ 6600 2700
Wire Wire Line
	6600 2900 6650 2900
Connection ~ 6600 2800
Wire Wire Line
	6600 3000 6650 3000
Connection ~ 6600 2900
Wire Wire Line
	6600 3100 6650 3100
Connection ~ 6600 3000
Wire Wire Line
	6600 3200 6650 3200
Connection ~ 6600 3100
Wire Wire Line
	6600 3300 6650 3300
Connection ~ 6600 3200
Wire Wire Line
	6600 3400 6650 3400
Connection ~ 6600 3300
Wire Wire Line
	6600 3500 6650 3500
Connection ~ 6600 3400
Wire Wire Line
	6600 3600 6650 3600
Connection ~ 6600 3500
Wire Wire Line
	6600 3700 6650 3700
Connection ~ 6600 3600
Wire Wire Line
	6600 3800 6650 3800
Connection ~ 6600 3700
Wire Wire Line
	6600 3900 6650 3900
Connection ~ 6600 3800
Wire Wire Line
	6600 4000 6650 4000
Connection ~ 6600 3900
Wire Wire Line
	6600 4100 6650 4100
Connection ~ 6600 4000
Wire Wire Line
	6600 4200 6650 4200
Connection ~ 6600 4100
Wire Wire Line
	6600 4300 6650 4300
Connection ~ 6600 4200
Wire Wire Line
	6600 4400 6650 4400
Connection ~ 6600 4300
Wire Wire Line
	6600 4500 6650 4500
Connection ~ 6600 4400
Wire Wire Line
	6600 4600 6650 4600
Connection ~ 6600 4500
Wire Wire Line
	6600 4700 6650 4700
Connection ~ 6600 4600
Wire Wire Line
	6600 4800 6650 4800
Connection ~ 6600 4700
Wire Wire Line
	6600 4900 6650 4900
Connection ~ 6600 4800
Wire Wire Line
	6600 5000 6650 5000
Connection ~ 6600 4900
Wire Wire Line
	6600 5100 6650 5100
Connection ~ 6600 5000
Wire Wire Line
	7600 1800 7500 1800
Wire Wire Line
	7550 1800 7550 5100
Wire Wire Line
	7550 1900 7500 1900
Connection ~ 7550 1800
Wire Wire Line
	7550 2000 7500 2000
Connection ~ 7550 1900
Wire Wire Line
	7550 2100 7500 2100
Connection ~ 7550 2000
Wire Wire Line
	7550 2200 7500 2200
Connection ~ 7550 2100
Wire Wire Line
	7550 2300 7500 2300
Connection ~ 7550 2200
Wire Wire Line
	7550 2400 7500 2400
Connection ~ 7550 2300
Wire Wire Line
	7550 2500 7500 2500
Connection ~ 7550 2400
Wire Wire Line
	7550 2600 7500 2600
Connection ~ 7550 2500
Wire Wire Line
	7550 2700 7500 2700
Connection ~ 7550 2600
Wire Wire Line
	7550 2800 7500 2800
Connection ~ 7550 2700
Wire Wire Line
	7550 2900 7500 2900
Connection ~ 7550 2800
Wire Wire Line
	7550 3000 7500 3000
Connection ~ 7550 2900
Wire Wire Line
	7550 3100 7500 3100
Connection ~ 7550 3000
Wire Wire Line
	7550 3200 7500 3200
Connection ~ 7550 3100
Wire Wire Line
	7550 3300 7500 3300
Connection ~ 7550 3200
Wire Wire Line
	7550 3400 7500 3400
Connection ~ 7550 3300
Wire Wire Line
	7550 3500 7500 3500
Connection ~ 7550 3400
Wire Wire Line
	7550 3600 7500 3600
Connection ~ 7550 3500
Wire Wire Line
	7550 3700 7500 3700
Connection ~ 7550 3600
Wire Wire Line
	7550 3800 7500 3800
Connection ~ 7550 3700
Wire Wire Line
	7550 3900 7500 3900
Connection ~ 7550 3800
Wire Wire Line
	7550 4000 7500 4000
Connection ~ 7550 3900
Wire Wire Line
	7550 4100 7500 4100
Connection ~ 7550 4000
Wire Wire Line
	7550 4200 7500 4200
Connection ~ 7550 4100
Wire Wire Line
	7550 4300 7500 4300
Connection ~ 7550 4200
Wire Wire Line
	7550 4400 7500 4400
Connection ~ 7550 4300
Wire Wire Line
	7550 4500 7500 4500
Connection ~ 7550 4400
Wire Wire Line
	7550 4600 7500 4600
Connection ~ 7550 4500
Wire Wire Line
	7550 4700 7500 4700
Connection ~ 7550 4600
Wire Wire Line
	7550 4800 7500 4800
Connection ~ 7550 4700
Wire Wire Line
	7550 4900 7500 4900
Connection ~ 7550 4800
Wire Wire Line
	7550 5000 7500 5000
Connection ~ 7550 4900
Wire Wire Line
	7550 5100 7500 5100
Connection ~ 7550 5000
Wire Wire Line
	3750 5450 3950 5450
Wire Wire Line
	3750 5550 3950 5550
Wire Wire Line
	3850 5550 3850 5950
Wire Wire Line
	3850 5650 3950 5650
Connection ~ 3850 5550
Wire Wire Line
	3850 5750 3950 5750
Connection ~ 3850 5650
Wire Wire Line
	3850 5850 3950 5850
Connection ~ 3850 5750
Wire Wire Line
	3850 5950 3950 5950
Connection ~ 3850 5850
Wire Wire Line
	3750 6250 3950 6250
Wire Wire Line
	3750 6450 3950 6450
Wire Wire Line
	3750 6350 3950 6350
Wire Wire Line
	3750 6150 3950 6150
Wire Wire Line
	4650 3200 4450 3200
Wire Wire Line
	4450 3300 4650 3300
NoConn ~ 2800 3900
$Comp
L C C46
U 1 1 564C9B4D
P 4000 7050
F 0 "C46" H 4025 7150 50  0000 L CNN
F 1 "4.7 uF" H 4025 6950 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 4038 6900 30  0001 C CNN
F 3 "" H 4000 7050 60  0000 C CNN
	1    4000 7050
	1    0    0    -1  
$EndComp
Text Label 3850 6900 2    60   ~ 0
SWITCH_JTAG_VDD
Wire Wire Line
	3850 6900 4000 6900
Text Label 3850 7200 2    60   ~ 0
GND
Wire Wire Line
	3850 7200 4000 7200
$EndSCHEMATC
