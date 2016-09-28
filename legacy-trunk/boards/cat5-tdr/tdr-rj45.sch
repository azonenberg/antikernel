EESchema Schematic File Version 2
LIBS:power
LIBS:device
LIBS:transistors
LIBS:conn
LIBS:linear
LIBS:regul
LIBS:74xx
LIBS:cmos4000
LIBS:adc-dac
LIBS:memory
LIBS:xilinx
LIBS:special
LIBS:microcontrollers
LIBS:dsp
LIBS:microchip
LIBS:analog_switches
LIBS:motorola
LIBS:texas
LIBS:intel
LIBS:audio
LIBS:interface
LIBS:digital-audio
LIBS:philips
LIBS:display
LIBS:cypress
LIBS:siliconi
LIBS:opto
LIBS:atmel
LIBS:contrib
LIBS:valves
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
LIBS:analog-azonenberg
LIBS:cat5-tdr-cache
EELAYER 25 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 9 11
Title "RJ45 and LED drive for TDR"
Date "Fri 16 Jan 2015"
Rev "$Rev: 1703 $"
Comp "Andrew Zonenberg"
Comment1 "Quad-Channel 1.25 GSa/s 12-bit Time-Domain Reflectometer"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L BEL_FUSE_0826-1G1T-23-F J1
U 1 1 54A4A576
P 6100 6850
F 0 "J1" H 6650 6800 60  0000 C CNN
F 1 "BEL_FUSE_0826-1G1T-23-F" H 6150 6600 60  0000 C CNN
F 2 "azonenberg:CONN_BELFUSE_0826_1G1T_23_F" H 6100 6850 60  0001 C CNN
F 3 "" H 6100 6850 60  0000 C CNN
	1    6100 6850
	1    0    0    -1  
$EndComp
$Comp
L C C22
U 1 1 54A4A57D
P 3100 6850
F 0 "C22" H 3150 6950 50  0000 L CNN
F 1 "0.1 uF" H 3150 6750 50  0000 L CNN
F 2 "azonenberg:EIA_0402_CAP_NOSILK" H 3100 6850 60  0001 C CNN
F 3 "" H 3100 6850 60  0000 C CNN
	1    3100 6850
	1    0    0    -1  
$EndComp
Text Label 5600 5450 2    60   ~ 0
CAT5_CH1_TAP
Text Label 5600 5850 2    60   ~ 0
CAT5_CH2_TAP
Text Label 5600 6250 2    60   ~ 0
CAT5_CH3_TAP
$Comp
L C C23
U 1 1 54A4A58A
P 3450 6850
F 0 "C23" H 3500 6950 50  0000 L CNN
F 1 "0.1 uF" H 3500 6750 50  0000 L CNN
F 2 "azonenberg:EIA_0402_CAP_NOSILK" H 3450 6850 60  0001 C CNN
F 3 "" H 3450 6850 60  0000 C CNN
	1    3450 6850
	1    0    0    -1  
$EndComp
$Comp
L C C24
U 1 1 54A4A591
P 3800 6850
F 0 "C24" H 3850 6950 50  0000 L CNN
F 1 "0.1 uF" H 3850 6750 50  0000 L CNN
F 2 "azonenberg:EIA_0402_CAP_NOSILK" H 3800 6850 60  0001 C CNN
F 3 "" H 3800 6850 60  0000 C CNN
	1    3800 6850
	1    0    0    -1  
$EndComp
$Comp
L C C25
U 1 1 54A4A598
P 4150 6850
F 0 "C25" H 4200 6950 50  0000 L CNN
F 1 "0.1 uF" H 4200 6750 50  0000 L CNN
F 2 "azonenberg:EIA_0402_CAP_NOSILK" H 4150 6850 60  0001 C CNN
F 3 "" H 4150 6850 60  0000 C CNN
	1    4150 6850
	1    0    0    -1  
$EndComp
Wire Wire Line
	4150 6650 5800 6650
Wire Wire Line
	2900 7050 4150 7050
Connection ~ 3450 7050
Connection ~ 3800 7050
Connection ~ 3100 7050
Wire Wire Line
	3800 6250 3800 6650
Wire Wire Line
	3450 5850 3450 6650
Wire Wire Line
	3100 5450 3100 6650
Wire Wire Line
	3800 6250 5800 6250
Wire Wire Line
	3450 5850 5800 5850
Wire Wire Line
	3100 5450 5800 5450
$Comp
L R R102
U 1 1 54A4F519
P 3150 2600
F 0 "R102" V 3230 2600 50  0000 C CNN
F 1 "220" V 3150 2600 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 3150 2600 60  0001 C CNN
F 3 "" H 3150 2600 60  0000 C CNN
	1    3150 2600
	1    0    0    -1  
$EndComp
$Comp
L R R103
U 1 1 54A4F520
P 4100 2600
F 0 "R103" V 4180 2600 50  0000 C CNN
F 1 "220" V 4100 2600 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 4100 2600 60  0001 C CNN
F 3 "" H 4100 2600 60  0000 C CNN
	1    4100 2600
	1    0    0    -1  
$EndComp
$Comp
L SSM6N58NU_DUAL_NMOS Q3
U 2 1 54A4F527
P 3050 3650
F 0 "Q3" H 3060 3820 60  0000 R CNN
F 1 "SSM6N58NU" H 3000 3500 60  0000 R CNN
F 2 "azonenberg:DFN_6_0.65MM_2x2MM_GDS" H 3050 3650 60  0001 C CNN
F 3 "" H 3050 3650 60  0000 C CNN
	2    3050 3650
	1    0    0    -1  
$EndComp
$Comp
L SSM6N58NU_DUAL_NMOS Q3
U 1 1 54A4F52E
P 4000 3650
F 0 "Q3" H 4010 3820 60  0000 R CNN
F 1 "SSM6N58NU" H 3950 3500 60  0000 R CNN
F 2 "azonenberg:DFN_6_0.65MM_2x2MM_GDS" H 4000 3650 60  0001 C CNN
F 3 "" H 4000 3650 60  0000 C CNN
	1    4000 3650
	1    0    0    -1  
$EndComp
Text Label 5600 6650 2    60   ~ 0
CAT5_CH4_TAP
Text HLabel 4950 5550 0    60   BiDi ~ 0
CAT5_CH1_P
Wire Wire Line
	4950 5350 5800 5350
Text HLabel 4950 5350 0    60   BiDi ~ 0
CAT5_CH1_N
Wire Wire Line
	4950 5550 5800 5550
Text HLabel 4950 5750 0    60   BiDi ~ 0
CAT5_CH2_P
Text HLabel 4950 5950 0    60   BiDi ~ 0
CAT5_CH2_N
Wire Wire Line
	4950 5950 5800 5950
Wire Wire Line
	5800 5750 4950 5750
Text HLabel 4950 6350 0    60   BiDi ~ 0
CAT5_CH3_P
Text HLabel 4950 6150 0    60   BiDi ~ 0
CAT5_CH3_N
Wire Wire Line
	4950 6150 5800 6150
Wire Wire Line
	5800 6350 4950 6350
Text HLabel 4950 6550 0    60   BiDi ~ 0
CAT5_CH4_P
Wire Wire Line
	4950 6550 5800 6550
Text HLabel 4950 6750 0    60   BiDi ~ 0
CAT5_CH4_N
Wire Wire Line
	4950 6750 5800 6750
Text Label 5800 5050 2    60   ~ 0
TDR_LED2_P
Text Label 5800 4850 2    60   ~ 0
TDR_LED1_P
Text Label 5800 5150 2    60   ~ 0
TDR_LED2_N
Text Label 5800 4950 2    60   ~ 0
TDR_LED1_N
Text Label 4400 3850 0    60   ~ 0
GND
Wire Wire Line
	3150 3850 4400 3850
Connection ~ 4100 3850
Text Label 3150 3300 2    60   ~ 0
TDR_LED1_N
Wire Wire Line
	3150 3300 3150 3450
Text Label 4100 3300 2    60   ~ 0
TDR_LED2_N
Wire Wire Line
	4100 3300 4100 3450
Text HLabel 2600 3650 0    60   Input ~ 0
TDR_LED1
Wire Wire Line
	2600 3650 2850 3650
Text HLabel 3750 3650 0    60   Input ~ 0
TDR_LED2
Wire Wire Line
	3750 3650 3800 3650
Text Label 3150 2850 2    60   ~ 0
TDR_LED1_P
Text Label 4100 2850 2    60   ~ 0
TDR_LED2_P
Text HLabel 3150 2350 0    60   Input ~ 0
2V5
Wire Wire Line
	3150 2350 4100 2350
Text HLabel 2900 7050 0    60   Input ~ 0
GND
Text Label 5800 6950 2    60   ~ 0
GND
Text Notes 3700 5300 0    60   ~ 0
Swap P/N in CH1/3 for routability
$EndSCHEMATC
