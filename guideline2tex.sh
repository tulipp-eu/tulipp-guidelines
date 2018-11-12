#!/bin/bash

# This will include every markdown file which is not referenced in the Home.md
# AND is not included in blacklistFiles
includeUnreferenced=0

blacklistFiles="_Footer.md Guideline-Review-Template.md Guideline-Template.md"

requiredApps="pandoc awk tr egrep paste sed find sort"

workDir=$(dirname $(readlink -f $0))


function md2tex {
    [ $# -lt 2 ] && exit
    # this very big column number prevents insertions of ugly minipages
    pandoc --from=markdown --output="$2" --wrap=none --columns=1000000 "$1"
}

function postProcess {
    filename=$(basename $1)
    filename=${filename%.*}

    # Turn links into file references
    sed -i -r 's/https\:\/\/[a-zA-Z0-9\.\/\-]+\/wiki\///g' "$1"
    # Remove self references
    sed -i -r -e "s/\\\\href[{]${filename}[^}]*[}][{]([^}]*)[}]/\\1/gI" "$1"
    # Turn href to hyperref
    sed -i -r 's/\\href[{]([^}]*)[}]/\\hyperref[\L\1]/g' "$1"
    # Remove labels
    sed -i -r 's/\\label[{][^}]*[}]//g' "$1"
    # Removing '#' and '\%23' from references filenames
    # Converting '\%28' and '\%29' to '(' and ')'
    sed -i -r '/\\hyperref\[/,/\]/s/\\#//g' "$1"
    sed -i -r '/\\hyperref\[/,/\]/s/\\%23//g' "$1"
    sed -i -r '/\\hyperref\[/,/\]/s/\\%28/(/g' "$1"
    sed -i -r '/\\hyperref\[/,/\]/s/\\%29/)/g' "$1"
    # remove pandocs \tightlist
    sed -i -r 's/\\tightlist//g' "$1"
    # limit images to linewidth
    sed -i -r 's/\\includegraphics/\\includegraphics[max width=\\linewidth]/g' "$1"
    # rework longtables to tabularx
    sed -i -r 's/\\begin[{]longtable[}]\[[^]]*\][{]\@\{\}([^}]*)\@\{\}[}]/\\begin\{tabularx\}\{\\columnwidth\}\{\1\}/g' "$1"
    sed -i -r 's/\\endhead//g' "$1"
    sed -i -r 's/\\end[{]longtable[}]/\\end\{tabularx\}/g' "$1"
    # replacing all column specifier after the first one with X
    sed -i -r ':a;s/(\\begin\{tabularx\}\{\\columnwidth\}\{[a-zA-Z][X]*)[^X]([^}]*\})/\1X\2/;t a' "$1"
    # replace '``' with '“' and '''' with '”'
    sed -i -r 's/``/“/g' "$1"
    sed -i -r 's/„/“/g' "$1" # if this was used, replace it with an uniform start quote character
    sed -i -r "s/''/”/g" "$1"
}

function insertSection {
    [ $# -lt 2 ] && exit
    filename=$(basename $1)
    filename=${filename%.*}
    title=$(echo $2 | sed -e 's/[\/&]/\\&/g')
    #Inserting section
    sed -i "1s/^/\\\\section\{${title}\}\n/" "$1"
    sed -i "2s/^/\\\\label\{${filename}\}\n/" "$1"
    #Get the Guideline Number
    guidelineNum=$(grep "Guideline Number" "$1" | egrep -o '[0-9]+' | head -n 1)
    [ -z $guidelineNum ] && {
        echo "WARNING: Guideline number from '$1' was not found!" >&2
    } || {
        sed -i "3s/^/\\\\label\{guideline_${guidelineNum}\}\n/" "$1"
    }
}


goOn=1
for i in $requiredApps; do
    whereis ${i} >/dev/null 2>&1  || {
        echo "Could not find application '$i'" >&2
        goOn=0
    }
done;
[ $goOn -ne 1 ] && exit 1


[ -f $workDir/Home.md ] || {
    echo "Coult not find '$workDir/Home.md'" >&2
    exit 1
}

echo "Creating $workDir/tex folder..."
mkdir -p ${workDir}/tex

echo "Analysing ${workDir}/Home.md file..."

# Gather all files reffered to in Home.md
egrep -E -o '\[[^]]+\]\([^)]+\)' "${workDir}/Home.md" | cut -f1 -d']' | tr -d '[]()' > ${workDir}/tex/titles.tmp
egrep -E -o '\[[^]]+\]\([^)]+\)' "${workDir}/Home.md" | cut -f2 -d']' | tr -d '[]()' | tr '/' '-' | sed 's/\%28/(/g' | sed 's/\%29/)/g' | awk '{print $1".md"}' > ${workDir}/tex/files.tmp
paste ${workDir}/tex/titles.tmp ${workDir}/tex/files.tmp > ${workDir}/tex/process.tmp
rm ${workDir}/tex/titles.tmp
rm ${workDir}/tex/files.tmp

for i in $blacklistFiles; do
    sed -i "/^.*\\t${i}\$/d" ${workDir}/tex/process.tmp
done

echo "Found $(cat ${workDir}/tex/process.tmp | wc -l) referenced files!"

echo "Converting main file..."
md2tex "$workDir/Home.md" "$workDir/tex/Home.tex"
postProcess "$workDir/tex/Home.tex"

echo '\documentclass[12pt]{article}
\usepackage[utf8]{inputenc}
\usepackage{tabularx}
\usepackage{booktabs}
\usepackage{graphicx}
\usepackage{listing}
\usepackage{hyperref}
\usepackage[export]{adjustbox}

\setlength\parindent{0pt}

\begin{document}' > $workDir/master.tex

echo "\\include{tex/Home}" >> $workDir/master.tex

while IFS= read -u 10 line; do
    filemd=$(echo -n "$line" | awk -F'\t' '{print $2}')
    # insensitive file search
    [ -f "$workDir/$filemd" ] || {
        tmp=$(find "$workDir" -maxdepth 1 -iname "$filemd")
        [ -f "$tmp" ] && {
            filemd=$(basename $tmp)
        } || {
            echo "WARNING: '$workDir/$filemd' was not found!" >&2
        }
    }
    [ -f "$workDir/$filemd" ] && {
        filename=${filemd%.*}
        filetex=$(echo -n ${filename/\#/}.tex | tr '[:upper:]' '[:lower:]')
        title=$(echo -n "$line" | awk -F'\t' '{print $1}')
        echo "Converting referenced file '$workDir/$filemd'..."
        md2tex "$workDir/$filemd" "$workDir/tex/$filetex"
        postProcess "$workDir/tex/$filetex"
        insertSection "$workDir/tex/$filetex" "$title"
        echo "\\include{tex/${filetex%.tex}}" >> $workDir/master.tex
    }
done 10<${workDir}/tex/process.tmp

[ $includeUnreferenced -eq 1 ] && {
    echo "Home.md $blacklistFiles" >> "${workDir}/tex/process.tmp"
    for filemd in $(echo ${workDir}/*.md | tr ' ' '\n' | sort -V); do
        filemd=$(basename $filemd)
        filename=${filemd%.*}
        filetex=$(echo -n ${filename/\#/}.tex | tr '[:upper:]' '[:lower:]')
        count=0
        grep -q -i "$filemd" "${workDir}/tex/process.tmp" || {
            echo "Convert unreferenced files '$workDir/$filemd'..."
            md2tex "$workDir/$filemd" "$workDir/tex/$filetex"
            postProcess "$workDir/tex/$filetex"
            grep -q -i '\\section' "$workDir/tex/$filetex" || {
                insertSection "$workDir/tex/$filetex" "Unreferenced-File-$count"
                count=$(($count + 1))
            }
            echo "\\include{tex/${filetex%.tex}}" >> $workDir/master.tex
        }
    done
}

echo '\end{document}' >> $workDir/master.tex

rm "${workDir}/tex/process.tmp"
exit 0
