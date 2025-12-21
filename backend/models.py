"""Pydantic models for API request/response validation."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, Field, field_validator


class ProtocolType(str, Enum):
    """Supported VPN protocols."""

    VLESS_WS = "vless_ws"
    VLESS_XHTTP = "vless_xhttp"
    VLESS_REALITY = "vless_reality"
    VMESS_WS = "vmess_ws"
    TROJAN_XTLS = "trojan_xtls"


class TransportType(str, Enum):
    """Network transport types."""

    TCP = "tcp"
    WS = "ws"
    XHTTP = "xhttp"
    GRPC = "grpc"
    QUIC = "quic"


class SecurityType(str, Enum):
    """Security/encryption types."""

    NONE = "none"
    TLS = "tls"
    REALITY = "reality"
    XTLS = "xtls"


class ProfileCreate(BaseModel):
    """Request model for creating new profile."""

    email: str = Field(..., description="User email/identifier", min_length=3, max_length=100)
    protocol: Optional[ProtocolType] = Field(
        default=ProtocolType.VLESS_REALITY,
        description="VPN protocol to use",
    )

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Sanitize email input."""
        return v.strip().lower()


class ProfileResponse(BaseModel):
    """Response model for profile data."""

    id: str = Field(..., description="Profile UUID")
    email: Optional[str] = Field(None, description="User identifier")
    protocol: ProtocolType = Field(..., description="Active protocol")
    transport: TransportType = Field(..., description="Network transport")
    security: SecurityType = Field(..., description="Encryption method")
    connection_link: str = Field(..., description="VLESS/VMess connection URI")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    port: int = Field(..., description="Server port", ge=1, le=65535)
    server_address: str = Field(..., description="Server IP or domain")
    
    # Protocol-specific fields
    flow: Optional[str] = Field(None, description="XTLS flow control (e.g., xtls-rprx-vision)")
    sni: Optional[str] = Field(None, description="SNI for TLS/Reality")
    public_key: Optional[str] = Field(None, description="Reality public key")
    short_id: Optional[str] = Field(None, description="Reality shortId")
    fingerprint: Optional[str] = Field(None, description="TLS fingerprint")

    class Config:
        json_schema_extra = {
            "example": {
                "id": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
                "email": "user@example.com",
                "protocol": "vless_reality",
                "transport": "tcp",
                "security": "reality",
                "connection_link": "vless://uuid@1.2.3.4:443?type=tcp&security=reality...",
                "port": 443,
                "server_address": "1.2.3.4",
                "flow": "xtls-rprx-vision",
                "sni": "www.microsoft.com",
            }
        }


class StatsResponse(BaseModel):
    """Response model for system statistics."""

    active_connections: int = Field(0, description="Current active connections", ge=0)
    total_profiles: int = Field(0, description="Total configured profiles", ge=0)
    uptime_seconds: int = Field(0, description="Server uptime in seconds", ge=0)
    total_traffic_bytes: int = Field(0, description="Total traffic processed", ge=0)
    cpu_usage_percent: Optional[float] = Field(None, ge=0, le=100)
    memory_usage_percent: Optional[float] = Field(None, ge=0, le=100)


class SystemInfo(BaseModel):
    """Response model for system information."""

    xray_version: str = Field(..., description="Installed Xray version")
    os_name: str = Field(..., description="Operating system name")
    os_version: str = Field(..., description="OS version")
    kernel_version: str = Field(..., description="Kernel version")
    python_version: str = Field(..., description="Python runtime version")
    dashboard_version: str = Field("1.0.0", description="Dashboard version")
    active_protocol: ProtocolType = Field(..., description="Currently configured protocol")
    bbr_enabled: bool = Field(False, description="TCP BBR status")


class BackupResponse(BaseModel):
    """Response model for backup operations."""

    backup_file: str = Field(..., description="Path to backup file")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    size_bytes: int = Field(..., description="Backup file size", ge=0)
    config_hash: str = Field(..., description="SHA256 hash of config")


class XrayInbound(BaseModel):
    """Xray inbound configuration model."""

    port: int = Field(..., ge=1, le=65535)
    protocol: str = Field(..., pattern="^(vless|vmess|trojan|shadowsocks)$")
    settings: Dict[str, Any]
    streamSettings: Dict[str, Any]
    sniffing: Optional[Dict[str, Any]] = None
    tag: Optional[str] = None


class XrayConfig(BaseModel):
    """Complete Xray configuration model."""

    log: Dict[str, Any]
    dns: Optional[Dict[str, Any]] = None
    inbounds: List[XrayInbound]
    outbounds: List[Dict[str, Any]]
    routing: Optional[Dict[str, Any]] = None
    policy: Optional[Dict[str, Any]] = None
    stats: Optional[Dict[str, Any]] = None

    @field_validator("inbounds")
    @classmethod
    def validate_inbounds(cls, v: List[XrayInbound]) -> List[XrayInbound]:
        """Ensure at least one inbound is present."""
        if not v:
            raise ValueError("At least one inbound configuration is required")
        return v