
MPID="$1"
ret=0

#---

if [ -z "$MPID" ] ; then
  if [ -n "$TUNNEL_DEBUG" ] ; then
    exec 2>/tmp/t1
    set -x
    env >&2
  fi

  ABSPATH=$(cd "$(dirname "$0")"; pwd -P)

  query="`dd 2>/dev/null`"
  [ -n "$TUNNEL_DEBUG" ] && echo "query: <$query>" >&2

  export TIMEOUT="`echo $query | sed -e 's/^.*\"timeout\": *\"//' -e 's/\".*$//g'`"
  export SSH_CMD="`echo $query | sed -e 's/^.*\"ssh_cmd\": *\"//' -e 's/\",.*$//g' -e 's/\\\"/\"/g'`"
  export LOCAL_HOST="`echo $query | sed -e 's/^.*\"local_host\": *\"//' -e 's/\".*$//g'`"
  export LOCAL_PORT="`echo $query | sed -e 's/^.*\"local_port\": *\"//' -e 's/\".*$//g'`"
  export TARGET_HOST="`echo $query | sed -e 's/^.*\"target_host\": *\"//' -e 's/\".*$//g'`"
  export TARGET_PORT="`echo $query | sed -e 's/^.*\"target_port\": *\"//' -e 's/\".*$//g'`"
  export GATEWAY_HOST="`echo $query | sed -e 's/^.*\"gateway_host\": *\"//' -e 's/\".*$//g'`"
  export GATEWAY_PORT="`echo $query | sed -e 's/^.*\"gateway_port\": *\"//' -e 's/\".*$//g'`"
  export GATEWAY_USER="`echo $query | sed -e 's/^.*\"gateway_user\": *\"//' -e 's/\".*$//g'`"
  export SHELL_CMD="`echo $query | sed -e 's/^.*\"shell_cmd\": *\"//' -e 's/\",.*$//g' -e 's/\\\"/\"/g'`"
  export SSH_TUNNEL_CHECK_SLEEP="`echo $query | sed -e 's/^.*\"ssh_tunnel_check_sleep\": *\"//' -e 's/\",.*$//g' -e 's/\\\"/\"/g'`"
  export CREATE="`echo $query | sed -e 's/^.*\"create\": *\"//' -e 's/\",.*$//g' -e 's/\\\"/\"/g'`"
  export SSM_INSTANCE_NAME="`echo $query | sed -e 's/^.*\"ssm_instance_name\": *\"//' -e 's/\".*$//g'`"
  export AWS_PROFILE="`echo $query | sed -e 's/^.*\"aws_profile\": *\"//' -e 's/\".*$//g'`"

  if [ "X$CREATE" = X -o "X$SSM_INSTANCE_NAME" = X ] ; then
    # No tunnel - connect directly to target host
    do_tunnel=''
    cnx_host="$TARGET_HOST"
    cnx_port="$TARGET_PORT"
  else
    do_tunnel='y'
    cnx_host="$LOCAL_HOST"
    cnx_port="$LOCAL_PORT"
  fi

  echo "{ \"host\": \"$cnx_host\",  \"port\": \"$cnx_port\" }"

  if [ -n "$do_tunnel" ] ; then
    p=`ps -p $PPID -o "ppid="`
    clog=`mktemp`
    nohup timeout $TIMEOUT $SHELL_CMD "$ABSPATH/tunnel.sh" $p <&- >&- 2>$clog &
    CPID=$!
    # A little time for the SSH tunnel process to start or fail
    sleep 3
    # If the child process does not exist anymore after this delay, report failure
    if ! ps -p $CPID >/dev/null 2>&1 ; then
      echo "Child process ($CPID) failure - Aborting" >&2
      echo "Child diagnostics follow:" >&2
      cat $clog >&2
      rm -f $clog
      ret=1
    fi
    rm -f $clog
  fi
else
  #------ Child
  if [ -n "$TUNNEL_DEBUG" ] ; then
    exec 2>/tmp/t2
    set -x
    env >&2
  fi

  if [ "X$SSM_INSTANCE_NAME" != "X" ] ; then
    export INSTANCE_ID=$(aws ssm describe-instance-information --filters "Key=tag:Name,Values=$SSM_INSTANCE_NAME" | jq -r '.InstanceInformationList[].InstanceId')
    export GATEWAY_HOST=$INSTANCE_ID
    gw="$GATEWAY_HOST"
    cat << EOF > /tmp/ssh_config
host $INSTANCE_ID
    ProxyCommand sh -c "aws ssm start-session --target $INSTANCE_ID --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    User $GATEWAY_USER
    StrictHostKeyChecking no
EOF
    ssh -F /tmp/ssh_config -N -L $LOCAL_HOST:$LOCAL_PORT:$TARGET_HOST:$TARGET_PORT -p $GATEWAY_PORT $gw &
  else
    gw="$GATEWAY_HOST"
    [ "X$GATEWAY_USER" = X ] || gw="$GATEWAY_USER@$GATEWAY_HOST"
    $SSH_CMD -N -L $LOCAL_HOST:$LOCAL_PORT:$TARGET_HOST:$TARGET_PORT -p $GATEWAY_PORT $gw &
  fi

  CPID=$!
  
  sleep $SSH_TUNNEL_CHECK_SLEEP

  while true ; do
    if ! ps -p $CPID >/dev/null 2>&1 ; then
      echo "SSH process ($CPID) failure - Aborting" >&2
      exit 1
    fi
    ps -p $MPID >/dev/null 2>&1 || break
    sleep 1
  done

  kill $CPID
fi

exit $ret
