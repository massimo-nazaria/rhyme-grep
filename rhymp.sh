#!/usr/bin/env bash
# rhymp -- a grep-based tool to find rhyming words in text
# code repository: https://github.com/massimo-nazaria/rhyme-grep
# usage: ./rhymp.sh [word] [file] [-o|--only-rhyming]
# note: if no [file] given, read text from stdin

# function that prints usage on stderr and exits
function print_usage_and_exit {
	echo "usage: $0 [word] [file] [-o|--only-rhyming" >> /dev/stderr;
	exit 1;
}

# default grep argument flags (do "man grep" on a terminal for more info)
DEFAULT_GREP_FLAGS="-E -wi";
# compute default CMU dictionary file with full path (i.e. same folder as this script)
DEFAULT_CMUDICT_FILE_FULLPATH="$(dirname "$(realpath "$0")")/cmudict/cmudict.dict";

# pronunciation dictionary file
cmudict="${DEFAULT_CMUDICT_FILE_FULLPATH}";
# default grep argument flags
grep_flags="${DEFAULT_GREP_FLAGS}";
# default input file (i.e. "-" stands for /dev/stdin)
input_file="-";
# init input word to the empty string
input_word="";
# init to zero the -o flag
oflag=0;

# check argument number
if [[ $# -eq 0 || $# -gt 3 ]]; then
	print_usage_and_exit;
fi

# parse arguments
while [[ $# -gt 0 ]]; do
	case $1 in
	-o|--only-rhyming)
		# set -o grep flag to 1
		oflag=1;
	;;
	*)
		if [[ -f $1 && "$input_file" == "-" ]]; then
			# arg is the input file, overwrite default file name
			input_file="$1";
		elif [[ -n "$1" && "$1" != -* && "$input_word" == "" ]]; then
			# arg is the input word (not a flag), set input word
			input_word="$1";
		else
			print_usage_and_exit;
		fi
	;;
	esac
	# proceed to the next arg
	shift;
done

# get rhyming phoneme string (of input word) from CMU dict:
# - get line with both word and pronunciation (only the first alternative pronuciation)
# - extract pronunciation string
# - extract rhyming phoneme string (from stressed phoneme to end-of-line)
# - remove possible comment
rhyming_phoneme=$(cat "$cmudict"\
	| grep -E -wi "^${input_word} .*"\
 	| cut -d' ' -f2-\
 	| grep -E -io "[a-z]+1.*\$"\
 	| sed -e "s/ #.*$//g");

# input word not found in CMU dict, just exit
if [ -z "$rhyming_phoneme" ]; then
	exit 0;
fi

# get rhyming word list from CMU dict:
# - remove possible comment
# - get line that end with rhyming phoneme string
# - extract rhyming word at the beginning of line
# - discard possible words containing dot characters (dots create problems in the final grep pattern)
# - discard input word from rhyming words
# - remove possible "(n)" suffix from rhyming word (i.e. the word is the n-th alternative pronunciation)
rhyming_word_list=($(cat "$cmudict"\
	| sed -e "s/ #.*$//g"\
	| grep -E "${rhyming_phoneme}\$"\
	| cut -d' ' -f1\
	| grep -v '[.]'\
	| grep -vi "$input_word"\
	| sed -e "s/([0-9])$//g"));

# no wors in CMU dict that rhyme with input word, just exit
if [ ${#rhyming_word_list[@]} -eq 0 ]; then
	exit 0;
fi

# iterate over (and print) rhyming words [only for debugging purposes]
#i=0;
#length=${#rhyming_word_list[*]};
#while [ $i -lt $length ]; do
#	echo "${rhyming_word_list[$i]}";
#	let i+=1;
#done

# compute grep pattern string from rhyming word list (join words by the "|" separator)
pattern=$(IFS=\|; echo "${rhyming_word_list[*]}");

# append -o grep flag (if it was requested)
if [[ $oflag -eq 1 ]]; then
	grep_flags="${grep_flags} -o";
fi

# append --color grep flag if script output is not redirected or piped
if [ -t 1 ]; then
	grep_flags="${grep_flags} --color";
fi

# run final grep command with computed regular expression pattern and flags
cat "$input_file" | grep $grep_flags $pattern;

# exit with code of the last command executed
exit $?;
