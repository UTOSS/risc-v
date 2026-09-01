#!/usr/bin/env python3
"""
Temporarily fix include paths for svsch diagram generation.
Adjusts relative includes to work with Surelog's elaboration.
"""

import os
import re
import sys
import tempfile
import shutil
from pathlib import Path

# Map from original include to fixed include based on file location
WORKSPACE_ROOT = Path(__file__).parent.parent
SRC_DIR = WORKSPACE_ROOT / "src"

def get_fixed_include_path(file_path, include_path):
    """Calculate the correct relative path for a given file."""
    file_path = Path(file_path)
    file_rel_to_root = file_path.relative_to(WORKSPACE_ROOT)
    
    # Get depth relative to workspace root
    depth = len(file_rel_to_root.parents) - 1
    
    # Build relative path back to workspace root + include path
    if include_path.startswith("src/"):
        # Calculate path from file's directory up to root, then down to src/...
        up_path = "../" * depth
        return up_path + include_path
    
    return include_path

def fix_includes_in_files(source_files, output_dir):
    """Copy source files to temp directory with fixed includes."""
    file_mapping = {}  # Original path -> temp path
    
    os.makedirs(output_dir, exist_ok=True)
    
    for src_file in source_files:
        src_path = Path(src_file)
        if not src_path.exists():
            continue
        
        # Create parallel directory structure
        rel_path = src_path.relative_to(WORKSPACE_ROOT)
        temp_file = Path(output_dir) / rel_path
        temp_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Read original file
        with open(src_path, 'r') as f:
            content = f.read()
        
        # Fix includes: replace `include "src/..." with corrected paths
        original_content = content
        
        def replace_include(match):
            include_path = match.group(1)
            if include_path.startswith("src/"):
                fixed_path = get_fixed_include_path(src_path, include_path)
                return f'`include "{fixed_path}"'
            return match.group(0)
        
        content = re.sub(r'`include\s+"([^"]+)"', replace_include, content)
        
        # Write fixed file to temp directory
        with open(temp_file, 'w') as f:
            f.write(content)
        
        file_mapping[str(src_path)] = str(temp_file)
    
    return file_mapping

def get_source_files():
    """Get list of all SystemVerilog source and header files."""
    files = []
    src_dir = WORKSPACE_ROOT / "src"
    env_dir = WORKSPACE_ROOT / "envs"
    
    # Find all .sv, .v, .svh files
    for pattern in ["**/*.sv", "**/*.v", "**/*.svh"]:
        files.extend(src_dir.glob(pattern))
        files.extend(env_dir.glob(pattern))
    
    return [str(f) for f in files if f.is_file()]

def main():
    if len(sys.argv) < 2:
        print("Usage: svsch_include_fixer.py <output_dir> [command...]")
        sys.exit(1)
    
    output_dir = sys.argv[1]
    command = sys.argv[2:] if len(sys.argv) > 2 else []
    
    print(f"[svsch_fixer] Creating fixed includes in {output_dir}...")
    
    source_files = get_source_files()
    print(f"[svsch_fixer] Found {len(source_files)} source files")
    
    file_mapping = fix_includes_in_files(source_files, output_dir)
    print(f"[svsch_fixer] Fixed {len(file_mapping)} files")
    
    if command:
        print(f"[svsch_fixer] Running: {' '.join(command)}")
        os.execvp(command[0], command)
    else:
        print(f"[svsch_fixer] Fixed files available in: {output_dir}")
        print("[svsch_fixer] File mapping:")
        for orig, temp in list(file_mapping.items())[:5]:
            print(f"  {orig} -> {temp}")
        if len(file_mapping) > 5:
            print(f"  ... and {len(file_mapping) - 5} more")

if __name__ == "__main__":
    main()
