`timescale 1 ns / 1 ps

module apb_system_wrapper (
    
    input  wire        PCLK,      
    input  wire        PRESETn,   
    input  wire        PSEL,      
    input  wire        PENABLE,   
    input  wire        PWRITE,    
    input  wire [31:0] PADDR,     
    input  wire [31:0] PWDATA,    
    
    output reg  [31:0] PRDATA,    
    output reg         PREADY     
);

    
    // TPU signals
    reg         tpu_start;
    wire        tpu_done;

    wire [15:0] tpu_res_00; 
    wire [15:0] tpu_res_01;
    wire [15:0] tpu_res_10;
    wire [15:0] tpu_res_11;
    
    // ALU signals
    //reg  [15:0] alu_op_a;
    //reg  [15:0] alu_op_b;
    //reg  [3:0]  alu_opcode;
    //wire [15:0] alu_result;

    
    // Instantiate TPU
    mini_tpu my_tpu (
        .clk(PCLK),
        .rst_n(PRESETn),
        .start(tpu_start),
        .done(tpu_done),
        // Actively routed outputs
        .result_00(tpu_res_00),
        .result_01(tpu_res_01),
        .result_10(tpu_res_10),
        .result_11(tpu_res_11)
    );

    // Instantiate ALU
    //alu my_alu (
    //    .clk(PCLK),
    //    .rst_n(PRESETn),
    //    .a(alu_op_a),
    //    .b(alu_op_b),
    //    .opcode(alu_opcode),
    //    .result(alu_result)
    //);

    // APB Write & Read Logic

    always @(posedge PCLK) begin
        if (!PRESETn) begin
            PRDATA     <= 32'd0;
            PREADY     <= 1'b0;
            tpu_start  <= 1'b0;
            //alu_op_a   <= 16'd0;
            //alu_op_b   <= 16'd0;
            //alu_opcode <= 4'd0;
        end else begin
            
            // Default states
            tpu_start <= 1'b0; // Start signal is a 1-cycle pulse
            PREADY    <= 1'b0;

            // APB Access Phase: PSEL is high and PENABLE goes high
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1; // Tell Master we are handling the request

                if (PWRITE) begin
                    // WRITE OPERATIONS
                    case (PADDR)
                        //32'h00: alu_op_a   <= PWDATA[15:0];
                        //32'h04: alu_op_b   <= PWDATA[15:0];
                        //32'h08: alu_opcode <= PWDATA[3:0];
                        32'h10: tpu_start  <= PWDATA[0]; // Write '1' here to start TPU
                        default: ; // Do nothing for undefined addresses
                    endcase
                end else begin
                    // READ OPERATIONS 
                    case (PADDR)
                        //32'h0C: PRDATA <= {16'd0, alu_result};
                        32'h14: PRDATA <= {31'd0, tpu_done}; // Master reads this to poll status
                        // Read TPU Matrix Results
                        32'h18: PRDATA <= {16'd0, tpu_res_00}; 
                        32'h1C: PRDATA <= {16'd0, tpu_res_01};
                        32'h20: PRDATA <= {16'd0, tpu_res_10};
                        32'h24: PRDATA <= {16'd0, tpu_res_11};
                        default: PRDATA <= 32'hDEADBEEF; // Standard debug hex for bad address
                    endcase
                end
            end
        end
    end

endmodule