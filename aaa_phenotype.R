#libraries
library(stringr)
library(data.table)

# Step 1: 
# Exclude type 1
# Excluding anyone with ICD codes given for "Exclude Type 1"

# 1.1 read in all ICD9
icd9_anno <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/annotation-icd9.csv")
icd9_person <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/person-icd9.csv")

colnames(icd9_person) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

setkey(icd9_anno, CODE)
setkey(icd9_person, MSDW)

tmp <- merge(icd9_anno, icd9_person, by.x="CODE", by.y="MSDW", allow.cartesian = TRUE)

setkeyv(tmp, c("CODE", "CUI", "ONTOLOGY_ID", "MRN", "EID", "TIMESTAMP"))
icd9.merged <- unique(tmp, by=key(tmp))

# 1.2 read in exclusion codes
excl_type1.icd <- fread("/home/johnsk26/projects/embeddings/code/aaa/exclude_type1_icd.txt")
colnames(excl_type1.icd) <- "ICD9_CODE"
icd9.to.excl <- subset(icd9.merged, (ONTOLOGY_ID %in% excl_type1.icd$ICD9_CODE))
mrn.toexcl.t1 <- unique(icd9.to.excl$MRN)
icd9.filtered <- subset(icd9.merged, !(MRN %in% mrn.toexcl.t1))
  
# Step 2: Subset all MRNs to those 40<=Age<90 years old at the date of encounter
# We'll then merge this subset to the ICD9 code MRNs from Step 1, subsetting them
colnames(icd9.filtered)[6] <- 'AGE_DAYS'
icd9.filtered[, AGE_DAYS:=as.numeric(AGE_DAYS)]
icd9.filtered[, AGE_YEARS:=AGE_DAYS/365.25]
icd9.filt2 <- icd9.filtered[AGE_YEARS>=40 & AGE_YEARS<90]

# Step 3: Include people by CPT codes
# We want to define Type 1 cases by those who have a particular CPT code or not
# 3.1 read in MSDW2 CPT codes
cpt_anno <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/cpt/annotation-cpt.csv")
cpt_person <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/cpt/person-cpt.csv")

colnames(cpt_anno)
colnames(cpt_person) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

setkey(cpt_anno, CODE)
setkey(cpt_person, MSDW)

tmp <- merge(cpt_anno, cpt_person, by.x="CODE", by.y="MSDW", allow.cartesian = TRUE)

#we don't care how many times they happened, so removing EID and timestamp columns
setkeyv(tmp, c("CODE", "CUI", "ONTOLOGY_ID", "MRN"))
cpt.merged <- unique(tmp, by=key(tmp))

# read in the AAA repair CPT codes
aaa.cpt.codes <- fread("/home/johnsk26/projects/embeddings/code/aaa/include_type1_cpt.txt", colClasses = "character")
colnames(aaa.cpt.codes) <- "cptcode"

cpt.aaa <- subset(cpt.merged, ONTOLOGY_ID %in% aaa.cpt.codes$cptcode)
cpt.mrn.type1 <- intersect(icd9.filt2$MRN, cpt.aaa$MRN)
write.table(cpt.mrn.type1, file="/home/johnsk26/projects/embeddings/results/aaa_type1.txt", quote=F, row.names = F, col.names = F)

### Step 4: Subtype into type 2 now
icd9.441.3 <- icd9.filt2[ONTOLOGY_ID=='441.3']
mrn.441.3 <- unique(icd9.441.3$MRN)
mrn.type2 <- setdiff(mrn.441.3, cpt.mrn.type1)
write.table(mrn.type2, file="/home/johnsk26/projects/embeddings/results/aaa_type2.txt", quote=F, row.names = F, col.names = F)

### Step 5: Type 1 or type 2
mrn.type1.type2 <- union(mrn.441.3, cpt.mrn.type1)
write.table(mrn.type1.type2, file="/home/johnsk26/projects/embeddings/results/aaa_type1_type2.txt", quote=F, row.names = F, col.names = F)

### Step 6: Type 3
icd9.t3 <- icd9.filt2
icd9.t3[, MOST_RECENT_AGE := max(AGE_YEARS), by=.(MRN)]
icd9.t3[, AGEDIFF := MOST_RECENT_AGE - AGE_YEARS]
icd9.t3.2 <- icd9.t3[AGEDIFF<=5]
icd9.t3.3 <- icd9.t3.2[ONTOLOGY_ID=='441.4', .N, by=MRN]
mrn.type3 <- icd9.t3.3[N>=2, .(MRN)]
mrn.type3 <- setdiff(mrn.type3$MRN, mrn.type1.type2)
write.table(mrn.type3, file="/home/johnsk26/projects/embeddings/results/aaa_type3.txt", quote=F, row.names = F, col.names = F)

### Step 7: Type 1, Type 2, Type 3
mrn.type1.type2.type3 <- union(mrn.type1.type2, mrn.type3)
write.table(mrn.type1.type2.type3, file="/home/johnsk26/projects/embeddings/results/aaa_type1_type2_type3.txt", quote=F, row.names = F, col.names = F)



