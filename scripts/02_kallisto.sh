#!/usr/bin/env bash

# Exit on errors, undefined variables, and fail on pipe errors
set -euo pipefail

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat <<'EOF'
Usage: $(basename "$0") [options]

Run kallisto quant on paired-end FASTQ files with optional MD5 verification.

Options:
  -d DIR    FASTQ directory (default: $FASTQ_DIR)
  -t N      threads per kallisto run (default: $THREADS)
  -i INDEX  kallisto index file path
  -o DIR    output base directory (default: $OUT_BASE)
  -s FILE   file containing sample names, one per line
  -r        use trimmed reads (look in $TRIMMED_DIR instead of $FASTQ_DIR)
  -j N      run up to N samples in parallel (requires xargs or GNU parallel)
  -h        show this message and exit
EOF
}

# =============================================================================
# Default Configuration
# =============================================================================

# Paths
FASTQ_DIR="data/raw/"
TRIMMED_DIR="${FASTQ_DIR}/trimmed"

# Kallisto index
# https://github.com/pachterlab/kallisto-transcriptome-indices?tab=readme-ov-file
# INDEX="/data/kallisto/mouse/ens108/index.idx"
# INDEX="/data_pool/raw_data/reference_genomes/mouse/mouse_gencode.idx"
INDEX="data/reference/mouse/ensembl/kallisto_index/mouse_transcripts.idx"

# Output base directory
OUT_BASE="results/02_kallisto"

# Threads
THREADS=28

# Parallelism (1 = sequential, >1 = parallel samples)
JOBS=1

# Use trimmed reads?
trimmed=false

# Sample names file (optional; uses hardcoded array if empty)
samples_file=""

# Hardcoded sample prefixes (without _R1/_R2 suffixes)
# Overridden if -s is provided
samples=(
    "B6Cont1NonPhag"
    "B6Cont2NonPhag"
    "B6Cont4NonPhag"
    "B6Cont1Phag"
    "B6Cont2Phag"
    "B6Cont4Phag"
)

# =============================================================================
# Parse Command-Line Options
# =============================================================================

while getopts ":d:t:i:o:s:hrj:" opt; do
    case $opt in
        d) FASTQ_DIR=$OPTARG ;;
        t) THREADS=$OPTARG ;;
        i) INDEX=$OPTARG ;;
        o) OUT_BASE=$OPTARG ;;
        s) samples_file=$OPTARG ;;
        r) trimmed=true ;;
        j) JOBS=$OPTARG ;;
        h) usage; exit 0 ;;
        \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Missing argument for -$OPTARG" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# =============================================================================
# Validation
# =============================================================================

# Check that kallisto is available
if ! command -v kallisto >/dev/null 2>&1; then
    echo "Error: kallisto command not found in PATH" >&2
    exit 1
fi

# Check that the index file exists
if [[ ! -f "$INDEX" ]]; then
    echo "Error: kallisto index not found: $INDEX" >&2
    exit 1
fi

# Check that the FASTQ directory exists
if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "Error: FASTQ directory not found: $FASTQ_DIR" >&2
    exit 1
fi

# =============================================================================
# Create Output Directories (after parsing, so overrides are respected)
# =============================================================================

mkdir -p "$OUT_BASE"

# =============================================================================
# Load Samples
# =============================================================================

if [[ -n "$samples_file" ]]; then
    if [[ ! -f "$samples_file" ]]; then
        echo "Error: sample file $samples_file not found" >&2
        exit 1
    fi
    mapfile -t samples < "$samples_file"
fi

if [[ ${#samples[@]} -eq 0 ]]; then
    echo "Error: no samples provided" >&2
    exit 1
fi

# =============================================================================
# Report Configuration
# =============================================================================

echo "Configuration:"
echo "  FASTQ_DIR=$FASTQ_DIR"
echo "  INDEX=$INDEX"
echo "  THREADS=$THREADS"
echo "  OUT_BASE=$OUT_BASE"
echo "  trimmed=$trimmed"
echo "  JOBS=$JOBS"
echo "  samples count=${#samples[@]}"
echo

# =============================================================================
# Functions
# =============================================================================

# Verify MD5 checksum for a file
# Arguments: path to fastq file, path to its corresponding .md5 file
verify_md5() {
    local file="$1"
    local md5file="$2"

    if [[ ! -f "$file" ]]; then
        echo "❌ Missing file: $file"
        return 1
    fi
    if [[ ! -f "$md5file" ]]; then
        echo "❌ Missing MD5 file: $md5file"
        return 1
    fi

    local dir
    dir=$(dirname "$file")
    if (cd "$dir" && md5sum -c "$(basename "$md5file")" >/dev/null 2>&1); then
        echo "✅ MD5 OK: $file"
        return 0
    else
        echo "❌ MD5 FAILED: $file"
        return 1
    fi
}

# Process a single sample: verify checksums, then run kallisto quant
process_sample() {
    local sample="$1"
    local ts
    ts=$(date --rfc-3339=seconds)
    echo "[$ts] === Processing sample: $sample ==="

    # Choose directory and suffix depending on trimmed flag
    local base_dir suffix
    if [[ "$trimmed" == true ]]; then
        base_dir="$TRIMMED_DIR"
        suffix=".trimmed.fastq.gz"
    else
        base_dir="$FASTQ_DIR"
        suffix="_001.fastq.gz"
    fi

    local R1="${base_dir}/${sample}_R1${suffix}"
    local R2="${base_dir}/${sample}_R2${suffix}"

    # Verify MD5 checksums
    verify_md5 "$R1" "${R1}.md5" || { echo "Skipping $sample due to MD5 failure."; return; }
    verify_md5 "$R2" "${R2}.md5" || { echo "Skipping $sample due to MD5 failure."; return; }

    # Output directory for this sample
    local OUTDIR="${OUT_BASE}/mouse_ensb/${sample}"
    mkdir -p "$OUTDIR"

    # Run kallisto quant
    kallisto quant -i "$INDEX" -o "$OUTDIR" -t "$THREADS" "$R1" "$R2"

    echo "✅ kallisto complete: $sample"
}

# =============================================================================
# Main Execution
# =============================================================================

# Export variables needed by parallel subshells
export FASTQ_DIR TRIMMED_DIR OUT_BASE INDEX THREADS trimmed

if [[ $JOBS -gt 1 ]]; then
    echo "Running up to $JOBS samples in parallel"
    export -f process_sample verify_md5
    if command -v parallel >/dev/null 2>&1; then
        printf "%s\n" "${samples[@]}" | parallel -j "$JOBS" process_sample {}
    else
        printf "%s\n" "${samples[@]}" | xargs -P"$JOBS" -I{} bash -c 'process_sample "$1"' _ {}
    fi
else
    for sample in "${samples[@]}"; do
        process_sample "$sample"
    done
fi

echo "=== All samples processed ==="
