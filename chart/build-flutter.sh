#!/bin/bash

# Script to build Flutter web app and copy to web/public/flutter

set -e  # Exit on error

echo "🔨 Building Flutter web app..."

# Navigate to Flutter project directory
cd chart_flutter

# Build Flutter web with base-href set to /flutter/
flutter build web --base-href="/flutter/" --wasm  --release #--debug

echo "✅ Flutter build completed"

# Navigate back to root
cd ..

echo "📦 Copying build to web/public/flutter..."

# Remove existing flutter folder if it exists
if [ -d "web/public/flutter" ]; then
    rm -rf web/public/flutter
fi

# Create the directory if it doesn't exist
mkdir -p web/public

# Copy the build output to web/public/flutter
cp -r chart_flutter/build/web web/public/flutter

echo "✅ Build copied successfully to web/public/flutter"
echo "🎉 Done! Your Flutter app is ready at web/public/flutter"
