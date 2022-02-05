#!/bin/bash

# Fixing a WSL problem with aliases. Just skip this, linux user
shopt -s expand_aliases
source ~/.bash_aliases

if [[ $1 == 'manual' ]]
then
    if [[ $2 == 'gray' ]]
    then
        # Generate .tex file from .lhs file
        lhs2Tex manual/manual.lhs > manual/manual.tex

        # Generate black and white pdf from created .tex file
        pdflatex -shell-escape -output-directory='manual/' manual/manual.tex

        # Renaming
        mv manual/manual.pdf manualGray.pdf
	
    elif [[ $2 == 'colorful' ]]
    then
        # Generate colorful pdf from .lhs file
        pdflatex -shell-escape -output-directory='manual/' manual/manual.lhs

        # Renaming
        mv manual/manual.pdf manualColorful.pdf
	
    elif [[ $2 == 'compile' ]]
    then
        # Compile the manual
        ghc manual/manual.lhs

	# Moving to current directory (Unix and Windows)
	mv manual/manual manual
	mv manual/manual.exe manual.exe
	
    else
        echo "No available option! Use compile, gray or colorful!"
    fi
elif [[ $1 == 'thesis' ]]
then
    if [[ $2 == 'gray' ]]
    then
        # Generate .tex file from .lhs file
        lhs2Tex GraduationThesis/thesis.lhs > GraduationThesis/thesis.tex

        # Generate black and white pdf from created .tex file
        pdflatex -shell-escape -output-directory='GraduationThesis/' GraduationThesis/thesis.tex

        # Renaming and moving
        mv GraduationThesis/thesis.pdf thesisGray.pdf

    elif [[ $2 == 'colorful' ]]
    then
        # Generate colorful pdf from .lhs file
        pdflatex -shell-escape -output-directory='GraduationThesis/' "\def\iscolorful{} \input{GraduationThesis/thesis.lhs}"

        # Renaming and moving
        mv GraduationThesis/thesis.pdf thesisColorful.pdf

    elif [[ $2 == 'compile' ]]
    then
        # Compile the thesis
        ghc GraduationThesis/thesis.lhs

	# Moving to current directory (Unix and Windows)
	mv GraduationThesis/thesis thesis
	mv GraduationThesis/thesis.exe thesis.exe

    else
        echo "No available option! Use compile, gray or colorful!"
    fi
else
    echo "No available documentation! Use manual or thesis!"
fi
