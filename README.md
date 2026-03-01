# Overview 
This is a pipeline for bulk RNA sequencing analysis that uses fastqc and kallisto to QC and map reads and quantify transcript abundance with Bash scripts. An R script is then used to run DESeq2 for differential expression. Volcano plots and heatmaps are created. A dockerfile is provided to build a container with a suitable environment to run this code. 

# Steps
0. If using docker container, first build a container using the provided Dockerfile. All subsequent code will be run in this container.
1. QC sequencing with fastqc_macrophage_bulk.sh
2. Pseudoalign and quantify reads with kallisto_macrophage_bulk.sh
3. Optional: If reads are mapping poorly to the expected transcriptome, try mapping to other references (genome, other species, noncoding etc.) to figure out where reads are coming from. aggregate_mapping_reads.py will summarize how the reads were mapped to the various othe references
4. Differential gene expression and plot generation. Run 251303_bulk_seq_deseq2_margeta_mac.Rmd