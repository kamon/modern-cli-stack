#!/usr/bin/env python3
"""
check_ai_tells.py — AI tell detection hook.

Scans a markdown file for common AI writing patterns and reports findings
by severity tier (P0 = credibility killer, P1 = obvious AI smell, P2 = polish).

Usage:
  python check_ai_tells.py <file.md>
  python check_ai_tells.py --mode audit <directory>

Outputs a structured report. Does NOT modify the file.
Based on patterns from the Hermes skill: writing/avoid-ai-writing.
"""

import re
import sys
import os
import json
from pathlib import Path
from collections import defaultdict

# ============================================================================
# Pattern definitions
# ============================================================================

# P0 — Credibility killers. Fix immediately.
P0_PATTERNS = [
    (r'\b(as of my last update|as of (?:january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{4})\b', "Cutoff disclaimer"),
    (r'\b(I hope this helps|great question|certainly!|absolutely!|feel free to reach out|let me know if you need anything else)\b', "Chatbot artifact"),
    (r'\b(experts (?:believe|say|agree)|studies show|research suggests|industry leaders agree)\b', "Vague attribution"),
    (r'\[(?:Your|Insert|Add|Enter|Describe|Specify|Choose)[^\]]+\]', "Unfilled placeholder"),
]

# P1 — Obvious AI smell. Fix before publishing.
P1_WORD_PATTERNS = [
    # Tier 1 words (always flag)
    (r'\bdelve\b|\bdelving\b', 'delve', 'Word: delve'),
    (r'\blandscape\b', 'landscape', 'Word: landscape (metaphor)'),
    (r'\btapestry\b', 'tapestry', 'Word: tapestry'),
    (r'\brealm\b', 'realm', 'Word: realm'),
    (r'\bparadigm\b', 'paradigm', 'Word: paradigm'),
    (r'\bembark\b', 'embark', 'Word: embark'),
    (r'\btestament to\b', 'testament to', 'Word: testament to'),
    (r'\brobust\b', 'robust', 'Word: robust'),
    (r'\bcomprehensive\b', 'comprehensive', 'Word: comprehensive'),
    (r'\bcutting[- ]edge\b', 'cutting-edge', 'Word: cutting-edge'),
    (r'\bleverage\b|\bleveraging\b|\bleveraged\b', 'leverage', 'Word: leverage'),
    (r'\bpivotal\b', 'pivotal', 'Word: pivotal'),
    (r'\bunderscores?\b', 'underscore', 'Word: underscores'),
    (r'\bmeticulous\b|\bmeticulously\b', 'meticulous', 'Word: meticulous'),
    (r'\bseamless\b|\bseamlessly\b', 'seamless', 'Word: seamless'),
    (r'\bgame[- ]?changer\b|\bgame[- ]?changing\b', 'game-changer', 'Word: game-changer'),
    (r'\butilize\b|\butilizing\b', 'utilize', 'Word: utilize'),
    (r'\bwatershed moment\b', 'watershed', 'Word: watershed moment'),
    (r'\bnestled\b', 'nestled', 'Word: nestled'),
    (r'\bvibrant\b', 'vibrant', 'Word: vibrant'),
    (r'\bthriving\b', 'thriving', 'Word: thriving'),
    (r'\bshowcasing\b', 'showcasing', 'Word: showcasing'),
    (r'\bdeep dive\b|\bdive into\b', 'deep dive', 'Word: deep dive'),
    (r'\bunpack(?:ing)?\b', 'unpack', 'Word: unpack'),
    (r'\bbustling\b', 'bustling', 'Word: bustling'),
    (r'\bintricate\b|\bintricacies\b', 'intricate', 'Word: intricate'),
    (r'\bever[- ]evolving\b', 'ever-evolving', 'Word: ever-evolving'),
    (r'\bdaunting\b', 'daunting', 'Word: daunting'),
    (r'\bholistic\b|\bholistically\b', 'holistic', 'Word: holistic'),
    (r'\bactionable\b', 'actionable', 'Word: actionable'),
    (r'\bimpactful\b', 'impactful', 'Word: impactful'),
    (r'\bthought leader\b|\bthought leadership\b', 'thought leader', 'Word: thought leader'),
    (r'\bbest practices\b', 'best practices', 'Word: best practices'),
    (r'\bat its core\b', 'at its core', 'Phrase: at its core'),
    (r'\bsynerg(?:y|ies)\b', 'synergy', 'Word: synergy'),
    (r'\binterplay\b', 'interplay', 'Word: interplay'),
    (r'\bfeatures?\b(?=\s+(?:a|an|the|over))', 'features', 'Word: features (verb inflation)'),
    (r'\bboasts?\b', 'boasts', 'Word: boasts'),
    (r'\bcommence\b', 'commence', 'Word: commence'),
    (r'\bascertain\b', 'ascertain', 'Word: ascertain'),
    (r'\bendeavor\b', 'endeavor', 'Word: endeavor'),
    (r'\bembrace\b', 'embrace', 'Word: embrace (metaphor)'),
]

# Tier 2 — Flag in clusters of 2+ in same paragraph
TIER2_WORDS = [
    'harness', 'navigate', 'navigating', 'foster', 'elevate', 'unleash',
    'streamline', 'empower', 'bolster', 'spearhead', 'resonate', 'revolutionize',
    'facilitate', 'underpin', 'nuanced', 'crucial', 'multifaceted', 'ecosystem',
    'myriad', 'plethora', 'encompass', 'catalyze', 'reimagine', 'galvanize',
    'augment', 'cultivate', 'illuminate', 'elucidate', 'juxtapose',
    'transformative', 'cornerstone', 'paramount', 'poised', 'burgeoning',
    'nascent', 'quintessential', 'overarching',
]

P1_PHRASE_PATTERNS = [
    (r'\bImagine:?\s+(?:a |an )', "Imagine: opener"),
    (r'\bImagine,?\s+', "Imagine opener"),
    (r'\bworth (?:reading|paying attention to|a look|exploring|checking out|your time)\b', 'Worth [verb]ing'),
    (r'\bgenuine\b|\bgenuinely\b|\bquite frankly\b|\bto be honest\b|\blet\'s be clear\b|\bit\'s worth noting\b', 'Hollow intensifier'),
    (r'\bperhaps\b|\bcould potentially\b|\bit\'s important to note that\b', 'Hedging'),
    (r'\bwhether you\'re\b.*\bor\b.*\b', 'Whether you\'re X or Y'),
    (r'\bI recently had the pleasure of\b', 'I recently had the pleasure of'),
    (r'\bmoreover\b|\bfurthermore\b|\badditionally\b', 'Transition: Moreover/Furthermore'),
    (r'\bin today\'s\b|\bin an era where\b', 'In today\'s / In an era where'),
    (r'\bhere\'s what\'s interesting\b|\bhere\'s what caught my eye\b|\bhere\'s what stood out\b', 'Reader-steering frame'),
    (r'\bin conclusion\b|\bin summary\b|\bto summarize\b', 'Generic conclusion'),
    (r'\bwhen it comes to\b', 'When it comes to'),
    (r'\bat the end of the day\b', 'At the end of the day'),
    (r'\bthe future looks bright\b', 'The future looks bright'),
    (r'\bonly time will tell\b', 'Only time will tell'),
    (r'\bone thing is certain\b', 'One thing is certain'),
    (r'\bdespite challenges?\b', 'Despite challenges...'),
    (r'\bWhile facing headwinds\b', 'While facing headwinds'),
    (r'\b\d+-?\d+x (?:faster|better|more|less)\b', 'Fake multiplier (10-100x faster)'),
    (r'\b\d+ times a day\b', 'Fake specific frequency (40 times a day)'),
    (r'\bblazing[- ]?fast\b', 'Blazing-fast'),
    (r'\bstate[- ]of[- ]the[- ]art\b', 'State-of-the-art'),
    (r'\bbest[- ]in[- ]class\b', 'Best-in-class'),
    (r'\bmay become one of the most\b', 'Future-narrative closer'),
    (r'\bcould become the defining\b', 'Future-narrative closer'),
    (r'\bis poised to become\b', 'Future-narrative closer'),
    (r'\bcould potentially create\b', 'Hedge-stacked prediction'),
    (r'\bmay eventually unlock\b', 'Hedge-stacked prediction'),
    (r'\bmight ultimately transform\b', 'Hedge-stacked prediction'),
    (r'\bLet me think\b|\bbreaking this down\b|\bworking through this logically\b', 'Reasoning chain artifact'),
    (r'\bFirst, let\'s consider\b', 'Reasoning chain artifact'),
    (r'\bthat said\b|\bthat being said\b', 'That said'),
    (r'\blet\'s (?:explore|examine|break|dive|take a look|see)\b', "Let's [verb] transition"),
    (r'\bdive in\b|\bdelve into\b', 'Dive in'),
]

# P2 — Stylistic polish
P2_PATTERNS = [
    (r'—', 'Em dash (count per 1000 words)'),  # tracked separately as count
    (r'\bnotably\b|\binterestingly\b|\bsurprisingly\b|\bcertainly\b|\bundoubtedly\b|\bwithout a doubt\b', 'Confidence calibration phrase'),
    (r'\bvery\b|\btruly\b|\bincredibly\b|\bremarkably\b|\bexceptionally\b', 'Intensifier'),
    (r'\bfurthermore\b|\bmoreover\b|\badditionally\b', 'Transition phrase'),
]

# ============================================================================
# Scanner
# ============================================================================

def strip_frontmatter(text):
    """Remove YAML frontmatter."""
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end > 0:
            return text[end + 4:]
    return text


def strip_code_blocks(text):
    """Remove code blocks and inline code (no AI tell check inside code)."""
    text = re.sub(r'```.*?```', '', text, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', '', text)
    return text


def count_em_dashes(text):
    """Count em dashes (—) and double-hyphens (--)."""
    return len(re.findall(r'—|--', text))


def count_words(text):
    """Rough word count after stripping code blocks."""
    text = strip_code_blocks(text)
    return len(text.split())


def find_pattern_matches(text, patterns):
    """Find all pattern matches, return list of (line_num, matched_text, name)."""
    matches = []
    lines = text.split('\n')
    for line_num, line in enumerate(lines, 1):
        # Skip lines that are in code blocks (heuristic: indented 4+ spaces or starts with backtick line)
        stripped_line = line.strip()
        if stripped_line.startswith('```') or stripped_line.startswith('    ') or stripped_line.startswith('\t'):
            continue
        for pattern, name, *rest in patterns:
            for m in re.finditer(pattern, line, re.IGNORECASE):
                matches.append((line_num, m.group(0), name))
    return matches


def find_tier2_clusters(text, tier2_words):
    """Find paragraphs with 2+ tier-2 words."""
    paragraphs = re.split(r'\n\s*\n', strip_code_blocks(strip_frontmatter(text)))
    clusters = []
    for para in paragraphs:
        if not para.strip():
            continue
        words_lower = set()
        for word in tier2_words:
            if re.search(rf'\b{re.escape(word)}\b', para, re.IGNORECASE):
                words_lower.add(word)
        if len(words_lower) >= 2:
            clusters.append((para[:80] + "...", list(words_lower)))
    return clusters


def find_bold_paragraphs(text):
    """Find paragraphs that are entirely bold (a tell-tale AI pattern)."""
    paragraphs = re.split(r'\n\s*\n', strip_code_blocks(strip_frontmatter(text)))
    bold_paragraphs = []
    for para in paragraphs:
        para = para.strip()
        # A paragraph that is mostly one bold sentence followed by more text
        if para.startswith('**') and '\n**' not in para:
            # Single bold line at start
            end = para.find('**', 2)
            if end > 0:
                bold_part = para[2:end]
                if len(bold_part) > 30:  # Only flag substantial bold sentences
                    bold_paragraphs.append(bold_part[:80])
    return bold_paragraphs


def scan_file(path):
    """Run all checks on a file, return structured findings."""
    text = Path(path).read_text(encoding='utf-8', errors='replace')
    findings = defaultdict(list)

    # P0
    for pattern, name in P0_PATTERNS:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            line = text[:m.start()].count('\n') + 1
            findings['P0'].append((line, m.group(0), name))

    # P1 words (Tier 1)
    for pattern, word, name in P1_WORD_PATTERNS:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            line = text[:m.start()].count('\n') + 1
            findings['P1'].append((line, m.group(0), name))

    # P1 phrases
    for pattern, name in P1_PHRASE_PATTERNS:
        for m in re.finditer(pattern, text, re.IGNORECASE):
            line = text[:m.start()].count('\n') + 1
            findings['P1'].append((line, m.group(0), name))

    # Tier 2 clusters
    clusters = find_tier2_clusters(text, TIER2_WORDS)
    for snippet, words in clusters:
        findings['P1'].append((None, ', '.join(words), f"Tier-2 cluster ({len(words)} words)"))

    # P2 — em dashes (density check, length-aware)
    em_count = count_em_dashes(text)
    word_count = count_words(text)
    if word_count > 0:
        em_per_1k = (em_count / word_count) * 1000
        # Tier the finding: absolute count + density
        # - 0 em dashes: clean
        # - 1-3 in any doc: OK
        # - >1 per 1000 words AND >5 total: flag
        if em_count > 5 and em_per_1k > 1.0:
            findings['P2'].append((None, f"{em_count} em dashes / {word_count} words = {em_per_1k:.1f} per 1k (limit: 1 per 1k, 5 absolute)", "Em dash overuse"))
        elif em_count > 3:
            findings['P2'].append((None, f"{em_count} em dashes (consider: limit is ~3 per document for variety)", "Em dash frequency"))

    # P2 — bold paragraphs
    bold_paras = find_bold_paragraphs(text)
    if len(bold_paras) >= 3:
        findings['P2'].append((None, f"{len(bold_paras)} paragraphs open with bold sentences", "Bold-overuse pattern"))

    # P2 — confidence calibration
    for pattern, name in P2_PATTERNS[1:]:  # Skip em dash (handled above)
        for m in re.finditer(pattern, text, re.IGNORECASE):
            line = text[:m.start()].count('\n') + 1
            findings['P2'].append((line, m.group(0), name))

    return findings, word_count


def format_findings(path, findings, word_count):
    """Format findings as a readable report."""
    p0 = findings.get('P0', [])
    p1 = findings.get('P1', [])
    p2 = findings.get('P2', [])

    total = len(p0) + len(p1) + len(p2)

    if total == 0:
        return f"✓ {path.name}: clean (no AI tells detected)\n"

    lines = [f"\n{path.name} ({word_count} words): {len(p0)} P0 + {len(p1)} P1 + {len(p2)} P2 = {total} total"]

    if p0:
        lines.append("  P0 — credibility killers (fix immediately):")
        seen = set()
        for line_num, text, name in p0[:10]:
            key = (name, text[:30])
            if key in seen:
                continue
            seen.add(key)
            line_str = f"L{line_num}" if line_num else "(cluster)"
            lines.append(f"    {line_str}: '{text}' [{name}]")

    if p1:
        lines.append("  P1 — obvious AI smell (fix before publishing):")
        # Group by name
        by_name = defaultdict(list)
        for line_num, text, name in p1:
            by_name[name].append((line_num, text))
        for name, items in sorted(by_name.items()):
            count = len(items)
            if count > 5:
                lines.append(f"    {count}x {name}")
            else:
                for line_num, text in items[:5]:
                    line_str = f"L{line_num}" if line_num else "(para)"
                    lines.append(f"    {line_str}: '{text}' [{name}]")

    if p2:
        lines.append("  P2 — stylistic polish:")
        for line_num, text, name in p2:
            line_str = f"L{line_num}" if line_num else "(file-wide)"
            lines.append(f"    {line_str}: '{text[:60]}' [{name}]")

    return "\n".join(lines) + "\n"


def audit_mode(directory):
    """Audit all .md files in a directory."""
    files = sorted(Path(directory).rglob("*.md"))
    if not files:
        print(f"No .md files found in {directory}")
        return 0

    grand_total_p0 = grand_total_p1 = grand_total_p2 = 0
    print(f"Auditing {len(files)} files...\n")

    for f in files:
        try:
            findings, wc = scan_file(f)
        except Exception as e:
            print(f"  ERROR scanning {f}: {e}")
            continue
        if findings:
            print(format_findings(f, findings, wc))
            grand_total_p0 += len(findings.get('P0', []))
            grand_total_p1 += len(findings.get('P1', []))
            grand_total_p2 += len(findings.get('P2', []))

    print(f"\n{'='*60}")
    print(f"Total: {grand_total_p0} P0 + {grand_total_p1} P1 + {grand_total_p2} P2")

    if grand_total_p0 > 0:
        print(f"⚠ P0 issues require immediate attention")
        return 1
    elif grand_total_p1 > 5:
        print(f"⚠ P1 issues warrant a cleanup pass")
        return 1
    else:
        print(f"✓ Acceptable (P0 and P1 within tolerance)")
        return 0


def main():
    # Mode 1: invoked with a file argument
    if len(sys.argv) >= 2 and sys.argv[1] != "--mode":
        path = Path(sys.argv[1])
        if not path.exists():
            print(f"ERROR: {path} not found")
            sys.exit(1)
        findings, wc = scan_file(path)
        report = format_findings(path, findings, wc)
        print(report)
        total = sum(len(v) for v in findings.values())
        if total == 0:
            sys.exit(0)
        elif findings.get('P0'):
            sys.exit(2)
        elif sum(len(v) for v in findings.values()) > 5:
            sys.exit(1)
        else:
            sys.exit(0)

    # Mode 2: --mode audit <directory>
    if len(sys.argv) >= 4 and sys.argv[1] == "--mode" and sys.argv[2] == "audit":
        directory = sys.argv[3]
        sys.exit(audit_mode(directory))

    # Mode 3: invoked from build system with BUILD_CONTEXT env var
    # Scan all markdown files listed in the context
    ctx = os.environ.get("BUILD_CONTEXT")
    if ctx:
        try:
            context = json.loads(ctx)
            # Look for content_dir in context
            content_dirs = []
            if "product" in context and "content_dir" in context.get("product", {}):
                content_dirs.append(context["product"]["content_dir"])
            if "build" in context and "content_dir" in context.get("build", {}):
                content_dirs.append(context["build"]["content_dir"])

            # Also check CWD for content/
            cwd = Path(os.getcwd())
            for candidate in ["content", "system/content", "system"]:
                p = cwd / candidate
                if p.exists() and p.is_dir():
                    content_dirs.append(str(p))

            if content_dirs:
                # Audit the first valid directory
                for d in content_dirs:
                    if Path(d).exists():
                        sys.exit(audit_mode(d))
                # If none exist, scan CWD for *.md
                sys.exit(audit_mode(str(cwd)))
            else:
                # Default to scanning CWD
                sys.exit(audit_mode(str(cwd)))
        except json.JSONDecodeError as e:
            print(f"ERROR: Bad BUILD_CONTEXT JSON: {e}")
            sys.exit(1)

    # Mode 4: no args — show usage
    print("Usage: python check_ai_tells.py <file.md>")
    print("       python check_ai_tells.py --mode audit <directory>")
    print("       (or invoke from build system with BUILD_CONTEXT set)")
    sys.exit(1)


if __name__ == "__main__":
    main()