setwd("Valdo")
ana = foreign::read.dbf(system("ls ana*/*.DBF", intern = TRUE))
ana=as.data.frame(apply(ana, 2, function(x) gsub(" ","_",x)))
ana[ana[,1] == ana[,3],3]="0"
ana[ana=="00000000000000"]="0"
anaf90=ana[,c(1,2,3,5,6)]
anaf90$DNAS=substr(anaf90$DNAS, 1, 4)
data.table::fwrite(anaf90,sep= " ","anaf90.txt", row.names = FALSE,col.names= FALSE, quote = FALSE)

ana=ana[,c(1,2,3,6)]


getwd()

data.table::fwrite(ana,sep= " ","ana.txt", row.names = FALSE,col.names= FALSE, quote = FALSE)


