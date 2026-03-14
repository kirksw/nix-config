# lunar: rebuild_aws_config lunarway https://d-c3672deb5f.awsapps.com/start eu-north-1

ensure_tooling() {
  # Ensure jq is installed
  if ! command -v jq &>/dev/null; then
    echo "❌ jq is not installed. Please install jq to proceed."
    return 1
  fi
  
  # Ensure aws-cli is installed
  if ! command -v aws &>/dev/null; then
    echo "❌ aws cli is not installed. Please install aws cli to proceed."
    return 1
  fi

  # Ensure aws-cli v2 is installed
  aws_major=$(aws --version 2>&1 \
  | sed -nE 's#^aws-cli/([0-9]+)\..*#\1#p')

  if [[ $aws_major -ne 2 ]]; then
    echo "❌ AWS CLI v2 is required (found v$aws_major)"
    return 1
  fi
}

rebuild_aws_config() {
  local SSO_SESSION_NAME=$1
  local SSO_START_URL=$2
  local SSO_REGION=$3
  local CONFIG_FILE="$HOME/.aws/config"
  local TMP_CONFIG="$CONFIG_FILE.generated"
  local PROFILE_PREFIX="aws-sso"

  ensure_tooling || return 1
  rm "$TMP_CONFIG"

  echo "🔐 Logging in to AWS Identity Center (SSO session: $SSO_SESSION_NAME)..."
  aws sso login --sso-session "$SSO_SESSION_NAME"
  if [ $? -ne 0 ]; then
    echo "❌ SSO login failed"
    return 1
  fi

  echo "🔍 Extracting access token from AWS CLI SSO cache..."
  local TOKEN=$(jq -r '.accessToken' ~/.aws/sso/cache/*.json | tail -n 1)

  if [ -z "$TOKEN" ]; then
    echo "❌ Failed to extract access token. Make sure 'jq' is installed and you've logged in."
    return 1
  fi

  echo "📦 Fetching AWS session details..."
  echo "[sso-session $SSO_SESSION_NAME]" >>"$TMP_CONFIG"
  echo "sso_start_url = $SSO_START_URL" >>"$TMP_CONFIG"
  echo "sso_region = $SSO_REGION" >>"$TMP_CONFIG"
  echo "sso_registration_scopes = sso:account:access" >>"$TMP_CONFIG"
  echo "" >>"$TMP_CONFIG"

  echo "✅ Imported sso-session: $SSO_SESSION_NAME"

  echo "📦 Fetching AWS accounts you have access to..."
  local accounts=$(aws sso list-accounts --access-token "$TOKEN" --region "$SSO_REGION")
  local account_ids=$(echo "$accounts" | jq -r '.accountList[].accountId')

  for account_id in $account_ids; do
    local account_name=$(echo "$accounts" | jq -r ".accountList[] | select(.accountId==\"$account_id\") | .accountName")
    local roles=$(aws sso list-account-roles --access-token "$TOKEN" --account-id "$account_id" --region "$SSO_REGION")

    for role_name in $(echo "$roles" | jq -r '.roleList[].roleName'); do
      local profile_name=$(echo "$PROFILE_PREFIX-$account_name-$role_name" | sed 's/[[:space:]]//g' | tr -d '[:blank:]')

      echo "[profile $profile_name]" >>"$TMP_CONFIG"
      echo "sso_session = $SSO_SESSION_NAME" >>"$TMP_CONFIG"
      echo "sso_account_id = $account_id" >>"$TMP_CONFIG"
      echo "sso_role_name = $role_name" >>"$TMP_CONFIG"
      echo "region = eu-west-1" >>"$TMP_CONFIG"
      echo "output = json" >>"$TMP_CONFIG"
      echo "" >>"$TMP_CONFIG"

      echo "✅ Imported profile: $profile_name"
    done
  done

  # TODO: handle in a more dynamic way
  echo "[profile lw-data-prod-dbt]" >>"$TMP_CONFIG"
  echo "role_arn = arn:aws:iam::478824949770:role/hubble-rbac/DbtDeveloper" >>"$TMP_CONFIG"
  echo "source_profile = aws-sso-LunarWay-Production-Data-OktaDataLogin" >>"$TMP_CONFIG"
  echo "region = eu-west-1" >>"$TMP_CONFIG"
  echo "output = json" >>"$TMP_CONFIG"

  echo "[profile lw-data-dev-dbt]" >>"$TMP_CONFIG"
  echo "role_arn = arn:aws:iam::899945594626:role/hubble-rbac/DbtDeveloper" >>"$TMP_CONFIG"
  echo "source_profile = aws-sso-LunarWay-Development-Data-OktaDataLogin" >>"$TMP_CONFIG"
  echo "region = eu-west-1" >>"$TMP_CONFIG"
  echo "output = json" >>"$TMP_CONFIG"

  cat "$TMP_CONFIG"
  echo "🔧 Updating AWS config at $CONFIG_FILE..."
  cat "$TMP_CONFIG" >"$CONFIG_FILE"
  echo "✅ All profiles generated and appended to $CONFIG_FILE"
}

aws_fzf_profile() {
  local profile

  ensure_tooling || return 1

  profile=$(aws configure list-profiles \
    | fzf --height 40% --reverse --prompt="AWS Profile> ")

  if [[ -z "$profile" ]]; then
    echo "❌ No profile selected."
    return 1
  fi

  export AWS_PROFILE=$profile
  echo "→ AWS_PROFILE set to '$AWS_PROFILE'"

  if is_aws_sso_valid; then
    echo "✅ SSO token is still valid"
  else
    echo "❌ SSO token expired (or not found)"
    if aws sso login --sso-session lunarway; then
      echo "✅ aws sso login successful"
    else
      echo "❌ aws sso login failed"
      return 1
    fi
  fi
}

# Unfortunately if we just run `aws sso login` it will open browser and refresh tokens all the time.
is_aws_sso_valid() {
  local cache_file exp now_sec exp_sec

  ensure_tooling || return 1

  cache_file=$(ls -1t ~/.aws/sso/cache/*.json 2>/dev/null | head -n1) \
    || return 1

  exp=$(jq -r '.expiresAt // .Credentials.Expiration' "$cache_file") \
    || return 1

  exp_sec=$(date -d "$exp" '+%s' 2>/dev/null) \
    || return 1

  now_sec=$(date '+%s')

  (( now_sec < exp_sec ))
}

sso_valid_time() {
  local file expires expires_secs now_secs rem

  ensure_tooling || return 1

  file=$(ls -1t ~/.aws/sso/cache/*.json 2>/dev/null | head -n1) || return 1
  expires=$(jq -r '.expiresAt // .Credentials.Expiration' "$file") || return 1
  expires_secs=$(date -d "$expires" +%s) || return 1
  now_secs=$(date +%s) || return 1
  rem=$((expires_secs - now_secs)) || return 1

  printf '%02d:%02d:%02d\n' $((rem/3600)) $((rem%3600/60)) $((rem%60))
}
