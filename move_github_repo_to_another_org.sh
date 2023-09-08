#!/bin/sh

#Script capable of migrating repo from Github Org into another Org  
#Was done to backup X to Y
#can 'easily' be reused..

# beware : repository unicity is "grep" and for repository with same prefix would probably fail

#Needs a curl netrc file for github user/password


#Maybe parameters one day
ORG_SRC='VJY0'
ORG_DST='RBB0'
GIT_ROOT_URL='https://mygithub.org'

SCRIPT_VERSION=2.0.0-SNAPSHOT
SCRIPT_NAME=$(basename $0)
CURRENT_DIRECTORY=$(pwd)
TEMP_DIRECTORY=$(mktemp -d)

RED='\033[0;31m'
GRN='\033[0;32m'
NC='\033[0m'
BLUE='\033[0;44m'
YELLOW='\033[0;33m'

TIMESTAMP="date '+%Y-%m-%d %H:%M:%S'"

logMe() {
    timestamp=`eval "$TIMESTAMP"`
    echo -e "$timestamp $*"
}

die() {
    echo -e "${RED}$SCRIPT_NAME: $* ${NC}" >&2
    exit 1
}

blueLog() {
    logMe "${BLUE}INFO: $* ${NC}"
}

info() {
    logMe "${GRN}INFO: $* ${NC}"
}

error() {
    logMe "${RED}ERROR: $* ${NC}" 
}

warning() {
    logMe "${YELLOW}WARN: $* ${NC}"
}

usage() {
    if [ "$*" != "" ] ; then
        error $*
    fi

    cat << EOF
Usage: 
To migrate list of git org repos to new org : $SCRIPT_NAME [csv file] 
or to list all git org repos to csv : $SCRIPT_NAME [all] [csv file]
EOF
    exit 1
}

ListAllRepo() {
  info "fetching out all repo from $1"
  
  url="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -s -k -I --request GET https://mygithub.org/api/v3/orgs/$1/repos"
  info "Repo list cmd [$url]"
  x=$( eval "$url" | grep "link:")
  echo > $2
  if [ ! -z "$x" ];then
     PG=$(echo $x | cut -d ";" -f2 )
     y=${PG##*=}
     PageLast=${y%?}
     RepoList=""
     for i in $(seq 1 $PageLast)
     do
       CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -k -s -w "%{http_code}" --header \"Content-Type: application/json\" --request GET https://mygithub.org/api/v3/orgs/$1/repos?page=\"$i\""
       eval "$CMD" | grep -e '"name"' -e '"description"' | awk -F ':' '{ if ( $1 == "    \"name\"" || $1 == "    \"description\"") print $2 }' | awk -F\" '{ print $2 }' | awk -v sboub="$CMD" '{key=$0; getline; print key ";" key ";" $0;}' >> $2
     done
	#echo " #1#RepoList: $RepoList$list "
  else
    CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -k -s -w "%{http_code}" --header \"Content-Type: application/json\" --request GET https://mygithub.org/api/v3/orgs/$1/repos?per_page=1000 | grep \"name\" | egrep -v \"labels_url|full_name\""
	eval "$CMD" | grep -e '"name"' -e '"description"' | awk -F ':' '{ if ( $1 == "    \"name\"" || $1 == "    \"description\"") print $2 }' | awk -F\" '{ print $2 }' | awk '{key=$0; getline; print key ";" key ";" $0;}' >> $2
  fi
}

PrepCheckifRepoExist() {
  info "Load all repo list from $ORG_SRC for cache/duplicate check"

  url="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -s -k -I --request GET https://mygithub.org/api/v3/orgs/$ORG_DST/repos"
  x=$( eval "$url" | grep "link:")

  if [ ! -z "$x" ];then
     PG=$(echo $x | cut -d ";" -f2 )
     y=${PG##*=}
     PageLast=${y%?}
     RepoList=""
     for i in $(seq 1 $PageLast)
     do
       CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -k -s -w "%{http_code}" --header \"Content-Type: application/json\" --request GET https://mygithub.org/api/v3/orgs/$ORG_DST/repos?page=\"$i\""
       list=$(eval "$CMD" | grep '"name"')
       RepoList=$RepoList$list
     done
	  #echo " #1#RepoList: $RepoList$list "
  else
    CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -k -s -w "%{http_code}" --header \"Content-Type: application/json\" --request GET https://mygithub.org/api/v3/orgs/$ORG_DST/repos?per_page=1000 | grep \"name\" | egrep -v \"labels_url|full_name\""
	  RepoList=$(eval "$CMD")
	  #echo " #2#RepoList: $RepoList$list "
  fi
}

CheckifRepoExist() {
 Repo=$1
 if [ -z "${RepoList##*$Repo*}" ];then
      retval=0
 else
      retval=1
 fi
#  echo "retval : $retval"
}



CurlStatus() {

    info "Running cmd: $1 ($#)"
    varr=$(eval $1)
        
    httpStatus=$( echo ${varr##*\}} )
	
    echo -e "\n" 

	if [ "$#" -eq 3 ]; then
		if [[ "$httpStatus" == 404 ]];then
			warning "($2) FAILED with http code $httpStatus. Please check logs.."
		elif [[ "$httpStatus" -ge 400 ]];then
			error "($2) FAILED with http code $httpStatus. Please check logs.."
			exit 1
		elif [[ "$httpStatus" -ge 200 ]];then
			info "($2) SUCCESS."
		fi
	else
		if [[ "$httpStatus" -ge 400 ]];then
			error "$2 FAILED with http code $httpStatus. Please check logs.."
			exit 1
		elif [[ "$httpStatus" -ge 200 ]];then
			info "$2 SUCCESS."
		fi
	fi	
}

AddDevRolesToRepo(){
    info "Adding team roles for $ORG_DST $PWD"
	
	CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -s -k -w \"%{http_code}\" --header \"Content-Type: application/json\" --request PUT --data '{\"permission\": \"admin\"}' https://mygithub.org/api/v3/teams/$DEV_LEAD_ID/repos/$ORG_DST/$NEW_REPO_NAME"
	CurlStatus "$CMD" "added developer lead team to repository"
	
	CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -s -k -w \"%{http_code}\" --header \"Content-Type: application/json\" --request PUT --data '{\"permission\": \"push\"}' https://mygithub.org/api/v3/teams/$DEV_ID/repos/$ORG_DST/$NEW_REPO_NAME"
	CurlStatus "$CMD" "added developer team to repository"
	
	info "Team roles probably applied..!? :)"
}

FindDevRolesToRepo(){
    info "Searching team roles for $ORG_DST"
	
	DEV_LEAD_ID=$(curl --netrc-file $CURRENT_DIRECTORY/netrcfile -s -k \
			https://mygithub.org/api/v3/orgs/$ORG_DST/teams \
			| grep -A1 '"Developer Lead"' | grep "id" | awk '{print $2}' | sed 's/[^0-9]*//g')
	info "Found DEV_LEAD_ID=[$DEV_LEAD_ID]"
	
	DEV_ID=$(curl --netrc-file $CURRENT_DIRECTORY/netrcfile -s -k \
			https://mygithub.org/api/v3/orgs/$ORG_DST/teams \
			| grep -A1 '"Developer"' | grep "id" | awk '{print $2}' | sed 's/[^0-9]*//g')
	
	info "Found DEV_ID=[$DEV_ID]"
	
	if [[ $DEV_LEAD_ID == "" || $DEV_ID == "" ]]; then
		error "Dev or Dev Lead id not found !"
		exit -1
	fi
}

AddBranchRestriction() {

    info "Creating branch restrictions for master"
    CMD="curl -k -s -w \"%{http_code}\" --netrc-file $CURRENT_DIRECTORY/netrcfile --header \"Content-Type: application/json\" --request PUT --data  '{\"restrictions\": {\"users\": [],\"teams\": [\"developer-lead\"]},\"required_status_checks\": null,\"enforce_admins\": true,\"required_pull_request_reviews\": null}' https://mygithub.org/api/v3/repos/$ORG_DST/$NEW_REPO_NAME/branches/master/protection"
    CurlStatus "$CMD" "Add Branch restrictions for master" 404

    info "Creating branch restrictions for Integration"
    CMD="curl -k -s -w \"%{http_code}\" --netrc-file $CURRENT_DIRECTORY/netrcfile --header \"Content-Type: application/json\" --request PUT --data  '{\"restrictions\": {\"users\": [],\"teams\": [\"developer-lead\"]},\"required_status_checks\": null,\"enforce_admins\": true,\"required_pull_request_reviews\": null}' https://mygithub.org/api/v3/repos/$ORG_DST/$NEW_REPO_NAME/branches/Integration/protection"
    CurlStatus "$CMD" "Add Branch restrictions for Integration" 404
}

RemoveBranchRestriction() {

    info "Remove branch restrictions for master"
    CMD="curl -k -s -w \"%{http_code}\" --netrc-file $CURRENT_DIRECTORY/netrcfile --header \"Content-Type: application/json\" --request DELETE https://mygithub.org/api/v3/repos/$ORG_DST/$NEW_REPO_NAME/branches/master/protection"
    CurlStatus "$CMD" "Remove Branch restrictions for master" 404

    info "Remove branch restrictions for Integration"
    CMD="curl -k -s -w \"%{http_code}\" --netrc-file $CURRENT_DIRECTORY/netrcfile --header \"Content-Type: application/json\" --request DELETE https://mygithub.org/api/v3/repos/$ORG_DST/$NEW_REPO_NAME/branches/Integration/protection"
    CurlStatus "$CMD" "Remove Branch restrictions for Integration" 404
}

####################################################################################################################################
# Main block
####################################################################################################################################

if [ "$#" -ne 1 ] && [ "$#" -ne 2 ]; then
  usage "Incorrect number of arguments"
fi

# we are in generation mode
if [ "$#" -eq 2 ]; then

	if [ $1 == "all" ]; then
		info "[$1] parameter detected : let's loop for all repo"
		
		ListAllRepo "$ORG_SRC" $2
		info "feed [$CURRENT_DIRECTORY/$2] with all that stuff"
		exit 0
	else
		usage "In generation mode, must be [all] + [csv output filename]"
	fi
fi

# else we only have CSV file input
CSV_FILE=$1

blueLog "******************************************************************************************************"
blueLog "Let's move stuff from $ORG_SRC to $ORG_DST"

# run some long running stuff to speed up all that crap
FindDevRolesToRepo
PrepCheckifRepoExist

TEMPFILE=/tmp/$$.tmp
echo 0 > $TEMPFILE

cat $CSV_FILE | grep -v "^$" | while read line
do
    OLD_REPO_NAME=`echo "$line" | awk -F\; '{print $1}'`
    NEW_REPO_NAME=`echo "$line" | awk -F\; '{print $2}'`
    DESCRIPTION=`echo "$line" | awk -F\; '{print $3}'`
    FORCE_CREATE=`echo "$line" | awk -F\; '{print $4}'`

    if [[ "$OLD_REPO_NAME" =~ ^#.*  ]]; then
      warning "ignore line $OLD_REPO_NAME"
    else
      COUNTER=$[$(cat $TEMPFILE) + 1]
      echo $COUNTER > $TEMPFILE

      blueLog "-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
      blueLog "($COUNTER) $ORG_SRC/${OLD_REPO_NAME//%20/ } -> $ORG_DST/$NEW_REPO_NAME"

      need_to_create_repo=0
      repo_already_exists=0

      CheckifRepoExist "$NEW_REPO_NAME"
      if [ "$retval" == 0 ]; then
        warning "Repo $ORG_DST/$NEW_REPO_NAME exists, bork bork bork"
        if [ "$FORCE_CREATE" == "FORCE" ]; then
          info "nah FORCE : let's go for it anyway..."
          need_to_create_repo=1
          repo_already_exists=1
        fi
      else
        info "Repo $ORG_DST/$NEW_REPO_NAME doesn't exist... creating it."
        need_to_create_repo=1
      fi

      if [ "$need_to_create_repo" == 1 ]; then

        if [ "$repo_already_exists" == 0 ]; then
          CMD="curl --netrc-file $CURRENT_DIRECTORY/netrcfile -k -s -w \"%{http_code}\" --header \"Content-Type: application/json\" --request POST --data '{\"name\": \"$NEW_REPO_NAME\",\"description\":\"$DESCRIPTION\"}' https://mygithub.org/api/v3/orgs/$ORG_DST/repos"
          CurlStatus "$CMD" "repository creation"
        else
          # if exists already, remove branch protection
          RemoveBranchRestriction $ORG_DST $GIT_REPO_NAME
        fi

        NEW_TMP_GIT_DIR=$(mktemp -d)
        info "New temporary git repo directory created [$NEW_TMP_GIT_DIR]"

        info "First checking out the stuff to [$NEW_TMP_GIT_DIR] $?"
        cd $NEW_TMP_GIT_DIR
        git clone --bare "$GIT_ROOT_URL/$ORG_SRC/$OLD_REPO_NAME"
        if [ "$?" != 0 ]; then
          error "Error during [git clone --bare $GIT_ROOT_URL/$ORG_SRC/$OLD_REPO_NAME]"
          die "stop !"
        fi

        info "The flush in target repo [$ORG_DST]"
        cd "$OLD_REPO_NAME.git"
        git push --mirror --force "$GIT_ROOT_URL/$ORG_DST/$NEW_REPO_NAME"

        # left as clean when we get in
        info "Cleaning up repo $NEW_TMP_GIT_DIR"
        rm -rf $NEW_TMP_GIT_DIR

        # add standard security stuff
        AddDevRolesToRepo
        AddBranchRestriction $ORG_DST $GIT_REPO_NAME
      fi

    fi

done

COUNTER=$[$(cat $TEMPFILE)]

blueLog "($COUNTER) repo moved from $ORG_SRC to $ORG_DST. Bye!"
blueLog "******************************************************************************************************"

unlink $TEMPFILE
exit 0
