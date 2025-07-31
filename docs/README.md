# Anthropic Swift SDK Documentation

This directory contains the GitHub Pages documentation for the Anthropic Swift SDK.

## Local Development

To run the documentation site locally:

1. **Install Ruby and Bundler** (if not already installed):
   ```bash
   # macOS (using Homebrew)
   brew install ruby
   gem install bundler
   
   # Ubuntu/Debian
   sudo apt-get install ruby-full build-essential zlib1g-dev
   gem install bundler
   ```

2. **Install dependencies**:
   ```bash
   cd docs
   bundle install
   ```

3. **Run the development server**:
   ```bash
   bundle exec jekyll serve
   ```

4. **View the site** at `http://localhost:4000`

## Structure

- `_config.yml` - Jekyll configuration
- `index.md` - Homepage
- `getting-started.md` - Getting started guide
- `api-reference.md` - Complete API documentation
- `examples.md` - Usage examples and tutorials
- `troubleshooting.md` - Common issues and solutions
- `assets/css/style.scss` - Custom styles
- `_layouts/` - Custom layout templates
- `Gemfile` - Ruby dependencies

## Deployment

The site is automatically deployed to GitHub Pages when changes are pushed to the `main` branch using the GitHub Actions workflow in `.github/workflows/docs.yml`.

## Contributing

When adding new documentation:

1. Follow the existing structure and naming conventions
2. Use clear, descriptive headings with proper hierarchy
3. Include code examples with proper syntax highlighting
4. Test locally before submitting
5. Update navigation in `_config.yml` if adding new pages

## Features

- 📱 Responsive design optimized for mobile and desktop
- 🎨 Custom styling with Anthropic brand colors
- 📋 Copy-to-clipboard buttons on code blocks
- 🔍 SEO optimized with proper meta tags
- ⚡ Fast loading with optimized assets
- 🚀 Automatic deployment via GitHub Actions