ifndef ROOTDIR
ROOTDIR=../..
endif

include $(ROOTDIR)/user/shared/boards.mk

all:

clean:

romfs:
	mkdir -p $(INSTALLDIR)/usr/sbin/adblock
	$(ROMFSINST) /usr/sbin/adblock/start.sh
	$(ROMFSINST) -p +x /usr/sbin/adblock/save.sh
	$(ROMFSINST) /usr/sbin/adblock/update.sh
	$(ROMFSINST) /usr/sbin/adblock/watchdog.sh
	$(ROMFSINST) /usr/sbin/adblock/pause.sh
	$(ROMFSINST) /usr/sbin/adblock/resume.sh
	$(ROMFSINST) /usr/sbin/adblock/restart.sh
	$(ROMFSINST) /usr/sbin/adblock/stop.sh
	$(ROMFSINST) /usr/sbin/adblock/rollback.sh
	$(ROMFSINST) /usr/sbin/adblock/stats.sh
	$(ROMFSINST) -p +x /usr/sbin/adblock/stats_collect.sh
	$(ROMFSINST) -d actions /usr/sbin/adblock/actions
	$(ROMFSINST) -d defaults /usr/sbin/adblock/defaults
