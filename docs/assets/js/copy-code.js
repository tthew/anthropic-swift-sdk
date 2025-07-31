// Add copy buttons to code blocks
document.addEventListener('DOMContentLoaded', function() {
    // Add copy buttons to all code blocks
    document.querySelectorAll('pre code').forEach(function(block) {
        const button = document.createElement('button');
        button.className = 'copy-button';
        button.textContent = '📋 Copy';
        button.setAttribute('aria-label', 'Copy code to clipboard');
        
        button.onclick = function() {
            // Copy text to clipboard
            if (navigator.clipboard) {
                navigator.clipboard.writeText(block.textContent).then(function() {
                    button.textContent = '✅ Copied!';
                    setTimeout(function() {
                        button.textContent = '📋 Copy';
                    }, 2000);
                });
            } else {
                // Fallback for older browsers
                const textarea = document.createElement('textarea');
                textarea.value = block.textContent;
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);
                
                button.textContent = '✅ Copied!';
                setTimeout(function() {
                    button.textContent = '📋 Copy';
                }, 2000);
            }
        };
        
        block.parentNode.appendChild(button);
    });
    
    // Add smooth scrolling to anchor links
    document.querySelectorAll('a[href^="#"]').forEach(function(anchor) {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth'
                });
            }
        });
    });
});