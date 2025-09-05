/**
 * SlightBuild Security Configuration and Validation
 * This script helps validate security headers and configurations
 */

const securityConfig = {
  // Security Headers Configuration
  headers: {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: [
          "'self'", 
          "'unsafe-inline'",
          "https://www.google-analytics.com",
          "https://www.googletagmanager.com",
          "https://cdnjs.cloudflare.com",
          "https://cdn.jsdelivr.net"
        ],
        styleSrc: [
          "'self'", 
          "'unsafe-inline'",
          "https://fonts.googleapis.com",
          "https://cdnjs.cloudflare.com"
        ],
        fontSrc: [
          "'self'",
          "https://fonts.gstatic.com",
          "https://cdnjs.cloudflare.com"
        ],
        imgSrc: [
          "'self'",
          "data:",
          "https:",
          "*.googleapis.com",
          "*.gstatic.com",
          "*.unsplash.com",
          "*.cloudfront.net"
        ],
        connectSrc: [
          "'self'",
          "https://www.google-analytics.com",
          "https://stats.g.doubleclick.net"
        ],
        frameAncestors: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        upgradeInsecureRequests: true
      }
    },
    strictTransportSecurity: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true
    },
    xFrameOptions: 'DENY',
    xContentTypeOptions: 'nosniff',
    xXssProtection: '1; mode=block',
    referrerPolicy: 'strict-origin-when-cross-origin',
    permissionsPolicy: {
      accelerometer: [],
      camera: [],
      geolocation: [],
      gyroscope: [],
      magnetometer: [],
      microphone: [],
      payment: [],
      usb: [],
      autoplay: [],
      fullscreen: ['self']
    }
  },

  // Cache Configuration
  cache: {
    html: {
      maxAge: 3600, // 1 hour
      directive: 'public, max-age=3600, must-revalidate'
    },
    assets: {
      maxAge: 31536000, // 1 year
      directive: 'public, max-age=31536000, immutable'
    },
    api: {
      directive: 'no-cache, no-store, must-revalidate'
    }
  },

  // Allowed External Domains
  allowedDomains: [
    'fonts.googleapis.com',
    'fonts.gstatic.com',
    'cdnjs.cloudflare.com',
    'www.google-analytics.com',
    'unsplash.com',
    'images.unsplash.com'
  ],

  // Security Validation Rules
  validation: {
    // Check for insecure content
    insecurePatterns: [
      /http:\/\/(?!localhost|127\.0\.0\.1)/gi,
      /javascript:/gi,
      /data:text\/html/gi,
      /vbscript:/gi
    ],
    
    // Required meta tags for security
    requiredMetaTags: [
      'viewport',
      'charset'
    ],
    
    // Sensitive data patterns to avoid
    sensitivePatterns: [
      /api[_-]?key/gi,
      /secret/gi,
      /password/gi,
      /token/gi,
      /auth[_-]?key/gi
    ]
  }
};

/**
 * Validate security configuration
 */
function validateSecurity() {
  const results = {
    passed: [],
    warnings: [],
    errors: []
  };

  // Check if HTTPS is enforced
  if (typeof window !== 'undefined' && window.location.protocol !== 'https:' && window.location.hostname !== 'localhost') {
    results.errors.push('HTTPS not enforced - site should redirect HTTP to HTTPS');
  } else {
    results.passed.push('HTTPS enforcement check passed');
  }

  // Validate CSP directives
  if (securityConfig.headers.contentSecurityPolicy.directives.defaultSrc.includes("'self'")) {
    results.passed.push('CSP default-src properly configured');
  } else {
    results.errors.push('CSP default-src should include self');
  }

  // Check for inline scripts/styles
  const hasInlineScripts = document.querySelectorAll('script:not([src])').length > 0;
  const hasInlineStyles = document.querySelectorAll('style').length > 0;
  
  if (hasInlineScripts && !securityConfig.headers.contentSecurityPolicy.directives.scriptSrc.includes("'unsafe-inline'")) {
    results.warnings.push('Inline scripts detected - consider moving to external files');
  }
  
  if (hasInlineStyles && !securityConfig.headers.contentSecurityPolicy.directives.styleSrc.includes("'unsafe-inline'")) {
    results.warnings.push('Inline styles detected - consider moving to external files');
  }

  // Check for external resources
  const externalLinks = Array.from(document.querySelectorAll('link[href^="http"], script[src^="http"], img[src^="http"]'));
  externalLinks.forEach(element => {
    const url = element.href || element.src;
    const domain = new URL(url).hostname;
    
    if (!securityConfig.allowedDomains.some(allowed => domain.includes(allowed))) {
      results.warnings.push(`External resource from non-whitelisted domain: ${domain}`);
    }
  });

  return results;
}

/**
 * Generate Content Security Policy string
 */
function generateCSPString() {
  const csp = securityConfig.headers.contentSecurityPolicy.directives;
  const cspString = Object.entries(csp).map(([directive, sources]) => {
    if (directive === 'upgradeInsecureRequests' && sources === true) {
      return 'upgrade-insecure-requests';
    }
    
    const camelToKebab = directive.replace(/([A-Z])/g, '-$1').toLowerCase();
    return `${camelToKebab} ${Array.isArray(sources) ? sources.join(' ') : sources}`;
  }).join('; ');
  
  return cspString;
}

/**
 * Security monitoring and reporting
 */
function initSecurityMonitoring() {
  // CSP violation reporting
  if (typeof document !== 'undefined') {
    document.addEventListener('securitypolicyviolation', (event) => {
      console.warn('CSP Violation:', {
        blockedURI: event.blockedURI,
        violatedDirective: event.violatedDirective,
        originalPolicy: event.originalPolicy,
        documentURI: event.documentURI,
        lineNumber: event.lineNumber,
        columnNumber: event.columnNumber
      });
      
      // In production, you might want to send this to your logging service
      if (typeof gtag !== 'undefined') {
        gtag('event', 'csp_violation', {
          blocked_uri: event.blockedURI,
          violated_directive: event.violatedDirective
        });
      }
    });
  }

  // Performance monitoring
  if (typeof window !== 'undefined' && window.performance) {
    const navigationTiming = performance.getEntriesByType('navigation')[0];
    if (navigationTiming) {
      console.info('Page Load Performance:', {
        domContentLoaded: navigationTiming.domContentLoadedEventEnd - navigationTiming.fetchStart,
        loadComplete: navigationTiming.loadEventEnd - navigationTiming.fetchStart,
        firstPaint: performance.getEntriesByName('first-paint')[0]?.startTime,
        firstContentfulPaint: performance.getEntriesByName('first-contentful-paint')[0]?.startTime
      });
    }
  }
}

// Export for use in different environments
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    securityConfig,
    validateSecurity,
    generateCSPString,
    initSecurityMonitoring
  };
} else if (typeof window !== 'undefined') {
  window.SecurityConfig = {
    config: securityConfig,
    validate: validateSecurity,
    generateCSP: generateCSPString,
    init: initSecurityMonitoring
  };
}