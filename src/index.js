import { ObjectDetector, DrawingUtils, FilesetResolver } from '@mediapipe/tasks-vision';

class VisionAssistApp {
    constructor() {
        this.video = document.getElementById('video');
        this.startButton = document.getElementById('start-button');
        this.videoInput = document.getElementById('video-input');
        this.playVideoButton = document.getElementById('play-video');
        this.detectionInfo = document.getElementById('detection-info');
        this.detector = null;
        this.stream = null;
        this.isRunning = false;
        this.isCamera = false;
        this.canvas = document.createElement('canvas');
        this.canvas.style.display = 'none';
        document.body.appendChild(this.canvas);
        this.canvasCtx = this.canvas.getContext('2d');

        // Event listeners
        this.startButton.addEventListener('click', () => this.toggleCamera());
        this.videoInput.addEventListener('change', () => this.handleVideoUpload());
        this.playVideoButton.addEventListener('click', () => this.toggleVideo());
        
        // Initialize detector
        this.initializeDetector();
    }

    async handleVideoUpload() {
        const file = this.videoInput.files[0];
        if (file) {
            const videoUrl = URL.createObjectURL(file);
            this.video.src = videoUrl;
            this.playVideoButton.disabled = false;
            
            // Stop camera if it's running
            if (this.isCamera) {
                this.stopCamera();
            }
        }
    }

    async toggleVideo() {
        if (!this.isRunning) {
            this.isCamera = false;
            this.isRunning = true;
            this.playVideoButton.textContent = 'Stop Video';
            await this.video.play();
            this.detectObjects();
        } else {
            this.isRunning = false;
            this.video.pause();
            this.playVideoButton.textContent = 'Play Video';
        }
    }

    async toggleCamera() {
        if (!this.isRunning) {
            await this.startCamera();
        } else {
            this.stopCamera();
        }
    }

    async startCamera() {
        try {
            this.stream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'environment' }
            });

            this.video.srcObject = this.stream;
            this.video.playsInline = true;

            await new Promise((resolve) => {
                this.video.onloadedmetadata = () => resolve();
            });

            await this.video.play();
            this.isCamera = true;
            this.isRunning = true;
            this.startButton.textContent = 'Stop Camera';
            this.playVideoButton.disabled = true;
            this.detectObjects();
        } catch (error) {
            console.error('Error starting camera:', error);
            alert('Error accessing camera. Please ensure camera permissions are granted.');
        }
    }

    stopCamera() {
        if (this.stream) {
            this.stream.getTracks().forEach(track => track.stop());
            this.video.srcObject = null;
            this.isRunning = false;
            this.isCamera = false;
            this.startButton.textContent = 'Start Camera';
            this.playVideoButton.disabled = false;
        }
    }

    async initializeDetector() {
        const vision = await FilesetResolver.forVisionTasks(
            "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.2/wasm"
          );

        this.detector = await ObjectDetector.createFromOptions(vision, {
            baseOptions: {
                modelAssetPath: "https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/float16/1/efficientdet_lite0.tflite",
                delegate: "GPU"
            },
            scoreThreshold: 0.5,
            maxResults: 20
        });
    }

    async detectObjects() {
        if (!this.isRunning || !this.video.videoWidth) return;

        try {
            // Set canvas dimensions to match video
            this.canvas.width = this.video.videoWidth;
            this.canvas.height = this.video.videoHeight;

            // Draw the video frame on the canvas
            this.canvasCtx.drawImage(this.video, 0, 0, this.canvas.width, this.canvas.height);

            // Detect objects using the canvas
            const results = this.detector.detect(this.canvas);
            this.updateDetectionInfo(results);

            // Continue detection loop with a slight delay to reduce CPU usage
            if (this.isRunning) {
                setTimeout(() => {
                    requestAnimationFrame(() => this.detectObjects());
                }, 1); // Add a 100ms delay between frames
            }
        } catch (error) {
            console.error('Error during detection:', error);
        }
    }

    updateDetectionInfo(results) {
        if (!results || !results.detections) return;

        // Clear previous detections
        this.detectionInfo.innerHTML = '';
        
        // Clear previous highlights
        const highlights = document.querySelectorAll('.highlighter, .detection-label');
        highlights.forEach(el => el.remove());
        
        results.detections.forEach((detection) => {
            const category = detection.categories[0];
            const confidence = Math.round(category.score * 100);
            const boundingBox = detection.boundingBox;
            
            // Calculate how much of the frame the object occupies
            const objectArea = boundingBox.width * boundingBox.height;
            const frameArea = this.video.videoWidth * this.video.videoHeight;
            const areaRatio = objectArea / frameArea;
            
            // Determine proximity and color based on area ratio
            let proximityColor;
            let proximityText;
            if (areaRatio > 0.2) { // Very close - red
                proximityColor = 'rgba(255, 0, 0, 0.4)';
                proximityText = 'VERY CLOSE!';
            } else if (areaRatio > 0.1) { // Moderately close - yellow
                proximityColor = 'rgba(255, 255, 0, 0.4)';
                proximityText = 'Getting Close';
            } else { // Far - green
                proximityColor = 'rgba(0, 255, 0, 0.25)';
                proximityText = 'Safe Distance';
            }
            
            // Create highlight box with proximity-based color
            const highlighter = document.createElement('div');
            highlighter.className = 'highlighter';
            highlighter.style.left = `${boundingBox.originX}px`;
            highlighter.style.top = `${boundingBox.originY}px`;
            highlighter.style.width = `${boundingBox.width}px`;
            highlighter.style.height = `${boundingBox.height}px`;
            highlighter.style.background = proximityColor;
            highlighter.style.borderColor = areaRatio > 0.4 ? '#ff0000' : '#ffffff';
            
            // Create label with proximity warning
            const label = document.createElement('div');
            label.className = 'detection-label';
            label.innerHTML = `
                ${category.categoryName} (${confidence}%)<br>
                <span style="color: ${areaRatio > 0.4 ? '#ff0000' : '#ffffff'}">${proximityText}</span>
            `;
            label.style.left = `${boundingBox.originX}px`;
            label.style.top = `${boundingBox.originY - 40}px`; // Adjusted for two lines
            
            // Add highlights to container
            document.getElementById('container').appendChild(highlighter);
            document.getElementById('container').appendChild(label);
            
            // Add to detection info panel with proximity warning
            const detectionElement = document.createElement('div');
            detectionElement.className = 'detection-item';
            detectionElement.style.backgroundColor = areaRatio > 0.4 ? 'rgba(255, 0, 0, 0.2)' : 'rgba(255, 255, 255, 0.1)';
            detectionElement.innerHTML = `
                <strong>${category.categoryName}</strong><br>
                Confidence: ${confidence}%<br>
                Distance: ${proximityText}<br>
                Location: ${Math.round(boundingBox.originX * 100)}% from left, 
                         ${Math.round(boundingBox.originY * 100)}% from top
            `;
            
            this.detectionInfo.appendChild(detectionElement);
        });
    }

    // Add event listener for video ending
    setupVideoEndHandler() {
        this.video.addEventListener('ended', () => {
            if (!this.isCamera) {
                this.isRunning = false;
                this.playVideoButton.textContent = 'Play Video';
            }
        });
    }
}

// Initialize the app when the page loads
window.addEventListener('load', () => {
    new VisionAssistApp();
}); 