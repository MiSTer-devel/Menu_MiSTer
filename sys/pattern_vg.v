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
	input              vs_in, hs_in, de_in,
	output reg         vs_out, hs_out, de_out,
	output reg [B-1:0] r, g, b,
	input [X_BITS-1:0] width,
	input [Y_BITS-1:0] height,
	input        [2:0] pattern
);
	
reg [Y_BITS-1:0] ramp_y;
reg [X_BITS-1:0] ramp_x;
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
always @(posedge clk_in) cosx <= vvc + ({y,10'd0}/height);

always @(posedge clk_in) begin
	reg [X_BITS-1:0] acc_x,step_x,add_x;
	reg [Y_BITS-1:0] acc_y,step_y,add_y;
	reg old_hs;

	if(vs_in) begin
		add_x <= pattern[1] ? 10'd14 : 10'd255;
		add_y <= pattern[1] ? 10'd255 : 10'd14;
	end

	ramp_x <= step_x;
	ramp_y <= step_y;

	acc_x = acc_x + add_x;
	if(acc_x >= width) begin
		acc_x = acc_x - width;
		step_x <= step_x + 1'd1;
	end

	if(!x) begin
		acc_x = 0;
		step_x <= 0;
		ramp_x <= 0;
	end

	old_hs <= hs_in;
	if(old_hs & ~hs_in) begin
		acc_y = acc_y + add_y;
		if(acc_y >= height) begin
			acc_y = acc_y - height;
			step_y <= step_y + 1'd1;
		end

		if(!y) begin
			acc_y = 0;
			step_y <= 0;
			ramp_y <= 0;
		end
	end
end

wire [X_BITS-1:0] inv_ramp_x = 8'd13 - ramp_x;
wire [Y_BITS-1:0] inv_ramp_y = 8'd13 - ramp_y;

always @(posedge clk_in) begin
	if(!x && !y && de_in) vvc <= vvc + 9'd6;
	if(!x) cos_g <= {1'b1, cos_out[7:3]};

	if(x[1:0] == 0) rnd_reg <= rnd_c;

	vs_out <= vs_in;
	hs_out <= hs_in;
	de_out <= de_in;
	
	case(pattern)
		// TV noise
		0: if(&x[1:0]) begin
				r <= noise;
				g <= noise;
				b <= noise;
			end

		// black
		1:	begin
				r <= 0;
				g <= 0;
				b <= 0;
			end

		// border
		2: if (de_in && ((y == 12'b0) || (x == 12'b0) || (x == width - 1) || (y == height - 1)))
			begin
				r <= 8'hFF;
				g <= 8'hFF;
				b <= 8'hFF;
			end
			else
			if (de_in && ((y == 12'b0+20) || (x == 12'b0+20) || (x == width - 1 - 20) || (y == height - 1 - 20)))
			begin
				r <= 8'h80;
				g <= 8'h80;
				b <= 8'h80;
			end
			else
			begin
				r <= 0;
				g <= 0;
				b <= 0;
			end

		// stripes
		3:	if ((de_in) && y[2])
			begin
				r <= 8'h80;
				g <= 8'h80;
				b <= 8'h80;
			end
			else
			begin
				r <= 8'hC0;
				g <= 8'hC0;
				b <= 8'hC0;
			end

		4: begin
				if(~ramp_y[0]) begin
					r <= ramp_y[1] ? 8'h00 : ramp_x[7:0];
					g <= ramp_y[2] ? 8'h00 : ramp_x[7:0];
					b <= ramp_y[3] ? 8'h00 : ramp_x[7:0];
				end
				else begin
					r <= inv_ramp_y[1] ? 8'h00 : ~ramp_x[7:0];
					g <= inv_ramp_y[2] ? 8'h00 : ~ramp_x[7:0];
					b <= inv_ramp_y[3] ? 8'h00 : ~ramp_x[7:0];
				end
			end

		5: begin
				r <= ramp_y[1] ? 8'h00 : ~ramp_x[7:0];
				g <= ramp_y[2] ? 8'h00 : ~ramp_x[7:0];
				b <= ramp_y[3] ? 8'h00 : ~ramp_x[7:0];
			end

		6: begin
				if(~ramp_x[0]) begin
					r <= ramp_x[1] ? 8'h00 : ramp_y[7:0];
					g <= ramp_x[2] ? 8'h00 : ramp_y[7:0];
					b <= ramp_x[3] ? 8'h00 : ramp_y[7:0];
				end
				else begin
					r <= inv_ramp_x[1] ? 8'h00 : ~ramp_y[7:0];
					g <= inv_ramp_x[2] ? 8'h00 : ~ramp_y[7:0];
					b <= inv_ramp_x[3] ? 8'h00 : ~ramp_y[7:0];
				end
			end

		7: begin
				r <= ramp_x[1] ? 8'h00 : ~ramp_y[7:0];
				g <= ramp_x[2] ? 8'h00 : ~ramp_y[7:0];
				b <= ramp_x[3] ? 8'h00 : ~ramp_y[7:0];
			end
	endcase
end

endmodule
