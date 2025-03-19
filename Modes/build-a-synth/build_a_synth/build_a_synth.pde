import processing.sound.*;

// Audio analysis components
FFT fft;
AudioIn audio;
Amplitude amp;

int bands = 512;
float[] spectrum = new float[bands];
float[] lastSpectrum = new float[bands]; // Previous frame spectrum
float[] smoothedSpectrum = new float[bands];
float smoothingFactor = 0.2;
float scale = 30; // Reduced from 50 to 30 for more balanced visualization

// Audio activity detection
float globalVolume = 0;
float volumeThreshold = 0.001; // DECREASED from 0.01 to be more sensitive
boolean audioActive = false;
int silenceCounter = 0;
int activityCounter = 0;

// Visual style options
boolean showFreqMarkers = true;
boolean useLogarithmicScale = true;
boolean showSpectralFlux = true;

// Synth parameters (would be received from SuperCollider)
String waveName = "Sine";
String filterName = "None";
String fx1Name = "None";
String fx2Name = "None";
float attackValue = 0.4;
float releaseValue = 0.7;
float currentAmp = 0.5;

// Performance tracking
int frameCounter = 0;
float avgFrameRate = 60;

void setup() {
  size(1024, 768, P2D);
  background(0);
  frameRate(60);
  
  // Initialize arrays
  for (int i = 0; i < bands; i++) {
    spectrum[i] = 0;
    lastSpectrum[i] = 0;
    smoothedSpectrum[i] = 0;
  }
  
  try {
    // Initialize audio input and boost input level
    audio = new AudioIn(this, 0);
    audio.amp(5); // ADDED amplification to input signal
    audio.start();
    
    // Initialize amplitude analysis
    amp = new Amplitude(this);
    amp.input(audio);
    
    // Initialize FFT analysis
    fft = new FFT(this, bands);
    fft.input(audio);
    
    println("Audio processing initialized");
  } catch (Exception e) {
    println("Error initializing audio: " + e.getMessage());
    println("Will continue with visualization only");
  }
  
  // Set font
  textFont(createFont("Arial", 14));
  
  println("Audio Visualizer started");
  println("Keyboard controls:");
  println("  F: Toggle frequency markers");
  println("  L: Toggle logarithmic/linear scale");
  println("  S: Toggle spectral flux visualization");
}

void draw() {
  // Black background with fade for trails
  fill(0, 30);
  rect(0, 0, width, height);
  
  // Calculate global amplitude and detect activity
  updateAudioActivity();
  
  // Get new spectrum data
  if (fft != null) {
    // Save last frame's spectrum
    System.arraycopy(spectrum, 0, lastSpectrum, 0, bands);
    // Analyze new spectrum
    fft.analyze(spectrum);
  }
  
  // Draw the spectrum visualization
  drawSpectrum();
  
  // Draw settings panel
  drawSettings();
  
  // Update performance tracking
  updatePerformanceStats();
}

void updateAudioActivity() {
  if (amp != null) {
    // Get current volume
    globalVolume = amp.analyze();
    
    // Detect audio activity
    if (globalVolume > volumeThreshold) {
      activityCounter++;
      silenceCounter = 0;
      if (activityCounter > 10) {
        audioActive = true;
      }
    } else {
      silenceCounter++;
      activityCounter = 0;
      if (silenceCounter > 30) {
        audioActive = false;
      }
    }
  }
}

void drawSpectrum() {
  // Smooth the spectrum data
  for (int i = 0; i < bands; i++) {
    smoothedSpectrum[i] = lerp(smoothedSpectrum[i], spectrum[i], smoothingFactor);
  }
  
  // Set visualization dimensions
  int visWidth = int(width * 0.8);
  int visHeight = int(height * 0.5);
  int visX = (width - visWidth) / 2;
  int visY = (height - visHeight) / 2 - 30;
  
  // Draw visualization background
  noStroke();
  fill(10);
  rect(visX, visY, visWidth, visHeight);
  
  // Only draw frequency bins up to 22kHz (human hearing)
  int maxBin = useLogarithmicScale ? bands - 1 : min(bands - 1, bands / 2);
  float binWidth = visWidth / float(maxBin);
  
  // Draw frequency markers if enabled
  if (showFreqMarkers) {
    drawFrequencyMarkers(visX, visY, visWidth, visHeight);
  }
  
  // Draw amplitude guides
  stroke(40);
  strokeWeight(1);
  for (int i = 1; i < 4; i++) {
    float y = visY + visHeight * (1 - i/4.0);
    line(visX, y, visX + visWidth, y);
  }
  
  // Draw spectral flux (difference between current and last frame) if enabled
  if (showSpectralFlux) {
    drawSpectralFlux(visX, visY, visWidth, visHeight);
  }
  
  // Draw main spectrum bars
  stroke(255);
  strokeWeight(2);
  
  for (int i = 0; i < maxBin; i++) {
    // Skip some bands for performance
    if (maxBin > 200 && i % 2 != 0) continue;
    
    // Calculate x position based on frequency
    float x;
    
    if (useLogarithmicScale) {
      // Logarithmic scale emphasizes lower frequencies
      float normalizedBin = map(i, 0, maxBin, 0, 1);
      float logBin = pow(normalizedBin, 0.4); // Adjust exponent for log scale shape
      x = map(logBin, 0, 1, visX, visX + visWidth);
    } else {
      // Linear scale
      x = visX + (i * binWidth);
    }
    
    // Calculate amplitude with frequency-dependent scaling
    float frequencyScaling = map(i, 0, maxBin, 6.0, 1.5); // Reduced scaling factors for better balance
    float value = smoothedSpectrum[i] * frequencyScaling * scale;
    
    // Apply non-linear scaling to make small values more visible
    value = pow(value, 0.8); // Slightly reduced non-linear scaling (0.7 to 0.8)
    
    // Calculate bar height
    float barHeight = map(value, 0, 0.5, 0, visHeight);
    barHeight = constrain(barHeight, 0, visHeight);
    
    // Calculate brightness based on amplitude
    int brightness = constrain(int(value * 500), 100, 255);
    
    // Draw line from bottom to height
    stroke(brightness);
    line(x, visY + visHeight, x, visY + visHeight - barHeight);
  }
  
  // Draw audio activity indicator
  noStroke();
  fill(audioActive ? color(0, 255, 0, 100) : color(255, 0, 0, 50));
  ellipse(width - 30, height - 100, 15, 15);
}

void drawFrequencyMarkers(int visX, int visY, int visWidth, int visHeight) {
  String[] freqLabels = {"50", "100", "200", "500", "1k", "2k", "5k", "10k", "20k"};
  float[] freqValues = {50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000};
  
  for (int i = 0; i < freqLabels.length; i++) {
    // Map frequency to position
    float x;
    
    if (useLogarithmicScale) {
      // Logarithmic scale
      float nyquist = 22050; // Half the standard sample rate
      float normalizedFreq = freqValues[i] / nyquist;
      float logFreq = pow(normalizedFreq, 0.4); // Match the main visualization
      x = map(logFreq, 0, 1, visX, visX + visWidth);
    } else {
      // Linear scale
      x = map(freqValues[i], 0, 22050, visX, visX + visWidth);
    }
    
    // If in visible range, draw marker
    if (x >= visX && x <= visX + visWidth) {
      stroke(40);
      strokeWeight(1);
      line(x, visY, x, visY + visHeight);
      
      fill(150);
      noStroke();
      textSize(10);
      textAlign(CENTER, TOP);
      text(freqLabels[i], x, visY + visHeight + 5);
    }
  }
}

void drawSpectralFlux(int visX, int visY, int visWidth, int visHeight) {
  strokeWeight(1);
  stroke(100, 100, 255, 100);
  
  for (int i = 1; i < bands - 1; i++) {
    // Skip some bands for performance
    if (i % 2 != 0) continue;
    
    // Calculate x position
    float x;
    if (useLogarithmicScale) {
      float normalizedBin = map(i, 0, bands - 1, 0, 1);
      float logBin = pow(normalizedBin, 0.4);
      x = map(logBin, 0, 1, visX, visX + visWidth);
    } else {
      x = map(i, 0, bands/2, visX, visX + visWidth);
    }
    
    // Calculate flux (difference between current and previous frame)
    float flux = max(0, spectrum[i] - lastSpectrum[i]);
    
    // Scale and draw
    float fluxHeight = flux * visHeight * 35; // Reduced from 50 to 35
    fluxHeight = constrain(fluxHeight, 0, visHeight);
    
    line(x, visY + visHeight - fluxHeight, x, visY + visHeight);
  }
}

void drawSettings() {
  // Draw panel background
  fill(0, 180);
  noStroke();
  rect(0, height - 120, width, 120);
  
  // Draw current settings
  fill(255);
  textSize(14);
  textAlign(LEFT, TOP);
  int leftCol = 30;
  int rightCol = width/2 + 30;
  int yPos = height - 110;
  
  // Title
  textSize(16);
  fill(255, 200);
  text("Build-A-Synth Audio Visualizer", leftCol, yPos);
  yPos += 25;
  textSize(14);
  
  // Left column
  fill(200);
  text("Wave:", leftCol, yPos);
  fill(255);
  text(waveName, leftCol + 80, yPos);
  
  fill(200);
  text("Filter:", leftCol, yPos + 25);
  fill(255);
  text(filterName, leftCol + 80, yPos + 25);
  
  fill(200);
  text("FX 1:", leftCol, yPos + 50);
  fill(255);
  text(fx1Name, leftCol + 80, yPos + 50);
  
  fill(200);
  text("FX 2:", leftCol, yPos + 75);
  fill(255);
  text(fx2Name, leftCol + 80, yPos + 75);
  
  // Right column
  fill(200);
  text("Attack:", rightCol, yPos);
  fill(255);
  text(nf(attackValue, 0, 2) + " s", rightCol + 80, yPos);
  
  fill(200);
  text("Release:", rightCol, yPos + 25);
  fill(255);
  text(nf(releaseValue, 0, 2) + " s", rightCol + 80, yPos + 25);
  
  fill(200);
  text("Amplitude:", rightCol, yPos + 50);
  fill(255);
  text(nf(currentAmp, 0, 2), rightCol + 80, yPos + 50);
  
  // Audio status
  fill(200);
  text("Audio:", rightCol, yPos + 75);
  fill(audioActive ? color(100, 255, 100) : color(255, 100, 100));
  text(audioActive ? "Active" : "Inactive", rightCol + 80, yPos + 75);
  
  // Performance info in top-right
  fill(150);
  textAlign(RIGHT, TOP);
  textSize(12);
  text("FPS: " + nf(avgFrameRate, 0, 1), width - 20, 20);
  text("Scale: " + (useLogarithmicScale ? "Log" : "Linear"), width - 20, 40);
}

void updatePerformanceStats() {
  // Update frame rate tracking
  frameCounter++;
  if (frameCounter >= 30) {
    avgFrameRate = frameRate;
    frameCounter = 0;
  }
}

void keyPressed() {
  if (key == 'f' || key == 'F') {
    showFreqMarkers = !showFreqMarkers;
    println("Frequency markers: " + (showFreqMarkers ? "ON" : "OFF"));
  }
  else if (key == 'l' || key == 'L') {
    useLogarithmicScale = !useLogarithmicScale;
    println("Scale: " + (useLogarithmicScale ? "Logarithmic" : "Linear"));
  }
  else if (key == 's' || key == 'S') {
    showSpectralFlux = !showSpectralFlux;
    println("Spectral flux: " + (showSpectralFlux ? "ON" : "OFF"));
  }
  else if (key == '+' || key == '=') {
    scale *= 1.5; // Increased multiplier from 1.2 to 1.5
    println("Scale increased to: " + nf(scale, 0, 1));
  }
  else if (key == '-' || key == '_') {
    scale /= 1.5; // Increased divisor from 1.2 to 1.5
    println("Scale decreased to: " + nf(scale, 0, 1));
  }
  else if (key == 'n' || key == 'N') {
    println("Noise floor temporarily added (hold key)");
  }
}

// Clean up resources when closing
void dispose() {
  if (audio != null) {
    audio.stop();
  }
  println("Audio resources released");
}
