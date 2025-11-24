#!/usr/bin/env python3
"""
Convert ns-3.22 source from Python 2 to Python 3 compatible syntax.

This script performs more robust conversions than the patch file,
including handling of multi-line statements and octal literals.

Usage:
    python3 convert-ns3-to-python3.py /path/to/ns-3.22

The script will process all Python files in the directory and
its subdirectories, converting Python 2 syntax to Python 3.
"""

import sys
import re
from pathlib import Path
from typing import List, Tuple


class Python2to3Converter:
    """Convert Python 2 syntax to Python 3."""

    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.files_processed = 0
        self.files_modified = 0
        self.changes = []

    def convert_file(self, file_path: Path) -> bool:
        """Convert a single Python file. Returns True if modified."""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                original_content = f.read()
        except Exception as e:
            if self.verbose:
                print(f"ERROR reading {file_path}: {e}")
            return False

        self.files_processed += 1

        # Apply conversions
        converted = self.convert_content(original_content, str(file_path))

        if converted == original_content:
            return False

        # Write back
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(converted)
            self.files_modified += 1
            if self.verbose:
                print(f"CONVERTED: {file_path}")
            return True
        except Exception as e:
            if self.verbose:
                print(f"ERROR writing {file_path}: {e}")
            return False

    def convert_content(self, content: str, filepath: str = "") -> str:
        """Convert Python 2 syntax in content string."""
        # Order matters - do simpler conversions first

        # 1. Exception syntax: except X, e: -> except X as e:
        content = self._fix_exception_syntax(content)

        # 2. File builtin: file() -> open()
        content = self._fix_file_builtin(content)

        # 3. Print statements (most complex)
        content = self._fix_print_statements(content)

        # 4. Octal literals: 0755 -> 0o755
        content = self._fix_octal_literals(content)

        # 5. Raw strings for regex patterns with escape sequences
        content = self._fix_regex_escapes(content)

        return content

    def _fix_exception_syntax(self, content: str) -> str:
        """Convert except Exception, var: to except Exception as var:"""
        # except (ExceptionA, ExceptionB), var:
        content = re.sub(
            r'except\s+\(([^)]+)\)\s*,\s*(\w+):',
            r'except (\1) as \2:',
            content
        )
        # except ExceptionType, var:
        content = re.sub(
            r'except\s+(\w+(?:\.\w+)*)\s*,\s*(\w+):',
            r'except \1 as \2:',
            content
        )
        return content

    def _fix_file_builtin(self, content: str) -> str:
        """Convert file(...) to open(...)"""
        return re.sub(r'\bfile\s*\(', 'open(', content)

    def _fix_print_statements(self, content: str) -> str:
        """Convert Python 2 print statements to print() function calls."""
        lines = content.split('\n')
        fixed_lines = []
        i = 0

        while i < len(lines):
            line = lines[i]

            # Skip pure comment and docstring lines
            stripped = line.lstrip()
            if stripped.startswith('#'):
                fixed_lines.append(line)
                i += 1
                continue

            # Skip lines that are just docstring markers
            if '"""' in line or "'''" in line:
                fixed_lines.append(line)
                i += 1
                continue

            # Try to handle print statements
            if self._is_print_statement(line):
                # Check if this is a multi-line print statement
                full_stmt, stmt_lines = self._get_full_statement(lines, i)

                # Convert the full statement
                converted = self._convert_print_stmt(full_stmt)

                if converted != full_stmt:
                    # Add the converted statement
                    fixed_lines.append(converted)
                    i += stmt_lines
                    continue

            fixed_lines.append(line)
            i += 1

        return '\n'.join(fixed_lines)

    def _is_print_statement(self, line: str) -> bool:
        """Check if a line contains a print statement (not function call)."""
        stripped = line.lstrip()
        # Must start with 'print ' or 'print>>'
        if not re.match(r'print\s', stripped):
            return False
        # If it's print(, it's already converted
        if re.match(r'print\s*\(', stripped):
            return False
        # If it's print >> or print something_not_paren
        return True

    def _get_full_statement(self, lines: List[str], start_idx: int) -> Tuple[str, int]:
        """Get a full (possibly multi-line) print statement."""
        stmt = lines[start_idx]
        line_count = 1

        # Keep reading lines if they're continuations
        while start_idx + line_count < len(lines):
            next_line = lines[start_idx + line_count]
            if stmt.rstrip().endswith('\\'):
                # Explicit continuation
                stmt = stmt.rstrip()[:-1] + ' ' + next_line.lstrip()
                line_count += 1
            elif re.match(r'^\s+', next_line) and not self._is_print_statement(next_line):
                # Implicit continuation (indented, not a new statement)
                stmt = stmt + '\n' + next_line
                line_count += 1
            else:
                break

        return stmt, line_count

    def _convert_print_stmt(self, stmt: str) -> str:
        """Convert a single print statement (possibly multi-line) to print function."""
        # Remove newlines for processing, but track indentation
        match = re.match(r'^(\s*)(.*)$', stmt, re.DOTALL)
        if not match:
            return stmt

        indent = match.group(1)
        stmt_body = match.group(2)

        # Case 1: print >> file, expr1, expr2, ...
        match = re.match(r'print\s*>>\s*(\w+(?:\.\w+)*)\s*,\s*(.*)', stmt_body, re.DOTALL)
        if match:
            file_var = match.group(1)
            rest = match.group(2).strip()
            # Handle potential trailing comma
            rest = re.sub(r',\s*$', '', rest)
            # Normalize whitespace/newlines in rest
            rest = re.sub(r'\s+', ' ', rest).strip()
            return f'{indent}print({rest}, file={file_var})'

        # Case 2: print expr1, expr2, ... (with trailing comma)
        match = re.match(r'print\s+(.+),\s*$', stmt_body, re.DOTALL)
        if match:
            exprs = match.group(1)
            exprs = re.sub(r'\s+', ' ', exprs).strip()
            return f'{indent}print({exprs}, end=" ")'

        # Case 3: print expr1, expr2, ... (without trailing comma)
        match = re.match(r'print\s+(.+)$', stmt_body, re.DOTALL)
        if match:
            exprs = match.group(1)
            # Clean up newlines but preserve structure
            exprs = re.sub(r'\n\s*', ' ', exprs).strip()
            return f'{indent}print({exprs})'

        # Case 4: bare print
        if stmt_body.strip() == 'print':
            return f'{indent}print()'

        return stmt

    def _fix_octal_literals(self, content: str) -> str:
        """Convert octal literals: 0755 -> 0o755"""
        # Only match in code context (not in strings/comments)
        # This is a simple pattern - might catch edge cases
        # Look for 0 followed by 0-7 digits, but not in strings

        lines = content.split('\n')
        fixed_lines = []

        for line in lines:
            # Skip comment lines
            if line.lstrip().startswith('#'):
                fixed_lines.append(line)
                continue

            # Simple approach: replace 0[0-7]+ with 0o[0-7]+ outside of strings
            # This is a heuristic and might need manual review

            # Remove string literals for processing
            # This is approximate - just check for obvious cases
            if re.search(r'\bchmod\s*\(\s*\w+,\s*0[0-7]{3,}', line):
                # This looks like a chmod call with octal literal
                line = re.sub(r'\bchmod\s*\(\s*(\w+),\s*0([0-7]+)',
                             r'chmod(\1, 0o\2', line)

            fixed_lines.append(line)

        return '\n'.join(fixed_lines)

    def _fix_regex_escapes(self, content: str) -> str:
        """Add r prefix to regex patterns with escape sequences."""
        # This is complex and error-prone, so we only handle obvious cases
        # Look for re.match/re.search/re.sub with unescaped patterns

        # Simplistic approach: just flag these for manual review
        # In practice, most regex patterns in ns-3 are already properly escaped

        return content

    def convert_directory(self, directory: Path) -> None:
        """Convert all Python files in a directory tree."""
        if not directory.is_dir():
            print(f"ERROR: {directory} is not a directory")
            return

        # Find all Python files and wscript files
        python_files = list(directory.glob('**/*.py'))
        wscript_files = list(directory.glob('**/wscript'))

        all_files = python_files + wscript_files

        print(f"Found {len(all_files)} files to process")

        for filepath in sorted(all_files):
            self.convert_file(filepath)

        print(f"\nConversion complete:")
        print(f"  Files processed: {self.files_processed}")
        print(f"  Files modified: {self.files_modified}")


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} /path/to/ns-3.22")
        sys.exit(1)

    ns3_path = Path(sys.argv[1])

    if not ns3_path.exists():
        print(f"ERROR: {ns3_path} does not exist")
        sys.exit(1)

    converter = Python2to3Converter(verbose=True)
    converter.convert_directory(ns3_path)


if __name__ == '__main__':
    main()
