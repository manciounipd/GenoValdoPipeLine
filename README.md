# GenoValdoPipeLine - Synergy to PLINK Conversion and Imputation Pipeline (July 2025)

This repository contains a pipeline composed of three main scripts for converting genotype data from Synergy format to PLINK format, preparing SNP panels, and performing imputation in one panel.

---

## Pipeline Components

1. **Step1_formSynergytoPlink.sh**  
   Converts Synergy genotype files into PLINK format. It cleans, truncates, organizes genotype data, splits it by breed and chip, and converts it into PLINK-compatible files.

2. **Step2_get_ready_impute.sh**  
   Prepares the genotype files for imputation by cleaning duplicates, merging panels, and creating imputation input files.

3. **Step3_impute.sh**  
   Performs imputation and converts output files to BLUPF90 format for downstream genetic analyses.

---

## Input Files Description

- **genotipi.csv**  
  Contains genotype data in two fields separated by `;` : `CodiceCamp;genotipo`.  
  The genotype is a sequence of characters: `0/1/2/5/-` where  
  `0` = homozygous AA,  
  `1` = heterozygous AB,  
  `2` = homozygous BB,  
  `5` and `-` = missing data.

- **marker_new.csv**  
  Contains the SNP map with several columns; relevant are:  
  - 1st column: SNP index (e.g., 100 means the 100th SNP in the genotype string),  
  - 2nd column: SNP name,  
  - 3rd and 4th columns: chromosome and position (chip origin unknown).

- **info_campioni.csv**  
  Contains sample info with fields:  
  - Matricola / Matricola14: animal ID  
  - Nome: name  
  - DtaNasc: birth date  
  - Sesso: sex  
  - Matricola_PD: father  
  - Matricola_MD: mother  
  - DtaArrivo: arrival date  
  - DtaPrelievo: sampling date  
  - Campione: internal sample code  
  - DtaInvioLab: lab submission date  
  - Laboratorio: lab name  
  - Chip: chip type  
  - CodiceCamp: code linking genotype  
  - Ricevimento: reception date  
  - Esito: quality call status (`SI` = call rate >95%, `SN` = call rate <95%, `XX` = problematic genotype to discard)  
  - Call rate: call rate percentage

> **Note:** SNPs expected are more than those actually present, as genotypes come from a general SYNERGY archive including many different chip types including HD.

---

## Requirements

- Bash shell environment (Linux/Unix/MacOS)
- Standard Unix utilities (`awk`, `sed`, `sort`, `join`, `wc`)
- Python 3 (for conversion scripts)
- PLINK v1.9 and PLINK2 installed and available in PATH
- Sufficient disk space for intermediate and output files

---

## Usage

1. Place the scripts and parameter files in your working directory.
2. Ensure input files (`info_campioni.csv`, `genotipi.csv`, `marker_new.csv`) are located in `../Dati_18072025/`.
3. Run the first script to convert Synergy to PLINK:

```bash
bash Step1_formSynergytoPlink.sh
```

## Detailed Workflow (Step 1)

1. **Setup and Data Copying**  
   Creates a working directory and copies input CSV files (`info_campioni.csv`, `genotipi.csv`, `marker_new.csv`) into it.

2. **Initial Quality Checks**  
   - Summarizes genotype quality from `info_campioni.csv`.  
   - Checks genotype string length distribution per sample from `genotipi.csv`.  
   - Counts the number of lines in the marker file.

3. **Truncation of Genotypes**  
   Truncates all genotypes to the minimum length found among samples, to ensure consistency.

4. **Preparation of Genotype and Sample Files**  
   - Cleans sample names (replaces spaces with underscores).  
   - Extracts and processes breed, sample ID, lab ID, and chip name.  
   - Joins genotype data with sample info.  
   - Splits data by breed into separate SNP files.

5. **Organization and Conversion**  
   - Removes breed columns from files.  
   - Creates separate folders for each breed.  
   - Splits SNP files by chip type, saving individual SNP files per chip.  
   - Converts SNP data to PLINK format using the Python script `f90_plink.py`.

6. **PLINK Cleaning**  
   - Removes duplicate samples, keeping only unique individuals.  
   - Filters SNPs and samples with high missing rates using PLINK v1.9 and PLINK2.  
   - Generates summary statistics for each panel.

7. **Cleanup**  
   - Deletes temporary files.  
   - Provides logs and summary files for review.

---

## Prerequisites

- Bash shell environment (Linux/Unix/MacOS).  
- Standard Unix utilities: `awk`, `sort`, `uniq`, `join`, `sed`, `wc`.  
- `python3` for running the Python conversion script (`f90_plink.py`).  
- PLINK v1.9 and PLINK2 installed and accessible in your PATH.  
- Adequate disk space for intermediate and output files.

---

## How to Run Step 1

1. Place the script `Step1_formSynergytoPlink.sh` in your working directory.

2. Ensure the following input files exist one directory level up in `../Dati_18072025/`:

   - `info_campioni.csv`  
   - `genotipi.csv`  
   - `marker_new.csv`

3. Execute the script with:

```bash
bash Step1_formSynergytoPlink.sh