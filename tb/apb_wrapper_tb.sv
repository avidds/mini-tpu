module apb_wrapper_tb;
    // time unit and precision for simulation
    timeunit 1 ns;
    time precision 1 ps;
    
    // signal declaration
    logic PCLK;
    logic PRESETn;
    logic PSEL;
    logic PENABLE;
    logic PWRITE;
    logic [31:0] PADDR;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic [31:0] PREADY;

    // instantiate DUT
    apb_system_wrapper dut (
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

    // clock generation
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; // 100 MHz clock
    end 

    // APB write task
    task apb_write(input [31:0] addr, input [31:0] data);
        @(posedge PCLK);
        // SETUP phase
        PSEL <= 1'b1;
        PENABLE <= 1'b0;
        PWRITE <= 1'b1;
        PADDR <= addr;
        PWDATA <= data;

        @(posedge PCLK);
        // ACCESS phase
        PENABLE <= 1'b1;

        // wait for slave to be ready
        wait (PREADY == 1'b1);

        @(posedge PCLK);
        // return to IDLE phase
        PSEL <= 1'b0;
        PENABLE <= 1'b0;
    endtask

    // APB read task
    task apb_read(input [31:0] addr, output [31:0] data);
        @(posedge PCLK);
        // SETUP phase
        PSEL <= 1'b1;
        PENABLE <= 1'b0;
        PWRITE <= 1'b0; // 0 for read
        PADDR <= addr;

        @(posedge PCLK);
        // ACCESS phase

        PENABLE <= 1'b1;

        // wait for slave to be ready
        wait (PREADY == 1'b1);
        data = PRDATA;

        @(posedge PCLK);
        // return to IDLE phase

        PSEL <= 1'b0;
        PENABLE <= 1'b0;
    endtask


    // test sequence
    initial begin
        logic [31:0] read_val;

        // initialize signals
        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;
        PADDR = 0;
        PWDATA = 0;

        // apply reset (active low)
        PRESETn = 0;
        repeat (3) @(posedge PCLK);
        PRESETn = 1;
        @(posedge PCLK);

        $display("starting APB write and read test...");

        // transaction 1: load matrix A into 0x00 - 0x0C
        $display("Time: %0t | Loading Weight Matrix A...", $time);
        apb_write(32'h0000_0000, 32'h0000_0001); // A[0][0] = 1
        apb_write(32'h0000_0004, 32'h0000_0002); // A[0][1] = 2
        apb_write(32'h0000_0008, 32'h0000_0003); // A[1][0] = 3
        apb_write(32'h0000_000C, 32'h0000_0004); // A[1][1] = 4

        // transaction 2: load matrix B into 0x10 - 0x1C
        $display("Time: %0t | Loading Input Matrix B...", $time);
        apb_write(32'h0000_0010, 32'h0000_0002); // B00
        apb_write(32'h0000_0014, 32'h0000_0000); // B01
        apb_write(32'h0000_0018, 32'h0000_0000); // B10
        apb_write(32'h0000_001C, 32'h0000_0002); // B11

        // transaction 3: trigger TPU start flag (Address 0x20)
        $display("Time: %0t | Triggering TPU Computation...", $time);
        apb_write(32'h0000_0020, 32'h0000_0001);

        // transaction 4: poll for TPU completion (Address 0x24)
        $display("Time: %0t | Polling for Completion...", $time);
        read_val = 32'h0;
        while (read_val !== 32'h0000_0001) begin
            apb_read(32'h0000_0024, read_val);
        end
        $display("Time: %0t | TPU Computation Complete!", $time);

        // transaction 5: read result (e.g. address 0x30 for result 00)
        $display("Time: %0t | Reading Results...", $time);
        apb_read(32'h0000_0030, read_val);
        
        // transaction 6: check if the result matches expected output
        if (read_val === 32'h0000_0002) begin
            $display("SUCCESS: Result 00 matches expected output (32'h%h).", read_val);
        end else begin
            $error("FAILURE: Expected 32'h0000_0002, got 32'h%h.", read_val);
        end

        $display("Test Complete");
        $finish;
    end 


endmodule