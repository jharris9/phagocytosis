#!/usr/bin/env bash

# Exit on errors, undefined variables, and fail on pipe errors
set -euo pipefail

# =============================================================================
# Usage
# =============================================================================

usage() {
    cat <<'EOF'
Usage: $(basename "$0") [options]

Trim FASTQ files with fastp and run FastQC on trimmed output.

Options:
  -d DIR      source FASTQ directory (default: $FASTQ_DIR)
  -t DIR      trimmed output directory (default: $TRIMMED_DIR)
  -q DIR      FastQC output directory (default: $FASTQC_DIR)
  -n N        threads per tool (default: $THREADS)
  -f N        trim front bases for R1 (default: $TRIM_FRONT1; set to 0 to skip)
  -r N        trim front bases for R2 (default: $TRIM_FRONT2)
  -j N        run up to N samples in parallel (default: 1 = sequential)
  -s FILE     file listing sample names (optional; auto-detect from FASTQ if empty)
  -h          show this message and exit
EOF
}

# =============================================================================
# Default Configuration
# =============================================================================

# Paths
PROJECT_ID="30-1191629345"
BASE_DIR="/data_pool/raw_data/bulk_rnaseq/${PROJECT_ID}"
FASTQ_DIR="${BASE_DIR}/00_fastq"
TRIMMED_DIR="${FASTQ_DIR}/trimmed"
FASTQC_DIR="/projects/margeta/phagocytosis/fastqc"

# Threads
THREADS=28

# Parallelism (1 = sequential, >1 = parallel samples)
JOBS=1

# Trim front bases (set to 0 to skip trimming)
TRIM_FRONT1=10
TRIM_FRONT2=10

# Sample names (optional; inferred from FASTQ files if empty)
samples_file=""
samples=()

# =============================================================================
# Parse Command-Line Options
# =============================================================================

while getopts ":d:t:q:n:f:r:j:s:h" opt; do
    case $opt in
        d) FASTQ_DIR=$OPTARG ;;
        t) TRIMMED_DIR=$OPTARG ;;
        q) FASTQC_DIR=$OPTARG ;;
        n) THREADS=$OPTARG ;;
        f) TRIM_FRONT1=$OPTARG ;;
        r) TRIM_FRONT2=$OPTARG ;;
        j) JOBS=$OPTARG ;;
        s) samples_file=$OPTARG ;;
        h) usage; exit 0 ;;
        \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Missing argument for -$OPTARG" >&2; usage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# =============================================================================
# Validation
# =============================================================================

# Check that source FASTQ directory exists
if [[ ! -d "$FASTQ_DIR" ]]; then
    echo "Error: FASTQ directory $FASTQ_DIR not found" >&2
    exit 1
fi

# Check that required tools exist
for tool in fastp fastqc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: $tool not found in PATH" >&2
        exit 1
    fi
done

# =============================================================================
# Create Output Directories (after parsing, so overrides are respected)
# =============================================================================

mkdir -p "$TRIMMED_DIR" "$FASTQC_DIR"

# =============================================================================
# Load / Auto-Detect Samples
# =============================================================================

if [[ -n "$samples_file" ]]; then
    if [[ ! -f "$samples_file" ]]; then
        echo "Error: sample file $samples_file not found" >&2
        exit 1
    fi
    mapfile -t samples < "$samples_file"
else
    # Auto-detect samples from _R1_001.fastq.gz files
    while IFS= read -r -d '' file; do
        sample=$(basename "$file" _R1_001.fastq.gz)
        samples+=("$sample")
    done < <(find "$FASTQ_DIR" -maxdepth 1 -name "*_R1_001.fastq.gz" -print0 | sort -z)
fi

if [[ ${#samples[@]} -eq 0 ]]; then
    echo "Error: no samples found" >&2
    exit 1
fi

# =============================================================================
# Report Configuration
# =============================================================================

echo "Configuration:"
echo "  FASTQ_DIR=$FASTQ_DIR"
echo "  TRIMMED_DIR=$TRIMMED_DIR"
echo "  FASTQC_DIR=$FASTQC_DIR"
echo "  THREADS=$THREADS"
echo "  TRIM_FRONT1=$TRIM_FRONT1, TRIM_FRONT2=$TRIM_FRONT2"
echo "  JOBS=$JOBS"
echo "  samples count=${#samples[@]}"
echo

# =============================================================================
# Functions
# =============================================================================

process_sample() {
    local sample="$1"
    local ts
    ts=$(date --rfc-3339=seconds)
    echo "[$ts] === Processing sample: $sample ==="

    local R1="${FASTQ_DIR}/${sample}_R1_001.fastq.gz"
    local R2="${FASTQ_DIR}/${sample}_R2_001.fastq.gz"

    # Verify files exist
    if [[ ! -f "$R1" ]]; then
        echo "❌ Missing R1: $R1"
        return 1
    fi
    if [[ ! -f "$R2" ]]; then
        echo "❌ Missing R2: $R2"
        return 1
    fi

    local TRIM_R1="$TRIMMED_DIR/${sample}_R1.trimmed.fastq.gz"
    local TRIM_R2="$TRIMMED_DIR/${sample}_R2.trimmed.fastq.gz"

    # Build optional trim arguments
    local trim_args=()
    if [[ $TRIM_FRONT1 -gt 0 ]]; then
        trim_args+=(--trim_front1 "$TRIM_FRONT1")
    fi
    if [[ $TRIM_FRONT2 -gt 0 ]]; then
        trim_args+=(--trim_front2 "$TRIM_FRONT2")
    fi

    # Run fastp
    fastp \
        -i "$R1" -I "$R2" \
        -o "$TRIM_R1" -O "$TRIM_R2" \
        --thread "$THREADS" \
        "${trim_args[@]}" \
        --html "$TRIMMED_DIR/${sample}_fastp.html" \
        --json "$TRIMMED_DIR/${sample}_fastp.json"

    echo "✅ fastp complete: $sample"
}

# =============================================================================
# Main Execution — Trim Samples
# =============================================================================

if [[ $JOBS -gt 1 ]]; then
    echo "Running up to $JOBS samples in parallel"
    export -f process_sample
    export FASTQ_DIR TRIMMED_DIR THREADS TRIM_FRONT1 TRIM_FRONT2
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

# =============================================================================
# Post-Processing — FastQC
# =============================================================================

echo
echo "=== Running FastQC on trimmed files ==="
if fastqc --threads "$THREADS" --outdir "$FASTQC_DIR" "$TRIMMED_DIR"/*.trimmed.fastq.gz; then
    echo "✅ FastQC analysis complete. Reports are in $FASTQC_DIR"
else
    echo "⚠️  FastQC completed with warnings (check $FASTQC_DIR)"
fi
