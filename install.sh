#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${1:-$HOME/.local/bin}"

echo "Installing zellij-workspaces to $INSTALL_DIR"

# Create install directory if needed
mkdir -p "$INSTALL_DIR"

# Create Python venv and install dependencies
if [[ ! -d "$SCRIPT_DIR/.venv" ]]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$SCRIPT_DIR/.venv"
fi

echo "Installing Python dependencies..."
"$SCRIPT_DIR/.venv/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt"

# Create wrapper scripts that use the venv
cat > "$INSTALL_DIR/ws" << EOF
#!/bin/bash
export WS_DASHBOARD="$SCRIPT_DIR/.venv/bin/python $SCRIPT_DIR/ws-dashboard"
exec "$SCRIPT_DIR/ws" "\$@"
EOF
chmod +x "$INSTALL_DIR/ws"

cat > "$INSTALL_DIR/ws-dashboard" << EOF
#!/bin/bash
exec "$SCRIPT_DIR/.venv/bin/python" "$SCRIPT_DIR/ws-dashboard" "\$@"
EOF
chmod +x "$INSTALL_DIR/ws-dashboard"

echo "Done! Make sure $INSTALL_DIR is in your PATH."
echo ""
echo "Usage:"
echo "  ws new <name>        # Create a new workspace"
echo "  ws open <name>       # Open a workspace in Claude Code"
echo "  ws dashboard         # Show workspace status dashboard"
echo "  ws list              # List all workspaces"
echo "  ws --help            # Show all commands"
