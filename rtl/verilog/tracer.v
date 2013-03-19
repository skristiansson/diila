/*
 * Trace logger
 *
 * Description
 *
 * Logs the signals 'trig0', 'data0', data1, ...
 * after a trigger event has occurred.
 *
 * WB interface:
 * Write Address 0x0000, Arm the trigger
 * Write Address 0x0004, Set post trigger count (default = 32)
 *
 * Read Address  0x0000 - 0x03ff, Read trig0 trace log
 * Read Address  0x0400 - 0x07ff, Read data0 trace log
 * Read Address  0x0800 - 0x0bff, Read data1 trace log
 * Read Address  0x0C00 - 0x0fff, Read data2 trace log
 *
 * (C) 2013, Stefan Kristiansson, stefan.kristiansson@saunalahti.fi
 */
`timescale 1ns / 1ps

module tracer(
	      // WB
	      input wire 	 wb_rst_i,
	      input wire 	 wb_clk_i,
	      input wire [31:0]  wb_dat_i,
	      input wire [13:2]  wb_adr_i,
	      input wire [3:0] 	 wb_sel_i,
	      input wire 	 wb_we_i,
	      input wire 	 wb_cyc_i,
	      input wire 	 wb_stb_i,
	      output wire [31:0] wb_dat_o,
	      output reg 	 wb_ack_o,
	      output wire 	 wb_err_o,
	      output wire 	 wb_rty_o,

	      // Tracer signals
	      input wire [31:0]  trig0_i,
	      input wire [31:0]  data0_i,
	      input wire [31:0]  data1_i,
	      input wire [31:0]  data2_i
);
   //---------------------------------------------------------------------------
   // Wishbone
   //---------------------------------------------------------------------------
   reg [31:0] 			 trigger;
   reg [31:0] 			 trig0_rd;
   reg [31:0] 			 data0_rd;
   reg [31:0] 			 data1_rd;
   reg [31:0] 			 data2_rd;
   reg 				 new_trig;
   reg [9:0] 			 post_trig_done_cnt;
   // Read
   assign wb_dat_o = (wb_adr_i[13:12] == 2'b00) ? trig0_rd :
                     (wb_adr_i[13:12] == 2'b01) ? data0_rd :
                     (wb_adr_i[13:12] == 2'b10) ? data1_rd :
                     (wb_adr_i[13:12] == 2'b11) ? data2_rd :
                     32'b0;

   // Write
   always @(posedge wb_clk_i) begin
      new_trig <= 0;
      if (wb_rst_i) begin
	 trigger <= 32'h00000000;
	 post_trig_done_cnt <= 10'd32;
      end else if (wb_stb_i & wb_cyc_i & wb_we_i) begin
	 if (wb_adr_i == 0) begin
	    trigger  <= wb_dat_i;
	    new_trig <= 1;
         end else if (wb_adr_i == 4) begin
	    post_trig_done_cnt <= wb_dat_i[9:0];
	 end
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

   //---------------------------------------------------------------------------
   // Trigger
   //---------------------------------------------------------------------------
   reg [11:2] mem_pos;
   reg [11:2] trig_pos;
   reg [9:0]  post_trig_cnt;
   reg        trig_hit;
   reg        done;

   always @(posedge wb_clk_i)
     if (wb_rst_i | new_trig) begin
	trig_pos <= 0;
	trig_hit <= 0;
     end else if (trig0_i == trigger & !trig_hit) begin
	trig_pos <= mem_pos + 1;
	trig_hit <= 1;
     end

   always @(posedge wb_clk_i)
     if (wb_rst_i | new_trig)
       post_trig_cnt <= 0;
     else if (trig_hit & !done)
       post_trig_cnt <= post_trig_cnt + 1;

   always @(posedge wb_clk_i)
     if (wb_rst_i)
       mem_pos <= 0;
     else
       mem_pos <= mem_pos + 1;

   always @(posedge wb_clk_i)
     if (wb_rst_i | new_trig)
       done <= 0;
     else if (post_trig_cnt == post_trig_done_cnt)
       done <= 1;

   //---------------------------------------------------------------------------
   // Logging logic (Block RAM's)
   //---------------------------------------------------------------------------
   reg  [31:0] trig0_mem[1023:0];
   reg [31:0]  data0_mem[1023:0];
   reg [31:0]  data1_mem[1023:0];
   reg [31:0]  data2_mem[1023:0];
   wire        wr_en;
   wire [11:2] wr_addr;
   wire [11:2] rd_addr;

   assign wr_addr = mem_pos;
   assign rd_addr = wb_adr_i[11:2] +
		    ((trig_pos + post_trig_done_cnt) - 10'd1023);
   assign wr_en   = !done;

   always @(posedge wb_clk_i) begin
      if (wr_en) begin
	 trig0_mem[wr_addr] <= trig0_i;
	 data0_mem[wr_addr] <= data0_i;
	 data1_mem[wr_addr] <= data1_i;
	 data2_mem[wr_addr] <= data2_i;
      end
      trig0_rd <= trig0_mem[rd_addr];
      data0_rd <= data0_mem[rd_addr];
      data1_rd <= data1_mem[rd_addr];
      data2_rd <= data2_mem[rd_addr];
   end
endmodule
