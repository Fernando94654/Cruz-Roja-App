import os

from cryptography.fernet import Fernet


def _fernet() -> Fernet:
    return Fernet(os.environ["MEDICAL_DATA_KEY"].encode())


def encrypt(value: str | None) -> bytes | None:
    return None if value is None else _fernet().encrypt(value.encode())


def decrypt(value: bytes | None) -> str | None:
    return None if value is None else _fernet().decrypt(value).decode()
