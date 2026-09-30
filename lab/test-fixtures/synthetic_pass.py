"""
Synthetic PASS Fixture for Test Farm SWA Tests
"""
import argparse
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--message", default="synthetic pass")
    parser.add_argument("--telemetry", default=None)
    args = parser.parse_args()

    print(f"STDOUT: {args.message}")
    print(f"STDERR: info log", file=sys.stderr)

    if args.telemetry:
        with open(args.telemetry, "w", encoding="utf-8") as f:
            f.write("frame,present_hr,zoom,tracking,locator_visible\n")
            f.write("# event=started\n")
            f.write("1,0,2,1,1\n")
            f.write("2,0,2,1,1\n")
            f.write("3,0,2,1,1\n")

    sys.exit(0)

if __name__ == "__main__":
    main()
