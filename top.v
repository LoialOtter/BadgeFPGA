`include "globals.v"

module top (
    input wire  pin_clk,

    inout wire  pin_usbp,
    inout wire  pin_usbn,
    output wire pin_pu,

    output wire pin_led,

    //input  wire pin_29_miso,
    //output wire pin_30_cs,
    //output wire pin_31_mosi,
    //output wire pin_32_sck,

    output wire pin_1,
    output wire pin_2,

    output wire pin_3,
    output wire pin_4,
    output wire pin_5,
    output wire pin_6,
    output wire pin_7,
    output wire pin_8,
    output wire pin_9,
    output wire pin_10,
    output wire pin_11,
    output wire pin_12,
    output wire pin_13,
    output wire pin_14,
    output wire pin_15,
    output wire pin_16,
    output wire pin_17,
    output wire pin_18,
    output wire pin_19,
    output wire pin_20,
    output wire pin_21,
    output wire pin_22,
    output wire pin_23,
    output wire pin_24,
    output wire pin_25
    );

    localparam N_COLS = 32;
    localparam N_ROWS = 7;
    
    wire [N_COLS-1:0] led_out;
    wire              led_shift_1st_line;
    wire              led_shift_clock;

    //reg [7:0]         test_counter;
    //always @(posedge pin_clk) begin
    //    test_counter <= test_counter + 1;
    //end

    
    wire [11:0]       debug;
    assign pin_14 = led_out[0]; //debug[ 0];
    assign pin_15 = led_out[1]; //debug[ 1];
    assign pin_16 = led_out[2]; //debug[ 2];
    assign pin_17 = led_out[3]; //debug[ 3];
    assign pin_18 = led_shift_1st_line; //debug[ 4];
    assign pin_19 = led_shift_clock; //debug[ 5];
    assign pin_20 = debug[ 6];
    assign pin_21 = debug[ 7];
    assign pin_22 = debug[ 8];
    assign pin_23 = debug[ 9];
    assign pin_24 = debug[10];

    assign pin_3 = led_shift_1st_line;
    assign pin_4 = led_shift_clock;
    assign pin_5 = led_out[0];
    assign pin_6 = led_out[1];
    assign pin_7 = led_out[2];
    assign pin_8 = led_out[3];
    assign pin_9 = led_out[4];
    assign pin_10 = led_out[5];
    assign pin_11 = led_out[6];
    assign pin_12 = led_out[7];
    assign pin_13 = led_out[8];
    assign pin_25 = led_out[9];
    
    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////
    ////////
    //////// generate 48 mhz clock
    ////////
    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////
    wire clk_48mhz;
    wire clk_locked;
    SB_PLL40_CORE #(
        .DIVR(4'b0000),
        .DIVF(7'b0101111),
        .DIVQ(3'b100),
        .FILTER_RANGE(3'b001),
        .FEEDBACK_PATH("SIMPLE"),
        .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
        .FDA_FEEDBACK(4'b0000),
        .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
        .FDA_RELATIVE(4'b0000),
        .SHIFTREG_DIV_MODE(2'b00),
        .PLLOUT_SELECT("GENCLK"),
        .ENABLE_ICEGATE(1'b0)
    ) usb_pll_inst (
        .REFERENCECLK(pin_clk),
        .PLLOUTCORE(clk_48mhz),
        .PLLOUTGLOBAL(),
        .EXTFEEDBACK(),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .LATCHINPUTVALUE(),
        .LOCK(clk_locked),
        .SDI(),
        .SDO(),
        .SCLK()
    );

    

    
    localparam TEXT_LEN = 13;

    assign pin_led = 1;

    
    // Generate reset signal
    // Generate reset signal
    reg [5:0] reset_cnt = 0;
    wire reset = ~reset_cnt[5];
    always @(posedge clk_48mhz)
        if ( clk_locked )
            reset_cnt <= reset_cnt + reset;

    reg        clk_24mhz = 0;
    always @(posedge clk_48mhz) clk_24mhz <= ~clk_24mhz;

    reg        clk_12mhz = 0;
    always @(posedge clk_24mhz) clk_12mhz <= ~clk_12mhz;

    wire clk;
    wire rst;
    assign clk = clk_12mhz;
    assign rst = reset;
    
    //---------------------------------------------------------------
    // Wishbone arbitration connections
    reg [7:0] data_in;
    wire      ack;
    
    reg [7:0] led_data;
    reg       led_ack;
    
    wire [7:0] mem_data;
    wire       mem_ack;
    
    wire [7:0] sid1_data;
    wire       sid1_ack;

    assign ack = |{led_ack, sid1_ack, mem_ack};
    
    always @(*) begin
        if      (led_ack)  begin  data_in = led_data;  end
        else if (mem_ack)  begin  data_in = mem_data;  end
        else if (sid1_ack) begin  data_in = sid1_data; end
        else               begin  data_in = 8'd0;      end
    end
    
    // the blocking mechanism is pretty simple. If any device is
    // currently using the bus, block everything else
    wire        cycle;
    reg [15:0]  adr;
    reg [7:0]   data;
    reg         we;
    reg [0:0]   sel;
    reg         stb;
    reg [2:0]   cti;
    
    wire        rs232_cycle;
    wire        rs232_cycle_in;
    wire [15:0] rs232_adr;
    wire [7:0]  rs232_data;
    wire        rs232_we;
    wire        rs232_sel;
    wire        rs232_stb;
    wire [2:0]  rs232_cti;
    
    wire        synth_cycle;
    wire        synth_cycle_in;
    wire [15:0] synth_adr;
    wire [7:0]  synth_data;
    wire        synth_we;
    wire        synth_sel;
    wire        synth_stb;
    wire [2:0]  synth_cti;
    
    wire        led_drv_cycle;
    wire        led_drv_cycle_in;
    wire [15:0] led_drv_adr;
    wire [7:0]  led_drv_data;
    wire        led_drv_we;
    wire        led_drv_sel;
    wire        led_drv_stb;
    wire [2:0]  led_drv_cti;

    assign rs232_cycle_in = synth_cycle | led_drv_cycle;
    assign synth_cycle_in = rs232_cycle | led_drv_cycle;
    assign led_drv_cycle_in  = rs232_cycle | synth_cycle;

    assign cycle = rs232_cycle | synth_cycle | led_drv_cycle;
    
    always @(*) begin
        if      (rs232_cycle)    begin  adr = rs232_adr;     data = rs232_data;     we = rs232_we;     sel = rs232_sel;     stb = rs232_stb;     cti = rs232_cti;    end
        else if (synth_cycle)    begin  adr = synth_adr;     data = synth_data;     we = synth_we;     sel = synth_sel;     stb = synth_stb;     cti = synth_cti;    end
        else if (led_drv_cycle)  begin  adr = led_drv_adr;   data = led_drv_data;   we = led_drv_we;   sel = led_drv_sel;   stb = led_drv_stb;   cti = led_drv_cti;  end
        else                     begin  adr =     16'd0;     data =       8'd0;     we =        0;     sel =         0;     stb =         0;     cti =      3'd0;    end
    end

    
    //---------------------------------------------------------------
    assign synth_cycle = 0;
    assign synth_adr   = 0;
    assign synth_data  = 0;
    assign synth_we    = 0;
    assign synth_sel   = 0;
    assign synth_stb   = 0;
    assign synth_cti   = 0;
    
    //assign test_cycle = 0;
    //assign test_adr   = 0;
    //assign test_data  = 0;
    //assign test_we    = 0;
    //assign test_sel   = 0;
    //assign test_stb   = 0;
    //assign test_cti   = 0;
    
    wishbone_memory #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8),
        .DATA_BYTES    (1),
        .BASE_ADDRESS  (`FRAME_MEMORY_START),
        .MEMORY_SIZE   (4096)
    ) memory_inst (
        .rst_i ( rst ),
        .clk_i ( clk ),
        .adr_i ( adr ),
        .dat_i ( data ),
        .dat_o ( mem_data ),
        .we_i  ( we ),
        .sel_i ( sel ),
        .stb_i ( stb ),
        .cyc_i ( cycle ),
        .ack_o ( mem_ack ),
        .cti_i ( cti )
    );
    

    //assign sid1_data = 0;
    //assign sid1_ack = 0;
    sid_chip #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8),
        .DATA_BYTES    (1),
        .BASE_ADDRESS  (`SID1_START),
        .FILTER_BASE_ADDRESS (`FILTER_START)
    ) sid1_inst (
        .rst_i ( rst ),
        .clk_i ( clk ),
        .adr_i ( adr ),
        .dat_i ( data ),
        .dat_o ( sid1_data ),
        .we_i  ( we ),
        .sel_i ( sel ),
        .stb_i ( stb ),
        .cyc_i ( cycle ),
        .ack_o ( sid1_ack ),
        .cti_i ( cti ),
    
        .audio_p ( pin_1 ),
        .audio_n ( pin_2 ),
    
        .debug ( debug )
    );

    //reg [4:0]                leds;
    //reg [4:0]                next_leds;
    //// simple LED module to check the wishbone interface
    //always @(posedge clk or posedge rst) begin
    //    if (rst) begin
    //        leds <= 5'b01010;
    //    end
    //    else begin
    //        leds <= next_leds;
    //    end
    //end
    //always @(*) begin
    //    led_data  = 8'd0;
    //    next_leds = leds;
    //    led_ack   = 1'd0;
    //    
    //    if (cycle && adr == 16'd0) begin
    //        led_data = { 3'd0, leds };
    //        led_ack = 1'b1;
    //        if (we) begin
    //            next_leds = data[4:0];
    //        end
    //    end
    //end
    
    //assign led_drv_adr = 0;
    //assign led_drv_data = 0;
    //assign led_drv_we = 0;
    //assign led_drv_sel = 0;
    //assign led_drv_stb = 0;
    //assign led_drv_cycle = 0;
    //assign led_drv_cti = 0;
    led_matrix #(
        .N_COLS          ( N_COLS ),
        .N_ROWS          ( N_ROWS ),
        .ADDRESS_WIDTH   ( 16 ),
        .DATA_WIDTH      ( 8 ),
        .DATA_BYTES      ( 1 ),
        .BASE_ADDRESS    ( `MATRIX_START ),
        .MAX_WAIT        ( 8 ),
        .TOTAL_LOAD_TIME ( 256 ),
        .TOTAL_LINE_TIME ( 2048 )
    ) led_matrix_inst (
        // Wishbone interface
        .rst_i ( rst ),
        .clk_i ( clk ),
    
        .adr_i ( adr ),
        .dat_i ( data ),
        .dat_o ( led_data ),
        .we_i  ( we ),
        .sel_i ( sel ),
        .stb_i ( stb ),
        .cyc_i ( cycle ),
        .ack_o ( led_ack ),
        .cti_i ( cti ),
    
        // Wishbone master
        .frame_adr_o ( led_drv_adr ),
        .frame_dat_i ( data_in ),
        .frame_dat_o ( led_drv_data ),
        .frame_we_o  ( led_drv_we ),
        .frame_sel_o ( led_drv_sel ),
        .frame_stb_o ( led_drv_stb ),
        .frame_cyc_i ( led_drv_cycle_in ),
        .frame_cyc_o ( led_drv_cycle ),
        .frame_ack_i ( ack ),
        .frame_cti_o ( led_drv_cti ),
    
        // LED Drive Out
        .shift_1st_line ( led_shift_1st_line ),
        .shift_clock    ( led_shift_clock ),
        .led_out        ( led_out )
    );

    
    //---------------------------------------------------------------
    // uart and protocol
    
    

    wire [7:0] uart_in_data;
    wire       uart_in_valid;
    wire       uart_in_ready;
    wire [7:0] uart_out_data;
    wire       uart_out_valid;
    wire       uart_out_ready;


    protocol #(
        .ADDRESS_WIDTH (16),
        .DATA_WIDTH    (8 ),
        .DATA_BYTES    (1 ),
        .MAX_WAIT      (8 ),
        .MAX_PAYLOAD   (4 )
    ) protocol_inst (
        // Wishbone interface
        .rst_i     ( rst ),
        .clk_i     ( clk ),
        .clk_48mhz ( clk_48mhz ),

        .adr_o ( rs232_adr      ),
        .dat_i ( data_in        ),
        .dat_o ( rs232_data     ),
        .we_o  ( rs232_we       ),
        .sel_o ( rs232_sel      ),
        .stb_o ( rs232_stb      ),
        .cyc_i ( rs232_cycle_in ),
        .cyc_o ( rs232_cycle    ),
        .ack_i ( ack            ),
        .cti_o ( rs232_cti      ),
        
        // Uart interfaces
        .rx_byte       ( uart_out_data ),
        .rx_byte_valid ( uart_out_valid ),
        .rx_ready      ( uart_out_ready ),

        .tx_byte       ( uart_in_data ),
        .tx_byte_valid ( uart_in_valid ),
        .tx_ready      ( uart_in_ready ), 
    );

    
    // usb uart
    usb_uart_core uart (
        .clk_48mhz     ( clk_48mhz      ),
        .reset         ( reset          ),
     
        .usb_p_tx      ( usb_p_tx       ),
        .usb_n_tx      ( usb_n_tx       ),
        .usb_p_rx      ( usb_p_rx       ),
        .usb_n_rx      ( usb_n_rx       ),
        .usb_tx_en     ( usb_tx_en      ),
     
        // uart pipeline in (out of the device, into the host)
        .uart_in_data  ( uart_in_data   ),
        .uart_in_valid ( uart_in_valid  ),
        .uart_in_ready ( uart_in_ready  ),
     
        // uart pipeline out (into the device, out of the host)
        .uart_out_data ( uart_out_data  ),
        .uart_out_valid( uart_out_valid ),
        .uart_out_ready( uart_out_ready ),
     
        .debug(  )
    );
    
    wire usb_p_tx;
    wire usb_n_tx;
    wire usb_p_rx;
    wire usb_n_rx;
    wire usb_tx_en;
    wire usb_p_in;
    wire usb_n_in;

    assign pin_pu = 1'b1;
    
    assign usb_p_rx = usb_tx_en ? 1'b1 : usb_p_in;
    assign usb_n_rx = usb_tx_en ? 1'b0 : usb_n_in;
    
    SB_IO #(
        .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
        .PULLUP(1'b 0)
    ) 
    iobuf_usbp 
    (
        .PACKAGE_PIN(pin_usbp),
        .OUTPUT_ENABLE(usb_tx_en),
        .D_OUT_0(usb_p_tx),
        .D_IN_0(usb_p_in)
    );

    SB_IO #(
        .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
        .PULLUP(1'b 0)
    ) 
    iobuf_usbn 
    (
        .PACKAGE_PIN(pin_usbn),
        .OUTPUT_ENABLE(usb_tx_en),
        .D_OUT_0(usb_n_tx),
        .D_IN_0(usb_n_in)
    );

endmodule
