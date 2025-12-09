---
title: "R Notebook"
output: html_notebook
---

This is an [R Markdown](http://rmarkdown.rstudio.com) Notebook. When you execute code within the notebook, the results appear beneath the code. 

Try executing this chunk by clicking the *Run* button within the chunk or by placing your cursor inside it and pressing *Ctrl+Shift+Enter*. 

```{r}
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

#BiocManager::install("biomaRt")

library(biomaRt)

```

```{r}
ensembl <- useEnsembl(biomart = "ensembl", dataset = "mmusculus_gene_ensembl")
abundance <- read_tsv("/output/kallisto_results/mouse_ensbl/B6Cont1NonPhag/abundance.tsv")

tx_ids = str_remove(abundance$target_id, "\\.\\d+$")

mapping <- getBM(
    attributes = c("ensembl_transcript_id", "ensembl_gene_id", "external_gene_name"),
    filters = "ensembl_transcript_id",
    values = tx_ids,
    mart = ensembl
)

mapping
abundance$gene_name = mapping
abundance$target_id_trimmed = tx_ids
```

```{r}
# Load required packages
library(dplyr)
library(readr)
library(stringr)

# ---- 1. Read Kallisto abundance file ----
abundance <- read_tsv("/output/kallisto_results/mouse_ensbl/B6Cont1NonPhag/abundance.tsv")

# ---- 2. Read Ensembl GTF annotation ----
gtf <- read_tsv("/data/raw_data/reference_genomes/mouse/ensembl/Mus_musculus.GRCm39.115.gtf",
                comment = "#",
                col_names = FALSE)

# GTF columns (Ensembl standard):
# 1 seqname, 2 source, 3 feature, 4 start, 5 end, 6 score,
# 7 strand, 8 frame, 9 attribute

# ---- 3. Extract transcript IDs for rRNA ----
# Filter rows with rRNA biotype
rRNA_gtf <- gtf %>%
  filter(str_detect(X9, 'gene_biotype "rRNA"') | 
         str_detect(X9, 'transcript_biotype "rRNA"'))

# Extract transcript_id values
rRNA_ids <- str_match(rRNA_gtf$X9, 'transcript_id "([^"]+)"')[,2] 

# ---- 4. Filter Kallisto output for rRNA transcripts ----
rRNA_abundance <- abundance %>%
  filter(target_id_trimmed %in% rRNA_ids)

# ---- 5. Calculate total rRNA reads and total reads ----
total_rRNA_reads <- sum(rRNA_abundance$est_counts)
total_reads <- sum(abundance$est_counts)

# ---- 6. Calculate percentage ----
percent_rRNA <- (total_rRNA_reads / total_reads) * 100

# ---- 7. Output result ----
cat("Percent ribosomal reads:", round(percent_rRNA, 2), "%\n")
 "ENSMUST00020182242.1" %in% abundance$target_id
```
Import
```{r}
BiocManager::install("GenomicFeatures")
BiocManager::install("txdbmaker")
library("GenomicFeatures")
txdb <- makeTxDbFromGFF("/data/raw_data/reference_genomes/mouse/ensembl/Mus_musculus.GRCm39.115.gtf")

k <- keys(txdb, keytype = "TXNAME")

tx2gene <- select(txdb, keys = k,
                  columns = c("GENEID"),
                  keytype = "TXNAME")
# Remove version numbers from transcript IDs
tx2gene[,1] <- sub("\\..*$", "", tx2gene[,1])

#write.table(tx2gene,
#            file = "tx2gene.tsv",
#            quote = FALSE,
#            sep = "\t",
#            row.names = FALSE,
#            col.names = FALSE)
```

```{r}
BiocManager::install("tximport")
BiocManager::install("rhdf5")
library(tximport)
# Read your table
samples <- read.table("/output/kallisto_results/mouse_ensbl/samples.txt", header = TRUE, sep = ",")

# Build named vector of kallisto abundance files
files <- setNames(samples$path, samples$sample)
#tx2gene <- read.table("tx2gene.tsv", header = TRUE, sep = "\t")
# Import kallisto results
txi <- tximport(
    files,
    type = "kallisto",
    tx2gene = tx2gene,
    countsFromAbundance = "no",
    ignoreTxVersion = TRUE
)

# Build DESeq2 metadata
metadata <- samples[, c("condition", "replicate")]
rownames(metadata) <- samples$sample

# Build DESeq2 dataset
dds <- DESeqDataSetFromTximport(
    txi,
    colData = metadata,
    design = ~ condition
)
```
DESEQ
```{r}
BiocManager::install("org.Mm.eg.db")
library(DESeq2)
library(AnnotationDbi)
library(org.Mm.eg.db)

# Run DESeq2 differential expression
dds <- DESeq(dds)

# Extract results
res <- results(dds)

# Order by adjusted p-value
res <- res[order(res$padj), ]
res$symbol <- mapIds(
    org.Mm.eg.db,
    keys = rownames(res),
    column = "SYMBOL",
    keytype = "ENSEMBL",
    multiVals = "first"
)
test=as.data.frame(res)
# Save full results
write.csv(as.data.frame(res), file = "/output/kallisto_results/mouse_ensbl/deseq2_results.csv")
```

Variance stablization (good fpr PCA/cluster/QC/distance matrices/ML that assumes homoskedastic data, not differential expression testing)
```{r}
# Optional: variance stabilized data
vsd <- vst(dds)
test2=assay(vsd)
write.csv(assay(vsd), file = "normalized_vst_counts.csv")
```

