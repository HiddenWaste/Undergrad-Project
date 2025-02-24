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
float centroid = 0;
float lastOnsetTime = 0;
float noiseTime = 0;
float colorBalance = 0.5;
float targetChromAb = 0;

// Control Variables (adjust these to taste)
float NOISE_SPEED = 0.01;        // Speed of background noise movement
float TEXT_FLOAT_SPEED = 0.01;  // Speed of text floating
float TEXT_FLOAT_AMOUNT = 30;    // Amount of text float in pixels
float CHROME_AB_MAX = 15;        // Maximum chromatic aberration
float CHROME_AB_SMOOTH = 0.95;   // Smoothing for chromatic aberration (higher = slower)
float SCAN_LINE_SPEED = 0.8;     // Speed of scanline movement
float NOISE_AMOUNT = 0.001;       // Amount of noise overlay
int NOISE_PARTICLES = 100;       // Number of noise particles
float NOISE_ALPHA = 40;          // Alpha value for noise
int TEXT_UPDATE_RATE = 3;        // Update text every N frames
float TEXT_SIZE = 120;           // Size of the text
float COLOR_BALANCE_INTENSITY = 2.0; // Scalar for color balance effect (0.0 - 2.0)

// VHS effect parameters
float chromAberrationStrength = 0;
float scanLineOffset = 0;

// Text parameters
PFont font;
float textY = 0;

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
  
  // Jagged text effect
  for (int i = 0; i < 5; i++) {
    float offsetX = random(-2, 2);
    float offsetY = random(-2, 2);
    float alpha = map(i, 0, 4, 100, 255);
    textBuffer.fill(245, 245, 220, alpha);
    textBuffer.text("P.A.C.E", baseX + offsetX, baseY + offsetY);
  }
  
  textBuffer.fill(245, 245, 220);
  textBuffer.text("P.A.C.E", baseX, baseY);
  textBuffer.endDraw();
}

void draw() {
  // Update parameters
  noiseTime += NOISE_SPEED;
  textY = sin(frameCount * TEXT_FLOAT_SPEED) * TEXT_FLOAT_AMOUNT;
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
  
  // Update text buffer only every few frames
  if (frameCount % TEXT_UPDATE_RATE == 0) {
    updateTextBuffer();
  }
  
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
  
  // Simplified noise overlay
  if (frameCount % 2 == 0) {
    blendMode(ADD);
    noStroke();
    for (int i = 0; i < NOISE_PARTICLES; i++) {
      float x = random(width);
      float y = random(height);
      fill(random(255), NOISE_ALPHA);
      rect(x, y, 2, 2);
    }
    blendMode(BLEND);
  }
  
  // Draw debug information if enabled
  updateDebug();
  drawDebug();
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/reich/volume")) {
    volume = msg.get(0).floatValue();
    updateDebugValue("volume", volume);
  }
  else if (msg.checkAddrPattern("/reich/centroid")) {
    centroid = msg.get(0).floatValue();
    updateDebugValue("centroid", centroid);
    colorBalance = map(centroid, 200, 2000, 0, 1) * COLOR_BALANCE_INTENSITY;
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
