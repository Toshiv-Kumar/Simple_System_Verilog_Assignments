// Name: Toshiv Kumar, Roll No.: 1024060266
`timescale 1ns / 1ps
class PacketInside;
 rand bit [3:0] addr;
 rand bit [7:0] data [];
 rand bit read_write;
 rand bit [2:0] mode;
 constraint c_addr_rw {
 solve read_write before addr;
 (read_write == 1) -> (addr inside {[4'h0 : 4'h7]});
 (read_write == 0) -> (addr inside {[4'h8 : 4'hF]});
 }
 constraint c_data_arr {
 data.size() inside {[4 : 8]};
 data.sum() < 500;
 foreach (data[i]) {
 if (i > 0) data[i] > data[i-1];
 }
 }
 constraint c_mode_dist {
 mode dist {0 := 20, [1:6] :/ 60, 7 := 20};
 }
endclass
module tb_packet_inside;
 PacketInside pkt_in;
 initial begin
 pkt_in = new();
 repeat(5) begin
 if(!pkt_in.randomize()) begin
 $display("Randomization failed");
 end else begin
 $display("addr=%0h, read_write=%0b, mode=%0d, data=%p", pkt_in.addr,
pkt_in.read_write, pkt_in.mode, pkt_in.data);
 end
 end
 $finish;
 end
endmodule
