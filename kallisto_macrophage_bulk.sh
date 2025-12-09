
# Paths
FASTQ_DIR="/raw_data/30-1191629345/00_fastq" #/data_pool/raw_data/bulk_rnaseq/30-1191629345/00_fastq/
TRIMMED_DIR="/raw_data/30-1191629345/00_fastq/trimmed"
#https://github.com/pachterlab/kallisto-transcriptome-indices?tab=readme-ov-file
#INDEX="/data/kallisto/mouse/ens108/index.idx"
INDEX="/raw_data/mouse_gencode.idx"
# Number of threads to use
THREADS=28

# Create an output directory
mkdir -p /output/kallisto_results

# Array of sample prefixes (without _R1/_R2 suffixes)
samples=(
    "B6Cont1NonPhag"
    "B6Cont2NonPhag"
    "B6Cont4NonPhag"
    "B6Cont1Phag"
    "B6Cont2Phag"
    "B6Cont4Phag"
)

# Function to verify MD5 checksum for a file
verify_md5() {
    local file="$1"
    local md5file="$2"

    if [[ ! -f "$file" || ! -f "$md5file" ]]; then
        echo "❌ Missing file or MD5 for $file"
        return 1
    fi
    cd /raw_data/30-1191629345/00_fastq/
    echo "$md5file"
    if md5sum -c "$md5file" >/dev/null 2>&1; then
        echo "✅ MD5 OK: $file"
        return 0
    else
        echo "❌ MD5 FAILED: $file"
        return 1
    fi
}

# Loop through each sample and run kallisto quant
for sample in "${samples[@]}"; do
    echo "=== Processing sample: $sample ==="
    
    #Map nontrimmed reads
    R1="${FASTQ_DIR}/${sample}_R1_001.fastq.gz"
    R2="${FASTQ_DIR}/${sample}_R2_001.fastq.gz"
    R1MD5="${R1}.md5"
    R2MD5="${R2}.md5"

    # Verify MD5 checksums
    verify_md5 "$R1" "$R1MD5" || { echo "Skipping $sample due to MD5 failure."; continue; }
    verify_md5 "$R2" "$R2MD5" || { echo "Skipping $sample due to MD5 failure."; continue; }


    #Map trimmed reads
    #R1="${TRIMMED_DIR}/${sample}_R1.trimmed.fastq.gz"
    #R2="${TRIMMED_DIR}/${sample}_R2.trimmed.fastq.gz"

    
    # Output directory for this sample
    OUTDIR="/output/kallisto_results/mouse_gencode/${sample}" #/home/user/Documents/projects/margeta/phagocytosis/kallisto_results/mouse_gencode/
    mkdir -p "$OUTDIR"

    # Run kallisto quant
    kallisto quant -i "$INDEX" -o "$OUTDIR" -t "$THREADS" "$R1" "$R2"
done

echo "=== All samples processed ==="


