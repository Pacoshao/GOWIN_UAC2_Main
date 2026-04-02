module usb_audio_pwm_player #(
    parameter FIFO_DEPTH = 1024
) (
    input              clk,
    input              reset,
    input              i_audio_dval,
    input      [7:0]   i_audio_data,
    input      [31:0]  i_sample_rate,
    input      [7:0]   i_rx_data_bits,
    input              i_mute,
    output reg         o_fifo_alempty,
    output reg         o_fifo_alfull,
    output             o_pwm
);

localparam CLK_HZ = 60_000_000;
localparam PTR_W  = 10;

reg [7:0] fifo_mem [0:FIFO_DEPTH-1];
reg [PTR_W-1:0] wr_ptr;
reg [PTR_W-1:0] rd_ptr;
reg [10:0] fifo_count;

wire fifo_full  = (fifo_count == FIFO_DEPTH);
wire fifo_empty = (fifo_count == 0);

wire [3:0] frame_bytes = (i_rx_data_bits == 8'd24) ? 4'd6 :
                         (i_rx_data_bits == 8'd32) ? 4'd8 : 4'd4;

reg [31:0] phase_acc;
wire [63:0] phase_step_wide = (i_sample_rate == 32'd0) ? 64'd0 : (({32'd0, i_sample_rate} << 32) / CLK_HZ);
wire [31:0] phase_step = phase_step_wide[31:0];
wire sample_event = (phase_acc[31] == 1'b0) && ((phase_acc + phase_step)[31] == 1'b1);
wire can_read = (fifo_count >= frame_bytes);
wire do_read = sample_event && can_read;
wire do_write = i_audio_dval && !fifo_full;

reg [7:0] sample_u8;
reg [7:0] pwm_cnt;

wire [PTR_W-1:0] rd1 = rd_ptr + 1'b1;
wire [PTR_W-1:0] rd2 = rd_ptr + 2'd2;
wire [PTR_W-1:0] rd3 = rd_ptr + 2'd3;

wire [7:0] duty = i_mute ? 8'h80 : sample_u8;
assign o_pwm = (pwm_cnt < duty);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        wr_ptr <= {PTR_W{1'b0}};
        rd_ptr <= {PTR_W{1'b0}};
        fifo_count <= 11'd0;
        phase_acc <= 32'd0;
        sample_u8 <= 8'h80;
        pwm_cnt <= 8'd0;
        o_fifo_alempty <= 1'b1;
        o_fifo_alfull <= 1'b0;
    end else begin
        pwm_cnt <= pwm_cnt + 1'b1;

        phase_acc <= phase_acc + phase_step;
        if (sample_event) begin
            if (can_read) begin
                if (frame_bytes == 4) begin
                    sample_u8 <= fifo_mem[rd1];
                    rd_ptr <= rd_ptr + 4'd4;
                end else if (frame_bytes == 6) begin
                    sample_u8 <= fifo_mem[rd2];
                    rd_ptr <= rd_ptr + 4'd6;
                end else begin
                    sample_u8 <= fifo_mem[rd3];
                    rd_ptr <= rd_ptr + 4'd8;
                end
            end else begin
                sample_u8 <= 8'h80;
            end
        end

        if (i_audio_dval && !fifo_full) begin
            fifo_mem[wr_ptr] <= i_audio_data;
            wr_ptr <= wr_ptr + 1'b1;
        end

        if (do_read && do_write) begin
            if (frame_bytes == 4) begin
                fifo_count <= fifo_count - 4'd4 + 1'b1;
            end else if (frame_bytes == 6) begin
                fifo_count <= fifo_count - 4'd6 + 1'b1;
            end else begin
                fifo_count <= fifo_count - 4'd8 + 1'b1;
            end
        end else if (do_read) begin
            if (frame_bytes == 4) begin
                fifo_count <= fifo_count - 4'd4;
            end else if (frame_bytes == 6) begin
                fifo_count <= fifo_count - 4'd6;
            end else begin
                fifo_count <= fifo_count - 4'd8;
            end
        end else if (do_write) begin
            fifo_count <= fifo_count + 1'b1;
        end

        o_fifo_alempty <= (fifo_count < {7'd0, frame_bytes} + 11'd16);
        o_fifo_alfull <= (fifo_count > (FIFO_DEPTH - 64));
    end
end

endmodule
