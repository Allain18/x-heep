module camera_model #(
    parameter int H_ACTIVE = 640,
    parameter int V_ACTIVE = 480,
    parameter int H_BLANK  = 16,
    parameter int V_BLANK  = 10
) (
    input logic clk_i,  // Pixel clock
    input logic rst_ni,

    output logic pclk_o,
    output logic vsync_o,
    output logic href_o,
    output logic [7:0] data_o
);

  logic [15:0] image_mem[0:H_ACTIVE*V_ACTIVE-1];

  initial begin
    $readmemh("../../../tb/image.hex", image_mem);
  end

  int x;
  int y;
  int pixel_idx;
  logic byte_sel;

  logic clk_div16;
  logic [2:0] div_cnt;

  assign pixel_idx = y * H_ACTIVE + x;


  assign pclk_o = clk_div16;

  // Clock divisor (may be remove later if dma is fast enough)
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      div_cnt   <= 3'd0;
      clk_div16 <= 1'b0;
    end else begin
      if (div_cnt == 3'd7) begin
        div_cnt   <= 3'd0;
        clk_div16 <= ~clk_div16;
      end else begin
        div_cnt <= div_cnt + 1'b1;
      end
    end
  end

  always_ff @(posedge pclk_o or negedge rst_ni) begin
    if (~rst_ni) begin
      x        <= 0;
      y        <= 0;
      byte_sel <= 0;
      href_o   <= 0;
      vsync_o  <= 1;
      data_o   <= 8'h00;
    end else begin

      //------------------------------------------
      // Frame timing
      //------------------------------------------
      if (y >= V_ACTIVE) begin
        vsync_o <= 1;
        href_o  <= 0;
      end else begin
        vsync_o <= 0;

        if (x < H_ACTIVE) href_o <= 1;
        else href_o <= 0;
      end

      //------------------------------------------
      // Pixel generation
      //------------------------------------------
      if ((y < V_ACTIVE) && (x < H_ACTIVE)) begin
        if (!byte_sel) begin
          data_o <= image_mem[pixel_idx][15:8];
        end else begin
          data_o <= image_mem[pixel_idx][7:0];
        end

        byte_sel <= ~byte_sel;

        // Advance to next pixel after two bytes
        if (byte_sel) x <= x + 1;

      end else begin
        data_o <= 8'h00;
        byte_sel <= 0;

        x <= x + 1;

        if (x == H_ACTIVE + H_BLANK - 1) begin
          x <= 0;
          y <= y + 1;

          if (y == V_ACTIVE + V_BLANK - 1) y <= 0;
        end
      end
    end
  end

endmodule
