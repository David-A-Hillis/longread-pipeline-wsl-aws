#!/bin/bash
set -euo pipefail

# Creator: David Hillis
# Date: 03/13/2026
# Purpose: Run long-read basecalling (Dorado)

### Create S3 bucket: dhillis-longread/Melanogaster/

### A. GPU basecalling node (on‑demand)
### 	Launch AMI: gpu-basecalling-v1
### 		AMI: Ubuntu 22.04
### 		Type: g5.4xlarge
### 		Key pair: david-ec2-key
### 		Storage: 1 TB gp3 (root or attached)
### 		Security group: SSH from your IP

S3_OUTPUT_FASTQ="s3://dhillis-longread/hg007/"


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
sudo mkdir -p /data/pod5 /data/fastq
sudo chown -R ubuntu:ubuntu /data

####################################
## The following loop is useful for downloading a limited POD5 set (N=5)
## The complete set of data can be downloaded with:
# aws s3 cp --no-sign-request \
#   s3://ont-open-data/giab_2025.01/flowcells/HG007/PBA20413/pod5/ \
#   /data/fast5/ \
#   --recursive 
####################################
for i in 0 1 2 3 4; do
  aws s3 cp --no-sign-request \
    s3://ont-open-data/giab_2025.01/flowcells/HG007/PBA20413/pod5/PBA20413_34e18f45_15a51301_${i}.pod5 \
    /data/pod5/
done

### Run Dorado (SUP) in Docker:
docker run --gpus all --rm -v /data:/data ontresearch/dorado:latest \
  dorado basecaller sup /data/pod5 --emit-fastq > /data/fastq/HG007_subset_sup.fastq

### Check the fastq file completed
ls -lh /data/fastq/HG007_subset_sup.fastq # Size should be roughly 10% of the original POD5 sizes (10-20)
grep -c '^@' /data/fastq/HG007_subset_sup.fastq # Should see counts into hundreds of thousands or more
head -10 /data/fastq/HG007_subset_sup.fastq # Should see standard header
tail -10 /data/fastq/HG007_subset_sup.fastq # Looks like garbage to me, but AI can tell if it is weird


### Sync FASTQ to your S3 bucket:
aws s3 cp /data/fastq/HG007_subset_sup.fastq $S3_OUTPUT_FASTQ

### Check to make sure S3 contains the fastq file

### Terminate GPU instance.


