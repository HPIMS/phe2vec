#libraries
library(stringr)
library(data.table)
library(dplyr)
library(tidyr)

# Step 1: Select cases by ICD9 codes

# 1.1 read in all msdw ICD9 data
icd9_anno <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/annotation-icd9.csv")
icd9_person <- fread("/home/riccardo/data2/datasets/msdw/msdw2b/ehr-csv/icd9/person-icd9.csv", colClasses = "character")
colnames(icd9_person) <- c("MRN", "MSDW", "EID", "TIMESTAMP")
setkey(icd9_anno, CODE)
setkey(icd9_person, MSDW)
tmp <- merge(icd9_anno, icd9_person, by.x="CODE", by.y="MSDW", allow.cartesian = TRUE)
setkeyv(tmp, c("CODE", "CUI", "ONTOLOGY_ID", "MRN", "EID", "TIMESTAMP"))
icd9_merged <- unique(tmp, by=key(tmp))

# 1.2 read in exclusion codes
excl_icd <- fread("/home/jessica/projects/embeddings/code/autism/icd_exclusion.txt")
colnames(excl_icd) <- "ICD9_CODE"
icd9_to_excl <- subset(icd9_merged, (ONTOLOGY_ID %in% excl_icd$ICD9_CODE))
mrn_to_excl <- unique(icd9_to_excl$MRN)
icd9_filtered <- subset(icd9_merged, !(MRN %in% mrn_to_excl))

# 1.3 read in inclusion codes
incl_icd <- fread("/home/jessica/projects/embeddings/code/autism/icd_inclusion.txt", colClasses = "character")
colnames(incl_icd) <- "ICD9_CODE"
icd9_to_incl <- subset(icd9_merged, (ONTOLOGY_ID %in% incl_icd$ICD9_CODE))
mrn_to_incl <- unique(icd9_to_incl$MRN)
icd9_filtered2 <- subset(icd9_filtered, (MRN %in% mrn_to_incl))

# Step 2: Create regexs from criteria phrases

# phrases provided by pheKB algorithm
phrase_files <- list.files("/home/jessica/projects/embeddings/code/autism/phrases", full.names = TRUE)

get_regex_from_phrase_files <- function(x, vocab) {
  y <- fread(x, header = FALSE, sep = "\n")
  get_regex_from_phrase <- function(string_to_parse){
    paste_rg <- function(x){
      paste0('(\\b|^)(', x, '\\b)')
    }
    vocab <- fread("/home/johnsk26/projects/embeddings/dat/vocab_subset.csv")
    share_regex <- vector()
    for (j in 1:nrow(string_to_parse)){
      print(j)
      string_input <- str_split(string_to_parse[j], pattern = " ") %>% unlist() %>% str_to_lower()
      string_regex <- vector()
      
      for (i in 1:length(string_input)) {
        if(string_input[i] == "not"){
          string_regex[i] <- "n"
        }else {
          pat <- paste0("(^", string_input[i], "\\b$)")
          vocab_match <- vocab[grep(pattern= pat,
                                    x=vocab[, STR],
                                    ignore.case=TRUE)] 
          string_regex[i] <- vocab_match[1,2, with=FALSE] %>% unique() %>% as.character()
          if(i > 1){
            if(string_regex[i-1] == "n"){
              string_regex[i-1] <- "NA"
              string_regex[i] <- paste0("n", string_regex[i])
            }
          }
        }
      }
      for (i in 1:length(string_regex)){
        if (string_regex[i] == "NA" | string_regex[i] == "nNA") {
          string_regex[i] <- NA
        }
      }
      string_regex <- string_regex[!is.na(string_regex)]
      share_regex[j] <- sapply(string_regex, paste_rg) %>% as.vector() %>% paste0(collapse = "[|]")
    }
    return(share_regex)
  }
  z <- get_regex_from_phrase(y)
  return(z)
}
catID <- c("c1", "c2", "c3")
regex_results <- lapply(get_regex_from_phrase_files, phrase_files)

for(i in 1:length(regex_results)){
  c_rex <-regex_results[[i]]
  c_rex <- c_rex[c(which(c_rex != ""))]
  fcon <- file(description = paste0("/home/jessica/projects/embeddings/code/autism/regex/autism_", catID[i], "_regex.txt"), open = "w")
  writeLines(c_rex, con=fcon)
  close(fcon)
}


## Step 3 Get noteIDs with mentions of criteria phrases

## We used ripgrep (rg) in bash in order to extract NOTE_IDs and corresponding sequences of TERM_IDs
## matching to the autism TERM_IDs
## bash script to do so at:
## /home/jessica/projects/embeddings/code/autism/ripgrep/ripgrep_autism_***_text.sh
## Output is at: 
## /home/jessica/projects/embeddings/dat/autism/autism_***_regex_rg_notes_annotation_sequence.csv
## First  column is note IDs:
## /home/jessica/projects/embeddings/dat/autism/autism_***_regex_rg_NOTE_IDs.txt

currDir <- paste0("/home/jessica/projects/embeddings/code/autism/ripgrep/")
regexDir <- "/home/jessica/projects/embeddings/code/autism/regex/"
msdw_notes <- "/home/riccardo/data2/msdw-import/data/processed-notes/msdw_2017/notes-annotation-sequence.csv"
outputDir <- "/home/jessica/projects/embeddings/dat/autism/"

for (i in 1:length(catID)){
line0 <- "#!/bin/bash"
line1 <- paste0("/usr/bin/rg -i -f ", regexDir, "autism_", catID[i], "_regex.txt", " --threads 28 ",  msdw_notes, " > ", outputDir, "autism_", catID[i], "_regex_rg_notes-annotation-sequence.csv")
line2 <- paste0("cat ", outputDir, "autism_", catID[i], "_regex_rg_notes-annotation-sequence.csv | awk -F\",\" \'{print $1}\' > ", outputDir, "autism_", catID[i], "_regex_rg_NOTE_IDs.txt")

ripgrepBash <-
  paste0("/home/jessica/projects/embeddings/code/autism/ripgrep/ripgrep_autism_", catID[i], "_text.sh")
fileConn <- file(ripgrepBash)
writeLines(paste(line0, line1, line2, sep = "\n"), fileConn)
close(fileConn)
#command <- paste("./", ripgrepBash, sep="")
command <- paste("chmod u+x", ripgrepBash, sep = " ")
system(command = command)
system(command = ripgrepBash, wait = TRUE)
}
  
list.files("/home/jessica/projects/embeddings/dat/autism/", pattern = "^autism_c*")

fconn <- file(description = "/home/jessica/projects/embeddings/code/autism/regex/autism_c1_regex_rg_NOTE_IDs.txt", open = "w")
writeLines(this, con=fconn)
close(fconn)

note_files <- list.files("/home/jessica/projects/embeddings/dat/autism/", pattern = "NOTE_IDs.txt$", full.names = TRUE)

note_types <- fread("/home/riccardo/data2/msdw-import/data/processed-notes/msdw_2017/notes-type.csv", 
                    colClasses = c("character", "character", "character", "integer","character"))
prog_notes <- note_types[NOTE_TYPE=="Progress Report"]
setkey(prog_notes, NOTE_ID)

#notes_anno_seq <- fread("/home/jessica/projects/embeddings/dat/autism/autism_c1c_regex_rg_notes_annotation_sequence.csv")


for (i in 1:length(note_files)){
  note_sequences <- fread(note_files[i])
  setkey(note_sequences, NOTE_ID)
  colnames(note_sequences_c1c) <- "NOTE_ID"
  
  autism_notes <- merge(prog_notes, note_sequences, by.x="NOTE_ID",   by.y="NOTE_ID")
  autism_notes_mrn <- unique(autism_notes$MEDICAL_RECORD_NUMBER)
  
  autism_notes <- merge(prog_notes, note_sequences, by.x="NOTE_ID",   by.y="NOTE_ID")
  # autism_c1a_notes[, nNotes := .N, by=.(MEDICAL_RECORD_NUMBER)]
  # autism_c1a_notes_mrn <- autism_c1a_notes[nNotes>=2, unique(MEDICAL_RECORD_NUMBER)]
  # autism_c1a_notes_mrn <- unique(autism_c1a_notes$MEDICAL_RECORD_NUMBER)
  
  ## Write out all of the MRNs
  fcon <- file(description = paste0("/home/jessica/projects/embeddings/code/autism/mrn/autism_c", i ,"_mrn.txt", open = "w"))
  writeLines(autism_notes_mrn, con=fcon)
  close(fcon)
  
}

# Autism spectrum disorder is made up of 3 types:
## Type 1) Classical autism, Type 2) Asperger's, Type 3) PDD-NOS (Pervasive developmental 
# disorders - not otherwise specified)

# Step 5 Identify TYPE1 cases with at least 6 items, at least: two for cat1, and one from cat2, cat3


cat1_mrn <- fread("/home/jessica/projects/embeddings/code/autism/mrn/autism_c1_mrn.txt", colClasses = "character")
cat2_mrn <- fread("/home/jessica/projects/embeddings/code/autism/mrn/autism_c2_mrn.txt", colClasses = "character")
cat3_mrn <- fread("/home/jessica/projects/embeddings/code/autism/mrn/autism_c3_mrn.txt", colClasses = "character")

x <- rep("cat1", length(cat1_mrn))
dim(x) <- c(length(cat1_mrn), 1)
cat1_mrn_table <- cbind(cat1_mrn, x) %>% as.data.table()
colnames(cat1_mrn_table) <- c("MRN", "cat")
cat1_counts <- count(cat1_mrn_table, MRN) %>% as.data.table()
y <- rep("cat1", length(cat1_counts))
dim(y) <- c(length(cat1_counts),1)
cat1_count_table <- cbind(cat1_counts, y)
colnames(cat1_count_table) <- c("MRN", "N", "cat")

x <- rep("cat2", length(cat2_mrn))
dim(x) <- c(length(cat2_mrn), 1)
cat2_mrn_table <- cbind(cat2_mrn, x) %>% as.data.table()
colnames(cat2_mrn_table) <- c("MRN", "cat")
cat2_counts <- count(cat2_mrn_table, MRN) %>% as.data.table()
y <- rep("cat2", length(cat2_counts))
dim(y) <- c(length(cat2_counts),1)
cat2_count_table <- cbind(cat2_counts, y)
colnames(cat2_count_table) <- c("MRN", "N", "cat")

x <- rep("cat3", length(cat3_mrn))
dim(x) <- c(length(cat3_mrn), 1)
cat3_mrn_table <- cbind(cat3_mrn, x) %>% as.data.table()
colnames(cat3_mrn_table) <- c("MRN", "cat")
cat3_counts <- count(cat3_mrn_table, MRN) %>% as.data.table()
y <- rep("cat3", length(cat3_counts))
dim(y) <- c(length(cat3_counts),1)
cat3_count_table <- cbind(cat3_counts, y)
colnames(cat3_count_table) <- c("MRN", "N", "cat")

all_counts <- rbind(cat1_count_table, cat2_count_table, cat3_count_table)
all_count_table <- spread(all_counts, cat, N) 
all_count_table <- all_count_table %>%mutate(total = rowSums(.[2:4], na.rm = TRUE))

all_count_table[is.na(all_count_table)] <- 0

icd_MRN <- icd9_filtered$MRN %>% unique() %>% as.data.table()
colnames(icd_MRN) <- "MRN"

mrn_count_join <- semi_join(all_count_table, icd_MRN)
mrn_keep <- mrn_count_join[which(mrn_count_join$total >= 6 & mrn_count_join$cat1 >= 2 & mrn_count_join$cat2 > 0 & mrn_count_join$cat3 > 0),]

autism_mrn <- mrn_keep$MRN

fcon <- file(description = "/home/jessica/projects/embeddings/results/autism_mrns.txt", open = "w")
writeLines(autism_mrn, con=fcon)
close(fcon)




