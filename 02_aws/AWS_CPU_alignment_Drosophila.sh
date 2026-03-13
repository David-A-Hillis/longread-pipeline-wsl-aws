#!/bin/bash
set -euo pipefail

# Creator: David Hillis
# Date: 03/13/2026
# Purpose: alignment (Minimap2), and structural variant calling (Sniffles)

### B. CPU alignment + SV node (spot)
### 	Launch EC2:
### 		Type: c7i.4xlarge (spot)
### 		Storage: 500 GB gp3
### 		Same security group


### USER VARIABLES
S3_FASTQ="s3://dhillis-longread/Melanogaster/mel_400bps_reads.fastq"
S3_OUTPUT="s3://dhillis-longread/Melanogaster/"


### Setup tools:
sudo apt update && sudo apt install -y awscli samtools


### install minimap2 + sniffles via conda or prebuilt binaries
wget https://micro.mamba.pm/api/micromamba/linux-64/latest -O micromamba.tar.bz2
tar -xvjf micromamba.tar.bz2
./bin/micromamba shell init -s bash -r ~/micromamba
source ~/.bashrc
micromamba create -n longread -c conda-forge -c bioconda python=3.11
micromamba activate longread
micromamba install -c bioconda -c conda-forge minimap2 sniffles


### Convert BAM to FASTQ
aws s3 cp $S3_FASTQ ~/data/fastq/
mv ~/data/fastq/mel_400bps_reads.fastq ~/data/fastq/mel_400bps_reads.bam
samtools fastq ~/data/fastq/mel_400bps_reads.bam > ~/data/fastq/mel_400bps_reads.fastq


### Download Reference
wget -O ~/data/ref/BDGP6.fa.gz "https://ftp.ensembl.org/pub/release-115/fasta/drosophila_melanogaster/dna/Drosophila_melanogaster.BDGP6.54.dna.toplevel.fa.gz" 
gunzip ~/data/ref/BDGP6.fa.gz
samtools faidx ~/data/ref/BDGP6.fa


### Check the fastq file completed
ls -lh /data/fastq/HG007_subset_sup.fastq # Size should be roughly 10% of the original POD5 sizes (10-20)
grep -c '^@' /data/fastq/HG007_subset_sup.fastq # Should see counts into hundreds of thousands or more
head -10 /data/fastq/HG007_subset_sup.fastq # Should see standard header
tail -10 /data/fastq/HG007_subset_sup.fastq # Looks like garbage to me, but AI can tell if it is weird


### Align with minimap2:
micromamba activate longread
minimap2 -t 16 -ax map-ont ~/data/ref/BDGP6.fa \
  ~/data/fastq/mel_400bps_reads.fastq \
  | samtools view -b -o ~/data/align/melanogaster.bam

### Sort + index:
samtools sort -@ 16 -o ~/data/align/melanogaster.sorted.bam ~/data/align/melanogaster.bam
samtools index ~/data/align/melanogaster.sorted.bam

### Sync outputs to S3 (break up for spot instance):
aws s3 cp ~/data/align/melanogaster.sorted.bam $S3_OUTPUT
aws s3 cp ~/data/align/melanogaster.sorted.bam.bai $S3_OUTPUT

### Sniffles:
sniffles --input ~/data/align/melanogaster.sorted.bam \
         --vcf ~/data/sv/melanogaster.sniffles.vcf \
         --reference ~/data/ref/BDGP6.fa \
         --threads 16


### Check VCF
sudo apt install bcftools
bcftools view -H ~/data/sv/melanogaster.sniffles.vcf | cut -f8 | sed 's/;/\n/g' | grep '^SVTYPE=' | cut -d= -f2 | sort | uniq -c


### Sync outputs to S3:
aws s3 cp /data/sv/melanogaster.sniffles.vcf $S3_OUTPUT


### Terminate CPU instance.











