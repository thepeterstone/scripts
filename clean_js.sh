#!/bin/zsh

# delete trailing whitespace
sed 's/[ \t]*$//' |
# delete repeated blank lines
sed '/./,/^$/!d' |
# Use [] and {} instead of new Array() or new Object()
sed -e 's/new Array()/[]/g' -e 's/new Object()/{}/g' |
# One space between keywords and parens
sed -e 's/function(/function (/g' -e 's/for(/for (/g' -e 's/if(/if (/g' |
# no spaces inside parens
sed -e 's/( /(/g' -e 's/ )/)/g' |
# braces: same line, one space
sed -e '/)\s*$/ { N; s/)[ \t]*\n[ \t]*{/) {/g; }' -e 's/)[ \t]*{/) {/g' |
sed -e '/else\s*$/ { N; s/else[ \t]*\n[ \t]*{/else {/g; }' -e 's/else[ \t]*{/else {/g' |
cat