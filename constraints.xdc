## Clock (25 MHz from Ethernet PHY)
set_property -preset_info {YOUR_CLOCK_SOURCE} [get_ports clk]
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { clk }]; # ETH_REFCLK

## Ethernet TX Interface
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { eth_tx_en }];
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[0] }];
set_property -dict { PACKAGE_PIN J14   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[1] }];
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[2] }];
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { eth_txd[3] }];

## Reset and Buttons
set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports { rst }]; # Reset Button
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { send_btn }]; # BTN0