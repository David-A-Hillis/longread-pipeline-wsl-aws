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
S3_FASTQ="s3://dhillis-longread/hg007/HG007_subset_sup.fastq"
S3_OUTPUT="s3://dhillis-longread/hg007/"


### Give Instance S3 Access (role)


### Setup tools:
sudo apt update && sudo apt install -y awscli samtools


# install minimap2 + sniffles via conda or prebuilt binaries
wget https://micro.mamba.pm/api/micromamba/linux-64/latest -O micromamba.tar.bz2
tar -xvjf micromamba.tar.bz2
./bin/micromamba shell init -s bash -r ~/micromamba
source ~/.bashrc
micromamba create -n longread -c conda-forge -c bioconda python=3.11
micromamba activate longread
micromamba install -c bioconda -c conda-forge minimap2 sniffles


### Pull FASTQ + reference:
mkdir data
sudo chown -R ubuntu:ubuntu ~/data
mkdir -p ~/data/{fastq,ref,align,sv}
aws s3 cp $S3_FASTQ ~/data/fastq/
mv ~/data/fastq/HG007_subset_sup.fastq ~/data/fastq/HG007_subset_sup.bam
samtools fastq ~/data/fastq/HG007_subset_sup.bam > ~/data/fastq/HG007_subset_sup.fastq
wget -O ~/data/ref/GRCh38.fa.gz "https://ftp.ensembl.org/pub/release-115/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.toplevel.fa.gz" 
gunzip ~/data/ref/GRCh38.fa.gz
samtools faidx ~/data/ref/GRCh38.fa


### Align with minimap2:
minimap2 -t 16 -ax map-ont ~/data/ref/GRCh38.fa \
  ~/data/fastq/HG007_subset_sup.fastq \
  | samtools view -b -o ~/data/align/HG007_subset.bam


### Sort + index:
samtools sort -@ 16 -o ~/data/align/HG007_subset.sorted.bam ~/data/align/HG007_subset.bam
samtools index ~/data/align/HG007_subset.sorted.bam


### Sync outputs to S3 (break up for spot instance):
aws s3 cp ~/data/align/HG007_subset.sorted.bam $S3_OUTPUT
aws s3 cp ~/data/align/HG007_subset.sorted.bam.bai $S3_OUTPUT


### Sniffles:
sniffles --input ~/data/align/HG007_subset.sorted.bam \
         --vcf ~/data/sv/HG007_subset.sniffles.vcf \
         --reference ~/data/ref/GRCh38.fa \
         --threads 16


### Sync outputs to S3:
aws s3 cp ~/data/sv/HG007_subset.sniffles.vcf s3://dhillis-longread/hg007/


### Check VCF
sudo apt install bcftools
bcftools view -H ~/data/sv/melanogaster.sniffles.vcf | cut -f8 | sed 's/;/\n/g' | grep '^SVTYPE=' | cut -d= -f2 | sort | uniq -c


### Terminate CPU instance.








