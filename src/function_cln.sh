#!/bin/bash

prepare_imputation_files() {
    local par=$1

    if [[ ! -f "$par" ]]; then
        echo "Parameter file '$par' not found."
        return 1
    fi

    # Read title (second line of file)
    local title
    title=$(awk 'NR==2 {print $0}' "$par")
    echo "Title: $title"

    # Create directory with title name and move into it
    mkdir -p "$title"
    cd "$title" || { echo "Failed to enter directory $title"; return 1; }

    # Save original parameter file
    cp "../$par" parametro_usato.txt

    # Find line number of "# reference"
    local ref_line
    ref_line=$(grep -n '^# reference' "../$par" | cut -d: -f1)

    # Create downgrade.txt (lines after "# reference")
    awk -v line="$ref_line" 'NR > line {print $0}' "../$par" > downgrade.txt

    # Create pannel_keep.txt (lines between "# chips" and "# reference")
awk -v line="$ref_line" 'NR < line {print $0}' "../$par" \
    | sed -n '/# chips/,$p' | sed '1d' > pannel_keep.txt

    # Set filename variable
    filename="$title"
    echo "Filename set to: $filename"
}

copysafeunique() {
    hd_p=$(basename "$1")
    echo "Processing file: $hd_p"

    # Check existence of .ped and .map
    if [[ ! -f "$hd_p.ped" || ! -f "$hd_p.map" ]]; then
        echo "Error: Missing $hd_p.ped or $hd_p.map in $(pwd)" >&2
        return 1
    fi

    # Ricalcola FID come numeri di riga per evitare problemi di join
    awk '{$1=NR; print $0}' "$hd_p.ped" > tmp.ped && mv tmp.ped "$hd_p.ped"

    plink --cow --file "$hd_p" --missing --out missing > LOGG 2>&1
    if [[ ! -f missing.imiss ]]; then
        echo "Error: missing.imiss not created by PLINK. Check LOGG for details." >&2
        return 1
    fi

    sed -i '1d' missing.imiss  # Remove header
    total_animals=$(wc -l < missing.imiss)
    echo "Number of animals: $total_animals"

    if [ "$total_animals" -gt 0 ]; then
        # SampleID ($2), callrate ($4), NR (line number)
        awk '{print NR, $2, $4}' missing.imiss | sort -k3,3n > order.miss

        # Keep lowest call rate per duplicate
        awk '
        !($2 in min) || $3 < min[$2] {
            min[$2] = $3
            lines[$2] = $0
        }
        END {
            for (key in lines) print lines[key]
        }' order.miss | awk '{print $1}' > torm

        num_lines=$(wc -l < torm)
        duplicates=$(( total_animals - num_lines ))
        echo "Found $duplicates duplicates"

        if [ "${duplicates:-0}" -gt 0 ]; then
            echo "Removing duplicates, new number of animals: $num_lines"
            awk 'NR==FNR{keep[$1]; next} (FNR in keep)' torm "$hd_p.ped" > "${hd_p}_unique.ped"
            cp "$hd_p.map" "${hd_p}_unique.map"
            plink --cow --file "${hd_p}_unique" --make-bed --out "${hd_p}_uniq" > LOG1 2>&1
            if [ $? -ne 0 ]; then
                echo "Error: PLINK failed during duplicate removal for $hd_p" >&2
                return 1
            fi
        else
            echo "No duplicates found. Converting PED to BED anyway."
            plink --cow --file "$hd_p" --make-bed --out "${hd_p}" > LOG1 2>&1
            if [ $? -ne 0 ]; then
                echo "Error: PLINK failed while converting PED to BED for $hd_p" >&2
                return 1
            fi
        fi
    else
        echo "No animals found in missing.imiss file."
        return 1
    fi

    # Cleanup
    rm -f order.miss torm missing.*
}



copysafeunique2() {
    hd_p=$(basename "$1")
    echo -e "\033[1;34m🔄 Processing file:\033[0m $hd_p"

    # Check for .ped and .map
    if [[ ! -f "$hd_p.ped" || ! -f "$hd_p.map" ]]; then
        echo -e "\033[1;31m❌ Error:\033[0m Missing $hd_p.ped or $hd_p.map in $(pwd)" >&2
        return 1
    fi

    # Recalculate FID using line numbers
    awk '{$1=NR; print $0}' "$hd_p.ped" > tmp.ped && mv tmp.ped "$hd_p.ped"

    echo -e "\033[1;33m📦 Running PLINK --missing...\033[0m"
    plink --cow --file "$hd_p" --missing --out missing > LOGG 2>&1
    if [[ ! -f missing.imiss ]]; then
        echo -e "\033[1;31m❌ Error:\033[0m PLINK did not create missing.imiss (see LOGG)" >&2
        return 1
    fi

    sed -i '1d' missing.imiss  # Remove header
    total_animals=$(wc -l < missing.imiss)
    echo -e "\033[1;32m✅ Total animals found:\033[0m $total_animals"

    if [[ "$total_animals" -gt 0 ]]; then
        awk '{print NR, $2, $4}' missing.imiss | sort -k3,3n > order.miss

        # Keep the lowest call rate per duplicate
        awk '
        !($2 in min) || $3 < min[$2] {
            min[$2] = $3
            lines[$2] = $0
        }
        END {
            for (key in lines) print lines[key]
        }' order.miss | awk '{print $1}' > torm

        num_lines=$(wc -l < torm)
        duplicates=$(( total_animals - num_lines ))
        echo -e "\033[1;36m🔍 Found duplicates:\033[0m $duplicates"

        if [[ "$duplicates" -gt 0 ]]; then
            echo -e "\033[1;35m🗑 Removing duplicates...\033[0m"
            awk 'NR==FNR{keep[$1]; next} (FNR in keep)' torm "$hd_p.ped" > "${hd_p}_unique.ped"
            cp "$hd_p.map" "${hd_p}_unique.map"

            echo -e "\033[1;33m📦 Converting to BED...\033[0m"
            plink --cow --file "${hd_p}_unique" --make-bed --out "${hd_p}_uniq" > LOG1 2>&1
            if [[ $? -ne 0 ]]; then
                echo -e "\033[1;31m❌ Error:\033[0m PLINK failed during duplicate removal." >&2
                return 1
            fi
        else
            echo -e "\033[1;32m👍 No duplicates found. Converting PED to BED...\033[0m"
            plink --cow --file "$hd_p" --make-bed --out "${hd_p}" > LOG1 2>&1
            if [[ $? -ne 0 ]]; then
                echo -e "\033[1;31m❌ Error:\033[0m PLINK failed during PED to BED conversion." >&2
                return 1
            fi
        fi
    else
        echo -e "\033[1;31m❌ Error:\033[0m No animals in missing.imiss file."
        return 1
    fi

    echo -e "\033[1;32m🎉 Done for $hd_p\033[0m"

    # Cleanup
    rm -f order.miss torm missing.*
}
