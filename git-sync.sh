#!/bin/bash

set -e

SOURCE_REPO=$1
SOURCE_BRANCH=$2
DESTINATION_REPO=$3
DESTINATION_BRANCH=$4

if ! echo $SOURCE_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
    SOURCE_REPO="git@github.com:${SOURCE_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    SOURCE_REPO="https://github.com/${SOURCE_REPO}.git"
  fi
fi

if ! echo $DESTINATION_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
    DESTINATION_REPO="git@github.com:${DESTINATION_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    DESTINATION_REPO="https://github.com/${DESTINATION_REPO}.git"
  fi
fi

echo "SOURCE=$SOURCE_REPO:$SOURCE_BRANCH"
echo "DESTINATION=$DESTINATION_REPO:$DESTINATION_BRANCH"

if [[ -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
  # Clone using source ssh key if provided
  git clone -c core.sshCommand="/usr/bin/ssh -i ~/.ssh/src_rsa" "$SOURCE_REPO" /root/source --origin source
else
  git clone "$SOURCE_REPO" /root/source --origin source
fi

cd /root/source

git remote add destination "$DESTINATION_REPO"

# Pull all branches references down locally so subsequent commands can see them
git fetch source '+refs/heads/*:refs/heads/*' --update-head-ok

# Print out all branches
git --no-pager branch -a -vv

if [[ -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
  # Push using destination ssh key if provided
  git config --local core.sshCommand "/usr/bin/ssh -i ~/.ssh/dst_rsa"
fi

# Remove .github directory because we do not want it to be public facing
echo "Current state of repo"
ls -la

echo "Replacing public README with README-public"
mv README-public.md README.md
git add README.md # Adding readme so it gets committed

# TO EXCLUDE A PRIVATE FILE OR DIRECTORY, ADD TO THE FOLLOWING ARRAY
# Note that any valid pathspec (https://git-scm.com/docs/gitglossary#Documentation/gitglossary.txt-aiddefpathspecapathspec)
# can be included for excluding subdirectories, etc
declare -a toExclude=("README-public.md" # Public repo should only have the README which was replaced above.
                      ".github" # Exclude workflows
                      "examples" # Exclude internal examples
                      ".gitignore" # Ignore gitignore for simplicity
                      )

# git rm all excluded pathspecs
for i in "${toExclude[@]}"
do
    git rm -rf --ignore-unmatch $i
done

git config user.email "csci1300@colorado.edu"
git config user.name "CSCI 1300"
echo "Git status post-removal"
git status
echo "Committing..."
git commit --amend -m "Update CSCI 1300 Files"
echo "Git status post-commit"
git status
echo "Pushing"
git push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}" -f
