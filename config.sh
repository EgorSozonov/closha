#! /usr/bin/bash

declare -a bupDirs
declare -a inputCommands
declare -a inputResults
declare -i keepVersions

function readConfig() {
   local state="bupDir" # bupDir | inputCommand | inputResult
   
   while IFS=" = " read k v; do
      if ! [[ "$v" == "" ]]; then
         echo "Processing: [[[$k | $v]]]"
         case $k in
         "output") case $state in
            "bupDir")
               bupDirs+=("$v")
               ;;
            *)
               echo "Key 'output' unexpected. Outputs must come before inputs"
               exit 1
               ;;
            esac;;
         "inputCommand") case $state in
            "inputResult") ;& #fallthrough
            "bupDir") 
               inputCommands+=("$v")
               state="inputCommand"
               ;; 
            *) 
               echo "Key 'inputCommand', but expected 'inputResult = '"
               exit 1
               ;; 
            esac;;
         "inputResult") case $state in
            "inputCommand")
               inputResults+=("$v")
               state="inputResult"
               ;;
            *)
               echo "Key 'inputResult', but expected 'inputCommand = '"
               exit 1
               ;;
            esac;;
         "keepVersions")
            (( keepVersions = (v > 1) ? v : 1 ))
            ;;
         *)
            echo "Unknown key '$k'."
            echo " Expected one of: output, keepVersions, inputCommand, inputResult"
            exit 1
            ;;
         esac;;
   done < "$1"
   
   if (( "${#bupDirs[@]}" == 0)) then
      echo "Empty array!"
      exit 1
   fi
   if (( "${#inputCommands[@]}" == 0)) then
      echo "Empty input commands!"
      exit 1
   fi
   if (("${#inputResults[@]}" == 0)) then
      echo "Empty input results!"
      exit 1
   fi
   if ! [[ $state == "inputResult" ]]; then
      echo "Expected 'inputResult = ' after 'inputCommand'!"
      exit 1 
   fi
}

# insert backup into outputs
# clean 

readConfig "$1"

echo "bupDirs:"
for x in "${bupDirs[@]}"; do
   echo "$x"
done

echo "inputCommands:"
for x in "${inputCommands[@]}"; do
   echo "$x"
done

echo "inputResults:"
for x in "${inputResults[@]}"; do
   echo "$x"
done

function main() {
   keepVersions=((3))
   
}
