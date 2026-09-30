"""
Synthetic SLEEP Fixture for Test Farm Timeout SWA Tests
"""
import argparse
import sys
import time

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=float, default=60.0)
    args = parser.parse_args()

    print(f"STDOUT: sleeping for {args.seconds}s...")
    sys.stdout.flush()
    time.sleep(args.seconds)
    print("STDOUT: sleep completed")
    sys.exit(0)

if __name__ == "__main__":
    main()
