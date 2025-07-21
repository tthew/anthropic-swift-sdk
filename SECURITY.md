# Security Guide

## API Key Management

### ⚠️ NEVER commit API keys to git repositories

This project uses various AI services that require API keys. **Never hardcode API keys in configuration files.**

### Secure Setup Instructions

1. **Copy the template configuration:**
   ```bash
   cp .mcp.json.template .mcp.json
   ```

2. **Set up environment variables:**
   ```bash
   # Add to your ~/.bashrc, ~/.zshrc, or equivalent
   export GEMINI_API_KEY="your-actual-api-key-here"
   export ANTHROPIC_API_KEY="your-anthropic-api-key-here"
   ```

3. **Verify environment variables:**
   ```bash
   echo $GEMINI_API_KEY
   # Should output your API key
   ```

4. **The .mcp.json file will automatically use environment variables:**
   ```json
   {
     "env": {
       "GEMINI_API_KEY": "${GEMINI_API_KEY}"
     }
   }
   ```

### Protected Files

The following files are automatically ignored by git to prevent accidental API key exposure:

- `.mcp.json`
- `.env` and `.env.*`
- `*_credentials.json`
- `secrets.*`
- `*.key`
- `*.pem`

### If You Accidentally Commit an API Key

1. **Immediately revoke the exposed key** from your provider's console
2. **Remove the key from git history:**
   ```bash
   git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch path/to/file' --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push to remote:**
   ```bash
   git push origin --force --all
   ```
4. **Generate a new API key**

### Best Practices

✅ **DO:**
- Use environment variables for all secrets
- Use template files with placeholder values
- Keep API keys out of source code
- Regularly rotate API keys
- Use different keys for development/production

❌ **DON'T:**
- Hardcode API keys in any files
- Commit `.env` files to git
- Share API keys in chat/email
- Use production keys for development
- Store keys in configuration files