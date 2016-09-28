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
Sheet 6 7
Title "MARBLEWALRUS Backplane"
Date "2015-11-15"
Rev "$Rev: 2241 $"
Comp "Andrew Zonenberg"
Comment1 "Management blade"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L CONN_MW_MGMT_BACKPLANE J9
U 1 1 564488B1
P 2500 3400
F 0 "J9" H 2500 3350 60  0000 L CNN
F 1 "CONN_MW_MGMT_BACKPLANE" H 2500 3250 60  0000 L CNN
F 2 "azonenberg_pcb:CONN_PCIE_X16_FCI_10018783_10203TLF" H 2500 3400 60  0001 C CNN
F 3 "" H 2500 3400 60  0000 C CNN
	1    2500 3400
	1    0    0    -1  
$EndComp
Text HLabel 4150 1250 2    60   Output ~ 0
ETH8_TX_P
Text HLabel 4150 1350 2    60   Output ~ 0
ETH8_TX_N
Text HLabel 4150 1550 2    60   Input ~ 0
ETH8_RX_P
Text HLabel 4150 1650 2    60   Input ~ 0
ETH8_RX_N
Text HLabel 1950 2250 0    60   Input ~ 0
GND
Text Label 2150 2350 2    60   ~ 0
GND
Text Label 2150 2450 2    60   ~ 0
GND
Text Label 2150 2550 2    60   ~ 0
GND
Text Label 2150 2650 2    60   ~ 0
GND
Text Label 2150 2750 2    60   ~ 0
GND
Text Label 2150 2850 2    60   ~ 0
GND
Text Label 2150 2950 2    60   ~ 0
GND
Text Label 2150 3050 2    60   ~ 0
GND
Text Label 2150 3150 2    60   ~ 0
GND
Text HLabel 4150 2650 2    60   Output ~ 0
I2C_SCL
Text HLabel 4150 2750 2    60   BiDi ~ 0
I2C_SDA
Text Label 4150 2950 0    60   ~ 0
MGMT_JTAG_TCK
Text Label 4150 3050 0    60   ~ 0
MGMT_JTAG_TDI
Text Label 4150 3150 0    60   ~ 0
MGMT_JTAG_TDO
Text Label 4150 3250 0    60   ~ 0
MGMT_JTAG_TMS
Text Label 2150 1950 2    60   ~ 0
MGMT_JTAG_VDD
$Comp
L CONN_MW_MGMT_BACKPLANE J9
U 3 1 56464E00
P 7600 3400
F 0 "J9" H 7600 3350 60  0000 L CNN
F 1 "CONN_MW_MGMT_BACKPLANE" H 7600 3250 60  0000 L CNN
F 2 "azonenberg_pcb:CONN_PCIE_X16_FCI_10018783_10203TLF" H 7600 3400 60  0001 C CNN
F 3 "" H 7600 3400 60  0000 C CNN
	3    7600 3400
	1    0    0    -1  
$EndComp
Text Label 7250 1850 2    60   ~ 0
GND
$Comp
L XILINX_JTAG J14
U 1 1 564698FD
P 2500 5900
F 0 "J14" H 3000 7450 60  0000 C CNN
F 1 "XILINX_JTAG" H 3000 7350 60  0000 C CNN
F 2 "azonenberg_pcb:XILINX_JTAG_PTH_MOLEX_0878311420" H 2500 5900 60  0001 C CNN
F 3 "" H 2500 5900 60  0000 C CNN
	1    2500 5900
	1    0    0    -1  
$EndComp
Text Label 2300 4800 2    60   ~ 0
MGMT_JTAG_VDD
Text Label 2300 4900 2    60   ~ 0
GND
Wire Wire Line
	4150 1650 3950 1650
Wire Wire Line
	3950 1550 4150 1550
Wire Wire Line
	3950 1250 4150 1250
Wire Wire Line
	4150 1350 3950 1350
Wire Wire Line
	1950 2250 2300 2250
Wire Wire Line
	2150 2350 2300 2350
Wire Wire Line
	2150 2450 2300 2450
Wire Wire Line
	2150 2550 2300 2550
Wire Wire Line
	2150 2650 2300 2650
Wire Wire Line
	2150 2750 2300 2750
Wire Wire Line
	2150 2850 2300 2850
Wire Wire Line
	2150 2950 2300 2950
Wire Wire Line
	2150 3050 2300 3050
Wire Wire Line
	2150 3150 2300 3150
Wire Wire Line
	4150 2650 3950 2650
Wire Wire Line
	4150 2750 3950 2750
Wire Wire Line
	4150 2950 3950 2950
Wire Wire Line
	3950 3050 4150 3050
Wire Wire Line
	4150 3150 3950 3150
Wire Wire Line
	3950 3250 4150 3250
Wire Wire Line
	2150 1950 2300 1950
Wire Wire Line
	2150 1250 2300 1250
Wire Wire Line
	2250 1250 2250 1750
Wire Wire Line
	2250 1350 2300 1350
Connection ~ 2250 1250
Wire Wire Line
	2250 1450 2300 1450
Connection ~ 2250 1350
Wire Wire Line
	2250 1550 2300 1550
Connection ~ 2250 1450
Wire Wire Line
	2250 1650 2300 1650
Connection ~ 2250 1550
Wire Wire Line
	2250 1750 2300 1750
Connection ~ 2250 1650
Wire Wire Line
	7250 1850 7400 1850
Wire Wire Line
	7350 1850 7350 3350
Wire Wire Line
	7350 1950 7400 1950
Connection ~ 7350 1850
Wire Wire Line
	7350 2050 7400 2050
Connection ~ 7350 1950
Wire Wire Line
	7350 2150 7400 2150
Connection ~ 7350 2050
Wire Wire Line
	7350 2250 7400 2250
Connection ~ 7350 2150
Wire Wire Line
	7350 2350 7400 2350
Connection ~ 7350 2250
Wire Wire Line
	7350 2450 7400 2450
Connection ~ 7350 2350
Wire Wire Line
	7350 2550 7400 2550
Connection ~ 7350 2450
Wire Wire Line
	7350 2650 7400 2650
Connection ~ 7350 2550
Wire Wire Line
	7350 2750 7400 2750
Connection ~ 7350 2650
Wire Wire Line
	7350 2850 7400 2850
Connection ~ 7350 2750
Wire Wire Line
	7350 2950 7400 2950
Connection ~ 7350 2850
Wire Wire Line
	7350 3050 7400 3050
Connection ~ 7350 2950
Wire Wire Line
	7350 3150 7400 3150
Connection ~ 7350 3050
Wire Wire Line
	7350 3250 7400 3250
Connection ~ 7350 3150
Wire Wire Line
	7350 3350 7400 3350
Connection ~ 7350 3250
Wire Wire Line
	2300 4800 2500 4800
Wire Wire Line
	2300 4900 2500 4900
Wire Wire Line
	2400 4900 2400 5300
Wire Wire Line
	2400 5000 2500 5000
Connection ~ 2400 4900
Wire Wire Line
	2400 5100 2500 5100
Connection ~ 2400 5000
Wire Wire Line
	2400 5200 2500 5200
Connection ~ 2400 5100
Wire Wire Line
	2400 5300 2500 5300
Connection ~ 2400 5200
NoConn ~ 2500 5400
Text Label 2300 5600 2    60   ~ 0
MGMT_JTAG_TCK
Text Label 2300 5800 2    60   ~ 0
MGMT_JTAG_TDI
Text Label 2300 5700 2    60   ~ 0
MGMT_JTAG_TDO
Text Label 2300 5500 2    60   ~ 0
MGMT_JTAG_TMS
Wire Wire Line
	2300 5600 2500 5600
Wire Wire Line
	2300 5800 2500 5800
Wire Wire Line
	2300 5700 2500 5700
Wire Wire Line
	2300 5500 2500 5500
NoConn ~ 2500 5900
Text HLabel 2150 1250 0    60   Input ~ 0
MGMT_12V0
NoConn ~ 2300 2050
NoConn ~ 2300 3350
$Comp
L C C45
U 1 1 564C8F0D
P 2850 6300
F 0 "C45" H 2875 6400 50  0000 L CNN
F 1 "4.7 uF" H 2875 6200 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 2888 6150 30  0001 C CNN
F 3 "" H 2850 6300 60  0000 C CNN
	1    2850 6300
	1    0    0    -1  
$EndComp
Text Label 2700 6150 2    60   ~ 0
MGMT_JTAG_VDD
Text Label 2700 6450 2    60   ~ 0
GND
Wire Wire Line
	2700 6150 2850 6150
Wire Wire Line
	2700 6450 2850 6450
$EndSCHEMATC
