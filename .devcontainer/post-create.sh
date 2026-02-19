#!/bin/bash
#loading functions to script
export SECONDS=0
source .devcontainer/util/source_framework.sh

setUpTerminal

verifyEnvironmentVars
#TODO: BeforeGoLive: uncomment this. This is only needed for professors to have the Mkdocs live in the container
finalizePostCreation

printInfoSection "Your dev container finished creating"



