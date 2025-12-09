#!/bin/bash

# Path to FASTQ files
FASTQ_DIR="/raw_data/30-1191629345/00_fastq"
TRIMMED_DIR="/raw_data/30-1191629345/00_fastq/trimmed"

# Output directory for FastQC results
FASTQC_DIR="/output/fastqc"
mkdir -p "$TRIMMED_DIR" "$FASTQC_DIR"

# Number of threads for FastQC
THREADS=28

# Loop through all .fastq.gz files in the FASTQ directory
#fastqc --threads "$THREADS" --outdir "$FASTQC_DIR" "$FASTQ_DIR"/*.fastq.gz


for R1 in "$FASTQ_DIR"/*_R1_001.fastq.gz; do
    # Derive R2 filename
    R2="${R1/_R1_001.fastq.gz/_R2_001.fastq.gz}"
    sample=$(basename "$R1" _R1_001.fastq.gz)

    echo "=== Processing sample: $sample ==="

    # Output trimmed files
    TRIM_R1="$TRIMMED_DIR/${sample}_R1.trimmed.fastq.gz"
    TRIM_R2="$TRIMMED_DIR/${sample}_R2.trimmed.fastq.gz"

    # Run fastp for trimming and basic QC
    fastp \
        -i "$R1" -I "$R2" \
        -o "$TRIM_R1" -O "$TRIM_R2" \
        --thread "$THREADS" \
        --trim_front1 10 --trim_front2 10 \ #optionally trim the first 10 bp if needed. 
        --html "$TRIMMED_DIR/${sample}_fastp.html" \
        --json "$TRIMMED_DIR/${sample}_fastp.json"
done

# Loop through all .fastq.gz files in the FASTQ directory
fastqc --threads "$THREADS" --outdir "$FASTQC_DIR" "$TRIMMED_DIR"/*.fastq.gz

echo "=== FastQC analysis complete. Reports are in $OUT_DIR ==="
