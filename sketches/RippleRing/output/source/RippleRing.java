/* autogenerated by Processing revision 1293 on 2025-01-05 */
import processing.core.*;
import processing.data.*;
import processing.event.*;
import processing.opengl.*;

import oscP5.*;
import netP5.*;

import java.util.HashMap;
import java.util.ArrayList;
import java.io.File;
import java.io.BufferedReader;
import java.io.PrintWriter;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;

public class RippleRing extends PApplet {




OscP5 oscP5;
NetAddress myRemoteLocation;

// Global state
boolean globalMode = false;
int currentSynth = 0;  // 0: FM, 1: Granular, 2: Drone

// Synth parameters with smoother transitions
float targetFrequency = 440;
float currentFrequency = 440;
float volume = 0.5f;
float modulation = 0;
float reverbMix = 0;

// Visual parameters
ArrayList<Ring> rings;
ArrayList<Particle> particles;
float rotationAngle = 0;
int[] synthColors = {
  color(255, 100, 150),  // FM: Pink
  color(100, 255, 150),  // Granular: Green
  color(150, 100, 255)   // Drone: Purple
};

public void setup() {
  /* size commented out by preprocessor */;
  colorMode(RGB);
  background(0);
  
  // Initialize OSC
  oscP5 = new OscP5(this, 12000);
  myRemoteLocation = new NetAddress("127.0.0.1", 57120);
  
  // Initialize visual elements
  rings = new ArrayList<Ring>();
  particles = new ArrayList<Particle>();
  
  // Create initial rings
  for (int i = 0; i < 5; i++) {
    rings.add(new Ring(100 + i * 50));
  }
  
  // Create initial particles
  for (int i = 0; i < 50; i++) {
    particles.add(new Particle());
  }
}

public void draw() {
  // Smooth parameter transitions
  currentFrequency = lerp(currentFrequency, targetFrequency, 0.1f);
  
  // Fade background with alpha based on reverb
  fill(0, map(reverbMix, 0, 1, 20, 40));
  rect(0, 0, width, height);
  
  if (globalMode) {
    drawGlobalMode();
  } else {
    switch(currentSynth) {
      case 0: drawFMMode(); break;
      case 1: drawGranularMode(); break;
      case 2: drawDroneMode(); break;
    }
  }
  
  rotationAngle += map(currentFrequency, 110, 880, 0.001f, 0.01f);
}

public void drawFMMode() {
  translate(width/2, height/2);
  rotate(rotationAngle);
  
  // Draw rings with FM-style modulation
  for (Ring ring : rings) {
    ring.update();
    ring.display(synthColors[0], modulation);
  }
}

public void drawGranularMode() {
  // Update and display particles
  for (Particle p : particles) {
    p.update();
    p.display(synthColors[1]);
  }
}

public void drawDroneMode() {
  translate(width/2, height/2);
  
  // Draw harmonic circles
  float baseSize = map(currentFrequency, 110, 880, 200, 100);
  for (int i = 1; i <= 6; i++) {
    float size = baseSize * i;
    float alpha = map(i, 1, 6, 255, 50) * volume;
    stroke(synthColors[2], alpha);
    strokeWeight(map(modulation, 0, 1, 1, 3));
    noFill();
    ellipse(0, 0, size + sin(rotationAngle * i) * 20, size + cos(rotationAngle * i) * 20);
  }
}

public void drawGlobalMode() {
  translate(width/2, height/2);
  
  // Draw volume indicator
  float centerSize = map(volume, 0, 1, 50, 200);
  
  // Draw reverb rings
  for (int i = 0; i < 5; i++) {
    float size = centerSize + (i * map(reverbMix, 0, 1, 20, 50));
    float alpha = map(i, 0, 4, 200, 50);
    stroke(synthColors[currentSynth], alpha);
    strokeWeight(2);
    noFill();
    ellipse(0, 0, size, size);
  }
  
  // Draw center shape
  fill(synthColors[currentSynth]);
  noStroke();
  ellipse(0, 0, centerSize, centerSize);
}

// Visual element classes
class Ring {
  float baseRadius;
  float phase = 0;
  
  Ring(float r) {
    baseRadius = r;
  }
  
  public void update() {
    phase += currentFrequency/1000.0f;
  }
  
  public void display(int c, float mod) {
    noFill();
    strokeWeight(map(volume, 0, 1, 1, 3));
    stroke(c, map(volume, 0, 1, 100, 255));
    
    beginShape();
    for (float a = 0; a < TWO_PI; a += 0.1f) {
      float r = baseRadius + sin(a * (mod * 10) + phase) * 20;
      float x = r * cos(a);
      float y = r * sin(a);
      vertex(x, y);
    }
    endShape(CLOSE);
  }
}

class Particle {
  PVector pos, vel;
  float size;
  float life;
  
  Particle() {
    reset();
    pos = PVector.random2D().mult(random(width/2));
    pos.x += width/2;
    pos.y += height/2;
  }
  
  public void reset() {
    pos = new PVector(random(width), random(height));
    vel = PVector.random2D().mult(map(currentFrequency, 110, 880, 1, 4));
    size = random(2, 8);
    life = random(0.5f, 1);
  }
  
  public void update() {
    pos.add(vel);
    life -= 0.01f;
    
    // Modulate velocity based on modulation parameter
    vel.rotate(sin(frameCount * 0.1f) * modulation * 0.1f);
    
    if (life <= 0 || pos.x < 0 || pos.x > width || pos.y < 0 || pos.y > height) {
      reset();
    }
  }
  
  public void display(int c) {
    noStroke();
    fill(c, life * 255 * volume);
    ellipse(pos.x, pos.y, size * volume, size * volume);
  }
}

// OSC message handling
public void oscEvent(OscMessage msg) {
  try {
    if (msg == null) return;
    
    String pattern = msg.addrPattern();
    if (pattern == null) return;
    
    // Safely get values with type checking
    if (pattern.equals("/synth/select")) {
      if (msg.checkTypetag("i")) {  // Check if message contains an integer
        int direction = msg.get(0).intValue();
        currentSynth = (currentSynth + direction + 3) % 3;
      }
    }
    else if (pattern.equals("/mode/global")) {
      if (msg.checkTypetag("i")) {  // Check if message contains an integer
        globalMode = msg.get(0).intValue() == 1;
      }
    }
    else if (pattern.equals("/pot/1")) {
      if (msg.checkTypetag("f")) {  // Check if message contains a float
        float value = constrain(msg.get(0).floatValue(), 0, 1);
        if (globalMode) {
          volume = value;
        } else {
          targetFrequency = map(value, 0, 1, 110, 880);
        }
      }
    }
    else if (pattern.equals("/pot/2")) {
      if (msg.checkTypetag("f")) {  // Check if message contains a float
        modulation = constrain(msg.get(0).floatValue(), 0, 1);
      }
    }
    else if (pattern.equals("/pot/3")) {
      if (msg.checkTypetag("f")) {  // Check if message contains a float
        reverbMix = constrain(msg.get(0).floatValue(), 0, 1);
      }
    }
  } catch (Exception e) {
    println("Error in oscEvent: " + e.getMessage());
  }
}


  public void settings() { size(1280, 720, P2D); }

  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "RippleRing" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
