# cisplit

## What is this?

`cisplit` is a program which splits files up as per the UNIX `split` command, except with some minor additional features:

* Chunk filenames include checksum of chunk
* Chunks may be individually compressed
* Existing chunks may be skipped
* Obsolete chunks may be deleted

## Why did I write this?

I wrote this for taking backups of large files/block devices which only change incrementally, specifically Virtual Machine disk images. The disks are periodically split and compressed to a directory, which is then backed up using `rsync`, giving differential backups and only copying chunks which have been modified.

This is faster than `rsync --checksum`, since the checksum need only be calculated on the sender and is embedded in the filename. It also avoids having to dump the entire disk again, since `cisplit` can skip writing out chunks when they already exist.

Having to copy to a local disk before running `rsync` isn't ideal. I was intending to also support sending directly to an rsync server (over SSH), but the rsync protocol doesn't seem to allow this (have to know the size of all files up front), if I've misunderstood how the protocol works or there is a way to do this I'd love to hear about it.

Other protocols or file storage methods may be added in the future. For the time being I kept it nice and dumb to make restoring backups easy; who wants to install half a dozen obscure programs when they're trying to recover a system from a livecd (or even worse, an initramfs)?

## Installing

Download the source and run `make` followed by `make install`.

You will need OpenSSL and zlib installed (including development packages).

## Example usage

Dumping and restoring a disk:

    # cisplit /dev/XXX /mnt/backup/
    # for f in /mnt/backup/chunk.*; do cat "$f"; done > /dev/XXX

Dumping, compressing and restoring a disk:

    # cisplit -z /dev/XXX /mnt/backup/
    # for f in /mnt/backup/chunk.*; do zcat "$f"; done > /dev/XXX

Updating an existing backup:

    # cisplit -zsd /dev/XXX /mnt/backup/

For more details, read the `man` page.
