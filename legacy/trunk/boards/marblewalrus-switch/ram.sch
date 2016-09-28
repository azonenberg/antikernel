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
LIBS:conn
LIBS:device
LIBS:marblewalrus-switch-cache
EELAYER 25 0
EELAYER END
$Descr A3 16535 11693
encoding utf-8
Sheet 6 13
Title "MARBLEWALRUS Ethernet Switch"
Date "2016-02-14"
Rev "$Rev: 2306 $"
Comp "Andrew Zonenberg"
Comment1 "QDR-II+ SRAM for packet buffering"
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L QDRII+_SRAM_36BIT U2
U 1 1 5686674E
P 9950 5400
F 0 "U2" H 9950 5300 60  0000 L CNN
F 1 "CY7C1145KV18-400BZXC" H 9950 5200 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_165_11x15_FULLARRAY_1MM" H 9950 5400 60  0001 C CNN
F 3 "" H 9950 5400 60  0000 C CNN
	1    9950 5400
	1    0    0    -1  
$EndComp
$Comp
L QDRII+_SRAM_36BIT U2
U 2 1 56866803
P 8150 5400
F 0 "U2" H 8150 5300 60  0000 L CNN
F 1 "CY7C1145KV18-400BZXC" H 8150 5200 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_165_11x15_FULLARRAY_1MM" H 8150 5400 60  0001 C CNN
F 3 "" H 8150 5400 60  0000 C CNN
	2    8150 5400
	1    0    0    -1  
$EndComp
$Comp
L QDRII+_SRAM_36BIT U2
U 3 1 5686686C
P 11650 5400
F 0 "U2" H 11650 5300 60  0000 L CNN
F 1 "CY7C1145KV18-400BZXC" H 11650 5200 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_165_11x15_FULLARRAY_1MM" H 11650 5400 60  0001 C CNN
F 3 "" H 11650 5400 60  0000 C CNN
	3    11650 5400
	1    0    0    -1  
$EndComp
Text Notes 2800 10450 0    60   ~ 0
Misc notes:\n* DOFF_N should be high in controller
$Comp
L R R2
U 1 1 56866F5F
P 13150 1900
F 0 "R2" V 13100 1750 50  0000 C CNN
F 1 "33" V 13150 1900 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 13080 1900 30  0001 C CNN
F 3 "" H 13150 1900 30  0000 C CNN
	1    13150 1900
	0    1    1    0   
$EndComp
$Comp
L R R1
U 1 1 568671A8
P 13150 1600
F 0 "R1" V 13100 1450 50  0000 C CNN
F 1 "249 1%" V 13250 1600 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 13080 1600 30  0001 C CNN
F 3 "" H 13150 1600 30  0000 C CNN
	1    13150 1600
	0    1    1    0   
$EndComp
Text Label 12900 1600 2    60   ~ 0
GND
Text Label 13750 1600 2    60   ~ 0
RAM_RZQ
Text Notes 12300 9900 0    60   ~ 0
Power sequencing:\n* Apply 1V8 before 1V5\n* Apply 1V5 before or at same time as RAM_VREF\n\nEstimated power usage:\n* Vdd (1V8): 920 mA (from datasheet)\n* Vddq (1V5): 584 mA (estimated below)\n* RAM_VREF (VDDQ/2, 0.75V): TODO\n\nTotal I/O power:\n* One toggle @ 12 pF load is 1.3e-11 J, entire bus is 4.8e-10 J\n* Times 800 MT/s is 388 mJ/s = 388 mW = 259 mA per DQ bus\n* Address bus is 1/2 rate and 1/2 width of DQ so 66 mA\n* 2x DQ + A = 584 mA\n\nThermal:\n* \theta J_a is 16.7C C/w static or 15.5 C/w at 300 LFM airflow\n* Core power is 1.65W, I/O power for read bus adds 0.39 W so 2.04 \n  -> 34.1 C rise static\n  -> 31.6 C rise w/ 300LFM\n* Should be OK w/o heatsink up to 48C ambient\n\nBandwidth:\n* Clock speed is 400 MHz (800 MT/s)\n* Available B/Win each direction after ECC:\n    0.8 GT/s * 32 bits = 25.6 Gbps\n* We only need 22 Gbps to saturate all ports so 3.6 Gbps available for CPU etc\n\nCapacity:\n* 16 Mbits (2048 KB) after ECC\n* 64 KB per 1gbit port, 768 KB for 12\n* 512 KB per 10gbit port, 1280 KB for all ports combined\n* 768 KB available for CPU etc\n\nRouting guidelines\n* Max skew +/- 15 ps (xx um) between D and K/~K\n* Max skew +/- 15 ps (xx um) between Q and CQ/~CQ\n* Max skew +/- 50 ps (xx um) between addr/ctrl and K/~K\n\nTermination:\n* Inputs to FPGA should use UNTUNED_SPLIT_50\n* Outputs from FPGA should use SLEW=FAST\n   and a 50 ohm resistor to Vtt (0.75V) at the RAM chip\n\nIOSTANDARD:\n* HSTL_1 for everything
Text HLabel 13700 2700 0    60   Input ~ 0
1V8
Wire Wire Line
	13700 2400 14000 2400
Wire Wire Line
	13900 2400 13900 2500
Wire Wire Line
	13900 2500 14000 2500
Connection ~ 13900 2400
Wire Wire Line
	13700 1800 14000 1800
Wire Wire Line
	13700 2000 14000 2000
Wire Wire Line
	13700 2100 14000 2100
Wire Wire Line
	12900 1900 13000 1900
Wire Wire Line
	13300 1900 14000 1900
Wire Wire Line
	12900 1600 13000 1600
Wire Wire Line
	13300 1600 14000 1600
Wire Wire Line
	15150 2700 15350 2700
Wire Wire Line
	15250 2700 15250 5100
Wire Wire Line
	15250 2800 15150 2800
Connection ~ 15250 2700
Wire Wire Line
	15250 2900 15150 2900
Connection ~ 15250 2800
Wire Wire Line
	15250 3000 15150 3000
Connection ~ 15250 2900
Wire Wire Line
	15250 3100 15150 3100
Connection ~ 15250 3000
Wire Wire Line
	15250 3200 15150 3200
Connection ~ 15250 3100
Wire Wire Line
	15250 3300 15150 3300
Connection ~ 15250 3200
Wire Wire Line
	15250 3400 15150 3400
Connection ~ 15250 3300
Wire Wire Line
	15250 3500 15150 3500
Connection ~ 15250 3400
Wire Wire Line
	15250 3600 15150 3600
Connection ~ 15250 3500
Wire Wire Line
	15250 3700 15150 3700
Connection ~ 15250 3600
Wire Wire Line
	15250 3800 15150 3800
Connection ~ 15250 3700
Wire Wire Line
	15250 3900 15150 3900
Connection ~ 15250 3800
Wire Wire Line
	15250 4000 15150 4000
Connection ~ 15250 3900
Wire Wire Line
	15250 4100 15150 4100
Connection ~ 15250 4000
Wire Wire Line
	15250 4200 15150 4200
Connection ~ 15250 4100
Wire Wire Line
	15250 4300 15150 4300
Connection ~ 15250 4200
Wire Wire Line
	15250 4400 15150 4400
Connection ~ 15250 4300
Wire Wire Line
	15250 4500 15150 4500
Connection ~ 15250 4400
Wire Wire Line
	15250 4600 15150 4600
Connection ~ 15250 4500
Wire Wire Line
	15250 4700 15150 4700
Connection ~ 15250 4600
Wire Wire Line
	15250 4800 15150 4800
Connection ~ 15250 4700
Wire Wire Line
	15250 4900 15150 4900
Connection ~ 15250 4800
Wire Wire Line
	15250 5000 15150 5000
Connection ~ 15250 4900
Wire Wire Line
	15250 5100 15150 5100
Connection ~ 15250 5000
Wire Wire Line
	13700 3800 14000 3800
Wire Wire Line
	13900 3800 13900 5300
Wire Wire Line
	13900 3900 14000 3900
Connection ~ 13900 3800
Wire Wire Line
	13900 4000 14000 4000
Connection ~ 13900 3900
Wire Wire Line
	13900 4100 14000 4100
Connection ~ 13900 4000
Wire Wire Line
	13900 4200 14000 4200
Connection ~ 13900 4100
Wire Wire Line
	13900 4300 14000 4300
Connection ~ 13900 4200
Wire Wire Line
	13900 4400 14000 4400
Connection ~ 13900 4300
Wire Wire Line
	13900 4500 14000 4500
Connection ~ 13900 4400
Wire Wire Line
	13900 4600 14000 4600
Connection ~ 13900 4500
Wire Wire Line
	13900 4700 14000 4700
Connection ~ 13900 4600
Wire Wire Line
	13900 4800 14000 4800
Connection ~ 13900 4700
Wire Wire Line
	13900 4900 14000 4900
Connection ~ 13900 4800
Wire Wire Line
	13900 5000 14000 5000
Connection ~ 13900 4900
Wire Wire Line
	13900 5100 14000 5100
Connection ~ 13900 5000
Wire Wire Line
	13900 5200 14000 5200
Connection ~ 13900 5100
Wire Wire Line
	13900 5300 14000 5300
Connection ~ 13900 5200
Wire Wire Line
	13700 2700 14000 2700
Wire Wire Line
	13900 2700 13900 3600
Wire Wire Line
	13900 2800 14000 2800
Connection ~ 13900 2700
Wire Wire Line
	13900 2900 14000 2900
Connection ~ 13900 2800
Wire Wire Line
	13900 3000 14000 3000
Connection ~ 13900 2900
Wire Wire Line
	13900 3100 14000 3100
Connection ~ 13900 3000
Wire Wire Line
	13900 3200 14000 3200
Connection ~ 13900 3100
Wire Wire Line
	13900 3300 14000 3300
Connection ~ 13900 3200
Wire Wire Line
	13900 3400 14000 3400
Connection ~ 13900 3300
Wire Wire Line
	13900 3500 14000 3500
Connection ~ 13900 3400
Wire Wire Line
	13900 3600 14000 3600
Connection ~ 13900 3500
Text HLabel 13700 3800 0    60   Input ~ 0
1V5
Text HLabel 15350 2700 2    60   Input ~ 0
GND
Text Notes 2800 10750 0    60   ~ 0
TODO: Check against pinout guidelines:\n* see UG586 page 220\n* possibly UG361 page 142
Text Notes 7350 9650 0    60   ~ 0
Vddq decoupling caps:\n* E4-D4\n* F4-E5\n* E7-F8\n* E8-D8\n* K4-L5\n* L7-K8\n* L4-M4\n* L8-M8\n* plus 0603 outside via field
Text Notes 7350 11000 0    60   ~ 0
Vdd decoupling caps:\n* E6-F7\n* F5-F6\n* G6-G7\n* H5-H6\n* J6-J7\n* K5-K6\n* L6-K7\n* plus 0603 outside via field
$Comp
L C C39
U 1 1 5686A836
P 8550 10000
F 0 "C39" H 8575 10100 50  0000 L CNN
F 1 "0.47 uF" H 8575 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8588 9850 30  0001 C CNN
F 3 "" H 8550 10000 60  0000 C CNN
	1    8550 10000
	1    0    0    -1  
$EndComp
$Comp
L C C41
U 1 1 5686A9D7
P 8900 10000
F 0 "C41" H 8925 10100 50  0000 L CNN
F 1 "0.47 uF" H 8925 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8938 9850 30  0001 C CNN
F 3 "" H 8900 10000 60  0000 C CNN
	1    8900 10000
	1    0    0    -1  
$EndComp
$Comp
L C C43
U 1 1 5686AA1D
P 9250 10000
F 0 "C43" H 9275 10100 50  0000 L CNN
F 1 "0.47 uF" H 9275 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9288 9850 30  0001 C CNN
F 3 "" H 9250 10000 60  0000 C CNN
	1    9250 10000
	1    0    0    -1  
$EndComp
$Comp
L C C45
U 1 1 5686AA56
P 9600 10000
F 0 "C45" H 9625 10100 50  0000 L CNN
F 1 "0.47 uF" H 9625 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9638 9850 30  0001 C CNN
F 3 "" H 9600 10000 60  0000 C CNN
	1    9600 10000
	1    0    0    -1  
$EndComp
$Comp
L C C47
U 1 1 5686AA92
P 9950 10000
F 0 "C47" H 9975 10100 50  0000 L CNN
F 1 "0.47 uF" H 9975 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9988 9850 30  0001 C CNN
F 3 "" H 9950 10000 60  0000 C CNN
	1    9950 10000
	1    0    0    -1  
$EndComp
$Comp
L C C49
U 1 1 5686AAD5
P 10300 10000
F 0 "C49" H 10325 10100 50  0000 L CNN
F 1 "0.47 uF" H 10325 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10338 9850 30  0001 C CNN
F 3 "" H 10300 10000 60  0000 C CNN
	1    10300 10000
	1    0    0    -1  
$EndComp
$Comp
L C C51
U 1 1 5686AB13
P 10650 10000
F 0 "C51" H 10675 10100 50  0000 L CNN
F 1 "0.47 uF" H 10675 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10688 9850 30  0001 C CNN
F 3 "" H 10650 10000 60  0000 C CNN
	1    10650 10000
	1    0    0    -1  
$EndComp
$Comp
L C C35
U 1 1 5686AB54
P 7950 10000
F 0 "C35" H 7975 10100 50  0000 L CNN
F 1 "4.7 uF" H 7975 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7988 9850 30  0001 C CNN
F 3 "" H 7950 10000 60  0000 C CNN
	1    7950 10000
	1    0    0    -1  
$EndComp
$Comp
L C C37
U 1 1 5686ABD1
P 8250 10000
F 0 "C37" H 8275 10100 50  0000 L CNN
F 1 "4.7 uF" H 8275 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 8288 9850 30  0001 C CNN
F 3 "" H 8250 10000 60  0000 C CNN
	1    8250 10000
	1    0    0    -1  
$EndComp
Wire Wire Line
	7150 9850 10650 9850
Connection ~ 8250 9850
Connection ~ 8550 9850
Connection ~ 8900 9850
Connection ~ 9250 9850
Connection ~ 9600 9850
Connection ~ 9950 9850
Connection ~ 10300 9850
Wire Wire Line
	7150 10150 10650 10150
Connection ~ 10300 10150
Connection ~ 9950 10150
Connection ~ 9600 10150
Connection ~ 9250 10150
Connection ~ 8900 10150
Connection ~ 8550 10150
Connection ~ 8250 10150
Text Label 7150 9850 2    60   ~ 0
1V8
Connection ~ 7950 9850
Text Label 7150 10150 2    60   ~ 0
GND
Connection ~ 7950 10150
$Comp
L C C38
U 1 1 5686BEAD
P 8550 8550
F 0 "C38" H 8575 8650 50  0000 L CNN
F 1 "0.47 uF" H 8575 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8588 8400 30  0001 C CNN
F 3 "" H 8550 8550 60  0000 C CNN
	1    8550 8550
	1    0    0    -1  
$EndComp
$Comp
L C C40
U 1 1 5686BEB3
P 8900 8550
F 0 "C40" H 8925 8650 50  0000 L CNN
F 1 "0.47 uF" H 8925 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8938 8400 30  0001 C CNN
F 3 "" H 8900 8550 60  0000 C CNN
	1    8900 8550
	1    0    0    -1  
$EndComp
$Comp
L C C42
U 1 1 5686BEB9
P 9250 8550
F 0 "C42" H 9275 8650 50  0000 L CNN
F 1 "0.47 uF" H 9275 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9288 8400 30  0001 C CNN
F 3 "" H 9250 8550 60  0000 C CNN
	1    9250 8550
	1    0    0    -1  
$EndComp
$Comp
L C C44
U 1 1 5686BEBF
P 9600 8550
F 0 "C44" H 9625 8650 50  0000 L CNN
F 1 "0.47 uF" H 9625 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9638 8400 30  0001 C CNN
F 3 "" H 9600 8550 60  0000 C CNN
	1    9600 8550
	1    0    0    -1  
$EndComp
$Comp
L C C46
U 1 1 5686BEC5
P 9950 8550
F 0 "C46" H 9975 8650 50  0000 L CNN
F 1 "0.47 uF" H 9975 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9988 8400 30  0001 C CNN
F 3 "" H 9950 8550 60  0000 C CNN
	1    9950 8550
	1    0    0    -1  
$EndComp
$Comp
L C C48
U 1 1 5686BECB
P 10300 8550
F 0 "C48" H 10325 8650 50  0000 L CNN
F 1 "0.47 uF" H 10325 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10338 8400 30  0001 C CNN
F 3 "" H 10300 8550 60  0000 C CNN
	1    10300 8550
	1    0    0    -1  
$EndComp
$Comp
L C C50
U 1 1 5686BED1
P 10650 8550
F 0 "C50" H 10675 8650 50  0000 L CNN
F 1 "0.47 uF" H 10675 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10688 8400 30  0001 C CNN
F 3 "" H 10650 8550 60  0000 C CNN
	1    10650 8550
	1    0    0    -1  
$EndComp
$Comp
L C C34
U 1 1 5686BED7
P 7950 8550
F 0 "C34" H 7975 8650 50  0000 L CNN
F 1 "4.7 uF" H 7975 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7988 8400 30  0001 C CNN
F 3 "" H 7950 8550 60  0000 C CNN
	1    7950 8550
	1    0    0    -1  
$EndComp
$Comp
L C C36
U 1 1 5686BEDD
P 8250 8550
F 0 "C36" H 8275 8650 50  0000 L CNN
F 1 "4.7 uF" H 8275 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 8288 8400 30  0001 C CNN
F 3 "" H 8250 8550 60  0000 C CNN
	1    8250 8550
	1    0    0    -1  
$EndComp
Wire Wire Line
	7150 8400 11000 8400
Connection ~ 8250 8400
Connection ~ 8550 8400
Connection ~ 8900 8400
Connection ~ 9250 8400
Connection ~ 9600 8400
Connection ~ 9950 8400
Connection ~ 10300 8400
Wire Wire Line
	7150 8700 11000 8700
Connection ~ 10300 8700
Connection ~ 9950 8700
Connection ~ 9600 8700
Connection ~ 9250 8700
Connection ~ 8900 8700
Connection ~ 8550 8700
Connection ~ 8250 8700
Text Label 7150 8400 2    60   ~ 0
1V5
Connection ~ 7950 8400
Text Label 7150 8700 2    60   ~ 0
GND
Connection ~ 7950 8700
$Comp
L C C33
U 1 1 5686BFF4
P 7650 10000
F 0 "C33" H 7675 10100 50  0000 L CNN
F 1 "4.7 uF" H 7675 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7688 9850 30  0001 C CNN
F 3 "" H 7650 10000 60  0000 C CNN
	1    7650 10000
	1    0    0    -1  
$EndComp
$Comp
L C C31
U 1 1 5686C057
P 7350 10000
F 0 "C31" H 7375 10100 50  0000 L CNN
F 1 "4.7 uF" H 7375 9900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7388 9850 30  0001 C CNN
F 3 "" H 7350 10000 60  0000 C CNN
	1    7350 10000
	1    0    0    -1  
$EndComp
Connection ~ 7650 9850
Connection ~ 7650 10150
Connection ~ 7350 9850
Connection ~ 7350 10150
$Comp
L C C32
U 1 1 5686C5DD
P 7650 8550
F 0 "C32" H 7675 8650 50  0000 L CNN
F 1 "4.7 uF" H 7675 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7688 8400 30  0001 C CNN
F 3 "" H 7650 8550 60  0000 C CNN
	1    7650 8550
	1    0    0    -1  
$EndComp
$Comp
L C C30
U 1 1 5686C6A9
P 7350 8550
F 0 "C30" H 7375 8650 50  0000 L CNN
F 1 "4.7 uF" H 7375 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7388 8400 30  0001 C CNN
F 3 "" H 7350 8550 60  0000 C CNN
	1    7350 8550
	1    0    0    -1  
$EndComp
Connection ~ 7350 8400
Connection ~ 7650 8400
Connection ~ 7650 8700
Connection ~ 7350 8700
$Comp
L C C52
U 1 1 5686CE74
P 11000 8550
F 0 "C52" H 11025 8650 50  0000 L CNN
F 1 "0.47 uF" H 11025 8450 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 11038 8400 30  0001 C CNN
F 3 "" H 11000 8550 60  0000 C CNN
	1    11000 8550
	1    0    0    -1  
$EndComp
Connection ~ 10650 8400
Connection ~ 10650 8700
Text HLabel 1050 6750 0    60   Input ~ 0
RAM_VTT
Text HLabel 13700 2400 0    60   Input ~ 0
RAM_VREF
$Comp
L XC7A200T-xFFG1156x U5
U 8 1 56982F70
P 3700 6150
F 0 "U5" H 3700 6100 60  0000 L CNN
F 1 "XC7A200T-1FFG1156C" H 3700 6000 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_1156_35x35_FULLARRAY_1MM" H 3700 6200 60  0001 C CNN
F 3 "" H 3700 6200 60  0000 C CNN
	8    3700 6150
	1    0    0    -1  
$EndComp
Text HLabel 3350 3500 0    60   Input ~ 0
FPGA_CLK_125_P
Text HLabel 3350 3600 0    60   Input ~ 0
FPGA_CLK_125_N
Text Label 11300 3400 2    60   ~ 0
RAM_CLK_P
Wire Wire Line
	11300 3400 11450 3400
Text Label 11300 3500 2    60   ~ 0
RAM_CLK_N
Wire Wire Line
	11300 3500 11450 3500
Text Label 11300 3700 2    60   ~ 0
RAM_A17
Wire Wire Line
	11300 3700 11450 3700
Text Label 11300 3800 2    60   ~ 0
RAM_A16
Wire Wire Line
	11300 3800 11450 3800
Text Label 11300 3900 2    60   ~ 0
RAM_A15
Wire Wire Line
	11300 3900 11450 3900
Text Label 11300 4000 2    60   ~ 0
RAM_A14
Wire Wire Line
	11300 4000 11450 4000
Text Label 11300 4100 2    60   ~ 0
RAM_A13
Wire Wire Line
	11300 4100 11450 4100
Text Label 11300 4200 2    60   ~ 0
RAM_A12
Wire Wire Line
	11300 4200 11450 4200
Text Label 11300 4300 2    60   ~ 0
RAM_A11
Wire Wire Line
	11300 4300 11450 4300
Text Label 11300 4400 2    60   ~ 0
RAM_A10
Wire Wire Line
	11300 4400 11450 4400
Text Label 11300 4500 2    60   ~ 0
RAM_A9
Wire Wire Line
	11300 4500 11450 4500
Text Label 11300 4600 2    60   ~ 0
RAM_A8
Wire Wire Line
	11300 4600 11450 4600
Text Label 11300 4700 2    60   ~ 0
RAM_A7
Wire Wire Line
	11300 4700 11450 4700
Text Label 11300 4800 2    60   ~ 0
RAM_A6
Wire Wire Line
	11300 4800 11450 4800
Text Label 11300 4900 2    60   ~ 0
RAM_A5
Wire Wire Line
	11300 4900 11450 4900
Text Label 11300 5000 2    60   ~ 0
RAM_A4
Wire Wire Line
	11300 5000 11450 5000
Text Label 11300 5100 2    60   ~ 0
RAM_A3
Wire Wire Line
	11300 5100 11450 5100
Text Label 11300 5200 2    60   ~ 0
RAM_A2
Wire Wire Line
	11300 5200 11450 5200
Text Label 11300 5300 2    60   ~ 0
RAM_A1
Wire Wire Line
	11300 5300 11450 5300
Text Label 11300 5400 2    60   ~ 0
RAM_A0
Wire Wire Line
	11300 5400 11450 5400
Text Label 9600 1200 2    60   ~ 0
RAM_WR_N
Wire Wire Line
	9600 1200 9750 1200
Text Label 9600 1400 2    60   ~ 0
RAM_DM0
Wire Wire Line
	9600 1400 9750 1400
Text Label 9600 1500 2    60   ~ 0
RAM_DM1
Wire Wire Line
	9600 1500 9750 1500
Text Label 9600 1600 2    60   ~ 0
RAM_DM2
Wire Wire Line
	9600 1600 9750 1600
Text Label 9600 1700 2    60   ~ 0
RAM_DM3
Wire Wire Line
	9600 1700 9750 1700
Text Label 9600 1900 2    60   ~ 0
RAM_WD0
Wire Wire Line
	9600 1900 9750 1900
Text Label 9600 2000 2    60   ~ 0
RAM_WD1
Wire Wire Line
	9600 2000 9750 2000
Text Label 9600 2100 2    60   ~ 0
RAM_WD2
Wire Wire Line
	9600 2100 9750 2100
Text Label 9600 2200 2    60   ~ 0
RAM_WD3
Wire Wire Line
	9600 2200 9750 2200
Text Label 9600 5100 2    60   ~ 0
RAM_WD32
Wire Wire Line
	9600 5100 9750 5100
Text Label 9600 5200 2    60   ~ 0
RAM_WD33
Wire Wire Line
	9600 5200 9750 5200
Text Label 9600 5300 2    60   ~ 0
RAM_WD34
Wire Wire Line
	9600 5300 9750 5300
Text Label 9600 5400 2    60   ~ 0
RAM_WD35
Wire Wire Line
	9600 5400 9750 5400
Text Label 9600 2300 2    60   ~ 0
RAM_WD4
Wire Wire Line
	9600 2300 9750 2300
Text Label 9600 2400 2    60   ~ 0
RAM_WD5
Wire Wire Line
	9600 2400 9750 2400
Text Label 9600 2500 2    60   ~ 0
RAM_WD6
Wire Wire Line
	9600 2500 9750 2500
Text Label 9600 2600 2    60   ~ 0
RAM_WD7
Wire Wire Line
	9600 2600 9750 2600
Text Label 9600 2700 2    60   ~ 0
RAM_WD8
Wire Wire Line
	9600 2700 9750 2700
Text Label 9600 2800 2    60   ~ 0
RAM_WD9
Wire Wire Line
	9600 2800 9750 2800
Text Label 9600 2900 2    60   ~ 0
RAM_WD10
Wire Wire Line
	9600 2900 9750 2900
Text Label 9600 3000 2    60   ~ 0
RAM_WD11
Wire Wire Line
	9600 3000 9750 3000
Text Label 9600 3100 2    60   ~ 0
RAM_WD12
Wire Wire Line
	9600 3100 9750 3100
Text Label 9600 3200 2    60   ~ 0
RAM_WD13
Wire Wire Line
	9600 3200 9750 3200
Text Label 9600 3300 2    60   ~ 0
RAM_WD14
Wire Wire Line
	9600 3300 9750 3300
Text Label 9600 3400 2    60   ~ 0
RAM_WD15
Wire Wire Line
	9600 3400 9750 3400
Text Label 9600 3500 2    60   ~ 0
RAM_WD16
Wire Wire Line
	9600 3500 9750 3500
Text Label 9600 3600 2    60   ~ 0
RAM_WD17
Wire Wire Line
	9600 3600 9750 3600
Text Label 9600 3700 2    60   ~ 0
RAM_WD18
Wire Wire Line
	9600 3700 9750 3700
Text Label 9600 3800 2    60   ~ 0
RAM_WD19
Wire Wire Line
	9600 3800 9750 3800
Text Label 9600 3900 2    60   ~ 0
RAM_WD20
Wire Wire Line
	9600 3900 9750 3900
Text Label 9600 4000 2    60   ~ 0
RAM_WD21
Wire Wire Line
	9600 4000 9750 4000
Text Label 9600 4100 2    60   ~ 0
RAM_WD22
Wire Wire Line
	9600 4100 9750 4100
Text Label 9600 4200 2    60   ~ 0
RAM_WD23
Wire Wire Line
	9600 4200 9750 4200
Text Label 9600 4300 2    60   ~ 0
RAM_WD24
Wire Wire Line
	9600 4300 9750 4300
Text Label 9600 4400 2    60   ~ 0
RAM_WD25
Wire Wire Line
	9600 4400 9750 4400
Text Label 9600 4500 2    60   ~ 0
RAM_WD26
Wire Wire Line
	9600 4500 9750 4500
Text Label 9600 4600 2    60   ~ 0
RAM_WD27
Wire Wire Line
	9600 4600 9750 4600
Text Label 9600 4700 2    60   ~ 0
RAM_WD28
Wire Wire Line
	9600 4700 9750 4700
Text Label 9600 4800 2    60   ~ 0
RAM_WD29
Wire Wire Line
	9600 4800 9750 4800
Text Label 9600 4900 2    60   ~ 0
RAM_WD30
Wire Wire Line
	9600 4900 9750 4900
Text Label 9600 5000 2    60   ~ 0
RAM_WD31
Wire Wire Line
	9600 5000 9750 5000
Text Label 7800 1200 2    60   ~ 0
RAM_RD_N
Wire Wire Line
	7800 1200 7950 1200
Text Label 7800 1400 2    60   ~ 0
RAM_RCLK_P
Text Label 7800 1500 2    60   ~ 0
RAM_RCLK_N
Wire Wire Line
	7800 1400 7950 1400
Wire Wire Line
	7950 1500 7800 1500
Text Label 7800 1700 2    60   ~ 0
RAM_RVALID
Wire Wire Line
	7800 1700 7950 1700
Text Label 7800 1900 2    60   ~ 0
RAM_RD0
Wire Wire Line
	7800 1900 7950 1900
Text Label 7800 2000 2    60   ~ 0
RAM_RD1
Wire Wire Line
	7800 2000 7950 2000
Text Label 7800 2100 2    60   ~ 0
RAM_RD2
Wire Wire Line
	7800 2100 7950 2100
Text Label 7800 2200 2    60   ~ 0
RAM_RD3
Wire Wire Line
	7800 2200 7950 2200
Text Label 7800 5100 2    60   ~ 0
RAM_RD32
Wire Wire Line
	7800 5100 7950 5100
Text Label 7800 5200 2    60   ~ 0
RAM_RD33
Wire Wire Line
	7800 5200 7950 5200
Text Label 7800 5300 2    60   ~ 0
RAM_RD34
Wire Wire Line
	7800 5300 7950 5300
Text Label 7800 5400 2    60   ~ 0
RAM_RD35
Wire Wire Line
	7800 5400 7950 5400
Text Label 7800 2300 2    60   ~ 0
RAM_RD4
Wire Wire Line
	7800 2300 7950 2300
Text Label 7800 2400 2    60   ~ 0
RAM_RD5
Wire Wire Line
	7800 2400 7950 2400
Text Label 7800 2500 2    60   ~ 0
RAM_RD6
Wire Wire Line
	7800 2500 7950 2500
Text Label 7800 2600 2    60   ~ 0
RAM_RD7
Wire Wire Line
	7800 2600 7950 2600
Text Label 7800 2700 2    60   ~ 0
RAM_RD8
Wire Wire Line
	7800 2700 7950 2700
Text Label 7800 2800 2    60   ~ 0
RAM_RD9
Wire Wire Line
	7800 2800 7950 2800
Text Label 7800 2900 2    60   ~ 0
RAM_RD10
Wire Wire Line
	7800 2900 7950 2900
Text Label 7800 3000 2    60   ~ 0
RAM_RD11
Wire Wire Line
	7800 3000 7950 3000
Text Label 7800 3100 2    60   ~ 0
RAM_RD12
Wire Wire Line
	7800 3100 7950 3100
Text Label 7800 3200 2    60   ~ 0
RAM_RD13
Wire Wire Line
	7800 3200 7950 3200
Text Label 7800 3300 2    60   ~ 0
RAM_RD14
Wire Wire Line
	7800 3300 7950 3300
Text Label 7800 3400 2    60   ~ 0
RAM_RD15
Wire Wire Line
	7800 3400 7950 3400
Text Label 7800 3500 2    60   ~ 0
RAM_RD16
Wire Wire Line
	7800 3500 7950 3500
Text Label 7800 3600 2    60   ~ 0
RAM_RD17
Wire Wire Line
	7800 3600 7950 3600
Text Label 7800 3700 2    60   ~ 0
RAM_RD18
Wire Wire Line
	7800 3700 7950 3700
Text Label 7800 3800 2    60   ~ 0
RAM_RD19
Wire Wire Line
	7800 3800 7950 3800
Text Label 7800 3900 2    60   ~ 0
RAM_RD20
Wire Wire Line
	7800 3900 7950 3900
Text Label 7800 4000 2    60   ~ 0
RAM_RD21
Wire Wire Line
	7800 4000 7950 4000
Text Label 7800 4100 2    60   ~ 0
RAM_RD22
Wire Wire Line
	7800 4100 7950 4100
Text Label 7800 4200 2    60   ~ 0
RAM_RD23
Wire Wire Line
	7800 4200 7950 4200
Text Label 7800 4300 2    60   ~ 0
RAM_RD24
Wire Wire Line
	7800 4300 7950 4300
Text Label 7800 4400 2    60   ~ 0
RAM_RD25
Wire Wire Line
	7800 4400 7950 4400
Text Label 7800 4500 2    60   ~ 0
RAM_RD26
Wire Wire Line
	7800 4500 7950 4500
Text Label 7800 4600 2    60   ~ 0
RAM_RD27
Wire Wire Line
	7800 4600 7950 4600
Text Label 7800 4700 2    60   ~ 0
RAM_RD28
Wire Wire Line
	7800 4700 7950 4700
Text Label 7800 4800 2    60   ~ 0
RAM_RD29
Wire Wire Line
	7800 4800 7950 4800
Text Label 7800 4900 2    60   ~ 0
RAM_RD30
Wire Wire Line
	7800 4900 7950 4900
Text Label 7800 5000 2    60   ~ 0
RAM_RD31
Wire Wire Line
	7800 5000 7950 5000
Text Label 5700 4300 2    60   ~ 0
RAM_RD0
Wire Wire Line
	5700 1700 5850 1700
Text Label 5700 4800 2    60   ~ 0
RAM_RD1
Wire Wire Line
	5700 2100 5850 2100
Text Label 5700 4000 2    60   ~ 0
RAM_RD2
Wire Wire Line
	5700 2200 5850 2200
Text Label 5700 3400 2    60   ~ 0
RAM_RD3
Wire Wire Line
	5700 2300 5850 2300
Text Label 5700 4600 2    60   ~ 0
RAM_RD32
Wire Wire Line
	5700 5800 5850 5800
Text Label 5700 5100 2    60   ~ 0
RAM_RD33
Wire Wire Line
	5700 5900 5850 5900
Text Label 5700 5200 2    60   ~ 0
RAM_RD34
Wire Wire Line
	5700 6000 5850 6000
Text Label 5700 5500 2    60   ~ 0
RAM_RD35
Wire Wire Line
	5700 1300 5850 1300
Text Label 5700 3300 2    60   ~ 0
RAM_RD4
Wire Wire Line
	5700 2500 5850 2500
Text Label 5700 2200 2    60   ~ 0
RAM_RD5
Wire Wire Line
	5700 1400 5850 1400
Text Label 5700 2100 2    60   ~ 0
RAM_RD6
Wire Wire Line
	5700 2700 5850 2700
Text Label 5700 1300 2    60   ~ 0
RAM_RD7
Wire Wire Line
	5700 2800 5850 2800
Text Label 5700 1400 2    60   ~ 0
RAM_RD8
Wire Wire Line
	5700 2900 5850 2900
Text Label 5700 5700 2    60   ~ 0
RAM_RD9
Wire Wire Line
	5700 3000 5850 3000
Text Label 5700 4900 2    60   ~ 0
RAM_RD10
Wire Wire Line
	5700 3100 5850 3100
Text Label 5700 4700 2    60   ~ 0
RAM_RD11
Wire Wire Line
	5700 3200 5850 3200
Text Label 5700 3900 2    60   ~ 0
RAM_RD12
Wire Wire Line
	5700 3300 5850 3300
Text Label 5700 2900 2    60   ~ 0
RAM_RD13
Wire Wire Line
	5700 3400 5850 3400
Text Label 5700 3000 2    60   ~ 0
RAM_RD14
Wire Wire Line
	5700 3900 5850 3900
Text Label 5700 2500 2    60   ~ 0
RAM_RD15
Wire Wire Line
	5700 4000 5850 4000
Text Label 5700 1700 2    60   ~ 0
RAM_RD16
Wire Wire Line
	5700 4100 5850 4100
Text Label 5700 1800 2    60   ~ 0
RAM_RD17
Wire Wire Line
	5700 4200 5850 4200
Text Label 5700 5300 2    60   ~ 0
RAM_RD18
Wire Wire Line
	5700 4300 5850 4300
Text Label 5700 4400 2    60   ~ 0
RAM_RD19
Wire Wire Line
	5700 4400 5850 4400
Text Label 5700 2800 2    60   ~ 0
RAM_RD20
Wire Wire Line
	5700 4500 5850 4500
Text Label 5700 3100 2    60   ~ 0
RAM_RD21
Wire Wire Line
	5700 4600 5850 4600
Text Label 5700 4100 2    60   ~ 0
RAM_RD22
Wire Wire Line
	5700 4700 5850 4700
Text Label 5700 4500 2    60   ~ 0
RAM_RD23
Wire Wire Line
	5700 4800 5850 4800
Text Label 5700 5600 2    60   ~ 0
RAM_RD24
Wire Wire Line
	5700 4900 5850 4900
Text Label 5700 5900 2    60   ~ 0
RAM_RD25
Wire Wire Line
	5700 5100 5850 5100
Text Label 5700 6000 2    60   ~ 0
RAM_RD26
Wire Wire Line
	5700 5200 5850 5200
Text Label 5700 5800 2    60   ~ 0
RAM_RD27
Wire Wire Line
	5700 5300 5850 5300
Text Label 5700 5400 2    60   ~ 0
RAM_RD28
Wire Wire Line
	5700 5400 5850 5400
Text Label 5700 2700 2    60   ~ 0
RAM_RD29
Wire Wire Line
	5700 5500 5850 5500
Text Label 5700 3200 2    60   ~ 0
RAM_RD30
Wire Wire Line
	5700 5600 5850 5600
Text Label 5700 4200 2    60   ~ 0
RAM_RD31
Wire Wire Line
	5700 5700 5850 5700
Text Label 5700 2300 2    60   ~ 0
RAM_RD_N
Wire Wire Line
	5700 1800 5850 1800
Text Label 5700 3500 2    60   ~ 0
RAM_RCLK_P
Text Label 5700 3700 2    60   ~ 0
RAM_RCLK_N
Wire Wire Line
	5700 3500 5850 3500
Wire Wire Line
	5850 3700 5700 3700
Text Label 5700 1900 2    60   ~ 0
RAM_RVALID
Wire Wire Line
	5700 1900 5850 1900
NoConn ~ 5850 3600
NoConn ~ 5850 3800
NoConn ~ 5850 1600
NoConn ~ 5850 1500
NoConn ~ 5850 1200
Text Label 3350 4200 2    60   ~ 0
RAM_WR_N
Wire Wire Line
	3350 1200 3500 1200
Text Label 3350 2500 2    60   ~ 0
RAM_DM0
Wire Wire Line
	3350 1700 3500 1700
Text Label 3350 2700 2    60   ~ 0
RAM_DM1
Wire Wire Line
	3350 1800 3500 1800
Text Label 3350 3200 2    60   ~ 0
RAM_DM2
Wire Wire Line
	3350 1900 3500 1900
Text Label 3350 4600 2    60   ~ 0
RAM_DM3
Wire Wire Line
	3350 3200 3500 3200
Text Label 3350 3400 2    60   ~ 0
RAM_WD0
Wire Wire Line
	3350 2100 3500 2100
Text Label 3350 3000 2    60   ~ 0
RAM_WD1
Wire Wire Line
	3350 2200 3500 2200
Text Label 3350 2900 2    60   ~ 0
RAM_WD2
Wire Wire Line
	3350 2300 3500 2300
Text Label 3350 2300 2    60   ~ 0
RAM_WD3
Wire Wire Line
	3350 2500 3500 2500
Text Label 3350 5300 2    60   ~ 0
RAM_WD32
Wire Wire Line
	3350 5800 3500 5800
Text Label 3350 5700 2    60   ~ 0
RAM_WD33
Wire Wire Line
	3350 5900 3500 5900
Text Label 3350 5100 2    60   ~ 0
RAM_WD34
Wire Wire Line
	3350 6000 3500 6000
Text Label 3350 6000 2    60   ~ 0
RAM_WD35
Wire Wire Line
	3350 6100 3500 6100
Text Label 3350 1900 2    60   ~ 0
RAM_WD4
Wire Wire Line
	3350 2600 3500 2600
Text Label 3350 2200 2    60   ~ 0
RAM_WD5
Wire Wire Line
	3350 2700 3500 2700
Text Label 3350 1400 2    60   ~ 0
RAM_WD6
Wire Wire Line
	3350 2800 3500 2800
Text Label 3350 1200 2    60   ~ 0
RAM_WD7
Wire Wire Line
	3350 2900 3500 2900
Text Label 3350 4800 2    60   ~ 0
RAM_WD8
Wire Wire Line
	3350 3000 3500 3000
Text Label 3350 4700 2    60   ~ 0
RAM_WD9
Wire Wire Line
	3350 3100 3500 3100
Text Label 3350 3300 2    60   ~ 0
RAM_WD10
Text Label 3350 3100 2    60   ~ 0
RAM_WD11
Wire Wire Line
	3350 3300 3500 3300
Text Label 3350 6100 2    60   ~ 0
RAM_WD12
Wire Wire Line
	3350 3400 3500 3400
Text Label 3350 2100 2    60   ~ 0
RAM_WD13
Wire Wire Line
	3350 3500 3500 3500
Text Label 3350 1300 2    60   ~ 0
RAM_WD14
Wire Wire Line
	3350 3600 3500 3600
Text Label 3350 1700 2    60   ~ 0
RAM_WD15
Wire Wire Line
	3350 4000 3500 4000
Text Label 3350 2600 2    60   ~ 0
RAM_WD16
Wire Wire Line
	3350 4100 3500 4100
Text Label 3350 1800 2    60   ~ 0
RAM_WD17
Wire Wire Line
	3350 4200 3500 4200
Text Label 3350 3700 2    60   ~ 0
RAM_WD18
Wire Wire Line
	3350 4300 3500 4300
Text Label 3350 5500 2    60   ~ 0
RAM_WD19
Wire Wire Line
	3350 4400 3500 4400
Text Label 3350 4400 2    60   ~ 0
RAM_WD20
Wire Wire Line
	3350 4500 3500 4500
Text Label 3350 5600 2    60   ~ 0
RAM_WD21
Wire Wire Line
	3350 4600 3500 4600
Text Label 3350 2800 2    60   ~ 0
RAM_WD22
Wire Wire Line
	3350 4700 3500 4700
Text Label 3350 5400 2    60   ~ 0
RAM_WD23
Wire Wire Line
	3350 4800 3500 4800
Text Label 3350 5800 2    60   ~ 0
RAM_WD24
Wire Wire Line
	3350 4900 3500 4900
Text Label 3350 5200 2    60   ~ 0
RAM_WD25
Wire Wire Line
	3350 5100 3500 5100
Text Label 3350 5900 2    60   ~ 0
RAM_WD26
Wire Wire Line
	3350 5200 3500 5200
Text Label 3350 4500 2    60   ~ 0
RAM_WD27
Wire Wire Line
	3350 5300 3500 5300
Text Label 3350 4000 2    60   ~ 0
RAM_WD28
Wire Wire Line
	3350 5400 3500 5400
Text Label 3350 3900 2    60   ~ 0
RAM_WD29
Wire Wire Line
	3350 5500 3500 5500
Text Label 3350 4300 2    60   ~ 0
RAM_WD30
Wire Wire Line
	3350 5600 3500 5600
Text Label 3350 4900 2    60   ~ 0
RAM_WD31
Wire Wire Line
	3350 5700 3500 5700
Wire Wire Line
	3350 3700 3500 3700
Wire Wire Line
	3500 3800 3350 3800
NoConn ~ 3500 1500
Text Label 3350 3800 2    60   ~ 0
RAM_CLK_P
Wire Wire Line
	3350 1300 3500 1300
Text Label 3350 4100 2    60   ~ 0
RAM_CLK_N
Wire Wire Line
	3350 1400 3500 1400
Text Label 1200 2200 2    60   ~ 0
RAM_A17
Wire Wire Line
	1200 3600 1350 3600
Text Label 1200 2800 2    60   ~ 0
RAM_A16
Wire Wire Line
	1200 2700 1350 2700
Text Label 1200 3600 2    60   ~ 0
RAM_A15
Wire Wire Line
	1200 2200 1350 2200
Text Label 1200 3000 2    60   ~ 0
RAM_A14
Wire Wire Line
	1200 3000 1350 3000
Text Label 1200 3100 2    60   ~ 0
RAM_A13
Wire Wire Line
	1200 3200 1350 3200
Text Label 1200 3300 2    60   ~ 0
RAM_A12
Wire Wire Line
	1200 3400 1350 3400
Text Label 1200 1900 2    60   ~ 0
RAM_A11
Wire Wire Line
	1200 2600 1350 2600
Text Label 1200 2000 2    60   ~ 0
RAM_A10
Wire Wire Line
	1200 1300 1350 1300
Text Label 1200 3400 2    60   ~ 0
RAM_A9
Wire Wire Line
	1200 1400 1350 1400
Text Label 1200 1600 2    60   ~ 0
RAM_A8
Wire Wire Line
	1200 1500 1350 1500
Text Label 1200 2100 2    60   ~ 0
RAM_A7
Wire Wire Line
	1200 1600 1350 1600
Text Label 1200 1700 2    60   ~ 0
RAM_A6
Wire Wire Line
	1200 1700 1350 1700
Text Label 1200 2300 2    60   ~ 0
RAM_A5
Wire Wire Line
	1200 1800 1350 1800
Text Label 1200 1500 2    60   ~ 0
RAM_A3
Wire Wire Line
	1200 2000 1350 2000
Text Label 1200 1300 2    60   ~ 0
RAM_A2
Wire Wire Line
	1200 2100 1350 2100
Text Label 1200 1400 2    60   ~ 0
RAM_A1
Wire Wire Line
	1200 3300 1350 3300
Text Label 1200 1800 2    60   ~ 0
RAM_A0
Wire Wire Line
	1200 2300 1350 2300
NoConn ~ 1350 1200
NoConn ~ 1350 3500
Wire Wire Line
	13800 1500 14000 1500
Text Label 3450 7150 0    60   ~ 0
RAM_A17
Text Label 3450 7250 0    60   ~ 0
RAM_A16
Text Label 3450 7350 0    60   ~ 0
RAM_A15
Text Label 3450 7450 0    60   ~ 0
RAM_A14
Text Label 3450 7550 0    60   ~ 0
RAM_A13
Text Label 3450 7650 0    60   ~ 0
RAM_A12
Text Label 3450 7750 0    60   ~ 0
RAM_A11
Text Label 3450 7850 0    60   ~ 0
RAM_A10
Text Label 3450 7950 0    60   ~ 0
RAM_A9
Text Label 3450 8050 0    60   ~ 0
RAM_A8
Text Label 3450 8150 0    60   ~ 0
RAM_A7
Text Label 3450 8250 0    60   ~ 0
RAM_A6
Text Label 3450 8350 0    60   ~ 0
RAM_A5
Text Label 3450 8450 0    60   ~ 0
RAM_A4
Text Label 3450 8550 0    60   ~ 0
RAM_A3
Text Label 3450 8650 0    60   ~ 0
RAM_A2
Text Label 3450 8750 0    60   ~ 0
RAM_A1
Text Label 3450 8850 0    60   ~ 0
RAM_A0
Text Label 1700 10450 0    60   ~ 0
RAM_WD32
Text Label 1700 10550 0    60   ~ 0
RAM_WD33
Text Label 1700 10650 0    60   ~ 0
RAM_WD34
Text Label 1700 10750 0    60   ~ 0
RAM_WD35
Text Label 1700 8650 0    60   ~ 0
RAM_WD14
Text Label 1700 8750 0    60   ~ 0
RAM_WD15
Text Label 1700 8850 0    60   ~ 0
RAM_WD16
Text Label 1700 8950 0    60   ~ 0
RAM_WD17
Text Label 1700 9050 0    60   ~ 0
RAM_WD18
Text Label 1700 9150 0    60   ~ 0
RAM_WD19
Text Label 1700 9250 0    60   ~ 0
RAM_WD20
Text Label 1700 9350 0    60   ~ 0
RAM_WD21
Text Label 1700 9450 0    60   ~ 0
RAM_WD22
Text Label 1700 9550 0    60   ~ 0
RAM_WD23
Text Label 1700 9650 0    60   ~ 0
RAM_WD24
Text Label 1700 9750 0    60   ~ 0
RAM_WD25
Text Label 1700 9850 0    60   ~ 0
RAM_WD26
Text Label 1700 9950 0    60   ~ 0
RAM_WD27
Text Label 1700 10050 0    60   ~ 0
RAM_WD28
Text Label 1700 10150 0    60   ~ 0
RAM_WD29
Text Label 1700 10250 0    60   ~ 0
RAM_WD30
Text Label 1700 10350 0    60   ~ 0
RAM_WD31
Text Label 1700 6750 0    60   ~ 0
RAM_WR_N
Text Label 1700 6850 0    60   ~ 0
RAM_DM0
Text Label 1700 6950 0    60   ~ 0
RAM_DM1
Text Label 1700 7050 0    60   ~ 0
RAM_DM2
Text Label 1700 7150 0    60   ~ 0
RAM_DM3
Text Label 1700 7250 0    60   ~ 0
RAM_WD0
Text Label 1700 7350 0    60   ~ 0
RAM_WD1
Text Label 1700 7450 0    60   ~ 0
RAM_WD2
Text Label 1700 7550 0    60   ~ 0
RAM_WD3
Text Label 1700 7650 0    60   ~ 0
RAM_WD4
Text Label 1700 7750 0    60   ~ 0
RAM_WD5
Text Label 1700 7850 0    60   ~ 0
RAM_WD6
Text Label 1700 7950 0    60   ~ 0
RAM_WD7
Text Label 1700 8050 0    60   ~ 0
RAM_WD8
Text Label 1700 8150 0    60   ~ 0
RAM_WD9
Text Label 1700 8250 0    60   ~ 0
RAM_WD10
Text Label 1700 8350 0    60   ~ 0
RAM_WD11
Text Label 1700 8450 0    60   ~ 0
RAM_WD12
Text Label 1700 8550 0    60   ~ 0
RAM_WD13
Text Label 3450 6950 0    60   ~ 0
RAM_CLK_P
Text Label 3450 7050 0    60   ~ 0
RAM_CLK_N
Text Label 3450 6850 0    60   ~ 0
RAM_RD_N
Text Label 5700 2400 2    60   ~ 0
RAM_VREF
Wire Wire Line
	5700 2400 5850 2400
Text Label 5700 5000 2    60   ~ 0
RAM_VREF
Wire Wire Line
	5700 5000 5850 5000
Text Label 3350 2400 2    60   ~ 0
RAM_VREF
Wire Wire Line
	3350 2400 3500 2400
Text Label 3350 5000 2    60   ~ 0
RAM_VREF
Wire Wire Line
	3350 5000 3500 5000
Text Label 1200 2400 2    60   ~ 0
RAM_VREF
Wire Wire Line
	1200 2400 1350 2400
Text Label 1200 5000 2    60   ~ 0
RAM_VREF
Wire Wire Line
	1200 5000 1350 5000
Text Notes 7350 7800 0    60   ~ 0
Vref filter caps
Text Label 7150 7850 2    60   ~ 0
RAM_VREF
$Comp
L C C184
U 1 1 56ACABE8
P 7950 8000
F 0 "C184" H 7975 8100 50  0000 L CNN
F 1 "0.47 uF" H 7975 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 7988 7850 30  0001 C CNN
F 3 "" H 7950 8000 60  0000 C CNN
	1    7950 8000
	1    0    0    -1  
$EndComp
Text Label 7150 8150 2    60   ~ 0
GND
Wire Wire Line
	7150 7850 10400 7850
Wire Wire Line
	7150 8150 10400 8150
$Comp
L C C181
U 1 1 56ACB293
P 7350 8000
F 0 "C181" H 7375 8100 50  0000 L CNN
F 1 "4.7 uF" H 7375 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7388 7850 30  0001 C CNN
F 3 "" H 7350 8000 60  0000 C CNN
	1    7350 8000
	1    0    0    -1  
$EndComp
$Comp
L C C182
U 1 1 56ACB325
P 7650 8000
F 0 "C182" H 7675 8100 50  0000 L CNN
F 1 "4.7 uF" H 7675 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7688 7850 30  0001 C CNN
F 3 "" H 7650 8000 60  0000 C CNN
	1    7650 8000
	1    0    0    -1  
$EndComp
$Comp
L C C187
U 1 1 56ACB541
P 8300 8000
F 0 "C187" H 8325 8100 50  0000 L CNN
F 1 "0.47 uF" H 8325 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8338 7850 30  0001 C CNN
F 3 "" H 8300 8000 60  0000 C CNN
	1    8300 8000
	1    0    0    -1  
$EndComp
$Comp
L C C189
U 1 1 56ACB5C7
P 8650 8000
F 0 "C189" H 8675 8100 50  0000 L CNN
F 1 "0.47 uF" H 8675 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8688 7850 30  0001 C CNN
F 3 "" H 8650 8000 60  0000 C CNN
	1    8650 8000
	1    0    0    -1  
$EndComp
$Comp
L C C191
U 1 1 56ACB650
P 9000 8000
F 0 "C191" H 9025 8100 50  0000 L CNN
F 1 "0.47 uF" H 9025 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9038 7850 30  0001 C CNN
F 3 "" H 9000 8000 60  0000 C CNN
	1    9000 8000
	1    0    0    -1  
$EndComp
$Comp
L C C193
U 1 1 56ACB6E2
P 9350 8000
F 0 "C193" H 9375 8100 50  0000 L CNN
F 1 "0.47 uF" H 9375 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9388 7850 30  0001 C CNN
F 3 "" H 9350 8000 60  0000 C CNN
	1    9350 8000
	1    0    0    -1  
$EndComp
$Comp
L C C195
U 1 1 56ACB771
P 9700 8000
F 0 "C195" H 9725 8100 50  0000 L CNN
F 1 "0.47 uF" H 9725 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9738 7850 30  0001 C CNN
F 3 "" H 9700 8000 60  0000 C CNN
	1    9700 8000
	1    0    0    -1  
$EndComp
$Comp
L C C197
U 1 1 56ACB889
P 10050 8000
F 0 "C197" H 10075 8100 50  0000 L CNN
F 1 "0.47 uF" H 10075 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10088 7850 30  0001 C CNN
F 3 "" H 10050 8000 60  0000 C CNN
	1    10050 8000
	1    0    0    -1  
$EndComp
$Comp
L C C198
U 1 1 56ACB91E
P 10400 8000
F 0 "C198" H 10425 8100 50  0000 L CNN
F 1 "0.47 uF" H 10425 7900 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10438 7850 30  0001 C CNN
F 3 "" H 10400 8000 60  0000 C CNN
	1    10400 8000
	1    0    0    -1  
$EndComp
Connection ~ 7350 7850
Connection ~ 7650 7850
Connection ~ 7950 7850
Connection ~ 8300 7850
Connection ~ 8650 7850
Connection ~ 9000 7850
Connection ~ 9350 7850
Connection ~ 9700 7850
Connection ~ 10050 7850
Connection ~ 10050 8150
Connection ~ 9700 8150
Connection ~ 9350 8150
Connection ~ 9000 8150
Connection ~ 8650 8150
Connection ~ 8300 8150
Connection ~ 7950 8150
Connection ~ 7350 8150
Connection ~ 7650 8150
Text Notes 7350 7200 0    60   ~ 0
Vtt filter caps
$Comp
L C C180
U 1 1 56ACE15F
P 7350 7400
F 0 "C180" H 7375 7500 50  0000 L CNN
F 1 "100 uF" H 7375 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_1206_CAP_NOSILK" H 7388 7250 30  0001 C CNN
F 3 "" H 7350 7400 60  0000 C CNN
	1    7350 7400
	1    0    0    -1  
$EndComp
$Comp
L C C183
U 1 1 56ACE269
P 7700 7400
F 0 "C183" H 7725 7500 50  0000 L CNN
F 1 "4.7 uF" H 7725 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 7738 7250 30  0001 C CNN
F 3 "" H 7700 7400 60  0000 C CNN
	1    7700 7400
	1    0    0    -1  
$EndComp
$Comp
L C C185
U 1 1 56ACE32B
P 8000 7400
F 0 "C185" H 8025 7500 50  0000 L CNN
F 1 "4.7 uF" H 8025 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0603_CAP_NOSILK" H 8038 7250 30  0001 C CNN
F 3 "" H 8000 7400 60  0000 C CNN
	1    8000 7400
	1    0    0    -1  
$EndComp
$Comp
L C C186
U 1 1 56ACE3CE
P 8300 7400
F 0 "C186" H 8325 7500 50  0000 L CNN
F 1 "0.47 uF" H 8325 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8338 7250 30  0001 C CNN
F 3 "" H 8300 7400 60  0000 C CNN
	1    8300 7400
	1    0    0    -1  
$EndComp
$Comp
L C C188
U 1 1 56ACE48E
P 8650 7400
F 0 "C188" H 8675 7500 50  0000 L CNN
F 1 "0.47 uF" H 8675 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 8688 7250 30  0001 C CNN
F 3 "" H 8650 7400 60  0000 C CNN
	1    8650 7400
	1    0    0    -1  
$EndComp
$Comp
L C C190
U 1 1 56ACE537
P 9000 7400
F 0 "C190" H 9025 7500 50  0000 L CNN
F 1 "0.47 uF" H 9025 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9038 7250 30  0001 C CNN
F 3 "" H 9000 7400 60  0000 C CNN
	1    9000 7400
	1    0    0    -1  
$EndComp
$Comp
L C C192
U 1 1 56ACE5E1
P 9350 7400
F 0 "C192" H 9375 7500 50  0000 L CNN
F 1 "0.47 uF" H 9375 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9388 7250 30  0001 C CNN
F 3 "" H 9350 7400 60  0000 C CNN
	1    9350 7400
	1    0    0    -1  
$EndComp
$Comp
L C C194
U 1 1 56ACE68E
P 9700 7400
F 0 "C194" H 9725 7500 50  0000 L CNN
F 1 "0.47 uF" H 9725 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 9738 7250 30  0001 C CNN
F 3 "" H 9700 7400 60  0000 C CNN
	1    9700 7400
	1    0    0    -1  
$EndComp
$Comp
L C C196
U 1 1 56ACE73E
P 10050 7400
F 0 "C196" H 10075 7500 50  0000 L CNN
F 1 "0.47 uF" H 10075 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10088 7250 30  0001 C CNN
F 3 "" H 10050 7400 60  0000 C CNN
	1    10050 7400
	1    0    0    -1  
$EndComp
Text Label 7150 7250 2    60   ~ 0
RAM_VTT
Text Label 7150 7550 2    60   ~ 0
GND
Wire Wire Line
	7150 7550 10400 7550
Connection ~ 7350 7550
Connection ~ 7700 7550
Connection ~ 8000 7550
Connection ~ 8300 7550
Connection ~ 8650 7550
Connection ~ 9000 7550
Connection ~ 9350 7550
Connection ~ 9700 7550
Wire Wire Line
	7150 7250 10400 7250
Connection ~ 9700 7250
Connection ~ 9350 7250
Connection ~ 9000 7250
Connection ~ 8650 7250
Connection ~ 8300 7250
Connection ~ 8000 7250
Connection ~ 7700 7250
Connection ~ 7350 7250
$Comp
L R R42
U 1 1 56AD13EF
P 1350 6750
F 0 "R42" V 1300 6950 50  0000 C CNN
F 1 "49.9" V 1350 6750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 6750 30  0001 C CNN
F 3 "" H 1350 6750 30  0000 C CNN
	1    1350 6750
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 6750 1700 6750
Wire Wire Line
	1050 6750 1200 6750
$Comp
L R R45
U 1 1 56AD2016
P 1350 6850
F 0 "R45" V 1300 7050 50  0000 C CNN
F 1 "49.9" V 1350 6850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 6850 30  0001 C CNN
F 3 "" H 1350 6850 30  0000 C CNN
	1    1350 6850
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 6850 1700 6850
Wire Wire Line
	1100 6750 1100 10750
Wire Wire Line
	1100 6850 1200 6850
Connection ~ 1100 6750
$Comp
L R R46
U 1 1 56AD22CE
P 1350 6950
F 0 "R46" V 1300 7150 50  0000 C CNN
F 1 "49.9" V 1350 6950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 6950 30  0001 C CNN
F 3 "" H 1350 6950 30  0000 C CNN
	1    1350 6950
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 6950 1700 6950
Wire Wire Line
	1100 6950 1200 6950
$Comp
L R R47
U 1 1 56AD22D6
P 1350 7050
F 0 "R47" V 1300 7250 50  0000 C CNN
F 1 "49.9" V 1350 7050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7050 30  0001 C CNN
F 3 "" H 1350 7050 30  0000 C CNN
	1    1350 7050
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7050 1700 7050
Wire Wire Line
	1100 7050 1200 7050
Connection ~ 1100 6950
Connection ~ 1100 6850
$Comp
L R R48
U 1 1 56AD2758
P 1350 7150
F 0 "R48" V 1300 7350 50  0000 C CNN
F 1 "49.9" V 1350 7150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7150 30  0001 C CNN
F 3 "" H 1350 7150 30  0000 C CNN
	1    1350 7150
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7150 1700 7150
Wire Wire Line
	1100 7150 1200 7150
$Comp
L R R49
U 1 1 56AD2760
P 1350 7250
F 0 "R49" V 1300 7450 50  0000 C CNN
F 1 "49.9" V 1350 7250 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7250 30  0001 C CNN
F 3 "" H 1350 7250 30  0000 C CNN
	1    1350 7250
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7250 1700 7250
Wire Wire Line
	1100 7250 1200 7250
Connection ~ 1100 7150
Connection ~ 1100 7050
$Comp
L R R105
U 1 1 56AD2CFC
P 3100 8750
F 0 "R105" V 3050 8950 50  0000 C CNN
F 1 "49.9" V 3100 8750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8750 30  0001 C CNN
F 3 "" H 3100 8750 30  0000 C CNN
	1    3100 8750
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8750 3450 8750
Wire Wire Line
	2850 8750 2950 8750
$Comp
L R R106
U 1 1 56AD2D04
P 3100 8850
F 0 "R106" V 3050 9050 50  0000 C CNN
F 1 "49.9" V 3100 8850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8850 30  0001 C CNN
F 3 "" H 3100 8850 30  0000 C CNN
	1    3100 8850
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8850 3450 8850
Connection ~ 2850 8750
$Comp
L R R101
U 1 1 56AD2EEB
P 3100 8350
F 0 "R101" V 3050 8550 50  0000 C CNN
F 1 "49.9" V 3100 8350 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8350 30  0001 C CNN
F 3 "" H 3100 8350 30  0000 C CNN
	1    3100 8350
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8350 3450 8350
Wire Wire Line
	2850 8350 2950 8350
$Comp
L R R102
U 1 1 56AD2EF3
P 3100 8450
F 0 "R102" V 3050 8650 50  0000 C CNN
F 1 "49.9" V 3100 8450 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8450 30  0001 C CNN
F 3 "" H 3100 8450 30  0000 C CNN
	1    3100 8450
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8450 3450 8450
Wire Wire Line
	2850 8450 2950 8450
Connection ~ 2850 8350
$Comp
L R R103
U 1 1 56AD2EFC
P 3100 8550
F 0 "R103" V 3050 8750 50  0000 C CNN
F 1 "49.9" V 3100 8550 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8550 30  0001 C CNN
F 3 "" H 3100 8550 30  0000 C CNN
	1    3100 8550
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8550 3450 8550
Wire Wire Line
	2850 8550 2950 8550
$Comp
L R R104
U 1 1 56AD2F04
P 3100 8650
F 0 "R104" V 3050 8850 50  0000 C CNN
F 1 "49.9" V 3100 8650 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8650 30  0001 C CNN
F 3 "" H 3100 8650 30  0000 C CNN
	1    3100 8650
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8650 3450 8650
Wire Wire Line
	2850 8650 2950 8650
Connection ~ 2850 8550
Connection ~ 2850 8450
Connection ~ 2850 8650
$Comp
L R R54
U 1 1 56AD34AF
P 1350 7750
F 0 "R54" V 1300 7950 50  0000 C CNN
F 1 "49.9" V 1350 7750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7750 30  0001 C CNN
F 3 "" H 1350 7750 30  0000 C CNN
	1    1350 7750
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7750 1700 7750
Wire Wire Line
	1100 7750 1200 7750
$Comp
L R R55
U 1 1 56AD34B7
P 1350 7850
F 0 "R55" V 1300 8050 50  0000 C CNN
F 1 "49.9" V 1350 7850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7850 30  0001 C CNN
F 3 "" H 1350 7850 30  0000 C CNN
	1    1350 7850
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7850 1700 7850
Wire Wire Line
	1100 7850 1200 7850
Connection ~ 1100 7750
$Comp
L R R56
U 1 1 56AD34C0
P 1350 7950
F 0 "R56" V 1300 8150 50  0000 C CNN
F 1 "49.9" V 1350 7950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7950 30  0001 C CNN
F 3 "" H 1350 7950 30  0000 C CNN
	1    1350 7950
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7950 1700 7950
Wire Wire Line
	1100 7950 1200 7950
$Comp
L R R57
U 1 1 56AD34C8
P 1350 8050
F 0 "R57" V 1300 8250 50  0000 C CNN
F 1 "49.9" V 1350 8050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8050 30  0001 C CNN
F 3 "" H 1350 8050 30  0000 C CNN
	1    1350 8050
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8050 1700 8050
Wire Wire Line
	1100 8050 1200 8050
Connection ~ 1100 7950
Connection ~ 1100 7850
$Comp
L R R50
U 1 1 56AD34D2
P 1350 7350
F 0 "R50" V 1300 7550 50  0000 C CNN
F 1 "49.9" V 1350 7350 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7350 30  0001 C CNN
F 3 "" H 1350 7350 30  0000 C CNN
	1    1350 7350
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7350 1700 7350
Wire Wire Line
	1100 7350 1200 7350
$Comp
L R R51
U 1 1 56AD34DA
P 1350 7450
F 0 "R51" V 1300 7650 50  0000 C CNN
F 1 "49.9" V 1350 7450 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7450 30  0001 C CNN
F 3 "" H 1350 7450 30  0000 C CNN
	1    1350 7450
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7450 1700 7450
Wire Wire Line
	1100 7450 1200 7450
Connection ~ 1100 7350
$Comp
L R R52
U 1 1 56AD34E3
P 1350 7550
F 0 "R52" V 1300 7750 50  0000 C CNN
F 1 "49.9" V 1350 7550 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7550 30  0001 C CNN
F 3 "" H 1350 7550 30  0000 C CNN
	1    1350 7550
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7550 1700 7550
Wire Wire Line
	1100 7550 1200 7550
$Comp
L R R53
U 1 1 56AD34EB
P 1350 7650
F 0 "R53" V 1300 7850 50  0000 C CNN
F 1 "49.9" V 1350 7650 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 7650 30  0001 C CNN
F 3 "" H 1350 7650 30  0000 C CNN
	1    1350 7650
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 7650 1700 7650
Wire Wire Line
	1100 7650 1200 7650
Connection ~ 1100 7550
Connection ~ 1100 7450
Connection ~ 1100 7650
Connection ~ 1100 7250
$Comp
L R R62
U 1 1 56AD4590
P 1350 8550
F 0 "R62" V 1300 8750 50  0000 C CNN
F 1 "49.9" V 1350 8550 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8550 30  0001 C CNN
F 3 "" H 1350 8550 30  0000 C CNN
	1    1350 8550
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8550 1700 8550
Wire Wire Line
	1100 8550 1200 8550
$Comp
L R R63
U 1 1 56AD4598
P 1350 8650
F 0 "R63" V 1300 8850 50  0000 C CNN
F 1 "49.9" V 1350 8650 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8650 30  0001 C CNN
F 3 "" H 1350 8650 30  0000 C CNN
	1    1350 8650
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8650 1700 8650
Wire Wire Line
	1100 8650 1200 8650
Connection ~ 1100 8550
$Comp
L R R64
U 1 1 56AD45A1
P 1350 8750
F 0 "R64" V 1300 8950 50  0000 C CNN
F 1 "49.9" V 1350 8750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8750 30  0001 C CNN
F 3 "" H 1350 8750 30  0000 C CNN
	1    1350 8750
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8750 1700 8750
Wire Wire Line
	1100 8750 1200 8750
$Comp
L R R65
U 1 1 56AD45A9
P 1350 8850
F 0 "R65" V 1300 9050 50  0000 C CNN
F 1 "49.9" V 1350 8850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8850 30  0001 C CNN
F 3 "" H 1350 8850 30  0000 C CNN
	1    1350 8850
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8850 1700 8850
Wire Wire Line
	1100 8850 1200 8850
Connection ~ 1100 8750
Connection ~ 1100 8650
$Comp
L R R58
U 1 1 56AD45B3
P 1350 8150
F 0 "R58" V 1300 8350 50  0000 C CNN
F 1 "49.9" V 1350 8150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8150 30  0001 C CNN
F 3 "" H 1350 8150 30  0000 C CNN
	1    1350 8150
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8150 1700 8150
Wire Wire Line
	1100 8150 1200 8150
$Comp
L R R59
U 1 1 56AD45BB
P 1350 8250
F 0 "R59" V 1300 8450 50  0000 C CNN
F 1 "49.9" V 1350 8250 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8250 30  0001 C CNN
F 3 "" H 1350 8250 30  0000 C CNN
	1    1350 8250
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8250 1700 8250
Wire Wire Line
	1100 8250 1200 8250
Connection ~ 1100 8150
$Comp
L R R60
U 1 1 56AD45C4
P 1350 8350
F 0 "R60" V 1300 8550 50  0000 C CNN
F 1 "49.9" V 1350 8350 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8350 30  0001 C CNN
F 3 "" H 1350 8350 30  0000 C CNN
	1    1350 8350
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8350 1700 8350
Wire Wire Line
	1100 8350 1200 8350
$Comp
L R R61
U 1 1 56AD45CC
P 1350 8450
F 0 "R61" V 1300 8650 50  0000 C CNN
F 1 "49.9" V 1350 8450 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8450 30  0001 C CNN
F 3 "" H 1350 8450 30  0000 C CNN
	1    1350 8450
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8450 1700 8450
Wire Wire Line
	1100 8450 1200 8450
Connection ~ 1100 8350
Connection ~ 1100 8250
Connection ~ 1100 8450
Connection ~ 1100 8050
$Comp
L R R70
U 1 1 56AD5914
P 1350 9350
F 0 "R70" V 1300 9550 50  0000 C CNN
F 1 "49.9" V 1350 9350 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9350 30  0001 C CNN
F 3 "" H 1350 9350 30  0000 C CNN
	1    1350 9350
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9350 1700 9350
Wire Wire Line
	1100 9350 1200 9350
$Comp
L R R71
U 1 1 56AD591C
P 1350 9450
F 0 "R71" V 1300 9650 50  0000 C CNN
F 1 "49.9" V 1350 9450 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9450 30  0001 C CNN
F 3 "" H 1350 9450 30  0000 C CNN
	1    1350 9450
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9450 1700 9450
Wire Wire Line
	1100 9450 1200 9450
Connection ~ 1100 9350
$Comp
L R R72
U 1 1 56AD5925
P 1350 9550
F 0 "R72" V 1300 9750 50  0000 C CNN
F 1 "49.9" V 1350 9550 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9550 30  0001 C CNN
F 3 "" H 1350 9550 30  0000 C CNN
	1    1350 9550
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9550 1700 9550
Wire Wire Line
	1100 9550 1200 9550
$Comp
L R R73
U 1 1 56AD592D
P 1350 9650
F 0 "R73" V 1300 9850 50  0000 C CNN
F 1 "49.9" V 1350 9650 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9650 30  0001 C CNN
F 3 "" H 1350 9650 30  0000 C CNN
	1    1350 9650
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9650 1700 9650
Wire Wire Line
	1100 9650 1200 9650
Connection ~ 1100 9550
Connection ~ 1100 9450
$Comp
L R R66
U 1 1 56AD5937
P 1350 8950
F 0 "R66" V 1300 9150 50  0000 C CNN
F 1 "49.9" V 1350 8950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 8950 30  0001 C CNN
F 3 "" H 1350 8950 30  0000 C CNN
	1    1350 8950
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 8950 1700 8950
Wire Wire Line
	1100 8950 1200 8950
$Comp
L R R67
U 1 1 56AD593F
P 1350 9050
F 0 "R67" V 1300 9250 50  0000 C CNN
F 1 "49.9" V 1350 9050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9050 30  0001 C CNN
F 3 "" H 1350 9050 30  0000 C CNN
	1    1350 9050
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9050 1700 9050
Wire Wire Line
	1100 9050 1200 9050
Connection ~ 1100 8950
$Comp
L R R68
U 1 1 56AD5948
P 1350 9150
F 0 "R68" V 1300 9350 50  0000 C CNN
F 1 "49.9" V 1350 9150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9150 30  0001 C CNN
F 3 "" H 1350 9150 30  0000 C CNN
	1    1350 9150
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9150 1700 9150
Wire Wire Line
	1100 9150 1200 9150
$Comp
L R R69
U 1 1 56AD5950
P 1350 9250
F 0 "R69" V 1300 9450 50  0000 C CNN
F 1 "49.9" V 1350 9250 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9250 30  0001 C CNN
F 3 "" H 1350 9250 30  0000 C CNN
	1    1350 9250
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9250 1700 9250
Wire Wire Line
	1100 9250 1200 9250
Connection ~ 1100 9150
Connection ~ 1100 9050
Connection ~ 1100 9250
Connection ~ 1100 8850
$Comp
L R R78
U 1 1 56AD68A8
P 1350 10150
F 0 "R78" V 1300 10350 50  0000 C CNN
F 1 "49.9" V 1350 10150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10150 30  0001 C CNN
F 3 "" H 1350 10150 30  0000 C CNN
	1    1350 10150
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10150 1700 10150
Wire Wire Line
	1100 10150 1200 10150
$Comp
L R R79
U 1 1 56AD68B0
P 1350 10250
F 0 "R79" V 1300 10450 50  0000 C CNN
F 1 "49.9" V 1350 10250 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10250 30  0001 C CNN
F 3 "" H 1350 10250 30  0000 C CNN
	1    1350 10250
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10250 1700 10250
Wire Wire Line
	1100 10250 1200 10250
Connection ~ 1100 10150
$Comp
L R R80
U 1 1 56AD68B9
P 1350 10350
F 0 "R80" V 1300 10550 50  0000 C CNN
F 1 "49.9" V 1350 10350 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10350 30  0001 C CNN
F 3 "" H 1350 10350 30  0000 C CNN
	1    1350 10350
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10350 1700 10350
Wire Wire Line
	1100 10350 1200 10350
$Comp
L R R81
U 1 1 56AD68C1
P 1350 10450
F 0 "R81" V 1300 10650 50  0000 C CNN
F 1 "49.9" V 1350 10450 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10450 30  0001 C CNN
F 3 "" H 1350 10450 30  0000 C CNN
	1    1350 10450
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10450 1700 10450
Wire Wire Line
	1100 10450 1200 10450
Connection ~ 1100 10350
Connection ~ 1100 10250
$Comp
L R R74
U 1 1 56AD68CB
P 1350 9750
F 0 "R74" V 1300 9950 50  0000 C CNN
F 1 "49.9" V 1350 9750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9750 30  0001 C CNN
F 3 "" H 1350 9750 30  0000 C CNN
	1    1350 9750
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9750 1700 9750
Wire Wire Line
	1100 9750 1200 9750
$Comp
L R R75
U 1 1 56AD68D3
P 1350 9850
F 0 "R75" V 1300 10050 50  0000 C CNN
F 1 "49.9" V 1350 9850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9850 30  0001 C CNN
F 3 "" H 1350 9850 30  0000 C CNN
	1    1350 9850
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9850 1700 9850
Wire Wire Line
	1100 9850 1200 9850
Connection ~ 1100 9750
$Comp
L R R76
U 1 1 56AD68DC
P 1350 9950
F 0 "R76" V 1300 10150 50  0000 C CNN
F 1 "49.9" V 1350 9950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 9950 30  0001 C CNN
F 3 "" H 1350 9950 30  0000 C CNN
	1    1350 9950
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 9950 1700 9950
Wire Wire Line
	1100 9950 1200 9950
$Comp
L R R77
U 1 1 56AD68E4
P 1350 10050
F 0 "R77" V 1300 10250 50  0000 C CNN
F 1 "49.9" V 1350 10050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10050 30  0001 C CNN
F 3 "" H 1350 10050 30  0000 C CNN
	1    1350 10050
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10050 1700 10050
Wire Wire Line
	1100 10050 1200 10050
Connection ~ 1100 9950
Connection ~ 1100 9850
Connection ~ 1100 10050
Connection ~ 1100 9650
$Comp
L R R82
U 1 1 56AD7764
P 1350 10550
F 0 "R82" V 1300 10750 50  0000 C CNN
F 1 "49.9" V 1350 10550 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10550 30  0001 C CNN
F 3 "" H 1350 10550 30  0000 C CNN
	1    1350 10550
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10550 1700 10550
Wire Wire Line
	1100 10550 1200 10550
$Comp
L R R83
U 1 1 56AD776C
P 1350 10650
F 0 "R83" V 1300 10850 50  0000 C CNN
F 1 "49.9" V 1350 10650 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10650 30  0001 C CNN
F 3 "" H 1350 10650 30  0000 C CNN
	1    1350 10650
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10650 1700 10650
Wire Wire Line
	1100 10650 1200 10650
$Comp
L R R84
U 1 1 56AD7774
P 1350 10750
F 0 "R84" V 1300 10950 50  0000 C CNN
F 1 "49.9" V 1350 10750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 1280 10750 30  0001 C CNN
F 3 "" H 1350 10750 30  0000 C CNN
	1    1350 10750
	0    1    1    0   
$EndComp
Wire Wire Line
	1500 10750 1700 10750
Wire Wire Line
	1100 10750 1200 10750
Connection ~ 1100 10650
Connection ~ 1100 10550
Connection ~ 1100 10450
Text Label 2750 6750 2    60   ~ 0
RAM_VTT
Wire Wire Line
	2850 6750 2850 9150
$Comp
L R R89
U 1 1 56AD876E
P 3100 7150
F 0 "R89" V 3050 7350 50  0000 C CNN
F 1 "49.9" V 3100 7150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7150 30  0001 C CNN
F 3 "" H 3100 7150 30  0000 C CNN
	1    3100 7150
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7150 3450 7150
Wire Wire Line
	2850 7150 2950 7150
$Comp
L R R90
U 1 1 56AD8776
P 3100 7250
F 0 "R90" V 3050 7450 50  0000 C CNN
F 1 "49.9" V 3100 7250 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7250 30  0001 C CNN
F 3 "" H 3100 7250 30  0000 C CNN
	1    3100 7250
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7250 3450 7250
Wire Wire Line
	2850 7250 2950 7250
Connection ~ 2850 7150
$Comp
L R R91
U 1 1 56AD877F
P 3100 7350
F 0 "R91" V 3050 7550 50  0000 C CNN
F 1 "49.9" V 3100 7350 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7350 30  0001 C CNN
F 3 "" H 3100 7350 30  0000 C CNN
	1    3100 7350
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7350 3450 7350
Wire Wire Line
	2850 7350 2950 7350
$Comp
L R R92
U 1 1 56AD8787
P 3100 7450
F 0 "R92" V 3050 7650 50  0000 C CNN
F 1 "49.9" V 3100 7450 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7450 30  0001 C CNN
F 3 "" H 3100 7450 30  0000 C CNN
	1    3100 7450
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7450 3450 7450
Wire Wire Line
	2850 7450 2950 7450
Connection ~ 2850 7350
Connection ~ 2850 7250
$Comp
L R R86
U 1 1 56AD8799
P 3100 6850
F 0 "R86" V 3050 7050 50  0000 C CNN
F 1 "49.9" V 3100 6850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 6850 30  0001 C CNN
F 3 "" H 3100 6850 30  0000 C CNN
	1    3100 6850
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 6850 3450 6850
Wire Wire Line
	2850 6850 2950 6850
Connection ~ 2850 6750
$Comp
L R R87
U 1 1 56AD87A2
P 3100 6950
F 0 "R87" V 3050 7150 50  0000 C CNN
F 1 "49.9" V 3100 6950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 6950 30  0001 C CNN
F 3 "" H 3100 6950 30  0000 C CNN
	1    3100 6950
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 6950 3450 6950
Wire Wire Line
	2850 6950 2950 6950
$Comp
L R R88
U 1 1 56AD87AA
P 3100 7050
F 0 "R88" V 3050 7250 50  0000 C CNN
F 1 "49.9" V 3100 7050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7050 30  0001 C CNN
F 3 "" H 3100 7050 30  0000 C CNN
	1    3100 7050
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7050 3450 7050
Wire Wire Line
	2850 7050 2950 7050
Connection ~ 2850 6950
Connection ~ 2850 6850
Connection ~ 2850 7050
$Comp
L R R97
U 1 1 56AD9D8D
P 3100 7950
F 0 "R97" V 3050 8150 50  0000 C CNN
F 1 "49.9" V 3100 7950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7950 30  0001 C CNN
F 3 "" H 3100 7950 30  0000 C CNN
	1    3100 7950
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7950 3450 7950
Wire Wire Line
	2850 7950 2950 7950
$Comp
L R R98
U 1 1 56AD9D95
P 3100 8050
F 0 "R98" V 3050 8250 50  0000 C CNN
F 1 "49.9" V 3100 8050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8050 30  0001 C CNN
F 3 "" H 3100 8050 30  0000 C CNN
	1    3100 8050
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8050 3450 8050
Wire Wire Line
	2850 8050 2950 8050
Connection ~ 2850 7950
$Comp
L R R99
U 1 1 56AD9D9E
P 3100 8150
F 0 "R99" V 3050 8350 50  0000 C CNN
F 1 "49.9" V 3100 8150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8150 30  0001 C CNN
F 3 "" H 3100 8150 30  0000 C CNN
	1    3100 8150
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8150 3450 8150
Wire Wire Line
	2850 8150 2950 8150
$Comp
L R R100
U 1 1 56AD9DA6
P 3100 8250
F 0 "R100" V 3050 8450 50  0000 C CNN
F 1 "49.9" V 3100 8250 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8250 30  0001 C CNN
F 3 "" H 3100 8250 30  0000 C CNN
	1    3100 8250
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8250 3450 8250
Wire Wire Line
	2850 8250 2950 8250
Connection ~ 2850 8150
Connection ~ 2850 8050
$Comp
L R R93
U 1 1 56AD9DB0
P 3100 7550
F 0 "R93" V 3050 7750 50  0000 C CNN
F 1 "49.9" V 3100 7550 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7550 30  0001 C CNN
F 3 "" H 3100 7550 30  0000 C CNN
	1    3100 7550
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7550 3450 7550
Wire Wire Line
	2850 7550 2950 7550
$Comp
L R R94
U 1 1 56AD9DB8
P 3100 7650
F 0 "R94" V 3050 7850 50  0000 C CNN
F 1 "49.9" V 3100 7650 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7650 30  0001 C CNN
F 3 "" H 3100 7650 30  0000 C CNN
	1    3100 7650
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7650 3450 7650
Wire Wire Line
	2850 7650 2950 7650
Connection ~ 2850 7550
$Comp
L R R95
U 1 1 56AD9DC1
P 3100 7750
F 0 "R95" V 3050 7950 50  0000 C CNN
F 1 "49.9" V 3100 7750 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7750 30  0001 C CNN
F 3 "" H 3100 7750 30  0000 C CNN
	1    3100 7750
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7750 3450 7750
Wire Wire Line
	2850 7750 2950 7750
$Comp
L R R96
U 1 1 56AD9DC9
P 3100 7850
F 0 "R96" V 3050 8050 50  0000 C CNN
F 1 "49.9" V 3100 7850 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 7850 30  0001 C CNN
F 3 "" H 3100 7850 30  0000 C CNN
	1    3100 7850
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 7850 3450 7850
Wire Wire Line
	2850 7850 2950 7850
Connection ~ 2850 7750
Connection ~ 2850 7650
Connection ~ 2850 7850
Connection ~ 2850 7450
Wire Wire Line
	2850 8850 2950 8850
Connection ~ 2850 8250
Text Notes 1550 1150 0    60   ~ 0
VCCO = 1V5
Text Notes 3700 1150 0    60   ~ 0
VCCO = 1V5
Text Notes 6050 1150 0    60   ~ 0
VCCO = 1V5
Text HLabel 13700 1800 0    60   Input ~ 0
RAM_TDI
Text HLabel 12900 1900 0    60   Output ~ 0
RAM_TDO
Text HLabel 13700 2000 0    60   Input ~ 0
RAM_TMS
Text HLabel 13700 2100 0    60   Input ~ 0
RAM_TCK
Text Label 11300 1400 2    60   ~ 0
RAM_A18
Wire Wire Line
	11300 1400 11450 1400
Text Label 11300 1300 2    60   ~ 0
RAM_A19
Text Label 11300 1200 2    60   ~ 0
RAM_A20
Wire Wire Line
	11300 1200 11450 1200
Wire Wire Line
	11450 1300 11300 1300
Text Label 1200 2700 2    60   ~ 0
RAM_A18
Text Label 1200 3200 2    60   ~ 0
RAM_A19
Text Label 1200 2500 2    60   ~ 0
RAM_A20
Wire Wire Line
	1350 2500 1200 2500
Wire Wire Line
	1200 3100 1350 3100
Wire Wire Line
	1350 2800 1200 2800
Text Label 3450 8950 0    60   ~ 0
RAM_A18
Text Label 3450 9050 0    60   ~ 0
RAM_A19
Text Label 3450 9150 0    60   ~ 0
RAM_A20
$Comp
L R R227
U 1 1 56BE2481
P 3100 8950
F 0 "R227" V 3050 9150 50  0000 C CNN
F 1 "49.9" V 3100 8950 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 8950 30  0001 C CNN
F 3 "" H 3100 8950 30  0000 C CNN
	1    3100 8950
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 8950 3450 8950
$Comp
L R R228
U 1 1 56BE2488
P 3100 9050
F 0 "R228" V 3050 9250 50  0000 C CNN
F 1 "49.9" V 3100 9050 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 9050 30  0001 C CNN
F 3 "" H 3100 9050 30  0000 C CNN
	1    3100 9050
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 9050 3450 9050
$Comp
L R R229
U 1 1 56BE248F
P 3100 9150
F 0 "R229" V 3050 9350 50  0000 C CNN
F 1 "49.9" V 3100 9150 50  0000 C CNN
F 2 "azonenberg_pcb:EIA_0402_RES_NOSILK" V 3030 9150 30  0001 C CNN
F 3 "" H 3100 9150 30  0000 C CNN
	1    3100 9150
	0    1    1    0   
$EndComp
Wire Wire Line
	3250 9150 3450 9150
Wire Wire Line
	2850 8950 2950 8950
Connection ~ 2850 8850
Wire Wire Line
	2850 9050 2950 9050
Connection ~ 2850 8950
Wire Wire Line
	2850 9150 2950 9150
Connection ~ 2850 9050
Wire Wire Line
	1200 1900 1350 1900
$Comp
L XC7A200T-xFFG1156x U5
U 5 1 56982E3F
P 1550 6150
F 0 "U5" H 1550 6100 60  0000 L CNN
F 1 "XC7A200T-1FFG1156C" H 1550 6000 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_1156_35x35_FULLARRAY_1MM" H 1550 6200 60  0001 C CNN
F 3 "" H 1550 6200 60  0000 C CNN
	5    1550 6150
	1    0    0    -1  
$EndComp
NoConn ~ 1350 6100
NoConn ~ 1350 6000
NoConn ~ 1350 5900
NoConn ~ 1350 5800
NoConn ~ 1350 5700
NoConn ~ 1350 5600
NoConn ~ 1350 5500
NoConn ~ 1350 5400
NoConn ~ 1350 5300
NoConn ~ 1350 5200
NoConn ~ 1350 5100
Text Label 1200 2600 2    60   ~ 0
RAM_A4
NoConn ~ 1350 4800
NoConn ~ 1350 4900
NoConn ~ 1350 3800
NoConn ~ 1350 4300
NoConn ~ 1350 4700
NoConn ~ 1350 4500
NoConn ~ 1350 3700
$Comp
L XC7A200T-xFFG1156x U5
U 7 1 56983070
P 6050 6150
F 0 "U5" H 6050 6100 60  0000 L CNN
F 1 "XC7A200T-1FFG1156C" H 6050 6000 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_1156_35x35_FULLARRAY_1MM" H 6050 6200 60  0001 C CNN
F 3 "" H 6050 6200 60  0000 C CNN
	7    6050 6150
	1    0    0    -1  
$EndComp
NoConn ~ 1350 3900
NoConn ~ 1350 4400
NoConn ~ 1350 2900
NoConn ~ 1350 4100
NoConn ~ 1350 4200
$Comp
L QDRII+_SRAM_36BIT U2
U 4 1 56C5208A
P 14200 5400
F 0 "U2" H 14200 5300 60  0000 L CNN
F 1 "CY7C1145KV18-400BZXC" H 14200 5200 60  0000 L CNN
F 2 "azonenberg_pcb:BGA_165_11x15_FULLARRAY_1MM" H 14200 5400 60  0001 C CNN
F 3 "" H 14200 5400 60  0000 C CNN
	4    14200 5400
	1    0    0    -1  
$EndComp
NoConn ~ 1350 4600
NoConn ~ 5850 2000
NoConn ~ 5850 6100
NoConn ~ 5850 2600
NoConn ~ 1350 4000
Text Label 13800 1500 2    60   ~ 0
1V5
Wire Wire Line
	2850 6750 2750 6750
$Comp
L C C456
U 1 1 56C75134
P 10400 7400
F 0 "C456" H 10425 7500 50  0000 L CNN
F 1 "0.47 uF" H 10425 7300 50  0000 L CNN
F 2 "azonenberg_pcb:EIA_0402_CAP_NOSILK" H 10438 7250 30  0001 C CNN
F 3 "" H 10400 7400 60  0000 C CNN
	1    10400 7400
	1    0    0    -1  
$EndComp
Connection ~ 10050 7250
Connection ~ 10050 7550
NoConn ~ 3500 1600
Wire Wire Line
	3500 3900 3350 3900
NoConn ~ 3500 2000
$EndSCHEMATC
