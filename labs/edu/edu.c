// SPDX-License-Identifier: GPL-2.0
/*
 * edu.c — I/O Systems lab: a Linux driver for QEMU's `edu` PCI device.
 *
 * THIS IS A SKELETON. It compiles and binds to the device, but does nothing
 * useful yet — every exercise below is a TODO that you implement. The point of
 * the lab is the three fundamental ways a CPU talks to a device:
 *
 *     1. MMIO        — read/write the device's registers   (ex1, ex2, ex3a)
 *     2. interrupts  — be notified instead of polling       (ex3b, ex4)
 *     3. DMA         — let the device move memory itself     (ex5)
 *
 * See README.md for the objectives, the device datasheet, and where to read.
 * It tells you WHICH kernel subsystems to use — not the line-by-line code.
 */
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/dma-mapping.h>

#define EDU_VENDOR_ID 0x1234
#define EDU_DEVICE_ID 0x11e8

/* ---- edu register map (datasheet — see README) -------------------------- *
 * Accesses below 0x80 MUST be 32-bit; the DMA registers (0x80+) are 64-bit.  */
#define EDU_REG_ID          0x00 /* RO  identification: 0xRRrr00edu           */
#define EDU_REG_LIVENESS    0x04 /* RW  reads back the bitwise NOT of writes  */
#define EDU_REG_FACTORIAL   0x08 /* RW  write N; read N! once status clears   */
#define EDU_REG_STATUS      0x20 /* RW  bit0=computing(RO)  bit7=IRQ-on-done  */
#define EDU_REG_IRQ_STATUS  0x24 /* RO  the value(s) that raised the IRQ      */
#define EDU_REG_IRQ_RAISE   0x60 /* WO  OR value into IRQ status (fire IRQ)   */
#define EDU_REG_IRQ_ACK     0x64 /* WO  clear value from IRQ status           */
#define EDU_REG_DMA_SRC     0x80 /* RW  64-bit DMA source address             */
#define EDU_REG_DMA_DST     0x88 /* RW  64-bit DMA destination address        */
#define EDU_REG_DMA_COUNT   0x90 /* RW  64-bit DMA byte count                 */
#define EDU_REG_DMA_CMD     0x98 /* RW  bit0=start bit1=dir(1=EDU->RAM) bit2=IRQ */

#define EDU_STATUS_COMPUTING   0x01
#define EDU_STATUS_IRQ_ON_FACT 0x80
#define EDU_DMA_BUF_ADDR       0x40000 /* device-internal 4 KiB DMA buffer    */
#define EDU_DMA_BUF_SIZE       4096
#define EDU_DMA_START          0x01
#define EDU_DMA_DIR_TO_RAM     0x02
#define EDU_DMA_IRQ            0x04
#define EDU_DMA_IRQ_VALUE      0x100  /* raised in IRQ status when DMA done   */

/* Per-device state. Grow this as you need it (a completion to wait on the IRQ,
 * a DMA buffer pointer + dma_addr_t, ...). */
struct edu_dev {
	struct pci_dev *pdev;
	void __iomem   *mmio;   /* BAR0, after you map it */
	int             irq;
	/* TODO: add fields your IRQ-driven and DMA exercises need. */
};

/* ===================== exercises — implement these ======================= */

/* TODO(ex1): read EDU_REG_ID and log the version with dev_info(). */
static void __maybe_unused edu_show_id(struct edu_dev *edu) { (void)edu; }

/* TODO(ex2): write a value to EDU_REG_LIVENESS, read it back, check it == ~value. */
static void __maybe_unused edu_liveness(struct edu_dev *edu) { (void)edu; }

/* TODO(ex3a): write N to EDU_REG_FACTORIAL, POLL the status COMPUTING bit until
 *             it clears, then read the result back.
 * TODO(ex3b): do it again, but set EDU_STATUS_IRQ_ON_FACT and let the interrupt
 *             tell you it's done instead of polling. */
static void __maybe_unused edu_factorial(struct edu_dev *edu, u32 n) { (void)edu; (void)n; }

/* TODO(ex4): the interrupt handler. Read EDU_REG_IRQ_STATUS, ACK by writing it
 *            back to EDU_REG_IRQ_ACK, wake whoever is waiting, return
 *            IRQ_HANDLED (IRQ_NONE if it wasn't ours). Register it in probe(). */
static irqreturn_t __maybe_unused edu_irq(int irq, void *data)
{
	(void)irq; (void)data;
	return IRQ_NONE; /* TODO */
}

/* TODO(ex5): allocate a coherent DMA buffer, fill it, and use the DMA engine to
 *            copy it RAM->device and back (EDU->RAM), then verify the bytes. */
static void __maybe_unused edu_dma_demo(struct edu_dev *edu) { (void)edu; }

/* ============================ driver lifecycle =========================== */

static int edu_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	/* TODO(probe): bring the device up, then drive the exercises.
	 *   - allocate your struct edu_dev and stash it (pci_set_drvdata)
	 *   - enable the device and reserve its BAR
	 *   - map BAR0 into edu->mmio
	 *   - allocate + request the interrupt, pointing at edu_irq
	 *   - set the DMA mask
	 *   - call edu_show_id / edu_liveness / edu_factorial / edu_dma_demo
	 *   - unwind cleanly on every error path
	 * README names the exact subsystems/APIs; you find the calls.
	 */
	(void)id;
	dev_info(&pdev->dev, "edu: bound (skeleton — implement the TODOs)\n");
	return 0;
}

static void edu_remove(struct pci_dev *pdev)
{
	/* TODO(remove): tear everything down in reverse order of probe(). */
	(void)pdev;
}

static const struct pci_device_id edu_ids[] = {
	{ PCI_DEVICE(EDU_VENDOR_ID, EDU_DEVICE_ID) },
	{ 0, }
};
MODULE_DEVICE_TABLE(pci, edu_ids);

static struct pci_driver edu_driver = {
	.name     = "edu",
	.id_table = edu_ids,
	.probe    = edu_probe,
	.remove   = edu_remove,
};
module_pci_driver(edu_driver);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("I/O Systems lab skeleton driver for the QEMU edu device");
