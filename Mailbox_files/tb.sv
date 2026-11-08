// Name: Toshiv Kumar, Roll No.: 1024060266
//
==================================================================
==========
// FILE: tb.sv
// ASSIGNMENT 7: Communication between parallel processes using a Mailbox
// (Packet Generator and Receiver)
//
==================================================================
==========
//
// ----------------------------------------------------------------------------
// 1. WHY wasn't this in Basic Verilog (IEEE 1364)?
// ----------------------------------------------------------------------------
// Basic Verilog was designed to describe hardware gates and wires, not software
// threads. If Process A wanted to send data to Process B in basic Verilog:
// - You had to use shared global 'reg' variables and 'event' triggers (->ev).
// - If Process A generated 3 packets before Process B finished reading the 1st,
// packets 2 and 3 overwrote packet 1 in the global reg!
// - If both accessed the reg at the exact same simulation delta-cycle, you got
// a non-deterministic RACE CONDITION.
//
// ----------------------------------------------------------------------------
// 2. WHAT BETTER are we doing in SystemVerilog?
// ----------------------------------------------------------------------------
// a) Atomic Thread Safety: Two threads can never corrupt the mailbox queue.
// b) Automatic Backpressure (Flow Control): A bounded mailbox automatically
// puts a fast Generator thread to sleep when full, and wakes it up the
// exact moment the slow Receiver frees up a slot.
// c) Reference Passing: Instead of copying massive bit-vectors across wires,
// a mailbox passes a lightweight 32/64-bit class handle (pointer).
//
==================================================================
==========
// ----------------------------------------------------------------------------
// STEP 1: Define the Transaction (Packet) Class
// ----------------------------------------------------------------------------
class Packet;
 rand bit [7:0] id;
 rand bit [7:0] payload;
 // Constraint to keep values easy to read in simulation logs
 constraint c_readable {
 id inside {[1:10]};
 payload inside {[10:50]};
 }
 function new(bit [7:0] id = 0, bit [7:0] payload = 0);
 this.id = id;
 this.payload = payload;
 endfunction
 function void display(string tag);
 $display("[Time %0t] [%s] Packet ID: %0d | Payload: %0d (Handle/Addr: %0d)",
 $time, tag, id, payload, $urandom_range(100,999)); // Conceptual display
 endfunction
endclass
// ----------------------------------------------------------------------------
// STEP 2: Packet Generator Class (The Producer Process)
// ----------------------------------------------------------------------------
class Generator;

 // CRITICAL EDGE CASE 1: Parameterized vs. Unparameterized Mailbox
 // - 'mailbox mbx;' is UNPARAMETERIZED (Typeless). It lets you accidentally
 // put a string or an int into a mailbox meant for Packets, causing a crash
 // at runtime when the Receiver tries to get() a Packet.
 // - 'mailbox #(Packet) mbx;' is PARAMETERIZED. The compiler strictly enforces
 // that ONLY handles of type 'Packet' can ever enter this mailbox.
 mailbox #(Packet) mbx;
 int num_packets;
 function new(mailbox #(Packet) mbx, int num_packets = 3);
 this.mbx = mbx;
 this.num_packets = num_packets;
 endfunction
 task run();
 Packet pkt;

 //
==================================================================
======
 // CRITICAL EDGE CASE 2: The "Handle Overwrite" Bug (Most Common Interview
Trap!)
 //
==================================================================
======
 // Remember: A mailbox does NOT store a copy of the Packet object!
 // It ONLY stores the HANDLE (memory pointer) to the object.
 //
 // WRONG WAY:
 // pkt = new(); // Allocated ONCE outside the loop!
 // for (int i = 0; i < num_packets; i++) begin
 // pkt.randomize();
 // mbx.put(pkt); // Puts the EXACT SAME pointer into the mailbox 3 times!
 // end
 // Result: All 3 slots in the mailbox point to the same memory address,
 // containing only the final iteration's randomized values!
 //
 // RIGHT WAY: Allocate 'pkt = new();' INSIDE the loop so every packet has
 // a brand-new, independent memory address.
 //
==================================================================
======
 for (int i = 1; i <= num_packets; i++) begin
 pkt = new(); // Fresh memory allocation for EVERY transaction!
 assert(pkt.randomize()) else $fatal("Randomization failed!");
 pkt.id = i; // Override ID sequentially so we can track order clearly
 // ----------------------------------------------------------------------
 // CRITICAL EDGE CASE 3: Non-blocking try_put() vs. Blocking put()
 // ----------------------------------------------------------------------
 // - try_put(pkt) is a FUNCTION (executes in 0 time, never blocks).
 // It returns >0 if inserted, or 0 if the bounded mailbox is currently FULL.
 // - put(pkt) is a TASK (can consume time). If the mailbox is FULL, it
 // freezes/suspends this Generator thread until the Receiver removes an item.
 if (mbx.try_put(pkt)) begin
 $display("[Time %0t] [GEN] try_put() SUCCESS for Packet ID=%0d (Mailbox
count=%0d)",
 $time, pkt.id, mbx.num());
 end else begin
 $display("[Time %0t] [GEN] Mailbox FULL (count=%0d)! Calling blocking put() and
waiting...",
 $time, mbx.num());
 mbx.put(pkt); // Blocks right here until Receiver frees a slot!
 $display("[Time %0t] [GEN] Unblocked! Blocking put() completed for Packet ID=%0d",
 $time, pkt.id);
 end
 end
 endtask
endclass
// ----------------------------------------------------------------------------
// STEP 3: Packet Receiver Class (The Consumer Process)
// ----------------------------------------------------------------------------
class Receiver;
 mailbox #(Packet) mbx;
 int num_packets;
 function new(mailbox #(Packet) mbx, int num_packets = 3);
 this.mbx = mbx;
 this.num_packets = num_packets;
 endfunction
 task run(ref logic clk, ref logic valid_in, ref logic [7:0] id_in, ref logic [7:0] payload_in);
 Packet pkt_peeked, pkt_received;
 for (int i = 1; i <= num_packets; i++) begin
 // Simulate a slower hardware receiver (takes 10ns before it is ready to read)
 #10;
 // ----------------------------------------------------------------------
 // CRITICAL EDGE CASE 4: peek() vs. get() (Non-Destructive vs. Destructive)
 // ----------------------------------------------------------------------
 // - peek() copies the handle from the front of the mailbox WITHOUT removing
 // it from the queue. If the mailbox is empty, peek() blocks just like get().
 // - try_peek() and try_get() are the non-blocking 0-time versions.
 mbx.peek(pkt_peeked);
 $display("[Time %0t] [RCV-PEEK] Peeked at front Packet ID=%0d (Still in mbx,
count=%0d)",
 $time, pkt_peeked.id, mbx.num());
 // Now actually remove the packet from the mailbox using blocking get()
 mbx.get(pkt_received);
 $display("[Time %0t] [RCV-GET] Removed Packet ID=%0d | Payload=%0d (Remaining
in mbx=%0d)",
 $time, pkt_received.id, pkt_received.payload, mbx.num());
 // Drive the received transaction onto the physical DUT signals
 @(posedge clk);
 valid_in = 1'b1;
 id_in = pkt_received.id;
 payload_in = pkt_received.payload;
 @(posedge clk);
 valid_in = 1'b0;
 end
 endtask
endclass
// ----------------------------------------------------------------------------
// STEP 4: Top-Level Testbench Module
// ----------------------------------------------------------------------------
module tb;
 logic clk = 0;
 logic rst_n;
 logic valid_in;
 logic [7:0] id_in;
 logic [7:0] payload_in;
 logic [7:0] processed_out;
 // 5ns half-period -> 10ns clock period
 always #5 clk = ~clk;
 // Instantiate the synthesizable Design (DUT)
 packet_dut dut (
 .clk (clk),
 .rst_n (rst_n),
 .valid_in (valid_in),
 .id_in (id_in),
 .payload_in (payload_in),
 .processed_out(processed_out)
 );
 // Declare handles for our verification components
 mailbox #(Packet) mbx;
 Generator gen;
 Receiver rcv;
 initial begin
 // Initialize signals
 rst_n = 0;
 valid_in = 0;
 id_in = 0;
 payload_in = 0;
 #15 rst_n = 1;
 //
==================================================================
======
 // CRITICAL EDGE CASE 5: Bounded vs. Unbounded Mailbox Allocation
 //
==================================================================
======
 // - mbx = new(); // UNBOUNDED: Can grow infinitely. Risk: If Generator
 // // has an infinite loop without delays, it consumes 100%
 // // of your PC's RAM in 0 simulation time!
 // - mbx = new(2); // BOUNDED (Size = 2): Holds a maximum of 2 packets.
 // // Attempting to put a 3rd packet stalls the Generator!
 //
==================================================================
======
 mbx = new(2); // Bounded to 2 slots so we can observe backpressure!
 // Pass the SAME mailbox handle to both Generator and Receiver so they share it
 gen = new(mbx, 4); // Generate 4 packets total
 rcv = new(mbx, 4); // Receive 4 packets total
 $display("------------------------------------------------------------------");
 $display("Starting Parallel Processes (Generator & Receiver) via fork...join");
 $display("------------------------------------------------------------------");
 // Run Generator and Receiver in parallel threads
 fork
 gen.run();
 rcv.run(clk, valid_in, id_in, payload_in);
 join
 #20;
 $display("------------------------------------------------------------------");
 $display("All packets generated, received, and processed by DUT. Finishing.");
 $display("------------------------------------------------------------------");
 $finish;
 end
 // Monitor the hardware DUT output whenever it changes
 initial begin
 $monitor("[Time %0t] [DUT-HW] valid_in=%b | id_in=%0d | payload_in=%0d |
processed_out=%0d",
 $time, valid_in, id_in, payload_in, processed_out);
 end
endmodule
