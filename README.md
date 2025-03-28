# Vision Assist App

A mobile-friendly web application that uses MediaPipe Object Detection to help people with vision difficulties identify objects in their surroundings using their phone's camera.

## Features

- Real-time object detection using the device's back camera
- High-contrast, accessible interface
- Clear audio feedback of detected objects
- Mobile-optimized design
- Easy-to-use controls

## Setup

1. Install dependencies:

```bash
npm install
```

2. Start the development server:

```bash
npm start
```

3. Open the app in your mobile browser:
   - The app will be available at `http://localhost:9000`
   - For testing on your phone, you can use your computer's local IP address (e.g., `http://192.168.1.100:9000`)

## Usage

1. Open the app in your mobile browser
2. Grant camera permissions when prompted
3. Tap the "Start Camera" button to begin object detection
4. Point your phone's camera at objects in your surroundings
5. The app will display detected objects and their locations on screen
6. Tap "Stop Camera" to end the session

## Technical Requirements

- Modern mobile browser with camera support
- HTTPS connection (required for camera access)
- JavaScript enabled
- Camera permissions granted

## Accessibility Features

- High contrast interface
- Large, readable text
- Clear button controls
- Screen reader compatible
- Voice feedback for detected objects

## Development

To build for production:

```bash
npm run build
```

The built files will be in the `dist` directory.
