/* cisplit - Content Identifiable File Splitter
 * Copyright (C) 2020 Daniel Collins <solemnwarning@solemnwarning.net>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 as published by
 * the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 51
 * Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#include <assert.h>
#include <errno.h>
#include <dirent.h>
#include <openssl/sha.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sysexits.h>
#include <unistd.h>
#include <zlib.h>

#define BUF_SIZE 256 * 1024
#define ARRAY_ALLOC_STEP 1024

static void print_usage(const char *argv0);

static int qsort_string_cmp(const void *a, const void *b);
static void array_push(char ***array, size_t *size, size_t *len, const char *string);
static void array_free(char **array, size_t len);

int main(int argc, char **argv)
{
	/* == Beginning of argument parsing. == */
	
	bool delete_old    = false;
	bool skip_existing = false;
	bool verbose       = false;
	
	bool comp_enable = false;
	const char *comp_suffix = "";
	
	int comp_level = Z_DEFAULT_COMPRESSION;
	
	int opt;
	while((opt = getopt(argc, argv, "dsvz0123456789")) != -1)
	{
		switch(opt)
		{
			case 'd':
				delete_old = true;
				break;
				
			case 's':
				skip_existing = true;
				break;
				
			case 'v':
				verbose = true;
				break;
				
			case 'z':
				comp_enable = true;
				comp_suffix = ".gz";
				break;
				
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
			case '8':
			case '9':
				comp_level = opt - '0';
				break;
				
			default:
				print_usage(argv[0]);
				return EX_USAGE;
		};
	}
	
	if((argc - optind) != 3)
	{
		print_usage(argv[0]);
		return EX_USAGE;
	}
	
	const char *in_file = argv[optind];
	const char *out_dir = argv[optind + 1];
	
	if(strcmp(in_file, "-") == 0)
	{
		in_file = "/dev/stdin";
	}
	
	char *endp;
	size_t chunk_size = strtoul(argv[optind + 2], &endp, 10);
	
	if(strcasecmp(endp, "K") == 0)
	{
		chunk_size *= 1024;
	}
	else if(strcasecmp(endp, "M") == 0)
	{
		chunk_size *= 1024 * 1024;
	}
	else if(*endp != '\0')
	{
		/* Unknown suffix. */
		chunk_size = 0;
	}
	
	if(chunk_size == 0)
	{
		fprintf(stderr, "Invalid chunk size '%s'\n", argv[optind + 2]);
		
		print_usage(argv[0]);
		return EX_USAGE;
	}
	
	/* == End of argument parsing == */
	
	FILE *in = fopen(in_file, "rb");
	if(in == NULL)
	{
		fprintf(stderr, "%s: %s\n", in_file, strerror(errno));
		return EX_NOINPUT;
	}
	
	/* We chdir() to the output directory so we can stat/open/unlink/etc target files without
	 * having to prefix the path.
	*/
	
	if(chdir(out_dir) != 0)
	{
		fprintf(stderr, "%s: %s\n", out_dir, strerror(errno));
		return EX_CANTCREAT;
	}
	
	unsigned char *in_buf = malloc(chunk_size);
	if(in_buf == NULL)
	{
		fprintf(stderr, "Cannot allocate memory\n");
		return EX_OSERR;
	}
	
	/* Output buffer receives zlib output if compression is enabled. */
	
	unsigned char *out_buf = NULL;
	if(comp_enable)
	{
		out_buf = malloc(BUF_SIZE);
		if(out_buf == NULL)
		{
			fprintf(stderr, "Cannot allocate memory\n");
			return EX_OSERR;
		}
	}
	
	unsigned int chunk_no = 0;
	size_t last_read;
	
	/* List of all files created or skipped, used to identify which files to unlink at the end
	 * if delete_old is enabled.
	*/
	char **my_files = NULL;
	size_t mf_size = 0, mf_len = 0;
	
	unsigned int created = 0, skipped = 0, removed = 0;
	
	do {
		/* TODO: Allow buffering large chunks in a file rather than in memory. */
		
		SHA256_CTX sha256;
		SHA256_Init(&sha256);
		
		size_t in_len = 0; /* Length of data in in_buf (i.e. chunk size) */
		
		do {
			last_read = fread(in_buf + in_len, 1, chunk_size - in_len, in);
			
			SHA256_Update(&sha256, in_buf + in_len, last_read);
			
			in_len += last_read;
		} while(in_len < chunk_size && last_read > 0);
		
		unsigned char hash[SHA256_DIGEST_LENGTH];
		SHA256_Final(hash, &sha256);
		
		if(in_len == 0)
		{
			/* No more data. */
			break;
		}
		
		/* Encode chunk number as a 6 character lowercase-only
		 * alphabetical string.
		 *
		 * The chunk ID is fixed-length and uses a single character
		 * type to ensure sort order is unambiguous.
		*/
		
		if(chunk_no > (26 * 26 * 26 * 26 * 26 * 26))
		{
			fprintf(stderr, "Too many chunks! Reduce input file size of increase chunk size\n");
			return EX_USAGE;
		}
		
		char id_s[8] = {
			('a' + (chunk_no / (26 * 26 * 26 * 26 * 26)) % 26),
			('a' + (chunk_no / (26 * 26 * 26 * 26     )) % 26),
			('a' + (chunk_no / (26 * 26 * 26          )) % 26),
			('a' + (chunk_no / (26 * 26               )) % 26),
			('a' + (chunk_no / (26                    )) % 26),
			('a' + (chunk_no                           ) % 26),
			
			'\0',
		};
		
		char hash_suffix[72] = { '.', '\0' };
		
		for(int ho = 0; ho < SHA256_DIGEST_LENGTH; ++ho)
		{
			sprintf(hash_suffix + 1 + (ho * 2), "%02x", hash[ho]);
		}
		
		char chunk_name[96];
		snprintf(chunk_name, sizeof(chunk_name), "chunk.%s%s%s", id_s, hash_suffix, comp_suffix);
		
		if(!skip_existing || access(chunk_name, F_OK) != 0)
		{
			char tmp_name[96];
			snprintf(tmp_name, sizeof(tmp_name), "%s.tmp", chunk_name);
			
			FILE *out = fopen(tmp_name, "wb");
			if(out == NULL)
			{
				fprintf(stderr, "Cannot open %s: %s\n", tmp_name, strerror(errno));
				return EX_CANTCREAT;
			}
			
			if(comp_enable)
			{
				/* Compression enabled.
				 * Compress and write buffer to output file.
				*/
				
				z_stream strm;
				
				strm.zalloc = Z_NULL;
				strm.zfree = Z_NULL;
				strm.opaque = Z_NULL;
				
				assert(deflateInit2(&strm, comp_level, Z_DEFLATED, (MAX_WBITS + 16), 8, Z_DEFAULT_STRATEGY) == Z_OK);
				
				strm.avail_in = in_len;
				strm.next_in = in_buf;
				
				int z_result;
				
				do {
					strm.avail_out = BUF_SIZE;
					strm.next_out  = out_buf;
					
					z_result = deflate(&strm, Z_FINISH);
					assert(z_result != Z_STREAM_ERROR);
					
					if(strm.avail_out < BUF_SIZE)
					{
						if(fwrite(out_buf, BUF_SIZE - strm.avail_out, 1, out) != 1)
						{
							fprintf(stderr, "Cannot write to %s: %s\n", tmp_name, strerror(errno));
							
							/* Don't leave an incomplete chunk around. */
							unlink(tmp_name);
							
							return EX_CANTCREAT;
						}
					}
				} while(strm.avail_out == 0 && z_result != Z_STREAM_END);
				
				assert(strm.avail_in == 0);
				
				deflateEnd(&strm);
			}
			else{
				/* Compression disabled.
				 * Write buffer to output file.
				*/
				
				if(fwrite(in_buf, in_len, 1, out) != 1)
				{
					fprintf(stderr, "Cannot write to %s: %s\n", tmp_name, strerror(errno));
					
					/* Don't leave incomplete chunk around. */
					unlink(tmp_name);
					
					return EX_CANTCREAT;
				}
			}
			
			if(fflush(out) != 0 || fclose(out) != 0)
			{
				/* Probably out of disk or some other write()
				 * error when flushing buffer.
				*/
				
				fprintf(stderr, "Cannot write to %s: %s\n", tmp_name, strerror(errno));
				
				/* Don't leave incomplete chunk around. */
				unlink(tmp_name);
				
				return EX_CANTCREAT;
			}
			
			if(rename(tmp_name, chunk_name) != 0)
			{
				fprintf(stderr, "Cannot create %s: %s\n", chunk_name, strerror(errno));
				
				/* Don't leave incomplete chunk around. */
				unlink(tmp_name);
				
				return EX_CANTCREAT;
			}
			
			if(verbose)
			{
				printf("Created '%s'\n", chunk_name);
				++created;
			}
		}
		else if(verbose)
		{
			printf("Skipping '%s'\n", chunk_name);
			++skipped;
		}
		
		if(delete_old)
		{
			array_push(&my_files, &mf_size, &mf_len, chunk_name);
		}
		
		++chunk_no;
	} while(last_read > 0);
	
	free(out_buf);
	free(in_buf);
	
	fclose(in);
	
	if(delete_old)
	{
		qsort(my_files, mf_len, sizeof(char*), &qsort_string_cmp);
		
		/* Build a sorted list of all regular files which exist in the output directory. */
		
		char **all_files = NULL;
		size_t af_size = 0, af_len = 0;
		
		DIR *dh = opendir("./");
		if(dh == NULL)
		{
			fprintf(stderr, "%s: %s\n", out_dir, strerror(errno));
			return EX_CANTCREAT;
		}
		
		struct dirent *d_node;
		while((d_node = readdir(dh)) != NULL)
		{
			struct stat st;
			if(lstat(d_node->d_name, &st) != 0)
			{
				fprintf(stderr, "Cannot lstat %s: %s\n", d_node->d_name, strerror(errno));
				continue;
			}
			
			if(S_ISREG(st.st_mode))
			{
				array_push(&all_files, &af_size, &af_len, d_node->d_name);
			}
		}
		
		closedir(dh);
		
		qsort(all_files, af_len, sizeof(char*), &qsort_string_cmp);
		
		/* Here we actually delete any redundant files.
		 *
		 * The list of valid files (my_files) and the list of all files (all_files) are
		 * both sorted, which means we can iterate through them together and avoid having
		 * to iterate through my_files repeatedly or do any complex searching.
		*/
		
		size_t mc_i = 0;
		for(size_t af_i = 0; af_i < af_len; ++af_i)
		{
			while(mc_i < mf_len && strcmp(all_files[af_i], my_files[mc_i]) > 0)
			{
				++mc_i;
			}
			
			if(mc_i >= mf_len || strcmp(all_files[af_i], my_files[mc_i]) != 0)
			{
				if(unlink(all_files[af_i]) != 0)
				{
					fprintf(stderr, "Unable to remove %s: %s\n", all_files[af_i], strerror(errno));
				}
				else{
					if(verbose)
					{
						printf("Removing '%s'\n", all_files[af_i]);
					}
					
					++removed;
				}
			}
		}
		
		array_free(all_files, af_len);
		array_free(my_files,  mf_len);
	}
	
	if(verbose)
	{
		printf("Total created: %u, skipped: %u, removed: %u\n", created, skipped, removed);
	}
	
	return 0;
}

static void print_usage(const char *argv0)
{
	fprintf(stderr, "Usage: %s [options] <input file/device> <output directory> <chunk size>\n", argv0);
	fprintf(stderr, "\n");
	fprintf(stderr, "  -d       Delete other files in output directory\n");
	fprintf(stderr, "  -s       Skip chunks that already exist\n");
	fprintf(stderr, "  -v       Output all chunks written/skipped/deleted\n");
	fprintf(stderr, "  -z       Compress chunks using gzip\n");
	fprintf(stderr, "  -0..9    Set gzip compression level\n");
}

static int qsort_string_cmp(const void *a, const void *b)
{
	return strcmp(*(const char**)(a), *(const char**)(b));
}

static void array_push(char ***array, size_t *size, size_t *len, const char *string)
{
	if(*size == *len)
	{
		*size += ARRAY_ALLOC_STEP;
		
		/* Check for multiplication overflow */
		if((SIZE_MAX / sizeof(char*)) < *size)
		{
			fprintf(stderr, "Cannot allocate memory");
			exit(EX_OSERR);
		}
		
		*array = realloc(*array, (*size * sizeof(char*)));
		if(*array == NULL)
		{
			fprintf(stderr, "Cannot allocate memory");
			exit(EX_OSERR);
		}
	}
	
	char *string_copy = strdup(string);
	if(string_copy == NULL)
	{
		fprintf(stderr, "Cannot allocate memory");
		exit(EX_OSERR);
	}
	
	(*array)[(*len)++] = string_copy;
}

static void array_free(char **array, size_t len)
{
	for(size_t i = 0; i < len; ++i)
	{
		free(array[i]);
	}
	
	free(array);
}
