#!/bin/bash

echo "serve per avere un feed back sul controllo dei dati"

cp ../../ana2025/anaf90.txt ana.txt

nohup seekparentf90 --thr_call_rate 0.001 --maxsnp 200000 \
    --excl_thr_prob 1 \
    --yob \
    --pedfile ana.txt --snpfile rawf90.snp \
    > seek_preimpute.log 2>&1 &


cp ../../ana.txt ped.txt
FImpute3 ../../par/par.txt -o


cd imputazione/

awk 'NR > 1 {print $1,$3}' genotypes_imp.txt >  impute.snp
awk 'NR > 1{print $2 ,$1  ,0 ,$3}' snp_info.txt  > impute.map

cp ../../../ana2025/anaf90.txt ana.txt
seekparentf90 --thr_call_rate 0.99 --maxsnp 200000 \
    --excl_thr_prob 1 \
    --yob \
    --pedfile ana.txt --snpfile impute.snp 


# remove all unecessary file
cd ..

rm *bed *bim *fam *ped *map *raw pca.* *.psam *.pvar *.nosex *.pgen *.LOG *.log log* LOG* log_* merge* *tmp
rm dpl.txt keep.txt