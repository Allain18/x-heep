// Copyright EPFL contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

<% 
    base_peripheral_domain = xheep.get_base_peripheral_domain()
    if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
        w25 = xheep.get_base_peripheral_domain().get_W25Q128JW_controller()
        cache = w25.get_cache()
    else:
        cache = 0
%>

{ name: "w25q128jw_controller"
  clock_primary: "clk_i"
  bus_interfaces: [
    { protocol: "reg_iface", direction: "device" }
  ]
  regwidth: "32"

  registers: [
    { name: "CONTROL"
      desc: "Control register for flash controller"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "2", name: "QUAD", desc: "Quad spi mode", resval: "0x0" swaccess: "rw", hwaccess: "hro"}
        { bits: "1", name: "RNW", desc: "Read Not Write operation mode", resval: "0x0" }
        { bits: "0", name: "START", desc: "Start operation", resval: "0x0" }
      ]
    }

    { name: "STATUS"
      desc: "Status register for flash controller"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "0", name: "READY", desc: "Ready for new operation", resval: "0x0" }
      ]
    }

    { name: "F_ADDRESS"
      desc: "Address in flash to read from/write to"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "31:0", name: "F_ADDRESS", desc: "Address in flash to read from/write to" }
      ]
    }

    { name: "S_ADDRESS"
      desc: "Address to store read data from SPI_FLASH"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "31:0", name: "S_ADDRESS", desc: "Address to store read data from SPI_FLASH" }
      ]
    }

    { name: "MD_ADDRESS"
      desc: "Address where data with which we have to modify the flash is"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "31:0", name: "MD_ADDRESS", desc: "Address where data with which we have to modify the flash is" }
      ]
    }

    { name: "LENGTH"
      desc: "Length of data to W/R"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "31:0", name: "LENGTH", desc: "Length of data to W/R" }
      ]
    }
    { name: "INTR_STATUS"
      desc: "Interrupt status register"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "0", name: "INTR_STATUS", desc: "Event interrupt status"}
     ]
    }
    { name: "INTR_ENABLE"
      desc: "Interrupt enable register"
      swaccess: "rw"
      hwaccess: "hro"
      fields: [
        { bits: "0", name: "INTR_ENABLE", desc: "interrupt enable"}
     ]
    }
    { name:    "DMA_SLOT_WAIT_COUNTER"
      desc:    '''A DMA counter used to wait before submitting the next req when using slots'''
      swaccess: "rw"
      hwaccess: "hro"
      resval:        0
      fields: [
        { bits: "7:0", name: "DMA_SLOT_WAIT_COUNTER", desc: "A DMA counter used to wait before submitting the next req when using slots"}
      ]
    }
    % if cache:
    {
      name:    "CACHE_DATA"
      desc:    "Cache data port, used to read from/write to the DMA buffer"
      swaccess: "rw"
      hwaccess: "hrw"
      fields: [
        { bits: "31:0", name: "CACHE_DATA", desc: "Cache data port, used to read from/write to the DMA buffer" }
      ]
    }
    % endif
  ]
}
