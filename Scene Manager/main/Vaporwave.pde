class Vaporwave extends Scene {
  private float time;
  private int numLines;
  private float[] lineOffsets;
  private color[] lineColors;
  private PGraphics staticBuffer;
  private float staticUpdateInterval = 0.1; // Update static less frequently
  private float lastStaticUpdate = 0;
  private int gradientSteps = 100; // Reduce gradient resolution
  private PGraphics bgBuffer; // Cache the gradient background
  
  void setup() {
    time = 0;
    numLines = 8; // Reduced number of lines
    lineOffsets = new float[numLines];
    lineColors = new color[numLines];
    
    // Create static effect buffer at lower resolution
    staticBuffer = createGraphics(width/2, height/2, P2D);
    
    // Create background buffer
    bgBuffer = createGraphics(width, height, P2D);
    
    // Vaporwave palette
    color[] palette = {
      color(255, 82, 255),    // Hot pink
      color(0, 255, 255),     // Cyan
      color(255, 138, 216),   // Light pink
      color(130, 87, 229),    // Purple
      color(94, 240, 177)     // Mint
    };
    
    for (int i = 0; i < numLines; i++) {
      lineOffsets[i] = random(TWO_PI);
      lineColors[i] = palette[i % palette.length];
    }
    
    // Pre-render gradient background
    createGradientBackground();
  }
  
  void createGradientBackground() {
    bgBuffer.beginDraw();
    bgBuffer.noStroke();
    
    // Draw gradient in fewer steps
    for(int i = 0; i < gradientSteps; i++) {
      float inter = map(i, 0, gradientSteps-1, 0, 1);
      color c = lerpColor(color(20, 0, 40), color(100, 0, 100), inter);
      bgBuffer.fill(c);
      float y1 = map(i, 0, gradientSteps-1, 0, height);
      float y2 = map(i+1, 0, gradientSteps-1, 0, height);
      bgBuffer.rect(0, y1, width, y2-y1+1);
    }
    
    // Add scanlines more efficiently
    bgBuffer.stroke(0, 50);
    bgBuffer.strokeWeight(1);
    for (int y = 0; y < height; y += 6) { // Increased spacing
      bgBuffer.line(0, y, width, y);
    }
    
    bgBuffer.endDraw();
  }
  
  void updateStatic() {
    staticBuffer.beginDraw();
    staticBuffer.loadPixels();
    for (int i = 0; i < staticBuffer.pixels.length; i += 2) { // Process fewer pixels
      float rand = random(1);
      color c = (rand < 0.05) ? color(255, 30) : color(0, 0);
      staticBuffer.pixels[i] = c;
      staticBuffer.pixels[i+1] = c; // Copy to adjacent pixel
    }
    staticBuffer.updatePixels();
    staticBuffer.endDraw();
  }
  
  void update() {
    time += 0.02;
    
    // Update static less frequently
    if (millis() - lastStaticUpdate > staticUpdateInterval * 1000) {
      updateStatic();
      lastStaticUpdate = millis();
    }
  }
  
  void draw() {
    buffer.beginDraw();
    
    // Draw pre-rendered background
    buffer.image(bgBuffer, 0, 0);
    
    // Draw sine wave lines more efficiently
    buffer.strokeWeight(2);
    buffer.noFill();
    
    for (int i = 0; i < numLines; i++) {
      buffer.stroke(lineColors[i], 200);
      buffer.beginShape();
      for (float x = 0; x < width; x += 6) { // Increased step size
        float y = height/2 + 
                 sin(x * 0.01 + time + lineOffsets[i]) * 100 * 
                 sin(time * 0.5);
        buffer.vertex(x, y);
      }
      buffer.endShape();
    }
    
    // Scale up static buffer and blend
    buffer.image(staticBuffer, 0, 0, width, height);
    
    // Simplified chromatic aberration (one pass instead of two)
    PImage temp = buffer.get();
    buffer.tint(255, 0, 0, 80);
    buffer.image(temp, 2, 0);
    buffer.tint(0, 0, 255, 80);
    buffer.image(temp, -2, 0);
    buffer.noTint();
    
    buffer.endDraw();
  }
  
  void cleanup() {
    if (staticBuffer != null) {
      staticBuffer.dispose();
    }
    if (bgBuffer != null) {
      bgBuffer.dispose();
    }
  }
}