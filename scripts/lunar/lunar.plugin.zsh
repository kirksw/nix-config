#!/usr/bin/env zsh
# Determine this file’s directory at runtime
typeset plugin_file=${(%):-%x}
typeset plugin_dir=${plugin_file:h}

# Source every module under modules/
typeset modules_dir=$plugin_dir/modules
[[ -d $modules_dir ]] || return 0

for mod in $modules_dir/*.zsh; do
  [[ -r $mod ]] || continue
  source $mod
done
