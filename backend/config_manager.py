"""Xray configuration management with atomic operations."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
from uuid import uuid4

import aiofiles

from .models import (
    BackupResponse,
    ProfileResponse,
    ProtocolType,
    SecurityType,
    StatsResponse,
    SystemInfo,
    TransportType,
)
from .utils import get_server_ip, generate_uuid

logger = logging.getLogger(__name__)


class ConfigManager:
    """Manages Xray configuration with atomic writes and validation."""

    def __init__(
        self,
        config_path: str = "/usr/local/etc/xray/config.json",
        backup_dir: str = "/var/backups/xray",
    ):
        self.config_path = Path(config_path)
        self.backup_dir = Path(backup_dir)
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.lock = asyncio.Lock()

    async def _read_config(self) -> Dict[str, Any]:
        """Read Xray configuration file asynchronously."""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Config not found: {self.config_path}")

        async with aiofiles.open(self.config_path, "r") as f:
            content = await f.read()
            return json.loads(content)

    async def _write_config(self, config: Dict[str, Any]) -> None:
        """Write configuration with atomic operation."""
        # Validate config first
        await self._validate_config(config)

        # Write to temp file
        temp_path = self.config_path.with_suffix(".tmp")
        async with aiofiles.open(temp_path, "w") as f:
            await f.write(json.dumps(config, indent=2))

        # Atomic move
        temp_path.replace(self.config_path)
        logger.info(f"Configuration written to {self.config_path}")

    async def _validate_config(self, config: Dict[str, Any]) -> bool:
        """Validate Xray configuration using xray -test."""
        temp_path = Path("/tmp/xray_test_config.json")
        
        try:
            async with aiofiles.open(temp_path, "w") as f:
                await f.write(json.dumps(config))

            process = await asyncio.create_subprocess_exec(
                "/usr/local/bin/xray",
                "-test",
                "-config",
                str(temp_path),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                error_msg = stderr.decode() if stderr else "Unknown error"
                logger.error(f"Config validation failed: {error_msg}")
                raise ValueError(f"Invalid Xray config: {error_msg}")

            return True
        finally:
            if temp_path.exists():
                temp_path.unlink()

    async def get_all_profiles(self) -> List[ProfileResponse]:
        """Get all configured profiles."""
        async with self.lock:
            config = await self._read_config()
            inbound = config["inbounds"][0]
            clients = inbound["settings"].get("clients", [])
            
            server_ip = await get_server_ip()
            port = inbound["port"]
            
            # Determine protocol and transport
            protocol_type = self._detect_protocol(inbound)
            transport = self._detect_transport(inbound)
            security = self._detect_security(inbound)

            profiles = []
            for client in clients:
                profile = await self._build_profile_response(
                    client=client,
                    inbound=inbound,
                    server_ip=server_ip,
                    port=port,
                    protocol_type=protocol_type,
                    transport=transport,
                    security=security,
                )
                profiles.append(profile)

            return profiles

    async def get_profile(self, profile_id: str) -> Optional[ProfileResponse]:
        """Get specific profile by UUID."""
        profiles = await self.get_all_profiles()
        for profile in profiles:
            if profile.id == profile_id:
                return profile
        return None

    async def create_profile(self, email: str) -> ProfileResponse:
        """Create new profile with generated UUID."""
        async with self.lock:
            config = await self._read_config()
            inbound = config["inbounds"][0]
            
            # Generate new client
            new_uuid = generate_uuid()
            new_client = {
                "id": new_uuid,
                "email": email,
            }
            
            # Add flow if protocol supports it
            protocol_type = self._detect_protocol(inbound)
            if protocol_type == ProtocolType.VLESS_REALITY:
                new_client["flow"] = "xtls-rprx-vision"

            # Add to clients list
            inbound["settings"]["clients"].append(new_client)
            
            # Write updated config
            await self._write_config(config)
            
            # Return profile response
            server_ip = await get_server_ip()
            port = inbound["port"]
            transport = self._detect_transport(inbound)
            security = self._detect_security(inbound)
            
            return await self._build_profile_response(
                client=new_client,
                inbound=inbound,
                server_ip=server_ip,
                port=port,
                protocol_type=protocol_type,
                transport=transport,
                security=security,
            )

    async def delete_profile(self, profile_id: str) -> bool:
        """Delete profile by UUID."""
        async with self.lock:
            config = await self._read_config()
            inbound = config["inbounds"][0]
            clients = inbound["settings"].get("clients", [])
            
            original_count = len(clients)
            filtered_clients = [c for c in clients if c["id"] != profile_id]
            
            if len(filtered_clients) == original_count:
                return False  # Profile not found
            
            inbound["settings"]["clients"] = filtered_clients
            await self._write_config(config)
            
            logger.info(f"Deleted profile {profile_id}")
            return True

    async def get_statistics(self) -> StatsResponse:
        """Get server statistics."""
        try:
            config = await self._read_config()
            total_profiles = len(config["inbounds"][0]["settings"].get("clients", []))
            
            # Get uptime
            uptime = await self._get_xray_uptime()
            
            return StatsResponse(
                active_connections=0,  # TODO: Implement via Xray Stats API
                total_profiles=total_profiles,
                uptime_seconds=uptime,
                total_traffic_bytes=0,  # TODO: Implement via Xray Stats API
            )
        except Exception as e:
            logger.error(f"Failed to get stats: {e}")
            return StatsResponse()

    async def get_system_info(self) -> SystemInfo:
        """Get system information."""
        # Get Xray version
        process = await asyncio.create_subprocess_exec(
            "/usr/local/bin/xray",
            "version",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await process.communicate()
        xray_version = stdout.decode().split("\n")[0].split()[-1] if stdout else "unknown"
        
        # Get OS info
        os_name = platform.system()
        os_version = platform.release()
        kernel_version = platform.version()
        python_version = sys.version.split()[0]
        
        # Check BBR
        bbr_enabled = await self._check_bbr()
        
        # Detect protocol
        config = await self._read_config()
        active_protocol = self._detect_protocol(config["inbounds"][0])
        
        return SystemInfo(
            xray_version=xray_version,
            os_name=os_name,
            os_version=os_version,
            kernel_version=kernel_version,
            python_version=python_version,
            active_protocol=active_protocol,
            bbr_enabled=bbr_enabled,
        )

    async def create_backup(self) -> BackupResponse:
        """Create configuration backup."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = self.backup_dir / f"config_backup_{timestamp}.json"
        
        # Copy config
        shutil.copy2(self.config_path, backup_file)
        
        # Calculate hash
        async with aiofiles.open(backup_file, "rb") as f:
            content = await f.read()
            config_hash = hashlib.sha256(content).hexdigest()
        
        size_bytes = backup_file.stat().st_size
        
        logger.info(f"Backup created: {backup_file}")
        
        return BackupResponse(
            backup_file=str(backup_file),
            size_bytes=size_bytes,
            config_hash=config_hash,
        )

    async def restore_backup(self, backup_file: str) -> bool:
        """Restore configuration from backup."""
        backup_path = Path(backup_file)
        
        if not backup_path.exists():
            raise FileNotFoundError(f"Backup not found: {backup_file}")
        
        # Validate backup before restoring
        async with aiofiles.open(backup_path, "r") as f:
            content = await f.read()
            config = json.loads(content)
        
        await self._validate_config(config)
        
        # Create safety backup of current config
        await self.create_backup()
        
        # Restore
        shutil.copy2(backup_path, self.config_path)
        
        logger.info(f"Configuration restored from {backup_file}")
        return True

    # Helper methods
    def _detect_protocol(self, inbound: Dict[str, Any]) -> ProtocolType:
        """Detect protocol type from inbound config."""
        protocol = inbound.get("protocol", "").lower()
        stream_settings = inbound.get("streamSettings", {})
        security = stream_settings.get("security", "none")
        network = stream_settings.get("network", "tcp")
        
        if protocol == "vless":
            if security == "reality":
                return ProtocolType.VLESS_REALITY
            elif network == "xhttp":
                return ProtocolType.VLESS_XHTTP
            else:
                return ProtocolType.VLESS_WS
        elif protocol == "vmess":
            return ProtocolType.VMESS_WS
        elif protocol == "trojan":
            return ProtocolType.TROJAN_XTLS
        
        return ProtocolType.VLESS_REALITY  # Default

    def _detect_transport(self, inbound: Dict[str, Any]) -> TransportType:
        """Detect transport type."""
        network = inbound.get("streamSettings", {}).get("network", "tcp")
        return TransportType(network)

    def _detect_security(self, inbound: Dict[str, Any]) -> SecurityType:
        """Detect security type."""
        security = inbound.get("streamSettings", {}).get("security", "none")
        return SecurityType(security)

    async def _build_profile_response(
        self,
        client: Dict[str, Any],
        inbound: Dict[str, Any],
        server_ip: str,
        port: int,
        protocol_type: ProtocolType,
        transport: TransportType,
        security: SecurityType,
    ) -> ProfileResponse:
        """Build ProfileResponse from client data."""
        client_id = client["id"]
        email = client.get("email")
        
        # Build connection link based on protocol
        connection_link = await self._generate_connection_link(
            client_id=client_id,
            server_ip=server_ip,
            port=port,
            protocol_type=protocol_type,
            inbound=inbound,
            email=email or "user",
        )
        
        # Extract protocol-specific fields
        flow = client.get("flow")
        reality_settings = inbound.get("streamSettings", {}).get("realitySettings", {})
        sni = reality_settings.get("serverNames", [None])[0] if reality_settings else None
        short_id = reality_settings.get("shortIds", [None])[0] if reality_settings else None
        
        return ProfileResponse(
            id=client_id,
            email=email,
            protocol=protocol_type,
            transport=transport,
            security=security,
            connection_link=connection_link,
            port=port,
            server_address=server_ip,
            flow=flow,
            sni=sni,
            short_id=short_id,
        )

    async def _generate_connection_link(
        self,
        client_id: str,
        server_ip: str,
        port: int,
        protocol_type: ProtocolType,
        inbound: Dict[str, Any],
        email: str,
    ) -> str:
        """Generate VLESS/VMess connection link."""
        if protocol_type == ProtocolType.VLESS_REALITY:
            reality_settings = inbound["streamSettings"]["realitySettings"]
            # Note: public key needs to be computed from private key
            # For now, return placeholder - implement key derivation
            sni = reality_settings["serverNames"][0]
            short_id = reality_settings["shortIds"][0]
            
            link = (
                f"vless://{client_id}@{server_ip}:{port}"
                f"?type=tcp&security=reality"
                f"&sni={sni}"
                f"&sid={short_id}"
                f"&flow=xtls-rprx-vision"
                f"#{email}"
            )
            return link
        
        elif protocol_type == ProtocolType.VLESS_WS:
            link = (
                f"vless://{client_id}@{server_ip}:{port}"
                f"?type=ws&security=none"
                f"#{email}"
            )
            return link
        
        # Add other protocols as needed
        return f"vless://{client_id}@{server_ip}:{port}#{email}"

    async def _get_xray_uptime(self) -> int:
        """Get Xray service uptime in seconds."""
        try:
            process = await asyncio.create_subprocess_exec(
                "systemctl",
                "show",
                "xray",
                "--property=ActiveEnterTimestamp",
                stdout=asyncio.subprocess.PIPE,
            )
            stdout, _ = await process.communicate()
            # Parse timestamp and calculate uptime
            # Simplified - return 0 for now
            return 0
        except Exception:
            return 0

    async def _check_bbr(self) -> bool:
        """Check if TCP BBR is enabled."""
        try:
            process = await asyncio.create_subprocess_exec(
                "sysctl",
                "net.ipv4.tcp_congestion_control",
                stdout=asyncio.subprocess.PIPE,
            )
            stdout, _ = await process.communicate()
            return b"bbr" in stdout
        except Exception:
            return False