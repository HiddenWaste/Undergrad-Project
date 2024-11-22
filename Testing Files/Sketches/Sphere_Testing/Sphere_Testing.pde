import processing.sound.*;
import java.util.ArrayList;

FFT fft;
AudioIn audio;
int bands = 512;
float[] spectrum = new float[bands];
GlitchSphere mainSphere;
ArrayList<GlitchSphere> tempSpheres;
boolean showHelp = false;
int[] cornerUsage = new int[4];

// Constants
final int MAX_SPHERES = 20;
final float DEFAULT_LIFESPAN = 3000;
final String[] CONTROLS = {
  "H - Toggle help display",
  "S - Spawn temporary sphere",
  "F - Spawn fractal sphere",
  "O - Spawn orbit sphere",
  "C - Spawn chain sphere",
  "Q - Spawn frequency follower"
};

void setup() {
  size(800, 800, P3D);
  initAudio();
  mainSphere = new GlitchSphere(width/2, height/2, 150);
  tempSpheres = new ArrayList<GlitchSphere>();
}

void initAudio() {
  audio = new AudioIn(this, 0);
  audio.start();
  audio.amp(8);
  fft = new FFT(this, bands);
  fft.input(audio);
}

void draw() {
  background(255);
  fft.analyze(spectrum);
  
  mainSphere.update(spectrum);
  mainSphere.display();
  
  updateSpheres();
  if (showHelp) drawHelp();
}

void updateSpheres() {
  for (int i = tempSpheres.size() - 1; i >= 0; i--) {
    GlitchSphere sphere = tempSpheres.get(i);
    sphere.update(spectrum);
    sphere.display();
    
    if (sphere instanceof TempSphere && ((TempSphere)sphere).isDead()) {
      tempSpheres.remove(i);
    }
  }
}

void keyPressed() {
  if (tempSpheres.size() >= MAX_SPHERES && key != 'h') return;
  
  switch(key) {
    case 'h': showHelp = !showHelp; break;
    case 's': spawnSphere(new TempSphere(getLeastUsedCorner(), random(50, 100))); break;
    case 'f': spawnSphere(new FractalSphere(randomOffset(width/2), randomOffset(height/2), random(40, 60))); break;
    case 'o': spawnSphere(new OrbitSphere(width/2, height/2, random(30, 50), mainSphere)); break;
    case 'c': spawnSphere(new ChainSphere(random(width * 0.2, width * 0.8), random(height * 0.2, height * 0.8), random(40, 60))); break;
    case 'q': spawnSphere(new FreqSphere(width/2, height/2, random(40, 60))); break;
  }
}

void spawnSphere(GlitchSphere sphere) {
  if (tempSpheres.size() >= MAX_SPHERES) tempSpheres.remove(0);
  tempSpheres.add(sphere);
}

PVector getLeastUsedCorner() {
  int minUsage = min(cornerUsage);
  ArrayList<Integer> available = new ArrayList<>();
  for (int i = 0; i < cornerUsage.length; i++) {
    if (cornerUsage[i] <= minUsage) available.add(i);
  }
  
  int cornerIndex = available.get(int(random(available.size())));
  cornerUsage[cornerIndex]++;
  
  float x = (cornerIndex % 2 == 0) ? width/4 : 3*width/4;
  float y = (cornerIndex < 2) ? height/4 : 3*height/4;
  
  normalizeCornerUsage();
  return new PVector(randomOffset(x, 50), randomOffset(y, 50));
}

float randomOffset(float value, float variation) {
  return value + random(-variation, variation);
}

float randomOffset(float value) {
  return randomOffset(value, 100);
}

void normalizeCornerUsage() {
  if (max(cornerUsage) > 100) {
    for (int i = 0; i < cornerUsage.length; i++) {
      cornerUsage[i] /= 2;
    }
  }
}

void drawHelp() {
  fill(255, 220);
  noStroke();
  rect(10, 10, 250, 200);
  
  fill(0);
  textAlign(LEFT);
  textSize(14);
  int y = 30;
  
  text("=== CONTROLS ===", 20, y);
  for (String control : CONTROLS) {
    y += 20;
    text(control, 20, y);
  }
  
  y += 20;
  text(String.format("Audio Level: %.3f", mainSphere.audioLevel), 20, y);
  y += 20;
  text(String.format("Active Spheres: %d/%d", tempSpheres.size(), MAX_SPHERES), 20, y);
}

// Base Sphere Class
class GlitchSphere {
  float x, y, baseRadius, currentRadius, targetRadius, rotation = 0;
  int numPoints = 50, numRings = 6;
  float radiusLerp = 0.15, rotationSpeed = 0.005;
  float[] glitchOffsets, targetOffsets;
  float glitchLerp = 0.25, glitchThreshold = 0.02;
  float maxGlitchOffset = 40, audioLevel = 0;
  
  GlitchSphere(float x, float y, float radius) {
    this.x = x;
    this.y = y;
    this.baseRadius = this.currentRadius = this.targetRadius = radius;
    glitchOffsets = new float[numPoints];
    targetOffsets = new float[numPoints];
  }
  
  void update(float[] spectrum) {
    updateAudioLevel(spectrum);
    updateRadius();
    updateGlitchEffects(spectrum);
    rotation += rotationSpeed;
  }
  
  void updateAudioLevel(float[] spectrum) {
    float avgAmp = 0;
    int relevantBands = bands/4;
    for (int i = 0; i < relevantBands; i++) {
      avgAmp += spectrum[i] * map(i, 0, relevantBands, 1.5, 0.5);
    }
    audioLevel = avgAmp / relevantBands;
  }
  
  void updateRadius() {
    targetRadius = baseRadius * (1 + audioLevel * 8);
    currentRadius = lerp(currentRadius, targetRadius, radiusLerp);
  }
  
  void updateGlitchEffects(float[] spectrum) {
    for (int i = 0; i < numPoints; i++) {
      float freqIntensity = spectrum[int(map(i, 0, numPoints, 0, bands/3))] * 3;
      
      if (freqIntensity > glitchThreshold) {
        float intensity = map(freqIntensity, glitchThreshold, 1, 0.5, 2);
        targetOffsets[i] = random(-maxGlitchOffset, maxGlitchOffset) * intensity;
      } else {
        targetOffsets[i] *= 0.85;
      }
      
      glitchOffsets[i] = lerp(glitchOffsets[i], targetOffsets[i], glitchLerp);
    }
  }
  
  void display() {
    pushMatrix();
    translate(x, y);
    rotateY(rotation);
    rotateX(rotation * 0.7);
    
    stroke(0, 100);
    strokeWeight(1);
    noFill();
    drawSphereMesh();
    
    popMatrix();
  }
  
  void drawSphereMesh() {
    for (int i = 0; i < numPoints; i += 2) {
      drawDistortedLine(map(i, 0, numPoints, 0, TWO_PI));
    }
    
    for (int i = 0; i < numRings; i++) {
      float ringY = map(i, 0, numRings-1, -currentRadius, currentRadius);
      drawHorizontalRing(ringY, sqrt(sq(currentRadius) - sq(ringY)));
    }
  }
  
  void drawDistortedLine(float angle) {
    float x = cos(angle), z = sin(angle);
    beginShape();
    for (int j = 0; j <= 20; j += 2) {
      float y = map(j, 0, 20, -1, 1);
      float r = currentRadius + glitchOffsets[int(map(y, -1, 1, 0, numPoints-1))];
      vertex(x * r * sqrt(1 - y*y), y * r, z * r * sqrt(1 - y*y));
    }
    endShape();
  }
  
  void drawHorizontalRing(float y, float ringRadius) {
    beginShape();
    for (int i = 0; i <= numPoints; i += 2) {
      float angle = map(i, 0, numPoints, 0, TWO_PI);
      float offset = glitchOffsets[i % numPoints];
      vertex(cos(angle) * (ringRadius + offset), y, sin(angle) * (ringRadius + offset));
    }
    endShape();
  }
  
  // Setter methods
  void setRotationSpeed(float speed) { rotationSpeed = speed; }
  void setGlitchSensitivity(float threshold) { glitchThreshold = threshold; }
  void setMaxGlitchOffset(float offset) { maxGlitchOffset = offset; }
  void setBaseRadius(float radius) { baseRadius = radius; }
}

// Temporary Sphere
class TempSphere extends GlitchSphere {
  float birthTime, lifespan, opacity = 255;
  
  TempSphere(PVector pos, float radius) {
    super(pos.x, pos.y, radius);
    birthTime = millis();
    lifespan = DEFAULT_LIFESPAN + random(-500, 500);
    setRotationSpeed(0.01);
    setGlitchSensitivity(0.05);
    setMaxGlitchOffset(50);
  }
  
  @Override
  void update(float[] spectrum) {
    super.update(spectrum);
    opacity = 255 * (1 - (millis() - birthTime) / lifespan);
  }
  
  @Override
  void display() {
    pushMatrix();
    translate(x, y);
    rotateY(rotation);
    rotateX(rotation * 0.7);
    stroke(0, opacity * 0.4);
    strokeWeight(1);
    noFill();
    drawSphereMesh();
    popMatrix();
  }
  
  boolean isDead() { return millis() - birthTime > lifespan; }
}

// Fractal Sphere
class FractalSphere extends GlitchSphere {
  int depth = 3;
  float childScale = 0.4;
  
  FractalSphere(float x, float y, float radius) {
    super(x, y, radius);
    setGlitchSensitivity(0.04);
    setRotationSpeed(0.007);
  }
  
  @Override
  void display() {
    displayRecursive(x, y, currentRadius, depth, rotation);
  }
  
  void displayRecursive(float px, float py, float r, int d, float rot) {
    if (d <= 0) return;
    
    pushMatrix();
    translate(px, py);
    rotateY(rot);
    rotateX(rot * 0.7);
    stroke(0, 100);
    strokeWeight(map(d, 1, depth, 0.5, 1.5));
    drawSphereMesh();
    
    if (d > 1) {
      float childR = r * childScale;
      float orbitR = r * 1.2;
      for (int i = 0; i < 3; i++) {
        float angle = (TWO_PI * i / 3) + (frameCount * 0.02);
        displayRecursive(cos(angle) * orbitR, sin(angle) * orbitR, 
                        childR, d - 1, -rot * 1.5);
      }
    }
    popMatrix();
  }
}

// Orbit Sphere
class OrbitSphere extends GlitchSphere {
  float orbitRadius, orbitSpeed, orbitAngle = 0;
  GlitchSphere target;
  
  OrbitSphere(float x, float y, float radius, GlitchSphere target) {
    super(x, y, radius);
    this.target = target;
    orbitRadius = target.currentRadius * 2;
    orbitSpeed = random(0.01, 0.03);
    setRotationSpeed(0.01);
  }
  
  @Override
  void update(float[] spectrum) {
    super.update(spectrum);
    orbitAngle += orbitSpeed * (1 + audioLevel * 2);
    x = target.x + cos(orbitAngle) * orbitRadius;
    y = target.y + sin(orbitAngle) * orbitRadius;
    orbitRadius = target.currentRadius * (1.5 + audioLevel);
  }
}

// Chain Sphere
class ChainSphere extends GlitchSphere {
  float connectionRange;
  
  ChainSphere(float x, float y, float radius) {
    super(x, y, radius);
    connectionRange = radius * 4;
    setGlitchSensitivity(0.06);
  }
  
  @Override
  void display() {
    super.display();
    drawConnections();
  }
  
  void drawConnections() {
    stroke(0, 50);
    strokeWeight(0.5);
    
    if (dist(x, y, mainSphere.x, mainSphere.y) < connectionRange) {
      drawConnection(this, mainSphere);
    }
    
    for (GlitchSphere other : tempSpheres) {
      if (other != this && dist(x, y, other.x, other.y) < connectionRange) {
        drawConnection(this, other);
      }
    }
  }
  
  void drawConnection(GlitchSphere a, GlitchSphere b) {
    float strength = (1 - dist(a.x, a.y, b.x, b.y) / connectionRange) * 100;
    stroke(0, strength);
    
    beginShape();
    for (int i = 0; i <= 10; i++) {
      float t = i / 10.0;
      float wave = sin(t * PI * 2 + frameCount * 0.1) * (audioLevel * 20);
      vertex(lerp(a.x, b.x, t) + wave, lerp(a.y, b.y, t) + wave);
    }
    endShape();
  }
}

// Frequency Following Sphere
class FreqSphere extends GlitchSphere {
  float targetX, targetY;
  float easing = 0.1;
  
  FreqSphere(float x, float y, float radius) {
    super(x, y, radius);
    targetX = x;
    targetY = y;
    setGlitchSensitivity(0.08);
    setRotationSpeed(0.015);
  }
  
  @Override
  void update(float[] spectrum) {
    super.update(spectrum);
    
    // Find loudest frequency
    float maxAmp = 0;
    int maxIndex = 0;
    for (int i = 0; i < bands; i++) {
      if (spectrum[i] > maxAmp) {
        maxAmp = spectrum[i];
        maxIndex = i;
      }
    }
    
    // Update target position
    targetX = map(maxIndex, 0, bands, width * 0.2, width * 0.8);
    targetY = map(maxAmp, 0, 0.5, height * 0.8, height * 0.2);
    
    // Smooth movement
    x = lerp(x, targetX, easing);
    y = lerp(y, targetY, easing);
  }
  
  @Override
  void display() {
    // Draw motion trail
    pushStyle();
    stroke(0, 30);
    strokeWeight(1);
    line(x, y, targetX, targetY);
    popStyle();
    
    super.display();
  }
}

void exit() {
  if (audio != null) {
    audio.stop();
  }
  super.exit();
}
