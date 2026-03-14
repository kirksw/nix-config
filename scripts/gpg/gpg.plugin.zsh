function gpg_delete() {
  # List secret keys with full fingerprint and user info
  KEYS=$(gpg --list-secret-keys --with-colons --keyid-format LONG | awk -F: '
    $1 == "sec" {
      fpr = ""
      keyid = $5
    }
    $1 == "fpr" && fpr == "" {
      fpr = $10
    }
    $1 == "uid" {
      printf "%s | %s | %s\n", fpr, keyid, $10
    }')

  # Use fzf to select a key
  SELECTED=$(echo "$KEYS" | fzf --prompt="Select GPG key to delete: ")

  if [ -z "$SELECTED" ]; then
    echo "No key selected."
    exit 1
  fi

  # Extract fingerprint
  FPR=$(echo "$SELECTED" | cut -d' ' -f1)

  echo "You selected fingerprint: $FPR"
  read -r -p "Are you sure you want to delete this key (y/N)? " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 1
  fi

  # Must delete secret key first
  gpg --batch --yes --delete-secret-keys "$FPR"

  # Then delete public key
  gpg --batch --yes --delete-keys "$FPR"

  echo "GPG key $FPR deleted."
}
