# ms_phenotype.R
# libraries
library(stringr)
library(data.table)

###
### Step 1: Find MRNs who have notes that mention "multiple sclerosis"
###
# Parse out the required terms from EHR strings fusing supplied regex
vocab <- fread("/home/johnsk26/projects/embeddings/dat/vocab_subset.csv")

# From document: (we added caret before a\\w)
# REGEXP_LIKE(IMPRESSION,’((^|[ \.])AF($|[ \.]))|(a\w*[ .]?(fib[\w]*|flutter))’,’i')

ms.regex <- 'multiple sclerosis'

matches <- vocab[grep(pattern=ms.regex,
                      x=vocab[, STR],
                      ignore.case=TRUE)]

matches.termid <- as.character(unique(matches$TERM_ID))
matches.termid.regex <- paste0('[^n](', matches.termid, "\\b)")

## Write out all of the regexes
fcon <- file(description = "/data1/accounts/students/johnsk26/projects/embeddings/code/ms/ms_regex.txt", open = "w")
writeLines(matches.termid.regex, con=fcon)
close(fcon)

## Step 1.2 
## We used ripgrep (rg) in bash in order to extract NOTE_IDs and corresponding sequences of TERM_IDs
## matching to the afib TERM_IDs
## bash script to do so at:
## /data1/accounts/students/johnsk26/projects/embeddings/code/ms/ripgrep_ms_text.sh
## Output is at: 
## cat /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/ms_regex_rg_notes-annotation-sequence.csv
## First  column is note IDs:
## /data1/accounts/students/johnsk26/projects/embeddings/dat/ms/ms_regex_rg_NOTE_IDs.txt
note.sequences <- fread("/data1/accounts/students/johnsk26/projects/embeddings/dat/ms/ms_regex_rg_NOTE_IDs.txt")
colnames(note.sequences) <- "NOTE_ID"

# Step 1.3
# Match the Note IDs to MRNs, giving us a list of MRNs with a note that says "multiple sclerosis"
note_types <- fread("/home/riccardo/data2/msdw-import/data/processed-notes/msdw_2017/notes-type.csv")
all_notes <- note_types
rm(note_types)

setkey(all_notes, NOTE_ID)
setkey(note.sequences, NOTE_ID)

ms.notes <- merge(all_notes, note.sequences, by.x="NOTE_ID",   by.y="NOTE_ID")
ms.notes.mrns <- unique(ms.notes$MEDICAL_RECORD_NUMBER)

###
### Step 2: Find people by ICD codes
###

## 5.1 read in msdw2 data
icd9_anno <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/annotation-icd9.csv")
icd9_person <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/person-icd9.csv")

colnames(icd9_person) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

setkey(icd9_anno, CODE)
setkey(icd9_person, MSDW)

tmp <- merge(icd9_anno, icd9_person, by.x="CODE", by.y="MSDW", allow.cartesian = TRUE)
ms.icd9 <- unique(tmp[CODE=='340'])
ms.icd9[, nCodes := .N, by=.(MRN)]
ms.icd9 <- ms.icd9[nCodes>=2]

## Type 1 just takes 2 MS codes
ms.mrn.type1 <- unique(ms.icd9$MRN)
write.table(ms.mrn.type1, file="/home/johnsk26/projects/embeddings/results/ms_type1.txt", quote=F, row.names = F, col.names = F)

ms2.icd9 <- tmp[CODE=='341.9' | CODE=='323.9' | CODE=='341.2' | CODE=='341.20' | CODE=='341.21']
msICD.mrn.type2 <- unique(ms2.icd9$MRN) # list of MRNs with these ICD codes


### Step 3: Find people by MS meds
### Used rg to extract all MS meds per the document
### med list (verified): /data1/accounts/students/johnsk26/projects/embeddings/dat/ms/ms_drugs.txt
### MS extracted meds are stored here: 
## /data1/accounts/students/johnsk26/projects/embeddings/dat/ms/ms_meds.txt

# 1.1 -- read in crohn's meds in order to get the MSDW code
anno_ms_meds <- fread("/data1/accounts/students/johnsk26/projects/embeddings/dat/ms/ms_meds.txt")
colnames(anno_ms_meds) <- c("CODE", "CUI", "ONTOLOGY_ID", "LABEL")

# 1.2 -- read in all med prescriptions
person_all_meds <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/medication/person-medication.csv")
colnames(person_all_meds) <- c("MRN", "MSDW", "EID", "TIMESTAMP")

# 1.3 -- get the MRNs of people with crohn's med prescriptions
person_ms_meds <- merge(person_all_meds, anno_ms_meds, by.x="MSDW",  by.y="CODE")
mrns.ms.meds <- as.character(unique(person_ms_meds$MRN))
