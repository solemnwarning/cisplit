# cisplit - Content Identifiable File Splitter
# Copyright (C) 2020 Daniel Collins <solemnwarning@solemnwarning.net>
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 51
# Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Wrapper around the $(shell) function that aborts the build if the command
# exits with a nonzero status.
shell-or-die = \
	$(eval sod_out := $(shell $(1); echo $$?)) \
	$(if $(filter 0,$(lastword $(sod_out))), \
		$(wordlist 1, $(shell echo $$(($(words $(sod_out)) - 1))), $(sod_out)), \
		$(error $(1) exited with status $(lastword $(sod_out))))

CFLAGS += -std=gnu99

CFLAGS += $(call shell-or-die,pkg-config --cflags zlib openssl)
LIBS   += $(call shell-or-die,pkg-config --libs-only-L zlib openssl) -lz -lcrypto

.PHONY: all
all: cisplit

.PHONY: clean
clean:
	rm -f cisplit cisplit.o

cisplit: cisplit.o
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

cisplit.o: cisplit.c
	$(CC) $(CFLAGS) -c -o $@ $<
