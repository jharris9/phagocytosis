# Overview 
This is a pipeline for bulk RNA sequencing analysis that uses fastqc and kallisto to QC and map reads and quantify transcript abundance with Bash scripts. An R script is then used to run DESeq2 for differential expression. Volcano plots and heatmaps are created. A dockerfile is provided to build a container with a suitable environment to run this code. 

# Steps
0. If using docker container, first build a container using the provided Dockerfile. All subsequent code will be run in this container.
1. QC sequencing with fastqc_macrophage_bulk.sh
2. Pseudoalign and quantify reads with kallisto_macrophage_bulk.sh
3. Optional: If reads are mapping poorly to the expected transcriptome, try mapping to other references (genome, other species, noncoding etc.) to figure out where reads are coming from. aggregate_mapping_reads.py will summarize how the reads were mapped to the various othe references
4. Differential gene expression and plot generation. Run 251303_bulk_seq_deseq2_margeta_mac.Rmd

# Project layout
project/
├── README.md
├── renv.lock
├── renv/
│
├── config/
│   └── samples.tsv                  # sample metadata (sample, condition, replicate)
│
├── scripts/
│   ├── 01_trim.sh                   # fastp trimming
│   ├── 02_kallisto.sh               # kallisto quant
│   └── 03_deseq2.Rmd               # DESeq2 analysis
│
├── data/
│   ├── raw/                         # original FASTQ files (read-only)
│   │   ├── sample1_R1_001.fastq.gz
│   │   ├── sample1_R2_001.fastq.gz
│   │   └── md5checksums.txt
│   │
│   └── reference/                   # reference files
│       ├── kallisto_index/
│       │   └── mouse_transcripts.idx
│       └── tx2gene.tsv              # transcript-to-gene mapping
│
├── results/
│   ├── 01_fastqc/
│   │   ├── pre_trim/               # FastQC on raw reads
│   │   └── post_trim/              # FastQC on trimmed reads
│   │
│   ├── 02_trimmed/                  # trimmed FASTQ files
│   │   ├── sample1_R1.trimmed.fastq.gz
│   │   ├── sample1_R2.trimmed.fastq.gz
│   │   └── sample1_fastp.html
│   │
│   ├── 03_kallisto/                 # kallisto quant output
│   │   ├── sample1/
│   │   │   ├── abundance.h5
│   │   │   ├── abundance.tsv
│   │   │   └── run_info.json
│   │   └── sample2/
│   │
│   └── 04_deseq2/                   # DESeq2 results
│       ├── dds.rds                  # saved DESeq2 object
│       ├── results_table.csv
│       ├── volcano_plot.pdf
│       ├── pca_plot.pdf
│       └── heatmap.pdf
│
└── reports/                         # rendered Rmd reports
    └── 03_deseq2.html