`include "globals.v"

module led_matrix #(
    parameter N_COLS        = 18,
    parameter N_ROWS        = 7,
    parameter ADDRESS_WIDTH = 16,
    parameter DATA_WIDTH    = 8,
    parameter DATA_BYTES    = 1,
    parameter BASE_ADDRESS  = 0,
    parameter MAX_WAIT      = 8
)  (
    // Wishbone interface
    input wire                      rst_i,
    input wire                      clk_i,

    input wire [ADDRESS_WIDTH-1:0]  adr_i,
    input wire [DATA_WIDTH-1:0]     dat_i,
    output reg [DATA_WIDTH-1:0]     dat_o,
    input wire                      we_i,
    input wire [DATA_BYTES-1:0]     sel_i,
    input wire                      stb_i,
    input wire                      cyc_i,
    output reg                      ack_o,
    input wire [2:0]                cti_i,

    // Wishbone master
    output wire [ADDRESS_WIDTH-1:0] frame_adr_o,
    input wire [DATA_WIDTH-1:0]     frame_dat_i,
    output wire [DATA_WIDTH-1:0]    frame_dat_o,
    output wire                     frame_we_o,
    output wire [DATA_BYTES-1:0]    frame_sel_o,
    output wire                     frame_stb_o,
    input wire                      frame_cyc_i,
    output wire                     frame_cyc_o,
    input wire                      frame_ack_i,
    output wire [2:0]               frame_cti_o,
    
    // LED Drive Out
    output wire                     shift_reset,
    output wire                     shift_clock,
    output reg [N_COLS-1:0]         led_out
    );

    // alias so it's easier to type
    wire       clk;
    wire       rst;
    assign clk = clk_i;
    assign rst = rst_i;
    

    // control registers
    reg [15:0] frame_address;
    reg [7:0]  global_brightness;
    reg        enabled;
    
    
    //===========================================================================================
    // Wishbone slave
    reg        valid_address;
    
    wire       address_in_range;
    wire [3:0] local_address;
    assign address_in_range = (adr_i & 16'hFFF0) == BASE_ADDRESS;
    assign local_address = address_in_range ? adr_i[3:0] : 4'hF;
    wire       masked_cyc = (address_in_range & cyc_i);
    
    
    always @(posedge clk_i) begin
        ack_o <= cyc_i & valid_address;
    end
    
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            frame_address     <= `DEFAULT_FRAME_ADDRESS;
            enabled           <= 1;
            global_brightness <= 8'hFF;
        end
        else begin
            if (masked_cyc & we_i) begin
                if      (local_address == `MATRIX_CONTROL    ) { enabled } <= dat_i[0];
                else if (local_address == `MATRIX_BRIGHTNESS ) { global_brightness } <= dat_i;
                else if (local_address == `MATRIX_ADDR_L     ) { frame_address[7:0] } <= dat_i;
                else if (local_address == `MATRIX_ADDR_H     ) { frame_address[15:8] } <= dat_i;
            end
        end
    end


    always @(*) begin
        if (~masked_cyc) valid_address = 0;
        else if (local_address == `MATRIX_CONTROL    ) begin  valid_address = 1;  dat_o = { 7'd0, enabled }; end
        else if (local_address == `MATRIX_BRIGHTNESS ) begin  valid_address = 1;  dat_o = { global_brightness }; end
        else if (local_address == `MATRIX_ADDR_L     ) begin  valid_address = 1;  dat_o = { frame_address[7:0] }; end
        else if (local_address == `MATRIX_ADDR_H     ) begin  valid_address = 1;  dat_o = { frame_address[15:8] }; end
        else begin 
            valid_address = 0;
            dat_o = 0;
        end
    end

    //===========================================================================================
    // Wishbone Master - Pixel Reader
    localparam MAX_PAYLOAD = 2;
    localparam INTERFACE_WIDTH = 2 * DATA_WIDTH;
    
    reg [ADDRESS_WIDTH-1:0]      pixel_address;
    wire [INTERFACE_WIDTH-1:0]   payload_in;
    wire [INTERFACE_WIDTH-1:0]   payload_out;
    reg [1:0]                    payload_length;
    reg                          start_read;
    wire                         read_busy;
    reg                          start_write;
    wire                         write_busy;
    wire                         completed;
    wire                         timeout;

    // housekeeping to make arrays
    reg [DATA_WIDTH-1:0] data_out [0:MAX_PAYLOAD-1];
    wire [DATA_WIDTH-1:0] data_in  [0:MAX_PAYLOAD-1];
    genvar                i;
    generate
        for(i = 1; i <= MAX_PAYLOAD; i = i+1) begin
            assign payload_in[(i*DATA_WIDTH)-1:((i-1)*DATA_WIDTH)] = data_out[i-1];
            assign data_in[i-1] = payload_out[(i*DATA_WIDTH)-1:((i-1)*DATA_WIDTH)];
        end
    endgenerate

    wishbone_master #(
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .DATA_BYTES    (DATA_BYTES),
        .MAX_WAIT      (MAX_WAIT),
        .MAX_PAYLOAD   (2)
    ) wb_master (
        // Wishbone interface
        .rst_i           ( rst_i          ),
        .clk_i           ( clk_i          ),
        .adr_o           ( frame_adr_o    ),
        .dat_i           ( frame_dat_i    ),
        .dat_o           ( frame_dat_o    ),
        .we_o            ( frame_we_o     ),
        .sel_o           ( frame_sel_o    ),
        .stb_o           ( frame_stb_o    ),
        .cyc_i           ( frame_cyc_i    ),
        .cyc_o           ( frame_cyc_o    ),
        .ack_i           ( frame_ack_i    ),
        .cti_o           ( frame_cti_o    ),

        // packet interface
        .transfer_address( pixel_address  ),
        .payload_in      ( 0              ),
        .payload_out     ( payload_out    ),
        .payload_length  ( 2              ),
        .start_read      ( start_read     ),
        .read_busy       ( read_busy      ),
        .start_write     ( 0              ),
        .write_busy      ( 0              ),
        .completed       ( completed      ),
        .timeout         ( timeout        )
    );

    ////===========================================================================================
    //// Nonlinear lookup
    //
    //
    //reg [7:0] brightness_lut_address;
    //reg [15:0] brightness_lut_out;
    //
    //reg [PIXEL_TIMER_SIZE-1:0]  brightness_lut_mem [256:0];
    //
    //initial begin
    //    $readmemh("./brightness_lut_rom.txt", brightness_lut_mem);
    //end
    //
    //always @(posedge clk) begin
    //    brightness_lut_out <= brightness_lut_mem[brightness_lut_address];
    //end
    //
    //
    ////===========================================================================================
    //// The matrix display
    //localparam N_COLS_SIZE = (N_COLS < 4 ? 2 :
    //                          N_COLS < 8 ? 3 :
    //                          N_COLS < 16 ? 4 :
    //                          N_COLS < 32 ? 5 : 6);
    //
    //reg [PIXEL_TIMER_SIZE-1:0] line_timer;
    //reg [PIXEL_TIMER_SIZE-1:0] pixel_timers [0:N_COLS-1];
    //reg [1:0]                  current_field;
    //reg [N_COLS_SIZE-1:0]      pixel_being_update;
    //
    //integer i;
    //
    //always @(posedge clk or posedge rst) begin
    //    if (rst) begin
    //        line_timer <= 0;
    //        for (i = 0; i < N_COLS; i = i+1) pixel_timer[i] <= 0;
    //    end
    //    else begin
    //        if (line_timer) begin
    //            line_timer <= line_timer - 1;
    //            for (i = 0; i < N_COLS; i = i+1) begin
    //                if (pixel_timer[i]) begin  pixel_timer[i] <= pixel_timer[i]-1;  led_out <= 1;  end
    //                else led_out <= 0;
    //            end
    //            
    //            pixel_being_update <= 1;
    //        end
    //        else begin // new line
    //            
    //
    //            
    //        end
    //    end
    //end
    
    
    
endmodule
