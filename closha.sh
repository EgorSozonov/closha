#! /usr/bin/bash

shopt -s extglob
shopt -s nullglob

### ### ### ### script state ### ### ### ### ### ###
declare -a configFiles
#The "output"s from a config file
declare -a bupDirs

#The "input"s from a config file
declare -a inputs
#The pairs of "inputCommand/inputResult" from a config file
declare -a inputCommands
declare -a inputResults
#How many versions of a backup to keep
declare -i keepVersions
### ### ### ### ### #### ### ### ### ### ### ### ###

#Read a single config file and fill the arrays of inputs&outputs
#$1 = config file
function readConfig() {
   echo "Processing config file: $1"
   local state="default" # default | inputCommand
   bupDirs=()
   inputs=()
   inputCommands=()
   inputResults=()
   
   while IFS=" = " read k v; do
      if [[ "$v" == "" ]]; then
         continue
      fi
      
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
            (( keepVersions = (v > 0) ? v : 1 ))
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
      echo "The number of commands should match number of outputs" #Should be unreachable
      exit 1
   fi
   if [[ $state == "inputCommand" ]]; then
      echo "Expected 'inputResult = ' after 'inputCommand'!"
      exit 1 
   fi
}

#Get all the existing backup ids of a file, and calculate the maximum among them
#$1 = short file name without the ".123.bak" suffix. $2 = output dir. 
#$3 = OUT array of existing ids, $4 = OUT max backup id
function getAllAndLatestVersions() {
   local -n existing=$3
   local -n maxId=$4
   
   local existingBackups=( $2/$1.*.bak )
   
   ((maxId = -1))
   
   for fn in "${existingBackups[@]}"; do
      if [[ "$fn" =~ $2/$1.([0-9]+).bak ]]; then
         local bId=$(( "${BASH_REMATCH[1]}" ))
         existing+=($bId)
         
         if (( bId > maxId )) then  
            ((maxId = bId))
         fi
      fi
   done
}

#Check if the new backup is different from the latest existing backup.
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

#Check how many versions of a backup exist and if it's more than keepVersions, delete extra ones
#$1 = existingVersions. $2 inpShort. $3 output
function deleteExtraVersions() {
   local -n existVers=$1
   if (( "${#existVers[@]}" <= $keepVersions )) then
      return 0
   fi
   declare -a sortedVersions  
   readarray -t sortedVersions < <(printf '%s\n' "${existVers[@]}" | sort -n)
   
   local j
   for (( j="${#existVers[@]}" - $keepVersions - 1; j>=0; j-- )); do
      /usr/bin/rm $3/$2.${sortedVersions[j]}.bak
      /usr/bin/rm $3/$2.${sortedVersions[j]}.sha256
   done
}

#Create a new backup
#$1 inpResult. $2 inpShort. $3 output
function makeABackup() {
   if ! [[ -f "$1" ]]; then
      echo "Expected a file to back up but can't find it!"
      echo "||$1||"
      return 1
   fi
   
   declare -i maxBId
   declare -a existingVersions
   getAllAndLatestVersions $2 $3 existingVersions maxBId
   local newId=$(( maxBId + 1 ))
   
   if (( maxBId >= 0)) then
      declare -i filesDiffer
      checkIfFilesDiffer $1 "$3/$2.$maxBId.bak" filesDiffer
      if (( filesDiffer == 0)) then
         deleteExtraVersions existingVersions $2 $3
         return 0
      fi
   fi
   
   #Actually copy the file to output dir and create&validate its checksum
   local newName="$3/$inpShort.$newId.bak"
   local newChecksumName="$output/$inpShort.$newId.sha256"
   /usr/bin/cp $1 $newName
   existingVersions+=( $newId )
   
   origChecksumAndFname="$(sha256sum $1)"
   newChecksumAndFname="$(sha256sum $newName)"
   origChecksum="${origChecksumAndFname:0:64}"
   newChecksum="${newChecksumAndFname:0:64}"
   if [[ "$newChecksum" != "$origChecksum" ]]; then
      echo "Checksum error when copying file "
      echo "||$1||"
      echo "to ||$3||"
      return 1
   fi
   echo "$newChecksum" > "$newChecksumName"
   
   deleteExtraVersions existingVersions $2 $3
}

#Make all the backups configured in all the files in ~/.config/closha
function makeBackups() {
   keepVersions=$((3))
   
   readarray -t configFiles < <(ls -A $HOME/.config/closha 2>/dev/null)
   
   for cFile in "${configFiles[@]}"; do
      readConfig "$HOME/.config/closha/$cFile"
      
      #Ordinary inputs
      declare -i i
      for ((i=0; i<"${#inputs[@]}"; i++)); do
         local input="${inputs[i]}"
         local inpShort="${input##*/}"
         for output in "${bupDirs[@]}"; do
            makeABackup $input $inpShort $output
         done
      done
      
      #Inputs generated from commands
      for ((i=0; i< "${#inputCommands[@]}"; i++)) do
         local comm="${inputCommands[i]}"
         local inpRes="${inputResults[i]}"
         local inpShort="${inpRes##*/}"
         
         $1 #Run user command to (hopefully) create the inpRes file 
         
         for output in "${bupDirs[@]}"; do
            makeABackup $inpRes $inpShort $output
         done
         
         if [[ -f "$inpRes" ]]; then
            /usr/bin/rm "$inpRes"
         fi
      done
   done
}

#If the restored backup is an archive, unpacks it to a subdir and deletes the archive
#$1 = backup file name
function maybeUnpack() {
   local bup="$1"
   local extractTo=""
   
   if [[ "$bup" =~ .*\.tar\.gz || "$bup" =~ .*\.tar\.xz ]]; then
      extractTo="${1:0:${#bup} - 7}"
   elif [[ "$bup" =~ .*\.tar\.zst ]]; then
      extractTo="${1:0:${#bup} - 8}"
   elif [[ "$bup" =~ .*\.gz || "$bup" =~ .*\.xz ]]; then
      extractTo="${1:0:${#bup} - 3}"
   elif [[ "$bup" =~ .*\.zst ]]; then
      extractTo="${1:0:${#bup} - 4}"
   fi
   
   if [[ "extractTo" != "" ]]; then
      mkdir "$extractTo"
      /usr/bin/tar -x -f "$bup" -C "$extractTo"
   fi
}

#Restore a single backup into the same dir. Unpack it into a subdir if it's a tarball
#$1 = backup file name. $2 = restoration path
function restoreFromBackup() {
   local bup=$(realpath "$1")
   if ! [[ -f $bup ]]; then
      echo "File doesn't exist or is a directory!"
      exit 1
   elif [[ "$bup" =~ .*\.([0-9]+).bak ]]; then
      local bId=$(( "${BASH_REMATCH[1]}" ))
      local checksumFname="${bup%.bak}.sha256"
      
      if ! [[ -f "$checksumFname" ]]; then
         echo "Checksum file doesn't exist, cannot validate the backup!"
         exit 1
      fi
      
      local restoredChecksumAndFname="$(sha256sum $1)"
      local restoredChecksum="${restoredChecksumAndFname:0:64}"
      local readChecksum=$(<$checksumFname)
      if [[ "$restoredChecksum" != "$readChecksum" ]]; then
         echo "Bitrot detected in backup! Current checksum is"
         echo "$restoredChecksum"
         echo "but the one written upon creation is"
         echo "$readChecksum"
         exit 1
      fi
      
      local restoredFname="${bup%.$bId.bak}"
      /usr/bin/cp "$bup" "$restoredFname"
      
      maybeUnpack "$restoredFname"
   else
      echo "The file name doesn't check out. It should end with a number like '.123.bak'"
      exit 1
   fi
}

#Main (entrypoint)
if [[ "$1" == "" ]]; then
   makeBackups
else
   restorePath="~/.local/share/closha/"
   mkdir -p "$restorePath"
   restoreFromBackup $1 $restorePath
fi
