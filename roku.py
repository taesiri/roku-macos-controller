#!/usr/bin/env python3
"""Simple Roku ECP CLI (no external deps)."""

import argparse
import http.client
import os
import socket
import sys
import time
import urllib.parse
import xml.etree.ElementTree as ET

SSDP_ADDR = ("239.255.255.250", 1900)
SSDP_ST = "roku:ecp"
DEFAULT_PORT = 8060


def ssdp_discover(timeout=3):
    msg = (
        "M-SEARCH * HTTP/1.1\r\n"
        f"HOST: {SSDP_ADDR[0]}:{SSDP_ADDR[1]}\r\n"
        "MAN: \"ssdp:discover\"\r\n"
        f"ST: {SSDP_ST}\r\n"
        "MX: 2\r\n"
        "\r\n"
    ).encode("ascii")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.settimeout(timeout)
    sock.sendto(msg, SSDP_ADDR)

    responses = []
    start = time.time()
    while time.time() - start < timeout:
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            break
        responses.append((addr, data.decode("utf-8", "ignore")))
    return responses


def parse_ssdp_headers(raw):
    headers = {}
    lines = raw.splitlines()
    for line in lines[1:]:
        if ":" not in line:
            continue
        key, val = line.split(":", 1)
        headers[key.strip().lower()] = val.strip()
    return headers


def pick_host(args):
    if args.host:
        return args.host
    env_host = os.environ.get("ROKU_HOST") or os.environ.get("ROKU_DEV_TARGET")
    if env_host:
        return env_host
    if args.auto:
        responses = ssdp_discover(timeout=args.timeout)
        for _addr, text in responses:
            headers = parse_ssdp_headers(text)
            loc = headers.get("location")
            if loc:
                parsed = urllib.parse.urlparse(loc)
                if parsed.hostname:
                    return parsed.hostname
    return None


def ecp_get(host, path):
    conn = http.client.HTTPConnection(host, DEFAULT_PORT, timeout=5)
    conn.request("GET", path)
    resp = conn.getresponse()
    body = resp.read()
    return resp.status, body


def ecp_post(host, path):
    conn = http.client.HTTPConnection(host, DEFAULT_PORT, timeout=5)
    conn.request("POST", path)
    resp = conn.getresponse()
    body = resp.read()
    return resp.status, body


def cmd_discover(args):
    responses = ssdp_discover(timeout=args.timeout)
    if not responses:
        print("No Roku SSDP responses found.")
        return 1
    for addr, text in responses:
        headers = parse_ssdp_headers(text)
        loc = headers.get("location", "")
        usn = headers.get("usn", "")
        server = headers.get("server", "")
        print("----")
        print(f"From: {addr[0]}")
        if loc:
            print(f"Location: {loc}")
        if usn:
            print(f"USN: {usn}")
        if server:
            print(f"Server: {server}")
    return 0


def cmd_info(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    status, body = ecp_get(host, "/query/device-info")
    if status != 200:
        print(f"HTTP {status} from {host}")
        return 1
    if args.raw:
        sys.stdout.buffer.write(body)
        return 0
    root = ET.fromstring(body)
    fields = [
        "friendly-device-name",
        "model-name",
        "model-number",
        "serial-number",
        "software-version",
        "software-build",
        "wifi-mac",
        "ethernet-mac",
        "network-type",
    ]
    for name in fields:
        el = root.find(name)
        if el is not None and el.text is not None:
            print(f"{name}: {el.text}")
    return 0


def cmd_apps(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    status, body = ecp_get(host, "/query/apps")
    if status != 200:
        print(f"HTTP {status} from {host}")
        return 1
    root = ET.fromstring(body)
    for app in root.findall("app"):
        app_id = app.get("id", "")
        name = app.text or ""
        print(f"{app_id}\t{name}")
    return 0


def cmd_keypress(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    status, _body = ecp_post(host, f"/keypress/{urllib.parse.quote(args.key)}")
    if status != 200:
        print(f"HTTP {status} from {host}")
        return 1
    return 0


def cmd_keydown(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    status, _body = ecp_post(host, f"/keydown/{urllib.parse.quote(args.key)}")
    if status != 200:
        print(f"HTTP {status} from {host}")
        return 1
    return 0


def cmd_keyup(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    status, _body = ecp_post(host, f"/keyup/{urllib.parse.quote(args.key)}")
    if status != 200:
        print(f"HTTP {status} from {host}")
        return 1
    return 0


def cmd_launch(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    status, _body = ecp_post(host, f"/launch/{urllib.parse.quote(args.app_id)}")
    if status != 200:
        print(f"HTTP {status} from {host}")
        return 1
    return 0


def cmd_type(args):
    host = pick_host(args)
    if not host:
        print("No Roku host set. Use --host or set ROKU_HOST, or pass --auto.")
        return 1
    for ch in args.text:
        lit = "Lit_" + urllib.parse.quote(ch)
        status, _body = ecp_post(host, f"/keypress/{lit}")
        if status != 200:
            print(f"HTTP {status} from {host}")
            return 1
    return 0


def build_parser():
    parser = argparse.ArgumentParser(description="Simple Roku ECP CLI")
    parser.add_argument("--host", help="Roku IP or hostname")
    parser.add_argument(
        "--auto",
        action="store_true",
        help="Auto-discover a Roku via SSDP if no host is set",
    )
    parser.add_argument(
        "--timeout", type=int, default=3, help="SSDP timeout (seconds)"
    )

    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("discover", help="Discover Roku devices via SSDP")
    p.set_defaults(func=cmd_discover)

    p = sub.add_parser("info", help="Show device info")
    p.add_argument("--raw", action="store_true", help="Print raw XML")
    p.set_defaults(func=cmd_info)

    p = sub.add_parser("apps", help="List installed apps")
    p.set_defaults(func=cmd_apps)

    p = sub.add_parser("keypress", help="Send keypress")
    p.add_argument("key", help="Key name, e.g. Home, Back, Up, Select")
    p.set_defaults(func=cmd_keypress)

    p = sub.add_parser("keydown", help="Send keydown")
    p.add_argument("key", help="Key name")
    p.set_defaults(func=cmd_keydown)

    p = sub.add_parser("keyup", help="Send keyup")
    p.add_argument("key", help="Key name")
    p.set_defaults(func=cmd_keyup)

    p = sub.add_parser("launch", help="Launch an app by id")
    p.add_argument("app_id", help="App id from `apps` output")
    p.set_defaults(func=cmd_launch)

    p = sub.add_parser("type", help="Type text into the active input")
    p.add_argument("text", help="Text to send")
    p.set_defaults(func=cmd_type)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
