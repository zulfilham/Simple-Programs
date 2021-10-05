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
   read_encryption_key "Enter decryption key: ";
   echo "*** Decrypting file names ***" 1>&2;
   local cpt_suffixed_filenames=() path base64_encrypted_basename decrypted_basename exit_code digest dirname basename;

   while read -d $'\0'; do
      cpt_suffixed_filenames+=("$REPLY");
   done < <(find "$@" -mindepth 1 -depth \( -name \*.cpt -and \! -name .cpt -or -type d \) -print0);

   for path in "${@-.}"; do
      while read -d $'\0'; do
         for base64_encrypted_basename in $(cat "$REPLY"); do
            decrypted_basename="$(base64 --decode <<< $base64_encrypted_basename | ccat --envvar=ENCRYPTION_KEY)";
            exit_code=$?;

            if ((exit_code == 0)); then
               digest=($(xxh128sum <<< $base64_encrypted_basename));

               for i in "${!cpt_suffixed_filenames[@]}"; do
                  dirname="${cpt_suffixed_filenames[i]%/*}"; [ "${cpt_suffixed_filenames[i]}" == "$dirname" ] && dirname=.;
                  basename="${cpt_suffixed_filenames[i]##*/}";

                  if [ "${basename%.cpt}" == ${digest[0]} ]; then
                     mv --verbose -- "$dirname/"${digest[0]}* "$dirname/${decrypted_basename%$'\n'}" 1>&2;
                     sed --in-place "/${base64_encrypted_basename//\//\\\/}/d" -- "$dirname/.cpt";
                     unset cpt_suffixed_filenames[i];
                     break;
                  fi;
               done;
            else
               return $exit_code;
            fi;
         done;
         if [ ! -s "$REPLY" ]; then rm --force -- "$REPLY"; fi;
      done < <(find "$path" -mindepth 1 -name .cpt -print0 | sort --zero --reverse);
   done;
   echo $'\n*** Decrypting file contents ***' 1>&2;
   echo -n "$ENCRYPTION_KEY" | ccdecrypt --verbose --force --recursive --keyfile=- -- "${@-.}";
}

main "${@/#-/.\/-}";
