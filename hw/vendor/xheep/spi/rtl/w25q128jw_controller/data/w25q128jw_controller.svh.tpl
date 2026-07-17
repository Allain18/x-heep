/*
 * Copyright 2025 EPFL
 * Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Author: Tommaso Terzano <alain.girard@epfl.ch> 
 *                         <alaingirardvd@gmail.com>
 *  
 * Info: Header file for the W25Q128JW controller.
 */

<% 
    base_peripheral_domain = xheep.get_base_peripheral_domain()
    if base_peripheral_domain.contains_peripheral('w25q128jw_controller'):
        w25 = xheep.get_base_peripheral_domain().get_W25Q128JW_controller()
        cache = w25.get_cache()
    else:
        cache = 0
%>

% if cache:
`define CACHE_EN_def
% endif
