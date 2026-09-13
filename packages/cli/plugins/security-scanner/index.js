const PATTERNS = [
  {
    pattern: /eval\s*\(/,
    title: 'Use of eval()',
    severity: 'critical',
    category: 'security',
    description: 'eval() executes arbitrary code and can lead to code injection',
    suggestion: 'Avoid eval(). Use JSON.parse() for data or a proper parser for expressions.',
  },
  {
    pattern: /innerHTML\s*=/,
    title: 'innerHTML assignment',
    severity: 'warning',
    category: 'security',
    description: 'Direct innerHTML assignment can lead to XSS attacks',
    suggestion: 'Use textContent for plain text or a sanitized HTML library.',
  },
  {
    pattern: /password\s*=\s*['"]/i,
    title: 'Hardcoded password',
    severity: 'critical',
    category: 'security',
    description: 'Hardcoded credentials should never be committed to source control',
    suggestion: 'Move credentials to environment variables or a secrets manager.',
  },
  {
    pattern: /new\s+Function\s*\(/,
    title: 'Dynamic function creation',
    severity: 'warning',
    category: 'security',
    description: 'new Function() can execute arbitrary code',
    suggestion: 'Avoid dynamic function creation; use static functions or modules.',
  },
  {
    pattern: /\/\/\s*TODO.*security/i,
    title: 'Security TODO',
    severity: 'info',
    category: 'security',
    description: 'Security-related TODO comment found',
    suggestion: 'Address the security concern before shipping to production.',
  },
];

export async function onAnalysisComplete(context) {
  const findings = [];
  for (const file of context.diff.files) {
    if (!file.diff) continue;
    const lines = file.diff.split('\n');
    let lineNumber = 0;
    for (const line of lines) {
      lineNumber++;
      if (line.startsWith('+') && !line.startsWith('+++')) {
        const content = line.slice(1);
        for (const rule of PATTERNS) {
          if (rule.pattern.test(content)) {
            findings.push({
              id: `${file.path}:${lineNumber}:${rule.title}`,
              severity: rule.severity,
              category: rule.category,
              title: rule.title,
              description: rule.description,
              location: { file: file.path, line: lineNumber },
              suggestion: rule.suggestion,
              confidence: 0.9,
              source: 'plugin',
              pluginId: 'com.spikey.security-scanner',
            });
          }
        }
      }
    }
  }
  return findings;
}
