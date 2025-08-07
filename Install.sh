#!/usr/bin/env bash
set -euo pipefail

print_info()   { echo -e "\033[1;34m[INFO]\033[0m $1"; }
print_error()  { echo -e "\033[1;31m[ERROR]\033[0m $1" >&2; }
is_installed() { command -v "$1" >/dev/null 2>&1; }
check_file_exists() { [[ -f "$1" ]] || { print_error "$1 not found in $SCRIPT_DIR!"; exit 1; }; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------
# Environment detection
# ------------------------------------------------
detect_environment() {
OS=$(uname)
ARCH=$(uname -m)

if [[ "$OS" == "Darwin" ]]; then
    CURRENT_SHELL="zsh"
    PROFILE="$HOME/.zshrc"
elif [[ "$OS" == "Linux" ]]; then
    CURRENT_SHELL=$(basename "$SHELL")
    if [[ "$CURRENT_SHELL" != "bash" && "$CURRENT_SHELL" != "zsh" ]]; then
        CURRENT_SHELL="bash"
    fi
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
version_lt() {
    # returns 0 (true) if $1 < $2 (using sort -V)
    [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}
# ------------------------------------------------
# System Packages installation
# ------------------------------------------------
install_system_packages() {
    local pkgs_file="$SCRIPT_DIR/System-packages.txt"
    local special_file="$SCRIPT_DIR/System-packages-special.txt"

    check_file_exists() {
        [[ -f "$1" ]] || { print_error "$1 not found!"; exit 1; }
    }
    check_file_exists "$pkgs_file"
    check_file_exists "$special_file"

    # Process system packages
    while read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        local tokens=($line)
        local pkg_os=${tokens[0]}
        # Collect archs
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
                                if ! dpkg -s "$pkg" &>/dev/null; then
                                    print_info "Installing system package $pkg..."
                                    $SUDO apt-get install -y "$pkg"
                                else
                                    print_info "Package $pkg already installed."
                                fi
                                ;;
                            Darwin)
                                if ! brew list "$pkg" &>/dev/null; then
                                    print_info "Installing brew package $pkg..."
                                    brew install "$pkg"
                                else
                                    print_info "Package $pkg already installed."
                                fi
                                ;;
                        esac
                    done
                fi
            done
        fi
    done < "$pkgs_file"

    # Process special packages
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
                    if ! command -v "$pkg" &>/dev/null; then
                        print_info "Installing special package $pkg ..."
                        eval "$cmd"
                    else
                        print_info "Special package $pkg already installed."
                    fi
                fi
            done
        fi
    done < "$special_file"
}

# ------------------------------------------------
# Upgrade Python setuptools
# ------------------------------------------------
upgrade_setuptools() {
    case "$OS" in
        Linux)
            python3 -m pip install --upgrade setuptools --break-system-packages || true
            ;;
    esac
}
# ------------------------------------------------
# uro installation
# ------------------------------------------------
install_uro() {
    case "$OS" in
        Darwin)  
            if ! is_installed uro; then
                pipx install uro
            else
                print_info "uro is already installed."
            fi
            ;;
        Linux)
            if ! is_installed uro; then
                pipx install uro
            else
                print_info "uro is already installed."
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS. Please install pipx and uro manually."
            exit 1
            ;;
    esac
    pipx ensurepath || true
}

# ------------------------------------------------
# Go installation with version check and OS logic
# ------------------------------------------------
find_latest_go_release() {
    # Only attempt on Linux, else exit early
    local os_name
    os_name=$(uname -s)
    if [[ "$os_name" != "Linux" ]]; then
        print_error "Go install only supported on Linux. Detected OS: $os_name"
        exit 1
    fi

    local release_list="https://go.dev/dl/"
    local fetch_cmd=""

    if has_cmd wget; then
        fetch_cmd="wget --connect-timeout=5 -qO-"
    elif has_cmd curl; then
        fetch_cmd="curl --connect-timeout 5 -sL"
    else
        print_error "Neither wget nor curl installed. Cannot fetch latest Go version."
        exit 1
    fi

    # Prefer JSON API with jq if possible
    if has_cmd jq; then
        $fetch_cmd "${release_list}?mode=json" | jq -r '.[].version' | \
        grep -v -E '(beta|rc)' | \
        grep -E '^go[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^go//' | sort -V | tail -n1
    else
        # Fallback HTML parsing: match only 3-part versions i.e. major.minor.patch
        $fetch_cmd "$release_list" | \
        grep -oE 'go[0-9]+\.[0-9]+\.[0-9]+' | \
        grep -v -E '(beta|rc)' | sed 's/^go//' | sort -V | tail -n1
    fi
}


install_go() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        print_info "Go install is only for Linux. Detected OS: $(uname -s). Skipping."
        return
    fi

    local current_version=""
    if command -v go &>/dev/null; then
        current_version=$(go version | awk '{print $3}' | sed 's/go//')
        print_info "Found installed Go version: $current_version"
    else
        print_info "No Go installation found."
    fi

    local latest_version
    latest_version=$(find_latest_go_release)

    if [[ -z "$latest_version" ]]; then
        print_error "Could not detect latest Go version."
        exit 1
    fi

    print_info "Latest Go version available: $latest_version"

    if [[ -n "$current_version" ]] && ! version_lt "$current_version" "$latest_version"; then
        print_info "Installed Go version ($current_version) is up-to-date."
        return
    fi

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    local go_tar="go${latest_version}.linux-${arch}.tar.gz"
    local go_url="https://go.dev/dl/${go_tar}"
    local tmp_tar="/tmp/${go_tar}"

    print_info "Downloading $go_url"
    if command -v curl &>/dev/null; then
        curl -sSL -o "$tmp_tar" "$go_url" || { print_error "curl download failed"; exit 1; }
    else
        wget -q -O "$tmp_tar" "$go_url" || { print_error "wget download failed"; exit 1; }
    fi

    print_info "Removing previous Go installation from /usr/local/go"
    sudo rm -rf /usr/local/go

    print_info "Extracting $tmp_tar to /usr/local"
    sudo tar -xzf "$tmp_tar" -C /usr/local || { print_error "Extraction failed"; exit 1; }

    # Update PATH (temporary, user should update their profile)
    add_path_if_missing "/usr/local/go/bin"
    add_path_if_missing "$HOME/go/bin"
    add_path_if_missing "$HOME/.local/bin"
    print_info "Go $latest_version installed. Please add /usr/local/go/bin to PATH permanently."
}

# Helper to compare semantic versions (returns true if $1 < $2)
version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}


# ------------------------------------------------
# Utility functions
# ------------------------------------------------
add_path_if_missing() {
    local path_entry="$1"
    # Escape slashes and square brackets for grep
    local escaped_path=$(printf '%s\n' "$path_entry" | sed -e 's/[][\\/^$.*]/\\&/g')
    if ! grep -Eq "(^|:)$escaped_path(:|\$)" <<< "$PATH"; then
        # Also add to profile if not present
        if ! grep -qxF "export PATH=\"\$PATH:$path_entry\"" >> "$PROFILE"; then
            echo "export PATH=\"\$PATH:$path_entry\"" >> "$PROFILE"
            print_info "Added $path_entry to PATH in $PROFILE"
        fi
        export PATH="$PATH:$path_entry"
    else
        print_info "Path $path_entry already in PATH"
    fi
}
# ------------------------------------------------
# Install Go tools from Go-tools.txt
# ------------------------------------------------
install_go_tools() {
    local gotools_file="$SCRIPT_DIR/Go-tools.txt"
    check_file_exists "$gotools_file"

    while read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        local name="${line%% *}"
        local url="${line#* }"
        [[ -z "$url" ]] && continue
        if [[ -x "$HOME/go/bin/$name" ]] || is_installed "$name"; then
            print_info "$name is already installed, skipping."
        else
            print_info "Installing Go tool $name ..."
            go install -v "$url"
        fi
    done < "$gotools_file"
}
# ------------------------------------------------
# Clone repositories helper
# ------------------------------------------------
clone_repos() {
    local file="$1"
    check_file_exists "$file"

    while IFS='|' read -r dir url; do
        [[ -z "$dir" || -z "$url" ]] && continue
        if [[ -d "$INSTALL_HOME/$dir" ]]; then
            print_info "$dir already cloned, skipping."
        else
            print_info "Cloning $dir from $url ..."
            git clone "$url" "$INSTALL_HOME/$dir"
        fi
    done < "$file"
}
# ------------------------------------------------
# Setup .gau.toml file
# ------------------------------------------------
setup_gau_toml() {
    local gau_toml="$INSTALL_HOME/.gau.toml"
    if [[ -f "$gau_toml" ]]; then
        print_info ".gau.toml already exists, skipping."
        return
    fi
    cat > "$gau_toml" <<-'EOF'
threads = 2
verbose = false
retries = 15
subdomains = false
parameters = false
providers = ["wayback","commoncrawl","otx","urlscan"]
blacklist = ["ttf","woff","svg","png","jpg"]
json = false

[urlscan]
apikey = ""

[filters]
from = ""
to = ""
matchstatuscodes = []
matchmimetypes = []
filterstatuscodes = []
filtermimetypes = ["image/png", "image/jpg", "image/svg+xml"]
EOF
    print_info ".gau.toml created."
}

# ------------------------------------------------
# Setup gf patterns and completions
# ------------------------------------------------
setup_gf() {
    local GOPATH
    GOPATH=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
    local gf_mod_dir
    gf_mod_dir=$(find "$GOPATH/pkg/mod/github.com/tomnomnom/gf@"* -maxdepth 0 2>/dev/null | head -n 1 || true)
    if [[ -z "$gf_mod_dir" ]]; then
        print_error "Could not find gf module directory in Go mod cache."
        return
    fi

    local completion_file
    if [[ "$CURRENT_SHELL" == "zsh" ]]; then
        completion_file="gf-completion.zsh"
    else
        completion_file="gf-completion.bash"
    fi

    local completion_path="$gf_mod_dir/$completion_file"
    if [[ -f "$completion_path" ]]; then
        local completion_line="source $completion_path"
        if ! grep -qxF "$completion_line" "$PROFILE"; then
            echo "$completion_line" >> "$PROFILE"
            print_info "Added gf completion ($completion_file) to $PROFILE"
        else
            print_info "gf completion already added in $PROFILE"
        fi
    else
        print_error "Could not find $completion_file in $gf_mod_dir"
    fi

    mkdir -p "$HOME/.gf"
    cp -r "$gf_mod_dir/examples/." "$HOME/.gf/" 2>/dev/null || true
    print_info "Copied gf example patterns to ~/.gf"

    if [[ -d "$HOME/GFpattren" ]]; then
        find "$HOME/GFpattren" -type f -name '*.json' -exec mv -f {} "$HOME/.gf/" \;
        print_info "Moved GFpattren JSON files to ~/.gf"
    fi
}

# ------------------------------------------------
# Setup dynamic tools (install python reqs, run setup scripts)
# ------------------------------------------------
setup_tool_dynamic() {
    local tool_dir="$1"
    local marker=".setup_done"
    local py3="python3"
    local shell_bin="bash"
    local setup_suffix=""
    [[ "$OS" == "Linux" || "$OS" == "Darwin" ]] && setup_suffix="--break-system-packages"

    local tool_path="$INSTALL_HOME/$tool_dir"
    if [[ -d "$tool_path" && ! -f "$tool_path/$marker" ]]; then
        print_info "Setting up $tool_dir ..."
        pushd "$tool_path" > /dev/null

        # Install Python requirements if any
        for req in requirements*.txt; do
            [[ -f "$req" ]] || continue
            print_info "Installing Python requirements from $req"
            $py3 -m pip install -r "$req" $setup_suffix
        done

        # Run any setup.sh scripts
        for setup_script in setup.sh; do
            [[ -f "$setup_script" ]] || continue
            print_info "Running setup script $setup_script"
            chmod +x "$setup_script"
            $shell_bin "$setup_script"
        done

        # If setup.py exists, install
        if [[ -f setup.py ]]; then
            print_info "Installing Python package via setup.py"
            $py3 -m pip install . $setup_suffix
        fi

        touch "$marker"
        popd > /dev/null
    else
        print_info "$tool_dir already set up or missing, skipping."
    fi
}

setup_all_tools_dynamic() {
    local tools_file="$SCRIPT_DIR/Tools.txt"
    check_file_exists "$tools_file"
    while IFS='|' read -r tool _; do
        [[ -z "$tool" || "$tool" =~ ^# ]] && continue
        setup_tool_dynamic "$tool"
    done < "$tools_file"
}

# ------------------------------------------------
# Create convenient aliases for tools
# ------------------------------------------------
create_aliases() {
    local tools_file="$SCRIPT_DIR/Tools.txt"
    check_file_exists "$tools_file"
    while IFS='|' read -r tool _; do
        [[ -z "$tool" || "$tool" =~ ^# ]] && continue
        local dir="$INSTALL_HOME/$tool"
        local tool_lower
        tool_lower=$(echo "$tool" | tr '[:upper:]' '[:lower:]')
        local tool_cap
        tool_cap=$(echo "$tool" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
        local main_script
        main_script=$(find "$dir" -maxdepth 1 -type f \( -iname "$tool_lower.py" -o -iname "$tool_cap.py" -o -iname "$tool_lower.sh" -o -iname "$tool_cap.sh" \) | head -n 1 || true)
        if [[ -n "$main_script" ]]; then
            chmod +x "$main_script"
            local alias_line=""
            if [[ "$main_script" == *.py ]]; then
                alias_line="alias $tool='python3 \"$main_script\"'"
            elif [[ "$main_script" == *.sh ]]; then
                alias_line="alias $tool='bash \"$main_script\"'"
            fi
            if ! grep -qF "$alias_line" "$PROFILE"; then
                echo "$alias_line" >> "$PROFILE"
                print_info "Added alias for $tool in $PROFILE"
            else
                print_info "Alias for $tool already present in $PROFILE"
            fi
        else
            print_info "No main .py or .sh script found for $tool, skipping alias creation."
        fi
    done < "$tools_file"
}

# ------------------------------------------------
# Main script flow
# ------------------------------------------------

main() {
    detect_environment
    upgrade_setuptools
    install_system_packages
    install_uro
    install_go
    install_go_tools
    setup_gau_toml
    setup_gf
    clone_repos "$SCRIPT_DIR/Tools.txt"
    setup_all_tools_dynamic
    create_aliases
    clone_repos "$SCRIPT_DIR/Wordlists.txt"
    print_info "=================================================================="
    print_info "All tools and dependencies have been installed and set up."
    print_info "Reload your shell profile to apply changes (e.g., run 'source $PROFILE' or open a new terminal)."
    print_info "You can now use the new tools and aliases."
    print_info "=================================================================="
    
}
main "$@"
