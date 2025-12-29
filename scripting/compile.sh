#!/bin/bash

# Delete compile.dat if it exists
if [ -f "compile.dat" ]; then
    rm compile.dat
fi

# Get the filename without extension
filename="$(basename "$1" .sp)"

# Compile with spcomp64
./spcomp64 "${filename}.sp" -o "../plugins/${filename}.smx"

