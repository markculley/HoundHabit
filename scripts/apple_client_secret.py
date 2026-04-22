#!/usr/bin/env python3
"""
Generate an Apple Sign in with Apple client secret JWT for Supabase.
Requires only the `cryptography` package: pip install cryptography

Usage:
    python3 apple_client_secret.py \
        --team-id ABC1234567 \
        --key-id XYZ9876543 \
        --services-id com.CometnCloud.HoundHabit.signin \
        --p8 /path/to/AuthKey_XYZ9876543.p8
"""
import argparse
import base64
import json
import time

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--team-id", required=True, help="Apple Team ID (10 chars)")
    p.add_argument("--key-id", required=True, help="Key ID from the .p8 file (10 chars)")
    p.add_argument("--services-id", required=True, help="Services ID (e.g. com.example.signin)")
    p.add_argument("--p8", required=True, help="Path to the AuthKey_XXX.p8 file")
    p.add_argument("--months", type=int, default=6, help="Expiry in months (Apple max: 6)")
    args = p.parse_args()

    with open(args.p8, "rb") as f:
        private_key = serialization.load_pem_private_key(f.read(), password=None)

    now = int(time.time())
    exp = now + args.months * 30 * 24 * 60 * 60

    header = {"alg": "ES256", "kid": args.key_id}
    claims = {
        "iss": args.team_id,
        "iat": now,
        "exp": exp,
        "aud": "https://appleid.apple.com",
        "sub": args.services_id,
    }

    header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode())
    claims_b64 = b64url(json.dumps(claims, separators=(",", ":")).encode())
    signing_input = f"{header_b64}.{claims_b64}".encode()

    # ES256 signature: sign, then convert DER → raw r||s (JWS format).
    der_sig = private_key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
    r, s = decode_dss_signature(der_sig)
    raw_sig = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    sig_b64 = b64url(raw_sig)

    print(f"{header_b64}.{claims_b64}.{sig_b64}")


if __name__ == "__main__":
    main()
