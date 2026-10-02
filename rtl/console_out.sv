// 32bpp frame buffer shown 1:1, centered, when it fits the 640 pixels wide output.

module console_out
(
	input             clk_sys,
	input             ddr_grant,
	output reg [28:0] ddr_addr,
	output reg  [7:0] ddr_burst,
	output reg        ddr_rd = 0,
	input             ddr_busy,
	input      [63:0] ddr_dout,
	input             ddr_dout_ready,
	output            ddr_idle,

	input       [5:0] fb_fmt,
	input      [31:0] fb_base,
	input      [11:0] fb_width,
	input      [11:0] fb_height,
	input      [13:0] fb_stride,

	input             clk_vid,
	input             ce_pix,
	input             show,
	input       [9:0] hc,
	input       [9:0] vc,
	input       [9:0] height,
	output reg [23:0] rgb,
	output reg        active = 0
);

localparam WIDTH = 640;
localparam BURST = 32;

reg  [5:0] fmt;
reg [11:0] w, h;
reg  [9:0] out_h, cols, lines, left, top;
reg  [1:0] show_s = 0;

always @(posedge clk_vid) begin
	fmt    <= fb_fmt;
	w      <= fb_width;
	h      <= fb_height;
	out_h  <= height;
	cols   <= w[9:0];
	lines  <= h[9:0];
	left   <= (WIDTH[9:0] - cols) >> 1;
	top    <= (out_h - lines) >> 1;
	show_s <= {show_s[0], show};
	active <= show_s[1] && fmt[2:0] == 3'b110 && w && h && w <= WIDTH && h <= out_h;
end

reg       req_t = 0;
reg [9:0] req_line;
reg       req_bank;

always @(posedge clk_vid) begin
	reg [9:0] ny;

	if(ce_pix && !hc && active && (vc + 1'd1 < out_h || vc == out_h)) begin
		ny = (vc == out_h) ? 10'd0 : vc + 1'd1;
		if(ny >= top && ny - top < lines) begin
			req_line <= ny - top;
			req_bank <= ny[0];
			req_t    <= ~req_t;
		end
	end
end

reg  [2:0] req_s = 0;
reg  [1:0] start = 0;
reg        fetch = 0;
reg  [9:0] line;
reg        bank, wbank;
reg [23:0] offset;
reg  [8:0] words, waddr;
reg  [7:0] beats = 0;
reg        bwe = 0;
reg  [9:0] baddr;
reg [63:0] bdata;

assign ddr_idle = ~fetch & ~|start & ~ddr_rd;

always @(posedge clk_sys) begin
	reg [31:0] laddr;

	req_s <= {req_s[1:0], req_t};
	bwe   <= 0;

	if(ddr_rd && !ddr_busy) begin
		ddr_rd   <= 0;
		ddr_addr <= ddr_addr + ddr_burst;
	end

	if(ddr_dout_ready && fetch && beats) begin
		bwe   <= 1;
		baddr <= {wbank, waddr};
		bdata <= ddr_dout;
		waddr <= waddr + 1'd1;
		beats <= beats - 1'd1;
	end

	case(start)
		0: if(!fetch && req_s[2] != req_s[1] && ddr_grant) begin
				line  <= req_line;
				bank  <= req_bank;
				start <= 1;
			end
		1: begin
				offset <= line * fb_stride;
				start  <= 2;
			end
		2: begin
				laddr    = fb_base + offset;
				ddr_addr <= laddr[31:3];
				wbank    <= bank;
				waddr    <= 0;
				words    <= (cols + 1'd1) >> 1;
				fetch    <= 1;
				start    <= 0;
			end
	endcase

	if(fetch && !start && !ddr_rd && !beats && ddr_grant) begin
		if(!words) fetch <= 0;
		else begin
			ddr_burst <= (words > BURST) ? BURST[7:0] : words[7:0];
			beats     <= (words > BURST) ? BURST[7:0] : words[7:0];
			words     <= (words > BURST) ? words - BURST[8:0] : 9'd0;
			ddr_rd    <= 1;
		end
	end
end

reg [63:0] buffer[1024];
always @(posedge clk_sys) if(bwe) buffer[baddr] <= bdata;

reg [63:0] q;
reg        hi, shown;

always @(posedge clk_vid) begin
	reg  [9:0] sx;
	reg [31:0] p;

	sx     = hc - left;
	q     <= buffer[{vc[0], sx[9:1]}];
	hi    <= sx[0];
	shown <= active && hc >= left && sx < cols && vc >= top && vc - top < lines;

	p = hi ? q[63:32] : q[31:0];
	if(!shown)      rgb <= 0;
	else if(fmt[4]) rgb <= p[23:0];
	else            rgb <= {p[7:0], p[15:8], p[23:16]};
end

endmodule
