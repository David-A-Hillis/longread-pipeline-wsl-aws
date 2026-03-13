#!/bin/bash
set -euo pipefail

# Creator: David Hillis
# Date: 03/13/2026
# Purpose: Run long-read basecalling (Dorado)

### Create S3 bucket: dhillis-longread/Melanogaster/

### A. GPU basecalling node (on‑demand)
### 	Launch AMI: gpu-basecalling-v1
### 		AMI: Ubuntu 22.04
### 		Type: g5.xlarge
### 		Key pair: david-ec2-key
### 		Storage: 1 TB gp3 (root or attached)
### 		Security group: SSH from your IP

S3_OUTPUT_FASTQ="s3://dhillis-longread/Melanogaster/"


### Setup:
sudo apt update && sudo apt install -y docker.io awscli
sudo usermod -aG docker ubuntu


### Install NVIDIA drivers:
sudo apt update
sudo apt install -y nvidia-driver-535


curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker


### Pull 5 POD5 files locally:
sudo mkdir -p /data/fast5
sudo chown -R ubuntu:ubuntu /data
aws s3 cp --no-sign-request \
  s3://ont-open-data/contrib/melanogaster_bkim_2023.01/flowcells/D.melanogaster.R1041.400bps/D_melanogaster_1/20221217_1251_MN20261_FAV70669_117da01a/fast5/ \
  /data/fast5/ \
  --recursive


### Convert to POD5
sudo apt update
sudo apt install python3-pip
pip install pod5
~/.local/bin/pod5 convert fast5 /data/fast5/*.fast5 --output /data/pod5/ --one-to-one /data/fast5/


### Copy Necessary Model From S3
mkdir -p ~/.cache/dorado/models
aws s3 cp --recursive \
  s3://dhillis-longread/dorado/dna_r10.4.1_e8.2_400bps_sup@v3.5.2 \
  ~/.cache/dorado/models/dna_r10.4.1_e8.2_400bps_sup@v3.5.2



### Download the Dorado Software
wget https://cdn.oxfordnanoportal.com/software/analysis/dorado-0.9.6-linux-x64.tar.gz
tar -xzf ~/dorado-0.9.6-linux-x64.tar.gz



###############################################
## Dorado Model (Discontinued v3.5.2) Download
## This model is no longer available via:
##   dorado download --model <name>
## For reproducibility, it is hosted in a project S3 bucket.
## S3_MODEL_PATH="s3://dhillis-longread/dorado_models/dna_r10.4.1_e8.2_400bps_sup@v3.5.2"
###############################################

#### ### Run dorado (SUP)
~/dorado-0.9.6-linux-x64/bin/dorado basecaller \
  ~/.cache/dorado/models/dna_r10.4.1_e8.2_400bps_sup@v3.5.2 \
  --device cuda:all \
  --batchsize 16 \
  --recursive \
  /data/pod5 \
  > /data/fastq/mel_400bps_reads.fastq



### Check the fastq file completed
ls -lh /data/fastq/mel_400bps_reads.fastq # Size should be roughly 10% of the original POD5 sizes (10-20)
grep -c '^@' /data/fastq/mel_400bps_reads.fastq # Should see counts into hundreds of thousands or more
head -10 /data/fastq/mel_400bps_reads.fastq # Should see standard header
tail -10 /data/fastq/mel_400bps_reads.fastq # Looks like garbage to me, but AI can tell if it is weird

### Attach S3 role to your running instance

### Sync FASTQ to your S3 bucket:
aws s3 cp /data/fastq/mel_400bps_reads.fastq $S3_OUTPUT_FASTQ

### Check to make sure S3 contains the fastq file

### Terminate GPU instance.







