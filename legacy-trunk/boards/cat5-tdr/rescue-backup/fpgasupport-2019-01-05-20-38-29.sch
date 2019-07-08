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
$Descr A3 16535 11693
encoding utf-8
Sheet 11 11
Title "FPGA infrastructure banks (JTAG/power/ground)"
Date "Fri 16 Jan 2015"
Rev "$Rev: 1703 $"
Comp "Andrew Zonenberg"
Comment1 "Quad-Channel 1.25 GSa/s 12-bit Time-Domain Reflectometer"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
Text HLabel 3450 3800 0    60   Input ~ 0
1V8
Text HLabel 8100 900  0    60   Input ~ 0
GND
$Comp
L XC7KxT-FBG484 U20
U 1 1 54AD57DA
P 1500 5800
F 0 "U20" H 1500 5700 60  0000 L CNN
F 1 "XC7K70T-1FBG484" H 2950 5700 60  0000 R CNN
F 2 "azonenberg:BGA_484_22x22_FULLARRAY_1MM" H 1500 5500 60  0001 C CNN
F 3 "" H 1500 5500 60  0000 C CNN
	1    1500 5800
	1    0    0    -1  
$EndComp
$Comp
L XC7KxT-FBG484 U20
U 2 1 54AD5903
P 4550 5800
F 0 "U20" H 4550 5700 60  0000 L CNN
F 1 "XC7K70T-1FBG484" H 6000 5700 60  0000 R CNN
F 2 "azonenberg:BGA_484_22x22_FULLARRAY_1MM" H 4550 5500 60  0001 C CNN
F 3 "" H 4550 5500 60  0000 C CNN
	2    4550 5800
	1    0    0    -1  
$EndComp
$Comp
L XC7KxT-FBG484 U20
U 10 1 54AD5979
P 8500 5800
F 0 "U20" H 8500 5700 60  0000 L CNN
F 1 "XC7K70T-1FBG484" H 9950 5700 60  0000 R CNN
F 2 "azonenberg:BGA_484_22x22_FULLARRAY_1MM" H 8500 5500 60  0001 C CNN
F 3 "" H 8500 5500 60  0000 C CNN
	10   8500 5800
	1    0    0    -1  
$EndComp
Text HLabel 3450 3300 0    60   Input ~ 0
1V2
$Comp
L INDUCTOR_PWROUT L9
U 1 1 54ADBF02
P 3750 3300
F 0 "L9" V 3700 3300 40  0000 C CNN
F 1 "TDK MPZ1608S101ATAH0" V 3850 3300 40  0000 C CNN
F 2 "azonenberg:EIA_0603_INDUCTOR_NOSILK" H 3750 3300 60  0001 C CNN
F 3 "" H 3750 3300 60  0000 C CNN
	1    3750 3300
	0    1    1    0   
$EndComp
$Comp
L INDUCTOR_PWROUT L8
U 1 1 54ADBF97
P 3750 2800
F 0 "L8" V 3700 2800 40  0000 C CNN
F 1 "TDK MPZ1608S101ATAH0" V 3850 2800 40  0000 C CNN
F 2 "azonenberg:EIA_0603_INDUCTOR_NOSILK" H 3750 2800 60  0001 C CNN
F 3 "" H 3750 2800 60  0000 C CNN
	1    3750 2800
	0    1    1    0   
$EndComp
Text HLabel 3450 2800 0    60   Input ~ 0
1V0
Text HLabel 4250 3150 0    60   Output ~ 0
GTX_VTT
Text HLabel 4250 2700 0    60   Output ~ 0
GTX_VCC
$Comp
L XILINX_JTAG J3
U 1 1 54AEACA8
P 2150 7600
F 0 "J3" H 2650 9150 60  0000 C CNN
F 1 "XILINX_JTAG" H 2650 9050 60  0000 C CNN
F 2 "azonenberg:XILINX_JTAG_PTH_MOLEX_0878311420" H 2150 7600 60  0001 C CNN
F 3 "" H 2150 7600 60  0000 C CNN
	1    2150 7600
	1    0    0    -1  
$EndComp
Text Label 2000 6600 2    60   ~ 0
GND
NoConn ~ 2150 7100
Text Label 2000 7200 2    60   ~ 0
JTAG_TMS
Text Label 2000 7300 2    60   ~ 0
JTAG_TCK
Text Label 2000 7500 2    60   ~ 0
JTAG_TDI
$Comp
L R R60
U 1 1 54AEC344
P 1250 7400
F 0 "R60" V 1330 7400 50  0000 C CNN
F 1 "49.9" V 1250 7400 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 1250 7400 60  0001 C CNN
F 3 "" H 1250 7400 60  0000 C CNN
	1    1250 7400
	0    -1   -1   0   
$EndComp
Text Label 2150 7400 2    60   ~ 0
JTAG_TDO_TERM
Text Label 1000 7400 2    60   ~ 0
JTAG_TDO
NoConn ~ 2150 7600
Text Label 1150 4500 2    60   ~ 0
JTAG_TDO
Text Label 1150 4700 2    60   ~ 0
JTAG_TMS
Text Label 1150 4600 2    60   ~ 0
JTAG_TDI
Text Label 1150 4400 2    60   ~ 0
JTAG_TCK
$Comp
L INDUCTOR_PWROUT L10
U 1 1 54AF4874
P 3800 4800
F 0 "L10" V 3750 4550 40  0000 C CNN
F 1 "TDK MPZ1608S101ATAH0" V 3900 4900 40  0000 C CNN
F 2 "azonenberg:EIA_0603_INDUCTOR_NOSILK" H 3800 4800 60  0001 C CNN
F 3 "" H 3800 4800 60  0000 C CNN
	1    3800 4800
	0    1    1    0   
$EndComp
Text HLabel 4250 4700 0    60   Input ~ 0
GTX_VAUX
NoConn ~ 1300 3500
NoConn ~ 1300 3600
Text HLabel 1150 3750 0    60   Input ~ 0
AVREF_1V25
Text Label 1150 3900 2    60   ~ 0
GND
Text Label 1150 4100 2    60   ~ 0
GND
Text Label 1150 5500 2    60   ~ 0
GND
Text Label 3550 3800 0    60   ~ 0
1V8
Text Label 6500 1950 0    60   ~ 0
1V8
Text Notes 6500 2050 0    60   ~ 0
Required for flash
Text Label 6500 3850 0    60   ~ 0
1V8
Text Label 6500 950  0    60   ~ 0
1V8
Text Notes 6500 1050 0    60   ~ 0
Required for config
Text Notes 6500 3950 0    60   ~ 0
Required for LVDS in HP banks
Text Label 6500 4550 0    60   ~ 0
1V8
Text Notes 6500 4650 0    60   ~ 0
Required for LVDS in HP banks
Text Notes 6500 2750 0    60   ~ 0
Required for LVDS in HR banks
Text Notes 6500 3450 0    60   ~ 0
Required for LVDS in HR banks
Text Label 6500 3350 0    60   ~ 0
2V5
Text Label 6500 1250 0    60   ~ 0
1V8
Text Notes 6500 1350 0    60   ~ 0
Low power IO for RGMII
Text HLabel 4950 6550 2    60   Output ~ 0
CCLK
Text Label 1150 4900 2    60   ~ 0
CCLK_UNTERM
Text Label 4450 6550 2    60   ~ 0
CCLK_UNTERM
$Comp
L R R70
U 1 1 54BD3BC3
P 4700 6550
F 0 "R70" V 4780 6550 50  0000 C CNN
F 1 "49.9" V 4700 6550 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 4700 6550 60  0001 C CNN
F 3 "" H 4700 6550 60  0000 C CNN
	1    4700 6550
	0    -1   -1   0   
$EndComp
Text Label 1150 5600 2    60   ~ 0
1V8
Text Label 1150 5700 2    60   ~ 0
GND
Text Label 1150 5200 2    60   ~ 0
INIT_B
Text Label 900  6150 2    60   ~ 0
INIT_B
$Comp
L R R69
U 1 1 54BD6C2F
P 1150 6150
F 0 "R69" V 1230 6150 50  0000 C CNN
F 1 "4.7K" V 1150 6150 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 1150 6150 60  0001 C CNN
F 3 "" H 1150 6150 60  0000 C CNN
	1    1150 6150
	0    1    1    0   
$EndComp
Text Label 1400 6150 0    60   ~ 0
1V8
Text HLabel 1150 5100 0    60   Output ~ 0
FPGA_DONE
Text HLabel 1150 5300 0    60   Input ~ 0
PROG_B_N
Text Label 4450 6850 2    60   ~ 0
PROG_B_N
$Comp
L R R82
U 1 1 54BE4576
P 4700 6850
F 0 "R82" V 4780 6850 50  0000 C CNN
F 1 "4.7K" V 4700 6850 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 4700 6850 60  0001 C CNN
F 3 "" H 4700 6850 60  0000 C CNN
	1    4700 6850
	0    -1   -1   0   
$EndComp
Text Label 4950 6850 0    60   ~ 0
1V8
Text Label 4450 7150 2    60   ~ 0
FPGA_DONE
$Comp
L R R83
U 1 1 54BE466E
P 4700 7150
F 0 "R83" V 4780 7150 50  0000 C CNN
F 1 "330" V 4700 7150 50  0000 C CNN
F 2 "azonenberg:EIA_0402_RES_NOSILK" H 4700 7150 60  0001 C CNN
F 3 "" H 4700 7150 60  0000 C CNN
	1    4700 7150
	0    -1   -1   0   
$EndComp
Text Label 4950 7150 0    60   ~ 0
1V8
Text Label 2000 6500 2    60   ~ 0
1V8
Text HLabel 6500 2600 2    60   Input ~ 0
2V5
Wire Wire Line
	1150 5500 1300 5500
Wire Wire Line
	1150 4200 1300 4200
Wire Wire Line
	1150 4100 1150 4200
Wire Wire Line
	1150 4100 1300 4100
Wire Wire Line
	1150 3750 1150 3800
Wire Wire Line
	1150 3900 1300 3900
Wire Wire Line
	1150 3800 1300 3800
Connection ~ 4250 4800
Wire Wire Line
	4250 4700 4250 4800
Connection ~ 3450 4800
Wire Wire Line
	4250 3800 4250 4600
Connection ~ 4250 4600
Wire Wire Line
	3450 4800 3500 4800
Wire Wire Line
	3450 3800 3450 4950
Wire Wire Line
	4100 4800 4350 4800
Connection ~ 6300 3950
Wire Wire Line
	6200 3950 6300 3950
Connection ~ 6300 4050
Wire Wire Line
	6300 4050 6200 4050
Connection ~ 6300 4150
Wire Wire Line
	6300 4150 6200 4150
Connection ~ 6300 4250
Wire Wire Line
	6300 4250 6200 4250
Connection ~ 6300 4650
Wire Wire Line
	6200 4650 6300 4650
Connection ~ 6300 4750
Wire Wire Line
	6300 4750 6200 4750
Connection ~ 6300 4850
Wire Wire Line
	6300 4850 6200 4850
Connection ~ 6300 4950
Wire Wire Line
	6300 4950 6200 4950
Wire Wire Line
	6300 5050 6200 5050
Wire Wire Line
	6300 4550 6300 5050
Wire Wire Line
	6200 4550 6500 4550
Wire Wire Line
	6300 4350 6200 4350
Wire Wire Line
	6300 3850 6300 4350
Wire Wire Line
	6200 3850 6500 3850
Wire Wire Line
	6300 3650 6200 3650
Wire Wire Line
	6200 3350 6500 3350
Connection ~ 6300 2750
Wire Wire Line
	6300 2750 6200 2750
Connection ~ 6300 2850
Wire Wire Line
	6300 2850 6200 2850
Connection ~ 6300 2950
Wire Wire Line
	6300 2950 6200 2950
Connection ~ 6300 3050
Wire Wire Line
	6300 3050 6200 3050
Wire Wire Line
	6300 3150 6200 3150
Wire Wire Line
	6300 2650 6300 3150
Wire Wire Line
	6200 2650 6500 2650
Connection ~ 6300 2050
Wire Wire Line
	6300 2050 6200 2050
Connection ~ 6300 2150
Wire Wire Line
	6300 2150 6200 2150
Connection ~ 6300 2250
Wire Wire Line
	6300 2250 6200 2250
Connection ~ 6300 2350
Wire Wire Line
	6300 2350 6200 2350
Wire Wire Line
	6300 2450 6200 2450
Wire Wire Line
	6300 1950 6300 2450
Connection ~ 6300 1350
Wire Wire Line
	6300 1350 6200 1350
Connection ~ 6300 1450
Wire Wire Line
	6300 1450 6200 1450
Connection ~ 6300 1550
Wire Wire Line
	6300 1550 6200 1550
Connection ~ 6300 1650
Wire Wire Line
	6300 1650 6200 1650
Wire Wire Line
	6300 1750 6200 1750
Wire Wire Line
	6300 1250 6300 1750
Wire Wire Line
	6200 1250 6500 1250
Wire Wire Line
	6300 1050 6200 1050
Wire Wire Line
	6300 950  6300 1050
Wire Wire Line
	6200 950  6500 950 
Wire Wire Line
	1150 4700 1300 4700
Wire Wire Line
	1300 4600 1150 4600
Wire Wire Line
	1300 4500 1150 4500
Wire Wire Line
	1150 4400 1300 4400
Wire Wire Line
	1500 7400 2150 7400
Wire Wire Line
	2000 7500 2150 7500
Wire Wire Line
	2000 7300 2150 7300
Wire Wire Line
	2000 7200 2150 7200
Connection ~ 2000 6900
Wire Wire Line
	2000 7000 2150 7000
Connection ~ 2000 6800
Wire Wire Line
	2000 6900 2150 6900
Connection ~ 2000 6700
Wire Wire Line
	2000 6800 2150 6800
Wire Wire Line
	2000 6700 2150 6700
Wire Wire Line
	2000 6600 2000 7000
Wire Wire Line
	2000 6600 2150 6600
Wire Wire Line
	3450 4950 4350 4950
Connection ~ 4250 4400
Wire Wire Line
	4250 4600 4350 4600
Connection ~ 4250 4300
Wire Wire Line
	4250 4400 4350 4400
Connection ~ 4250 4200
Wire Wire Line
	4250 4300 4350 4300
Connection ~ 4250 4100
Wire Wire Line
	4250 4200 4350 4200
Connection ~ 4250 4000
Wire Wire Line
	4250 4100 4350 4100
Connection ~ 4250 3900
Wire Wire Line
	4250 4000 4350 4000
Connection ~ 4250 3800
Wire Wire Line
	4250 3900 4350 3900
Wire Wire Line
	3450 3800 4350 3800
Connection ~ 8200 4100
Wire Wire Line
	8200 4100 8300 4100
Connection ~ 8200 4000
Wire Wire Line
	8200 4000 8300 4000
Connection ~ 8200 3900
Wire Wire Line
	8200 3900 8300 3900
Connection ~ 8200 3800
Wire Wire Line
	8200 3800 8300 3800
Connection ~ 8200 3700
Wire Wire Line
	8200 3700 8300 3700
Connection ~ 8200 3600
Wire Wire Line
	8200 3600 8300 3600
Connection ~ 8200 3500
Wire Wire Line
	8200 3500 8300 3500
Connection ~ 8200 3400
Wire Wire Line
	8200 3400 8300 3400
Connection ~ 8200 3300
Wire Wire Line
	8200 3300 8300 3300
Connection ~ 8200 3200
Wire Wire Line
	8200 3200 8300 3200
Connection ~ 8200 3100
Wire Wire Line
	8200 3100 8300 3100
Connection ~ 8200 3000
Wire Wire Line
	8200 3000 8300 3000
Connection ~ 8200 2900
Wire Wire Line
	8200 2900 8300 2900
Connection ~ 8200 2800
Wire Wire Line
	8200 2800 8300 2800
Connection ~ 8200 2700
Wire Wire Line
	8200 2700 8300 2700
Connection ~ 8200 2600
Wire Wire Line
	8200 2600 8300 2600
Connection ~ 8200 2500
Wire Wire Line
	8200 2500 8300 2500
Connection ~ 8200 2400
Wire Wire Line
	8200 2400 8300 2400
Connection ~ 8200 2300
Wire Wire Line
	8200 2300 8300 2300
Connection ~ 8200 2200
Wire Wire Line
	8200 2200 8300 2200
Connection ~ 8200 2100
Wire Wire Line
	8200 2100 8300 2100
Connection ~ 8200 2000
Wire Wire Line
	8200 2000 8300 2000
Connection ~ 8200 1900
Wire Wire Line
	8200 1900 8300 1900
Connection ~ 8200 1800
Wire Wire Line
	8200 1800 8300 1800
Connection ~ 8200 1700
Wire Wire Line
	8200 1700 8300 1700
Connection ~ 8200 1600
Wire Wire Line
	8200 1600 8300 1600
Connection ~ 8200 1500
Wire Wire Line
	8200 1500 8300 1500
Connection ~ 8200 1400
Wire Wire Line
	8200 1400 8300 1400
Connection ~ 10250 1000
Wire Wire Line
	10250 1000 10150 1000
Connection ~ 10250 1100
Wire Wire Line
	10250 1100 10150 1100
Connection ~ 10250 1200
Wire Wire Line
	10250 1200 10150 1200
Connection ~ 10250 1300
Wire Wire Line
	10250 1300 10150 1300
Connection ~ 10250 1400
Wire Wire Line
	10250 1400 10150 1400
Connection ~ 10250 1500
Wire Wire Line
	10250 1500 10150 1500
Connection ~ 10250 1600
Wire Wire Line
	10250 1600 10150 1600
Connection ~ 10250 1700
Wire Wire Line
	10250 1700 10150 1700
Connection ~ 10250 1800
Wire Wire Line
	10250 1800 10150 1800
Connection ~ 10250 1900
Wire Wire Line
	10250 1900 10150 1900
Connection ~ 10250 2000
Wire Wire Line
	10250 2000 10150 2000
Connection ~ 10250 2100
Wire Wire Line
	10250 2100 10150 2100
Connection ~ 10250 2300
Wire Wire Line
	10250 2300 10150 2300
Connection ~ 10250 2200
Wire Wire Line
	10250 2200 10150 2200
Connection ~ 10250 2400
Wire Wire Line
	10250 2400 10150 2400
Connection ~ 10250 2500
Wire Wire Line
	10250 2500 10150 2500
Connection ~ 10250 2600
Wire Wire Line
	10250 2600 10150 2600
Connection ~ 10250 2700
Wire Wire Line
	10250 2700 10150 2700
Connection ~ 10250 2800
Wire Wire Line
	10250 2800 10150 2800
Connection ~ 10250 2900
Wire Wire Line
	10250 2900 10150 2900
Connection ~ 10250 3000
Wire Wire Line
	10250 3000 10150 3000
Connection ~ 10250 3100
Wire Wire Line
	10250 3100 10150 3100
Connection ~ 10250 3200
Wire Wire Line
	10250 3200 10150 3200
Connection ~ 10250 3300
Wire Wire Line
	10250 3300 10150 3300
Connection ~ 10250 3400
Wire Wire Line
	10250 3400 10150 3400
Connection ~ 10250 3500
Wire Wire Line
	10250 3500 10150 3500
Connection ~ 10250 3600
Wire Wire Line
	10250 3600 10150 3600
Connection ~ 10250 3700
Wire Wire Line
	10250 3700 10150 3700
Connection ~ 10250 3800
Wire Wire Line
	10250 3800 10150 3800
Connection ~ 10250 3900
Wire Wire Line
	10250 3900 10150 3900
Connection ~ 10250 4000
Wire Wire Line
	10250 4000 10150 4000
Connection ~ 10250 4100
Wire Wire Line
	10250 4100 10150 4100
Connection ~ 10250 4200
Wire Wire Line
	10250 4200 10150 4200
Connection ~ 10250 4300
Wire Wire Line
	10250 4300 10150 4300
Connection ~ 10250 4400
Wire Wire Line
	10250 4400 10150 4400
Connection ~ 10250 4500
Wire Wire Line
	10250 4500 10150 4500
Connection ~ 10250 4600
Wire Wire Line
	10250 4600 10150 4600
Connection ~ 10250 900 
Wire Wire Line
	10250 4700 10150 4700
Wire Wire Line
	10250 900  10150 900 
Wire Wire Line
	10250 800  10250 4700
Wire Wire Line
	8200 800  10250 800 
Connection ~ 8200 4200
Wire Wire Line
	8200 4200 8300 4200
Connection ~ 8200 4300
Wire Wire Line
	8200 4300 8300 4300
Connection ~ 8200 4400
Wire Wire Line
	8200 4400 8300 4400
Connection ~ 8200 4500
Wire Wire Line
	8200 4500 8300 4500
Connection ~ 8200 4600
Wire Wire Line
	8200 4600 8300 4600
Connection ~ 8200 4700
Wire Wire Line
	8200 4700 8300 4700
Connection ~ 8200 4800
Wire Wire Line
	8200 4800 8300 4800
Connection ~ 8200 4900
Wire Wire Line
	8200 4900 8300 4900
Connection ~ 8200 5000
Wire Wire Line
	8200 5000 8300 5000
Connection ~ 8200 5100
Wire Wire Line
	8200 5100 8300 5100
Connection ~ 8200 5200
Wire Wire Line
	8200 5200 8300 5200
Connection ~ 8200 5300
Wire Wire Line
	8200 5300 8300 5300
Connection ~ 8200 5400
Wire Wire Line
	8200 5400 8300 5400
Connection ~ 8200 5500
Wire Wire Line
	8200 5500 8300 5500
Connection ~ 8200 5600
Wire Wire Line
	8200 5600 8300 5600
Connection ~ 8200 5700
Wire Wire Line
	8200 5700 8300 5700
Connection ~ 8200 1300
Wire Wire Line
	8200 5800 8300 5800
Connection ~ 8200 1200
Wire Wire Line
	8200 1300 8300 1300
Connection ~ 8200 1100
Wire Wire Line
	8200 1200 8300 1200
Connection ~ 8200 900 
Wire Wire Line
	8200 1100 8300 1100
Wire Wire Line
	8200 800  8200 5800
Wire Wire Line
	8100 900  8300 900 
Connection ~ 4250 3000
Wire Wire Line
	4250 3100 4350 3100
Connection ~ 4250 2900
Wire Wire Line
	4250 3000 4350 3000
Wire Wire Line
	4250 2900 4350 2900
Connection ~ 4250 2500
Wire Wire Line
	4250 2500 4350 2500
Connection ~ 4250 2400
Wire Wire Line
	4250 2400 4350 2400
Connection ~ 4250 2200
Wire Wire Line
	4250 2200 4350 2200
Connection ~ 4250 2100
Wire Wire Line
	4250 2100 4350 2100
Connection ~ 4250 2000
Wire Wire Line
	4250 2000 4350 2000
Connection ~ 4250 1900
Wire Wire Line
	4250 1900 4350 1900
Connection ~ 4250 1800
Wire Wire Line
	4250 1800 4350 1800
Connection ~ 4250 1700
Wire Wire Line
	4250 1700 4350 1700
Connection ~ 4250 1600
Wire Wire Line
	4250 1600 4350 1600
Connection ~ 4250 1500
Wire Wire Line
	4250 1500 4350 1500
Connection ~ 4250 1400
Wire Wire Line
	4250 1400 4350 1400
Connection ~ 4250 1300
Wire Wire Line
	4250 1300 4350 1300
Connection ~ 4250 1200
Wire Wire Line
	4250 1200 4350 1200
Connection ~ 4250 1100
Wire Wire Line
	4250 1100 4350 1100
Connection ~ 4250 1000
Wire Wire Line
	4350 1000 4250 1000
Connection ~ 4250 2600
Wire Wire Line
	4250 900  4350 900 
Wire Wire Line
	4250 900  4250 2600
Wire Wire Line
	3450 2600 4350 2600
Wire Wire Line
	3450 2800 3450 2600
Wire Wire Line
	4250 2700 4250 3100
Connection ~ 4250 2800
Wire Wire Line
	4050 2800 4350 2800
Connection ~ 4250 3500
Wire Wire Line
	4250 3600 4350 3600
Connection ~ 4250 3400
Wire Wire Line
	4250 3500 4350 3500
Connection ~ 4250 3300
Wire Wire Line
	4250 3400 4350 3400
Wire Wire Line
	4250 3150 4250 3600
Wire Wire Line
	4050 3300 4350 3300
Connection ~ 6300 2650
Connection ~ 6300 950 
Connection ~ 6300 3850
Connection ~ 6300 4550
Connection ~ 6300 3350
Wire Wire Line
	6200 1950 6500 1950
Connection ~ 6300 1950
Connection ~ 6300 1250
Wire Wire Line
	1150 4900 1300 4900
Wire Wire Line
	1150 5600 1300 5600
Wire Wire Line
	1150 5700 1300 5700
Wire Wire Line
	1300 5700 1300 5800
Wire Wire Line
	1150 5200 1300 5200
Wire Wire Line
	1150 5100 1300 5100
Wire Wire Line
	1150 5300 1300 5300
Wire Wire Line
	2000 6500 2150 6500
Wire Wire Line
	6300 3350 6300 3650
Wire Wire Line
	6300 3550 6200 3550
Connection ~ 6300 3550
Wire Wire Line
	6200 3450 6300 3450
Connection ~ 6300 3450
Wire Wire Line
	6500 2650 6500 2600
$EndSCHEMATC
