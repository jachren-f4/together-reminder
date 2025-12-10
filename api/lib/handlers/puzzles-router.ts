/**
 * Puzzles Router - Routes /api/puzzles/* requests
 */

import { NextRequest, NextResponse } from 'next/server';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

// MIME types for common image formats
const MIME_TYPES: Record<string, string> = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
};

/**
 * Route GET requests for puzzle endpoints
 */
export async function routePuzzlesGET(req: NextRequest, subPath: string[]): Promise<NextResponse> {
  try {
    // Route: /api/puzzles/images/{puzzleId}/{filename}
    if (subPath[0] === 'images' && subPath.length === 3) {
      return handleImageRequest(subPath[1], subPath[2]);
    }

    return NextResponse.json(
      { error: 'Not found' },
      { status: 404 }
    );
  } catch (error) {
    console.error('Error in puzzles route:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

/**
 * Handle puzzle image requests
 * GET /api/puzzles/images/{puzzleId}/{filename}
 */
async function handleImageRequest(
  puzzleId: string,
  filename: string
): Promise<NextResponse> {
  try {
    // Validate puzzleId format (alphanumeric and underscores only)
    if (!/^[a-zA-Z0-9_]+$/.test(puzzleId)) {
      return NextResponse.json(
        { error: 'Invalid puzzle ID' },
        { status: 400 }
      );
    }

    // Validate filename (prevent directory traversal)
    if (filename.includes('..') || filename.includes('/') || filename.includes('\\')) {
      return NextResponse.json(
        { error: 'Invalid filename' },
        { status: 400 }
      );
    }

    // Get file extension
    const ext = '.' + filename.split('.').pop()?.toLowerCase();
    const mimeType = MIME_TYPES[ext];

    if (!mimeType) {
      return NextResponse.json(
        { error: 'Unsupported image format' },
        { status: 400 }
      );
    }

    // Build path to image file
    const imagePath = join(process.cwd(), 'data', 'puzzles', puzzleId, 'images', filename);

    if (!existsSync(imagePath)) {
      return NextResponse.json(
        { error: 'Image not found' },
        { status: 404 }
      );
    }

    // Read and serve the image
    const imageBuffer = readFileSync(imagePath);

    return new NextResponse(imageBuffer, {
      status: 200,
      headers: {
        'Content-Type': mimeType,
        'Cache-Control': 'public, max-age=31536000, immutable', // Cache for 1 year
      },
    });
  } catch (error) {
    console.error('Error serving puzzle image:', error);
    return NextResponse.json(
      { error: 'Failed to serve image' },
      { status: 500 }
    );
  }
}
