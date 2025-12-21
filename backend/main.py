#!/usr/bin/env python3
"""FastAPI application for Xray profile management.

Provides REST API for:
- Profile CRUD operations
- QR code generation
- Statistics retrieval
- Configuration backup/restore
"""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import List

from fastapi import FastAPI, HTTPException, Query, status
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from .models import (
    ProfileCreate,
    ProfileResponse,
    StatsResponse,
    SystemInfo,
    BackupResponse,
)
from .config_manager import ConfigManager
from .utils import generate_qr_code, get_server_ip, restart_xray_service

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

# Initialize FastAPI
app = FastAPI(
    title="Xray Dashboard API",
    description="Multi-protocol VPN management system",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
)

# CORS middleware for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize config manager
config_manager = ConfigManager()

# Health check
@app.get("/api/health")
async def health_check() -> dict:
    """Health check endpoint."""
    return {"status": "healthy", "version": "1.0.0"}


# Profile Management
@app.get("/api/profiles", response_model=List[ProfileResponse])
async def list_profiles() -> List[ProfileResponse]:
    """List all active profiles.
    
    Returns:
        List of profile objects with metadata.
    """
    try:
        profiles = await config_manager.get_all_profiles()
        return profiles
    except Exception as e:
        logger.error(f"Failed to list profiles: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve profiles: {str(e)}",
        )


@app.post("/api/profiles", response_model=ProfileResponse, status_code=status.HTTP_201_CREATED)
async def create_profile(
    email: str = Query(..., description="User email for profile identification"),
) -> ProfileResponse:
    """Create new VPN profile.
    
    Args:
        email: User identifier (used in client list).
    
    Returns:
        Created profile with connection details.
    """
    try:
        profile = await config_manager.create_profile(email=email)
        
        # Restart Xray to apply changes
        restart_success = await restart_xray_service()
        if not restart_success:
            logger.warning("Profile created but Xray restart failed")
        
        return profile
    except Exception as e:
        logger.error(f"Failed to create profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create profile: {str(e)}",
        )


@app.get("/api/profiles/{profile_id}", response_model=ProfileResponse)
async def get_profile(profile_id: str) -> ProfileResponse:
    """Get specific profile by UUID.
    
    Args:
        profile_id: Profile UUID.
    
    Returns:
        Profile details.
    """
    try:
        profile = await config_manager.get_profile(profile_id)
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Profile {profile_id} not found",
            )
        return profile
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get profile {profile_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


@app.delete("/api/profiles/{profile_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_profile(profile_id: str) -> None:
    """Delete profile by UUID.
    
    Args:
        profile_id: Profile UUID to delete.
    """
    try:
        deleted = await config_manager.delete_profile(profile_id)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Profile {profile_id} not found",
            )
        
        # Restart Xray
        await restart_xray_service()
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete profile {profile_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


@app.get("/api/profiles/{profile_id}/qr")
async def get_qr_code(profile_id: str) -> StreamingResponse:
    """Generate QR code for profile.
    
    Args:
        profile_id: Profile UUID.
    
    Returns:
        PNG image stream.
    """
    try:
        profile = await config_manager.get_profile(profile_id)
        if not profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Profile {profile_id} not found",
            )
        
        qr_bytes = await generate_qr_code(profile.connection_link)
        
        return StreamingResponse(
            iter([qr_bytes.getvalue()]),
            media_type="image/png",
            headers={
                "Content-Disposition": f"inline; filename=qr_{profile_id[:8]}.png"
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate QR for {profile_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


# Statistics
@app.get("/api/stats", response_model=StatsResponse)
async def get_stats() -> StatsResponse:
    """Get server statistics.
    
    Returns:
        System metrics and connection stats.
    """
    try:
        stats = await config_manager.get_statistics()
        return stats
    except Exception as e:
        logger.error(f"Failed to retrieve stats: {e}")
        # Return default stats on error
        return StatsResponse(
            active_connections=0,
            total_profiles=0,
            uptime_seconds=0,
            total_traffic_bytes=0,
        )


# System Info
@app.get("/api/system", response_model=SystemInfo)
async def get_system_info() -> SystemInfo:
    """Get system information.
    
    Returns:
        OS details, Xray version, protocol info.
    """
    try:
        info = await config_manager.get_system_info()
        return info
    except Exception as e:
        logger.error(f"Failed to get system info: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


# Configuration Backup
@app.get("/api/backup", response_model=BackupResponse)
async def create_backup() -> BackupResponse:
    """Create configuration backup.
    
    Returns:
        Backup metadata with file path.
    """
    try:
        backup_info = await config_manager.create_backup()
        return backup_info
    except Exception as e:
        logger.error(f"Failed to create backup: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


@app.post("/api/restore")
async def restore_backup(
    backup_file: str = Query(..., description="Backup file path")
) -> dict:
    """Restore configuration from backup.
    
    Args:
        backup_file: Path to backup file.
    
    Returns:
        Restore status.
    """
    try:
        success = await config_manager.restore_backup(backup_file)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to restore backup",
            )
        
        await restart_xray_service()
        return {"status": "restored", "backup_file": backup_file}
    except Exception as e:
        logger.error(f"Failed to restore backup: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


# Mount static files (frontend)
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="static")
    logger.info(f"Frontend mounted from {frontend_path}")
else:
    logger.warning(f"Frontend directory not found: {frontend_path}")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info",
    )