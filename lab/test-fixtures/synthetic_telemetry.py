"""
Synthetic Telemetry Fixture for Assertion Evaluation SWA Tests
"""
import argparse
import sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--frames", type=int, default=50)
    parser.add_argument("--present-failures", type=int, default=0)
    args = parser.parse_args()

    with open(args.output, "w", encoding="utf-8") as f:
        f.write("frame,qpc,zoom,tracking,present_hr,locator_visible,viewport_action\n")
        f.write("# event=telemetry_started\n")
        for i in range(1, args.frames + 1):
            hr = 0 if i > args.present_failures else 142213121
            f.write(f"{i},{1000000 + i * 16000},2,1,{hr},1,1\n")

    print(f"Generated {args.frames} frames to {args.output}")
    sys.exit(0)

if __name__ == "__main__":
    main()
