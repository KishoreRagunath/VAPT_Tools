#!/usr/bin/env bash
set -euo pipefail

print_info()  { echo -e "\033[1;34m[INFO]\033[0m $1"; }
print_error() { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sed_inplace() {
    local expr="$1"
    local file="$2"
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$expr" "$file"
    else
        sed -i "$expr" "$file"
    fi
}

# Detect environment same as install.sh
detect_environment() {
    OS=$(uname)
    ARCH=$(uname -m)

    if [[ "$OS" == "Darwin" ]]; then
        OS="Darwin"  # match casing from install.sh case
        CURRENT_SHELL="zsh"
        PROFILE="$HOME/.zshrc"
    elif [[ "$OS" == "Linux" ]]; then
        CURRENT_SHELL=$(basename "$SHELL")
        [[ "$CURRENT_SHELL" =~ ^(bash|zsh)$ ]] || CURRENT_SHELL="bash"
        PROFILE="$HOME/.${CURRENT_SHELL}rc"
    else
        CURRENT_SHELL="bash"
        PROFILE="$HOME/.bashrc"
    fi

    [[ -f "$PROFILE" ]] || touch "$PROFILE"

    if [[ $EUID -eq 0 ]]; then
        SUDO=""
        INSTALL_HOME="/root"
    else
        SUDO="sudo"
        INSTALL_HOME="$HOME"
    fi

    print_info "Detected OS: $OS, Architecture: $ARCH"
    print_info "Shell: $CURRENT_SHELL, Profile file: $PROFILE"
    print_info "Install home directory: $INSTALL_HOME"
}

remove_system_packages() {
    local pkgs_file="$SCRIPT_DIR/System-packages.txt"
    local special_file="$SCRIPT_DIR/System-packages-special.txt"

    if [[ -f "$pkgs_file" ]]; then
        while read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            local tokens=($line)
            local pkg_os=${tokens[0]}
            # archs and pkgs parsing like install.sh
            local archs=()
            local pkgs=()
            for ((i=1; i < ${#tokens[@]}; i++)); do
                tok=${tokens[i]}
                if [[ "$tok" =~ ^(amd64|aarch64|arm64|x86_64)$ ]]; then
                    archs+=("$tok")
                else
                    pkgs=("${tokens[@]:i}")
                    break
                fi
            done
            if [[ "$OS" == "$pkg_os" ]]; then
                for arch in "${archs[@]}"; do
                    if [[ "$ARCH" == "$arch" ]]; then
                        for pkg in "${pkgs[@]}"; do
                            case "$OS" in
                                Linux)
                                    if dpkg -s "$pkg" &>/dev/null; then
                                        print_info "Removing system package $pkg..."
                                        $SUDO apt-get remove -y --purge "$pkg"
                                    else
                                        print_info "Package $pkg not installed, skipping."
                                    fi
                                    ;;
                                Darwin)
                                    if brew list "$pkg" &>/dev/null; then
                                        print_info "Uninstalling brew package $pkg ..."
                                        sudo brew uninstall --ignore-dependencies "$pkg"
                                    else
                                        print_info "Package $pkg not installed, skipping."
                                    fi
                                    ;;
                            esac
                        done
                    fi
                done
            fi
        done < "$pkgs_file"
    else
        print_info "$pkgs_file not found, skipping system packages removal."
    fi

    if [[ -f "$special_file" ]]; then
        while read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            local tokens=($line)
            local pkg_os=${tokens[0]}
            local archs=()
            local pkg=""
            local cmd=""
            local i=1
            for (( ; i < ${#tokens[@]}; i++ )); do
                tok=${tokens[i]}
                if [[ "$tok" =~ ^(amd64|aarch64|arm64|x86_64)$ ]]; then
                    archs+=("$tok")
                else
                    break
                fi
            done
            pkg=${tokens[i]}
            cmd="${tokens[@]:i+1}"
            if [[ "$OS" == "$pkg_os" ]]; then
                for arch in "${archs[@]}"; do
                    if [[ "$ARCH" == "$arch" ]]; then
                        if command -v "$pkg" &>/dev/null; then
                            print_info "Attempting to uninstall special package $pkg ..."
                            case "$pkg" in
                                searchsploit)
                                    [[ -d "$INSTALL_HOME/exploitdb" ]] && rm -rf "$INSTALL_HOME/exploitdb"
                                    rm -f /usr/local/bin/searchsploit
                                    if command -v snap &>/dev/null; then
                                        $SUDO snap remove searchsploit || true
                                    fi
                                    ;;
                                uro)
                                    if command -v pipx &>/dev/null; then
                                        pipx uninstall uro || true
                                    fi
                                    ;;
                                *)
                                    print_info "No uninstall instruction for $pkg, skipping."
                                    ;;
                            esac
                        else
                            print_info "Special package $pkg not installed, skipping."
                        fi
                    fi
                done
            fi
        done < "$special_file"
    else
        print_info "$special_file not found, skipping special packages removal."
    fi
}

remove_go() {
    if [[ "$OS" == "Linux" ]]; then
        print_info "Removing Go installation..."
        $SUDO rm -rf /usr/local/go 2>/dev/null || true
        rm -rf "$HOME/go" 2>/dev/null || true
    else
        print_info "Skipping Go removal on OS: $OS"
    fi

    # Remove Go-related paths from profile always
    local go_paths=(
        "/usr/local/go/bin"
        "$HOME/go/bin"
        "$HOME/.local/bin"
        "$HOME/Library/Python/3.9/bin"
    )
    for pattern in "${go_paths[@]}"; do
        sed_inplace "\|$pattern|d" "$PROFILE"
    done
}


remove_go_tools() {
    if [[ -d "$HOME/go/bin" ]]; then
        print_info "Removing Go tools binaries..."
        rm -rf "$HOME/go/bin/"* || true
    fi
}

remove_cloned_repos() {
    for file in "$SCRIPT_DIR/Tools.txt" "$SCRIPT_DIR/Wordlists.txt"; do
        [[ -f "$file" ]] || continue
        while IFS='|' read -r dir url; do
            [[ -z "$dir" || -z "$url" || "$dir" =~ ^# ]] && continue
            local target_dir="$INSTALL_HOME/$dir"
            if [[ -d "$target_dir" ]]; then
                print_info "Removing cloned directory $target_dir ..."
                rm -rf "$target_dir"
            else
                print_info "Directory $target_dir not found, skipping."
            fi
        done < "$file"
    done
}

remove_dotfiles() {
    local files=(
        "$HOME/.gf"
        "$HOME/.gau.toml"
        "$HOME/.zenmap"
    )
    for f in "${files[@]}"; do
        if [[ -e $f ]]; then
            print_info "Removing $f ..."
            sudo rm -rf "$f"
        else
            print_info "$f not found, skipping."
        fi
    done
}

cleanup_profile() {
    print_info "Cleaning up PATH additions and aliases from $PROFILE ..."

    local paths_to_remove=(
        "/usr/local/go/bin"
        "$HOME/go/bin"
        "$HOME/.local/bin"
    )
    for p in "${paths_to_remove[@]}"; do
        sed -i.bak "\|$p|d" "$PROFILE" 2>/dev/null || sed -i "\|$p|d" "$PROFILE"
    done

    # Remove aliases from Tools.txt
    if [[ -f "$SCRIPT_DIR/Tools.txt" ]]; then
        while IFS='|' read -r tool _; do
            [[ -z "$tool" || "$tool" =~ ^# ]] && continue
            sed -i.bak "/^alias $tool=/d" "$PROFILE" 2>/dev/null || sed -i "/^alias $tool=/d" "$PROFILE"
        done < "$SCRIPT_DIR/Tools.txt"
    fi

    # Remove gf shell completions lines
    sed -i.bak '/gf-completion\.bash/d' "$PROFILE" 2>/dev/null || sed -i '/gf-completion\.bash/d' "$PROFILE"
    sed -i.bak '/gf-completion\.zsh/d' "$PROFILE" 2>/dev/null || sed -i '/gf-completion\.zsh/d' "$PROFILE"

    print_info "Backup of profile saved as $PROFILE.bak"
    print_info "Please reload your shell or open a new terminal to apply changes."
}

main() {
    detect_environment
    print_info "Starting uninstall process..."
    remove_system_packages
    remove_go
    remove_go_tools
    remove_cloned_repos
    remove_dotfiles
    cleanup_profile
    print_info "Uninstallation completed."
}

main "$@"
