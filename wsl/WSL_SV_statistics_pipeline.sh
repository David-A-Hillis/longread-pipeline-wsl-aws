#!/bin/bash
set -euo pipefail

# Creator: David Hillis
# Date: 03/09/2026
# Purpose: Run basic analyses on structural variant VCF output produced by Sniffles

### Set up Variables
FOLDER= "/path/to/vcf/"
VCF="melanogaster.sniffles.vcf"
OUTPUT="melanogaster_SV"

### Copy from Windows to WSL
mkdir ~/$OUTPUT/
echo "Structural Variant Summary — $(date)" > "$OUTPUT/${OUTPUT}_results.txt"
echo "${OUTPUT} Statistical Results
" >> ~/$OUTPUT/${OUTPUT}_results.txt
cp $FOLDER/$VCF ~/$OUTPUT/
echo "
VCF File" >> ~/$OUTPUT/${OUTPUT}_results.txt
ls -lh ~/$OUTPUT/ >> ~/$OUTPUT/${OUTPUT}_results.txt

### Download BCFtools
# sudo apt update
# sudo apt install bcftools

### Count by Type
echo "
Count by Type" >> ~/$OUTPUT/${OUTPUT}_results.txt
bcftools view -H ~/${OUTPUT}/${VCF} | cut -f8 | sed 's/;/\n/g' | grep '^SVTYPE=' | cut -d= -f2 | sort | uniq -c >> ~/$OUTPUT/${OUTPUT}_results.txt

### Rough Size Distribution
echo "
Rough Size Distribution" >> ~/$OUTPUT/${OUTPUT}_results.txt
bcftools view -H ~/${OUTPUT}/${VCF} \
  | awk -F'\t' '{
      svlen="NA";
      split($8,info,";");
      for(i in info){ if(info[i] ~ /^SVLEN=/){ split(info[i],a,"="); svlen=a[2]; } }
      if(svlen!="NA"){ print svlen; }
    }' \
  | awk '{print ($1<100?"<100bp":$1<1000?"100-1kb":$1<10000?"1-10kb":">=10kb")}' \
  | sort | uniq -c >> ~/$OUTPUT/${OUTPUT}_results.txt

### Per-Chromosome SV Density
echo "
Per-Chromosome SV Density" >> ~/$OUTPUT/${OUTPUT}_results.txt
bcftools view -H ~/${OUTPUT}/${VCF} | cut -f1 | sort | uniq -c >> ~/$OUTPUT/${OUTPUT}_results.txt

### VAF and zygosity patterns
bcftools view -H ~/${OUTPUT}/${VCF} \
  | awk -F'\t' '{
      split($8,info,";");
      vaf="NA";
      for(i in info){ if(info[i] ~ /^VAF=/){ split(info[i],a,"="); vaf=a[2]; } }
      if(vaf!="NA"){ print vaf; }
    }' > ~/${OUTPUT}/${OUTPUT}_vaf_values.txt

echo "
Head and Count of VAF Values" >> ~/$OUTPUT/${OUTPUT}_results.txt
head ~/${OUTPUT}/${OUTPUT}_vaf_values.txt >> ~/$OUTPUT/${OUTPUT}_results.txt
wc -l ~/${OUTPUT}/${OUTPUT}_vaf_values.txt >> ~/$OUTPUT/${OUTPUT}_results.txt

echo "
Distribution of VAF" >> ~/$OUTPUT/${OUTPUT}_results.txt
awk '{
  bin = int($1*10); 
  if (bin == 10) bin = 9; 
  counts[bin]++
} END {
  for (i=0; i<10; i++) {
    printf "%.1f–%.1f: %d\n", i/10, (i+1)/10, counts[i]+0
  }
}' ~/${OUTPUT}/${OUTPUT}_vaf_values.txt >> ~/$OUTPUT/${OUTPUT}_results.txt



### Filter for High Confidence SVs
bcftools view -f PASS ~/${OUTPUT}/${VCF} \
  | bcftools view -i 'INFO/SUPPORT>=10' \
  -o ~/${OUTPUT}/${OUTPUT}.highconf.vcf 
echo "VCF File" >> ~/$OUTPUT/${OUTPUT}_results.txt
ls -lh ~/$OUTPUT/ >> ~/$OUTPUT/${OUTPUT}_results.txt

# Count by Type (High Confidence)
echo "
Count by Type (High Confidence)" >> ~/$OUTPUT/${OUTPUT}_results.txt
bcftools view -H ~/${OUTPUT}/${OUTPUT}.highconf.vcf | cut -f8 | sed 's/;/\n/g' | grep '^SVTYPE=' | cut -d= -f2 | sort | uniq -c >> ~/$OUTPUT/${OUTPUT}_results.txt

# Rough Size Distribution (High Confidence)
echo "
Rough Size Distribution (High Confidence)" >> ~/$OUTPUT/${OUTPUT}_results.txt
bcftools view -H ~/${OUTPUT}/${OUTPUT}.highconf.vcf \
  | awk -F'\t' '{
      svlen="NA";
      split($8,info,";");
      for(i in info){ if(info[i] ~ /^SVLEN=/){ split(info[i],a,"="); svlen=a[2]; } }
      if(svlen!="NA"){ print svlen; }
    }' \
  | awk '{print ($1<100?"<100bp":$1<1000?"100-1kb":$1<10000?"1-10kb":">=10kb")}' \
  | sort | uniq -c >> ~/$OUTPUT/${OUTPUT}_results.txt

# Per-Chromosome SV Density (High Confidence)
echo "
Per-Chromosome SV Density (High Confidence)" >> ~/$OUTPUT/${OUTPUT}_results.txt
bcftools view -H ~/${OUTPUT}/${OUTPUT}.highconf.vcf | cut -f1 | sort | uniq -c >> ~/$OUTPUT/${OUTPUT}_results.txt

# VAF and zygosity patterns (High Confidence)
bcftools view -H ~/${OUTPUT}/${OUTPUT}.highconf.vcf \
  | awk -F'\t' '{
      split($8,info,";");
      vaf="NA";
      for(i in info){ if(info[i] ~ /^VAF=/){ split(info[i],a,"="); vaf=a[2]; } }
      if(vaf!="NA"){ print vaf; }
    }' > ~/${OUTPUT}/${OUTPUT}_vaf_values.highconf.txt

echo "
Head and Count of VAF Values (High Confidence)" >> ~/$OUTPUT/${OUTPUT}_results.txt
head ~/${OUTPUT}/${OUTPUT}_vaf_values.highconf.txt >> ~/$OUTPUT/${OUTPUT}_results.txt
wc -l ~/${OUTPUT}/${OUTPUT}_vaf_values.highconf.txt >> ~/$OUTPUT/${OUTPUT}_results.txt

echo "
Distribution of VAF (High Confidence)" >> ~/$OUTPUT/${OUTPUT}_results.txt
awk '{
  bin = int($1*10); 
  if (bin == 10) bin = 9; 
  counts[bin]++
} END {
  for (i=0; i<10; i++) {
    printf "%.1f–%.1f: %d\n", i/10, (i+1)/10, counts[i]+0
  }
}' ~/${OUTPUT}/${OUTPUT}_vaf_values.highconf.txt  >> ~/$OUTPUT/${OUTPUT}_results.txt

cp ~/$OUTPUT/${OUTPUT}_results.txt ${FOLDER}
cp ~/${OUTPUT}/${OUTPUT}_vaf_values.txt ${FOLDER}
cp ~/${OUTPUT}/${OUTPUT}_vaf_values.highconf.txt ${FOLDER}








