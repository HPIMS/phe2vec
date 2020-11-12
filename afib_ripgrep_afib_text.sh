#!/bin/bash

## Temporary command
# /usr/bin/rg -i -f /data1/accounts/students/johnsk26/projects/embeddings/code/afib/afib_regex.txt --stats --threads 28 /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/notes-annotation-sequence-head100k.csv > /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_notes-annotation-sequence.csv

## Real command
/usr/bin/rg -i -f /data1/accounts/students/johnsk26/projects/embeddings/code/afib/afib_regex.txt --threads 28 /home/riccardo/data2/msdw-import/data/processed-notes/msdw_2017/notes-annotation-sequence.csv > /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_notes-annotation-sequence.csv

## Extract out NOTE_IDs from file
cat /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_notes-annotation-sequence.csv | awk -F"," '{print $1}' > /data1/accounts/students/johnsk26/projects/embeddings/dat/afib/afib_regex_rg_NOTE_IDs.txt
