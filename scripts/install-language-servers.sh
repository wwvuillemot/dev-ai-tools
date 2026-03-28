#!/usr/bin/env bash
# install-language-servers.sh
# Scans project repos to detect languages in use, then presents an interactive
# menu to install the relevant Serena language servers.
#
# Usage: install-language-servers.sh [projects-root]
#   projects-root  defaults to ~/Projects

set -euo pipefail

PROJECTS_ROOT="${1:-$HOME/Projects}"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "  [·] $*"; }
ok()      { echo "  [✓] $*"; }
warn()    { echo "  [!] $*"; }
skip()    { echo "  [–] $*"; }
section() { echo; echo "── $* ──────────────────────────────────────────────"; }

detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then echo "macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl"
  else echo "linux"; fi
}
OS="$(detect_os)"

cmd_exists() { command -v "$1" &>/dev/null; }

# ── Language definitions ───────────────────────────────────────────────────────
# Format (pipe-separated):
#   KEY | LABEL | DETECT (space-sep globs/files) | CHECK_CMD | PREREQ | INSTALL_MAC | INSTALL_LINUX | NOTES
#
# DETECT globs are searched under PROJECTS_ROOT (find -name).
# CHECK_CMD: if this exits 0, server is considered installed.
# PREREQ: tool that must exist before we can install (empty = none beyond uv/npm).
# NOTES: shown to user if install is skipped or has caveats.

LANG_DEFS=(
  # KEY        | LABEL                       | DETECT GLOBS           | CHECK CMD                  | PREREQ  | INSTALL MAC                                                                     | INSTALL LINUX                                                                       | NOTES
  "go          | Go (gopls)                  | go.mod *.go             | gopls version              | go      | go install golang.org/x/tools/gopls@latest                                      | go install golang.org/x/tools/gopls@latest                                          | Requires Go SDK in PATH"
  "rust        | Rust (rust-analyzer)        | Cargo.toml *.rs         | rust-analyzer --version    | rustup  | rustup component add rust-analyzer                                              | rustup component add rust-analyzer                                                  | Requires rustup"
  "python      | Python — pyright            | *.py pyproject.toml requirements.txt | pyright --version  | uv      | uv tool install pyright                                                         | uv tool install pyright                                                             | Optional upgrade; pylsp is bundled"
  "typescript  | TypeScript / JavaScript     | tsconfig.json *.ts      | (bundled)                  |         | (bundled — no install needed)                                                   | (bundled — no install needed)                                                       | Bundled with Serena"
  "ruby        | Ruby (ruby-lsp)             | Gemfile *.rb            | ruby-lsp --version         | ruby    | gem install ruby-lsp                                                            | gem install ruby-lsp                                                                | Requires Ruby"
  "cpp         | C / C++ (clangd)            | CMakeLists.txt *.cpp *.cc *.c *.h | clangd --version  |         | brew install llvm                                                               | apt-get install -y clangd                                                           | Add compile_commands.json to project root for best results"
  "csharp      | C# / F# (.NET / Roslyn)     | *.csproj *.sln *.cs *.fsproj *.fs | dotnet --version  |         | brew install dotnet                                                             | wget https://dot.net/v1/dotnet-install.sh && bash dotnet-install.sh                | Requires .NET v10+"
  "java        | Java                        | pom.xml build.gradle *.java | (bundled)              |         | (bundled — no install needed)                                                   | (bundled — no install needed)                                                       | Bundled with Serena"
  "scala       | Scala (Metals)              | build.sbt *.scala       | metals --version           |         | brew install coursier && cs install metals                                      | curl -fL https://github.com/coursier/launchers/raw/master/cs-x86_64-pc-linux.gz | gzip -d > cs && chmod +x cs && ./cs install metals | Requires coursier (cs)"
  "kotlin      | Kotlin (kotlin-lsp)         | *.kt *.kts              | kotlin -version            | kotlin  | brew install kotlin                                                             | apt-get install -y kotlin                                                           | kotlin-lsp is pre-alpha; Kotlin must be installed"
  "haskell     | Haskell (HLS)               | stack.yaml *.cabal *.hs | haskell-language-server-wrapper --version | ghcup | ghcup install hls                                                             | ghcup install hls                                                                   | Requires ghcup"
  "elixir      | Elixir (auto-downloads)     | mix.exs *.ex *.exs      | elixir --version           | elixir  | (auto — Elixir must be installed)                                               | (auto — Elixir must be installed)                                                   | LS auto-downloads on first project activation"
  "erlang      | Erlang (erlang_ls)          | rebar.config *.erl      | erlang_ls --version        |         | brew install erlang-ls                                                          | apt-get install -y erlang-ls                                                        | Requires Erlang/OTP"
  "ocaml       | OCaml (ocaml-lsp-server)    | dune-project *.ml *.mli | ocamllsp --version         | opam    | opam install ocaml-lsp-server                                                   | opam install ocaml-lsp-server                                                       | Requires opam"
  "r           | R (languageserver)          | DESCRIPTION *.R *.r     | Rscript --version          | Rscript | Rscript -e 'install.packages(\"languageserver\", repos=\"https://cloud.r-project.org\")' | Rscript -e 'install.packages(\"languageserver\", repos=\"https://cloud.r-project.org\")' | Requires R"
  "fortran     | Fortran (fortls)            | *.f90 *.f95 *.f03 *.f08 | fortls --version           | uv      | uv tool install fortls                                                          | uv tool install fortls                                                              |"
  "nix         | Nix (nixd)                  | flake.nix *.nix         | nixd --version             |         | nix-env -iA nixpkgs.nixd                                                        | nix-env -iA nixpkgs.nixd                                                            | Requires Nix package manager"
  "zig         | Zig (ZLS)                   | *.zig build.zig         | zls --version              |         | brew install zls                                                                | snap install zls --classic                                                          | ZLS version must match Zig version"
  "php         | PHP (Intelephense — bundled) | composer.json *.php     | php --version              |         | (bundled — requires PHP in PATH)                                                | (bundled — requires PHP in PATH)                                                    | Bundled; set INTELEPHENSE_LICENSE_KEY for premium features"
  "ansible     | Ansible                     | playbooks tasks roles site.yml | ansible --version    | npm     | npm install -g @ansible/ansible-language-server                                 | npm install -g @ansible/ansible-language-server                                     | Requires Node.js / npm"
  "vue         | Vue (volar)                 | *.vue vite.config.ts vite.config.js | (npm check)   | npm     | npm install -g @vue/language-server                                             | npm install -g @vue/language-server                                                 | Requires Node.js v18+"
  "solidity    | Solidity                    | *.sol foundry.toml hardhat.config.js | (npm check)  | npm     | npm install -g @nomicfoundation/solidity-language-server                        | npm install -g @nomicfoundation/solidity-language-server                            | Requires Node.js / npm"
  "elm         | Elm                         | elm.json *.elm          | elm --version              | npm     | npm install -g elm                                                              | npm install -g elm                                                                  | Requires Node.js / npm"
  "lua         | Lua                         | *.lua                   | (bundled)                  |         | (bundled — no install needed)                                                   | (bundled — no install needed)                                                       | Bundled with Serena"
  "bash        | Bash / Shell                | *.sh                    | (bundled)                  |         | (bundled — no install needed)                                                   | (bundled — no install needed)                                                       | Bundled with Serena"
)

# ── Scan repos for detected languages ─────────────────────────────────────────
section "Scanning $PROJECTS_ROOT for languages"

declare -a DETECTED_KEYS

detect_language() {
  local key="$1"
  local globs="$2"

  for glob in $globs; do
    # Search up to depth 4, stop on first hit for speed
    if find "$PROJECTS_ROOT" \
        -maxdepth 5 \
        \( -path "*/node_modules/*" -o -path "*/.git/*" -o -path "*/.venv/*" \) -prune \
        -o -name "$glob" -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

for def in "${LANG_DEFS[@]}"; do
  IFS='|' read -r key label globs check prereq mac linux notes <<< "$def"
  key="${key// /}"
  globs="${globs#"${globs%%[![:space:]]*}"}"  # ltrim
  if detect_language "$key" "$globs"; then
    DETECTED_KEYS+=("$key")
    info "Detected: ${label// /  }"
  fi
done

echo
info "${#DETECTED_KEYS[@]} language(s) detected in $PROJECTS_ROOT"

# ── Interactive menu ───────────────────────────────────────────────────────────
section "Select language servers to install"

# Build display list — detected languages first, then rest
declare -a ALL_KEYS ALL_LABELS ALL_CHECKS ALL_PREREQS ALL_MAC ALL_LINUX ALL_NOTES ALL_DETECTED_FLAGS
declare -a ORDERED_DEFS

# Pass 1: detected
for def in "${LANG_DEFS[@]}"; do
  IFS='|' read -r key label globs check prereq mac linux notes <<< "$def"
  key="${key// /}"
  for dk in "${DETECTED_KEYS[@]:-}"; do
    if [[ "$dk" == "$key" ]]; then
      ORDERED_DEFS+=("DETECTED|||$def")
      break
    fi
  done
done
# Pass 2: not detected
for def in "${LANG_DEFS[@]}"; do
  IFS='|' read -r key label globs check prereq mac linux notes <<< "$def"
  key="${key// /}"
  found=false
  for dk in "${DETECTED_KEYS[@]:-}"; do
    [[ "$dk" == "$key" ]] && found=true && break
  done
  $found || ORDERED_DEFS+=("|||$def")
done

# Parse ordered list into arrays
i=0
for odef in "${ORDERED_DEFS[@]}"; do
  detected_flag="${odef%%|||*}"
  def="${odef#*|||}"
  IFS='|' read -r key label globs check prereq mac linux notes <<< "$def"
  key="${key// /}"; label="${label#"${label%%[![:space:]]*}"}"; label="${label%" "}";
  check="${check#"${check%%[![:space:]]*}"}"; check="${check%" "}"
  prereq="${prereq#"${prereq%%[![:space:]]*}"}"; prereq="${prereq%" "}"
  mac="${mac#"${mac%%[![:space:]]*}"}"; mac="${mac%" "}"
  linux="${linux#"${linux%%[![:space:]]*}"}"; linux="${linux%" "}"
  notes="${notes#"${notes%%[![:space:]]*}"}"; notes="${notes%" "}"

  ALL_KEYS[$i]="$key"
  ALL_LABELS[$i]="$label"
  ALL_CHECKS[$i]="$check"
  ALL_PREREQS[$i]="$prereq"
  ALL_MAC[$i]="$mac"
  ALL_LINUX[$i]="$linux"
  ALL_NOTES[$i]="$notes"
  ALL_DETECTED_FLAGS[$i]="${detected_flag:+yes}"
  ((i++)) || true
done

TOTAL=${#ALL_KEYS[@]}

# Check installed status
check_installed() {
  local check="$1"
  [[ "$check" == "(bundled"* ]] && return 0
  local cmd
  cmd="$(echo "$check" | awk '{print $1}')"
  cmd_exists "$cmd" && return 0 || return 1
}

# ── fzf path ──────────────────────────────────────────────────────────────────
if cmd_exists fzf; then
  # Build fzf input: one line per language
  FZF_INPUT=""
  for ((i=0; i<TOTAL; i++)); do
    key="${ALL_KEYS[$i]}"
    label="${ALL_LABELS[$i]}"
    det="${ALL_DETECTED_FLAGS[$i]:-}"
    check="${ALL_CHECKS[$i]}"
    notes="${ALL_NOTES[$i]}"

    marker="  "
    [[ -n "$det" ]] && marker="◆ "

    if check_installed "$check"; then
      status="[already installed]"
    elif [[ "$check" == "(bundled"* ]]; then
      status="[bundled]"
    else
      status=""
    fi

    note_str=""
    [[ -n "$notes" ]] && note_str="  — $notes"

    FZF_INPUT+=$(printf "%-2s %-30s %-20s%s\n" "$marker" "$label" "$status" "$note_str")
  done

  echo "  ◆ = detected in your repos"
  echo "  Tab = toggle · Ctrl-A = select all · Enter = confirm · Esc = skip"
  echo

  SELECTED_LINES=$(echo "$FZF_INPUT" | fzf \
    --multi \
    --ansi \
    --prompt="Language servers › " \
    --header="◆ detected in repos | Tab=toggle | Ctrl-A=all | Enter=install | Esc=skip" \
    --bind='ctrl-a:select-all,ctrl-d:deselect-all' \
    --layout=reverse \
    2>/dev/null) || true

  if [[ -z "$SELECTED_LINES" ]]; then
    echo; info "No languages selected — skipping language server installation."; echo
    exit 0
  fi

  # Map selected labels back to keys
  declare -a SELECTED_KEYS
  while IFS= read -r line; do
    label_part="$(echo "$line" | sed 's/^◆\|^  //' | awk '{$1=$1; print}' | cut -d' ' -f1-4 | sed 's/ *\[.*//' | sed 's/^ *//' | sed 's/ *$//')"
    for ((i=0; i<TOTAL; i++)); do
      l="${ALL_LABELS[$i]}"
      if [[ "$l" == *"$label_part"* ]] || [[ "$label_part" == *"${l%% *}"* ]]; then
        SELECTED_KEYS+=("${ALL_KEYS[$i]}")
        break
      fi
    done
  done <<< "$SELECTED_LINES"

# ── fallback: numbered checklist ──────────────────────────────────────────────
else
  echo "  (Install fzf for a better experience: brew install fzf)"
  echo
  printf "  %-4s %-3s %-30s %s\n" "Num" "Sel" "Language" "Status"
  printf "  %-4s %-3s %-30s %s\n" "───" "───" "────────────────────────────" "──────────────────"

  for ((i=0; i<TOTAL; i++)); do
    key="${ALL_KEYS[$i]}"
    label="${ALL_LABELS[$i]}"
    det="${ALL_DETECTED_FLAGS[$i]:-}"
    check="${ALL_CHECKS[$i]}"

    marker="[ ]"
    [[ -n "$det" ]] && marker="[◆]"

    if check_installed "$check"; then
      status="already installed"
    elif [[ "$check" == "(bundled"* ]]; then
      status="bundled"
    else
      status=""
    fi

    printf "  %-4s %-3s %-30s %s\n" "$((i+1))" "$marker" "$label" "$status"
  done

  echo
  echo "  ◆ = detected in your repos (pre-selected)"
  echo
  # Build default selection string from detected languages
  DEFAULT_SEL=""
  for ((i=0; i<TOTAL; i++)); do
    det="${ALL_DETECTED_FLAGS[$i]:-}"
    check="${ALL_CHECKS[$i]}"
    if [[ -n "$det" ]] && ! check_installed "$check"; then
      [[ -n "$DEFAULT_SEL" ]] && DEFAULT_SEL+=" "
      DEFAULT_SEL+="$((i+1))"
    fi
  done

  read -r -p "  Enter numbers to install (space-separated) [default: $DEFAULT_SEL] or Enter to accept, 'q' to skip: " USER_INPUT
  [[ "${USER_INPUT:-}" == "q" ]] && { echo; info "Skipping language server installation."; echo; exit 0; }
  [[ -z "$USER_INPUT" ]] && USER_INPUT="$DEFAULT_SEL"

  declare -a SELECTED_KEYS
  for num in $USER_INPUT; do
    idx=$((num - 1))
    if (( idx >= 0 && idx < TOTAL )); then
      SELECTED_KEYS+=("${ALL_KEYS[$idx]}")
    fi
  done
fi

# ── Install selected ───────────────────────────────────────────────────────────
if [[ ${#SELECTED_KEYS[@]:-0} -eq 0 ]]; then
  info "Nothing selected."; echo; exit 0
fi

section "Installing language servers"

for sel_key in "${SELECTED_KEYS[@]}"; do
  # Find index
  idx=-1
  for ((i=0; i<TOTAL; i++)); do
    [[ "${ALL_KEYS[$i]}" == "$sel_key" ]] && idx=$i && break
  done
  [[ $idx -eq -1 ]] && continue

  label="${ALL_LABELS[$idx]}"
  check="${ALL_CHECKS[$idx]}"
  prereq="${ALL_PREREQS[$idx]}"
  notes="${ALL_NOTES[$idx]}"
  [[ "$OS" == "macos" ]] && install_cmd="${ALL_MAC[$idx]}" || install_cmd="${ALL_LINUX[$idx]}"

  echo
  echo "  ▸ $label"

  # Bundled — nothing to do
  if [[ "$install_cmd" == "(bundled"* ]]; then
    skip "Bundled with Serena — no installation needed"
    [[ -n "$notes" ]] && info "$notes"
    continue
  fi

  # Auto-downloads
  if [[ "$install_cmd" == "(auto"* ]]; then
    skip "Auto-downloads on first use — $install_cmd"
    [[ -n "$notes" ]] && info "$notes"
    continue
  fi

  # Already installed
  if check_installed "$check"; then
    ok "Already installed"
    continue
  fi

  # Check prerequisite
  if [[ -n "$prereq" ]] && ! cmd_exists "$prereq"; then
    warn "Prerequisite not found: $prereq — skipping"
    [[ -n "$notes" ]] && info "$notes"
    continue
  fi

  # Run install
  info "Running: $install_cmd"
  if eval "$install_cmd"; then
    ok "Installed"
  else
    warn "Installation failed — check output above"
    [[ -n "$notes" ]] && info "$notes"
  fi
done

echo
section "Done"
echo "  Restart any open Claude Code / VS Code / Cursor sessions to activate new language servers."
echo
