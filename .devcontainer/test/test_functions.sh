#!/bin/bash
# Here is the definition of the test functions, the file needs to be loaded within the functions.sh file

assertDynatraceOperator(){

    printInfoSection "Testing Dynatrace Operator Deployment"
    kubectl get all -n dynatrace
    printWarn "TBD"
}

assertDynatraceCloudNative(){
    printInfoSection "Testing Dynatrace CloudNative FullStack deployment"
    kubectl get all -n dynatrace
    kubectl get dynakube -n dynatrace
    printWarn "TBD"
}

assertRunningApp(){
  # The 1st agument is the port.
  if [ -z "$1" ]; then
    PORT=30100
  else
    PORT=$1
  fi
    
  URL="http://127.0.0.1:$PORT"
  printInfoSection "Testing Deployed app running in $URL"

  printInfo "Asserting app is running as NodePort in kind-control-plane in port $URL"

  if docker exec kind-control-plane sh -c "curl --silent --fail $URL" > /dev/null; then
    printInfo "✅ App is running on $URL"
  else
    printError "❌ App is NOT running on $URL"
    exit 1
  fi
}

getVscodeContainername(){
    docker ps --format '{{json .}}' | jq -s '.[] | select(.Image | contains("vsc")) | .Names'
    containername=$(docker ps --format '{{json .}}' | jq -s '.[] | select(.Image | contains("vsc")) | .Names')
    containername=${containername//\"/}
    echo "$containername"
}

assertRunningPod(){

  printInfoSection "Asserting running pods in namespace '$1' that contain the name '$2'"
  # Function to filter by Namespace and POD string, default is ALL namespaces
  # If 2 parameters then the first is Namespace the second is Pod-String
  # If 1 parameters then Namespace == all-namespaces the first is Pod-String
  if [[ $# -eq 2 ]]; then
    namespace_filter="-n $1"
    pod_filter="$2"
    verify_namespace=true
  elif [[ $# -eq 1 ]]; then
    namespace_filter="--all-namespaces"
    pod_filter="$1"
  fi

  # Need to check if the NS exists
  if [[ $verify_namespace == true ]]; then
    kubectl get namespace "$1" >/dev/null 2>&1
    if [[ $? -eq 1 ]]; then
      printError "❌ Namespace \"$1\" does not exists."
      exit 1
    fi
  fi

  # Get all pods, count and invert the search for not running nor completed. Status is for deleting the last line of the output
  CMD="kubectl get pods $namespace_filter 2>&1 | grep -c -E '$pod_filter'"
  printInfo "Verifying that pods in \"$namespace_filter\" with name \"$pod_filter\" are up and running."
  pods_running=$(eval "$CMD")
  
  if [[ "$pods_running" != '0' ]]; then
      printInfo "✅ \"$pods_running\" pods are running on \"$namespace_filter\" with name \"$pod_filter\"."    
  else 
      printError "❌ \"$pods_running\" pods are running on \"$namespace_filter\" with name \"$pod_filter\". "
      kubectl get pods $namespace_filter
      exit 1
  fi
}

assertRunningHttp(){
  # The 1st argument is the port. Checks if localhost is listening and responding to HTTP on that port.
  if [ -z "$1" ]; then
    PORT=8501
  else
    PORT=$1
  fi

  URL="http://127.0.0.1:$PORT"
  printInfoSection "Asserting HTTP service is reachable on $URL"

  if curl --silent --fail --max-time 5 "$URL" > /dev/null 2>&1; then
    printInfo "✅ HTTP service is listening and responding on $URL"
  else
    printError "❌ HTTP service is NOT reachable on $URL"
    printInfo "Checking if port $PORT is open on the loopback interface..."
    ss -tlnp "sport = :$PORT" 2>/dev/null || netstat -tlnp 2>/dev/null | grep ":$PORT" || true
    exit 1
  fi
}

assertRunningContainer(){
  # The 1st argument is the image name (or substring) to look for in running containers.
  if [ -z "$1" ]; then
    printError "❌ assertRunningContainer requires an image name argument."
    exit 1
  fi

  IMAGE_NAME="$1"
  printInfoSection "Asserting running container with image containing '$IMAGE_NAME'"

  MATCH=$(docker ps --format '{{.Image}}' | grep -c "$IMAGE_NAME")

  if [[ "$MATCH" -gt 0 ]]; then
    printInfo "✅ Found $MATCH running container(s) with image matching '$IMAGE_NAME'."
  else
    printError "❌ No running containers found with image matching '$IMAGE_NAME'."
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
    exit 1
  fi
}

assertDynakube(){
    printInfoSection "Verifying Dynakube is deployed and running"

}