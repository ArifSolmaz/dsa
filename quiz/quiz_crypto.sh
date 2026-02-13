#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Quiz Encrypt/Decrypt Tool
#  Encrypts quiz notebooks before pushing to GitHub
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#  Usage:
#    ./quiz_crypto.sh encrypt              # Encrypt all quizzes
#    ./quiz_crypto.sh encrypt 01           # Encrypt specific week
#    ./quiz_crypto.sh decrypt 01           # Decrypt specific week (for testing)
#    ./quiz_crypto.sh decrypt-all          # Decrypt all (for testing)
#    ./quiz_crypto.sh status               # Show what's encrypted/published
#
#  First time: set your key
#    export QUIZ_KEY="your-secret-key-here"
#    or create a .quiz_key file (git-ignored)
#

set -e

QUIZ_DIR="quiz"
ENC_DIR="quiz/encrypted"
DRAFTS_DIR="quiz/drafts"   # Optional: keep plaintext drafts here (git-ignored)

# Load key
if [ -f ".quiz_key" ]; then
    QUIZ_KEY=$(cat .quiz_key)
elif [ -z "$QUIZ_KEY" ]; then
    echo "❌ No encryption key found!"
    echo "   Set QUIZ_KEY env variable or create .quiz_key file"
    exit 1
fi

encrypt_file() {
    local week=$1
    local src="${QUIZ_DIR}/drafts/Quiz_Week_${week}.ipynb"
    
    # Also check root quiz dir
    if [ ! -f "$src" ]; then
        src="${QUIZ_DIR}/Quiz_Week_${week}.ipynb"
    fi
    
    if [ ! -f "$src" ]; then
        echo "  ⚠️  Week ${week}: source not found (checked drafts/ and quiz/)"
        return 1
    fi
    
    local dst="${ENC_DIR}/Quiz_Week_${week}.ipynb.enc"
    mkdir -p "$ENC_DIR"
    
    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
        -in "$src" \
        -out "$dst" \
        -pass pass:"$QUIZ_KEY"
    
    local size=$(wc -c < "$dst")
    echo "  ✅ Week ${week}: encrypted (${size} bytes)"
}

decrypt_file() {
    local week=$1
    local src="${ENC_DIR}/Quiz_Week_${week}.ipynb.enc"
    
    if [ ! -f "$src" ]; then
        echo "  ⚠️  Week ${week}: encrypted file not found"
        return 1
    fi
    
    local dst="${DRAFTS_DIR}/Quiz_Week_${week}_decrypted.ipynb"
    mkdir -p "$DRAFTS_DIR"
    
    openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 \
        -in "$src" \
        -out "$dst" \
        -pass pass:"$QUIZ_KEY"
    
    echo "  ✅ Week ${week}: decrypted → ${dst}"
}

show_status() {
    echo ""
    echo "Quiz Status"
    echo "═══════════════════════════════════════════"
    printf "  %-8s %-12s %-12s %-12s\n" "Week" "Draft" "Encrypted" "Published"
    echo "  ─────── ──────────── ──────────── ────────────"
    
    for i in $(seq -w 1 13); do
        local draft="—"
        local enc="—"
        local pub="—"
        
        [ -f "${QUIZ_DIR}/drafts/Quiz_Week_${i}.ipynb" ] && draft="✅"
        [ -f "${ENC_DIR}/Quiz_Week_${i}.ipynb.enc" ] && enc="🔒"
        [ -f "${QUIZ_DIR}/Quiz_Week_${i}.ipynb" ] && pub="📝"
        
        printf "  %-8s %-12s %-12s %-12s\n" "$i" "$draft" "$enc" "$pub"
    done
    echo ""
}

case "${1:-}" in
    encrypt)
        if [ -n "${2:-}" ]; then
            WEEK=$(printf "%02d" "$2")
            echo "Encrypting Week ${WEEK}..."
            encrypt_file "$WEEK"
        else
            echo "Encrypting all quizzes..."
            for i in $(seq -w 1 13); do
                encrypt_file "$i" || true
            done
        fi
        echo ""
        echo "Done! Now: git add quiz/encrypted/ && git commit && git push"
        ;;
    
    decrypt)
        if [ -z "${2:-}" ]; then
            echo "Usage: $0 decrypt <week_number>"
            exit 1
        fi
        WEEK=$(printf "%02d" "$2")
        echo "Decrypting Week ${WEEK}..."
        decrypt_file "$WEEK"
        ;;
    
    decrypt-all)
        echo "Decrypting all quizzes..."
        for i in $(seq -w 1 13); do
            decrypt_file "$i" || true
        done
        ;;
    
    status)
        show_status
        ;;
    
    *)
        echo "Quiz Encrypt/Decrypt Tool"
        echo ""
        echo "Usage:"
        echo "  $0 encrypt [week]    Encrypt quiz(es)"
        echo "  $0 decrypt <week>    Decrypt a quiz"
        echo "  $0 decrypt-all       Decrypt all quizzes"
        echo "  $0 status            Show status"
        ;;
esac
