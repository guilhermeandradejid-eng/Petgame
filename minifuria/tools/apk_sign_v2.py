#!/usr/bin/env python3
"""
Assina um APK com o APK Signature Scheme v2 (Android 7.0+/API 24+), sem precisar do Android SDK.

Uso: python3 apk_sign_v2.py entrada.apk saida.apk chave.pem certificado.der
     python3 apk_sign_v2.py --gen chave.pem certificado.der   (gera chave RSA-2048 + certificado autoassinado)

Segue a especificação oficial (source.android.com/docs/security/features/apksigning/v2):
- digest "em pedaços" de 1 MB das seções 1 (entradas), 3 (diretório central) e 4 (EOCD), SHA-256;
- bloco "APK Sig Block 42" com o par ID 0x7109871a inserido logo antes do diretório central;
- assinatura RSASSA-PKCS1-v1_5 com SHA-256 (algoritmo 0x0103).
O APK precisa já estar alinhado (o Godot alinha na exportação).
"""
import hashlib
import struct
import sys
import datetime

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID

SIG_RSA_PKCS1_SHA256 = 0x0103
V2_ID = 0x7109871A
MAGIC = b"APK Sig Block 42"


def lp(b: bytes) -> bytes:
    return struct.pack("<I", len(b)) + b


def gen(key_path: str, cert_path: str) -> None:
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Mini Furia"), x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Mini Furia")])
    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=365 * 30)).sign(key, hashes.SHA256()))
    open(key_path, "wb").write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    open(cert_path, "wb").write(cert.public_bytes(serialization.Encoding.DER))


def find_eocd(data: bytes) -> int:
    for i in range(len(data) - 22, max(-1, len(data) - 22 - 65536), -1):
        if data[i:i + 4] == b"PK\x05\x06":
            (clen,) = struct.unpack("<H", data[i + 20:i + 22])
            if i + 22 + clen == len(data):
                return i
    raise SystemExit("EOCD não encontrado (não é um zip?)")


def chunked_digest(sections) -> bytes:
    digests = []
    for sec in sections:
        for i in range(0, len(sec), 1 << 20):
            ch = sec[i:i + (1 << 20)]
            digests.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(ch)) + ch).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(digests)) + b"".join(digests)).digest()


def sign(src: str, dst: str, key_path: str, cert_path: str) -> None:
    data = open(src, "rb").read()
    eocd = find_eocd(data)
    cd_size, cd_off = struct.unpack("<II", data[eocd + 12:eocd + 20])
    if cd_off + cd_size != eocd:
        raise SystemExit("diretório central não termina no EOCD (APK com dados extras?)")
    if cd_off >= 16 and data[cd_off - 16:cd_off] == MAGIC:
        raise SystemExit("o APK já tem um APK Signing Block")
    sec1, sec3, sec4 = data[:cd_off], data[cd_off:eocd], data[eocd:]
    digest = chunked_digest([sec1, sec3, sec4])   # no EOCD, o offset do diretório central = início do bloco
    key = serialization.load_pem_private_key(open(key_path, "rb").read(), password=None)
    cert = open(cert_path, "rb").read()
    pub = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    alg = struct.pack("<I", SIG_RSA_PKCS1_SHA256)
    signed_data = lp(lp(alg + lp(digest))) + lp(lp(cert)) + lp(b"")
    signature = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    signer = lp(signed_data) + lp(lp(alg + lp(signature))) + lp(pub)
    value = lp(lp(signer))
    pairs = struct.pack("<Q", 4 + len(value)) + struct.pack("<I", V2_ID) + value
    size = len(pairs) + 8 + 16
    block = struct.pack("<Q", size) + pairs + struct.pack("<Q", size) + MAGIC
    new_eocd = sec4[:16] + struct.pack("<I", len(sec1) + len(block)) + sec4[20:]
    open(dst, "wb").write(sec1 + block + sec3 + new_eocd)
    print(f"assinado: {dst}  ({len(sec1) + len(block) + len(sec3) + len(new_eocd)} bytes, digest {digest.hex()[:16]}…)")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--gen":
        gen(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 5:
        sign(*sys.argv[1:5])
    else:
        print(__doc__)
        sys.exit(1)
