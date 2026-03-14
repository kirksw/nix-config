#!/bin/bash

login() {
  rm -rf ~/.aws/cli/cache/*
  #rm -rf ~/.aws/sso/cache/*

  local SSO_SESSION_NAME=$1
  aws sso login --sso-session "$SSO_SESSION_NAME"
  export AWS_PROFILE=$(cat ~/.aws/config | grep profile | awk -F'[][]' '{print $2}' | sed 's/^profile //' | fzf --prompt "Choose AWS role:")
}

check_login() {
  aws sts get-caller-identity &>/dev/null
  EXIT_CODE=$? # captures exit code

  if [[ ! $EXIT_CODE == 0 ]]; then
    login "lunarway"
  fi
}

assume_aws_role() {
  check_login
  export AWS_PROFILE=$(cat ~/.aws/config | grep profile | awk -F'[][]' '{print $2}' | sed 's/^profile //' | fzf --prompt "Choose AWS role:")
  echo "Assumed role: $AWS_PROFILE"
}

assume_aws_role
