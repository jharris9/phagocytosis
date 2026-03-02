FROM bioconductor/bioconductor_docker:RELEASE_3_21-r-4.5.1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libcairo2-dev \
    pkg-config
    wget \
    unzip \
    git \
    openjdk-21-jre \
    && rm -rf /var/lib/apt/lists/*

# Install FastQC
RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip \
    && unzip fastqc_v0.12.1.zip \
    && rm fastqc_v0.12.1.zip \
    && chmod +x FastQC/fastqc \
    && ln -s /FastQC/fastqc /usr/local/bin/fastqc

# Install fastp
RUN wget http://opengene.org/fastp/fastp \
	&& chmod a+x ./fastp \
    && mv fastp /usr/local/bin/

# Install Kallisto
RUN wget https://github.com/pachterlab/kallisto/releases/download/v0.51.1/kallisto_linux-v0.51.1.tar.gz \
    && tar -xvzf kallisto_linux-v0.51.1.tar.gz \
    && mv kallisto*/kallisto /usr/local/bin/ \
    && rm -rf kallisto_linux-v0.51.1.tar.gz kallisto*

# Install Bioconductor and DESeq2 in R

RUN R -e "install.packages('BiocManager'); BiocManager::install('DESeq2', \
	'biomaRt', 'GenomicFeatures', 'txdbmaker', 'tximport', 'rhdf5', 'org.Mm.eg.db', 'EnhancedVolcano', \
							ask=FALSE)"

# Optional: Install tidyverse for data manipulation
RUN R -e "install.packages('tidyverse')"

# Set working directory
WORKDIR /data



#Run this to build:
#docker build -t kallisto-deseq2:latest -t kallisto-deseq2:1.0.0 -f /home/user/Documents/projects/margeta/phagocytosis/code/kallisto_deseq2.Dockerfile .
