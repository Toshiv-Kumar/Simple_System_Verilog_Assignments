// Name: Toshiv Kumar, Roll No.: 1024060266
`timescale 1ns / 1ps
class PacketOutside;
 rand bit [4:0] index;
 rand bit [7:0] payload [];
 rand bit enable;
 rand bit [1:0] priority_lvl;
 extern constraint c_index_en;
 extern constraint c_payload_arr;
 extern constraint c_priority_dist;
endclass
constraint PacketOutside::c_index_en {
 solve enable before index;
 if (enable) {
 index inside {[10:20]};
 } else {
 !(index inside {[10:20]});
 }
}
constraint PacketOutside::c_payload_arr {
 payload.size() == 5;
 foreach (payload[i]) {
 payload[i] inside {[8'hA0 : 8'hFF]};
 if (i > 0) payload[i] > payload[i-1];
 }
}
constraint PacketOutside::c_priority_dist {
 priority_lvl dist {0 := 10, 1 := 30, 2 := 40, 3 := 20};
}
module tb_packet_outside;
 PacketOutside pkt_out;
 initial begin
 pkt_out = new();
 repeat(5) begin
 if(!pkt_out.randomize()) begin
 $display("Randomization failed");
 end else begin
 $display("index=%0d, enable=%0b, priority_lvl=%0d, payload=%p", pkt_out.index,
pkt_out.enable, pkt_out.priority_lvl, pkt_out.payload);
 end
 end
 $finish;
 end
endmodule
