#!/bin/bash
set -euo pipefail

# This script rewrites git history to:
# 1. Remove sensitive information (absolute paths, computer-specific info)
# 2. Update commit author to 313861498+pwin32@users.noreply.github.com
# 3. Preserve upstream nginx commits with exact hashes

NEW_AUTHOR_EMAIL="313861498+pwin32@users.noreply.github.com"
NEW_AUTHOR_NAME="pwin32"

# Backup current branch
echo "Creating backup branch 'backup-before-rewrite'..."
git branch -f backup-before-rewrite HEAD

# Use git filter-repo (recommended) or git filter-branch (fallback)
if command -v git-filter-repo &> /dev/null; then
    echo "Using git-filter-repo..."

    # Create mailmap for author rewriting
    cat > .mailmap-temp <<'EOF'
pwin32 <313861498+pwin32@users.noreply.github.com> Your Name <you@example.com>
EOF

    # Create path-based content filters
    git filter-repo --force \
        --mailmap .mailmap-temp \
        --replace-text <(cat <<'PATTERNS'
/mnt/d/msys64/usr/bin/bash.exe==>/usr/bin/bash
/mnt/d/bak/node-v22.16.0-win-x64/node.exe==>node.exe
Z:\\nginx-bench-tools\\win32-process-times.exe==>win32-process-times.exe
C:\\Windows\\System32\\wbem\\WMIC.exe==>wmic.exe
C:\\Windows\\System32\\netstat.exe==>netstat.exe
PATTERNS
)

    rm .mailmap-temp

else
    echo "git-filter-repo not found, using git filter-branch..."

    # Create filter script for content replacement
    cat > /tmp/filter-content.sh <<'FILTERSCRIPT'
#!/bin/bash

# Read file content
content=$(cat)

# Replace sensitive paths
content="${content//\/mnt\/d\/msys64\/usr\/bin\/bash.exe/\/usr\/bin\/bash}"
content="${content//\/mnt\/d\/bak\/node-v22.16.0-win-x64\/node.exe/node.exe}"
content="${content//Z:\\\\nginx-bench-tools\\\\win32-process-times.exe/win32-process-times.exe}"
content="${content//C:\\\\Windows\\\\System32\\\\wbem\\\\WMIC.exe/wmic.exe}"
content="${content//C:\\\\Windows\\\\System32\\\\netstat.exe/netstat.exe}"

# Output modified content
echo "$content"
FILTERSCRIPT

    chmod +x /tmp/filter-content.sh

    # Run filter-branch
    git filter-branch --force --env-filter '
        # Only rewrite commits by you@example.com
        if [ "$GIT_AUTHOR_EMAIL" = "you@example.com" ]; then
            export GIT_AUTHOR_NAME="'"$NEW_AUTHOR_NAME"'"
            export GIT_AUTHOR_EMAIL="'"$NEW_AUTHOR_EMAIL"'"
            export GIT_COMMITTER_NAME="'"$NEW_AUTHOR_NAME"'"
            export GIT_COMMITTER_EMAIL="'"$NEW_AUTHOR_EMAIL"'"
        fi
    ' --tree-filter '
        # Apply content filters to specific files
        for file in misc/*.js misc/*.sh docs/*.md AGENTS.md; do
            if [ -f "$file" ]; then
                /tmp/filter-content.sh < "$file" > "$file.tmp" && mv "$file.tmp" "$file"
            fi
        done
    ' --tag-name-filter cat -- --all

    rm /tmp/filter-content.sh
fi

echo ""
echo "History rewrite complete!"
echo ""
echo "Summary:"
echo "  - Updated author: $NEW_AUTHOR_EMAIL"
echo "  - Removed sensitive paths"
echo "  - Backup branch: backup-before-rewrite"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git log --all --oneline | head -50"
echo "  2. Check specific files: git show HEAD:misc/win32-process-cpu.js"
echo "  3. If satisfied, delete backup: git branch -D backup-before-rewrite"
echo "  4. Force push to new remote: git push --force --all"
echo ""
