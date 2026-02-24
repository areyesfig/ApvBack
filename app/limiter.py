"""Rate limiter por IP para la API (slowapi)."""

from slowapi import Limiter
from slowapi.util import get_remote_address

# Límite por defecto para todos los endpoints; los más pesados se sobrescriben en routes.
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["60/minute"],
)
