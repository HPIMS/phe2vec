#libraries
library(stringr)
library(data.table)

# Step 1: Get the meds list
# We used ripgrep to extract at meds from:
# /home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/medication/annotation-medication.csv
# and saved the resulting file to:
# /data1/accounts/students/johnsk26/projects/embeddings/dat/crohns/crohns_meds.txt

# 1.1 -- read in crohn's meds in order to get the MSDW code
anno_crohns_meds <- fread("/data1/accounts/students/johnsk26/projects/embeddings/dat/crohns/crohns_meds.txt")
colnames(anno_crohns_meds) <- c("CODE", "CUI", "ONTOLOGY_ID", "LABEL")

# 1.2 -- read in all med prescriptions
person_all_meds <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/medication/person-medication.csv")
colnames(person_all_meds) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

# 1.3 -- get the MRNs of people with crohn's med prescriptions
person_crohns_meds <- merge(person_all_meds, anno_crohns_meds, by.x="MSDW",  by.y="CODE")
mrns.crohns.meds <- as.character(unique(person_crohns_meds$MRN))

### Step 2: Get people with corresponding ICD9 codes (inclusion and exclusion)
## 2.1 read in msdw2 data
icd9_anno <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/annotation-icd9.csv")
icd9_person <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/person-icd9.csv")

colnames(icd9_person) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

setkey(icd9_anno, CODE)
setkey(icd9_person, MSDW)

tmp <- merge(icd9_anno, icd9_person, by.x="CODE", by.y="MSDW", allow.cartesian = TRUE)

setkeyv(tmp, c("CODE", "CUI", "ONTOLOGY_ID", "MRN", "EID", "TIMESTAMP"))
icd9.merged <- unique(tmp, by=key(tmp))
rm(tmp)

## 2.2 read in crohn's disease ICD9 codes we want (include)
case.icd9.include <- fread("/data1/accounts/students/johnsk26/projects/embeddings/code/crohns/icd_inclusion.txt")
colnames(case.icd9.include) <- "ICD9_CODE"
crohns.icd9.include <- subset(icd9.merged, ONTOLOGY_ID %in% case.icd9.include$ICD9_CODE)

# cast crohn's ICDs
crohns.icd9.include.counts <- dcast(crohns.icd9.include, 
                                    formula = MRN ~ ONTOLOGY_ID,
                                    fun.aggregate = length,
                                    value.var = "EID")

colnames(crohns.icd9.include.counts)[2:5] <- paste0('icd', colnames(crohns.icd9.include.counts)[2:5])
crohns.icd9.include.counts.gte2 <- crohns.icd9.include.counts[icd555>=2 | icd555.1>=2 | icd555.2>=2 | icd555.9>=2]

## 2.3 read in crohn's disease ICD9 codes we DON'T want (exclude)
case.icd9.exclude <- fread("/data1/accounts/students/johnsk26/projects/embeddings/code/crohns/icd_exclusion.txt")
colnames(case.icd9.exclude) <- "ICD9_CODE"
crohns.icd9.exclude <- subset(icd9.merged, ONTOLOGY_ID %in% case.icd9.exclude$ICD9_CODE)

## 2.4 Get a final set of ICD9 Crohn's Dz patients
mrns.crohns.icd9 <- setdiff(crohns.icd9.include.counts.gte2$MRN, crohns.icd9.exclude$MRN)

## Step 3
## 3.1 Intersect5 Crohn's Dz ICD9 MRNs with Crohn's DZ Drug-Receiving MRNs
mrn_crohns <- intersect(mrns.crohns.icd9, mrns.crohns.meds)

## Step 4 -- Save the results!
write.table(x=mrn_crohns,
            file="/data1/accounts/students/johnsk26/projects/embeddings/results/crohns_mrns.txt",
            quote=F, row.names = F, col.names = F)










