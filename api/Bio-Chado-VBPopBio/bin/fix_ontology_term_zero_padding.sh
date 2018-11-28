#!/usr/bin/env bash
#
# usage: bin/fix_ontology_term_zero_padding.sh ISA-DIRECTORY
#
# When zero padding of accession numbers has been messed up by spreadsheets
# this will fix them inplace (preserving the original in filename.txt.bak)
#
# CAVEAT: will need updating for more ontologies
#
#

directory=$1

if [ -z $directory ]
then
  echo must give an ISA-Tab directory as argument
  exit
fi

if [ ! -d $directory ]
then
  echo $directory is not a directory
  exit
fi

if [ ! -e "$directory/i_investigation.txt" ]
then
  echo $directory does not look like an ISA-Tab directory
  exit
fi

echo fixing a_ s_ p_ and g_ files in $directory only

for file in $directory/[aspg]_*.txt
do

  perl -i.bak -npe 's/\b(VBcv|VBsp|IRO|UO|VSMO|IDOMAL|PATO|EFO|OBI)\t(\d+)\b/sprintf "%s\t%07d", $1, $2/ge; s/\b(MIRO|GAZ)\t(\d+)/sprintf "%s\t%08d", $1, $2/ge' $file

  # check to see if that actually did anything
  if ! cmp --quiet $file $file.bak
  then
    echo \*\*fixed\*\* $file
  else
    echo no-change $file
    rm $file.bak
  fi

done
