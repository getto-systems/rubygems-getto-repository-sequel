#!/bin/bash

git remote add super https://gett-systems:$GITLAB_ACCESS_TOKEN@gitlab.com/getto-systems-labo/rubygems-repository-sequel.git
git remote add backup https://getto-systems:$GITHUB_ACCESS_TOKEN@github.com/getto-systems/rubygems-getto-repository-sequel.git
git tag $(cat .release-version)
git push super HEAD:master --tags
git push backup HEAD:master --tags
