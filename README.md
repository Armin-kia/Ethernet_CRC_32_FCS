# Ethernet_CRC_32_FCS-
Small, synthesizable Ethernet FCS (CRC-32) generator &amp; checker with AXI-Stream wrappers, a self-checking testbench (randomized traffic + error injection), and an FPGA loopback top for quick on-board validation (Signal Tap/ILA).
Why this exists

If you’re building or validating Ethernet datapaths, you need a reliable, standalone FCS block you can plug into AXI-Stream pipelines and prove in both simulation and hardware.

Features

TX path (fcs_tx): AXI-Stream payload in → appends CRC-32 (0x04C11DB7) → emits payload + 4-byte FCS.

RX path (fcs_rx): AXI-Stream frame (payload+FCS) in → verifies CRC → outputs payload, flags bad_fcs.

Byte-wide, streaming design (one byte per cycle by default; easy to retime/parameterize).

Self-checking testbench: randomized lengths, PRBS payloads, error injection (bit flips) + scoreboard.

FPGA loopback top: internal TX→RX path with counters & ILA/Signal Tap hooks for on-board bring-up.

Clean AXI-Stream handshakes (tvalid/tready/tlast); optional tkeep/width params as TODOs.

Block diagram (concept)
AXI-S in       +-----------+        AXI-S out
payload  --->  |  FCS_TX   | --->  payload + FCS(4B)
               +-----------+
GMII/PHY not required for this repo (focus is FCS on AXI-Stream)

AXI-S in (payload+FCS)
            +-----------+       AXI-S out (payload)
------->    |  FCS_RX   | ---->  + bad_fcs flag
            +-----------+
