#!/usr/bin/env python3
"""Offline notification contract and transport safety tests; no external delivery."""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import unittest
from unittest.mock import patch, MagicMock

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "bin/notelseit-notify"
loader = importlib.machinery.SourceFileLoader("notify", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)


class Notifications(unittest.TestCase):
    def test_allowlist(self):
        report = {"status": "critical", "kind": "local", "message": "secret", "latest": "/private"}
        self.assertEqual(set(mod.payload(report)), {"service", "status", "kind"})
        for value in (None, {}, {"status": "unknown", "kind": "local"}):
            with self.assertRaises(ValueError):
                mod.payload(value)

    def test_default_preview_and_invalid_input(self):
        result = subprocess.run([sys.executable, str(SCRIPT)], input=b'{"status":"critical","kind":"local"}', capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["status"], "critical")
        for raw in (b"invalid", b"x" * 65537):
            self.assertEqual(subprocess.run([sys.executable, str(SCRIPT)], input=raw, capture_output=True).returncode, 2)

    def test_endpoint_and_token_rejection(self):
        for url in ("http://example.org", "https://u:p@example.org", "https://example.org/?secret=x", "https://example.org/#x"):
            with self.assertRaises(ValueError):
                mod.send({}, url, "token")
        with self.assertRaises(ValueError):
            mod.send({}, "https://example.org", "x\r\nInjected: yes")

    def test_transport_and_failure(self):
        response = MagicMock()
        response.__enter__.return_value.status = 204
        opener = MagicMock()
        opener.open.return_value = response
        with patch.object(mod.urllib.request, "build_opener", return_value=opener):
            mod.send({"status": "critical"}, "https://example.org/hook", "secret")
            request = opener.open.call_args.args[0]
            self.assertEqual(request.get_header("Authorization"), "Bearer secret")
            self.assertEqual(opener.open.call_args.kwargs["timeout"], 10)
            response.__enter__.return_value.status = 500
            with self.assertRaises(ValueError):
                mod.send({}, "https://example.org", "secret")
            opener.open.side_effect = TimeoutError("secret")
            with self.assertRaises(TimeoutError):
                mod.send({}, "https://example.org", "secret")
        self.assertIsNone(mod.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.org"))

    def test_failure_logs_are_redacted(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "--send"],
            input=b'{"status":"critical","kind":"local"}', capture_output=True,
            env={**os.environ, "NOTELSEIT_NOTIFY_URL": "http://secret.invalid",
                 "NOTELSEIT_NOTIFY_TOKEN": "private-token"})
        self.assertEqual(result.returncode, 2)
        self.assertNotIn(b"private-token", result.stderr)
        self.assertNotIn(b"secret.invalid", result.stderr)


if __name__ == "__main__":
    unittest.main()
