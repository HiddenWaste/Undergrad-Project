// Main.pde
import oscP5.*;
import netP5.*;

// Constants moved to a separate file
final int MAX_FIREBALLS = 20;
final int MAX_MISSILES = 15;
final PVector FIREBALL_SPAWN_OFFSET = new PVector(80, -50);
final PVector MISSILE_SPAWN_OFFSET = new PVector(100, -30);
final PVector THUNDERBOLT_SPAWN_OFFSET = new PVector(80, -50);

// Game objects
PImage fireballImg, wizardImg, goblinImg, lightningImg;
OscP5 oscP5;
GameState gameState;
boolean debugMode = false;
WaveManager waveManager;

void setup() {
  size(1024, 768, P2D);
  imageMode(CENTER);
  frameRate(60);
  
  // Initialize game state (now manages all game objects)
  gameState = new GameState();
  
  // Load images with error handling
  loadGameAssets();
  
  waveManager = new WaveManager();
  
  // Initialize OSC
  try {
    oscP5 = new OscP5(this, 12000);
    println("OSC initialized on port 12000");
  } catch (Exception e) {
    println("Warning: Could not initialize OSC");
  }
}

void loadGameAssets() {
  try {
    fireballImg = loadImage("Fireball.png");
    wizardImg = loadImage("wizard.png");
    goblinImg = loadImage("flying-goblin.png");
    lightningImg = loadImage("lightning.png");
    
    if (wizardImg != null) {
      wizardImg.resize(0, 200);
    }
    if (goblinImg != null) {
      goblinImg.resize(0, 100); // Adjust size as needed
    }
  } catch (Exception e) {
    println("Warning: Could not load images - using fallback shapes");
  }
}

void oscEvent(OscMessage theOscMessage) {
  gameState.handleOscMessage(theOscMessage);
}


void draw() {
  background(gameState.getBgColor());
  gameState.update();
  gameState.display();
  
  if (debugMode) {
    displayDebugInfo();
  }
  
  waveManager.update();
  waveManager.updateEnemies();
  waveManager.displayEnemies();
  
  // Display wave status
  textAlign(CENTER);
  text(waveManager.getWaveStatus(), width/2, 30);
}

void displayDebugInfo() {
  fill(255);
  textAlign(LEFT, TOP);
  textSize(12);
  text("FPS: " + nf(frameRate, 0, 1), 10, 10);
  text("Active fireballs: " + gameState.getFireballCount(), 10, 30);
  text("Active missiles: " + gameState.getMissileCount(), 10, 50);
  text("Active enemies: " + gameState.getEnemyCount(), 10, 70);  // Changed from getGoblinCount
  text("Wizard Y position: " + nf(gameState.getWizardY(), 0, 2), 10, 90);
  text("Current wave: " + gameState.waveManager.getCurrentWave(), 10, 110);
  text("Wave active: " + gameState.waveManager.isWaveActive(), 10, 130);
}

void keyPressed() {
  if (key == 'd' || key == 'D') {
    debugMode = !debugMode;
  }
  if (key == 'c' || key == 'C') {
    gameState.clearProjectiles();
  }
  if (key == ' ' && !waveManager.isWaveActive()) {
    waveManager.startNextWave();
  }
  // Add this new condition for power mode activation
  if (key == 'p' || key == 'P') {
    gameState.activatePowerMode();
  }
}

void mousePressed() {
  if (mouseButton == LEFT) {
    gameState.createFireball();
  } else if (mouseButton == RIGHT) {
    gameState.createMissile();
  }
}
