module pattern_vg
#(
	parameter B=8, // number of bits per channel
	X_BITS=13,
	Y_BITS=13
)

(
	input reset, clk_in,
	input wire [X_BITS-1:0] x,
	input wire [Y_BITS-1:0] y,
	input wire vn_in, hn_in, dn_in,
	input wire [B-1:0] r_in, g_in, b_in,
	output reg vn_out, hn_out, den_out,
	output reg [B-1:0] r_out, g_out, b_out,
	input wire [X_BITS-1:0] total_active_pix,
	input wire [Y_BITS-1:0] total_active_lines,
	input wire [7:0] pattern
);
	
wire [Y_BITS+2:0] bar  = {y,3'b000}/total_active_lines;
wire [X_BITS+7:0] ramp = {x,8'h00}/total_active_pix;

wire [X_BITS+9:0] cosx = {y,10'd0}/total_active_lines;

wire [63:0] rnd;
reg   [5:0] rnd_reg;
wire  [5:0] rnd_c = {rnd[0],rnd[1],rnd[2],rnd[2],rnd[2],rnd[2]};
reg   [9:0] vvc;
wire  [7:0] cos_out;
reg   [5:0] cos_g;

lfsr random(rnd);
cos cos(vvc + cosx[9:0], cos_out);

wire [7:0] comp_v = (cos_g >= rnd_reg) ? {cos_g - rnd_reg, 2'b00} : 8'd0;

always @(posedge clk_in) begin

	if(!x && !y) vvc <= vvc + 9'd6;
	if(!x) cos_g <= {1'b1, cos_out[7:3]};

	if(x[1:0] == 0) rnd_reg <= rnd_c;

	vn_out <= vn_in;
	hn_out <= hn_in;
	den_out <= dn_in;

	if ((pattern == 0) && &x[1:0])
	begin
		r_out <= comp_v;
		g_out <= comp_v;
		b_out <= comp_v;
	end
	else if (pattern == 1) // border
	begin
		if (dn_in && ((y == 12'b0) || (x == 12'b0) || (x == total_active_pix - 1) || (y == total_active_lines - 1)))
		begin
			r_out <= 8'hFF;
			g_out <= 8'hFF;
			b_out <= 8'hFF;
		end
		else	// Double-border (OzOnE)...
		if (dn_in && ((y == 12'b0+20) || (x == 12'b0+20) || (x == total_active_pix - 1 - 20) || (y == total_active_lines - 1 - 20)))
		begin
			r_out <= 8'hD0;
			g_out <= 8'hB0;
			b_out <= 8'hB0;
		end
		else
		begin
			r_out <= r_in;
			g_out <= g_in;
			b_out <= b_in;
		end
	end
	else if (pattern == 2) // moireX
	begin
		if ((dn_in) && x[0] == 1'b1)
		begin
			r_out <= 8'hFF;
			g_out <= 8'hFF;
			b_out <= 8'hFF;
		end
		else
		begin
			r_out <= 8'b0;
			g_out <= 8'b0;
			b_out <= 8'b0;
		end
	end
	else if (pattern == 3) // moireY
	begin
		if ((dn_in) && y[0] == 1'b1)
		begin
			r_out <= 8'hFF;
			g_out <= 8'hFF;
			b_out <= 8'hFF;
		end
		else
		begin
			r_out <= 8'b0;
			g_out <= 8'b0;
			b_out <= 8'b0;
		end
	end
	else if (pattern == 4) // Simple RAMP
	begin
		r_out <= (bar[0]) ? ramp[7:0] : 8'h00;
		g_out <= (bar[1]) ? ramp[7:0] : 8'h00;
		b_out <= (bar[2]) ? ramp[7:0] : 8'h00;
	end
	else if(pattern == 5)
	begin
		r_out <= r_in;
		g_out <= g_in;
		b_out <= b_in;
	end
end

endmodule
