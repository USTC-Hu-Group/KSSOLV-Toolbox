"""Shared authentication primitives for imported and direct service entry points."""
import hashlib


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class Rejected(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message
