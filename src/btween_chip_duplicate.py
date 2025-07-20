#!/usr/bin/env python3

import os
import subprocess
from collections import defaultdict

def load_animals_from_fam(fam_file):
    """
    Load (family_id, animal_id) tuples from a .fam file.
    Returns a set of tuples.
    """
    animals = set()
    with open(fam_file, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 2:
                fam_id = parts[0]
                animal_id = parts[1]
                animals.add((fam_id, animal_id))
    return animals

def main():
    chefile = "chefile.txt"

    if not os.path.exists(chefile):
        print("❌ File chefile.txt non trovato!")
        return

    print("📦 Avvio analisi duplicati tra chip...")

    # Carica lista chip in ordine (con posizione)
    with open(chefile, 'r') as f:
        chips = [line.strip().replace('.bim', '') for line in f]

    chips = chips[::-1]
    chip_pos = {chip: i for i, chip in enumerate(chips)}  # mappa chip → indice (0-based)

    # Map animal_id → list of chips
    animal_chips = defaultdict(list)
    animal_family = dict()  # animal_id → fam_id (first occurrence)

    # Popola animal_chips
    for chip in chips:
        fam_file = chip + ".fam"
        if not os.path.exists(fam_file):
            print(f"⚠️  File .fam mancante per {chip}")
            continue

        animals = load_animals_from_fam(fam_file)
        for fam_id, animal_id in animals:
            animal_chips[animal_id].append(chip)
            if animal_id not in animal_family:
                animal_family[animal_id] = fam_id

    # Scrivi lista duplicati con chip
    with open("duplicated_animals.txt", "w") as dup_file:
        dup_file.write("FAM_ID\tANIMAL_ID\tCHIPS\n")
        for animal_id, chip_list in animal_chips.items():
            unique_chips = sorted(set(chip_list), key=lambda x: chip_pos.get(x, 1e6))
            if len(unique_chips) > 1:
                fam_id = animal_family.get(animal_id, "NA")
                dup_file.write(f"{fam_id}\t{animal_id}\t" + "\t".join(unique_chips) + "\n")

    print("📄 Lista duplicati scritta in duplicated_animals.txt")

    # File report rimozioni
    with open("removed_duplicates_report.txt", "w") as report:
        report.write("FAM_ID\tANIMAL_ID\tREMOVED_FROM_CHIP\n")

        # Rimuovi duplicati mantenendo l'animale solo nel chip più in alto
        for chip in chips:
            fam_file = chip + ".fam"
            remove_file = chip + "_remove.txt"
            cleaned_prefix = chip + "_cleaned"

            if not os.path.exists(fam_file):
                continue

            print(f"📝 Controllo duplicati da rimuovere in {chip}...")

            animals_to_remove = []
            with open(fam_file, 'r') as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        fam_id = parts[0]
                        animal_id = parts[1]
                        if animal_id in animal_chips:
                            # Ordina i chip di questo animale per posizione (asc)
                            ordered_chips = sorted(set(animal_chips[animal_id]), key=lambda x: chip_pos.get(x, 1e6))
                            first_chip = ordered_chips[0] if ordered_chips else None
                            # Se il chip corrente non è il primo dove l'animale compare, rimuovi
                            if chip != first_chip:
                                animals_to_remove.append((fam_id, animal_id))
                                report.write(f"{fam_id}\t{animal_id}\t{chip}\n")

            if animals_to_remove:
                with open(remove_file, 'w') as out:
                    for fam_id, animal_id in animals_to_remove:
                        out.write(f"{fam_id} {animal_id}\n")  # PLINK expects fam_id and animal_id

                print(f"➖ Rimuovo {len(animals_to_remove)} duplicati da {chip}")

                result = subprocess.run([
                    "plink", "--cow", "--bfile", chip,
                    "--remove", remove_file,
                    "--make-bed", "--out", cleaned_prefix
                ], stdout=open(chip + "_log.txt", 'w'), stderr=subprocess.STDOUT)

                if result.returncode != 0:
                    print(f"❌ PLINK failed on chip {chip}. Exiting.")
                    exit(1)
            else:
                print(f"✔️ Nessun duplicato da rimuovere in {chip}")
                for ext in [".bed", ".bim", ".fam"]:
                    src = chip + ext
                    dst = cleaned_prefix + ext
                    if os.path.exists(src):
                        subprocess.run(["cp", src, dst])

    print("🎉 Rimozione duplicati completata. Report in removed_duplicates_report.txt")

if __name__ == "__main__":
    main()
