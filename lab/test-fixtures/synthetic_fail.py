"""
Synthetic FAIL Fixture for Test Farm SWA Tests
"""
import argparse
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--code", type=int, default=42)
    parser.add_argument("--error", default="controlled synthetic error")
    args = parser.parse_args()

    print(f"STDOUT: starting failing fixture")
    print(f"STDERR: {args.error}", file=sys.stderr)
    sys.exit(args.code)

if __name__ == "__main__":
    main()
