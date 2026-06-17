# Out-of-tree kbuild for the edu lab driver. Run inside the lab VM:
#   make            build edu.ko against the running kernel
#   sudo insmod edu.ko ; dmesg | tail ; sudo rmmod edu
#   make clean
obj-m += edu.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
