// GlitchArt.pde
import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress supercollider;

// Constants for effects
final int EFFECT_BLOWOUT = 0;
final int EFFECT_HALFTIME = 1;
final int EFFECT_THEREANDBACK = 2;

// State variables
ArrayList<GlitchSymbol> symbols;
color baseColor;
color backgroundColor;
float currentHue;
int selectedEffect;
boolean isHalftime;
float filterAmount;
PGraphics canvas;

void setup() {
  size(1024, 768, P2D);
  colorMode(HSB, 360, 100, 100);
  
  // Initialize collections and variables
  symbols = new ArrayList<GlitchSymbol>();
  baseColor = color(0, 80, 80);
  backgroundColor = color(0, 0, 20);
  currentHue = 0;
  selectedEffect = EFFECT_BLOWOUT;
  isHalftime = false;
  filterAmount = 0;
  
  // Create canvas for effects
  canvas = createGraphics(width, height, P2D);
  
  // Initialize OSC
  oscP5 = new OscP5(this, 12000);
  supercollider = new NetAddress("127.0.0.1", 57120);
}

void oscEvent(OscMessage msg) {
  String pattern = msg.addrPattern();
  
  switch(pattern) {
    case "/symbol/add":
      float x = random(width);
      float y = random(height);
      int symbolType = msg.get(0).intValue();
      addSymbol(x, y, symbolType);
      break;
      
    case "/screen/clear":
      symbols.clear();
      break;
      
    case "/color/update":
      currentHue = (currentHue + 60) % 360;
      updateColors();
      break;
      
    case "/effect/trigger":
      triggerEffect();
      break;
      
    case "/background/control":
      float value = msg.get(0).floatValue();
      updateBackground(value);
      break;
      
    case "/effect/select":
      float pot3Value = msg.get(0).floatValue();
      selectedEffect = int(map(pot3Value, 0, 1, 0, 3));
      break;
  }
}

void addSymbol(float x, float y, int type) {
  symbols.add(new GlitchSymbol(x, y, type, currentHue));
}

void updateColors() {
  for (GlitchSymbol symbol : symbols) {
    symbol.updateHue(currentHue);
  }
}

void updateBackground(float value) {
  float hue = (currentHue + map(value, 0, 1, 0, 180)) % 360;
  float brightness = map(value, 0, 1, 20, 80);
  backgroundColor = color(hue, 40, brightness);
}

void triggerEffect() {
  switch(selectedEffect) {
    case EFFECT_BLOWOUT:
      triggerBlowout();
      break;
    case EFFECT_HALFTIME:
      triggerHalftime();
      break;
    case EFFECT_THEREANDBACK:
      triggerThereAndBack();
      break;
  }
}

void triggerBlowout() {
  // Create explosive displacement of symbols
  for (GlitchSymbol symbol : symbols) {
    symbol.applyForce(random(-20, 20), random(-20, 20));
  }
}

void triggerHalftime() {
  isHalftime = !isHalftime;
  if (isHalftime) {
    currentHue = 240; // Blue
    updateColors();
  }
}

void triggerThereAndBack() {
  filterAmount = 1.0;
}

void draw() {
  // Draw to canvas first
  canvas.beginDraw();
  canvas.background(backgroundColor);
  
  // Update and draw symbols
  for (int i = symbols.size() - 1; i >= 0; i--) {
    GlitchSymbol symbol = symbols.get(i);
    symbol.update();
    symbol.display(canvas);
    
    if (!symbol.isActive()) {
      symbols.remove(i);
    }
  }
  canvas.endDraw();
  
  // Apply effects
  if (filterAmount > 0) {
    // Apply low pass filter effect visually
    PImage filtered = canvas.get();
    filtered.filter(BLUR, filterAmount * 3);
    image(filtered, 0, 0);
    filterAmount = max(0, filterAmount - 0.02);
  } else {
    image(canvas, 0, 0);
  }
}

class GlitchSymbol {
  PVector position;
  PVector velocity;
  float hue;
  int type;
  float size;
  boolean active;
  
  GlitchSymbol(float x, float y, int symbolType, float h) {
    position = new PVector(x, y);
    velocity = new PVector();
    hue = h;
    type = symbolType;
    size = random(20, 50);
    active = true;
  }
  
  void update() {
    position.add(velocity);
    velocity.mult(0.95); // Drag
    
    // Deactivate if off screen
    if (position.x < -size || position.x > width + size ||
        position.y < -size || position.y > height + size) {
      active = false;
    }
  }
  
  void display(PGraphics pg) {
    pg.push();
    pg.translate(position.x, position.y);
    pg.rotate(frameCount * 0.02);
    
    pg.noStroke();
    pg.fill(hue, 80, 80);
    
    switch(type) {
      case 0: // Square
        pg.rectMode(CENTER);
        pg.rect(0, 0, size, size);
        break;
      case 1: // Circle
        pg.ellipse(0, 0, size, size);
        break;
      case 2: // Triangle
        pg.triangle(-size/2, size/2, 0, -size/2, size/2, size/2);
        break;
    }
    
    pg.pop();
  }
  
  void updateHue(float newHue) {
    hue = newHue;
  }
  
  void applyForce(float fx, float fy) {
    velocity.add(fx, fy);
  }
  
  boolean isActive() {
    return active;
  }
}
