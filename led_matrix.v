`include "globals.v"

module led_matrix #(
    parameter N_COLS          = 18,
    parameter N_ROWS          = 7,
    parameter ADDRESS_WIDTH   = 16,
    parameter DATA_WIDTH      = 8,
    parameter DATA_BYTES      = 1,
    parameter BASE_ADDRESS    = 0,
    parameter MAX_WAIT        = 8,
    parameter SHIFT_CLOCK_PERIOD = 32,
    parameter TOTAL_LOAD_TIME = MAX_WAIT * N_COLS / 2,
    parameter TOTAL_LINE_TIME = 16'h1000 // don't forget to update for the maximum PWM time
                    
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
    output wire                     shift_1st_line,
    output wire                     shift_clock,
    output wire [N_COLS-1:0]        led_out
    );

    reg [N_COLS-1:0] led_out_state;
    
    // alias so it's easier to type
    wire       clk;
    wire       rst;
    assign clk = clk_i;
    assign rst = rst_i;
    

    // control registers
    reg [15:0] frame_address;
    reg [7:0]  global_brightness;
    reg        enabled;

    reg [3:0]        local_clock_div = 0;
    reg              local_clk = 0;
    always @(posedge clk) begin
        if (local_clock_div) local_clock_div <= local_clock_div - 1;
        else begin
            local_clock_div <= 5;
            local_clk       <= ~local_clk;
        end
    end
    
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
        if (~masked_cyc) begin valid_address = 0; dat_o = 0; end
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
    localparam INTERFACE_WIDTH = 3 * DATA_WIDTH;
    
    reg [ADDRESS_WIDTH-1:0]      pixel_address = 0;
    wire [INTERFACE_WIDTH-1:0]   payload_out;
    reg                          start_read = 0;
    wire                         read_busy;
    wire                         completed;
    wire                         timeout;

    wishbone_master #(
        .ADDRESS_WIDTH (ADDRESS_WIDTH),
        .DATA_WIDTH    (DATA_WIDTH),
        .DATA_BYTES    (DATA_BYTES),
        .MAX_WAIT      (MAX_WAIT),
        .MAX_PAYLOAD   (3)
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
        .payload_length  ( 3              ),
        .start_read      ( start_read     ),
        .read_busy       ( read_busy      ),
        .start_write     ( 0              ),
        .write_busy      (                ),
        .completed       ( completed      ),
        .timeout         ( timeout        )
    );
    
    localparam FIELD_RED   = 3'b001;
    localparam FIELD_GREEN = 3'b010;
    localparam FIELD_BLUE  = 3'b100;
    reg [2:0] current_field = FIELD_RED;
    reg [2:0] last_field = FIELD_RED;
    
    //===========================================================================================
    // Select component

    // this both grabs the component of the 565 encoded value as well as
    // prepending it with the offset into the LUT for the field region
    reg [7:0] field_lut_addr = 0;
    always @(*) begin
        case (last_field)
        FIELD_RED:   field_lut_addr = { 2'b00, payload_out[4:0], 1'b0 };
        FIELD_GREEN: field_lut_addr = { 2'b01, payload_out[10:5] };
        FIELD_BLUE:  field_lut_addr = { 2'b10, payload_out[15:11], 1'b0 };
        default: field_lut_addr     = 6'd0;
        endcase
    end
    
    //===========================================================================================
    // Nonlinear lookup
    localparam PIXEL_TIMER_SIZE = 16;
    reg [15:0] brightness_lut_out;
    
    reg [PIXEL_TIMER_SIZE-1:0]  brightness_lut_mem [255:0];
    
    initial begin
        $readmemh("./brightness_lut_rom.txt", brightness_lut_mem);
    end
    
    always @(posedge clk) begin
        brightness_lut_out <= brightness_lut_mem[field_lut_addr];
    end
    
    
    //===========================================================================================
    // The matrix display
    localparam N_COLS_SIZE = (N_COLS < 4 ? 2 :
                              N_COLS < 8 ? 3 :
                              N_COLS < 16 ? 4 :
                              N_COLS < 32 ? 5 : 6);
    localparam N_ROWS_SIZE = (N_ROWS < 2 ? 1 :
                              N_ROWS < 4 ? 2 :
                              N_ROWS < 8 ? 3 :
                              N_ROWS < 16 ? 4 :
                              N_ROWS < 32 ? 5 : 6);
    
    reg [PIXEL_TIMER_SIZE-1:0] line_timer = 0;
    reg [PIXEL_TIMER_SIZE-1:0] load_timer = 0;
    reg [PIXEL_TIMER_SIZE-1:0] pixel_timers [0:N_COLS-1];
    reg [PIXEL_TIMER_SIZE+1-1:0] pixel_accum [0:N_COLS-1];
    reg [N_ROWS_SIZE-1:0]      current_row = 0;
    reg [15:0]                 row_address_offset = 0;
    reg [N_COLS_SIZE-1:0]      pixel_being_updated = 0;

    reg [5:0]                  load_state = 5'b00001;
    localparam LOAD_STATE_INC_LINE          = 5'b00001;
    localparam LOAD_STATE_START_REQUEST     = 5'b00010;
    localparam LOAD_STATE_COMPLETE_REQUEST  = 5'b00100;
    localparam LOAD_STATE_GET_VALUE         = 5'b01000;
    localparam LOAD_STATE_LOAD_WAIT         = 5'b10000;

    integer pdm_i;
    always @(posedge local_clk) begin
        for (pdm_i = 0; pdm_i < N_COLS; pdm_i = pdm_i+1) begin
            if (line_timer) begin
                if (pixel_accum[pdm_i] + pixel_timers[pdm_i] >= TOTAL_LINE_TIME) begin
                    pixel_accum[pdm_i]   <= pixel_accum[pdm_i] + pixel_timers[pdm_i] - TOTAL_LINE_TIME;
                    led_out_state[pdm_i] <= 1;
                end
                else begin
                    pixel_accum[pdm_i]   <= pixel_accum[pdm_i] + pixel_timers[pdm_i];
                    led_out_state[pdm_i] <= 0;
                end
            end
            else begin
                pixel_accum[pdm_i] <= TOTAL_LINE_TIME-1;
            end
        end
    end
    
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            line_timer    <= 0;
            current_field <= FIELD_RED;
            load_state    <= LOAD_STATE_INC_LINE;
            for (i = 0; i < N_COLS; i = i+1) pixel_timers[i] <= 0;
        end

        else begin
            if (line_timer) begin
                line_timer <= line_timer - 1;
                

                load_timer <= TOTAL_LOAD_TIME;
            end
            else begin // new line
                if (load_timer) load_timer <= load_timer -1;
                    
                case (load_state)
                LOAD_STATE_INC_LINE: begin
                    pixel_address       <= frame_address + row_address_offset;
                    pixel_being_updated <= 0;
                    start_read          <= 1;
                    last_field          <= current_field;

                    
                    if (current_row) begin
                        current_row        <= current_row - 1;
                        row_address_offset <= row_address_offset + (N_COLS<<1);
                    end
                    else begin
                        current_row        <= N_ROWS - 1;
                        row_address_offset <= 0;

                        case(current_field)
                        FIELD_RED: current_field   <= FIELD_GREEN;
                        
                        FIELD_GREEN: current_field <= FIELD_BLUE;
                    
                        FIELD_BLUE: current_field  <= FIELD_RED;

                        default: current_field     <= FIELD_RED;
                        endcase
                    end

                    load_state <= LOAD_STATE_START_REQUEST;
                end

                LOAD_STATE_START_REQUEST: begin
                    start_read <= 1;

                    if (read_busy) load_state <= LOAD_STATE_COMPLETE_REQUEST;
                end
                
                LOAD_STATE_COMPLETE_REQUEST: begin
                    start_read <= 0;

                    if (!read_busy) load_state <= LOAD_STATE_GET_VALUE;
                end

                LOAD_STATE_GET_VALUE: begin
                    start_read <= 0;
                    
                    for (i = 0; i < N_COLS; i = i+1) begin
                        if (i == pixel_being_updated) begin
                            pixel_timers[i] <= brightness_lut_out;
                        end
                    end

                    if (pixel_being_updated < N_COLS) begin
                        pixel_being_updated <= pixel_being_updated + 1;
                        pixel_address       <= pixel_address + 2;
                        load_state          <= LOAD_STATE_START_REQUEST;
                    end
                    else begin
                        load_state <= LOAD_STATE_LOAD_WAIT;
                    end
                end
                    
                LOAD_STATE_LOAD_WAIT: begin
                    start_read <= 0;
                    if (!load_timer) begin
                        load_state <= LOAD_STATE_INC_LINE;
                        load_timer <= TOTAL_LOAD_TIME;
                        line_timer <= TOTAL_LINE_TIME;
                    end
                end

                endcase
            end
        end
    end

    localparam SHIFT_CLOCK_COUNTER_SIZE = (SHIFT_CLOCK_PERIOD < 16 ? 4 :
                                           SHIFT_CLOCK_PERIOD < 32 ? 5 :
                                           SHIFT_CLOCK_PERIOD < 64 ? 6 :
                                           SHIFT_CLOCK_PERIOD < 128 ? 7 :
                                           SHIFT_CLOCK_PERIOD < 256 ? 8 : 9);
    reg [SHIFT_CLOCK_COUNTER_SIZE-1:0] shift_clock_counter;
    
    wire state_is_load = (load_state == LOAD_STATE_INC_LINE); // LOAD_STATE_LOAD_WAIT
    reg last_state_is_load;    
    always @(posedge clk) begin
        last_state_is_load <= state_is_load;
        
        if (state_is_load && !last_state_is_load) shift_clock_counter <= SHIFT_CLOCK_PERIOD;
        else if (shift_clock_counter) shift_clock_counter <= shift_clock_counter-1;
    end
    assign shift_clock = |shift_clock_counter;

    assign shift_1st_line = (current_row == N_ROWS - 1) && (current_field == FIELD_RED);

    assign led_out = led_out_state;

    
endmodule
