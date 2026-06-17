# Lab: writing a PCI driver for the `edu` device

In this lab you write a real Linux kernel driver for QEMU's **`edu`** device — a
deliberately minimal PCI device. By the end your module will talk to it three
ways, which are *the* three ways any CPU talks to any device:

1. **MMIO** — read/write the device's registers directly.
2. **Interrupts** — be notified when work finishes, instead of polling.
3. **DMA** — have the device move data to/from RAM by itself.

You are given a skeleton (`edu.c`) that compiles and binds to the device but
does nothing. Your job is the `TODO`s. This guide gives you the **objectives**,
the **datasheet**, and **where to read** — not the code. Figuring out the exact
kernel functions and the order to call them *is* the exercise.

## Prerequisites

C, and a first look at the Linux kernel module / PCI driver model. Work inside
the lab VM (it has the kernel headers and toolchain). Confirm the device is
present first:

```sh
lspci -nn -d 1234:11e8        # you should see the edu device
```

## The device (datasheet)

PCI ID **`1234:11e8`**, with one MMIO region (BAR 0), 1 MB. Registers — **all
accesses below `0x80` must be 32-bit; the DMA registers at `0x80`+ are 64-bit**:

| Offset | Acc | Register | Behaviour |
|--------|-----|----------|-----------|
| `0x00` | RO  | Identification   | Magic `0xRRrr00edu` (`RR` major, `rr` minor version). |
| `0x04` | RW  | Liveness check   | Reads back the bitwise **NOT** of whatever you wrote. |
| `0x08` | RW  | Factorial        | Write N; after the device finishes, N! is readable here. |
| `0x20` | RW  | Status           | bit `0x01` = computing (RO); bit `0x80` = raise an IRQ when the factorial finishes. |
| `0x24` | RO  | Interrupt status | The value(s) that raised the current interrupt. |
| `0x60` | WO  | Interrupt raise  | Value is OR'd into interrupt status (fires the IRQ). |
| `0x64` | WO  | Interrupt ack    | Value is cleared from interrupt status. **You must do this in the handler** or the IRQ re-fires. |
| `0x80` | RW  | DMA source       | 64-bit source address. |
| `0x88` | RW  | DMA destination  | 64-bit destination address. |
| `0x90` | RW  | DMA count        | Transfer size in bytes. |
| `0x98` | RW  | DMA command      | bit `0x01` = start; `0x02` = direction (`0` = RAM→device, `1` = device→RAM); `0x04` = raise IRQ `0x100` when done. |

DMA on the device side always uses its **internal 4096-byte buffer at offset
`0x40000`**. The other side is an address in system RAM. The factorial and DMA
take *time* — that is what makes polling vs. interrupts a real choice.

## What to implement (objectives)

Each is defined by what it should *achieve*, not how. Observe results with
`dmesg`.

- **ex1 — identify.** Read the ID register and log the version. (Proves your
  driver is bound and BAR 0 is mapped.)
- **ex2 — liveness.** Write a value to the liveness register, read it back,
  confirm it is the bitwise inverse.
- **ex3a — factorial by polling.** Make the device compute `5!` and read back
  `120`, by busy-waiting on the status bit.
- **ex3b — factorial by interrupt.** Same result, but ask the device to
  interrupt you when it's done instead of polling.
- **ex4 — interrupt handler.** Service the IRQ: read the cause, acknowledge it,
  and unblock whoever was waiting.
- **ex5 — DMA.** Move a buffer of bytes from RAM into the device and back out
  again using the DMA engine, and verify the data survived the round trip.

You also implement `probe()` (bring the device up) and `remove()` (tear it
down) yourself.

## Where to read (you find the exact calls)

You will be working with four kernel subsystems. Read these, then choose the
functions:

- **PCI driver model** — enabling a device, reserving its regions, mapping a
  BAR. → `Documentation/PCI/`, `man 9 pci_enable_device`, *LDD3* ch. 12.
- **MMIO accessors** — reading/writing mapped registers (mind the 32- vs 64-bit
  rule above). → `Documentation/driver-api/device-io.rst`, `man 9 readl`.
- **Interrupts** — allocating an IRQ for a PCI device and registering a handler.
  → `Documentation/core-api/genericirq.rst`, `man 9 request_irq`, *LDD3* ch. 10.
- **DMA** — allocating a buffer the device can reach and the address you give
  the device. → `Documentation/core-api/dma-api.rst` and `dma-api-howto.rst`,
  *LDD3* ch. 15.

## Build, run, observe

```sh
make
sudo insmod edu.ko
dmesg | tail -n 30          # your dev_info() output
sudo rmmod edu
make clean
```

Re-run by `rmmod` then `insmod` again. If `make` can't find the kernel build
tree, check that `linux-lts-dev` matches the running kernel (`uname -r`).
