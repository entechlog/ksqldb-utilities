#!/bin/bash
#######################################################################################################
#  Script Name       : deploy-ksql-query.sh                                                             #
#  created by        : Siva Nadesan                                                                   #
#  created date      : 2020-04-20                                                                     #
#  Syntax            : ./deploy-ksql-query.sh <ENVIRONMENT> <FILE_NAME>                                 #
#                    : ENVIRONMENT - Target environment name                                          #
#                    : FILE_NAME - File Name with list of ksqlDB query which needs to be deployed     #
#                    : DEPLOYMENT_INTERVAL - Interval in seconds between each deployment              #
#                    : MODE - deploy OR dryrun                                                        #
#  Config file format: Yaml configuration file                                                        #
#  Example           : ./deploy-ksql-query.sh dev sample.txt                                            #
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
  [[ -z â€œ${!1}â€ ]] && echo $1 value not present in yaml, exiting.
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

if [ $# -ge 4 ]; then
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
echo "INFO-FILE_NAME         :" $FILE_NAME

DEPLOYMENT_INTERVAL=$3
#FILE_NAME=$(echo $FILE_NAME | tr '[:upper:]' '[:lower:]')
echo "INFO-DEPLOYMENT_INTERVAL    :" $DEPLOYMENT_INTERVAL

MODE=$4
MODE=$(echo $MODE | tr '[:upper:]' '[:lower:]')
echo "INFO-MODE              :" $MODE

#######################################################################################################
# Location of log files and any supporting files                                                      #
#######################################################################################################

LOGDIR=$(echo $THISDIR"/logs" | tr '[:upper:]' '[:lower:]')
echo "INFO-LOGDIR            :" $LOGDIR

TEMPDIR=$(echo $THISDIR"/temp" | tr '[:upper:]' '[:lower:]')
echo "INFO-TEMPDIR           :" $TEMPDIR

INPUTDIR=$(echo $THISDIR"/input" | tr '[:upper:]' '[:lower:]')
echo "INFO-INPUTDIR          :" $INPUTDIR

REPORTSDIR=$(echo $THISDIR"/reports" | tr '[:upper:]' '[:lower:]')
echo "INFO-REPORTSDIR        :" $REPORTSDIR

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

TEMPFILE=$TEMPDIR"/"$SCRIPT_NAME"_"$CURR_DATE".dat"
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
# Source the config file                                                                              #
#######################################################################################################

eval $(parse_yaml $INPUTDIR/$SCRIPT_NAME.yaml)

#######################################################################################################
# Derive values from config file for the current env                                                  #
#######################################################################################################

verify_param $ENVIRONMENT'_ksql_url'
KSQL_URL=$(eval 'echo $'$ENVIRONMENT'_ksql_url')

verify_param $ENVIRONMENT'_ksql_basic_auth_user'
ksql_basic_auth_user=$(eval 'echo $'$ENVIRONMENT'_ksql_basic_auth_user')

verify_param $ENVIRONMENT'_ksql_basic_auth_password'
ksql_basic_auth_password=$(eval 'echo $'$ENVIRONMENT'_ksql_basic_auth_password')

#######################################################################################################
# Copy static HTML Header to the report file                                                          #
#######################################################################################################

cat $INPUTDIR/html/part_10.html > $REPORTSFILE

#######################################################################################################
# All processing logic goes here                                                                      #
#######################################################################################################

ksql_basic_auth=$(eval echo -u "$ksql_basic_auth_user":"$ksql_basic_auth_password")
if [[ $ksql_basic_auth == '-u :' ]]; then
   ksql_basic_auth=""
fi

#echo $ksql_basic_auth

while read query_file
do

if [[ -n $query_file ]]; then

   echo "**************************************************************************" >>$LOGFILE
   echo `date "+%Y-%m-%d%H:%M:%S"` "- Processing : " $query_file >>$LOGFILE
   echo "**************************************************************************" >>$LOGFILE
   
   # 1. Remove lines starting with -- | sed '/^--/d'
   # 2. Escape single quotes | sed "s/'/'\\\''/g"
   # 3. Replace all newlines with space | tr '\n' ' '
   # 4. Remove all lines containing only whitespace | sed '/^[[:space:]]*$/d'
   # 5. Remove leading and trailing whitespace | sed 's/^[ \t]*//;s/[ \t]*$//', Removed this code to fix an deployment issue
   # 6. Escape asterisks
   # 7. Replace all tabs with space | tr '\t' ' '
   ksql_query=$(eval cat "$query_file" | sed '/^--/d' | sed "s/'/'\\\''/g" | tr '\n' ' ' | sed '/^[[:space:]]*$/d' | sed "s/*/'\\\*'/g" | tr '\t' ' ')

   echo `date "+%Y-%m-%d%H:%M:%S"` "- Full query : " "$ksql_query" >>$LOGFILE

   # Logic to loop on each sub query based on a query delimiter
    
    IFS=';' # ; is set as delimiter
    read -ra ADDR <<< "$ksql_query" # str is read into an array as tokens separated by IFS
    for ksql_sub_query in "${ADDR[@]}"; do # access each element of array
        echo `date "+%Y-%m-%d%H:%M:%S"` "- Sub query before removing special CHAR : " $ksql_sub_query >>$LOGFILE
        echo "==========================================================================" >>$LOGFILE

       # Remove newline and carriage returns
       ksql_sub_query=$(echo "$ksql_sub_query" | sed 's/'`echo -e "\010"`'/ /g' | tr -d '\r' | awk 'NF')
       echo `date "+%Y-%m-%d%H:%M:%S"` "- Sub query : " $ksql_sub_query >>$LOGFILE
       echo "==========================================================================" >>$LOGFILE
      
      #Process only when query is not null or space
      if [ ! -z "$ksql_sub_query" -a "$ksql_sub_query" != " " ] && [ "$ksql_sub_query" != "" ] && [ "$MODE" == 'deploy' ]; then

        #Create Command to deploy the query
        ksql_rest_command=$(echo "curl $ksql_basic_auth -s -X "\""POST"\"" $KSQL_URL/ksql \
       -H "\""Content-Type: application/vnd.ksql.v1+json; charset=utf-8"\"" \
       -d '{"\""ksql"\"": "\"""$ksql_sub_query";"\"" \
           , "\""streamsProperties"\"": { \
           "\""ksql.streams.auto.offset.reset"\"": "\""earliest"\"" \
       }}'")
      
        stream_table_name=$(echo $ksql_sub_query | tr -s " " | sed 's/^[ \t]*//;s/[ \t]*$//' | cut -d ' ' -f 3 | tr -d '\n\r')
        query_file_name=$(echo $query_file | rev | cut -d '/' -f1 | rev)
      
        # Create the report file
        echo "<td>$query_file_name</td>" >> $REPORTSFILE
        echo "<td>$stream_table_name</td>" >> $REPORTSFILE
      
        #Execute Command to deploy the query
        echo "Issuing Command        : " "$ksql_rest_command" >> $LOGFILE
        ksql_rest_command_output=$(eval "$ksql_rest_command")
        echo $ksql_rest_command_output >> $LOGFILE
        
        # Capture the commmand sequence number
        # 1. Get eveything after the key word
        # 2. Get numeric values only from the result        
        ksql_commandSequenceNumber=$(echo $ksql_rest_command_output | tr [a-z] [A-Z] | grep -oP '(?<=COMMANDSEQUENCENUMBER).*')
        ksql_commandSequenceNumber=$(echo $ksql_commandSequenceNumber | cut -d ',' -f 1 | sed 's/[^0-9]*//g')

        # Enhance the error handling to capture the message from curl
        if [[ "$ksql_rest_command_output" == *SUCCESS* ]]; then
            echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name DEPLOYED SUCCESSFULLY" >>$LOGFILE
            echo "<td>Success</td>" >> $REPORTSFILE
        elif [[ "$ksql_rest_command_output" == *EXECUTING* ]]; then
            echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name EXECUTING" >>$LOGFILE
            echo "<td>Executing</td>" >> $REPORTSFILE
        elif [[ "$ksql_rest_command_output" == *QUEUED* ]]; then
            echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name QUEUED" >>$LOGFILE
            echo "<td>Queued</td>" >> $REPORTSFILE
        elif [[ "$ksql_rest_command_output" == *Unauthorized* ]]; then
            echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name UNAUTHORIZED" >>$LOGFILE
            echo "<td>Unauthorized</td>" >> $REPORTSFILE
        elif [[ "$ksql_rest_command_output" == *error_code* ]]; then
            if [[ "$ksql_rest_command_output" == *already* ]]; then
                echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name SKIPPED" >>$LOGFILE
                echo "<td>Skipped</td>" >> $REPORTSFILE
            else
                echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name FAILED" >>$LOGFILE
                echo "<td>Failed</td>" >> $REPORTSFILE
            fi
        else
            echo "DEPLOYMENT-RESULT      : $query_file $stream_table_name STATUS UNKNOWN " >>$LOGFILE
            echo "<td>Not Found</td>" >> $REPORTSFILE
        fi
      
        echo "</tr>" >> $REPORTSFILE

        # Sleep only after executing a valid query
        # Sleep for sometime before making the next call, This allows schema's to have data and kafka to catch up
        if [ ! -z "$DEPLOYMENT_INTERVAL" -a "$DEPLOYMENT_INTERVAL" != " " ]; then
            echo "Sleeping for user input: " $DEPLOYMENT_INTERVAL"s" >>$LOGFILE
            sleep $DEPLOYMENT_INTERVAL"s"
        else
            echo "Sleeping for default   : " "10s" >>$LOGFILE
            sleep 10s
        fi
      
      fi

   done
   IFS=' ' # reset to default value after usage

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
echo "**************************************************************************" >>$LOGFILE

exit 0;