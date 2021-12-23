import machine
import time
from machine import Pin

i2c = machine.SoftI2C(scl = machine.Pin(22), sda = machine.Pin(21), freq=400000, timeout=255)

devadr = 54

def set_current_address(smb,addr):
	smb.writeto_mem(devadr,addr,addrsize=16)

def read_byte(smb,addr):
	set_current_address(smb,addr)
	return bin(smb.readfrom(devadr,1))

def reset(smb):
	write_block(smb, 0x3008, [0x82])
	time.sleep(0.005)
	check_ready(smb)

def check_ready(smb):
	# wait until acknowledged
	ready=0
	while not ready:
		try:
			smb.readfrom(devadr,1)
			ready=1
		except OSError:
			print('not ready')
			ready=0

def write_block(smb,addr,data):
	smb.writeto_mem(devadr,addr,bytearray(data),addrsize=16)
	time.sleep(0.001)
	# wait until acknowledged
	check_ready(smb)

def cam_init():
	# Uncoment to scan bus
	# print(i2c.scan())
	framelength = 666
	linelength = 3448
	# Read sensor ID
	data = i2c.readfrom_mem(devadr, 0x300A, 3, addrsize=16)
	print("OV5647 should return ID: 0x56 0x47 0x6C")
	print("Camera returned ID: ","".join("0x%02x " % i for i in data))
	data = i2c.readfrom_mem(54, 0x0100, 1, addrsize=16)
	print("Mode - 0: SW- Standby")
	print("     - 1: Streaming")
	print("Current mode: ", data)
	# Send camera init bytes

	init = [
 	(0x0100, 0x00), # Power off
	(0x0103, 0x01), # RESET
	(0x3034, 0x08), # SC_CMMN_PLL_ 0x1A  0x08 - 10 bit mode
					# Bit[6:4]: pll_charge_pump
				    # Bit[3:0]: mipi_bit_mode
				    #  0000: 8 bit mode
				    #  0001: 10 bit mode
				    #  Others: Reserved to future use
	(0x3035, 0x41), # DEBUG MODE   0x21  0x41
					# Bit[7:4]: system_clk_div
					# Will slow down all clocks
					# Bit[3:0]: scale_divider_mipi
					# MIPI PCLK/SERCLK can be slowed down when image is scaled down	
	(0x3036, 0x46), # SC_CMMN_PLL_MULTIPLIER 0x69 0x46
	                # Bit[7:0]: PLL_multiplier (4~252) can be any integer during 4~127 
	                # and only even integer during 128~252
	(0x303C, 0x11), # SC_CMMN_PLLS_CTRL2 0x11
					# Bit[6:4]: plls_cp
				    # Bit[3:0]: plls_sys_div
	(0x3106, 0xF5), # SRB CTRL 0xF5
					# Bit[3:2]: PLL clock divider
					#  00: pll_sclk
					#  01: pll_sclk/2
					#  10: pll_sclk/4
					#  11: pll_sclk
					# Bit[1]: rst_arb
					#  1: Reset arbiter
					# Bit[0]: sclk_arb
					#  1: Enable SCLK to arbiter
	(0x3821,0x07),    #{1'b0, 16'h3821, 8'h07}, // Timing TC: r_mirror_isp, r_mirror_snr, r_hbin
	(0x3820,0x41),    #{1'b0, 16'h3820, 8'h41}, // Timing TC: r_vbin, 1 unknown setting
	(0x3827, 0xEC), # Debug mode 0xEC
	(0x370C, 0x0F), # ?
	(0x3612, 0x59), # ?
	(0x3618, 0x00), # ?
	# ISP TOP control registers
	(0x5000, 0x06), # ISP CTRL00
					# Bit[7]: lenc_en
					#  0: Disable
					#  1: Enable
					# Bit[6:3]: Not used
					# Bit[2]: bc_en
					#  0: Disable
					#  1: Enable
					# Bit[1]: wc_en
					#  0: Disable
					#  1: Enable
					#  Bit[0]: Not used
	(0x5002, 0x41), # ISP CTRL02
					# Bit[6]: win_en
					#  0: Disable
					#  1: Enable
					# Bit[1]: otp_en
					#  0: Disable
					#  1: Enable
					# Bit[0]: awb_gain_en
					#  0: Disable
					#  1: Enable
	(0x5003, 0x08), # ISP CTRL03
					# Bit[3]: buf_en
					#  0: Disable
					#  1: Enable
					# Bit[2]: bin_man_set
					#  0: Manual value as 0
					#  1: Manual value as 1
					# Bit[1]: bin_auto_en
					#  0: Disable
					#  1: Enable
					# Bit[0]: Not used
	# AEC/AGC 3 registers
	(0x5A00, 0x08), # DIGC CTRL0
					# Bit[2]: dig_comp_bypass
					# Bit[1]: man_opt
					# Bit[0]: man_en
	# System control registers
	(0x3000, 0x00), # SC_CMMN_PAD_OEN0 - io_y_oen[11:8]
	(0x3001, 0x00), # SC_CMMN_PAD_OEN1 - io_y_oen[7:0]
	(0x3002, 0x00), # SC_CMMN_PAD_OEN2
					# Bit[7]: io_vsync_oen
					# Bit[6]: io_href_oen
					# Bit[5]: io_pclk_oen
					# Bit[4]: io_frex_oen
					# Bit[3]: io_strobe_oen
					# Bit[2]: io_sda_oen
					# Bit[1]: io_gpio1_oen
					# Bit[0]: io_gpio0_oen
	(0x3016, 0x08), # SC_CMMN_MIPI_PHY
					# Bit[7:6]: LPH
					# Bit[3]: mipi_pad_enable
					# Bit[2]: pgm_bp_hs_en_lat btpass the latch of hs_enable
					# Bit[1:0]: ictl[1:0] Bias current adjustment
	(0x3017, 0xE0), # SC_CMMN_MIPI_PHY 0xE0
					# Bit[7:6]: pgm_vcm[1:0] High speed common mode voltage
					# Bit[5:4]: pgm_lptx[1:0] 01: Driving strength of low speed transmitter
					# Bit[3]: IHALF Bias current reduction
					# Bit[2]: pgm_vicd CD input low voltage
					# Bit[1]: pgm_vih CD input high voltage-dummy
					# Bit[0]: pgm_hs_valid Valid delay-dummy

	(0x3018, 0x44), # SC_CMMN_MIPI_SC_CTRL 01000100
					# Bit[7:5]: mipi_lane_mode
					#  0: One lane mode
					#  1: Two lane mode
					# Bit[4]: r_phy_pd_mipi
					#  1: Power donw PHY HS TX
					# Bit[3]: r_phy_pd_lprx
					#  1: Power down PHY LP RX module
					# Bit[2]: mipi_en
					#  0: DVP enable
					#  1: MIPI enable
					# Bit[1]: mipi_susp_reg MIPI system Suspend register
					#  1: suspend
					# Bit[0]: lane_dis_op
					#  0: Use mipi_release1/2 and lane_disable1/2 to disable two data lane
					#  1: Use lane_disable1/2 to disable two data lane
	(0x301C, 0xF8), # ?
	(0x301D, 0xF0), # ?
	# AEC/AGC 2 registers
	(0x3A18, 0x00), # AEC GAIN CEILING   Bit[1:0]: gain_ceiling[9:8]
	(0x3A19, 0xF8), # AEC GAIN CEILING - gain_ceiling[7:0]
	(0x3C01, 0x80), # 50/60 HZ DETECTION CTRL01
					# Bit[7]: band_man_en Band detection manual mode
					#  0: Manual mode disable
					#  1: Manual mode enable
					# Bit[6:0]: 50/60 Hz detection control Contact local OmniVision FAE for the correct settings
	# FREX strobe control functions
	(0x3B07, 0x0C),  # STROBE_FREX_MODE_SEL
					 # Bit[3]: fx1_fm_en
					 # Bit[2]: frex_inv
					 # Bit[1:0]: FREX mode select
					 #  00: frex_strobe mode0
					 #  01: frex_strobe mode1
					 #  1x: Rolling strobe
	# Timing control registers
	(0x380C, 0x07), # TIMING_HTS Bit[4:0]: Total horizontal size[12:8]
	(0x380D, 0x68), #            Bit[7:0]: Total horizontal size[7:0]
	(0x380E, 0x03),
	(0x380F, 0xD8),
	(0x3814, 0x31), # TIMING_X_INC Bit[7:4]: h_odd_inc Horizontal subsample odd increase number
                                 # Bit[3:0]: h_even_inc Horizontal subsample even increasenumber
	(0x3815, 0x31), # TIMING_Y_INC Bit[7:4]: v_odd_inc Vertical subsample odd increase number
                                 # Bit[3:0]: v_even_inc Vertical subsample even increase number
	(0x3708, 0x64), # ?
	(0x3709, 0x52), # ?
	# System timing registers
	(0x3808, 0x02), # TIMING_X_OUTPUT_SIZE Bit[7:4]: Debug mode
                                         # Bit[3:0]: DVP output horizontal width[11:8]
	(0x3809, 0x80), # TIMING_X_OUTPUT_SIZE Bit[7:0]: DVP output horizontal width[7:0]
	(0x380A, 0x01), # TIMING_Y_OUTPUT_SIZE Bit[7:4]: Debug mode
                                         # Bit[3:0]: DVP output vertical height[11:8]
	(0x380B, 0xE0), # TIMING_Y_OUTPUT_SIZE Bit[7:0]: DVP output vertical height[7:0]
	# Image windowing registers
	(0x3800, 0x00), # TIMING_X_ADDR_START  Bit[3:0]: x_addr_start[11:8] 
	(0x3801, 0x00), # TIMING_X_ADDR_START  Bit[7:0]: x_addr_start[7:0]
	(0x3802, 0x00), # TIMING_Y_ADDR_START  Bit[3:0]: y_addr_start[11:8]
	(0x3803, 0x00), # TIMING_Y_ADDR_START  Bit[7:0]: y_addr_start[7:0]
	(0x3804, 0x0A), # TIMING_X_ADDR_END    Bit[3:0]: x_addr_end[11:8]
	(0x3805, 0x3F), # TIMING_X_ADDR_END    Bit[7:0]: x_addr_end[7:0]
	(0x3806, 0x07), # TIMING_Y_ADDR_END    Bit[3:0]: y_addr_end[11:8]
	(0x3807, 0xA1), # TIMING_Y_ADDR_END    Bit[7:0]: y_addr_end[7:0]
	(0x3811, 0x08), #   {1'b0, 16'h3811, 8'h08}, // ISP horizontal offset = 8
	(0x3813, 0x02), #   {1'b0, 16'h3813, 8'h02}, // ISP vertical offset = 2
	(0x3630, 0x2E), # ?
	(0x3632, 0xE2), # ?
	(0x3633, 0x23), # ?
	(0x3634, 0x44), # ?
	(0x3636, 0x06), # ?
	(0x3620, 0x64), # ?
	(0x3621, 0xE0), # ?
	(0x3600, 0x37), # ?
	(0x3704, 0xA0), # ?
	(0x3703, 0x5A), # ?
	(0x3715, 0x78), # ?
	(0x3717, 0x01), # ?
	(0x3731, 0x02), # ?
	(0x370B, 0x60), # ?
	(0x3705, 0x1A), # ?
	(0x3F05, 0x02), # ?
	(0x3F06, 0x10), # ?
	(0x3F01, 0x0A), # ?
	# AEC/AGC 2 registers
	(0x3A08, 0x01), # B50 STEP   Bit[1:0]: b50_step[9:8]
	(0x3A09, 0x27), # B50 STEP   Bit[7:0]: b50_step[7:0]
	(0x3A0A, 0x00), # B60 STEP   Bit[1:0]: b60_step[9:8]
	(0x3A0B, 0xF6), # B60 STEP   Bit[7:0]: b60_step[7:0] 
	(0x3A0D, 0x04), # B60 MAX    Bit[5:0]: b60_max 
	(0x3A0E, 0x03), # B50 MAX    Bit[5:0]: b50_max
	(0x3A0F, 0x58), # WPT        Bit[7:0]: WPT
	(0x3A10, 0x50), # BPT        Bit[7:0]: BPT
	(0x3A1B, 0x58), # WPT2       Bit[7:0]: wpt2
	(0x3A1E, 0x50), # BPT2       Bit[7:0]: bpt2
	(0x3A11, 0x60), # HIGH VPT   Bit[7:0]: vpt_high
	(0x3A1F, 0x28), # LOW VPT    Bit[7:0]: vpt_low
	# BLC registers
	(0x4001, 0x02), # BLC CTRL01 Bit[5:0]: start_line
	(0x4004, 0x02), # BLC CTRL04 Bit[7:0]: blc_line_num
	(0x4000, 0x09), # BLC CTRL00 BLC Control
                               # (0: disable ISP; 1: enable ISP)
                               # Bit[7]: blc_median_filter_enable
                               # Bit[6:4]: Not used
                               # Bit[3]: adc_11bit_mode
                               # Bit[2]: apply2blackline
                               # Bit[1]: blackline_averageframe
                               # Bit[0]: BLC enable
	(0x4837, 0x24), # PCLK_PERIOD Period of pclk2x, pclk_div = 1, and 1-bit decimal
	(0x4050, 0x6e),
	(0x4051, 0x8F), #

	# MIPI top registers
	(0x4800, 0x04),  # 	              '0x84' -> 10000000
	#(0x4800, 0xD4),
	#(0x4800, 0x34), # MIPI CTRL 00 - '0x34' ->  00110100
	#(0x4800, 0x1C), #                '0x1C' -> 00011100
	#(0x4800, 0x14), #                '0x14' -> 00010100
	#(0x4800, 0x3C), #                '0x1C' -> 00111100
	#(0x4800, 0xB4), #                '0xB4' -> 10110100	
	#(0x4800, 0x94), #                '0x94' -> 10010100	- free running clock - always in high speed
	#(0x4800, 0x80), #                '0x80' -> 10000000
	#(0x4800,0x04),     #   100 reverse bit order
	#(0x4800,0x04),  # 00000100
	                # Was 0x34 - HS LS mode - 0xD4 - HS only mode - F4 - Gate clock lane
					# MIPI Control 00
					#  Bit[7]: mipi_hs_only
					#   0: MIPI can support CD and ESCAPE mode
					#   1: MIPI always in High Speed mode
					#  Bit[6]: ck_mark1_en
					#   1: Enable clock lane mark1 when resume
					#  Bit[5]: Clock lane gate enable
					#  0: Clock lane is free running
					#  1: Gate clock lane when no packet to transmit
					# Bit[4]: Line sync enable
					#  0: Do not send line short packet for each line
					#  1: Send line short packet for each line
					# Bit[3]: Lane select
					#  0: Use lane1 as default data lane
					#  1: Use lane2 as default data lane
					# Bit[2]: Idle status
					#  0: MIPI bus will be LP00 when no packet to transmit
					#  1: MIPI bus will be LP11 when no packet to transmit
					# Bit[1]: Clock lane first bits
					#  0: Output 0x55
					#  1: Output 0xAA
					#  1: Manually set clock lane to low power mode
	#(0x4806,0x2B),  # MIPI REG RW CTRL  0x2B -> 00101011
	                #                           00101000                   
	(0x503D, 0x92), # enable test patern 10010001
	(0x0100, 0x01)  # Wake up from sleep
#   End of OV5647 init
	]

	for s in init:
		print("Writing: ", hex(s[1]), " to: ", hex(s[0]))
		write_block(i2c,s[0],[s[1]])
		data = i2c.readfrom_mem(devadr, s[0], 1, addrsize=16)
		print("Reading: ", hex(s[0]), "Value: ", data)

	data = i2c.readfrom_mem(devadr, 0x0100, 1, addrsize=16)
	print("Mode - 0: SW- Standby")
	print("     - 1: Streaming")
	print("Current mode: ", data)

	print('camera-init done')
