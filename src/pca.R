require("data.table")
require("tidyverse")

#setwd("Valdo/Analisi_Luglio2025/VPRimputation100k_v1")

system("plink --cow --mind 0.95 --bfile s --geno 0.2 --pca 10 --out pca ")
f=fread("pca.eigenvec")

A=system("awk '{print $1}' file.snp",intern=TRUE)
B=system("awk '{print $2}' file.snp",intern=TRUE)

df=data.frame(chip=B,V2=A)

f=merge(df,f)

png("Pca_pannels.png")
print(ggplot(f,aes(x=V3,y=V4,color=chip))+geom_point())
dev.off()