#! /usr/bin/bash

shopt -s extglob
shopt -s nullglob

declare -a configFiles
declare -a bupDirs
declare -a inputs
declare -a inputCommands
declare -a inputResults
declare -i keepVersions

#$1 = config file
function readConfig() {
   local state="default" # default | inputCommand
   
   while IFS=" = " read k v; do
      if [[ "$v" == "" ]]; then
         continue
      fi
      echo "Processing: [[[$k | $v]]]"
      
      if [[ $state == "inputCommand" ]]; then
         if [[ "$k" == "inputResult" ]]; then
            inputResults+=("${v/#\~/$HOME}")
            state="default"
         else
            echo 
         fi
      else
         case $k in
         "output")
            bupDirs+=("${v/#\~/$HOME}") # expand leading tilde
            ;;
         "input")
            inputs+=("${v/#\~/$HOME}")
            ;;
         "inputCommand")
            inputCommands+=("${v/#\~/$HOME}")
            state="inputCommand"
            ;;
         "keepVersions")
            (( keepVersions = (v > 1) ? v : 1 ))
            ;;
         *)
            echo "Unknown key '$k'."
            echo "Expected one of: output, input, inputCommand,"
            echo "inputResult (only after inputCommand!), keepVersions."
            exit 1
            ;;
         esac
      fi
   done < "$1"
   
   if (( "${#inputs[@]}" + "${#inputCommands[@]}" == 0)) then
      echo "Empty inputs! Nothing to backup!"
      exit 1
   fi
   if (("${#inputCommands[@]}" != "${#inputResults[@]}")) then
      echo "The number of commands should match number of outputs" # Should be unreachable
      exit 1
   fi
   if [[ $state == "inputCommand" ]]; then
      echo "Expected 'inputResult = ' after 'inputCommand'!"
      exit 1 
   fi
}

#$1 = short file name without the ".123.bak" suffix. $2 = output dir. 
#$3 = OUT min backup id, $4 = OUT max backup id
function getEarliestAndLatestVersions() {
   local -n minId=$3
   local -n maxId=$4
   echo ""
   echo "Getting ids from $2/$1.*.bak"
   
   #declare -a existingBackups
   #readarray -t existingBackups < <(ls -A "$2/$1.*.bak" 2>/dev/null)
   existingBackups=( $2/$1.*.bak )
   
   echo "got ${#existingBackups[@]} existing backups"
   ((maxId = -1))
   
   for fn in "${existingBackups[@]}"; do
      if [[ "$fn" =~ $2/$1.([0-9]+).bak ]]; then
         local bId=$(( "${BASH_REMATCH[1]}" ))
         echo "encountered backup $bid"
         if (( bId < minId )) then
            ((minId = bId))
         elif (( bId > maxId )) then  
            ((maxId = bId))
         fi
      fi
   done
}

#$1 = existing backup. $2 = new backup. $3 = OUT 1 iff they differ
function checkIfFilesDiffer() {
   declare -n out=$3
   local szOld=$(stat -c %s $1)
   local szNew=$(stat -c %s $2)
   
   if (( szOld != szNew )) then
      ((out = 1))
      return 0
   elif ! cmp -s $1 $2; then
      ((out = 1))
      return 0
   fi
   ((out = 0))
}

#$1 user command. $2 inpResult $3 inpShort $4 out
function makeABackup() {
   declare -i minBId
   declare -i maxBId
   
   $1 #Run user command to (hopefully) create the inpRes file 
   
   if ! [[ -f "$2" ]]; then
      echo "Expected a file to back up but can't find it!"
      echo "|| $2 ||"
      exit 1
   fi
   
   getEarliestAndLatestVersions $3 $4 minBId maxBId
   local newId=$(( maxBId + 1 ))
   echo "minId $minId max $maxId newId $newId"
   
   declare -i filesDiffer
   checkIfFilesDiffer $2 "$4/$3.$maxId.bak" filesDiffer
   if (( filesDiffer == 0)) then
      return 0
   fi
   
   local newName="$4/$inpShort.$newId.bak"
   local newChecksumName="$output/$inpShort.$newId.sha256"
   cp $inpRes $newName
   
   origChecksumAndFname="$(sha256sum $2)"
   newChecksumAndFname="$(sha256sum $newName)"
   origChecksum="${origChecksumAndFname:0:64}"
   newChecksum="${newChecksumAndFname:0:64}"
   if [[ "$newChecksum" != "$origChecksum" ]]; then
      echo "Error when copying file "
      echo "$2"
      echo "to $4"
      echo "Orig checksum $origChecksum, new checksum $newChacksum"
   fi
   echo "$newChecksumAndFname" > "$newChecksumName"
}

function makeBackups() {
   keepVersions=$((3))
   
   readarray -t configFiles < <(ls -A $HOME/.config/closha 2>/dev/null)
   
   for cFile in "${configFiles[@]}"; do
      readConfig "$HOME/.config/closha/$cFile"
   done
   
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
   
   
   for ((i=0; i< "${#inputCommands[@]}"; i++)) do
      local comm="${inputCommands[i]}"
      local inpRes="${inputResults[i]}"
      local inpShort="${inpRes##*/}"
      
      for output in "${bupDirs[@]}"; do
         makeABackup $comm $inpRes $inpShort $output
      done
   done
}

# $1 = backup file name
function restoreFromBackup() {
# get checksum from  file
# calculate checksum from $1
# if not same, display error
   echo "restoring"
}

function main() {
   if [[ "$1" == "" ]]; then
      makeBackups
   else
      restoreFromBackup $1
   fi
}

main
