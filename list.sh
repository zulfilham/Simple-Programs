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
   local base64_encrypted_basename decrypted_basename digest exit_code;

   while read -d $'\0'; do
      for base64_encrypted_basename in $(cat "$REPLY"); do
         decrypted_basename="$(base64 --decode <<< $base64_encrypted_basename | ccat --envvar=ENCRYPTION_KEY)";
         exit_code=$?;

         if ((exit_code == 0)); then
            digest=($(xxh128sum <<< $base64_encrypted_basename));
            echo -e "${REPLY%/.cpt}/$decrypted_basename (\x1b[33m${digest[0]}\x1b[0m)";
         else
            return $exit_code;
         fi;
      done;
   done < <(find "$@" -mindepth 1 -name .cpt -print0);
}

main "$@";
