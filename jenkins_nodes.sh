#!/bin/sh

SCRIPT_NAME=$(basename $0)

SCRIPT_HOME=/app
JENKINS_HOME=$SCRIPT_HOME/jenkins
LOG_DIR=$SCRIPT_HOME/logs
TMP_DIR=$SCRIPT_HOME/temp
PROPERTIES_FILE=properties.slaves

JAVA_HOME=/app/java/jdk1.8.0_25/bin
JENKINS_HOME=/app/jenkins
JENKINS_4_HOME=/app/jenkins4
JENKINS_URL=https://myjenkins.org:8443/computer/
JENKINS_4_URL=https://myjenkins4.org:8443/computer/
JENKINS_AGENT=slave-agent.jnlp

RED='\033[0;31m'
GRN='\033[0;32m'
NC='\033[0m'


die() {
  echo -e "${RED}$SCRIPT_NAME: $* ${NC}" >&2
  exit 1
}

usage() { 
  if [ "$*" != "" ] ; then
    echo -e "${RED}ERROR: $* ${NC}"
  fi

  cat << EOF
Usage: $SCRIPT_NAME [all|APP_CODE] [status|stop|start]
Stop and start Jenkins Slaves or show their status.

Options: [all|APP_CODE] Chose either all slaves, or specify one by app_code
	 status - show the status of this slave (or all slaves)
         stop - stop
         start - start

Examples : ./$SCRIPT_NAME all stop - stop all jenkins slaves
           ./$SCRIPT_NAME RBB0 status - show the status of the RBB0 slave.
EOF

  exit 1
}

start_slave() {
  if [ "$*" == "" ] ; then
    die "ERROR: No slave name passed to start_slave()"
  fi

  if [ "$*" == "all" ] ; then
    sed 1,2d $PROPERTIES_FILE | grep -v "^$" | while read line
    do
      APP_CODE=`echo "$line" | awk '{print $1}'`
      SLAVE_NAME=`echo "$line" | awk '{print $2}'`
      SLAVE_USER=`echo "$line" | awk '{print $3}'`
      SLAVE_KEY=`echo "$line" | awk '{print $4}'`
      PID=`ps -ef | grep $SLAVE_NAME | grep $SLAVE_KEY | grep -v grep | awk '{print $2}'`
      echo -e "${GRN}Starting${NC} Slave [$SLAVE_NAME] as User [$SLAVE_USER] with Key [$SLAVE_KEY]"

      if [[ "UYU0" == "$APP_CODE" ]]; then
	SRV=$JENKINS_4_URL
	HM=$JENKINS_4_HOME
      else
	SRV=$JENKINS_URL
	HM=$JENKINS_HOME
      fi

      if [[ "" != "$PID" ]]; then
        echo -e "Slave [$SLAVE_NAME] is ${GRN}*ALREADY* Running${NC}"
      else
        sudo su - $SLAVE_USER <<EOF
nohup "$JAVA_HOME"/java -Djava.util.logging.loglevel=FINE -Djava.io.tmpdir="$TMP_DIR" -Djavax.net.ssl.trustStore="$HM"/jenkinslave.jks -jar "$HM"/slave.jar -jnlpUrl "$SRV$SLAVE_NAME/$JENKINS_AGENT" -secret "$SLAVE_KEY" >> "$LOG_DIR"/"$SLAVE_NAME.log" 2>&1&
EOF

        status_slave "$APP_CODE"  
      fi
    done
  else
    line=`grep -i $* $PROPERTIES_FILE`
    APP_CODE=`echo "$line" | awk '{print $1}'`
    SLAVE_NAME=`echo "$line" | awk '{print $2}'`
    SLAVE_USER=`echo "$line" | awk '{print $3}'`
    SLAVE_KEY=`echo "$line" | awk '{print $4}'`
    PID=`ps -ef | grep $SLAVE_NAME | grep $SLAVE_KEY | grep -v grep | awk '{print $2}'`
    echo -e "${GRN}Starting${NC} Slave [$SLAVE_NAME] as User [$SLAVE_USER] with Key [$SLAVE_KEY]"
      if [[ "UYU0" == "$APP_CODE" ]]; then
	SRV=$JENKINS_4_URL
	HM=$JENKINS_4_HOME
echo "Url = $SRV"
      else
	SRV=$JENKINS_URL
	HM=$JENKINS_HOME
      fi
    if [[ "" != "$PID" ]]; then
      echo -e "Slave [$SLAVE_NAME] is ${GRN}*ALREADY* Running${NC}"
    else
      sudo su - $SLAVE_USER <<EOF
nohup "$JAVA_HOME"/java -Djava.util.logging.loglevel=FINE -Djava.io.tmpdir="$TMP_DIR" -Djavax.net.ssl.trustStore="$HM"/jenkinslave.jks -jar "$HM"/slave.jar -jnlpUrl "$SRV$SLAVE_NAME/$JENKINS_AGENT" -secret "$SLAVE_KEY" >> "$LOG_DIR"/"$SLAVE_NAME.log" 2>&1&
EOF

      status_slave "$APP_CODE"  
    fi
  fi

}


stop_slave() {
  if [ "$*" == "" ] ; then
    die "ERROR: No slave name passed to stop_slave()"
  fi

  if [ "$*" == "all" ] ; then
     sed 1,2d  $PROPERTIES_FILE | grep -v "^$" | while read line
    do
      APP_CODE=`echo "$line" | awk '{print $1}'`
      SLAVE_NAME=`echo "$line" | awk '{print $2}'`
      SLAVE_USER=`echo "$line" | awk '{print $3}'`
      SLAVE_KEY=`echo "$line" | awk '{print $4}'`
      PID=`ps -ef | grep $SLAVE_NAME | grep $SLAVE_KEY | grep -v grep | awk '{print $2}'`
      if [[ "" != "$PID" ]]; then
        echo -e "${RED}Stopping${NC} slave [$SLAVE_NAME]..."
        sudo su - $SLAVE_USER <<EOF
kill -9 "$PID"
echo "$SLAVE_NAME Stopped" >> "$LOG_DIR"/"$SLAVE_NAME".log
mv "$LOG_DIR"/"$SLAVE_NAME".log "$LOG_DIR"/"$SLAVE_NAME".$(date -d "today" +"%Y%m%d%H%M%S").log
EOF
        
        status_slave "$APP_CODE"  
      else
        echo -e "Slave [$SLAVE_NAME] is ${RED}*NOT* Running${NC}"
      fi
   done
  else
    line=`grep -i $* $PROPERTIES_FILE`
    APP_CODE=`echo "$line" | awk '{print $1}'`
    SLAVE_NAME=`echo "$line" | awk '{print $2}'`
    SLAVE_USER=`echo "$line" | awk '{print $3}'`
    SLAVE_KEY=`echo "$line" | awk '{print $4}'`
    PID=`ps -ef | grep $SLAVE_NAME | grep $SLAVE_KEY | grep -v grep | awk '{print $2}'`
    if [[ "" != "$PID" ]]; then
      echo -e "${RED}Stopping${NC} slave [$SLAVE_NAME]..."
      sudo su - $SLAVE_USER <<EOF
kill -9 "$PID"
echo "$SLAVE_NAME" Stopped >> "$LOG_DIR"/"$SLAVE_NAME".log
mv "$LOG_DIR"/"$SLAVE_NAME".log "$LOG_DIR"/"$SLAVE_NAME".$(date -d "today" +"%Y%m%d%H%M%S").log
EOF

      status_slave "$APP_CODE"  
    else
      echo -e "Slave [$SLAVE_NAME] is ${RED}*NOT* Running${NC}"
    fi
  fi
}

status_slave() {
  if [ "$*" == "" ] ; then
    die "ERROR: No slave name passed to stop_slave()"
  fi
  
  if [ "$*" == "all" ] ; then
    sed 1,2d $PROPERTIES_FILE | grep -v "^$" | while read line
    do
      SLAVE_NAME=`echo "$line" | awk '{print $2}'`
      SLAVE_KEY=`echo "$line" | awk '{print $4}'`
      PID=`ps -ef | grep $SLAVE_NAME | grep $SLAVE_KEY | grep -v grep | awk '{print $2}'`
      if [[ "" != "$PID" ]]; then
        echo -e "Slave [$SLAVE_NAME] is ${GRN}Running [$PID]${NC}"
      else
        echo -e "Slave [$SLAVE_NAME] is ${RED}*NOT* Running${NC}" 
     fi 
   done
  else
    line=`grep -i $* $PROPERTIES_FILE`
    SLAVE_NAME=`echo "$line" | awk '{print $2}'`
    SLAVE_KEY=`echo "$line" | awk '{print $4}'`
    PID=`ps -ef | grep $SLAVE_NAME | grep $SLAVE_KEY | grep -v grep | awk '{print $2}'`
    if [[ "" != "$PID" ]]; then
        echo -e "Slave [$SLAVE_NAME] is ${GRN}Running [$PID]${NC}"
    else
        echo -e "Slave [$SLAVE_NAME] is ${RED}*NOT* Running${NC}" 
    fi 
  fi
}

chmod_slave() {
  if [ "$*" == "" ] ; then
    die "ERROR: No slave name passed to chmod_slave()"
  fi
  
  if [ "$*" == "all" ] ; then
    sed 1,2d $PROPERTIES_FILE | grep -v "^$" | while read line
    do
      SLAVE_USER=`echo "$line" | awk '{print $3}'`
      sudo su - $SLAVE_USER <<EOF
rm -f ~/.mavenrc
cat <<FOE > ~/.mavenrc
umask 007
FOE

mkdir ~/.m2
cp /app/maven/settings/settings-security.xml ~/.m2/

setfacl -Rdm g:myunixgroup:rwx /app/maven/repo
setfacl -Rdm g:myunixgroup:rwx /app/jenkins_workspaces
setfacl -Rm g:myunixgroup:rwx /app/maven/repo
setfacl -Rm g:myunixgroup:rwx /app/jenkins_workspaces
setfacl -Rm g:myunixgroup:rwx /app/temp
setfacl -Rdm o::0 /app/maven/repo
setfacl -Rdm o::0 /app/jenkins_workspaces
setfacl -Rdm o::0 /app/temp
setfacl -Rm o::0 /app/maven/repo
setfacl -Rm o::0 /app/jenkins_workspaces
setfacl -Rm o::0 /app/temp

chmod -R 770 /app/maven/repo
chmod -R 770 /app/jenkins_workspaces
chmod -R 770 /app/temp
chgrp -R myunixgroup /app/maven/repo
chgrp -R myunixgroup /app/jenkins_workspaces
chgrp -R myunixgroup /app/temp
chmod g+s /app/maven/repo
chmod g+s /app/jenkins_workspaces
chmod g+s /app/temp
EOF
   done
  else
    line=`grep -i $* $PROPERTIES_FILE`
    SLAVE_USER=`echo "$line" | awk '{print $3}'`
    sudo su - $SLAVE_USER <<EOF
whoami
echo $PATH
echo **GIT config BEFORE update
/app/git/usr/bin/git config --global -l
/app/git/usr/bin/git config --global --unset-all http.sslverify
/app/git/usr/bin/git config --global --unset-all user.name
/app/git/usr/bin/git config --global --unset-all user.email
/app/git/usr/bin/git config --global --unset-all init.templatedir
/app/git/usr/bin/git config --global http.sslverify false
/app/git/usr/bin/git config --global user.name MYSERVICEID
/app/git/usr/bin/git config --global user.email MYSERVICEID@users.noreply.mygithub.org
/app/git/usr/bin/git config --global init.templatedir /app/git/usr/share/git-core/templates/
echo **GIT config AFTER update
/app/git/usr/bin/git config --global -l
echo **SSH directory content BEFORE update
ls -lstra .ssh
cp /app/jenkins_workspaces/id_rsa* .ssh
echo **SSH directory content AFTER update
ls -lstra .ssh
#chmod -R 777 /app/maven/repo
#chgrp -R myunixgroup /app/maven/repo
EOF
  fi
}

####

if [ "$#" -ne 2 ]; then
  usage "Incorrect number of arguments"
fi 

SLAVE_NAME=$1
ACTION=$2

check_line=`sed 1,2d $PROPERTIES_FILE | grep -i $SLAVE_NAME`
if [ "$SLAVE_NAME" != "all" ]; then
  if [ -z "$check_line" ]; then
    die "$SLAVE_NAME is not a valid slave name"
  fi
fi

case $ACTION in
  start)
    start_slave $SLAVE_NAME
  ;;
  stop)
    stop_slave $SLAVE_NAME
  ;;
  status)
    status_slave $SLAVE_NAME
  ;;
  chmod)
    chmod_slave $SLAVE_NAME
  ;;
  *)
    usage "Unknown action $ACTION, should be one of start/stop/status"
  ;;
esac
