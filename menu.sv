//============================================================================
//
//  Menu for MiSTer.
//  Copyright (C) 2017-2019 Sorgelig
//
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign DDRAM_CLK = clk_sys;
assign CE_PIXEL  = ce_pix;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VIDEO_ARX = 0;
assign VIDEO_ARY = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER[1]= 1;
assign BUTTONS = 0;

reg  [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + 1'd1; 
assign LED_USER    = FB ? led[0] : act_cnt[26]  ? act_cnt[25:18]  > act_cnt[7:0]  : act_cnt[25:18]  <= act_cnt[7:0];

wire [26:0] act_cnt2 = {~act_cnt[26],act_cnt[25:0]};
assign LED_POWER[0]= FB ? led[2] : act_cnt2[26] ? act_cnt2[25:18] > act_cnt2[7:0] : act_cnt2[25:18] <= act_cnt2[7:0];


localparam CONF_STR = {
	"MENU;;"
};

wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(cfg),
	
	.ps2_key(ps2_key)
);

/*
always @(posedge CLK_50M) begin
	integer sec, to;
	reg old_stb;
	
	sec <= sec + 1;
	if(sec >= 50000000) begin
		sec <= 0;
		to <= to + 1;
	end

	DIM <= (to >= 120);

	old_stb <= ps2_key[10];
	if((old_stb ^ ps2_key[10]) || status[0] || buttons[1]) to <= 0;
end
*/

////////////////////   CLOCKS   ///////////////////
wire locked, clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
	.locked(locked)
);


/////////////////////   SDRAM   ///////////////////
//
// Helper functionality:
//    SDRAM and DDR3 RAM are being cleared while this core is working.
//    some cores behave incorrectly if started with non-clean RAM.

sdram sdr
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.addr(sdram_addr),
	.wtbt(3),
	.dout(sdram_dout),
	.din(sdram_din),
	.rd(sdram_rd),
	.we(sdram_we),
	.ready(sdram_ready)
);

reg  [26:0] sdram_addr;
wire        sdram_ready;
wire [15:0] sdram_dout;
reg  [15:0] sdram_din;
reg         sdram_we;
reg         sdram_rd;
reg  [15:0] cfg = 0;

always @(posedge clk_sys) begin
	reg [4:0] state = 0;

	sdram_rd <= 0;
	sdram_we <= 0;

	if(RESET) begin
		state <= 0;
		cfg <= 0;
	end
	else begin
		case(state)
			0: if(sdram_ready) begin
					cfg <= 0;
					state      <= state+1'd1;
				end
			1: begin
					sdram_addr <= 'h4000000;
					sdram_din  <= 3128;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			2: state <= state+1'd1;
			3: if(sdram_ready) begin
					sdram_addr <= 'h2000000;
					sdram_din  <= 2064;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			4: state <= state+1'd1;
			5: if(sdram_ready) begin
					sdram_addr <= 'h0000000;
					sdram_din  <= 1032;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			6: state <= state+1'd1;
			7: if(sdram_ready) begin
					sdram_addr <= 'h1000000;
					sdram_din  <= 12345;
					sdram_we   <= 1;
					state      <= state+1'd1;
				end
			8: state <= state+1'd1;
			9: if(sdram_ready) begin
					sdram_addr <= 'h4000000;
					sdram_rd   <= 1;
					state      <= state+1'd1;
				end
			10: state <= state+1'd1;
			11: if(sdram_ready) begin
					cfg[2]     <= (sdram_dout == 3128);
					sdram_addr <= 'h2000000;
					sdram_rd   <= 1;
					state      <= state+1'd1;
				end
			12: state <= state+1'd1;
			13: if(sdram_ready) begin
					cfg[1]     <= (sdram_dout == 2064);
					sdram_addr <= 'h0000000;
					sdram_rd   <= 1;
					state      <= state+1'd1;
				end
			14: state <= state+1'd1;
			15: if(sdram_ready) begin
					cfg[0]     <= (sdram_dout == 1032);
					cfg[15]    <= 1;
					state      <= state+1'd1;
				end
			16: begin
					sdram_addr <= addr[24:0];
					sdram_din  <= 0;
					sdram_we   <= we;
				end
		endcase
	end
end

ddram ddr
(
	.*,
	.reset(RESET),
   .dout(),
   .din(0),
   .rd(0),
   .ready()
);

reg        we;
reg [28:0] addr = 0;

always @(posedge clk_sys) begin
	reg [4:0] cnt = 9;

	if(~RESET & cfg[15]) begin
		cnt <= cnt + 1'b1;
		we <= &cnt;
		if(cnt == 8) addr <= addr + 1'd1;
	end
end


/////////////////////   VIDEO   ///////////////////

wire PAL = status[4];
wire FB  = status[5];
wire [2:0] led = status[8:6];

reg   [9:0] hc;
reg   [9:0] vc;
reg   [9:0] vvc;
reg  [63:0] rnd_reg;

wire  [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};
wire [63:0] rnd;

lfsr random(rnd);

always @(posedge CLK_VIDEO) begin
	if(forced_scandoubler) ce_pix <= 1;
		else ce_pix <= ~ce_pix;

	if(ce_pix) begin
		if(hc == 637) begin
			hc <= 0;
			if(vc == (PAL ? (forced_scandoubler ? 623 : 311) : (forced_scandoubler ? 523 : 261))) begin 
				vc <= 0;
				vvc <= vvc + 9'd6;
			end else begin
				vc <= vc + 1'd1;
			end
		end else begin
			hc <= hc + 1'd1;
		end

		rnd_reg <= rnd;
	end
end

reg HBlank;
reg HSync;
reg VBlank;
reg VSync;

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	if (hc == 529) HBlank <= 1;
		else if (hc == 0) HBlank <= 0;

	if (hc == 544) begin
		HSync <= 1;

		if(PAL) begin
			if(vc == (forced_scandoubler ? 609 : 304)) VSync <= 1;
				else if (vc == (forced_scandoubler ? 617 : 308)) VSync <= 0;

			if(vc == (forced_scandoubler ? 601 : 300)) VBlank <= 1;
				else if (vc == 0) VBlank <= 0;
		end
		else begin
			if(vc == (forced_scandoubler ? 490 : 245)) VSync <= 1;
				else if (vc == (forced_scandoubler ? 496 : 248)) VSync <= 0;

			if(vc == (forced_scandoubler ? 480 : 240)) VBlank <= 1;
				else if (vc == 0) VBlank <= 0;
		end
	end
	
	if (hc == 590) HSync <= 0;
end

reg  [7:0] cos_out;
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(vvc + {vc>>forced_scandoubler, 2'b00}, cos_out);

wire [7:0] comp_v = (cos_g >= rnd_c) ? {cos_g - rnd_c, 2'b00} : 8'd0;

assign VGA_DE  = ~(HBlank | VBlank);
assign VGA_HS  = HSync;
assign VGA_VS  = VSync;
assign VGA_G   = comp_v;
assign VGA_R   = comp_v;
assign VGA_B   = comp_v;

endmodule
