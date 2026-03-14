{
  pkgs,
  lib,
  config,
  self,
  ...
}:

{
  options = {
    homeModules.tmux.enable = lib.mkEnableOption "enables tmux";
  };

  config = lib.mkIf config.homeModules.tmux.enable {
    home = {
      packages = with pkgs; [
        gitmux
      ];

      file.".config/gitmux/gitmux.conf".source = "${self}/config/gitmux/gitmux.conf";
    };

    programs.tmux = {
      enable = true;

      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "tmux-256color";
      prefix = "C-a";
      keyMode = "vi";
      mouse = true;
      baseIndex = 1;

      resizeAmount = 5;
      disableConfirmationPrompt = true;
      focusEvents = true;
      escapeTime = 10;
      clock24 = true;

      plugins = with pkgs; [
        tmuxPlugins.vim-tmux-navigator
        tmuxPlugins.tmux-fzf
        tmuxPlugins.better-mouse-mode
        tmuxPlugins.battery
        tmuxPlugins.cpu
      ];

      extraConfig = ''
        set -g @rose_pine_variant 'main' # Options are 'main', 'moon' or 'dawn'

        set -g @rose_pine_host 'on'
        set -g @rose_pine_hostname_short 'on'
        set -g @rose_pine_user 'on'
        set -g @rose_pine_directory 'on' # Turn on the current folder component in the status bar
        set -g @rose_pine_bar_bg_disable 'on' # Disables background color, for transparent terminal emulators
        set -g @rose_pine_bar_bg_disabled_color_option 'default'

        set -g @rose_pine_only_windows 'off' # Leaves only the window module, for max focus and space
        set -g @rose_pine_disable_active_window_menu 'on' # Disables the menu that shows the active window on the left

        set -g @rose_pine_default_window_behavior 'on' # Forces tmux default window list behaviour
        set -g @rose_pine_show_current_program 'on' # Forces tmux to show the current running program as window name
        set -g @rose_pine_show_pane_directory 'on' # Forces tmux to show the current directory as window name

        # Cleanup
        set -g @rose_pine_user 'off'
        set -g @rose_pine_host 'off'
        set -g @rose_pine_hostname_short 'off'
        # NOTE: maybe remove the below
        set -g @rose_pine_window_tabs_enabled 'on'

        # Example values for these can be:
        set -g @rose_pine_left_separator ' > ' # The strings to use as separators are 1-space padded
        set -g @rose_pine_right_separator ' < ' # Accepts both normal chars & nerdfont icons
        set -g @rose_pine_field_separator ' | ' # Again, 1-space padding, it updates with prefix + I
        set -g @rose_pine_window_separator ' - ' # Replaces the default `:` between the window number and name

        # These are not padded
        set -g @rose_pine_session_icon '' # Changes the default icon to the left of the session name
        set -g @rose_pine_current_window_icon '' # Changes the default icon to the left of the active window name
        set -g @rose_pine_folder_icon '' # Changes the default icon to the left of the current directory folder
        set -g @rose_pine_username_icon '' # Changes the default icon to the right of the hostname
        set -g @rose_pine_hostname_icon '󰒋' # Changes the default icon to the right of the hostname
        set -g @rose_pine_date_time_icon '󰃰' # Changes the default icon to the right of the date module
        set -g @rose_pine_window_status_separator "  " # Changes the default icon that appears between window names

        # Very beta and specific opt-in settings, tested on v3.2a, look at issue #10
        set -g @rose_pine_prioritize_windows 'off' # Keep right-side sections stable across initial load/reload
        set -g @rose_pine_width_to_hide '80' # Specify a terminal width to toggle off most of the right side functionality
        set -g @rose_pine_window_count '5' # Specify a number of windows, if there are more than the number, do the same as width_to_hide

        # combining tmux and nvim status lines
        set -g status-style bg=default

        # pane management binds
        unbind %
        bind | split-window -h
        unbind '"'
        bind - split-window -v
        #
        # keybinds for pane resizing
        bind -r j resize-pane -D 5
        bind -r k resize-pane -U 5
        bind -r l resize-pane -R 5
        bind -r h resize-pane -L 5
        bind -r m resize-pane -Z

        # copy mode binds
        bind -T copy-mode-vi v send-keys -X begin-selection # start selection with "v"
        bind -T copy-mode-vi y send-keys -X copy-selection  # copy text with "y"
        unbind -T copy-mode-vi MouseDragEnd2Pane

        # clear screen
        bind C-l send-keys 'C-l'

        # pass ctrl+? by doing Ctrl+a ?
        bind-key a send-prefix
        bind-key l send-prefix

        # binds
        set -g set-clipboard on
        set -g allow-passthrough on
        set -g detach-on-destroy off
        bind -T copy-mode-vi Enter send-keys -X copy-selection-and-cancel

        # ezgit bind
        bind-key g display-popup -E -w 80% -h 70% 'ezgit'

        # ensure can handle commands
        set -g extended-keys always
        set -as terminal-features 'xterm*:extkeys'

        # Clear stale plugin append state from older configs to avoid duplicate git segment.
        set -gu @rose_pine_status_right_append_section

        # Load rose-pine after theme options so first startup matches reload behavior.
        run-shell ${pkgs.tmuxPlugins.rose-pine}/share/tmux-plugins/rose-pine/rose-pine.tmux
        # Keep git branch visible even if rose-pine rewrites/trims status-right.
        set -ag status-right '#[fg=#9ccfd8]  #(git -C "#{pane_current_path}" rev-parse --abbrev-ref HEAD 2>/dev/null)'

        # reload config
        bind r run-shell "tmux source-file ~/.config/tmux/tmux.conf && tmux display-message 'Config reloaded'"
      '';
    };
  };
}
