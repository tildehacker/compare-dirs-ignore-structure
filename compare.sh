#!/usr/bin/env bash

export _root="$( dirname "$( readlink -f "${0}" )" )"
export _tmp_dir="$( mktemp --directory )"

_print_usage() {
	echo "Usage:"
	echo -e "\t${0} <folder1> <folder2>"
}

_scan_folder() {
	if [ "${#}" -ne 1 ]
	then
		return 1
	else
		_folder="${1}"
	fi

	_folder_tmp="$( mktemp \
		--tmpdir="${_tmp_dir}" \
		-t "$( basename "${_folder}" ).XXX" )"

	_folder_count="$( find "${_folder}" \
				-type f \
				| wc -l )"
	find "${_folder}" \
		-type f \
		-exec md5sum "{}" \; \
		| tee --append "${_folder_tmp}" \
		| pv -n -l -s "${_folder_count}" 2>&1 \
		| dialog --keep-tite \
			--gauge "Scanning ${_folder}..." 7 70
}

if [ "${#}" -ne 2 ]
then
	_print_usage
	exit 1
else
	_folder1="${1}"
	_folder2="${2}"
fi

export _folder_tmp

_scan_folder "${_folder1}"
_folder1_tmp="${_folder_tmp}"

_scan_folder "${_folder2}"
_folder2_tmp="${_folder_tmp}"

_folder1_hashes="$( mktemp \
		--tmpdir="${_tmp_dir}" \
		-t "$( basename "${_folder1}" ).hash.XXX" )"
cat ${_folder1_tmp} \
	| tr -s " " \
	| cut -d " " -f 1 > "${_folder1_hashes}"

_folder2_hashes="$( mktemp \
		--tmpdir="${_tmp_dir}" \
		-t "$( basename "${_folder2}" ).hash.XXX" )"
cat ${_folder2_tmp} \
	| tr -s " " \
	| cut -d " " -f 1 > "${_folder2_hashes}"

_diff_hashes="$( mktemp \
		--tmpdir="${_tmp_dir}" \
		-t "diff-hashes.XXX" )"
diff <( sort "${_folder1_hashes}" ) \
	<( sort "${_folder2_hashes}" ) \
	> "${_diff_hashes}"

_folder1_found="$( mktemp \
		--tmpdir="${_tmp_dir}" \
		-t "$( basename "${_folder1}" ).found.XXX" )"
while read -r _line
do
	cat "${_folder1_tmp}" \
		| grep "$( echo "${_line}" \
				| tr -s ' ' \
				| cut -d ' ' -f 2 )" \
		| tr -s ' ' \
		| cut -d ' ' -f 2- \
		>> "${_folder1_found}"
done < <( cat "${_diff_hashes}" | grep '<' )

_folder2_found="$( mktemp \
		--tmpdir="${_tmp_dir}" \
		-t "$( basename "${_folder2}" ).found.XXX" )"
while read -r _line
do
	cat "${_folder2_tmp}" \
		| grep "$( echo "${_line}" \
				| tr -s ' ' \
				| cut -d ' ' -f 2 )" \
		| tr -s ' ' \
		| cut -d ' ' -f 2- \
		>> "${_folder2_found}"
done < <( cat "${_diff_hashes}" | grep '>' )

_output="${_root}/output.tmp"
rm -f "${_output}"

echo "Found only in ${_folder1}:"
while read -r _line
do
	echo -e "\t${_line}"
	echo "< ${_line}" >> "${_output}"
done < "${_folder1_found}"
echo

echo "Found only in ${_folder2}:"
while read -r _line
do
	echo -e "\t${_line}"
	echo "> ${_line}" >> "${_output}"
done < "${_folder2_found}"
