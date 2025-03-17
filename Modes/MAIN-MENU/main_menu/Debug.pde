// Debug system variables
boolean showDebug = false;
ArrayList<Float> recentVolumes;
ArrayList<Float> recentCentroids;
int maxDataPoints = 100;
float onsetCount = 0;
float lastOnsetCheck = 0;
float onsetsPerSecond = 0;

void setupDebug() {
  recentVolumes = new ArrayList<Float>();
  recentCentroids = new ArrayList<Float>();
}

void toggleDebug() {
  showDebug = !showDebug;
}

void updateDebugValue(String type, float value) {
  if (type.equals("volume")) {
    if (recentVolumes.size() >= maxDataPoints) {
      recentVolumes.remove(0);
    }
    recentVolumes.add(value);
  } else if (type.equals("centroid")) {
    if (recentCentroids.size() >= maxDataPoints) {
      recentCentroids.remove(0);
    }
    recentCentroids.add(value);
  }
}

void registerOnset() {
  onsetCount++;
}

void updateDebug() {
  // Update onsets per second
  if (millis() - lastOnsetCheck >= 1000) {
    onsetsPerSecond = onsetCount;
    onsetCount = 0;
    lastOnsetCheck = millis();
  }
}

void drawDebug() {
  if (!showDebug) return;
  
  // Create semi-transparent background for debug panel
  pushStyle();
  fill(0, 180);
  noStroke();
  rect(0, 0, 300, height);
  popStyle();
  
  float margin = 20;
  float lineHeight = 25;
  float y = margin;
  
  // Set up debug text style
  pushStyle();
  textAlign(LEFT);
  textSize(14);
  fill(255);  // White text
  
  // Basic info
  text("DEBUG INFORMATION:", margin, y);
  y += lineHeight * 1.5;
  
  // Audio Analysis
  text("AUDIO ANALYSIS", margin, y);
  y += lineHeight;
  text(String.format("Volume: %.3f", volume), margin, y += lineHeight);
  text(String.format("Centroid: %.1f Hz", centroid), margin, y += lineHeight);
  text(String.format("Onsets/sec: %.1f", onsetsPerSecond), margin, y += lineHeight);
  y += lineHeight;
  
  // Visual Parameters
  text("VISUAL PARAMETERS", margin, y);
  y += lineHeight;
  text(String.format("FPS: %.1f", frameRate), margin, y += lineHeight);
  text(String.format("Color Balance: %.3f", colorBalance), margin, y += lineHeight);
  text(String.format("Chrome Aberration: %.2f", chromAberrationStrength), margin, y += lineHeight);
  y += lineHeight;
  
  // Control Variables
  text("CONTROL VARIABLES", margin, y);
  y += lineHeight;
  text(String.format("Color Balance Intensity: %.2f", COLOR_BALANCE_INTENSITY), margin, y += lineHeight);
  text(String.format("Chrome Ab Max: %.2f", CHROME_AB_MAX), margin, y += lineHeight);
  text(String.format("Chrome Ab Smooth: %.2f", CHROME_AB_SMOOTH), margin, y += lineHeight);
  
  // Draw volume history graph
  y += lineHeight * 1.5;
  drawHistoryGraph("Volume History", recentVolumes, margin, y, 260, 50);
  
  // Draw centroid history graph
  y += 80;
  drawHistoryGraph("Frequency History", recentCentroids, margin, y, 260, 50);
  
  popStyle();
}

void drawHistoryGraph(String label, ArrayList<Float> data, float x, float y, float w, float h) {
  pushStyle();
  // Draw background
  fill(0, 100);
  stroke(255, 30);
  rect(x, y, w, h);
  
  // Draw label
  fill(255);
  textSize(12);
  text(label, x, y - 5);
  
  if (data != null && data.size() > 1) {
    // Draw graph
    stroke(0, 255, 0, 200);  // Bright green for visibility
    strokeWeight(1.5);
    noFill();
    beginShape();
    float xStep = w / (maxDataPoints - 1);
    for (int i = 0; i < data.size(); i++) {
      float value = data.get(i);
      float graphX = x + (i * xStep);
      float graphY = y + h - (value * h);
      vertex(graphX, graphY);
    }
    endShape();
    
    // Draw current value indicator
    if (data.size() > 0) {
      float currentValue = data.get(data.size() - 1);
      fill(255, 0, 0);
      noStroke();
      ellipse(x + w, y + h - (currentValue * h), 6, 6);
    }
  } else {
    // No data message
    fill(255, 100);
    textAlign(CENTER);
    text("Waiting for data...", x + w/2, y + h/2);
  }
  popStyle();
}
