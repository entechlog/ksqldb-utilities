#!/bin/bash
#######################################################################################################
#  Script Name       : buildKsqlQuery.sh                                                              #
#  created by        : Siva Nadesan                                                                   #
#  created date      : 2020-04-20                                                                     #
#  Syntax            : ./buildKsqlQuery.sh <ENVIRONMENT> <FILE_NAME>                                  #
#                    : ENVIRONMENT - Target environment name                                          #
#                    : FILE_NAME - File Name with ksqlDB query which needs to be updated              #
#  Config file format: Yaml configuration file                                                        #
#  Example           : ./buildKsqlQuery.sh dev sample.txt                                             #
#######################################################################################################

#######################################################################################################
# Find the Script Name automatically                                                                  #
#######################################################################################################

ScriptNameWithExt=`basename "$0"`
extension="${ScriptNameWithExt##*.}"
SCRIPT_NAME="${ScriptNameWithExt%.*}"

echo "**************************************************************************"
echo "SCRIPT_NAME            : "$SCRIPT_NAME
echo "**************************************************************************"

#######################################################################################################
# Function to parse YAML                                                                              #
#######################################################################################################

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

#######################################################################################################
# Function to verify parameter                                                                        #
#######################################################################################################
function verify_param() {
  [[ -z “${!1}� ]] && echo $1 value not present in yaml, exiting.
}

#######################################################################################################
# Find the location of scripts and check for logs dir, create if don't exist                          #
#######################################################################################################

THISDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -d "$THISDIR/logs" ]; then
   echo "INFO                   : logs directory exists"
else
   mkdir -p "$THISDIR/logs" 2>/dev/null
   chmod 777 "$THISDIR/logs"
fi

if [ -d "$THISDIR/temp" ]; then
   echo "INFO                   : temp directory exists"
else
   mkdir -p "$THISDIR/temp" 2>/dev/null
   chmod 777 "$THISDIR/temp"
fi

#######################################################################################################
# Read Arguments                                                                                      #
#######################################################################################################

echo "INFO                   : Total arguments.." $#

if [ $# -ge 2 ]; then
  echo "INFO                   : Received the correct number of input parameters"
else
  echo " "
  echo "ERROR                  : Syntax:" $SCRIPT_NAME "<ENVIRONMENT>"
  exit;
fi

ENVIRONMENT=$1
ENVIRONMENT=$(echo $ENVIRONMENT | tr '[:upper:]' '[:lower:]')
echo "INFO-ENVIRONMENT       :" $ENVIRONMENT

FILE_NAME=$2
#FILE_NAME=$(echo $FILE_NAME | tr '[:upper:]' '[:lower:]')
echo "INFO-FILE_NAME        :" $FILE_NAME

#######################################################################################################
# Location of log files and any supporting files                                                      #
#######################################################################################################

LOGDIR=$(echo $THISDIR"/logs" | tr '[:upper:]' '[:lower:]')
echo "INFO-LOGDIR            :" $LOGDIR

TEMPDIR=$(echo $THISDIR"/temp" | tr '[:upper:]' '[:lower:]')
echo "INFO-TEMPDIR           :" $TEMPDIR

INPUTDIR=$(echo $THISDIR"/input" | tr '[:upper:]' '[:lower:]')
echo "INFO-INPUTDIR          :" $INPUTDIR

#######################################################################################################
# Protect files created by this script.                                                               #
#######################################################################################################

umask u=rw,g=rw,o=rw

#######################################################################################################
# Read Current System time stamp                                                                      #
#######################################################################################################

CURR_DATE=`date "+%Y-%m-%d%H:%M:%S"`
CURR_DATE=$(echo $CURR_DATE | sed 's/[^A-Za-z0-9_]/_/g')

#######################################################################################################
# Create a new folder in temp which will have the builds for current run                              #
#######################################################################################################

RANDOM_NAME=$CURR_DATE$RANDOM

if [ -d "$THISDIR/temp/$RANDOM_NAME" ]; then
   echo "INFO                   : work dir directory exists"
else
   mkdir -p "$THISDIR/temp/$RANDOM_NAME" 2>/dev/null
   chmod 777 "$THISDIR/temp/$RANDOM_NAME"
fi

#######################################################################################################
# Open up a new log and supporting files for todays run                                               #
#######################################################################################################

LOGFILE=$LOGDIR"/"$SCRIPT_NAME"_"$CURR_DATE".log"
touch $LOGFILE

TEMPFILE=$TEMPDIR"/"$SCRIPT_NAME_$RANDOM_NAME".dat"
touch $TEMPFILE

#######################################################################################################
# Delete previous tmp file                                                                            #
#######################################################################################################

rm $TEMPFILE > $TEMPFILE

#######################################################################################################
# Create and write the log header message                                                             #
#######################################################################################################

echo `date "+%Y-%m-%d%H:%M:%S"` "-" $SCRIPT_NAME "Started" > $LOGFILE

#######################################################################################################
# Insert Seperator                                                                                    #
#######################################################################################################

echo ' ' >>$LOGFILE

#######################################################################################################
# Source the config file                                                                              #
#######################################################################################################

eval $(parse_yaml $INPUTDIR/$SCRIPT_NAME.yaml)

#######################################################################################################
# Derive values from config file for the current env                                                  #
#######################################################################################################

verify_param $ENVIRONMENT'_object_before'
object_before=$(eval 'echo $'$ENVIRONMENT'_object_before')

verify_param $ENVIRONMENT'_object_after'
object_after=$(eval 'echo $'$ENVIRONMENT'_object_after')

verify_param $ENVIRONMENT'_topic_before'
topic_before=$(eval 'echo $'$ENVIRONMENT'_topic_before')

verify_param $ENVIRONMENT'_topic_after'
topic_after=$(eval 'echo $'$ENVIRONMENT'_topic_after')

#######################################################################################################
# All processing logic goes here                                                                      #
#######################################################################################################

while read query_file
do

if [[ -n $query_file ]]; then

   echo "**************************************************************************" >>$LOGFILE
   echo `date "+%Y-%m-%d%H:%M:%S"` "- Processing : " $query_file >>$LOGFILE
   echo "**************************************************************************" >>$LOGFILE
   echo "Replacing "$object_before" with "$object_after >> $LOGFILE
   echo "Replacing "$topic_before" with "$topic_after >> $LOGFILE
   echo "**************************************************************************" >>$LOGFILE

   # Dervive the output file name 
   OUTPUTFILE="$(basename -- $query_file)"
   OUTPUTFILE="${OUTPUTFILE%.*}"
   OUTPUTFILE=$OUTPUTFILE"_"$ENVIRONMENT"_"$CURR_DATE".sql"
   echo "INFO-OUTPUTFILE        :" $OUTPUTFILE

# Sed to make target env changes
# Replace double quotes with backtick

   sed -e 's/'$object_before'/'$object_after'/g' \
       -e 's/'$topic_before'/'$topic_after'/g' \
      -e "s/\"/\`/g" \
      $query_file > $TEMPDIR'/'$RANDOM_NAME'/'$OUTPUTFILE

   fi

done < $FILE_NAME

cd $TEMPDIR'/'$RANDOM_NAME

# Find all sql files which was created as part of this build and write to a file for deployment
#%Tk: File's last modification time in the format specified by k.
#@: seconds since Jan. 1, 1970, 00:00 GMT, with fractional part.
#c: locale's date and time (Sat Nov 04 12:02:33 EST 1989).
#%p: File's name.

find "$(pwd)" -maxdepth 1 -printf "%T@ %Tc %p\n" -name '*.sql' | grep $CURR_DATE'.sql' | sort -n | cut -d ' ' -f 9 > $TEMPFILE

#######################################################################################################
# write trailer log record                                                                            #
#######################################################################################################
echo `date "+%Y-%m-%d%H:%M:%S"` "-" $SCRIPT_NAME "finished" >> $LOGFILE

exit 0;