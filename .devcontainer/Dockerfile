FROM bioconductor/bioconductor_docker:RELEASE_3_21-r-4.5.1

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libcairo2-dev \
    pkg-config \
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

# Use project-local renv to restore packages at container creation time
# The devcontainer mounts a shared renv cache into /home/rstudio/.cache

# Ensure the existing rstudio user has a cache directory
RUN mkdir -p /home/rstudio/.cache \
    && mkdir -p /home/rstudio/.vscode-server \
    && chown -R rstudio:rstudio /home/rstudio \
    && chmod -R 777 /home/rstudio/.cache /home/rstudio/.vscode-server

ENV HOME=/home/rstudio
ENV RENV_PATHS_LIBRARY=/home/rstudio/R/x86_64-pc-linux-gnu-library/4.5

RUN R -e "install.packages('https://cran.r-project.org/src/contrib/Archive/renv/renv_1.2.2.tar.gz', repos=NULL, type='source', lib=.Library)" \
    && R -e "install.packages('languageserver', repos='https://p3m.dev/cran/__linux__/noble/latest', lib=.Library)" \
    && chmod -R 777 /home/rstudio/.vscode-server

WORKDIR /projects/phagocytosis
