//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:39:42 05/20/2012 
// Design Name: 
// Module Name:    lp805x_newtimer 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: MMIO INTERFACE
//
//////////////////////////////////////////////////////////////////////////////////

// synopsys translate_off
`include "oc8051_timescale.v"
// synopsys translate_on
`include "oc8051_defines.v"

`define LP805X_SFR_NTMRH 8'hea
`define LP805X_SFR_NTMRL 8'heb
`define LP805X_SFR_NTMRCTR 8'he8
`define LP805X_SFR_B_NTMRCTR 5'b11101

module lp805x_newtimer
	(
		clk, 
		rst,
		bit_in,
		bit_out,
		data_in,
		data_out,
		wr, 
		wr_bit,
		rd,
		rd_bit,
		wr_addr, 
		rd_addr,
		ntf,
		ntr,
		
		pin_cnt,
		pin
	);
	 
parameter TIMER_BITLEN = 16;
parameter PRESCALE_BITLEN = 8; //prescaler of 256!

parameter TIMER_RSTVAL = 0;

parameter BITMODES_LEN = 3;

parameter TIMERCTR_RSTVAL = 0;

parameter PWMS_LEN = 0;
parameter PWMS_TYPE = 0;
	 
input clk,rst; //inter

input wr,rd;
input wr_bit,rd_bit;

input [7:0]	wr_addr,rd_addr;

input [7:0] data_in;
input bit_in;

output tri [7:0] data_out;
output tri bit_out;

reg [7:0] data_read;
reg		 bit_read;

output ntf, ntr;

// I/O pins

input pin_cnt;

output reg [PWMS_LEN-1:0] pin;

// I/O pins

//two-ways of prescaling, let's try the lsb xtra bit count way
reg [ (TIMER_BITLEN)-1:0] timer_count;
reg [ PRESCALE_BITLEN-1:0] timer_pres; // bit 0 - no bit at all
reg timer_ov;
reg [7:0] timer_control;

wire [2:0] presc_ctr; //prescaling the timer count
wire ctc_mode; //ctc, pwm pin toggle mode
wire inc_timer; //condition to increment is match! assign...
wire int_enable;
wire cnt_mode;

assign
	presc_ctr = timer_control[7:5],
	inc_timer = timer_control[4],
	cnt_mode = timer_control[3],	
	ctc_mode = timer_control[2],
	int_enable = timer_control[1];
	

assign 
	ntf = timer_ov,
	ntr = 1'b1;


always @(posedge clk or posedge rst)
begin
	if ( rst) begin
		timer_control <= #1 TIMERCTR_RSTVAL;
	end else if (wr) begin
		if (!wr_bit) begin
			case ( wr_addr)
				`LP805X_SFR_NTMRCTR: timer_control <= #1 data_in;
			endcase
		end else begin
			case (wr_addr[7:3])
				`LP805X_SFR_B_NTMRCTR: timer_control[wr_addr[2:0]] <= #1 bit_in;
			endcase
		end
		if ( !rst & timer_ov) begin
		timer_control[0] <= #1 1'b1;
		end
	end else begin
		if ( !rst & timer_ov) begin
		timer_control[0] <= #1 1'b1;
		end
	end
end

reg [6:0] pres_src;

always @(*)
begin
	case ( presc_ctr)
	3'b000: pres_src = 7'b1111111;
	3'b001: pres_src = { timer_pres[0], 6'b111111 };
	3'b010: pres_src = { timer_pres[1:0], 5'b11111 };
	3'b011: pres_src = { timer_pres[2:0], 4'b1111 };
	3'b100: pres_src = { timer_pres[3:0], 3'b111 };
	3'b101: pres_src = { timer_pres[4:0], 2'b11 };
	3'b110: pres_src = { timer_pres[5:0], 1'b1 };
	3'b111: pres_src = timer_pres[6:0];
	endcase
end

generate 
		if ( PWMS_LEN == 1) begin
			always @( posedge clk)
			begin
				if ( timer_ov & ctc_mode) //overflow & ctc turned on!
				begin
					pin <= ~pin;
				end
			end
		end
		else if ( PWMS_TYPE == 0) begin
			always @( posedge clk)
			begin
				if ( rst)
				begin
					pin <= #1 1'b1;
				end
				else if ( pin == 0)
				begin
					pin <= #1 1'b1;
				end
				else if ( timer_ov & ctc_mode) //overflow & ctc turned on!
				begin
					pin <= #1 pin << 1;
				end
			end
		end
		else if ( PWMS_TYPE == 1) begin
			always @( posedge clk)
			begin
				if ( rst)
				begin
					pin <= #1 1'b0;
				end
				else if ( timer_ov & ctc_mode) //overflow & ctc turned on!
				begin
					pin <= pin + 1;
				end
			end
		end
endgenerate

// new timer - counter mode from pin
//

reg ntc_r;
reg ntc_event;

reg [6:0] dummy; // decoy to control prescale adder outputs
always @(posedge clk or posedge rst)
begin
	if ( rst) begin
		timer_count <= #1 TIMER_RSTVAL;
		timer_ov <= #1 1'b0;
		timer_pres <= #1 8'b0;
		dummy <= #1 7'b0;
	end else if ((wr) & !(wr_bit) & (wr_addr==`LP805X_SFR_NTMRH)) begin
		timer_count <= #1 {data_in,timer_count[7:0]};
	end else if ((wr) & !(wr_bit) & (wr_addr==`LP805X_SFR_NTMRL)) begin
		timer_count <= #1 {timer_count[15:8],data_in};		
	end else if ( inc_timer & ~(~ntc_event & cnt_mode)) begin
		case ( timer_control[BITMODES_LEN-1:0]) //nmr of configurable bits
			3'b000: begin//16 bit counter
			
				case ( presc_ctr)
				3'b000: { timer_ov, timer_count, dummy[6:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b001: { timer_ov, timer_count, timer_pres[0], dummy[5:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b010: { timer_ov, timer_count, timer_pres[1:0], dummy[4:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b011: { timer_ov, timer_count, timer_pres[2:0], dummy[3:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b100: { timer_ov, timer_count, timer_pres[3:0], dummy[2:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b101: { timer_ov, timer_count, timer_pres[4:0], dummy[1:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b110: { timer_ov, timer_count, timer_pres[5:0], dummy[0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
				
				3'b111: { timer_ov, timer_count, timer_pres[6:0] }
				<= #1 { 1'b0, timer_count, pres_src } + 1'b1;
		
				default: 
					begin
						timer_ov <= 1'b0;
						timer_count <= #1 timer_count;
						timer_pres <= #1 timer_pres;
						dummy <= #1 dummy;
					end
				endcase
			end
		3'b001: begin //
		
				
		
			end
		endcase
	end
end

reg output_data;
//
// case of reading byte from port
always @(posedge clk or posedge rst)
begin
  if (rst) begin
    {output_data,data_read} <= #1 {1'b0,8'h0};
	end
  else
	//if ( !rd_bit)
    case (rd_addr)
		`LP805X_SFR_NTMRH: 	{output_data,data_read} <= #1 {1'b1,timer_count[15:8]};
		`LP805X_SFR_NTMRL: 	{output_data,data_read} <= #1 {1'b1,timer_count[7:0]};
      `LP805X_SFR_NTMRCTR: {output_data,data_read} <= #1 {1'b1,timer_control[7:0]};
      default:             {output_data,data_read} <= #1 {1'b0,8'h0};
    endcase
end

assign data_out = output_data ? data_read : 8'hzz;

reg output_bit;
//
// case of reading bit from port
always @(posedge clk or posedge rst)
begin
  if (rst)
   {output_bit,bit_read} <= #1 {1'b0,1'b0};
  else
   if ( rd_bit)
    case (rd_addr[7:3])
      `LP805X_SFR_B_NTMRCTR:    {output_bit,bit_read} <= #1 {1'b1,timer_control[rd_addr[2:0]]};
	default:		{output_bit,bit_read} <= #1 {1'b0,1'b0};
    endcase
end

assign bit_out = output_bit ? bit_read : 1'bz;


// new timer - counter mode from pin
//

always @(posedge clk or posedge rst)
begin
  if (rst) begin
    ntc_event <= #1 1'b0;
    ntc_r <= #1 1'b0;
  end else if (pin_cnt) begin
    ntc_event <= #1 1'b0;
    ntc_r <= #1 1'b1;
  end else if (!pin_cnt & ntc_r) begin
    ntc_event <= #1 1'b1;
    ntc_r <= #1 1'b0;
  end else begin
    ntc_event <= #1 1'b0;
  end
end

endmodule
