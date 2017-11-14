# Automagically pick clang or gcc, with preference for clang
# This is only done if we have not overridden these with an environment or CLI variable
ifeq ($(origin CC),default)
	CC=$(shell if [ -e /usr/bin/clang ]; then echo clang; else echo gcc; fi)
endif
ifeq ($(origin CXX),default)
	CXX=$(shell if [ -e /usr/bin/clang++ ]; then echo clang++; else echo g++; fi)
endif

INCLUDES?=
DEFS?=-D_FORTIFY_SOURCE=2
LDLIBS?=
DESTDIR?=

include objects.mk

# Use bundled http-parser since distribution versions are NOT API-stable or compatible!
# Trying to use dynamically linked libhttp-parser causes tons of compatibility problems.
OBJS+=ext/http-parser/http_parser.o

# Auto-detect miniupnpc and nat-pmp as well and use system libs if present,
# otherwise build into binary as done on Mac and Windows.
OBJS+=osdep/PortMapper.o
DEFS+=-DZT_USE_MINIUPNPC
MINIUPNPC_IS_NEW_ENOUGH=$(shell grep -sqr '.*define.*MINIUPNPC_VERSION.*"2.."' /usr/include/miniupnpc/miniupnpc.h && echo 1)
ifeq ($(MINIUPNPC_IS_NEW_ENOUGH),1)
	DEFS+=-DZT_USE_SYSTEM_MINIUPNPC
	LDLIBS+=-lminiupnpc
else
	DEFS+=-DMINIUPNP_STATICLIB -DMINIUPNPC_SET_SOCKET_TIMEOUT -DMINIUPNPC_GET_SRC_ADDR -D_BSD_SOURCE -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600 -DOS_STRING=\"Linux\" -DMINIUPNPC_VERSION_STRING=\"2.0\" -DUPNP_VERSION_STRING=\"UPnP/1.1\" -DENABLE_STRNATPMPERR
	OBJS+=ext/miniupnpc/connecthostport.o ext/miniupnpc/igd_desc_parse.o ext/miniupnpc/minisoap.o ext/miniupnpc/minissdpc.o ext/miniupnpc/miniupnpc.o ext/miniupnpc/miniwget.o ext/miniupnpc/minixml.o ext/miniupnpc/portlistingparse.o ext/miniupnpc/receivedata.o ext/miniupnpc/upnpcommands.o ext/miniupnpc/upnpdev.o ext/miniupnpc/upnperrors.o ext/miniupnpc/upnpreplyparse.o
endif
ifeq ($(wildcard /usr/include/natpmp.h),)
	OBJS+=ext/libnatpmp/natpmp.o ext/libnatpmp/getgateway.o
else
	LDLIBS+=-lnatpmp
	DEFS+=-DZT_USE_SYSTEM_NATPMP
endif

ifeq ($(ZT_ENABLE_CLUSTER),1)
	DEFS+=-DZT_ENABLE_CLUSTER
endif

ifeq ($(ZT_SYNOLOGY), 1)
	DEFS+=-D__SYNOLOGY__
endif

ifeq ($(ZT_TRACE),1)
	DEFS+=-DZT_TRACE
endif

ifeq ($(ZT_RULES_ENGINE_DEBUGGING),1)
	DEFS+=-DZT_RULES_ENGINE_DEBUGGING
endif

ifeq ($(ZT_DEBUG),1)
	DEFS+=-DZT_TRACE
	override CFLAGS+=-Wall -g -O -pthread $(INCLUDES) $(DEFS)
	override CXXFLAGS+=-Wall -g -O -std=c++11 -pthread $(INCLUDES) $(DEFS)
	override LDFLAGS+=
	STRIP?=echo
	# The following line enables optimization for the crypto code, since
	# C25519 in particular is almost UNUSABLE in -O0 even on a 3ghz box!
node/Salsa20.o node/SHA512.o node/C25519.o node/Poly1305.o: CFLAGS = -Wall -O2 -g -pthread $(INCLUDES) $(DEFS)
else
	CFLAGS?=-O3 -fstack-protector
	override CFLAGS+=-Wall -fPIE -pthread $(INCLUDES) -DNDEBUG $(DEFS)
	CXXFLAGS?=-O3 -fstack-protector
	override CXXFLAGS+=-Wall -Wno-unused-result -Wreorder -fPIE -std=c++11 -pthread $(INCLUDES) -DNDEBUG $(DEFS)
	override LDFLAGS+=-pie -Wl,-z,relro,-z,now
	STRIP?=strip
	STRIP+=--strip-all
endif

# Uncomment for gprof profile build
#CFLAGS=-Wall -g -pg -pthread $(INCLUDES) $(DEFS)
#CXXFLAGS=-Wall -g -pg -pthread $(INCLUDES) $(DEFS)
#LDFLAGS=
#STRIP=echo

# Determine system build architecture from compiler target
CC_MACH=$(shell $(CC) -dumpmachine | cut -d '-' -f 1)
ZT_ARCHITECTURE=999
ifeq ($(CC_MACH),x86_64)
        ZT_ARCHITECTURE=2
	ZT_USE_X64_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),amd64)
        ZT_ARCHITECTURE=2
	ZT_USE_X64_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),i386)
        ZT_ARCHITECTURE=1
endif
ifeq ($(CC_MACH),i686)
        ZT_ARCHITECTURE=1
endif
ifeq ($(CC_MACH),arm)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),armel)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),armhf)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),armv6)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),armv6zk)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),armv6kz)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),armv7)
        ZT_ARCHITECTURE=3
	override DEFS+=-DZT_NO_TYPE_PUNNING
	ZT_USE_ARM32_NEON_ASM_SALSA2012=1
endif
ifeq ($(CC_MACH),arm64)
        ZT_ARCHITECTURE=4
	override DEFS+=-DZT_NO_TYPE_PUNNING
endif
ifeq ($(CC_MACH),aarch64)
        ZT_ARCHITECTURE=4
	override DEFS+=-DZT_NO_TYPE_PUNNING
endif
ifeq ($(CC_MACH),mipsel)
        ZT_ARCHITECTURE=5
	override DEFS+=-DZT_NO_TYPE_PUNNING
endif
ifeq ($(CC_MACH),mips)
        ZT_ARCHITECTURE=5
	override DEFS+=-DZT_NO_TYPE_PUNNING
endif
ifeq ($(CC_MACH),mips64)
        ZT_ARCHITECTURE=6
	override DEFS+=-DZT_NO_TYPE_PUNNING
endif
ifeq ($(CC_MACH),mips64el)
        ZT_ARCHITECTURE=6
	override DEFS+=-DZT_NO_TYPE_PUNNING
endif

# Fail if system architecture could not be determined
ifeq ($(ZT_ARCHITECTURE),999)
ERR=$(error FATAL: architecture could not be determined from $(CC) -dumpmachine: $CC_MACH)
.PHONY: err
err: ; $(ERR)
endif

# Disable software updates by default on Linux since that is normally done with package management
override DEFS+=-DZT_BUILD_PLATFORM=1 -DZT_BUILD_ARCHITECTURE=$(ZT_ARCHITECTURE) -DZT_SOFTWARE_UPDATE_DEFAULT="\"disable\""

# Build faster crypto on some targets
ifeq ($(ZT_USE_X64_ASM_SALSA2012),1)
	override DEFS+=-DZT_USE_X64_ASM_SALSA2012
	override OBJS+=ext/x64-salsa2012-asm/salsa2012.o
endif
ifeq ($(ZT_USE_ARM32_NEON_ASM_SALSA2012),1)
	override DEFS+=-DZT_USE_ARM32_NEON_ASM_SALSA2012
	override OBJS+=ext/arm32-neon-salsa2012-asm/salsa2012.o
endif

# Static builds, which are currently done for a number of Linux targets
ifeq ($(ZT_STATIC),1)
	override LDFLAGS+=-static
	ifeq ($(ZT_ARCHITECTURE),3)
		ifeq ($(ZT_ARM_SOFTFLOAT),1)
			override CFLAGS+=-march=armv5te -mfloat-abi=soft -msoft-float -mno-unaligned-access -marm
			override CXXFLAGS+=-march=armv5te -mfloat-abi=soft -msoft-float -mno-unaligned-access -marm
		else
			override CFLAGS+=-march=armv6kz -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard -mno-unaligned-access -marm
			override CXXFLAGS+=-march=armv6kz -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard -mno-unaligned-access -marm
		endif
	endif
endif

all:	one

one:	$(OBJS) service/OneService.o one.o osdep/LinuxEthernetTap.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o zerotier-one $(OBJS) service/OneService.o one.o osdep/LinuxEthernetTap.o $(LDLIBS)
	$(STRIP) zerotier-one
	ln -sf zerotier-one zerotier-idtool
	ln -sf zerotier-one zerotier-cli

selftest:	$(OBJS) selftest.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o zerotier-selftest selftest.o $(OBJS) $(LDLIBS)
	$(STRIP) zerotier-selftest

manpages:	FORCE
	cd doc ; ./build.sh

doc:	manpages

clean: FORCE
	rm -rf *.so *.o node/*.o controller/*.o osdep/*.o service/*.o ext/http-parser/*.o ext/miniupnpc/*.o ext/libnatpmp/*.o $(OBJS) zerotier-one zerotier-idtool zerotier-cli zerotier-selftest build-* ZeroTierOneInstaller-* *.deb *.rpm .depend debian/files debian/zerotier-one*.debhelper debian/zerotier-one.substvars debian/*.log debian/zerotier-one doc/node_modules

distclean:	clean

realclean:	distclean

debug:	FORCE
	make ZT_DEBUG=1 one
	make ZT_DEBUG=1 selftest

# Note: keep the symlinks in /app/vendor/zerotier-one to the binaries since these
# provide backward compatibility with old releases where the binaries actually
# lived here. Folks got scripts.

install:	FORCE
	mkdir -p $(DESTDIR)/usr/sbin
	rm -f $(DESTDIR)/app/vendor/bin/zerotier-one
	cp -f zerotier-one $(DESTDIR)/app/vendor/bin/zerotier-one
	rm -f $(DESTDIR)/app/vendor/bin/zerotier-cli
	rm -f $(DESTDIR)/app/vendor/bin/zerotier-idtool
	ln -s zerotier-one $(DESTDIR)/app/vendor/bin/zerotier-cli
	ln -s zerotier-one $(DESTDIR)/app/vendor/bin/zerotier-idtool
	mkdir -p $(DESTDIR)/app/vendor/zerotier-one
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-one
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-cli
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-idtool
	ln -s ../../../app/vendor/bin/zerotier-one $(DESTDIR)/app/vendor/zerotier-one/zerotier-one
	ln -s ../../../app/vendor/bin/zerotier-one $(DESTDIR)/app/vendor/zerotier-one/zerotier-cli
	ln -s ../../../app/vendor/bin/zerotier-one $(DESTDIR)/app/vendor/zerotier-one/zerotier-idtool
	mkdir -p $(DESTDIR)/usr/share/man/man8
	rm -f $(DESTDIR)/usr/share/man/man8/zerotier-one.8.gz
	cat doc/zerotier-one.8 | gzip -9 >$(DESTDIR)/usr/share/man/man8/zerotier-one.8.gz
	mkdir -p $(DESTDIR)/usr/share/man/man1
	rm -f $(DESTDIR)/usr/share/man/man1/zerotier-idtool.1.gz
	rm -f $(DESTDIR)/usr/share/man/man1/zerotier-cli.1.gz
	cat doc/zerotier-cli.1 | gzip -9 >$(DESTDIR)/usr/share/man/man1/zerotier-cli.1.gz
	cat doc/zerotier-idtool.1 | gzip -9 >$(DESTDIR)/usr/share/man/man1/zerotier-idtool.1.gz

# Uninstall preserves identity.public and identity.secret since the user might
# want to save these. These are your ZeroTier address.

uninstall:	FORCE
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-one
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-cli
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-idtool
	rm -f $(DESTDIR)/app/vendor/bin/zerotier-cli
	rm -f $(DESTDIR)/app/vendor/bin/zerotier-idtool
	rm -f $(DESTDIR)/app/vendor/bin/zerotier-one
	rm -rf $(DESTDIR)/app/vendor/zerotier-one/iddb.d
	rm -rf $(DESTDIR)/app/vendor/zerotier-one/updates.d
	rm -rf $(DESTDIR)/app/vendor/zerotier-one/networks.d
	rm -f $(DESTDIR)/app/vendor/zerotier-one/zerotier-one.port
	rm -f $(DESTDIR)/usr/share/man/man8/zerotier-one.8.gz
	rm -f $(DESTDIR)/usr/share/man/man1/zerotier-idtool.1.gz
	rm -f $(DESTDIR)/usr/share/man/man1/zerotier-cli.1.gz

# These are just for convenience for building Linux packages

debian:	FORCE
	debuild -I -i -us -uc -nc -b

redhat:	FORCE
	rpmbuild -ba zerotier-one.spec

FORCE:
