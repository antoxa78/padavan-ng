ifndef ROOTDIR
ROOTDIR=../..
endif

include $(ROOTDIR)/user/shared/boards.mk

all:

clean:

romfs:
	mkdir -p $(INSTALLDIR)/usr/sbin/sqm
	$(ROMFSINST) -p +x /usr/sbin/sqm/common.sh
	$(ROMFSINST) -p +x /usr/sbin/sqm/start.sh
	$(ROMFSINST) -p +x /usr/sbin/sqm/apply.sh
	$(ROMFSINST) -p +x /usr/sbin/sqm/stop.sh
	$(ROMFSINST) -p +x /usr/sbin/sqm/wan_hook.sh
	$(ROMFSINST) -d actions /usr/sbin/sqm/actions
