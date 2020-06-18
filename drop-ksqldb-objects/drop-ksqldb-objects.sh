#!/bin/bash
#######################################################################################################
#  Script Name       : drop-ksqldb-objects.sh                                                           #
#  created by        : Siva Nadesan                                                                   #
#  created date      : 2020-04-15                                                                     #
#  Syntax            : ./drop-ksqldb-objects.sh <MODE> <KSQL_URL> <FILE_NAME>                           #
#                    : MODE - sed and jq are the valid values                                         #
#                    : KSQL_URL - KSQL host and port number in host:port format                       #
#                    : FILE_NAME - Full path of file with list of table\stream to be deleted          #
#  Input file format : <TABLE_STREAM_NAME>,<DELETE_TOPIC_FLAG>                                        #
#                    : TABLE_STREAM_NAME - Table OR Stream which you want to delete                   #
#                    : DELETE_TOPIC_FLAG - Flag(Yes/No) to delete topic                               #
#                    : TERMINATE_ONLY_FLAG - Flag(Yes/No) to terminate only and not drop objects      #
#  Example           : ./drop-ksqldb-objects.sh sed localhost:8088 /input/DEMO_DROP_KSQL_OBJECT.txt     #
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

if [ -d "$THISDIR/reports" ]; then
   echo "INFO                   : reports directory exists"
else
   mkdir -p "$THISDIR/reports" 2>/dev/null
   chmod 777 "$THISDIR/reports"
fi

#######################################################################################################
# Read Arguments                                                                                      #
#######################################################################################################

echo "INFO                   : Total arguments.." $#

if [ $# -ge 3 ]; then
  echo "INFO                   : Received the correct number of input parameters"
else
  echo " "
  echo "ERROR                  : Syntax:" $SCRIPT_NAME "<MODE> <KSQL_URL> <FILE_NAME>"
  exit;
fi

MODE=$1
MODE=$(echo $MODE | tr '[:upper:]' '[:lower:]')
echo "INFO-MODE              :" $MODE

KSQL_URL=$2
KSQL_URL=$(echo $KSQL_URL | tr '[:upper:]' '[:lower:]')
echo "INFO-KSQL_URL          :" $KSQL_URL

FILE_NAME=$3
#FILE_NAME=$(echo $FILE_NAME | tr '[:upper:]' '[:lower:]')
echo "INFO-FILE_NAME         :" $FILE_NAME

#######################################################################################################
# Location of log files and any supporting files                                                      #
#######################################################################################################

LOGDIR=$(echo $THISDIR"/logs" | tr '[:upper:]' '[:lower:]')
echo "INFO-LOGDIR            :" $LOGDIR

TEMPDIR=$(echo $THISDIR"/temp" | tr '[:upper:]' '[:lower:]')
echo "INFO-TEMPDIR           :" $TEMPDIR

REPORTSDIR=$(echo $THISDIR"/reports" | tr '[:upper:]' '[:lower:]')
echo "INFO-REPORTSDIR        :" $REPORTSDIR

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
# Open up a new log and supporting files for todays run                                               #
#######################################################################################################

LOGFILE=$LOGDIR"/"$SCRIPT_NAME"_"$CURR_DATE".log"
touch $LOGFILE

TEMPFILE=$TEMPDIR"/"$SCRIPT_NAME".dat"
touch $TEMPFILE

REPORTSFILE=$REPORTSDIR"/"$SCRIPT_NAME"_"$CURR_DATE".html"
touch $REPORTSFILE

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
# Copy static HTML Header to the report file                                                          #
#######################################################################################################

cat $INPUTDIR/html/part_10.html > $REPORTSFILE

#######################################################################################################
# All processing logic goes here                                                                      #
#######################################################################################################


#Read the input file with list of table/streams and loop until end of file to apply the properties
while read stream_table_names
do

if [[ -n $stream_table_names ]]; then
  stream_table_name=$(echo $stream_table_names | cut -d',' -f1 | tr -d '\n\r')
  delete_flag=$(echo $stream_table_names | cut -d',' -f2 | tr '[:upper:]' '[:lower:]' | tr -d '\n\r')
  terminate_only_flag=$(echo $stream_table_names | cut -d',' -f3 | tr '[:upper:]' '[:lower:]' | tr -d '\n\r')

  echo "**************************************************************************" >>$LOGFILE
  echo `date "+%Y-%m-%d%H:%M:%S"` "- Processing : " $stream_table_name >>$LOGFILE
  echo "**************************************************************************" >>$LOGFILE
  echo "" >>$LOGFILE
  
  echo "INFO-STREAM_TABLE_NAME  :" $stream_table_name >>$LOGFILE
  echo "INFO-DELETE_FLAG        :" $delete_flag     >>$LOGFILE
  echo "INFO-TERMINATE_ONLY_FLAG  :" $terminate_only_flag >>$LOGFILE

  #Determines if to delete the topic OR not
  if [[ $delete_flag = 'y' ]] || [[ $delete_flag = 'yes' ]] ; then
    delete_command=$(echo 'DELETE TOPIC')
  else
    delete_command=$(echo '')
  fi
     
  #Command to find the query id and to terminate them
  find_and_term_command=$(echo "curl -s -X "\""POST"\"" $KSQL_URL/ksql \
    -H "\""Content-Type: application/vnd.ksql.v1+json; charset=utf-8"\"" \
    -d '{"\""ksql"\"": "\""DESCRIBE $stream_table_name;"\""}' \ |
    grep -zoP '"\""id"\"":\s*\K[^\s,]*(?=\s*,)' |\
    sed 's/"\""//g' |\
    sed 's/\x0//g' |\
    xargs -Iq1 curl -s -X "\""POST"\"" $KSQL_URL/ksql \
    -H "\""Content-Type: application/vnd.ksql.v1+json; charset=utf-8"\"" \
    -d '{"\""ksql"\"": "\""TERMINATE 'q1';"\""}'")
 
    echo "Issuing Command (TERM) : " $find_and_term_command >> $LOGFILE
    find_and_term_command_output=$(eval $find_and_term_command)
    echo $find_and_term_command_output >> $LOGFILE

    echo "<td>$stream_table_name</td>" >> $REPORTSFILE
    echo "<td>Query</td>" >> $REPORTSFILE
    query_name=$(echo $find_and_term_command_output | grep -m1 -oP '"statementText"\s*:\s*"\K[^"]+' | cut -d' ' -f2 | sed 's/[^A-Za-z0-9_]//g')
    echo "<td>$query_name</td>" >> $REPORTSFILE

    # Enhance the error handling to capture the message from curl
    if [[ "$find_and_term_command_output" == *SUCCESS* ]]; then
      echo "INFO                   : QUERIES FOR $stream_table_name TERMINATED SUCCESSFULLY" >>$LOGFILE
      echo "<td>Success</td>" >> $REPORTSFILE
    elif [[ "$find_and_term_command_output" == *error_code* ]]; then
      echo "ERROR                  : QUERIES FOR $stream_table_name TERMINATION FAILED"      >>$LOGFILE
      echo "<td>Failed</td>" >> $REPORTSFILE
    else
      echo "INFO                   : NO QUERIES FOUND FOR $stream_table_name" >>$LOGFILE
      echo "<td>Not Found</td>" >> $REPORTSFILE
    fi

    echo "</tr>" >> $REPORTSFILE
    
    echo '==========================================================================' >>$LOGFILE

    echo "<td>$stream_table_name</td>" >> $REPORTSFILE

  # Do not drop if terminate_only_flag flag is set
    if [[ $terminate_only_flag = 'y' ]] || [[ $terminate_only_flag = 'yes' ]] ; then
      echo "INFO                  : $stream_table_name SKIPPED" >>$LOGFILE
      echo "<td>Skipped</td>" >> $REPORTSFILE
    else
    #Command to drop the table\stream
    drop_command=$(echo "curl -s -X "\""POST"\"" $KSQL_URL/ksql \
      -H "\""Content-Type: application/vnd.ksql.v1+json; charset=utf-8"\"" \
      -d '{"\""ksql"\"": "\""DESCRIBE $stream_table_name;"\""}' \ |
      grep -zoP '],"\""type"\"":\s*\K[^\s,]*(?=\s*,)' |\
      sed 's/"\""//g' |\
      sed 's/\x0//g' |\
      xargs -Iq2 curl -s -X "\""POST"\"" $KSQL_URL/ksql \
      -H "\""Content-Type: application/vnd.ksql.v1+json; charset=utf-8"\"" \
      -d '{"\""ksql"\"": "\""DROP 'q2' IF EXISTS $stream_table_name $delete_command;"\""}'")
  
    echo "Issuing Command (DROP) : " $drop_command >> $LOGFILE
    drop_command_output=$(eval $drop_command)
    echo $drop_command_output >> $LOGFILE
  
    echo "<td>Table</td>" >> $REPORTSFILE
    echo "<td>$stream_table_name</td>" >> $REPORTSFILE
  
    # Enhance the error handling to capture the message from curl
    if [[ "$drop_command_output" == *SUCCESS* ]]; then
      echo "INFO                   : $stream_table_name DROPPED SUCCESSFULLY" >>$LOGFILE
      echo "<td>Success</td>" >> $REPORTSFILE
    elif [[ "$drop_command_output" == *error_code* ]]; then
      echo "ERROR                  : $stream_table_name DROP FAILED" >>$LOGFILE
      echo "<td>Failed</td>" >> $REPORTSFILE
    else
      echo "INFO                   : $stream_table_name NOT FOUND" >>$LOGFILE
      echo "<td>Not Found</td>" >> $REPORTSFILE
    fi
    fi  

    echo "</tr>" >> $REPORTSFILE

    echo '==========================================================================' >>$LOGFILE
    echo "" >>$LOGFILE

  fi
done < $FILE_NAME

#######################################################################################################
# Copy static HTML Footer to the report file                                                          #
#######################################################################################################
cat $INPUTDIR/html/part_20.html >> $REPORTSFILE

#######################################################################################################
# write trailer log record                                                                            #
#######################################################################################################
echo `date "+%Y-%m-%d%H:%M:%S"` "-" $SCRIPT_NAME "finished" >> $LOGFILE

exit 0;