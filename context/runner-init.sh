#!/bin/bash

unregister(){
    gitlab-runner unregister --all-runners
}


# Ensure clean removal from gitlab in most cases
trap unregister SIGINT SIGTERM SIGHUP EXIT  # cannot be caught: SIGKILL SIGSTOP

# Ensure sudo rights
touch /etc/sudoers.d/gitlab-runner
echo '%gitlab-runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gitlab-runner
chmod 0400 /etc/sudoers.d/gitlab-runner

# Ensure docker run permissions
groupadd -g `stat -c"%g" /var/run/docker.sock` docker || true
usermod -a -G docker gitlab-runner


CONFIG_DIR=/etc/gitlab-runner
STACK=$(docker inspect $HOSTNAME --format '{{index .Config.Labels "com.docker.stack.namespace"}}')
NODE_ID=$(docker inspect $HOSTNAME --format '{{index .Config.Labels "com.docker.swarm.node.id"}}')
NODE=$(docker node inspect $NODE_ID --format '{{.Description.Hostname}}')

# You could use this under stack files environment tag:
#  - STACK={{index .Service.Labels "com.docker.stack.namespace"}}  # - STACK={{printf "%#v" .}}
if [[ ! "${SERVICE:-}" ]]; then
    SERVICE=$(docker inspect $HOSTNAME --format '{{index .Config.Labels "com.docker.swarm.service.name"}}')
fi

: ${SERVICE:?SERVICE required}
DESCRIPTION=${SERVICE}_${HOSTNAME}@$NODE

# Ensure config/secret is bound to myself
dCONFIG=$(docker config ls --format {{.Name}}|grep '^runner$') || true
dSECRET=$(docker secret ls --format {{.Name}}|grep "^${SERVICE}$") || true
dSECRET_ALT=$(docker secret ls --format {{.Name}}|grep "^${STACK}$") || true
docker service update $SERVICE -d ${dCONFIG:+--config-rm $dCONFIG --config-add $dCONFIG}${dSECRET:+ --secret-rm $dSECRET --secret-add $dSECRET}${dSECRET_ALT:+ --secret-rm $dSECRET_ALT --secret-add $dSECRET_ALT} || true

# Source some variables
. /var/run/secrets/$STACK || true
. /var/run/secrets/$SERVICE || true
. /runner || true

export CI_SERVER_URL=${URL:-${CI_SERVER_URL:?One of URL, CI_SERVER_URL required}}
export REGISTRATION_TOKEN=${TOKEN:-${REGISTRATION_TOKEN:-${CI_SERVER_TOKEN:?One of TOKEN, REGISTRATION_TOKEN, CI_SERVER_TOKEN required}}}
export RUNNER_EXECUTOR=${EXECUTOR:-${RUNNER_EXECUTOR:-shell}}

# Misc options
if [[ $RUNNER_EXECUTOR == 'docker' ]]; then
    OPTIONS+=" --docker-image docker:latest --docker-volumes /var/run/docker.sock:/var/run/docker.sock"
fi

if [[ $TAG_LIST ]]; then
    OPTIONS+=" --tag-list ${TAG_LIST// /,}"
fi


# Main
gitlab-runner register${OPTIONS} -n --description "$DESCRIPTION" --locked  # --executor ${EXECUTOR:-shell} -u ${URL:?URL required} -r ${TOKEN:?TOKEN required}

/entrypoint $@
