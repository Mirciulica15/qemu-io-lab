// SPDX-License-Identifier: GPL-2.0
/*
 * edu.c — REFERENCE SOLUTION for the edu driver lab.
 *
 * INSTRUCTOR ONLY. This file is NOT copied into the student kit (package.sh /
 * build-image.sh ship only labs/edu/{edu.c,Makefile,README.md}). It exists as
 * the grading reference and to prove the lab is solvable on the shipped image.
 *
 * Status: written to the QEMU edu datasheet; validate by building + running it
 * in the lab VM (see the build-image.sh verify step / verify.py extension).
 */
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/dma-mapping.h>
#include <linux/completion.h>
#include <linux/delay.h>

#define EDU_VENDOR_ID 0x1234
#define EDU_DEVICE_ID 0x11e8

#define EDU_REG_ID          0x00
#define EDU_REG_LIVENESS    0x04
#define EDU_REG_FACTORIAL   0x08
#define EDU_REG_STATUS      0x20
#define EDU_REG_IRQ_STATUS  0x24
#define EDU_REG_IRQ_RAISE   0x60
#define EDU_REG_IRQ_ACK     0x64
#define EDU_REG_DMA_SRC     0x80
#define EDU_REG_DMA_DST     0x88
#define EDU_REG_DMA_COUNT   0x90
#define EDU_REG_DMA_CMD     0x98

#define EDU_STATUS_COMPUTING   0x01
#define EDU_STATUS_IRQ_ON_FACT 0x80
#define EDU_DMA_BUF_ADDR       0x40000
#define EDU_DMA_BUF_SIZE       4096
#define EDU_DMA_START          0x01
#define EDU_DMA_DIR_TO_RAM     0x02
#define EDU_DMA_IRQ            0x04

#define EDU_WAIT_MS 2000

struct edu_dev {
	struct pci_dev   *pdev;
	void __iomem     *mmio;
	int               irq;
	struct completion irq_done;
};

/* Interrupt handler: read the cause, acknowledge it (mandatory — else it
 * re-fires), and wake the waiter. Generic across factorial- and DMA-completion. */
static irqreturn_t edu_irq(int irq, void *data)
{
	struct edu_dev *edu = data;
	u32 status = readl(edu->mmio + EDU_REG_IRQ_STATUS);

	if (!status)
		return IRQ_NONE;            /* not ours (shared INTx) */
	writel(status, edu->mmio + EDU_REG_IRQ_ACK);
	complete(&edu->irq_done);
	return IRQ_HANDLED;
}

static void edu_show_id(struct edu_dev *edu)
{
	u32 id = readl(edu->mmio + EDU_REG_ID);

	dev_info(&edu->pdev->dev, "ex1 id: 0x%08x (major %u, minor %u)\n",
		 id, (id >> 24) & 0xff, (id >> 16) & 0xff);
}

static int edu_liveness(struct edu_dev *edu)
{
	u32 v = 0xdeadbeef, back;

	writel(v, edu->mmio + EDU_REG_LIVENESS);
	back = readl(edu->mmio + EDU_REG_LIVENESS);
	dev_info(&edu->pdev->dev, "ex2 liveness: wrote 0x%08x read 0x%08x (~ = 0x%08x)\n",
		 v, back, ~v);
	return back == ~v ? 0 : -EIO;
}

static u32 edu_factorial_poll(struct edu_dev *edu, u32 n)
{
	writel(n, edu->mmio + EDU_REG_FACTORIAL);
	while (readl(edu->mmio + EDU_REG_STATUS) & EDU_STATUS_COMPUTING)
		cpu_relax();
	return readl(edu->mmio + EDU_REG_FACTORIAL);
}

static u32 edu_factorial_irq(struct edu_dev *edu, u32 n)
{
	writel(EDU_STATUS_IRQ_ON_FACT, edu->mmio + EDU_REG_STATUS);
	reinit_completion(&edu->irq_done);
	writel(n, edu->mmio + EDU_REG_FACTORIAL);
	if (!wait_for_completion_timeout(&edu->irq_done, msecs_to_jiffies(EDU_WAIT_MS)))
		dev_err(&edu->pdev->dev, "ex3b: factorial IRQ timed out\n");
	return readl(edu->mmio + EDU_REG_FACTORIAL);
}

static int edu_dma_once(struct edu_dev *edu, u64 src, u64 dst, u32 cmd)
{
	reinit_completion(&edu->irq_done);
	writeq(src, edu->mmio + EDU_REG_DMA_SRC);
	writeq(dst, edu->mmio + EDU_REG_DMA_DST);
	writeq((u64)EDU_DMA_BUF_SIZE, edu->mmio + EDU_REG_DMA_COUNT);
	writeq((u64)cmd, edu->mmio + EDU_REG_DMA_CMD);
	if (!wait_for_completion_timeout(&edu->irq_done, msecs_to_jiffies(EDU_WAIT_MS))) {
		dev_err(&edu->pdev->dev, "DMA timed out\n");
		return -ETIMEDOUT;
	}
	return 0;
}

static int edu_dma_demo(struct edu_dev *edu)
{
	dma_addr_t handle;
	u8 *buf;
	int i, ret;

	buf = dma_alloc_coherent(&edu->pdev->dev, EDU_DMA_BUF_SIZE, &handle, GFP_KERNEL);
	if (!buf)
		return -ENOMEM;

	for (i = 0; i < EDU_DMA_BUF_SIZE; i++)
		buf[i] = (u8)i;

	/* RAM -> device buffer, then device buffer -> RAM (after wiping RAM). */
	ret = edu_dma_once(edu, handle, EDU_DMA_BUF_ADDR, EDU_DMA_START | EDU_DMA_IRQ);
	if (ret)
		goto out;
	memset(buf, 0, EDU_DMA_BUF_SIZE);
	ret = edu_dma_once(edu, EDU_DMA_BUF_ADDR, handle,
			   EDU_DMA_START | EDU_DMA_DIR_TO_RAM | EDU_DMA_IRQ);
	if (ret)
		goto out;

	for (i = 0; i < EDU_DMA_BUF_SIZE; i++) {
		if (buf[i] != (u8)i) {
			dev_err(&edu->pdev->dev, "ex5 DMA mismatch at %d: 0x%02x\n", i, buf[i]);
			ret = -EIO;
			goto out;
		}
	}
	dev_info(&edu->pdev->dev, "ex5 DMA: %d-byte round trip verified\n", EDU_DMA_BUF_SIZE);
out:
	dma_free_coherent(&edu->pdev->dev, EDU_DMA_BUF_SIZE, buf, handle);
	return ret;
}

static int edu_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct edu_dev *edu;
	int ret;

	edu = devm_kzalloc(&pdev->dev, sizeof(*edu), GFP_KERNEL);
	if (!edu)
		return -ENOMEM;
	edu->pdev = pdev;
	init_completion(&edu->irq_done);
	pci_set_drvdata(pdev, edu);

	ret = pci_enable_device(pdev);
	if (ret)
		return ret;
	ret = pci_request_regions(pdev, "edu");
	if (ret)
		goto err_disable;
	edu->mmio = pci_iomap(pdev, 0, 0);
	if (!edu->mmio) {
		ret = -ENOMEM;
		goto err_regions;
	}
	ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(28));
	if (ret)
		goto err_unmap;
	pci_set_master(pdev);

	ret = pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_ALL_TYPES);
	if (ret < 0)
		goto err_unmap;
	edu->irq = pci_irq_vector(pdev, 0);
	ret = request_irq(edu->irq, edu_irq, IRQF_SHARED, "edu", edu);
	if (ret)
		goto err_vectors;

	/* run the exercises (results in dmesg) */
	edu_show_id(edu);
	if (edu_liveness(edu))
		dev_err(&pdev->dev, "ex2 liveness FAILED\n");
	dev_info(&pdev->dev, "ex3a factorial(5) poll = %u\n", edu_factorial_poll(edu, 5));
	dev_info(&pdev->dev, "ex3b factorial(5) irq  = %u\n", edu_factorial_irq(edu, 5));
	edu_dma_demo(edu);

	dev_info(&pdev->dev, "edu lab self-test complete\n");
	return 0;

err_vectors:
	pci_free_irq_vectors(pdev);
err_unmap:
	pci_iounmap(pdev, edu->mmio);
err_regions:
	pci_release_regions(pdev);
err_disable:
	pci_disable_device(pdev);
	return ret;
}

static void edu_remove(struct pci_dev *pdev)
{
	struct edu_dev *edu = pci_get_drvdata(pdev);

	free_irq(edu->irq, edu);
	pci_free_irq_vectors(pdev);
	pci_iounmap(pdev, edu->mmio);
	pci_release_regions(pdev);
	pci_disable_device(pdev);
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
MODULE_DESCRIPTION("Reference solution: edu PCI driver (I/O Systems lab)");
