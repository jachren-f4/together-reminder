/**
 * Puzzle Image Serving Endpoint
 *
 * GET /api/puzzles/images/[puzzleId]/[filename]
 *
 * Serves images for puzzle clues from the data/puzzles/{puzzleId}/images/ directory
 */

import { NextRequest, NextResponse } from 'next/server';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

export const dynamic = 'force-dynamic';

// MIME types for common image formats
const MIME_TYPES: Record<string, string> = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
};

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ puzzleId: string; filename: string }> }
) {
  try {
    const { puzzleId, filename } = await params;

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
