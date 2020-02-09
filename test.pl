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
	};
	
	it "writes uncompressed chunks" => sub
	{
		write_rand("$file", 0, SEED_1, 4 * 1024 * 1024);
		
		cisplit("$file", "$dir", "1000000");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.873d30f2d28efaa7eba71a3812ecc804e8390f6eab5231adcfbeb3ba4b6788af", "SHA-1"), "f2a1349a689c4259c3a9395cd5bfdc0443ca29c9");
		is(digest_file_hex("$dir/chunk.aaaaab.3e881f91acac77875a5f1679a4e4d26027c8b90ce3c57d8497ba4e2cc37569fd", "SHA-1"), "5f804e7fdb2941b761b6b7f2fab4e31214b2d7df");
		is(digest_file_hex("$dir/chunk.aaaaac.64e00281803d4493b518e1bf3e270f8f504c713bd710b9b6bda1833905795592", "SHA-1"), "8870268f02276fe9f81b992c18b002ac6f35bbb5");
		is(digest_file_hex("$dir/chunk.aaaaad.618c60519a82f0997634d4e3b6284f9762e7b654a439348e883faa44542b483b", "SHA-1"), "3a90d35d1caa8ee83572b8619826ce104689ac6f");
		is(digest_file_hex("$dir/chunk.aaaaae.31e27c22dc569aa899f51b8dbcf148f69b044ae9ad06edb9673207ce76637c24", "SHA-1"), "c5274b7ff6ca905200ee621e6518ee23bd07274e");
	};
	
	it "writes compressed chunks" => sub
	{
		write_rand("$file", 0, SEED_1, 4 * 1024 * 1024);
		
		cisplit("-z6", "$file", "$dir", "1000000");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.873d30f2d28efaa7eba71a3812ecc804e8390f6eab5231adcfbeb3ba4b6788af.gz", "SHA-1"), "eea62e650a31b72ded0898208043cd99f5b65db2");
		is(digest_file_hex("$dir/chunk.aaaaab.3e881f91acac77875a5f1679a4e4d26027c8b90ce3c57d8497ba4e2cc37569fd.gz", "SHA-1"), "72187e0aaa747f2a2d015fa4c38ec4f99346dbbf");
		is(digest_file_hex("$dir/chunk.aaaaac.64e00281803d4493b518e1bf3e270f8f504c713bd710b9b6bda1833905795592.gz", "SHA-1"), "94a61791f1df5fb81a90aed7e7297d08fe3fd1e1");
		is(digest_file_hex("$dir/chunk.aaaaad.618c60519a82f0997634d4e3b6284f9762e7b654a439348e883faa44542b483b.gz", "SHA-1"), "14d5b4b8b3b4200409c6fe8daeb561214afb2976");
		is(digest_file_hex("$dir/chunk.aaaaae.31e27c22dc569aa899f51b8dbcf148f69b044ae9ad06edb9673207ce76637c24.gz", "SHA-1"), "a357a38a14933f40676f505ee2d84068870cf049");
	};
	
	it "supports chunk sizes with 'k' suffix" => sub
	{
		write_rand("$file", 0, SEED_1, 4096);
		
		cisplit("$file", "$dir", "1k");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.f4f182a2b1bc569ec5b2166ac550a61e8539ed60bf3a0efd1c3c1d0961b5e09a", "SHA-1"), "393c2468edd206dddb1084961cec6d88a6459643");
		is(digest_file_hex("$dir/chunk.aaaaab.69f27d6652d95fc4b88773b8062281ba9bdd0353f3d6c16383412bee9c336c06", "SHA-1"), "2c30db27562c52df483134cf7d5c70c5a7bd7e81");
		is(digest_file_hex("$dir/chunk.aaaaac.a540a008c0aa63d5de7839947fbbff027530ddf9767a1516495e3bb1a1a6d823", "SHA-1"), "5afab69251e3ac8d93936eeea9539bab333ece17");
		is(digest_file_hex("$dir/chunk.aaaaad.538ed1ce80dfde8dc9a1d4c071753a4defb9bf8f77196e571b20ca92996c67f9", "SHA-1"), "1e770a0987379895955e2e5f948fbcdb0c9fc1f5");
	};
	
	it "supports chunk sizes with 'M' suffix" => sub
	{
		write_rand("$file", 0, SEED_1, 4 * 1024 * 1024);
		
		cisplit("$file", "$dir", "1M");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.8f7d8cb6817b412eab4649530a8f66fcdc575a2b2fbe41529045049d78ac03d5", "SHA-1"), "56fe1edf947ac459c4721c53132131428addc933");
		is(digest_file_hex("$dir/chunk.aaaaab.dd404cad72a27bcca8c15fe65ca347853ecf16a8d888fdc3defe361b74127179", "SHA-1"), "41f74d293fc8b2016340e7cf0e19b3b54400a6cc");
		is(digest_file_hex("$dir/chunk.aaaaac.1b1aa9541c7ee8c35d57d88ef5c705e78fdfe46aac2083319db243ebbcf49058", "SHA-1"), "2b812ea0a4d64490484a8af6dd88e850952d2d35");
		is(digest_file_hex("$dir/chunk.aaaaad.505a49af699c11d6a111329570b5f594e8bad909761dbd42ca99f35739960fb1", "SHA-1"), "cd5d870896b8f50faa907ffb969e9e737dc803ec");
	};
	
	it "leaves old/other files by default" => sub
	{
		write_rand("$file", 0, SEED_1, 4096);
		
		cisplit("$file", "$dir", "1024");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.f4f182a2b1bc569ec5b2166ac550a61e8539ed60bf3a0efd1c3c1d0961b5e09a", "SHA-1"), "393c2468edd206dddb1084961cec6d88a6459643");
		is(digest_file_hex("$dir/chunk.aaaaab.69f27d6652d95fc4b88773b8062281ba9bdd0353f3d6c16383412bee9c336c06", "SHA-1"), "2c30db27562c52df483134cf7d5c70c5a7bd7e81");
		is(digest_file_hex("$dir/chunk.aaaaac.a540a008c0aa63d5de7839947fbbff027530ddf9767a1516495e3bb1a1a6d823", "SHA-1"), "5afab69251e3ac8d93936eeea9539bab333ece17");
		is(digest_file_hex("$dir/chunk.aaaaad.538ed1ce80dfde8dc9a1d4c071753a4defb9bf8f77196e571b20ca92996c67f9", "SHA-1"), "1e770a0987379895955e2e5f948fbcdb0c9fc1f5");
		
		# Change some of the file
		write_rand("$file", 1536, SEED_2, 1024);
		
		cisplit("$file", "$dir", "1024");
		
		# New files
		is(digest_file_hex("$dir/chunk.aaaaaa.f4f182a2b1bc569ec5b2166ac550a61e8539ed60bf3a0efd1c3c1d0961b5e09a", "SHA-1"), "393c2468edd206dddb1084961cec6d88a6459643");
		is(digest_file_hex("$dir/chunk.aaaaab.ec8818b0083ea0f5d4bf5f1a24068c92dbef175dbc908ee32686611b414d58bb", "SHA-1"), "65127fae619c3181834a6754fa02af039978c8fe");
		is(digest_file_hex("$dir/chunk.aaaaac.edad3f8964aefe5c2db0119ae9994c8ef6b98813dd03a3364a4e735dca4c0ade", "SHA-1"), "fda934d59f5d95183387793082afd568b75b3ecd");
		is(digest_file_hex("$dir/chunk.aaaaad.538ed1ce80dfde8dc9a1d4c071753a4defb9bf8f77196e571b20ca92996c67f9", "SHA-1"), "1e770a0987379895955e2e5f948fbcdb0c9fc1f5");
		
		# Old files
		is(digest_file_hex("$dir/chunk.aaaaab.69f27d6652d95fc4b88773b8062281ba9bdd0353f3d6c16383412bee9c336c06", "SHA-1"), "2c30db27562c52df483134cf7d5c70c5a7bd7e81");
		is(digest_file_hex("$dir/chunk.aaaaac.a540a008c0aa63d5de7839947fbbff027530ddf9767a1516495e3bb1a1a6d823", "SHA-1"), "5afab69251e3ac8d93936eeea9539bab333ece17");
	};
	
	it "deletes old/other files if -d specified" => sub
	{
		write_rand("$file", 0, SEED_1, 4096);
		
		cisplit("$file", "$dir", "1024");
		
		is(digest_file_hex("$dir/chunk.aaaaaa.f4f182a2b1bc569ec5b2166ac550a61e8539ed60bf3a0efd1c3c1d0961b5e09a", "SHA-1"), "393c2468edd206dddb1084961cec6d88a6459643");
		is(digest_file_hex("$dir/chunk.aaaaab.69f27d6652d95fc4b88773b8062281ba9bdd0353f3d6c16383412bee9c336c06", "SHA-1"), "2c30db27562c52df483134cf7d5c70c5a7bd7e81");
		is(digest_file_hex("$dir/chunk.aaaaac.a540a008c0aa63d5de7839947fbbff027530ddf9767a1516495e3bb1a1a6d823", "SHA-1"), "5afab69251e3ac8d93936eeea9539bab333ece17");
		is(digest_file_hex("$dir/chunk.aaaaad.538ed1ce80dfde8dc9a1d4c071753a4defb9bf8f77196e571b20ca92996c67f9", "SHA-1"), "1e770a0987379895955e2e5f948fbcdb0c9fc1f5");
		
		# Change some of the file
		write_rand("$file", 1536, SEED_2, 1024);
		
		cisplit("-d", "$file", "$dir", "1024");
		
		# New files
		is(digest_file_hex("$dir/chunk.aaaaaa.f4f182a2b1bc569ec5b2166ac550a61e8539ed60bf3a0efd1c3c1d0961b5e09a", "SHA-1"), "393c2468edd206dddb1084961cec6d88a6459643");
		is(digest_file_hex("$dir/chunk.aaaaab.ec8818b0083ea0f5d4bf5f1a24068c92dbef175dbc908ee32686611b414d58bb", "SHA-1"), "65127fae619c3181834a6754fa02af039978c8fe");
		is(digest_file_hex("$dir/chunk.aaaaac.edad3f8964aefe5c2db0119ae9994c8ef6b98813dd03a3364a4e735dca4c0ade", "SHA-1"), "fda934d59f5d95183387793082afd568b75b3ecd");
		is(digest_file_hex("$dir/chunk.aaaaad.538ed1ce80dfde8dc9a1d4c071753a4defb9bf8f77196e571b20ca92996c67f9", "SHA-1"), "1e770a0987379895955e2e5f948fbcdb0c9fc1f5");
		
		# Old files
		ok(! -e "$dir/chunk.aaaaab.69f27d6652d95fc4b88773b8062281ba9bdd0353f3d6c16383412bee9c336c06");
		ok(! -e "$dir/chunk.aaaaac.a540a008c0aa63d5de7839947fbbff027530ddf9767a1516495e3bb1a1a6d823");
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
