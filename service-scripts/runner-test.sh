# 1=TOKEN 2=IMAGE
if [ ! $1 ]; then
 echo "Usage: $0 TOKEN IMAGE(default: webrunners/gitlab-runner-service)"
 exit
fi

IMAGE=${2:-webrunners/gitlab-runner-service}

docker run -ti --rm -e "TOKEN=$1" -e "EXECUTOR=shell" -e "URL=https://code.webrunners.de:443/ci" $IMAGE
