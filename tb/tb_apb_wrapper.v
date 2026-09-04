`timescale 1 ns / 1 ps

module tb_apb_wrapper();

    // System Signals
    reg PCLK;
    reg PRESETn;

    // APB Bus Signals
    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg  [31:0] PADDR;
    reg  [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire        PREADY;


    // Instantiate the Wrapper
    apb_system_wrapper uut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADDR(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY)
    );

    // Clock Generation (100 MHz)
    always #5 PCLK = ~PCLK;


    // APB Write Task (Standard Protocol Timing)
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge PCLK); // Wait for clock edge
            
            // SETUP PHASE
            PSEL = 1'b1;
            PWRITE = 1'b1;
            PADDR = addr;
            PWDATA = data;
            PENABLE = 1'b0;
            
            @(posedge PCLK);
            // ACCESS PHASE
            PENABLE = 1'b1;
            
            wait(PREADY); // Wait for peripheral to acknowledge
            
            @(posedge PCLK);
            // Return to IDLE
            PSEL = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    // APB Read Task (Standard Protocol Timing)
    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge PCLK);
            
            // SETUP PHASE
            PSEL = 1'b1;
            PWRITE = 1'b0;
            PADDR = addr;
            PENABLE = 1'b0;
            
            @(posedge PCLK);
            // ACCESS PHASE
            PENABLE = 1'b1;
            
            wait(PREADY);
            data = PRDATA; // Capture the data from the bus
            
            @(posedge PCLK);
            // Return to IDLE
            PSEL = 1'b0;
            PENABLE = 1'b0;
        end
    endtask

    // Main Test Sequence

    reg [31:0] read_val;

    initial begin
        // Initialize all signals to 0
        PCLK = 0;
        PRESETn = 0;
        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;
        PADDR = 0;
        PWDATA = 0;

        // Reset Sequence
        #20;
        PRESETn = 1;
        #20;

        $display("Starting System-on-Chip Verification...");

        // Test the ALU (Assuming opcode 4'd1 is ADD)
        //$display("Testing ALU Block...");
        //apb_write(32'h00, 32'd10); // Write 10 to Operand A
        //apb_write(32'h04, 32'd15); // Write 15 to Operand B
        //apb_write(32'h08, 32'd1);  // Write 1 to Opcode (ADD)
        
        //apb_read(32'h0C, read_val); // Read the result
        //$display("ALU Result (Expected 25): %d", read_val);

  
        // Test the Tensor Processing Unit
        $display("Testing TPU Block...");
        apb_write(32'h10, 32'd1); // Send a '1' to the Start Register
        
        // Continuously read the status register until TPU is done
        read_val = 0;
        while (read_val[0] == 0) begin
            apb_read(32'h14, read_val);
            #10;
        end
        $display("TPU Computation Complete! Fetching Matrix...");

        // read the 4 matrix results
        apb_read(32'h18, read_val);
        $display("Result 00: %h", read_val);
        
        apb_read(32'h1C, read_val);
        $display("Result 01: %h", read_val);
        
        apb_read(32'h20, read_val);
        $display("Result 10: %h", read_val);
        
        apb_read(32'h24, read_val);
        $display("Result 11: %h", read_val);

        #50;
        $display("Simulation Complete.");
        $finish;
    end

endmodule