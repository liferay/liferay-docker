#!/bin/bash

function check_container_running {
    if docker ps | grep -q test-container
    then
        echo "Container started successfully"
        echo "<html><body><h1>Hello!</h1></body></html>" > test_files/index.html

        sleep 2

        response=$(curl -s http://localhost:8080/index.html)

        if [[ $response == *"Hello!"* ]]
        then
            echo "Content served properly from /public_html folder"
        else
            echo "Content serving test failed"
        fi

        docker stop test-container
        docker rm test-container

    else
        echo "Container failed to start"
    fi
}

function main {
    run_container

    check_container_running
}

function run_container {
    docker run -d --name test-container -p 8080:80 -v $(pwd)/test_files:/public_html liferay/caddy

    sleep 5
}

main "${@}"