# longread-pipeline-wsl-aws
Pipelines for ONT long-read basecalling, alignment, and structural variant calling.

## Project Overview

### Summary:  
This repository contains a complete long‑read genomics workflow for Oxford Nanopore data, including WSL2‑based local development and AWS‑based GPU/CPU compute pipelines. It covers basecalling (Dorado), alignment (minimap2), assembly (Flye), structural variant calling (Sniffles2), and downstream SV statistics using bcftools and custom Bash scripts. The project demonstrates reproducible, cloud‑ready bioinformatics engineering with clear separation of compute roles and environment management.

### Pipeline Architecture:
```
WSL2 pipeline — local development, environment setup, basecalling tests, alignment, assembly, and SV calling.
AWS pipeline — GPU basecalling node (g5.xlarge or g5.2xlarge) and CPU alignment/SV calling node (c7i.4xlarge spot).
S3 storage model — separation of raw POD5, intermediate FASTQ/BAM, and final VCF outputs.
```

### Features:
```
Complete Bash scripts for each pipeline stage
Reproducible environment setup using micromamba
GPU‑accelerated Dorado basecalling
Minimap2 alignment and Flye assembly
Sniffles2 structural variant calling
bcftools‑based SV statistics and VAF distribution analysis
AWS‑ready workflows with AMI creation steps
Public ONT datasets used for testing (Drosophila, HG007)
```

### Repository Structure:
```
longread-pipeline/
│
├── wsl/
│   ├── WSL_alignment_SVcalling_pipeline.sh
│   └── WSL_SV_statistics_pipeline.sh
│
├── aws/
│   ├── AWS_GPU_basecalling_Drosophila.sh
│   ├── AWS_CPU_alignment_Drosophila.sh
│   ├── AWS_GPU_basecalling_Human.sh
│   └── AWS_CPU_alignment_Human.sh
│
├── examples/
│   └── Analyses_Ouputs.txt
│
└── README.md
```

### Requirements:
```
WSL2 (Ubuntu 22.04)
micromamba (conda‑forge + bioconda)
minimap2 ≥ 2.30
Flye ≥ 2.9
Sniffles2 ≥ 2.7
bcftools ≥ 1.17
sratoolkit ≥ 3.0.3
Dorado ≥ 0.5.3 (local) or ≥ 0.9.6 (AWS Docker)
AWS CLI v2
EC2 GPU instance (g5.xlarge or g5.4xlarge)
EC2 CPU instance (c7i.4xlarge spot)
```

### WSL2 Pipeline:
```
Environment setup (micromamba, tool installation)
Basecalling tests (CPU or GPU if available)
POD5 conversion
Alignment with minimap2
Assembly with Flye
SV calling with Sniffles2
SV statistics (type counts, size distribution, VAF bins, chromosome density)
```

### Optional Analyses:  
The repository includes additional tools commonly used in long‑read genome assembly workflows. These steps are not required for the core alignment and structural variant pipeline but are provided for users who want to extend the analysis.

Assembly graph visualization (Flye) — Convert assembly_graph.gv to PDF using Graphviz (sfdp -Tpdf).

Contamination screening (Kraken2) — Classify contigs or assemblies using MiniKraken or the standard Kraken2 database.

Contig size filtering (seqkit) — Extract contigs within specific size ranges for targeted analysis.

### Note on ONT SUP Model dna_r10.4.1_e8.2_400bps_sup@v3.5.2:  
The Drosophila pipeline was originally developed using the Dorado SUP model dna_r10.4.1_e8.2_400bps_sup@v3.5.2. This model has since been retired and is no longer available through the standard Dorado download interface. For reproducibility, the model is available through a project‑specific download link. Users should ensure they comply with the Oxford Nanopore Technologies Public License when accessing and using this model.

### Note on POD5 → FASTQ conversion in WSL2:    
This repository includes the full POD5‑to‑FASTQ conversion workflow for completeness, but the D. melanogaster dataset used in this project is large enough that full basecalling exceeded the practical runtime of a local WSL2 environment. The conversion step runs correctly, but performance on a CPU‑only workstation is not suitable for large ONT datasets.

To continue downstream development and testing on WSL2, a publicly available ONT FASTQ dataset was used as an alternative input. The complete GPU‑accelerated basecalling workflow—including POD5 conversion, Dorado SUP basecalling, and FASTQ generation—is implemented in the AWS pipeline, which is designed for full‑scale production runs.

In this structure, the WSL2 pipeline serves as a lightweight development and validation environment, while the AWS pipeline provides the scalable compute required for full dataset processing.

### AWS Pipeline:  
GPU Basecalling Node
```
		Launch AMI
		Copy POD5 from ONT S3
		Convert to FASTQ using Dorado
		Sync FASTQ to your S3 bucket
		Terminate instance
```

CPU Alignment + SV Node
```
Launch spot instance
Pull FASTQ + reference
Align with minimap2
Sort/index with samtools
Call SVs with Sniffles2
Sync BAM/VCF to S3
Terminate instance
```

### Example Outputs:
```
Count by Type
      8 BND
   4087 DEL
     12 DUP
   5601 INS
     10 INV
```
```
Rough Size Distribution
   5759 <100bp
   3409 100-1kb
    532 1-10kb
     10 >=10kb
```

### Data Sources:  
List the public ONT datasets used for testing.  
D. melanogaster ONT R10.4.1 400bps (ONT Open Data)
```
s3://ont-open-data/contrib/melanogaster_bkim_2023.01/flowcells/D.melanogaster.R1041.400bps/D_melanogaster_1/20221217_1251_MN20261_FAV70669_117da01a/fast5/
```

D. melanogaster (SRR32117930) ONT MinION R10.4.1, SQK‑LSK114 ligation kit.
```
s3://sra-pub-src-5/SRR32117930/BL620_raw.fastq.1
```

HG007 GIAB 2025.01 POD5 subset
```
s3://ont-open-data/giab_2025.01/flowcells/HG007/PBA20413/pod5/
```

### Citations:  
This project uses publicly available datasets and open‑source tools. Please cite the following when using or extending this workflow:  
Jain M, Olsen HE, Paten B, Akeson M. The Oxford Nanopore MinION: delivery of nanopore sequencing to the genomics community. Genome Biology 17, 239 (2016).

Oxford Nanopore Technologies Benchmark Datasets was accessed on March 13, 2026 from https://registry.opendata.aws/ont-open-data.

Zook JM et al. Integrating human sequence data sets provides a resource of benchmark SNP and indel genotype calls. Nature Biotechnology 32, 246–251 (2014).

Cunningham F et al. Ensembl 2022. Nucleic Acids Research 50(D1):D988–D995 (2022).
Reference genomes downloaded from Ensembl release 115 (ftp://ftp.ensembl.org/pub/release-115/

Li H. Minimap2: pairwise alignment for nucleotide sequences. Bioinformatics 34(18):3094–3100 (2018).

Kolmogorov M, Yuan J, Lin Y, Pevzner PA. Assembly of long, error-prone reads using repeat graphs. Nature Biotechnology 37, 540–546 (2019).

Sedlazeck FJ et al. Accurate detection of complex structural variations using single-molecule sequencing. Nature Methods 15, 461–468 (2018).

Danecek P et al. Twelve years of SAMtools and BCFtools. GigaScience 10(2):giab008 (2021).

Oxford Nanopore Technologies. Dorado basecaller. https://github.com/nanoporetech/dorado
