#!/usr/bin/env bash
set -euo pipefail

# Trim + FastQC pipeline
#   -d data/raw  input directory with raw FASTQ files
#   -t data/raw/trimmed  output directory for trimmed FASTQ files
#   -q results/01_fastqc  output directory for FastQC reports
#   -n 28   threads per tool
#   -f 10   trim front bases for R1
#   -r 10   trim front bases for R2
#   -j 6    run up to 6 samples in parallel
bash scripts/01_fastqc.sh \
    -d data/raw \
    -t data/raw/trimmed \
    -q results/01_fastqc \
    -n 28 \
    -f 10 \
    -r 10 \
    -j 6

# Kallisto quantification pipeline
#   -d data/raw/  input directory with raw FASTQ files (looks for trimmed
#              files if -r is set)
#   -t 28  threads per kallisto run
#   -i data/reference/mouse/ensembl/kallisto_index/mouse_transcripts.idx  
#               kallisto index file path
#   -o results/02_kallisto  output base directory for kallisto results
#   -j 6   run up to 6 samples in parallel
bash scripts/02_kallisto.sh \
  -d data/raw \
  -t 28 \
  -i data/reference/mouse/ensembl/kallisto_index/mouse_transcripts.idx \
  -o results/02_kallisto \
  -j 6


python3 scripts/aggregate_mapping_reads.py 


echo "========================================="
echo " Step 5: DESeq2 Analysis"
echo "========================================="

Rscript -e "rmarkdown::render(
    'scripts/05_deseq2.Rmd',
    output_dir = 'reports/',
    output_file = 'deseq2_report.html'
)" 2>&1 | tee logs/deseq2_$(date +%Y-%m-%d).log

echo "✅ DESeq2 report saved to reports/deseq2_report.html"