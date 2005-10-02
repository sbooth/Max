struct toc {
	int     min;
	int     sec;
	int     frame;
};

int
read_cddb_toc_from_drive(void)
{
	/* Do whatever is appropriate to read the TOC of the CD
	* into the cddb_toc[] structure array.
	*/
	return (tot_trks);
}

int
cddb_sum(int n)
{
	int     ret;
	
	/* For backward compatibility this algorithm must not change */
	
	ret = 0;
	
	while (n > 0) {
		ret = ret + (n % 10);
		n = n / 10;
	}
	
	return (ret);
}

unsigned long
cddb_discid(int tot_trks, toc *cddb_toc)
{
	int     i,
	t = 0,
	n = 0;
	
	/* For backward compatibility this algorithm must not change */
	
	i = 0;
	
	while (i < tot_trks) {
		n = n + cddb_sum((cddb_toc[i].min * 60) + cdtoc[i].sec);
		i++;
	}
	
	t = ((cddb_toc[tot_trks].min * 60) + cdtoc[tot_trks].sec) -
		((cddb_toc[0].min * 60) + cdtoc[0].sec);
	
	return ((n % 0xff) << 24 | t << 8 | tot_trks);
}

cddb_main()
{
	int tot_trks;
	
	tot_trks = read_cddb_toc_from_drive();
	printf("The discid is %08x", cddb_discid(tot_trks));
}