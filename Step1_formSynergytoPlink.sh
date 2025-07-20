#!/bin/bash

mkdir -p Analisi_Luglio2025
cd  Analisi_Luglio2025

cp ../Dati_18072025/info_campioni.csv .
cp ../Dati_18072025/genotipi.csv .
cp ../Dati_18072025/marker_new.csv .

echo "-----------------------------"
echo "Qualità dei genotipi"
echo "-----------------------------"
awk -F ';' 'NR > 1 {print $(NF-1)}' info_campioni.csv | sort | uniq -c

echo
echo "-----------------------------"
echo "Controllo lunghezza genotipi per campione"
echo "-----------------------------"
awk -F ";" 'NR > 1 {print length($2)}' genotipi.csv | sort -n | uniq -c

echo
echo "-----------------------------"
echo "Lunghezza file map"
echo "-----------------------------"
wc -l marker_new.csv


######################################################################################


echo
echo "-----------------------------"
echo "Opzione 2: taglia tutti i genotipi alla lunghezza minima trovata  (in accordo con Attilio Rossoini)"
echo "-----------------------------"


min_len=$(awk -F ";" 'NR > 1 {l=length($2); if (min=="" || l<min) min=l} END{print min}' genotipi.csv)
echo
echo "Lunghezza minima trovata: $min_len"

head -n "$min_len" marker_new.csv > marker_truncated.csv

awk -F ";" -v len="$min_len" 'BEGIN{OFS=FS}
                NR==1 {print; next}  # stampa intestazione
                {
                    $2 = substr($2, 1, len)
                    print
                }' genotipi.csv > genotipi_truncated.csv



echo "---------------------------------"
echo "Procedura per creare file genotipo"
echo "--------------------------------"

geno="genotipi_truncated.csv"
map="marker_truncated.csv"

echo "Step 1: sistemazione file campioni e genotipi"

# Sostituisci spazi con underscore
awk 'BEGIN{FS=OFS=";"} {for(i=1; i<=NF; i++) gsub(" ", "_", $i)} 1' info_campioni.csv > campioni.tmp

# Estrai razza, matricola, id lab e nome SNP chip per campioni buoni
awk -F ';' 'NR>1 { if($(NF-1) != "XX") print $1, $1, $12, $11 }' campioni.tmp | \
awk '{print substr($1,1,2), substr($1,3), $2, $3, $4}' | sort -k2 > giusti.tmp

# Rimuovi matricola (campo 3) per ottenere giusti.csv
awk '{$3=""; print $0}' giusti.tmp > giusti.csv

# Ordina e sostituisci spazi con underscore nei genotipi
awk -F ';' 'NR>1{OFS=" "; $1=$1; print}' $geno | \
awk '{gsub(" ", "_", $1)} 1' | sort -k1b,1 > geno.sort.tmp

# Join tra campioni e genotipi
echo "join..."
join -1 3 -2 1 <(sort -k3,3b giusti.csv) geno.sort.tmp > geno2.tmp
echo done 

echo "Controllo righe dopo join:"

if [ $(( $(wc -l < geno2.tmp) )) -eq $(( $(wc -l < giusti.csv) )) ]; then
    echo "✅ Same row"
else
    echo "❌ Sum does NOT match!"
    exit 1
fi

# Rimuovi colonna dei campioni dai genotipi
awk '{$1=""; print}' geno2.tmp > all.snp

echo "Controllo numero righe per razza:"
wc -l *snp*


echo "Step 2: divisione per razze"
awk '$1=="03"{print > "vpr.snp"} $1!="03"{print > "vpn.snp"}' all.snp

if [ $(( $(wc -l < vpn.snp) + $(wc -l < vpr.snp) )) -eq $(wc -l < all.snp) ]; then
    echo "✅ Sum matches: vpn.snp + vpr.snp == all.snp"
else
    echo "❌ Sum does NOT match!"
    echo "vpn.snp: $(wc -l < vpn.snp)"
    echo "vpr.snp: $(wc -l < vpr.snp)"
    echo "all.snp: $(wc -l < all.snp)"
    exit 1
fi



# Rimuovi colonna razza
awk '{$1=""; print}' vpr.snp > vpr.snp.tmp
awk '{$1=""; print}' vpn.snp > vpn.snp.tmp

mv vpr.snp.tmp vpr.snp
mv vpn.snp.tmp vpn.snp

awk '{print length($1)}' vpn.snp | sort -k 1 |  uniq -c
awk '{print length($1)}' vpr.snp | sort -k 1 |  uniq -c


echo "Step3  copia ciscuno file dentro la cartella e rimuvoi la colonna del pannelo"

for breed in $( ls v*.snp)
do
    br=$(echo $breed | sed 's/.snp//g'  )
    echo "###############<- "$br" ->###################"
    mkdir $br
    chip=$(awk '{print $2}' $breed | sort -k 1 | uniq)
    for i in $chip
    do
        awk -v col=$i '$2==col{print $1,$3}'  $br.snp  >  $br"/"$i".snp"
        echo $i "numer of animal" $(awk 'END{print NR}' $br"/"$i".snp") 
    done
done | tee  import_log1.txt



echo  "Step 4 converti in plink nelle due cartelle.."

for breed in $(ls -d vp*.snp); do
    br=$(echo "$breed" | sed -e 's/.snp//g')
    # potrei d'ora in poi proseguire per gli affari miei

    cd "$br" || exit 1
    echo "############< $br >#############"

    for filen in $(ls *.snp); do
        echo "$filen"
        filename=$(echo "$filen" | sed -e 's/\.snp//g')
        echo "$filename ../marker_truncated.csv" | python3 ../../src/f90_plink.py
    done

    cd .. || exit 1
done

echo "🎉 Conversione done $(date)"


echo "Step 5 pulizia genotipi e creazione map per ciasun pannello"
echo "I know, if duplicated that keeping randomly the first genotype is not the best, but is necessary to make code simple to mantain and fast"
echo "è necessario girare plink v1.9 perche essondoci troppi missing fa casino con v2.0"



for breed in vp*.snp; do
    br="${breed%.snp}"
    cd "$br" || exit 1
    echo "############< $br >#############"

    # File riepilogo per la cartella corrente
    summary_file="summary_panel_counts.tsv"
    echo -e "File\tOrig_Animals\tNon_Unique\tUnique_Animals\tFinal_SNPs\tLoss_%Animals\tLoss_%SNPs" > "$summary_file"

    total_orig_animals=0
    total_non_unique=0
    total_unique_animals=0
    total_final_snps=0

    for filen in *.snp; do
        echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
        echo "$filen"
        filename="${filen%.snp}"

        echo "Checking duplicate animals in genotype file..."
        orig_n=$(wc -l < "$filename.ped")

        # Count non-unique (duplicates)
        non_unique_n=$(awk '{count[$2]++} END{c=0; for (i in count) if(count[i]>1)c+=count[i]-1; print c}' "$filename.ped")

        # Fix duplicates
       echo "checking duplicate animal in genotype file"

# Elimina righe duplicate
        echo "TO DO next step arrange within snp and based on call rate on 'infogenotypi.csv' and take the first"
        awk '!seen[$2]++' "$filename.ped" > "${filename}_unique.ped"
        cp "$filename.map"  "${filename}_unique.map"

        # Conta righe prima e dopo
        orig_n=$(wc -l < "$filename.ped")
        uniq_n=$(wc -l < "${filename}_unique.ped")
        non_unique_n=$((orig_n - uniq_n))

        echo " From $orig_n animals to $uniq_n unique animals (duplicates removed: $non_unique_n)"


        echo "Running PLINK cleaning..."
        plink --cow --allow-extra-chr --chr 1-29 --file "${filename}_unique" \
            --geno 0.95 --make-bed --out tmp > log \
            || { echo "❌ plink step 1 failed for ${filename}"; exit 1; }

        plink2 --cow --bfile tmp --make-pgen --sort-vars -export ped 12 --out --out "${filename}_cln"  > log \
            || { echo "❌ plink2 step 2 failed for ${filename}"; exit 1; }

        plink2 --cow --pfile tmp --geno 0.95 --export ped 12 --out "${filename}_cln" > log \
            || { echo "❌ plink2 step 3 failed for ${filename}"; exit 1; }


        final_animals=$(awk 'END{print NR}' "${filename}_cln.ped")
        final_snps=$(awk 'END{print NR}' "${filename}_cln.map")

        # Percentuali di perdita
        loss_animals=$(awk -v o=$uniq_n -v f=$final_animals 'BEGIN{printf("%.2f", ((o-f)/o)*100)}')
        loss_snps=$(awk -v o=$(wc -l < "${filename}_unique.map") -v f=$final_snps 'BEGIN{printf("%.2f", ((o-f)/o)*100)}')

        echo "Number of animals: $final_animals  | Number of SNPs: $final_snps"

        # Aggiorna totali
        total_orig_animals=$((total_orig_animals + orig_n))
        total_non_unique=$((total_non_unique + non_unique_n))
        total_unique_animals=$((total_unique_animals + uniq_n))
        total_final_snps=$((total_final_snps + final_snps))

        # Aggiungi al riepilogo locale
        echo -e "${filename}\t${orig_n}\t${non_unique_n}\t${uniq_n}\t${final_snps}\t${loss_animals}%\t${loss_snps}%" >> "$summary_file"

        rm tmp*
    done

    # Totale finale per la cartella
    echo -e "TOTAL\t${total_orig_animals}\t${total_non_unique}\t${total_unique_animals}\t${total_final_snps}\t-\t-" >> "$summary_file"

    echo "✅ Summary created in: $br/$summary_file"
    cd ..
    done | tee cln_plink.log


echo "🎉 Creazione Pannelli  $(date)"

echo "remove all non necessray files"

rm -f *tmp*  

echo "✅ fine parte sistemazione genotipi"


