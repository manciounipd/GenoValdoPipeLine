library(data.table)
library(tidyverse)

# Run PCA with PLINK
cat("doing PCA")
system("plink --cow --mind 0.9999999 --geno 0.05 --bfile s --pca 10 --out pca  > log 2>&1 ")
cat("done..\n")

# Read eigenvectors
f <- fread("pca.eigenvec", header=FALSE)
colnames(f) <- c("FID", "IID", paste0("PC", 1:10))

# Load sample annotations (adjust file and columns as needed)
annot <- fread("file.snp", header=FALSE, select=1:2)
colnames(annot) <- c("IID","chip")

# Merge PCA with annotation
f <- merge(f, annot, by="IID", all.y=TRUE)

# Identify outliers (>5 SD in PC1 or PC2)
f <- f %>%
  mutate(
    PC1_z = scale(PC1),
    PC2_z = scale(PC2),
    is_outlier = abs(PC1_z) > 5 | abs(PC2_z) > 5
  )

# Save outliers list to file
outliers <- f %>% filter(is_outlier) %>% select(chip, IID, PC1, PC2)
fwrite(outliers, "PCA_outliers.txt", sep="\t")

# Print outlier list in R
print("Outliers:")
print(outliers)

# Plot PCA, color outliers in red
p <- ggplot(f, aes(x=PC1, y=PC2, color=is_outlier)) +
  geom_point(size=2, alpha=0.7) +
  scale_color_manual(values=c("FALSE"="blue", "TRUE"="red"),
                     labels=c("Core Samples", "Outliers"),
                     name="Sample Type") +
  labs(x="PC1", y="PC2", title="PCA Plot with Outliers Highlighted") +
  theme_minimal()

# Save plot
getwd()
png("Pca_panels_with_outliers.png", width=8, height=6, units="in", res=300)
print(p)
dev.off()
