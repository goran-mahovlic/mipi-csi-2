# ******* project, board and chip name *******
PROJECT = CSI
BOARD = ulx3s
# 12 25 45 85
FPGA_SIZE = um-45
FPGA_PACKAGE = CABGA381

# ******* if programming with OpenOCD *******
# using local latest openocd until in linux distribution
#OPENOCD=openocd_ft232r
# default onboard usb-jtag
OPENOCD_INTERFACE=$(SCRIPTS)/ft231x.ocd
# ulx3s-jtag-passthru
#OPENOCD_INTERFACE=$(SCRIPTS)/ft231x2.ocd
# ulx2s
#OPENOCD_INTERFACE=$(SCRIPTS)/ft232r.ocd
# external jtag
#OPENOCD_INTERFACE=$(SCRIPTS)/ft2232.ocd

# ******* design files *******
CONSTRAINTS = ../../constraints/ulx4m-ld_v001.lpf
#TOP_MODULE = top
#TOP_MODULE_FILE = top/$(TOP_MODULE).v
TOP_MODULE = top
TOP_MODULE_FILE = top/$(TOP_MODULE).v

#camera.sv  decoders  d_phy_receiver.sv  Manifest.py
#mistery@DESKTOP-EO12E5I:/mnt/d/FPGA/ulx3s-misc-goran-ulx4m/examples/mipi-csi-2$ ls src/decoders/
#Manifest.py  raw8.sv  rgb565.sv  rgb888.sv  yuv422_8bit.sv

VERILOG_FILES = \
  $(TOP_MODULE_FILE) \
  ../ecp5pll/hdl/sv/ecp5pll.sv \
  src/clock.sv \
  src/i2c_master.sv \
  src/i2c_core.sv \
  src/ov5647.sv \
  src/d_phy_receiver.v \
  src/camera.v \
  src/decoders/raw8.sv \
  src/decoders/rgb565.v \
  src/header_ecc.v \
  src/downsample.v \
  src/buffer.v \
  src/uart_tx.v \
  src/clk_25_250_125_25.v \
  src/fake_differential.v \
  src/hdmi_video.v \
  src/pll.v \
  src/tmds_encoder.v \
  src/vga2dvid.v \
  src/vga_video.v
#  src/downsample_bf.v \
#  src/uart.v \
#  src/uart_tx.v 
#  src/decoders/raw8.sv \
#  src/decoders/rgb565.sv \
#  src/decoders/rgb888.sv \
#  src/decoders/yuv422_8bit.sv
#  src/d_phy_receiver.sv \
#  src/camera.sv
#  src/i2c_master.sv \
#  src/ov5647.sv
#  phy/word_combiner.v \
#  csi/rx_packet_handler.v \
#  csi/header_ecc.v \
#  top/csi_rx_ecp5.v \
#  misc/downsample.v \
#  test/icebreaker/uart.v
#  test/icebreaker/top.v \
#  phy/dphy_iserdes.v \
#  phy/dphy_oserdes.v \
#  phy/word_combiner.v \
#  phy/byte_aligner.v \
#  csi/header_ecc.v
#  top/csi_rx_ecp5.v \
#  csi/rx_packet_handler.v

# *.vhd those files will be converted to *.v files with vhdl2vl (warning overwriting/deleting)
VHDL_FILES = \
#  hdl/vga.vhd \
#  hdl/vga2dvid.vhd \
#  hdl/tmds_encoder.vhd

# synthesis options
#YOSYS_OPTIONS = -noccu2
NEXTPNR_OPTIONS = --timing-allow-fail --speed 6

SCRIPTS = ../../scripts
include $(SCRIPTS)/diamond_path.mk
include $(SCRIPTS)/trellis_path.mk
include $(SCRIPTS)/trellis_main.mk
