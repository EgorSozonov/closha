#! /usr/bin/bash

declare -a configFiles
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
   
   if (("${#inputCommands[@]}" != "${#inputResults[@]}")) then
      echo "The number of commands should match number of outputs" # Should be unreachable
      exit 1
   fi
   if ! [[ $state == "inputResult" ]]; then
      echo "Expected 'inputResult = ' after 'inputCommand'!"
      exit 1 
   fi
}

#$1 = short file name without the ".123.bak" suffix. $2 = output dir. 
#$3 = OUT min backup id, $4 = OUT max backup id
function getEarliestAndLatestVersions() {
   local -n minId=$3
   local -n maxId=$4
   declare -a existingBackups
   
   readarray -t existingBackups < <(ls -A "$2/$1.*.bak" 2>/dev/null)
   ((maxId = -1))
   
   for fn in "${existingBackups[@]}"; do
      if [[ $fn =~ "$1.([0-9]+).bak"  ]]; then
         local bId = (( "${BASH_REMATCH[1]}" ))
         if (( bId < minId )) then
            ((minId = bId))
         elif (( bId > maxId )) then  
            ((maxId = bId))
         fi
      fi
   done
}

#$1
function makeABackup() {
   declare -i minId
   declare -i maxId
   getEarliestAndLatestVersions $inpRes $output minId maxId
   local newId=$(( maxId + 1 ))
   echo "minId $minId max $maxId newId $newId"
   if (( maxId != -1 )) then
      #check if the file changed since last backup
   fi
   local newName="$output/$inpShort.$newId.bak"
   local newChecksumName="$output/$inpShort.$newId.sha256"
   cp $inpRes $newName
   
   origChecksum=$(sha256sum $inpRes)
   newChecksum=$(sha256sum $newName)
   if [[ "$newChecksum" != "$origChecksum" ]]; then
   
   fi
   sha256sum $newName > $newChecksumName
}

function makeBackups() {
   keepVersions=((3))
   
   readarray -t configFiles < <(ls -A ~/.config/saveera 2>/dev/null)
   
   for cFile in "${configFiles[@]}"; do
      readConfig "~/.config/saveera/$cFile"
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
   
   
   for ((i=0; i<= "${inputCommands[@]}"; i++)) do
      local comm="${inputCommands[$i]}"
      local inpRes="${inputResults[$i]}"
      local inpShort="${inpRes##*/}"
      $(comm) #Run command to (hopefully) create the inpRes file 
      
      if [[ ! -f $inpRes ]]; then
         echo "Expected a file to back up but can't find it!"
         echo "$inpRes"
         exit 1
      fi
      
      for output in "${bupDirs[@]}"; do
         echo "$output"
      done
   done
}

# $1 = backup file name
function restoreFromBackup() {
# get checksum from  file
# calculate checksum from $1
# if not same, display error

}

function main() {
   if [[ "$1" == "" ]]; then
      makeBackups
   else
      restoreFromBackup $1
   fi

   
}

main
