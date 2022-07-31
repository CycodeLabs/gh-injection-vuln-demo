#!/bin/bash


# File to commit
FILE_URL_PATH_TO_COMMIT=$1
# Repository path where to commit
PATH_TO_COMMIT=$2


COMMIT_NAME="Maintainer Name"
COMMIT_EMAIL="maintainer@gmail.com"
COMMIT_MESSAGE="innocent commit message"


# Fetching the file
curl $FILE_URL_PATH_TO_COMMIT -o $PATH_TO_COMMIT --create-dirs


# Commiting to the repo
git add *
find . -name '.[a-z]*' -exec git add '{}' ';' # Adding hidden files
git config --global user.email $COMMIT_EMAIL
git config --global user.name "$COMMIT_NAME"
git commit -m "$COMMIT_MESSAGE"
git push -u origin HEAD