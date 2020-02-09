#!/usr/bin/perl
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

use strict;
use warnings;

use Digest::file qw(digest_file_hex);
use Fcntl qw(SEEK_SET);
use File::Temp;
use Test::Spec;

use constant {
	SEED_1 => 1234,
	SEED_2 => 5678,
};

describe "cisplit" => sub
{
	my $file;
	my $dir;
	
	before each => sub
	{
		$file = File::Temp->new();
		$dir  = File::Temp->newdir();
		
		write_rand("$file", 0, SEED_1, 4 * 1024 * 1024);
	};
	
	it "writes uncompressed chunks" => sub
	{
		cisplit("$file", "$dir", "1000000");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.873d30f2d28efaa7eba71a3812ecc804e8390f6eab5231adcfbeb3ba4b6788af", "SHA-1"), "f2a1349a689c4259c3a9395cd5bfdc0443ca29c9");
		is(digest_file_hex("$dir/chunk.aaaaab.3e881f91acac77875a5f1679a4e4d26027c8b90ce3c57d8497ba4e2cc37569fd", "SHA-1"), "5f804e7fdb2941b761b6b7f2fab4e31214b2d7df");
		is(digest_file_hex("$dir/chunk.aaaaac.64e00281803d4493b518e1bf3e270f8f504c713bd710b9b6bda1833905795592", "SHA-1"), "8870268f02276fe9f81b992c18b002ac6f35bbb5");
		is(digest_file_hex("$dir/chunk.aaaaad.618c60519a82f0997634d4e3b6284f9762e7b654a439348e883faa44542b483b", "SHA-1"), "3a90d35d1caa8ee83572b8619826ce104689ac6f");
		is(digest_file_hex("$dir/chunk.aaaaae.31e27c22dc569aa899f51b8dbcf148f69b044ae9ad06edb9673207ce76637c24", "SHA-1"), "c5274b7ff6ca905200ee621e6518ee23bd07274e");
	};
	
	it "writes compressed chunks" => sub
	{
		cisplit("-z6", "$file", "$dir", "1000000");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.873d30f2d28efaa7eba71a3812ecc804e8390f6eab5231adcfbeb3ba4b6788af.gz", "SHA-1"), "eea62e650a31b72ded0898208043cd99f5b65db2");
		is(digest_file_hex("$dir/chunk.aaaaab.3e881f91acac77875a5f1679a4e4d26027c8b90ce3c57d8497ba4e2cc37569fd.gz", "SHA-1"), "72187e0aaa747f2a2d015fa4c38ec4f99346dbbf");
		is(digest_file_hex("$dir/chunk.aaaaac.64e00281803d4493b518e1bf3e270f8f504c713bd710b9b6bda1833905795592.gz", "SHA-1"), "94a61791f1df5fb81a90aed7e7297d08fe3fd1e1");
		is(digest_file_hex("$dir/chunk.aaaaad.618c60519a82f0997634d4e3b6284f9762e7b654a439348e883faa44542b483b.gz", "SHA-1"), "14d5b4b8b3b4200409c6fe8daeb561214afb2976");
		is(digest_file_hex("$dir/chunk.aaaaae.31e27c22dc569aa899f51b8dbcf148f69b044ae9ad06edb9673207ce76637c24.gz", "SHA-1"), "a357a38a14933f40676f505ee2d84068870cf049");
	};
};

# Write $length bytes of deterministic random data (derived from $seed) to
# filename $file at offset $off.
sub write_rand
{
	my ($file, $off, $seed, $length) = @_;
	
	my $v = $seed;
	
	open(my $fh, "+<", $file) or die $!;
	binmode($fh, ":raw");
	
	seek($fh, $off, SEEK_SET) or die $!;
	
	while($length > 0)
	{
		$v = (1103515245 * $v + 12345) % (1 << 31);
		
		if($length >= 4)
		{
			print {$fh} pack("L", $v);
			$length -= 4;
		}
		else{
			print {$fh} pack("C", ($v % 256));
			$length -= 1;
		}
	}
}

sub cisplit
{
	system("./cisplit", @_) and die "cisplit returned nonzero exit status\n";
}

runtests unless(caller);
