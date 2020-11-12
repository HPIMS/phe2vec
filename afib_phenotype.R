#libraries
library(stringr)
library(data.table)

# Step 1: Parse out the required terms from EHR strings fusing supplied regex
vocab <- fread("/home/johnsk26/projects/embeddings/dat/vocab_subset.csv")

# From document: (we added caret before a\\w)
# REGEXP_LIKE(IMPRESSION,’((^|[ \.])AF($|[ \.]))|(a\w*[ .]?(fib[\w]*|flutter))’,’i')

afib.regex <- '((^|[ \\.])AF($|[ \\.]))|(^a\\w*[ .]?(fib[\\w]*|flutter))'

matches <- vocab[grep(pattern=afib.regex,
                      x=vocab[, STR],
                      ignore.case=TRUE)]

matches.termid <- as.character(unique(matches$TERM_ID))
matches.termid.regex <- paste0('[^n](', matches.termid, "\\b)")

## Write out all of the regexes
fcon <- file(description = "/data1/accounts/students/johnsk26/projects/embeddings/code/afib/afib_regex.txt", open = "w")
writeLines(matches.termid.regex, con=fcon)
close(fcon)

## Step 2: 
## We used ripgrep (rg) in bash in order to extract NOTE_IDs and corresponding sequences of TERM_IDs
## matching to the afib TERM_IDs
## bash script to do so at:
## /data1/accounts/students/johnsk26/projects/embeddings/code/afib/ripgrep_afib_text.sh
## Output is at: 
## /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_notes-annotation-sequence.csv
## First  column is note IDs:
## /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_NOTE_IDs.txt
note.sequences <- fread("/data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_NOTE_IDs.txt")
colnames(note.sequences) <- "NOTE_ID"

# Step 3
# Match the Note IDs to MRNs, giving us a list of MRNs with a note that says "afib something"
note_types <- fread("/home/riccardo/data2/msdw-import/data/processed-notes/msdw_2017/notes-type.csv")
ekg_notes <- note_types[NOTE_TYPE=="EKG Report"]
rm(note_types)

setkey(ekg_notes, NOTE_ID)
setkey(note.sequences, NOTE_ID)

afib.notes <- merge(ekg_notes, note.sequences, by.x="NOTE_ID",   by.y="NOTE_ID")
afib.notes.mrns <- unique(afib.notes$MEDICAL_RECORD_NUMBER)

# Step 4: Exclude people by CPT codes
# We now have a list of all the MRNs with afib mentions in their EKG reports
# Now we are proceeding to the ICD/CPT code analysis portion
# 4.1 read in MSDW2 CPT codes
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
rm(tmp)

## 4.2 read in atrial fibrillation CPT codes we don't want
case.cpt.exclude <- fread("/data1/accounts/students/johnsk26/projects/embeddings/code/afib/case_cpt.csv")
colnames(case.cpt.exclude) <- "CPT_CODE"
cpt_excluded_mrns <- subset(cpt.merged, ONTOLOGY_ID %in% case.cpt.exclude$CPT_CODE, select=MRN)

### Step 5: Exclude peope by ICD codes
## 5.1 read in msdw2 data
icd9_anno <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/annotation-icd9.csv")
icd9_person <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/person-icd9.csv")

colnames(icd9_person) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

setkey(icd9_anno, CODE)
setkey(icd9_person, MSDW)

tmp <- merge(icd9_anno, icd9_person, by.x="CODE", by.y="MSDW", allow.cartesian = TRUE)

#we don't care how many times they happened, so removing EID and timestamp columns
setkeyv(tmp, c("CODE", "CUI", "ONTOLOGY_ID", "MRN"))
icd9.merged <- unique(tmp, by=key(tmp))
rm(tmp)

## 5.2 read in atrial fibrillation ICD9 codes we don't want
case.icd9.exclude <- fread("/data1/accounts/students/johnsk26/projects/embeddings/code/afib/case_icd.csv")
colnames(case.cpt.exclude) <- "ICD9_CODE"
icd9_excluded_mrns <- subset(icd9.merged, ONTOLOGY_ID %in% case.cpt.exclude$ICD9_CODE, select=MRN)

## Step 6:
## We will exclude the afib_note MRNs as per algorithm
## If they have any of the identified CPT or ICD codes
ekg.included.mrns <- sort(as.character(afib.notes.mrns))
cpt.excluded.mrns <- sort(cpt_excluded_mrns$MRN)
icd.excluded.mrns <- sort(icd9_excluded_mrns$MRN)

head(ekg.included.mrns)
head(cpt.excluded.mrns)
head(icd.excluded.mrns)

intersect(ekg.included.mrns, cpt.excluded.mrns)
intersect(ekg.included.mrns, icd.excluded.mrns)

ekg.in_cpt.out_MRNs <- setdiff(ekg.included.mrns, cpt.excluded.mrns)
ekg.in_cpt.out_icd9.out_MRNs <- setdiff(ekg.in_cpt.out_MRNs, icd.excluded.mrns)
ekg.in_cpt.out_icd9.out_MRNs <- sort(ekg.in_cpt.out_icd9.out_MRNs)

write.table(x=ekg.in_cpt.out_icd9.out_MRNs,
            file="/data1/accounts/students/johnsk26/projects/embeddings/results/afib_mrns.txt",
            quote=F, row.names = F, col.names = F)


