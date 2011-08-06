//////////////////////////////////////////////////////////////////////
////                                                              ////
////  Trace logger                                                ////
////                                                              ////
////  Description                                                 ////
////                                                              ////
////  Logs the two signals 'trig0' and 'data0'                    ////
////  after a trigger event has occurred.                         ////
////                                                              ////
////  WB interface:                                               ////
////  Write Address 0x0000, Arm the trigger                       ////
////  Read Address  0x0000 - 0x03ff, Read trig0 trace log         ////
////  Read Address  0x0400 - 0x07ff, Read data0 trace log         ////
////  Read Address  0x0800 - 0x0Bff, Read data0 trace log         ////
////  Read Address  0x0C00 - 0x0fff, Read data0 trace log         ////
////                                                              ////
////  Author(s):                                                  ////
////    - Stefan Kristiansson, stefan.kristiansson@saunalahti.fi  ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2011 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module tracer(
    // WB
    input  wire        wb_rst_i,
    input  wire        wb_clk_i,
    input  wire [31:0] wb_dat_i,
    input  wire [13:2] wb_adr_i,
    input  wire [3:0]  wb_sel_i,
    input  wire        wb_we_i,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    output wire [31:0] wb_dat_o,
    output reg         wb_ack_o,
    output wire        wb_err_o,
    output wire        wb_rty_o,

    // Tracer signals
    input wire [31:0]  trig0_i,
    input wire [31:0]  data0_i,
    input wire [31:0]  data1_i,
    input wire [31:0]  data2_i
);
    //--------------------------------------------------------------------------
    // Wishbone
    //--------------------------------------------------------------------------
    reg  [31:0] trigger;
    reg  [31:0] trig0_rd;
    reg  [31:0] data0_rd;
    reg  [31:0] data1_rd;
    reg  [31:0] data2_rd;
    reg         new_trig;
    // Read
    assign wb_dat_o = (wb_adr_i[13:12] == 2'b00) ? trig0_rd :
                      (wb_adr_i[13:12] == 2'b01) ? data0_rd : 
                      (wb_adr_i[13:12] == 2'b10) ? data1_rd : 
                      (wb_adr_i[13:12] == 2'b11) ? data2_rd : 
                      32'b0;

    // Write 
    always @(posedge wb_clk_i) begin
      new_trig <= 0;
      if (wb_rst_i)
        trigger <= 32'h00000000;
      else if (wb_stb_i & wb_cyc_i & wb_we_i)
        if (wb_adr_i == 0) begin
          trigger  <= wb_dat_i;
          new_trig <= 1;
        end
    end

    // Ack generation
    always @(posedge wb_clk_i)
      if (wb_rst_i)
        wb_ack_o <= 0;
      else if (wb_ack_o)
        wb_ack_o <= 0;
      else if (wb_cyc_i & wb_stb_i & !wb_ack_o)
        wb_ack_o <= 1;
     
    assign wb_err_o = 0;
    assign wb_rty_o = 0;
    
    
    //--------------------------------------------------------------------------
    // Trigger
    //--------------------------------------------------------------------------
    reg [11:2] mem_pos;
    reg        running;
    reg        done;
    
    always @(posedge wb_clk_i)
      if (wb_rst_i | new_trig)
        running <= 0;
      else if (trig0_i == trigger)
        running <= 1;
        
    always @(posedge wb_clk_i)
      if (wb_rst_i | new_trig)
        mem_pos <= 0;
      else if (running & !(&mem_pos))
        mem_pos <= mem_pos + 1;

    always @(posedge wb_clk_i)
      if (wb_rst_i | new_trig)
        done <= 0;
      else if (&mem_pos)
        done <= 1;
  
    
    //--------------------------------------------------------------------------
    // Logging logic (Block RAM's)
    //--------------------------------------------------------------------------
    reg  [31:0] trig0_mem[1023:0];
    reg  [31:0] data0_mem[1023:0];
    reg  [31:0] data1_mem[1023:0];
    reg  [31:0] data2_mem[1023:0];
    reg  [31:0] trig0_q;
    reg  [31:0] data0_q;
    reg  [31:0] data1_q;
    reg  [31:0] data2_q;
    wire        wr_en;
    wire [11:2] wr_addr;

    assign wr_addr = mem_pos;
    assign wr_en   = running & !done;  

    always @(posedge wb_clk_i) begin
      trig0_q <= trig0_i;
      data0_q <= data0_i;
      data1_q <= data1_i;
      data2_q <= {wr_addr[9:2], data2_i[23:0]};
    end

    always @(posedge wb_clk_i) begin
      if (wr_en) begin
        trig0_mem[wr_addr] <= trig0_q;
        data0_mem[wr_addr] <= data0_q;
        data1_mem[wr_addr] <= data1_q;
        data2_mem[wr_addr] <= data2_q;
      end
      trig0_rd <= trig0_mem[wb_adr_i[11:2]];
      data0_rd <= data0_mem[wb_adr_i[11:2]];
      data1_rd <= data1_mem[wb_adr_i[11:2]];
      data2_rd <= data2_mem[wb_adr_i[11:2]];
    end
endmodule
