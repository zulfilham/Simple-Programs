#!/usr/bin/bash

function read_encryption_key() {
   local REPLY;
   read -esp "$1";

   if (($? == 0)); then
      export ENCRYPTION_KEY="$REPLY";
      echo -n $'\x0d\x1b[0K' 1>&2;
   else
      exit 1;
   fi;
}

function main() {
   local keyref="YOUR KEY REFERENCE FILE";
   read_encryption_key "Enter encryption key: ";
   echo "*** Encrypting file contents ***" 1>&2;
   echo -n "$ENCRYPTION_KEY" | ccencrypt --verbose --force --strictsuffix --recursive --keyref="$keyref" --keyfile=- -- "${@-.}";
   local exit_code=$?;

   if ((exit_code == 0)); then
      local cpt_suffixed_filenames=() basename_digests=() base64_encrypted_basename digest cpt_suffixed_filename dirname basename;

      while read -d $'\0'; do
         cpt_suffixed_filenames+=("$REPLY");
      done < <(find "$@" -mindepth 1 -depth \( -name \*.cpt -and \! -name .cpt -or -type d \) -print0);

      while read; do
         for base64_encrypted_basename in $REPLY; do
            digest=($(xxh128sum <<< $base64_encrypted_basename));
            basename_digests+=(${digest[0]});
         done;
      done < <(find "$@" -mindepth 1 -name .cpt -exec cat {} +);

      echo $'\n*** Encrypting file names ***' 1>&2;

      for cpt_suffixed_filename in "${cpt_suffixed_filenames[@]}"; do
         dirname="${cpt_suffixed_filename%/*}"; [ "$cpt_suffixed_filename" == "$dirname" ] && dirname=.;
         basename="${cpt_suffixed_filename##*/}";

         if ! [[ "${basename_digests[@]}" == *${basename%.cpt}* ]]; then
            base64_encrypted_basename=$(ccencrypt --force --envvar=ENCRYPTION_KEY <<< "$basename" | base64 --wrap=0);
            echo $base64_encrypted_basename >> "$dirname/.cpt";
            digest=($(xxh128sum <<< $base64_encrypted_basename));
            mv --verbose -- "$cpt_suffixed_filename" "$dirname"/${digest[0]}$([ ! -d "$cpt_suffixed_filename" ] && echo -n .cpt) 1>&2;
         fi;
      done;
   else
      return $exit_code;
   fi;
}

main "${@/#-/.\/-}";
