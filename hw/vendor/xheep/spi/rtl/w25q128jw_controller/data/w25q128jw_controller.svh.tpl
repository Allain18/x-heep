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
    w25 = xheep.get_base_peripheral_domain().get_W25Q128JW_controller()
    cache = w25.get_cache()
%>

% if cache:
`define CACHE_EN
% endif
