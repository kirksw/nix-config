# function hubble() {
#   local USER_EMAIL=$(aws sts get-caller-identity | jq -r '.UserId' | cut -d':' -f 2)
#   local IMAGE=quay.io/lunarway/hubble-cli
# 
#   if ! command -v docker &> /dev/null; then
#     echo "Docker is not installed. Please install Docker to use this command."
#     return 1
#   fi
# 
#   if [ -z "$USER_EMAIL" ]; then
#     echo "Could not retrieve AWS user email. Please ensure you have the AWS CLI configured."
#     return 1
#   fi
# 
#   docker run --rm -it \
#     --entrypoint "/scripts/entrypoint.sh" \
#     -e AWS_PROFILE="${AWS_PROFILE:-default}" \
#     -e USER_EMAIL=$USER_EMAIL \
#     -v ~/.aws:/root/.aws:ro \
#     $IMAGE "$@"
# 
#   # Note: sometimes you need to mount the current directory to access local files.
#   #--mount type=bind,source="$(pwd)",target=/app,readonly
# }
