//////////////////////////////////////////////////////////////////////
////                                                              ////
////  8051 cores sfr top level module                             ////
////                                                              ////
////  This file is part of the 8051 cores project                 ////
////  http://www.opencores.org/cores/8051/                        ////
////                                                              ////
////  Description                                                 ////
////   special function registers for oc8051                      ////
////                                                              ////
////  To Do:                                                      ////
////    nothing                                                   ////
////                                                              ////
////  Author(s):                                                  ////
////      - Simon Teran, simont@opencores.org                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
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
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.14  2003/05/07 12:39:20  simont
// fix bug in case of sequence of inc dptr instrucitons.
//
// Revision 1.13  2003/05/05 15:46:37  simont
// add aditional alu destination to solve critical path.
//
// Revision 1.12  2003/04/29 11:24:31  simont
// fix bug in case execution of two data dependent instructions.
//
// Revision 1.11  2003/04/25 17:15:51  simont
// change branch instruction execution (reduse needed clock periods).
//
// Revision 1.10  2003/04/10 12:43:19  simont
// defines for pherypherals added
//
// Revision 1.9  2003/04/09 16:24:03  simont
// change wr_sft to 2 bit wire.
//
// Revision 1.8  2003/04/09 15:49:42  simont
// Register oc8051_sfr dato output, add signal wait_data.
//
// Revision 1.7  2003/04/07 14:58:02  simont
// change sfr's interface.
//
// Revision 1.6  2003/04/07 13:29:16  simont
// change uart to meet timing.
//
// Revision 1.5  2003/04/04 10:35:07  simont
// signal prsc_ow added.
//
// Revision 1.4  2003/03/28 17:45:57  simont
// change module name.
//
// Revision 1.3  2003/01/21 13:51:30  simont
// add include oc8051_defines.v
//
// Revision 1.2  2003/01/13 14:14:41  simont
// replace some modules
//
// Revision 1.1  2002/11/05 17:22:27  simont
// initial import
//
//

// synopsys translate_off
`include "oc8051_timescale.v"
// synopsys translate_on

`include "oc8051_defines.v"


module lp805x_sfr (rst, clk,
       adr0, adr1, data_out, 
       dat1, dat2, bit_in,
       des_acc,
       we, wr_bit,
       bit_out,
       wr_sfr, acc, acc_bypass,
       ram_wr_sel, ram_rd_sel, 
       sp, sp_w, 
       bank_sel, 
       desAc, desOv,
       srcAc, cy,
       psw_set,
       comp_sel,
       comp_wait,

  `ifdef LP805X_UART
       rxd, txd,
  `endif

       int_ack, intr,
       int0, int1,
       int_src,
       reti,
		 ntf,
		 ntr,

  `ifdef LP805X_TC01
       t0, t1,
  `endif

  `ifdef LP805X_TC2
       t2, t2ex,
  `endif

       dptr_hi, dptr_lo, dptr,
       wait_data);

input ntf,ntr;

input       rst,	// reset - pin
	    clk,	// clock - pin
            we,		// write enable
	    bit_in,
	    desAc,
	    desOv;
input       int_ack,
            int0,
	    int1,
            reti,
	    wr_bit;
input [1:0] psw_set,
            wr_sfr,
	    comp_sel;
input [2:0] ram_rd_sel,
            ram_wr_sel;
input [7:0] adr0, 	//address 0 input
            adr1, 	//address 1 input
	    des_acc,
	    dat1,	//data 1 input (des1)
            dat2;	//data 2 input (des2)

output       bit_out,
             intr,
             srcAc,
	     cy,
	     wait_data,
	     comp_wait;
output [1:0] bank_sel;
output [7:0] int_src,
	     dptr_hi,
	     dptr_lo,
	     acc,
		  acc_bypass;
		  
output [15:0] dptr;		  
		  
output tri [7:0] data_out;	//data output				  
		  
output [7:0] sp,
             sp_w;
				 
				 
				 
// serial interface
`ifdef LP805X_UART
input        rxd;
output       txd;
`endif

// timer/counter 0,1
`ifdef LP805X_TC01
input	     t0, t1;
`endif

// timer/counter 2
`ifdef LP805X_TC2
input	     t2, t2ex;
`endif

tri		bit_out;
reg        bit_outd, 
           wait_data;
reg [7:0]  adr0_r;

reg        wr_bit_r;
reg [2:0]  ram_wr_sel_r;


wire       p,
           uart_int,
	   tf0,
	   tf1,
	   tr0,
	   tr1,
           rclk,
           tclk,
	   brate2,
	   tc2_int;


wire [7:0] b_reg, 
           psw,

`ifdef LP805X_TC2
  // t/c 2
	   t2con, 
	   tl2, 
	   th2, 
	   rcap2l, 
	   rcap2h,
`endif

`ifdef LP805X_TC01
  // t/c 0,1
	   tmod, 
	   tl0, 
	   th0, 
	   tl1,
	   th1,
`endif

  // serial interface
`ifdef LP805X_UART
           scon, 
	   pcon, 
	   sbuf,
`endif

  //interrupt control
	   ie, 
	   tcon, 
	   ip;


reg        pres_ow;
reg [3:0]  prescaler;


assign cy = psw[7];
assign srcAc = psw [6];



//
// accumulator
// ACC
lp805x_acc acc_1(.clk(clk), 
                       .rst(rst), 
		       .bit_in(bit_in), 
		       .data_in(des_acc),
		       .data2_in(dat2),
		       .wr(we),
		       .wr_bit(wr_bit_r),
		       .wr_sfr(wr_sfr),
		       .wr_addr(adr1),
		       .data_out(acc),
				 .acc(acc_bypass),
		       .p(p));


//
// b register
// B
lp805x_b_register b_register_1 (.clk(clk),
                                     .rst(rst),
				     .bit_in(bit_in),
				     .data_in(des_acc),
				     .wr(we), 
				     .wr_bit(wr_bit_r), 
				     .wr_addr(adr1),
				     .data_out(b_reg));

//
//stack pointer
// SP
lp805x_sp sp_1(.clk(clk), 
                     .rst(rst), 
		     .ram_rd_sel(ram_rd_sel), 
		     .ram_wr_sel(ram_wr_sel), 
		     .wr_addr(adr1), 
		     .wr(we), 
		     .wr_bit(wr_bit_r), 
		     .data_in(dat1), 
		     .sp_out(sp), 
		     .sp_w(sp_w));

//
//data pointer
// DPTR, DPH, DPL
lp805x_dptr dptr_1(.clk(clk), 
                         .rst(rst), 
			 .addr(adr1), 
			 .data_in(des_acc),
			 .data2_in(dat2), 
			 .wr(we), 
			 .wr_bit(wr_bit_r),
			 .data_hi(dptr_hi),
			 .data_lo(dptr_lo), 
			 .wr_sfr(wr_sfr),
			 .dptr(dptr));


//
//program status word
// PSW
lp805x_psw psw_1 (
			.clk(clk), 
         .rst(rst), 
			.wr_addr(adr1), 
			.data_in(dat1),
			.wr(we), 
			.wr_bit(wr_bit_r), 
			.data_out(psw), 
			.p(p), 
			.cy_in(bit_in),
			.ac_in(desAc), 
			.ov_in(desOv), 
			.set(psw_set), 
			.bank_sel(bank_sel));


//
// serial interface
// SCON, SBUF
`ifdef LP805X_UART
  lp805x_uart uart_1 (.clk(clk), 
                            .rst(rst), 
			    .bit_in(bit_in),
			    .data_in(dat1), 
			    .wr(we), 
			    .wr_bit(wr_bit_r), 
			    .wr_addr(adr1),
			    .rxd(rxd), 
			    .txd(txd), 
		// interrupt
			    .intr(uart_int),
		// baud rate sources
			    .brate2(brate2),
			    .t1_ow(tf1),
			    .pres_ow(pres_ow),
			    .rclk(rclk),
			    .tclk(tclk),
		//registers
			    .scon(scon),
			    .pcon(pcon),
			    .sbuf(sbuf));
`else
  assign uart_int = 1'b0;
`endif

//
// interrupt control
// IP, IE, TCON
lp805x_int int_1 (.clk(clk), 
                        .rst(rst), 
			.wr_addr(adr1), 
			.bit_in(bit_in),
			.ack(int_ack), 
			.data_in(dat1),
			.wr(we), 
			.wr_bit(wr_bit_r),
			.tf0(tf0), 
			.tf1(tf1), 
			.t2_int(tc2_int), 
			.tr0(tr0), 
			.tr1(tr1),
			.ie0(int0), 
			.ie1(int1),
			.uart_int(uart_int),
			.reti(reti),
			.intr(intr),
			.int_vec(int_src),
			.ie(ie),
			.tcon(tcon), 
			.ip(ip),
			.ntf(ntf),
			.ntr(ntr)
			);


//
// timer/counter control
// TH0, TH1, TL0, TH1, TMOD
`ifdef LP805X_TC01
  lp805x_tc tc_1(.clk(clk), 
                       .rst(rst), 
		       .wr_addr(adr1),
		       .data_in(dat1), 
		       .wr(we), 
		       .wr_bit(wr_bit_r), 
		       .ie0(int0), 
		       .ie1(int1), 
		       .tr0(tr0),
		       .tr1(tr1), 
		       .t0(t0), 
		       .t1(t1), 
		       .tf0(tf0), 
		       .tf1(tf1), 
		       .pres_ow(pres_ow),
		       .tmod(tmod), 
		       .tl0(tl0), 
		       .th0(th0), 
		       .tl1(tl1), 
		       .th1(th1));
`else
  assign tf0 = 1'b0;
  assign tf1 = 1'b0;
`endif

//
// timer/counter 2
// TH2, TL2, RCAPL2L, RCAPL2H, T2CON
`ifdef LP805X_TC2
  lp805x_tc2 tc2_1(.clk(clk), 
                         .rst(rst), 
			 .wr_addr(adr1),
			 .data_in(dat1), 
			 .wr(we),
			 .wr_bit(wr_bit_r), 
			 .bit_in(bit_in), 
			 .t2(t2), 
			 .t2ex(t2ex),
			 .rclk(rclk), 
			 .tclk(tclk), 
			 .brate2(brate2), 
			 .tc2_int(tc2_int), 
			 .pres_ow(pres_ow),
			 .t2con(t2con), 
			 .tl2(tl2), 
			 .th2(th2), 
			 .rcap2l(rcap2l), 
			 .rcap2h(rcap2h));
`else
  assign tc2_int = 1'b0;
  assign rclk    = 1'b0;
  assign tclk    = 1'b0;
  assign brate2  = 1'b0;
`endif



always @(posedge clk or posedge rst)
  if (rst) begin
    //adr0_r <= #1 8'h00;
    ram_wr_sel_r <= #1 3'b000;
    wr_bit_r <= #1 1'b0;
//    wait_data <= #1 1'b0;
  end else begin
    //adr0_r <= #1 adr0;
    ram_wr_sel_r <= #1 ram_wr_sel;
    wr_bit_r <= #1 wr_bit;
  end

assign comp_wait = !(
                    ((comp_sel==`LP805X_CSS_AZ) &
		       ((wr_sfr==`LP805X_WRS_ACC1) |
		        (wr_sfr==`LP805X_WRS_ACC2) |
			((adr1==`LP805X_SFR_ACC) & we & !wr_bit_r) |
			((adr1[7:3]==`LP805X_SFR_B_ACC) & we & wr_bit_r))) |
		    ((comp_sel==`LP805X_CSS_CY) &
		       ((|psw_set) |
			((adr1==`LP805X_SFR_PSW) & we & !wr_bit_r) |
			((adr1[7:3]==`LP805X_SFR_B_PSW) & we & wr_bit_r))) |
		    ((comp_sel==`LP805X_CSS_BIT) &
		       ((adr1[7:3]==adr0[7:3]) & (~&adr1[2:0]) &  we & !wr_bit_r) |
		       ((adr1==adr0) & adr1[7] & we & !wr_bit_r)));

reg [7:0] data_outd;
reg 		data_outc;
assign data_out = data_outc ? data_outd : 8'hzz;
//
//set output in case of address (byte)
always @(posedge clk or posedge rst)
begin
  if (rst) begin
    {data_outc,data_outd} <= #1 {1'b0,8'h00};
    wait_data <= #1 1'b0;
  end else if ((wr_sfr==`LP805X_WRS_DPTR) & (adr0==`LP805X_SFR_DPTR_LO)) begin				//write and read same address
    {data_outc,data_outd} <= #1 {1'b1,des_acc};
    wait_data <= #1 1'b0;
  end else if (
      (
        ((wr_sfr==`LP805X_WRS_ACC1) & (adr0==`LP805X_SFR_ACC)) | 	//write to acc
//        ((wr_sfr==`LP805X_WRS_DPTR) & (adr0==`LP805X_SFR_DPTR_LO)) |	//write to dpl
        (adr1[7] & (adr1==adr0) & we & !wr_bit_r) |			//write and read same address
        (adr1[7] & (adr1[7:3]==adr0[7:3]) & (~&adr0[2:0]) &  we & wr_bit_r) //write bit addressable to read address
      ) & !wait_data) begin
	 //{data_outc,data_outd} <= #1 {1'b1, ????
    wait_data <= #1 1'b1;

  end else if ((
      ((|psw_set) & (adr0==`LP805X_SFR_PSW)) |
      ((wr_sfr==`LP805X_WRS_ACC2) & (adr0==`LP805X_SFR_ACC)) | 	//write to acc
      ((wr_sfr==`LP805X_WRS_DPTR) & (adr0==`LP805X_SFR_DPTR_HI))	//write to dph
      ) & !wait_data) begin
    wait_data <= #1 1'b1;
	// ?????
  end else begin
    case (adr0)
      `LP805X_SFR_ACC: 		{data_outc,data_outd} <= #1 {1'b1,acc};
      `LP805X_SFR_PSW: 		{data_outc,data_outd} <= #1 {1'b1,psw};

      `LP805X_SFR_SP: 		{data_outc,data_outd} <= #1 {1'b1,sp};
      `LP805X_SFR_B: 		{data_outc,data_outd} <= #1 {1'b1,b_reg};
      `LP805X_SFR_DPTR_HI: 	{data_outc,data_outd} <= #1 {1'b1,dptr_hi};
      `LP805X_SFR_DPTR_LO: 	{data_outc,data_outd} <= #1 {1'b1,dptr_lo};

`ifdef LP805X_UART
      `LP805X_SFR_SCON: 	{data_outc,data_outd} <= #1 {1'b1,scon};
      `LP805X_SFR_SBUF: 	{data_outc,data_outd} <= #1 {1'b1,sbuf};
      `LP805X_SFR_PCON: 	{data_outc,data_outd} <= #1 {1'b1,pcon};
`endif

`ifdef LP805X_TC01
      `LP805X_SFR_TH0: 		{data_outc,data_outd} <= #1 {1'b1,th0};
      `LP805X_SFR_TH1: 		{data_outc,data_outd} <= #1 {1'b1,th1};
      `LP805X_SFR_TL0: 		{data_outc,data_outd} <= #1 {1'b1,tl0};
      `LP805X_SFR_TL1: 		{data_outc,data_outd} <= #1 {1'b1,tl1};
      `LP805X_SFR_TMOD: 	{data_outc,data_outd} <= #1 {1'b1,tmod};
`endif

      `LP805X_SFR_IP: 		{data_outc,data_outd} <= #1 {1'b1,ip};
      `LP805X_SFR_IE: 		{data_outc,data_outd} <= #1 {1'b1,ie};
      `LP805X_SFR_TCON: 	{data_outc,data_outd} <= #1 {1'b1,tcon};

`ifdef LP805X_TC2
      `LP805X_SFR_RCAP2H: 	{data_outc,data_outd} <= #1 {1'b1,rcap2h};
      `LP805X_SFR_RCAP2L: 	{data_outc,data_outd} <= #1 {1'b1,rcap2l};
      `LP805X_SFR_TH2:    	{data_outc,data_outd} <= #1 {1'b1,th2};
      `LP805X_SFR_TL2:    	{data_outc,data_outd} <= #1 {1'b1,tl2};
      `LP805X_SFR_T2CON:  	{data_outc,data_outd} <= #1 {1'b1,t2con};
`endif

      default: 			{data_outc,data_outd} <= #1 {1'b0,8'h00};
    endcase
    wait_data <= #1 1'b0;
  end
end

reg bit_outc;

assign bit_out = bit_outc ? bit_outd : 1'bz;
//
//set output in case of address (bit)

always @(posedge clk or posedge rst)
begin
  if (rst)
    {bit_outc,bit_outd} <= #1 {1'b0,1'b0};
  else if (
          ((adr1[7:3]==adr0[7:3]) & (~&adr1[2:0]) &  we & !wr_bit_r) |
          ((wr_sfr==`LP805X_WRS_ACC1) & (adr0[7:3]==`LP805X_SFR_B_ACC)) 	//write to acc
	  )
    {bit_outc,bit_outd} <= #1 {1'b1,dat1[adr0[2:0]]};
  else if ((adr1==adr0) & we & wr_bit_r)
    {bit_outc,bit_outd} <= #1 {1'b1,bit_in};
  else
    case (adr0[7:3]) /* previous full_mask parallel_mask */
      `LP805X_SFR_B_ACC:   {bit_outc,bit_outd} <= #1 {1'b1,acc[adr0[2:0]]};
      `LP805X_SFR_B_PSW:   {bit_outc,bit_outd} <= #1 {1'b1,psw[adr0[2:0]]};

      `LP805X_SFR_B_B:     {bit_outc,bit_outd} <= #1 {1'b1,b_reg[adr0[2:0]]};
      `LP805X_SFR_B_IP:    {bit_outc,bit_outd} <= #1 {1'b1,ip[adr0[2:0]]};
      `LP805X_SFR_B_IE:    {bit_outc,bit_outd} <= #1 {1'b1,ie[adr0[2:0]]};
      `LP805X_SFR_B_TCON:  {bit_outc,bit_outd} <= #1 {1'b1,tcon[adr0[2:0]]};

`ifdef LP805X_UART
      `LP805X_SFR_B_SCON:  {bit_outc,bit_outd} <= #1 {1'b1,scon[adr0[2:0]]};
`endif

`ifdef LP805X_TC2
      `LP805X_SFR_B_T2CON: {bit_outc,bit_outd} <= #1 {1'b1,t2con[adr0[2:0]]};
`endif

      default:             {bit_outc,bit_outd} <= #1 {1'b0,1'b0};
    endcase
end

always @(posedge clk or posedge rst)
begin
  if (rst) begin
    prescaler <= #1 4'h0;
    pres_ow <= #1 1'b0;
  end else if (prescaler==4'b1011) begin
    prescaler <= #1 4'h0;
    pres_ow <= #1 1'b1;
  end else begin
    prescaler <= #1 prescaler + 4'h1;
    pres_ow <= #1 1'b0;
  end
end

endmodule
