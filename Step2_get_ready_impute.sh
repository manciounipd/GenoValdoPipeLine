#!/bin/bash 
set -e
source ../code/src/function_cln.sh

#cp par_vpr.txt par_vpn_prediction.txt
#par="../par_vpn_gwas.txt"

echo "name of the file..."

par=$1
if [[ ! -f $par ]]; then
    echo "❌ No file par !"
    exit 1
fi

prepare_imputation_files $par

echo  "Copia i files.."

while IFS= read -r file; do
    cp "../${file}.map" .
    cp "../${file}.ped" .
done < pannel_keep.txt

echo "Step 1 ........"
echo " Rimozione duplicati entro panello "
echo "(lo ho fatto anche nello script precente ma per sicuarezza)"

while IFS= read -r file; do
    filex=$(basename $file)
    copysafeunique2 $file
done < pannel_keep.txt | tee duplictae_within_chips_log.txt




printf "########################################\n"
printf "🚀 STEP 2: Rimozione animali presenti su più chip\n"
printf "\n"
printf "📌 Logica:\n"
printf "  - Se un animale è presente su più chip, mantengo quello:\n"
printf "    • Sul chip più denso (maggior numero di SNP).\n"
printf "    • Oppure sul pannello scelto come principale.\n"
printf "\n"
printf "🔀 L'ordine dei pannelli viene stabilito in base al numero di righe nel file .bim:\n"
printf "    → Il pannello con più righe è considerato il più grande.\n"
printf "    → Gli altri vengono downgradati se necessario.\n"
printf "\n"
printf "########################################\n"



# genera un nuovo file che mi serve da guida in ordinde di mappa di densita
ls -1 *.bim | xargs -I {} sh -c 'echo "$(wc -l {})"' | sort -n  | awk '{print $2}' > chefile.txt

#  sto casino qua serve per ordinarmi la lista
todonw=$(cat downgrade.txt)

if [ "$todonw" != "no" ]; then
    core_name="${todonw#vpr/}"  # => GGP_Bovine_100K_cln
    grep -v -F -f <(echo "$core_name")  chefile.txt > chefile.txt.tmp
    grep -F -f <(echo "$core_name")  chefile.txt > downgrade.txt.tmp
fi
 
mv chefile.txt.tmp chefile.txt
mv downgrade.txt.tmp downgrade.txt

if [[ ! -f chefile.txt ]]; then
    echo "❌ File chefile.txt non trovato!"
    exit 1
fi


cat   chefile.txt downgrade.txt > chefile.tmp
mv chefile.tmp chefile.txt

python3 ../../code/src/btween_chip_duplicate.py

if [ $? -ne 0 ]; then
    echo "❌ Python script failed. Exiting..."
    exit 1
fi
# riniomvi per evitare casini

for ext in bim fam bed; do
    for f in *_cleaned."$ext"; do
        [[ -e "$f" ]] || continue  # skip se non ci sono file
        new_name="${f/_cleaned/}"
        mv "$f" "$new_name"
    done
done



printf "########################################\n"
printf "📦 STEP 3: Downgrade pannelli e gestione nomi SNP\n"
printf "\n"
printf "📌 Nota:\n"
printf "  - Anche i nomi degli SNP vengono controllati se presenti.\n"
printf "  - Per ora viene effettuato solo il downgrade dei pannelli.\n"
printf "  - Appena disponibili le mappe aggiornate (update map), sarà possibile aggiornare anche i nomi SNP.\n"
printf "\n"
printf "⚙️ Procedura:\n"
printf "  • Effettuo il downgrade dei pannelli per uniformare i dataset.\n"
printf "  • Nomi SNP verranno gestiti in una fase successiva quando noto.\n"
printf "\n"
printf "########################################\n"



todonw=$(cat downgrade.txt)

if [ "$todonw" != "no" ]; then
    while IFS= read -r filex
        do  
                    echo  "$filex" "=>" "$todonw"
                    join -1 1 -2 1 <( awk '{print $1"_"$4}' $todonw | sort -k 1 ) <(awk '{print $1"_"$4}' $filex | sort -k 1  ) > incommon.txt
                    join -1 1 -2 1 <(awk '{print $1"_"$4,$0}' $filex | sort -k 1b,1 )  <(sort -k 1b,1  incommon.txt) | awk '{print $3}' > keep.txt
                    tooo=$(awk 'END{print NR}' $filex )
                    ed=$(echo $filex | sed -e 's/.bim//g')
                    if plink2 --cow --bfile "$ed" --extract keep.txt --make-bed --out "$ed" > log 2>&1; then
                            echo "✅ plink2 completed successfully."
                        else
                            echo "⚠️ plink2 failed. Running fallback script..."
                            ./fallback_script.sh "$ed" || {
                                echo "❌ Fallback script also failed."
                                exit 1
                            }
                        fi
                    frommm=$(awk 'END{print NR}' $ed".bim")
                    echo " Went to from" $tooo "to" $frommm  
        
    done < chefile.txt
    
fi


base=${todonw%.bim}  # toglie .bim se c'è

for ext in bim fam bed; do
    cp "${base}.${ext}" "${base}_rec.${ext}"
done


# crea file fimpute
rm *~

# DA QUA SOLO MIGLIORARE LOS STYLE

printf "########################################\n"
printf "📦 STEP  Crea file 4\n"
printf "\n"# rimuvoi snp doppio e in comume
printf "########################################\n"

echo "create file snp.."



while IFS= read -r i
 do   
    filex=$(echo "$i" | sed 's/\.bim$//')
    echo $filex
    echo "removing duplicate names..."
    plink2 --cow --bfile $filex --export ped 12  --rm-dup  --out $filex > log
    echo "removing differen snp with same position and same chr.."
    awk '{print $1"_"$4,$2}' $filex".map"  > tmp
    awk '{print $1}' tmp | sort -k 1b,1 | uniq -c | awk '$1>1 {print $0}' > dpl.txt
    join -1 2 -2 1 <(sort -k 2b,2 dpl.txt) <(sort -k 1b,1 tmp ) | awk '{print $3}' > rm.tmp
    plink2 --cow --exclude rm.tmp --bfile $filex --export ped 12 --out $filex > log
    echo $( wc -l dpl.txt)
done < chefile.txt



echo "✅"

echo "ID chips genotype" > file.snp
row=1
while IFS= read -r i
 do   
    echo "#########"
    filex=$(echo "$i" | sed 's/\.bim$//')
    echo $filex  # potrei indicar eilpaneelllo
    #echo "sorting.."
    plink2 --cow --pedmap $filex --sort-vars  --make-pgen --out  $filex   > logd
    echo "make raw and pedmap .."
    plink2 --cow --pfile $filex --recode ped 12  --out  $filex  > logd
    plink2 --cow --pfile $filex --mind 0.3 --recode A --out  $filex   > eliminati_per_mid_chips_$filex.txt
    #echo "adding on file.."
    awk 'NR > 1 { printf "%s%s", $2, OFS; 
        for (i = 7; i <= NF; i++) printf "%s", $i; print "" }' $filex".raw" > tmp
    awk -v IS=$row '{ gsub("NA", "5", $2); print $1,IS,$2 }'  tmp >> file.snp
    ((row++))
done < chefile.txt

# crea il file da imputare 
# file snp...

echo "" > merge.txt
while IFS= read -r i
 do   
    filex=$(echo "$i" | sed 's/\.bim$//')
    echo $filex".ped" $filex".map"  >> merge.txt
done <  chefile.txt 


sed -i '1d' merge.txt
plink --cow --merge-list  merge.txt --recode ped 12 --out s > log 2>&1 
echo "tranforma in blupf90 , questo serve per fare un check.." 
plink --cow --file s --recode A --out s > log 2>&1



awk 'NR > 1{ 
        printf "%s ", $2; for (i=7; i<=NF; i++) printf "%s", $i;
             printf "\n" }' s.raw | awk '{gsub("NA",5,$2); print $0}'  > rawf90.snp




while IFS= read -r i
 do   
    filex=$(echo "$i" | sed 's/\.bim$//')
    echo $filex
    awk 'NR==FNR { file1[$2] = FNR; next } 
            $2 in file1 { print $0, file1[$2]; next } { print $0, 0 }' $filex.map s.map >  tmp
    mv tmp s.map
done < chefile.txt



awk '{printf "%s %s %s ", $2, $1, $4; for (i=5; i<=NF; i++) printf "%s ", $i; print ""}' s.map  > file.map
chip=$(awk 'NR==1 {for (i=5; i<=NF; i++) printf "chip_%d ", i-4; print ""}' s.map)
sed  -i "1i SNP_ID chr pos $chip"   file.map




echo "End ✅ "

