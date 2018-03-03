module pattern_vg
#(
	parameter B=8, // number of bits per channel
	X_BITS=13,
	Y_BITS=13
)

(
	input              reset, clk_in,
	input [X_BITS-1:0] x,
	input [Y_BITS-1:0] y,
	input              vn_in, hn_in, dn_in,
	output reg         vn_out, hn_out, den_out,
	output reg [B-1:0] r_out, g_out, b_out,
	input [X_BITS-1:0] total_active_pix,
	input [Y_BITS-1:0] total_active_lines,
	input        [2:0] pattern
);
	
reg [Y_BITS+2:0] bar;
reg [X_BITS+7:0] ramp;
reg [X_BITS+9:0] cosx;

wire [63:0] rnd;
reg   [5:0] rnd_reg;
wire  [5:0] rnd_c = {rnd[0],rnd[1],rnd[2],rnd[2],rnd[2],rnd[2]};
wire  [7:0] cos_out;
reg   [5:0] cos_g;

lfsr random(rnd);
cos cos(cosx[9:0], cos_out);

wire [7:0] noise = (cos_g >= rnd_reg) ? {cos_g - rnd_reg, 2'b00} : 8'd0;

reg [9:0] vvc = 0;
always @(negedge clk_in) begin
	reg div;
	reg [Y_BITS-1:0] x1;
	reg [X_BITS-1:0] y1;

	div <= ~div;
	
	if(!div) begin
		x1 <= x;
		y1 <= y;
		if(pattern[0]) begin
			bar <= ~den_out ? 1'b0 : {y1,3'b000}/total_active_lines;
			ramp <= {x1,8'h00}/total_active_pix;
		end else begin
			bar <= ~den_out ? 1'b0 : {x1,3'b000}/total_active_pix;
			ramp <= ~({y1,8'h00}/total_active_lines);
		end
	end

	cosx <= vvc + ({y,10'd0}/total_active_lines);
end

always @(posedge clk_in) begin
	if(!x && !y && dn_in) vvc <= vvc + 9'd6;
	if(!x) cos_g <= {1'b1, cos_out[7:3]};

	if(x[1:0] == 0) rnd_reg <= rnd_c;

	vn_out <= vn_in;
	hn_out <= hn_in;
	den_out <= dn_in;
	
	case(pattern)
		// TV noise
		0: if(&x[1:0]) begin
				r_out <= noise;
				g_out <= noise;
				b_out <= noise;
			end

		// black
		1:	begin
				r_out <= 0;
				g_out <= 0;
				b_out <= 0;
			end

		// border
		2: if (dn_in && ((y == 12'b0) || (x == 12'b0) || (x == total_active_pix - 1) || (y == total_active_lines - 1)))
			begin
				r_out <= 8'hFF;
				g_out <= 8'hFF;
				b_out <= 8'hFF;
			end
			else
			if (dn_in && ((y == 12'b0+20) || (x == 12'b0+20) || (x == total_active_pix - 1 - 20) || (y == total_active_lines - 1 - 20)))
			begin
				r_out <= 8'h80;
				g_out <= 8'h80;
				b_out <= 8'h80;
			end
			else
			begin
				r_out <= 0;
				g_out <= 0;
				b_out <= 0;
			end

		// stripes
		3:	if ((dn_in) && y[2])
			begin
				r_out <= 8'h80;
				g_out <= 8'h80;
				b_out <= 8'h80;
			end
			else
			begin
				r_out <= 8'hC0;
				g_out <= 8'hC0;
				b_out <= 8'hC0;
			end

		// Simple RAMPs
		4,5: begin
				r_out <= (bar[0]) ? ramp[7:0] : 8'h00;
				g_out <= (bar[1]) ? ramp[7:0] : 8'h00;
				b_out <= (bar[2]) ? ramp[7:0] : 8'h00;
			end

	endcase
end

endmodule
