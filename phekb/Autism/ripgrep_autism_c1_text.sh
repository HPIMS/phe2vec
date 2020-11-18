#!/bin/bash
/usr/bin/rg -i -f /home/jessica/projects/embeddings/code/autism/regex/autism_c1_regex.txt --threads 28 /home/riccardo/data2/msdw-import/data/processed-notes/msdw_2017/notes-annotation-sequence.csv > /home/jessica/projects/embeddings/dat/autism/autism_c1_regex_rg_notes-annotation-sequence.csv
cat /home/jessica/projects/embeddings/dat/autism/autism_c1_regex_rg_notes-annotation-sequence.csv | awk -F"," '{print $1}' > /home/jessica/projects/embeddings/dat/autism/autism_c1_regex_rg_NOTE_IDs.txt
