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
