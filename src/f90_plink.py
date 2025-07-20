import pandas as pd
import sys
from tqdm import tqdm  # Progress bar

# Read inputs
inputs = sys.stdin.readline().strip().split()
if len(inputs) != 2:
    raise ValueError("❌ You must provide exactly 2 arguments: <snp_basename> <map_basename>")
snp_basename, map_basename = inputs

print(f"📂 Processing SNP file: {snp_basename}.snp")
print(f"📄 Using MAP file: {map_basename}")

# Load marker file
t = pd.read_csv(map_basename, sep=";", header=None, low_memory=False)
n_markers = t.shape[0]
print(f"✅ Markers loaded: {n_markers} markers")

# Prepare MAP file
t = t.replace(" ", "_", regex=True)
t[2] = t[2].fillna("0")
t["pos"] = "0"
t[[2, 1, "pos", 3]].to_csv(snp_basename + ".map", sep=" ", index=False, header=False)
print(f"📄 MAP file written: {snp_basename}.map")

# Genotype recoding dictionary
recode = {'0': '1 1', '1': '1 2', '2': '2 2', '5': '0 0'}

# Count total samples for progress bar
with open(snp_basename + ".snp", 'r', encoding='utf-8') as f_in:
    total_samples = sum(1 for _ in f_in)
print(f"👥 Total samples (rows): {total_samples}")

# Process SNP file and write PED with progress bar
with open(snp_basename + ".snp", 'r', encoding='utf-8') as f_in, \
     open(snp_basename + ".ped", 'w') as f_out:

    for line in tqdm(f_in, total=total_samples, desc="🔄 Converting SNP → PED"):
        line = line.rstrip('\n').rstrip('\r')
        if not line.strip():
            continue

        fields = line.split(maxsplit=1)
        if len(fields) < 2:
            raise ValueError(f"❌ Missing genotype string for sample '{fields[0]}'")

        sample_id, geno_str = fields

        if len(geno_str) < n_markers:
            geno_str = geno_str.ljust(n_markers, '5')  # pad missing
        elif len(geno_str) > n_markers:
            raise ValueError(f"❌ Sample {sample_id} has {len(geno_str)} genotypes, but MAP has only {n_markers} markers!")

        # Recode genotypes (unknown alleles → missing)
        genotype = [recode.get(allele, '0 0') for allele in geno_str]
        ped_line = f"breed {sample_id} 0 0 0 -9 {' '.join(genotype)}\n"
        f_out.write(ped_line)

print("✅ Conversion complete.")
