#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<unistd.h>

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// vanhan 4k-intron kompressiosysteemi
int find_magic_byte(unsigned char *src, int len, int n);
int compress1(unsigned char *src, unsigned char *dest, int uclen);
int uncompress1(unsigned char *src, unsigned char *dest, int clen, int magic);

int compress1(unsigned char *src, unsigned char *dest, int uclen)
{
	int c, magic, magic2, magic3, complen=0;
//	int hdrsize;
	short backptr;
	char mbyte, mbyte2, mbyte3;
	unsigned int dws[8000];
	int dwc[8000] = {0};
	int n_dwords = 0;
//	FILE *head;

	magic = find_magic_byte(src, uclen, 1);
	if(magic==-1) return -1;
	mbyte = magic;

	magic2 = find_magic_byte(src, uclen, 2);
	if(magic2==-1) return -1;
	mbyte2 = magic2;

	magic3 = find_magic_byte(src, uclen, 3);
	if(magic3==-1) return -1;
	mbyte3 = magic3;

	for(c=0;c<uclen-3;c++){
	      int d=0;
	      int dword = (*((unsigned int *)src + c)) & 0xffffffff;
	      
	      // jos dword jo taulukossa, niin kasvata coutteria, muuten lis‰‰ tauluun
	      while(-1){
		    if(d>=n_dwords){
			  n_dwords++;
			  dws[d] = dword;
			  dwc[d] = 1;
			  break;
		    }
		    if(dword  == dws[d]){
			  dwc[d]++;
			  break;
		    }
		    d++;
	      }
	}
	
//	fprintf(stderr, "\n");
	
	for(c=0;c<n_dwords;c++){
	      if(dwc[c]>2){
//			fprintf(stderr, "%.8x (%d)\n", dws[c], dwc[c]);
	      }
	}
	
	
	// lue pohjalle headeri
//	head = fopen("cdh", "rb");
//	hdrsize = fread(dest, 1, 1000, head);
//	complen+=hdrsize;

	// magicbyte oikeeseen kohtaan
//	dest[0x5b] = (unsigned char)mbyte;

	for(c=0;;){
	      int best_len=0, best_start=0;
	      int match_search_start=0, d;
	      
	      if(c>4095)
		    match_search_start = c - 4095;

//	      if(c<(uclen-1) && src[c]==2 && src[c+1]==0){
	      if(0){
		    fprintf(stderr, "\nfop");
		    dest[complen++] = mbyte3;
		    c+=2;
	      }
	      else{
		    // sarja nollia enkoodataan yhteen byteen
		    if(c<(uclen-2) && src[c]==0 && src[c+1]==0 && src[c+2]==0){
//			  fprintf(stderr, "\nfap");
			  dest[complen++] = mbyte2;
			  c+=3;
		    }
		    else{
			  // etsi pisin match
			  for(d=match_search_start;d<c;d++){
				int curr_len=0;
				
				// laske d;st‰ alkavan matchin pituus, jos paras niin
				while(-1){
				      if(src[c+curr_len]==src[d+curr_len] && curr_len<(16+3) &&
					 (d+curr_len)<c){
					    curr_len++;
				      }
				      else{
					    if(curr_len>best_len){
						  best_start=d;
						  best_len=curr_len;
					    }
					    break;
				      }
				}
			  }
			  //	fprintf(stderr, "%d %d\n", best_len, best_start);
			  
			  // riitt‰v‰n pitk‰ matchi koodataan, muuten tavu ulos raakana
			  if(best_len<4){
				//tavu normaalisti ulos
				dest[complen]=src[c++];
				complen++;
			  }
			  else{
				// repeattia
				backptr = ((c-best_start)<<4 | (best_len-4));
				dest[complen++] = mbyte;
				dest[complen++] = backptr & 0xff;
				dest[complen++] = backptr >> 8;
				c+=best_len;
			  }
		    }
	      }
	      if(c>=uclen) return complen; // kun kaikki on pakattu, palautetaan pakatun koko
	}
	return -1; // terror, t‰nne ei pit‰is p‰‰ty‰
}

int uncompress1(unsigned char *src, unsigned char *dest, int clen, int magic)
{
	unsigned char mbyte;
	int c=0, d=0, e=0;

	mbyte = magic;

	for(c=0;c<clen;){
		if(src[c]==mbyte){
			int rptr=0, rc;

			fprintf(stderr, "pos: %d jmp: %d rep: %d\n", d, src[c+2], src[c+1]);

			rptr = d - ((src[c+2]<<4) + (src[c+1]>>4));
			rc = (src[c+1] & 0x0f) + 4;
			for(e=rptr;e<(rptr+rc);e++){
				dest[d++] = dest[e];
			}
			c+=3;
		}
		else{
			dest[d++] = src[c++];
		}
	}
	return d;
}

int find_magic_byte(unsigned char *src, int len, int n)
{
	int bytecount[256]={0};
	int c, mbytes=0, foo=0;

	for(c=0;c<len;c++)
		bytecount[src[c]]++;

	for(c=0;c<256;c++){ 
		if(bytecount[c]==0) mbytes++;
//		fprintf(stderr, "\n%d: %d", c, bytecount[c]);
	}

//	fprintf(stderr, "\nmbs: %d", mbytes);


	for(c=0;c<256;c++)
		if(bytecount[c]==0){
			foo++;
			if(foo==n){
				fprintf(stderr, "\nmagic: %x\n", c);
				return c;
			}
		}

	return -1; // ei lˆyty taikabyte‰, pahus sent‰‰n
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// mitenk‰h‰n LZ pelais?
int compress2(unsigned char *src, unsigned char *dest, int uclen);
int uncompress2(unsigned char *src, unsigned char *dest, int clen);

// palauta, kuinka mones jono on dictionaryssa, jos ei ole dictiss‰ ollenkaan niin -1
int in_dict(unsigned char *dict, int dictsize, int magic, unsigned char *prev, int prevsize)
{
	int c, dpos=0, prevpos=0, d_elem_c=0;
	
	if(prevsize==0) return -1;

	for(c=0;c<dictsize;){
		if(dict[dpos] == magic){
			prevpos=0;
			d_elem_c++;
			dpos++;
			c++;
			if(d_elem_c == dictsize)
				return -1;
		}
		if(dict[dpos] == prev[prevpos]){
			dpos++;
			prevpos++;
			if(prevpos==prevsize && dict[dpos]==magic)
				return d_elem_c;
		}
		else{
			while(dict[dpos++]!=magic);
			d_elem_c++;
			c++;
			prevpos=0;
		}
	}
	return -1;
}

int dict_add(unsigned char *dict, int dictsize, int magic, unsigned char *prev, int prevsize)
{
	int c=0, foo=0;

	while(c<dictsize) if(dict[foo++] == magic) c++;

	for(c=0;c<prevsize;c++) dict[foo++] = prev[c];
	dict[foo] = magic;

	fprintf(stderr, "\ndict_add 0x%x: ", dictsize);
//	fwrite(prev, 1, prevsize, stderr);

	return 0;
}

int compress2(unsigned char *src, unsigned char *dest, int uclen){
	unsigned char prev[512];
	int prev_num=0, dictpos=0, dictsize;
	unsigned char dict[65536*8];

	int clen=0;
	int c, magic;

	magic = find_magic_byte(src, uclen, 1);
	if (magic==-1) exit(1);

	//alusta dict (kaikki bytet yhden merkin mittaisina jonoina)
	for(c=0;c<256;c++){
		dict[c*2] = c;
		dict[c*2+1] = magic;
	}
	dictsize = 256;
			
	c=0;
	while(-1){
		int foo;

		prev[prev_num] = src[c];

		// jos ei dictionaryssa, nii ulos pointteri n_prev - viim. merkki -sekvenssin
		// kohtaan dictionaryssa (ei pointterii oikeestaan, vaan indeksi), muuten 
		// jatketaan vaan
		fprintf(stderr, "\n in-dict? ");
//		fwrite(prev, 1, prev_num+1, stderr);

		foo = in_dict(dict, dictsize, magic, prev, prev_num+1);
		fprintf(stderr, " 0x%x", foo);
		if(foo == -1){
			// ulos pointteri
			dest[clen++] = dictpos&0xff; // viimeisen matchin pos dictionaryssa
			dest[clen++] = dictpos>>8;
			fprintf(stderr, "\nout: 0x%x", dictpos);

			// ja lis‰‰ dictiin
			dict_add(dict, dictsize, magic, prev, prev_num+1);
			dictsize++;

			prev_num=0;
			dictpos=0;

//			prev[0] = prev[prev_num];
//			prev_num = 1;
		}
		else{
			prev_num++;
			dictpos = foo;
			c++;
			if(c==uclen){
				dest[clen++] = dictpos&0xff; 
				dest[clen++] = dictpos>>8;
				fprintf(stderr, "\nout: 0x%x\n done.\n", dictpos);
				fprintf(stderr, "dict. entries: %d\n", dictsize);
				return clen;
			}
		}
	}
	
	return clen;
}

int uncompress2(unsigned char *src, unsigned char *dest, int clen){
	return 0;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

int main(int argc, char **argv)
{
	unsigned char *uncompr, *compr;
	int uncomp_len, comp_len, method;
	
	uncompr = (unsigned char *)malloc(65536); // tarpeex 
	compr = (unsigned char *)malloc(65536); 

	uncomp_len = fread(uncompr, 1, 65536, stdin); 

	if(argc<2) exit(1);

	sscanf(argv[1], "%d", &method);

	// palautetaanko vain taikaluku?
	if(argc>2){
		if(strcmp(argv[2], "-m1")==0){
			int m;
			m = find_magic_byte(uncompr, uncomp_len, 1);
			printf("%d", m);
			return 0;
		}
		if(strcmp(argv[2], "-m2")==0){
			int m;
			m = find_magic_byte(uncompr, uncomp_len, 2);
			printf("%d", m);
			return 0;
		}
		if(strcmp(argv[2], "-d")==0 && argc>2){
			int magic=0;

			// pura kama
			switch(method){
			case 1:
				sscanf(argv[3], "%d", &magic);
				comp_len = uncompress1(uncompr, compr, uncomp_len, magic);
				break;
			case 2:
				comp_len = uncompress2(uncompr, compr, uncomp_len);
				break;
			default:
				exit(1);
			}

			fwrite(compr, 1, comp_len, stdout);
			return 0;
		}
	}

	switch(method){
	case 1:
		comp_len = compress1(uncompr, compr, uncomp_len);
		break;
	case 2:
		comp_len = compress2(uncompr, compr, uncomp_len);
		break;
	default:
		exit(1);
	}
	
	fprintf(stderr, " [ uncomp: %d comp: %d (%.4f%%) ]\n", uncomp_len, comp_len,
		(((float)comp_len)/uncomp_len) * 100);
	
	fwrite(compr, 1, comp_len, stdout);
	
	return 0;
}
