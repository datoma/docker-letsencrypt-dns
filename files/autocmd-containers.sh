#!/bin/sh

domain=$1
containers_and_cmd=$2
is_new_certificate=$3
cluster_provider=$4

if [ ! -S /var/run/docker.sock ]; then
    echo "ERROR: /var/run/docker.sock socket is missing."
    exit 1
fi

if [ ! -d /etc/letsencrypt/archive/$domain ]; then
    echo "ERROR: /etc/letsencrypt/archive/$domain directory is missing."
fi

execute() {
    IFS=','; for container_and_cmd in $containers_and_cmd; do
        # Extract container name and its command
        container_name=""
        command=""
        IFS=':'; for entry in $container_and_cmd; do
            if [ -z $container_name ]; then
            container_name="$entry"
            else
                command="$entry"
            fi
        done; unset IFS
        echo ">>> Executing command '$command' for container $container_name because certificate for $domain has been modified."
        # Execute it
        if [ "$cluster_provider" == "swarm" ]; then
            echo "WARNING: autocmd feature is not supported in Swarm mode and has been ignored."
        else
            docker exec $container_name $command
        fi
    done; unset IFS
}

# Load hash of the certificate
current_hash=`md5sum /etc/letsencrypt/live/$domain/cert.pem | awk '{ print $1 }'`
while true; do
    new_hash=`md5sum /etc/letsencrypt/live/$domain/cert.pem | awk '{ print $1 }'`

    if [ "$is_new_certificate" = true ]; then
        execute
        is_new_certificate=false
    elif [ "$current_hash" != "$new_hash" ]; then
        execute
        # Keep new hash version
        current_hash="$new_hash"
    fi

    # Wait 1s for next iteration
    sleep 1
done
