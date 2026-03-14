{
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.zellij.enable = lib.mkEnableOption "enables zellij";
  };

  config = lib.mkIf config.homeModules.zellij.enable {
    programs.zellij = {
      enable = true;
      enableZshIntegration = false;
      attachExistingSession = false;
      exitShellOnExit = false;
      settings = {
        pane_frames = false;
        tab_bar = false;
        default_layout = "compact";
        theme = "rose-pine";
        default_shell = "zsh";
        ui = {
          pane_frames = {
            hide_session_name = true;
          };
        };
        show_startup_tips = false;
        show_release_notes = false;
      };

      extraConfig = ''
        keybinds {
          shared_except "locked" {
            bind "Ctrl h" {
              MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm" {
                name "move_focus_or_tab";
                payload "left";
                move_mod "ctrl";
                use_arrow_keys "false";
              };
            }

            bind "Ctrl j" {
              MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm" {
                name "move_focus";
                payload "down";
                move_mod "ctrl";
                use_arrow_keys "false";
              };
            }

            bind "Ctrl k" {
              MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm" {
                name "move_focus";
                payload "up";
                move_mod "ctrl";
                use_arrow_keys "false";
              };
            }

            bind "Ctrl l" {
              MessagePlugin "https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm" {
                name "move_focus_or_tab";
                payload "right";
                move_mod "ctrl";
                use_arrow_keys "false";
              };
            }
          }
        }

        themes {
          rose-pine {
            text_unselected {
              base 224 222 244
              background 33 32 46
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            text_selected {
              base 224 222 244
              background 64 61 82
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            ribbon_selected {
              base 33 32 46
              background 49 116 143
              emphasis_0 246 193 119
              emphasis_1 235 188 186
              emphasis_2 196 167 231
              emphasis_3 156 207 216
            }
            ribbon_unselected {
              base 25 23 36
              background 224 222 244
              emphasis_0 246 193 119
              emphasis_1 235 188 186
              emphasis_2 196 167 231
              emphasis_3 156 207 216
            }
            table_title {
              base 49 116 143
              background 0 0 0
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            table_cell_selected {
              base 224 222 244
              background 64 61 82
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            table_cell_unselected {
              base 224 222 244
              background 33 32 46
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            list_selected {
              base 224 222 244
              background 64 61 82
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            list_unselected {
              base 224 222 244
              background 33 32 46
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 49 116 143
              emphasis_3 196 167 231
            }
            frame_selected {
              base 49 116 143
              background 0 0 0
              emphasis_0 235 188 186
              emphasis_1 156 207 216
              emphasis_2 196 167 231
              emphasis_3 0 0 0
            }
            frame_highlight {
              base 235 188 186
              background 0 0 0
              emphasis_0 235 188 186
              emphasis_1 235 188 186
              emphasis_2 235 188 186
              emphasis_3 235 188 186
            }
            exit_code_success {
              base 49 116 143
              background 0 0 0
              emphasis_0 156 207 216
              emphasis_1 33 32 46
              emphasis_2 196 167 231
              emphasis_3 49 116 143
            }
            exit_code_error {
              base 235 111 146
              background 0 0 0
              emphasis_0 246 193 119
              emphasis_1 0 0 0
              emphasis_2 0 0 0
              emphasis_3 0 0 0
            }
            multiplayer_user_colors {
              player_1 196 167 231
              player_2 49 116 143
              player_3 235 188 186
              player_4 246 193 119
              player_5 156 207 216
              player_6 235 111 146
              player_7 0 0 0
              player_8 0 0 0
              player_9 0 0 0
              player_10 0 0 0
            }
          }
        }
      '';
    };
  };
}
