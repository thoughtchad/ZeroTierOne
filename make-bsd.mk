# This requires GNU make, which is typically "gmake" on BSD systems

INCLUDES=
DEFS=
LIBS=

include objects.mk
OBJS+=osdep/BSDEthernetTap.o ext/http-parser/http_parser.o

# Build with ZT_ENABLE_CLUSTER=1 to build with cluster support
ifeq ($(ZT_ENABLE_CLUSTER),1)
	DEFS+=-DZT_ENABLE_CLUSTER
endif

# "make debug" is a shortcut for this
ifeq ($(ZT_DEBUG),1)
	DEFS+=-DZT_TRACE
	CFLAGS+=-Wall -g -pthread $(INCLUDES) $(DEFS)
	LDFLAGS+=
	STRIP=echo
	# The following line enables optimization for the crypto code, since
	# C25519 in particular is almost UNUSABLE in heavy testing without it.
node/Salsa20.o node/SHA512.o node/C25519.o node/Poly1305.o: CFLAGS = -Wall -O2 -g -pthread $(INCLUDES) $(DEFS)
else
	CFLAGS?=-O3 -fstack-protector
	CFLAGS+=-Wall -fPIE -fvisibility=hidden -fstack-protector -pthread $(INCLUDES) -DNDEBUG $(DEFS)
	LDFLAGS+=-pie -Wl,-z,relro,-z,now
	STRIP=strip --strip-all
endif

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

# Build faster crypto on some targets
ifeq ($(ZT_USE_X64_ASM_SALSA2012),1)
	override DEFS+=-DZT_USE_X64_ASM_SALSA2012
	override OBJS+=ext/x64-salsa2012-asm/salsa2012.o
endif
ifeq ($(ZT_USE_ARM32_NEON_ASM_SALSA2012),1)
	override DEFS+=-DZT_USE_ARM32_NEON_ASM_SALSA2012
	override OBJS+=ext/arm32-neon-salsa2012-asm/salsa2012.o
endif

override DEFS+=-DZT_BUILD_PLATFORM=$(ZT_BUILD_PLATFORM) -DZT_BUILD_ARCHITECTURE=$(ZT_ARCHITECTURE) -DZT_SOFTWARE_UPDATE_DEFAULT="\"disable\""

CXXFLAGS+=$(CFLAGS) -fno-rtti -std=c++11 #-D_GLIBCXX_USE_C99 -D_GLIBCXX_USE_C99_MATH -D_GLIBCXX_USE_C99_MATH_TR1

all:	one

one:	$(OBJS) service/OneService.o one.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o zerotier-one $(OBJS) service/OneService.o one.o $(LIBS)
	$(STRIP) zerotier-one
	ln -sf zerotier-one zerotier-idtool
	ln -sf zerotier-one zerotier-cli

selftest:	$(OBJS) selftest.o
	$(CXX) $(CXXFLAGS) $(LDFLAGS) -o zerotier-selftest selftest.o $(OBJS) $(LIBS)
	$(STRIP) zerotier-selftest

clean:
	rm -rf *.o node/*.o controller/*.o osdep/*.o service/*.o ext/http-parser/*.o build-* zerotier-one zerotier-idtool zerotier-selftest zerotier-cli ZeroTierOneInstaller-* $(OBJS)

debug:	FORCE
	gmake -j 4 ZT_DEBUG=1

install:	one
	rm -f /app/vendor/bin/zerotier-one
	cp zerotier-one /usr/local/sbin
	ln -sf /app/vendor/bin/zerotier-one /app/vendor/bin/zerotier-cli
	ln -sf /app/vendor/bin/zerotier-one /app/vendor/bin/zerotier-idtool

uninstall:	FORCE
	rm -rf /app/vendor/bin/zerotier-one /app/vendor/bin/zerotier-cli /app/vendor/bin/zerotier-idtool /var/db/zerotier-one/zerotier-one.port /var/db/zerotier-one/zerotier-one.pid /var/db/zerotier-one/iddb.d

FORCE:
