#!/bin/bash
set -euo pipefail

# Creator: David Hillis
# Date: 03/05/2026
# Purpose: Run long-read basecalling (Dorado), alignment (Minimap2), assembly (Flye), and structural variant calling (Sniffles)

### Code used for setting up WSL 2 and environments:

### Download WSL2 and Ubuntu together
wsl --install -d Ubuntu


### Perfom updates and install Curl and Git
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential wget curl git


### Download Mamba and initiate shell
wget https://micro.mamba.pm/api/micromamba/linux-64/latest -O micromamba.tar.bz2
tar -xvjf micromamba.tar.bz2
./bin/micromamba shell init -s bash -r ~/micromamba


### Run micromamba
source ~/.bashrc 
micromamba --version # unnecessary but good to remember how to get the version


### Create new environment (longread) and download conda-forge, Bioconda, and python version 3.11
micromamba create -n longread -c conda-forge -c bioconda python=3.11


### Activate the new environment (remember source ~/.bashrc must come first)
micromamba activate longread


### Perform essential downloads for the workflow
micromamba install -c bioconda -c conda-forge \
    minimap2 \
    flye \
    samtools \
    sniffles \
    bcftools \
    bedtools \
    seqkit


### Check key versions
minimap2 --version  # 2.30-r1287
flye --version      # 2.9.6-b1802
samtools --version  # 1.23
sniffles --version  # 2.7.2


### Make the necessary directories
mkdir -p ~/longread_project/{data,results,logs,scripts}


### Downloaded AWS-CLI v2
cd ~
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"


### Downloaded Unzip command code
sudo apt install unzip


### Unzipped, Installed, and retrieved version of AWS-CLI
unzip awscliv2.zip
sudo ./aws/install
aws --version # aws-cli/2.34.0 Python/3.13.11 Linux/6.6.87.2-microsoft-standard-WSL2 exe/x86_64.ubuntu.24


###############################################
## Dorado Model (Discontinued v3.5.2) Download
## This model is no longer available via:
##   dorado download --model <name>
## For reproducibility, it is hosted in a project S3 bucket.
## S3_MODEL_PATH="s3://dhillis-longread/dorado_models/dna_r10.4.1_e8.2_400bps_sup@v3.5.2"
###############################################

### Download dorado and add to ~/.bashrc (required for small-scale tests; large datasets recommended on GPU/AWS)
cd ~ 
wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.5.3-linux-x64.tar.gz 
tar -xvzf dorado-0.5.3-linux-x64.tar.gz
export PATH="$HOME/dorado-0.5.3-linux-x64/bin:$PATH"
source ~/.bashrc
dorado --version # 0.5.3+d9af343
dorado download --model dna_r10.4.1_e8.2_400bps_sup@v3.5.2 # Note: there are other models for methylation calls
mv ~/longread_project/data/dna_r10.4.1_e8.2_400bps_sup@v3.5.2 ~/.cache/dorado/models/


### Check RAM and CPU inside WSL2
free -h 
nproc   


### Download FAST5 Data (optional if using preprocessed FASTQ)
aws s3 cp --no-sign-request \
  s3://ont-open-data/contrib/melanogaster_bkim_2023.01/flowcells/D.melanogaster.R1041.400bps/D_melanogaster_1/20221217_1251_MN20261_FAV70669_117da01a/fast5/ \
  ~/longread_project/data/mel_400bps_fast5/ \
  --recursive

### Run a quick test to make sure dorado identifies the data
### This should produce a small fastq file
dorado basecaller dna_r10.4.1_e8.2_400bps_sup@v3.5.2 \
  --device cpu \
  --recursive \
  --emit-fastq \
  --max-reads 10 \
  ~/longread_project/data/mel_400bps_fast5 \
  > test.fastq


### This is much faster if you use GPU (may decrease runtime about 20x)
### First, download toolkit for using GPU
sudo apt update
sudo apt install nvidia-cuda-toolkit
nvcc --version # Build cuda_12.0.r12.0/compiler.32267302_0
dorado basecaller --device cuda:all

### Conversion from FAST5 or POD5 for faster analyses (10-20 minutes)
pip install pod5
mkdir ~/longread_project/data/mel_400bps_pod5
pod5 convert fast5 \
  ~/longread_project/data/mel_400bps_fast5 \
  ~/longread_project/data/mel_400bps_pod5


### Run dorado (SUP)
### Models: SUP (most accurate), HAC (faster), and Fast (fastest) options.
## This block is intentionally commented out because full POD5→FASTQ conversion 
## is not practical on CPU-only WSL2. The AWS GPU pipeline performs this step.
## This step is included for completeness but is not recommended for large ONT datasets.
## Use the AWS GPU pipeline for full-scale basecalling.

# ~/dorado-0.5.3-linux-x64/bin/dorado basecaller \
#   ~/.cache/dorado/models/dna_r10.4.1_e8.2_400bps_sup@v3.5.2 \
#   --device cpu \
#   --batchsize 8 \
#   --recursive \
#   ~/longread_project/data/mel_400bps_pod5 \
#   > ~/longread_project/data/mel_400bps_reads.fastq


### The POD5 → FASTQ conversion step is included for completeness, but full conversion of the D. melanogaster dataset exceeded the practical runtime of a local WSL2 environment. For downstream analyses, a publicly available ONT FASTQ dataset was used instead. The AWS pipeline contains the full GPU‑accelerated basecalling workflow.

### For Downloads from SRA, the SRA toolkit is best
wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-ubuntu64.tar.gz
tar -xvzf sratoolkit.current-ubuntu64.tar.gz
echo 'export PATH=$PATH:$HOME/Downloads/sratoolkit.current-ubuntu64/bin' >> ~/.bashrc
source ~/.bashrc
sudo apt install sra-toolkit
prefetch --version # 3.0.3 ( 3.0.2 )
fasterq-dump --version # 3.0.3 ( 3.0.2 )


###############################################
## Download Public FASTQ Dataset (Alternative Input)
###############################################

### Download data
mkdir -p ~/longread_project/data/SRR32117930
cd ~/longread_project/data/SRR32117930

prefetch SRR32117930
fasterq-dump SRR32117930 --threads 8 --split-spot
wc -l SRR32117930.fastq # This provides a line count which should be divisible by 4 (or its incomplete)


### Get the reference genome
mkdir -p ~/longread_project/reference
cd ~/longread_project/reference

wget ftp://ftp.ensembl.org/pub/release-115/fasta/drosophila_melanogaster/dna/Drosophila_melanogaster.BDGP6.54.dna.toplevel.fa.gz
gunzip Drosophila_melanogaster.BDGP6.54.dna.toplevel.fa.gz
minimap2 -d dm6.mmi Drosophila_melanogaster.BDGP6.54.dna.toplevel.fa # For indexing


###############################################
## Alignment and Structural Variant Calling
###############################################

### Align Reads
mkdir -p ~/longread_project/alignment
cd ~/longread_project/alignment
minimap2 -t 20 -ax map-ont ~/longread_project/reference/Drosophila_melanogaster.BDGP6.54.dna.toplevel.fa \
~/longread_project/data/SRR32117930/SRR32117930.fastq > ~/longread_project/alignment/SRR32117930.sam 

samtools sort -@ 20 ~/longread_project/alignment/SRR32117930.sam -o ~/longread_project/alignment/SRR32117930.sorted.bam
samtools index ~/longread_project/alignment/SRR32117930.sorted.bam


### Genome Assembly (not necessary if good a reference exists)
flye --nano-raw ~/longread_project/data/SRR32117930/SRR32117930.fastq --out-dir ~/longread_project/assembly --threads 20 --resume


### Call Structural variants
sniffles --input ~/longread_project/alignment/SRR32117930.sorted.bam \
         --vcf ~/longread_project/results/sniffles.vcf \
         --threads 20




###############################################
## Optional Analyses
## These steps are not required for the core SV pipeline
## but are included for users who want to extend the workflow.
###############################################

###############################################
### Install a Graph viewer (for Flye)
###############################################
# sudo apt update
# sudo apt install graphviz

# sfdp -Tpdf assembly_graph.gv -o assembly_graph.pdf
# explorer.exe assembly_graph.pdf # To view the graph


###############################################
### Run Kraken to identify contamination 
###############################################
# micromamba activate longread
# micromamba install -c bioconda -c conda-forge kraken2
# kraken2 --version # 2.17.1

## Standard Kraken database takes notable time and space
# kraken2-build --standard --db kraken2_db

## MiniKraken database (good for test runs)
# wget https://genome-idx.s3.amazonaws.com/kraken/k2_standard_08gb_20230605.tar.gz
# tar -xvzf k2_standard_08gb_20230605.tar.gz
# mkdir kraken2_db
# mv hash.k2d taxo.k2d opts.k2d seqid2taxid.map ktaxonomy.tsv inspect.txt database*kmer_distrib kraken2_db/

###############################################
### Extract sequences (5-200Kbp)
## This was used for a more direct look at certain sequences
###############################################

# seqkit seq -m 5000 -M 200000 assembly.fasta > contigs_5k_200k.fasta
# seqkit stats contigs_5k_200k.fasta # XX sequences

## Run Kraken
# kraken2 \
#  --db ~/kraken2_db \
#  --threads 16 \
#  --report ~/longread_project/assembly/kraken_report.txt \
#  --output ~/longread_project/assembly/kraken_output.txt \
#  ~/longread_project/assembly/assembly.fasta






