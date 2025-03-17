import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress supercollider;

// Persistent buffers
PGraphics mainBuffer;
PGraphics textBuffer;
PGraphics scanlineTexture;

// Shader for background
PShader gradientShader;

// Visual parameters
float volume = 0;
float targetVolume = 0;
float centroid = 0;
float targetCentroid = 0;
float lastOnsetTime = 0;
float noiseTime = 0;
float colorBalance = 0.5;
float targetColorBalance = 0.5;
float targetChromAb = 0;

// Control Variables (adjust these to taste)
float NOISE_SPEED = 0.005;        // Reduced from 0.01 for smoother movement
float TEXT_FLOAT_SPEED = 0.005;   // Reduced from 0.01 for smoother floating
float TEXT_FLOAT_AMOUNT = 30;     // Amount of text float in pixels
float CHROME_AB_MAX = 15;         // Maximum chromatic aberration
float CHROME_AB_SMOOTH = 0.95;    // Smoothing for chromatic aberration (higher = slower)
float SCAN_LINE_SPEED = 0.5;      // Reduced from 0.8 for smoother movement
float NOISE_AMOUNT = 0.001;       // Amount of noise overlay
int NOISE_PARTICLES = 80;         // Reduced from 100 for less visual noise
float NOISE_ALPHA = 30;           // Reduced from 40 for subtler effect
int TEXT_UPDATE_RATE = 1;         // Update text every frame for smoother movement
float TEXT_SIZE = 120;            // Size of the text
float COLOR_BALANCE_INTENSITY = 2.0; // Scalar for color balance effect (0.0 - 2.0)

// Smoothing constants
float PARAM_SMOOTH_FACTOR = 0.05; // Lower value = smoother/slower transitions (0.0-1.0)
float COLOR_SMOOTH_FACTOR = 0.03; // Even slower transitions for color
float VOLUME_SMOOTH_FACTOR = 0.1; // Responsive but not jittery

// VHS effect parameters
float chromAberrationStrength = 0;
float scanLineOffset = 0;

// Text parameters
PFont font;
float textY = 0;
float targetTextY = 0;

// Noise particles with persistence
class NoiseParticle {
  float x, y, brightness, life;
  
  NoiseParticle() {
    reset();
    // Randomize initial life so all particles don't appear at once
    life = random(0, 1);
  }
  
  void reset() {
    x = random(width);
    y = random(height);
    brightness = random(100, 255);
    life = 1.0;
  }
  
  void update() {
    life -= random(0.01, 0.05);
    if (life <= 0) {
      reset();
    }
  }
  
  void display() {
    float alpha = NOISE_ALPHA * life;
    fill(brightness, alpha);
    rect(x, y, 2, 2);
  }
}

NoiseParticle[] particles;

void setup() {
  size(1280, 720, P2D);
  frameRate(60);
  
  // Initialize OSC
  oscP5 = new OscP5(this, 12000);
  supercollider = new NetAddress("127.0.0.1", 57120);
  
  // Load and setup shader
  gradientShader = loadShader("gradient.glsl");
  gradientShader.set("resolution", float(width), float(height));
  
  // Initialize persistent buffers
  mainBuffer = createGraphics(width, height, P2D);
  textBuffer = createGraphics(width, height, P2D);
  
  // Create scanline texture
  createScanlineTexture();
  
  // Load font
  font = createFont("Arial Bold", TEXT_SIZE);
  textFont(font);
  
  // Initialize noise particles
  particles = new NoiseParticle[NOISE_PARTICLES];
  for (int i = 0; i < particles.length; i++) {
    particles[i] = new NoiseParticle();
  }
  
  // Initialize debug system
  setupDebug();
}

void createScanlineTexture() {
  scanlineTexture = createGraphics(width, height, P2D);
  scanlineTexture.beginDraw();
  scanlineTexture.background(0, 0);
  scanlineTexture.stroke(0, 30);
  for (int y = 0; y < height; y += 3) {
    scanlineTexture.line(0, y, width, y);
  }
  scanlineTexture.endDraw();
}

void updateTextBuffer() {
  textBuffer.beginDraw();
  textBuffer.clear();
  textBuffer.textFont(font);
  textBuffer.textAlign(CENTER, CENTER);
  
  float baseX = width/2;
  float baseY = height/2 + textY;
  
  // Shadow
  textBuffer.fill(0, 80);
  textBuffer.text("P.A.C.E", baseX + 4, baseY + 4);
  
  // Less jagged text effect with controlled randomness
  int jaggedness = 3; // Reduced from 5 for less jagged effect
  for (int i = 0; i < jaggedness; i++) {
    // Use noise instead of random for smoother variation
    float offsetX = map(noise(i * 0.3, frameCount * 0.01), 0, 1, -1.5, 1.5);
    float offsetY = map(noise(i * 0.3 + 10, frameCount * 0.01), 0, 1, -1.5, 1.5);
    float alpha = map(i, 0, jaggedness-1, 100, 255);
    textBuffer.fill(245, 245, 220, alpha);
    textBuffer.text("P.A.C.E", baseX + offsetX, baseY + offsetY);
  }
  
  textBuffer.fill(245, 245, 220);
  textBuffer.text("P.A.C.E", baseX, baseY);
  textBuffer.endDraw();
}

void draw() {
  // Smooth parameter updates
  volume = lerp(volume, targetVolume, VOLUME_SMOOTH_FACTOR);
  centroid = lerp(centroid, targetCentroid, PARAM_SMOOTH_FACTOR);
  colorBalance = lerp(colorBalance, targetColorBalance, COLOR_SMOOTH_FACTOR);
  
  // Update parameters with smoother increments
  noiseTime += NOISE_SPEED;
  
  // Use a smoother sine function for text movement
  targetTextY = sin(frameCount * TEXT_FLOAT_SPEED) * TEXT_FLOAT_AMOUNT;
  textY = lerp(textY, targetTextY, 0.1); // Smooth the text movement
  
  scanLineOffset = (scanLineOffset + SCAN_LINE_SPEED) % height;
  
  // Smooth chromatic aberration
  targetChromAb = map(volume, 0, 1, 0, CHROME_AB_MAX);
  chromAberrationStrength = lerp(chromAberrationStrength, targetChromAb, 1.0 - CHROME_AB_SMOOTH);
  
  // Draw gradient background using shader
  gradientShader.set("time", noiseTime);
  gradientShader.set("colorBalance", colorBalance);
  gradientShader.set("resolution", float(width), float(height));
  shader(gradientShader);
  rect(0, 0, width, height);
  resetShader();
  
  // Update text buffer every frame for smoother movement
  updateTextBuffer();
  
  // Apply chromatic aberration to text
  mainBuffer.beginDraw();
  mainBuffer.clear();
  
  // Red channel
  mainBuffer.tint(255, 0, 0);
  mainBuffer.image(textBuffer, -chromAberrationStrength, 0);
  
  // Blue channel
  mainBuffer.tint(0, 0, 255);
  mainBuffer.image(textBuffer, chromAberrationStrength, 0);
  
  // Green channel
  mainBuffer.tint(0, 255, 0);
  mainBuffer.image(textBuffer, 0, 0);
  mainBuffer.endDraw();
  
  // Draw main content
  image(mainBuffer, 0, 0);
  
  // Draw scanlines with offset
  tint(255);
  pushMatrix();
  translate(0, scanLineOffset);
  image(scanlineTexture, 0, -height);
  image(scanlineTexture, 0, 0);
  popMatrix();
  
  // Smoother noise overlay with persistent particles
  blendMode(ADD);
  noStroke();
  for (int i = 0; i < particles.length; i++) {
    particles[i].update();
    particles[i].display();
  }
  blendMode(BLEND);
  
  // Draw debug information if enabled
  updateDebug();
  drawDebug();
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/reich/volume")) {
    targetVolume = msg.get(0).floatValue();
    updateDebugValue("volume", volume);
    updateDebugValue("targetVolume", targetVolume);
  }
  else if (msg.checkAddrPattern("/reich/centroid")) {
    targetCentroid = msg.get(0).floatValue();
    updateDebugValue("centroid", centroid);
    // Smooth the color balance calculation
    targetColorBalance = map(targetCentroid, 200, 2000, 0, 1) * COLOR_BALANCE_INTENSITY;
  }
  else if (msg.checkAddrPattern("/reich/onset")) {
    lastOnsetTime = millis();
    registerOnset();
  }
}

void keyPressed() {
  if (key == 'h' || key == 'H') {
    toggleDebug();
  }
}
