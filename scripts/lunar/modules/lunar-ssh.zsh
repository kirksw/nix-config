
function genssh() {
    GITHUB_SSH_KEY= "$(openssl rsa -in ~/.ssh/github |  base64 | tr -d '\n')";
}
