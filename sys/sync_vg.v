module sync_vg
#(
	parameter X_BITS=12, Y_BITS=12
)
(
	input wire clk,
	input wire reset,

	input wire [Y_BITS-1:0] v_total,
	input wire [Y_BITS-1:0] v_fp,
	input wire [Y_BITS-1:0] v_bp,
	input wire [Y_BITS-1:0] v_sync,
	input wire [X_BITS-1:0] h_total,
	input wire [X_BITS-1:0] h_fp,
	input wire [X_BITS-1:0] h_bp,
	input wire [X_BITS-1:0] h_sync,

	output reg vs_out,
	output reg hs_out,
	output reg hde_out,
	output reg vde_out,
	output reg [X_BITS-1:0] x_out,
	output reg [Y_BITS-1:0] y_out
);


reg [X_BITS-1:0] htotal,hbp,hfp,hsync;
reg [Y_BITS-1:0] vtotal,vbp,vfp,vsync;
always @(posedge clk) begin
	vtotal <= v_total - 1'd1;
	vsync <= v_sync - 1'd1;
	vbp <= vsync  + v_bp;
	vfp <= vtotal - v_fp;

	htotal <= h_total - 1'd1;
	hsync <= h_sync - 1'd1;
	hbp <= hsync  + h_bp;
	hfp <= htotal - h_fp;
end


reg [X_BITS-1:0] hcount;
reg [Y_BITS-1:0] vcount;
always @(posedge clk) begin
	reg [X_BITS-1:0] h_count;
	reg [Y_BITS-1:0] v_count;

	h_count <= h_count + 1'd1;
	if (h_count == htotal) begin
		h_count <= 0;
		v_count <= v_count + 1'd1;
		if (v_count == vtotal) v_count <= 0;
	end
	
	hcount <= h_count;
	vcount <= v_count;
end


reg [X_BITS-1:0] x;
reg [Y_BITS-1:0] y;
reg hs,hde;
reg vs,vde;
always @(posedge clk) begin
	if(hcount == htotal) hs <= 1;
	if(hcount == hsync)  hs <= 0;
	if(hcount == hbp)    hde <= 1;
	if(hde)              x <= hcount - hbp;
	if(hcount == hfp)    {hde,x} <= 0;

	if(vcount == vtotal) vs <= 1;
	if(vcount == vsync)  vs <= 0;
	if(vcount == vbp)    vde <= 1;
	if(vde)              y <= vcount - vbp;
	if(vcount == vfp)    {vde,y} <= 0;
end

always @(posedge clk) {vs_out,hs_out,hde_out,vde_out,x_out,y_out} <= {vs,hs,hde,vde,x,y};

endmodule
