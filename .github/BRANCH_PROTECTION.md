# Branch Protection Configuration

This document outlines the recommended branch protection rules for the `main` branch to ensure code quality and maintain the integrity of the repository.

## Required Configuration

### Navigate to Repository Settings

1. Go to **Settings** → **Branches**
2. Click **Add rule** or edit existing rule for `main` branch

### Branch Protection Rule Settings

#### **Branch Name Pattern**
```
main
```

#### **Protection Rules**

**✅ Require a pull request before merging**
- Require approvals: `1`
- ✅ Dismiss stale PR approvals when new commits are pushed
- ✅ Require review from code owners (if CODEOWNERS file exists)

**✅ Require status checks to pass before merging**
- ✅ Require branches to be up to date before merging

**Required Status Checks:**
Add these exact check names (they will appear after first CI run):
```
CI Tests (macos-14, 5.9)
CI Tests (macos-14, 5.10)
CI Tests (macos-13, 5.9)
CI Tests (macos-13, 5.10)
iOS Tests (iPhone 14, iOS 15.0)
iOS Tests (iPhone 14, iOS 16.0)
iOS Tests (iPhone 15, iOS 17.0)
iOS Tests (iPhone 15, iOS latest)
Linux Compatibility Check
Code Quality & Validation
CI Success
PR Validation Complete
```

**Note**: The iOS testing checks ensure comprehensive cross-platform compatibility by running the full test suite on multiple iOS simulator configurations (iOS 15.0-latest on iPhone 14/15 simulators).

**✅ Require conversation resolution before merging**

**✅ Restrict pushes that create files**
- No additional restrictions needed

**✅ Restrict pushes and merges to this branch**
- ✅ Restrict pushes that create files
- ✅ Restrict pushes that delete files  

**✅ Do not allow bypassing the above settings**
- ✅ Include administrators

**✅ Allow force pushes**
- ❌ Everyone (disable this)

**✅ Allow deletions**
- ❌ (disable this)

## Additional Repository Settings

### Actions Permissions
1. Go to **Settings** → **Actions** → **General**
2. Set **Actions permissions** to: "Allow all actions and reusable workflows"
3. Set **Workflow permissions** to: "Read and write permissions"
4. ✅ Allow GitHub Actions to create and approve pull requests

### Security Settings
1. Go to **Settings** → **Code security and analysis**
2. ✅ Enable Dependency graph
3. ✅ Enable Dependabot alerts  
4. ✅ Enable Dependabot security updates
5. ✅ Enable Secret scanning

### Merge Settings
1. Go to **Settings** → **General** → **Pull Requests**
2. ✅ Allow merge commits
3. ✅ Allow squash merging (recommended default)
4. ✅ Allow rebase merging
5. ✅ Automatically delete head branches

## Verification

After configuring branch protection, verify by:

1. **Test PR Creation**: Create a test branch and PR to ensure:
   - CI workflows trigger automatically
   - All required status checks appear
   - Merge is blocked until checks pass
   - Review requirement is enforced

2. **Test Direct Push Block**: Try pushing directly to `main`:
   ```bash
   git push origin main
   # Should be rejected with protection message
   ```

3. **Check Status Badges**: Ensure README badges work:
   - CI badge shows current status
   - Coverage badge displays correctly

## Status Check Descriptions

### CI Workflows

**CI Tests (matrix)**: 
- Runs comprehensive test suite on multiple OS/Swift combinations
- Builds all example projects
- Validates package resolution
- Performs API consistency checks

**Linux Compatibility Check**:
- Tests basic compilation on Ubuntu
- Runs core functionality tests
- Ensures cross-platform compatibility

**Code Quality & Validation**:
- SwiftLint validation (if configured)
- API compatibility analysis
- Documentation completeness check
- Version consistency validation

**PR Validation Complete**:
- Breaking change detection
- Changelog requirement validation
- Documentation update verification
- Security pattern analysis

### Integration Status

**CI Success**:
- Aggregates all CI job results
- Required for merge - ensures all tests pass
- Single status check that represents overall CI health

## Troubleshooting

### Status Checks Not Appearing
1. Trigger initial workflow run by creating a test PR
2. Status checks appear after first workflow execution
3. Add exact names from workflow runs to required checks

### CI Failures Blocking Merge
1. Check specific failure in Actions tab
2. Fix issues locally and push updates
3. CI re-runs automatically on new commits
4. All checks must be green before merge allowed

### Permission Issues
1. Verify repository admin permissions
2. Check Actions permissions in repository settings
3. Ensure workflow tokens have sufficient permissions

### Emergency Override
- Administrators can temporarily disable protection
- Use only for critical hotfixes
- Re-enable protection immediately after emergency merge
- Document override usage in commit messages

## Maintenance

### Regular Reviews
- Monthly review of protection effectiveness
- Update required checks as workflows evolve  
- Monitor CI reliability and performance
- Adjust settings based on team feedback

### Workflow Updates
When updating CI workflows (`.github/workflows/`):
1. Test changes on feature branch first
2. Update required status check names if job names change
3. Ensure backward compatibility during transitions
4. Document any changes in PR description

This branch protection configuration ensures that all code reaching the `main` branch has been thoroughly tested, reviewed, and validated according to the project's quality standards.