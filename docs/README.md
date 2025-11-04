# Ethernet_CRC_32_FCS

Synthesizable **Ethernet CRC-32 (FCS)** generator & checker with **AXI-Stream** wrappers, a **self-checking testbench** (randomized traffic + error injection), and an **FPGA loopback top** for Signal Tap/ILA validation.

## Features
- **TX (`fcs_tx`)**: AXI-Stream payload in → appends **CRC-32 (0x04C11DB7)** → emits payload + 4-byte FCS.
- **RX (`fcs_rx`)**: AXI-Stream frame (payload+FCS) in → verifies CRC → outputs payload, flags `bad_fcs`.
- **Self-checking testbench**: randomized lengths, PRBS payloads, **error injection** (bit flips) + scoreboard.
- **FPGA loopback top**: internal TX→RX path with counters & ILA/Signal Tap hooks.
- Clean **AXI-Stream** handshakes (`tvalid/tready/tlast`).

## CRC details
- Polynomial: **0x04C11DB7** (Ethernet); reflected form used internally: **0xEDB88320**
- Init: **0xFFFFFFFF**; Final XOR: **0xFFFFFFFF**
- Byte order: LSB-first per byte (reflected); FCS bytes transmitted least significant byte first.

## Run simulation (ModelSim/Questa)
```sh
vlog rtl/*.sv sim/*.sv
vsim -c tb_fcs_axistream -do "run -all; quit"
```

## Expected results
- ~2000 frames → **0 CRC errors** with injection disabled.
- With `inj_every_n=50`, expect `bad_fcs` ≈ number of injected frames.

## Directory
```
rtl/  – axi_stream_pkg.svh, crc32_ethernet.sv, fcs_tx.sv, fcs_rx.sv
sim/  – tb_fcs_axistream.sv, axi_stream_packet_gen.sv, axi_stream_packet_chk.sv
fpga/ – top_loopback.sv
docs/ – results.md (fill with Fmax/LUT/FF/BRAM + screenshots)
```
