/* autogenerated by Processing revision 1293 on 2025-03-18 */
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

public class wizardcore extends PApplet {

// Main.pde



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

public void setup() {
  /* size commented out by preprocessor */;
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

public void loadGameAssets() {
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

public void oscEvent(OscMessage theOscMessage) {
  gameState.handleOscMessage(theOscMessage);
}


public void draw() {
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

public void displayDebugInfo() {
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

public void keyPressed() {
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

public void mousePressed() {
  if (mouseButton == LEFT) {
    gameState.createFireball();
  } else if (mouseButton == RIGHT) {
    gameState.createMissile();
  }
}
// Enemy.pde

// Base class for all enemies
abstract class Enemy {
  PVector position;
  PVector velocity;
  float size;
  int health;
  int maxHealth;
  float hitboxRadius;
  boolean alive;
  PImage sprite;
  String type;
  
  Enemy(float x, float y, String type, int health, float size, float speed) {
    this.position = new PVector(x, y);
    this.type = type;
    this.health = health;
    this.maxHealth = health;
    this.size = size;
    this.alive = true;
    this.sprite = loadImage(type + ".png");
    if (this.sprite != null) {
      this.sprite.resize(0, (int)size);
    }
    setupMovement(speed);
  }
  
  public abstract void setupMovement(float speed);
  public abstract void updateMovement();
  
  public void update() {
    if (!alive) return;
    updateMovement();
    checkBounds();
  }
  
  public void checkBounds() {
    if (position.x < -size || position.x > width + size || 
        position.y < -size || position.y > height + size) {
      alive = false;
    }
  }
  
  public void display() {
    if (!alive) return;
    
    pushMatrix();
    translate(position.x, position.y);
    
    if (sprite != null) {
      image(sprite, 0, 0);
    } else {
      // Fallback shape
      fill(255, 0, 0);
      ellipse(0, 0, size, size);
    }
    
    // Health bar
    displayHealthBar();
    
    // Debug hitbox
    if (debugMode) {
      noFill();
      stroke(255, 0, 0);
      ellipse(0, 0, hitboxRadius * 2, hitboxRadius * 2);
    }
    
    popMatrix();
  }
  
  public void displayHealthBar() {
    float healthBarWidth = size;
    float healthBarHeight = 5;
    float healthPercentage = (float)health / maxHealth;
    
    stroke(0);
    fill(255, 0, 0);
    rect(-healthBarWidth/2, -size/2 - 10, healthBarWidth, healthBarHeight);
    fill(0, 255, 0);
    rect(-healthBarWidth/2, -size/2 - 10, healthBarWidth * healthPercentage, healthBarHeight);
  }
  
  public void takeDamage(int amount) {
    health -= amount;
    if (health <= 0) {
      die();
    }
  }
  
  public void die() {
    alive = false;
    // Send OSC message for death sound
    oscP5.send(new OscMessage("/" + type + "/death"), new NetAddress("127.0.0.1", 57120));
    
    // Register the kill with the game state
    gameState.registerKill();
}
  
  public boolean checkCollision(PVector point, float radius) {
    return PVector.dist(position, point) < (hitboxRadius + radius);
  }
  
  public boolean isAlive() {
    return alive;
  }
}
// EnemyTypes.pde

class FlyingGoblin extends Enemy {
  float bobTimer;
  
  FlyingGoblin(float x, float y) {
    super(x, y, "flying-goblin", 3, 60, 1.0f);
    hitboxRadius = size * 0.4f;
    bobTimer = random(TWO_PI);
  }
  
  public void setupMovement(float speed) {
    velocity = new PVector(-speed, 0);
  }
  
  public void updateMovement() {
    position.add(velocity);
    bobTimer += 0.05f;
    position.y += sin(bobTimer) * 0.5f;
  }
}

class RedDragon extends Enemy {
  float phaseTimer;
  float verticalSpeed;
  
  RedDragon(float x, float y) {
    super(x, y, "red-dragon", 50, 120, 0.5f);
    hitboxRadius = size * 0.6f;
    phaseTimer = random(TWO_PI);
    verticalSpeed = 0.3f;
  }
  
  public void setupMovement(float speed) {
    velocity = new PVector(-speed, 0);
  }
  
  public void updateMovement() {
    position.add(velocity);
    // Slow sinusoidal vertical movement
    phaseTimer += 0.02f;
    position.y += sin(phaseTimer) * verticalSpeed;
  }
}

class BatSwarm extends Enemy {
  float spreadFactor;
  float swarmAngle;
  
  BatSwarm(float x, float y) {
    super(x, y, "bat-swarm", 5, 80, 1.5f);
    hitboxRadius = size * 0.5f;
    spreadFactor = random(20, 30);
    swarmAngle = 0;
  }
  
  public void setupMovement(float speed) {
    velocity = new PVector(-speed, 0);
  }
  
  public void updateMovement() {
    position.add(velocity);
    // Create swarm-like movement pattern
    swarmAngle += 0.1f;
    position.y += sin(swarmAngle) * spreadFactor * 0.1f;
    position.x += cos(swarmAngle * 0.5f) * spreadFactor * 0.05f;
  }
}
// Projectiles.pde

class Projectile {
  PVector position;
  PVector velocity;
  boolean active;
  float hitboxRadius;
  
  public boolean checkCollision(FlyingGoblin goblin) {
    return goblin.checkCollision(position, hitboxRadius);
  }
}

class Fireball extends Projectile {
  float baseSize;
  float size;
  int tint;
  
  Fireball(float x, float y) {
    position = new PVector(x, y);
    float angle = random(-PI/6, PI/6);
    velocity = new PVector(cos(angle), sin(angle));
    float baseSpeed = random(15, 25);
    velocity.mult(baseSpeed);
    baseSize = random(40, 60);
    size = baseSize * gameState.potSize;
    active = true;
    tint = color(255, random(180, 255), random(0, 100));
    hitboxRadius = size * 0.4f;
  }
  
  public void update() {
    if (!active) return;
    
    position.add(velocity);
    velocity.y += 0.1f;
    
    // Update size based on current potSize
    size = baseSize * gameState.potSize;
    hitboxRadius = size * 0.4f;
    
    if (position.x < -size || position.x > width + size || 
        position.y < -size || position.y > height + size) {
      active = false;
    }
  }
  
  public void display() {
    if (!active) return;
    
    pushMatrix();
    translate(position.x, position.y);
    
    if (fireballImg != null) {
      tint(tint);
      image(fireballImg, 0, 0, size, size);
      noTint();
    } else {
      fill(tint);
      noStroke();
      ellipse(0, 0, size, size);
    }
    
    if (debugMode) {
      noFill();
      stroke(255, 0, 0);
      ellipse(0, 0, hitboxRadius * 2, hitboxRadius * 2);
    }
    
    popMatrix();
  }
}

class MagicMissile extends Projectile {
  float angle;
  float baseLength;
  float length;
  int missileColor;
  
  MagicMissile(float x, float y) {
    position = new PVector(x, y);
    angle = random(-PI/8, PI/8);
    velocity = new PVector(cos(angle), sin(angle));
    float baseSpeed = random(18, 28);
    velocity.mult(baseSpeed);
    baseLength = random(30, 45);
    length = baseLength * gameState.potSize;
    active = true;
    missileColor = color(random(200, 255), 100, random(200, 255));
    hitboxRadius = length * 0.25f;
  }
  
  public void update() {
    if (!active) return;
    
    position.add(velocity);
    
    // Gentle wave motion
    velocity.y = sin(frameCount * 0.1f) * 2;
    
    // Update length based on current potSize
    length = baseLength * gameState.potSize;
    hitboxRadius = length * 0.25f;
    
    if (position.x < -length || position.x > width + length || 
        position.y < -length || position.y > height + length) {
      active = false;
    }
  }
  
  public void display() {
    if (!active) return;
    
    pushMatrix();
    translate(position.x, position.y);
    rotate(atan2(velocity.y, velocity.x));
    
    // Draw the magic missile shape
    noStroke();
    // Main body
    fill(missileColor);
    beginShape();
    vertex(-length/2, -length/6);
    vertex(length/2, 0);
    vertex(-length/2, length/6);
    endShape(CLOSE);
    
    // Glowing trail
    for (int i = 0; i < 3; i++) {
      float alpha = map(i, 0, 3, 200, 0);
      fill(missileColor, alpha);
      float offset = map(i, 0, 3, 0, -length/2);
      beginShape();
      vertex(-length/2 + offset, -length/8);
      vertex(-length/4 + offset, 0);
      vertex(-length/2 + offset, length/8);
      endShape(CLOSE);
    }
    
    if (debugMode) {
      noFill();
      stroke(255, 0, 0);
      ellipse(0, 0, hitboxRadius * 2, hitboxRadius * 2);
    }
    
    popMatrix();
  }
}
// WaveManager.pde
class WaveManager {
  int currentWave;
  int enemiesRemaining;
  boolean waveActive;
  float spawnTimer;
  float spawnInterval;
  float waveTransitionTimer;
  final float WAVE_TRANSITION_DELAY = 5.0f; // 5 seconds between waves
  ArrayList<Enemy> enemies;
  
  WaveManager() {
    currentWave = 0;
    waveActive = false;
    spawnTimer = 0;
    waveTransitionTimer = 0;
    spawnInterval = 1.0f;
    enemies = new ArrayList<Enemy>();
  }
  
  public void startFirstWave() {
    waveTransitionTimer = WAVE_TRANSITION_DELAY;
    currentWave = 0; // Will become 1 when startNextWave is called
  }
  
  public void update() {
    if (!waveActive) {
      // Handle wave transitions
      if (waveTransitionTimer > 0) {
        waveTransitionTimer -= 1.0f/frameRate;
        if (waveTransitionTimer <= 0) {
          startNextWave();
        }
      }
      return;
    }
    
    // Update spawn timer when wave is active
    if (spawnTimer > 0) {
      spawnTimer -= 1.0f/frameRate;
    }
    
    // Spawn enemies if timer is up and we have more to spawn
    if (spawnTimer <= 0 && enemiesRemaining > 0) {
      spawnNextEnemy();
      spawnTimer = spawnInterval;
    }
    
    // Update existing enemies
    updateEnemies();
    
    // Check if wave is complete
    if (enemiesRemaining == 0 && enemies.isEmpty()) {
      waveActive = false;
      if (currentWave < 6) { // Don't start timer after final wave
        waveTransitionTimer = WAVE_TRANSITION_DELAY;
      }
    }
  }
  
  public void startNextWave() {
    currentWave++;
    waveActive = true;
    spawnTimer = 0;
    waveTransitionTimer = 0;
    
    // Set up wave configuration
    switch(currentWave) {
      case 1:
        enemiesRemaining = 2; // 2 goblins
        spawnInterval = 1.0f;
        break;
      case 2:
        enemiesRemaining = 4; // 4 goblins
        spawnInterval = 0.8f;
        break;
      case 3:
        enemiesRemaining = 12; // 8 goblins + 4 bats
        spawnInterval = 0.7f;
        break;
      case 4:
        enemiesRemaining = 24; // 16 goblins + 8 bats
        spawnInterval = 0.6f;
        break;
      case 5:
        enemiesRemaining = 48; // 32 goblins + 16 bats
        spawnInterval = 0.5f;
        break;
      case 6:
        enemiesRemaining = 8; // 7 goblins + 1 dragon
        spawnInterval = 1.0f;
        break;
      default:
        // Game complete
        currentWave = 6;
        waveActive = false;
        return;
    }
  }
  
  public void spawnNextEnemy() {
    if (enemiesRemaining <= 0) return;
    
    float x = width + 50; // Spawn just off screen
    float y = random(100, height - 100);
    
    Enemy newEnemy = null;
    
    if (currentWave == 6) {
      // Final wave: dragon + goblins
      if (enemiesRemaining == 1) {
        newEnemy = new RedDragon(x, y);
      } else {
        newEnemy = new FlyingGoblin(x, y);
      }
    } else {
      // Normal waves
      if (currentWave >= 3) {
        // Waves 3-5 include bat swarms
        int totalEnemiesInWave = (currentWave == 3) ? 12 : (currentWave == 4) ? 24 : 48;
        if (enemiesRemaining <= totalEnemiesInWave/3) { // Spawn bats in last third of enemies
          newEnemy = new BatSwarm(x, y);
        } else {
          newEnemy = new FlyingGoblin(x, y);
        }
      } else {
        // Waves 1-2 only have goblins
        newEnemy = new FlyingGoblin(x, y);
      }
    }
    
    if (newEnemy != null) {
      enemies.add(newEnemy);
      enemiesRemaining--;
    }
  }
  
  public void updateEnemies() {
    for (int i = enemies.size() - 1; i >= 0; i--) {
      Enemy enemy = enemies.get(i);
      enemy.update();
      if (!enemy.isAlive()) {
        enemies.remove(i);
      }
    }
  }
  
  public void displayEnemies() {
    for (Enemy enemy : enemies) {
      enemy.display();
    }
  }
  
  public ArrayList<Enemy> getEnemies() {
    return enemies;
  }
  
  public boolean isWaveActive() {
    return waveActive;
  }
  
  public int getCurrentWave() {
    return currentWave;
  }
  
  public String getWaveStatus() {
    if (!waveActive) {
      if (currentWave == 0) {
        return String.format("First wave starting in %.1f seconds!", waveTransitionTimer);
      } else if (currentWave == 6 && enemiesRemaining == 0 && enemies.isEmpty()) {
        return "Congratulations! You've completed all waves!";
      } else {
        return String.format("Wave %d complete! Next wave in %.1f seconds", 
                           currentWave, waveTransitionTimer);
      }
    }
    return String.format("Wave %d - Enemies remaining: %d", 
                        currentWave, enemiesRemaining + enemies.size());
  }
}
// GameState.pde
class GameState {
  Wizard wizard;
  ArrayList<Fireball> fireballs;
  ArrayList<MagicMissile> missiles;
  WaveManager waveManager;
  int bgColor;
  
  // Pot control variables
  float potWizardY = 0.5f;
  float potSize = 1.0f;
  float potBackground = 0.0f;

  // Power Mode
  int killCount = 0;
  float powerMeter = 0;
  boolean powerModeActive = false;
  float powerModeTimer = 0;
  final int KILLS_FOR_POWER = 25; // Number of kills needed for power mode
  final float POWER_MODE_DURATION = 10.0f; // Duration in seconds
  
  GameState() {
    wizard = new Wizard(width/8, height/2);
    fireballs = new ArrayList<Fireball>();
    missiles = new ArrayList<MagicMissile>();
    waveManager = new WaveManager();
    bgColor = color(0, 0, 30);
    
    // Start the first wave automatically
    waveManager.startFirstWave();
  }

  public void registerKill() {
  killCount++;
  
  // Update power meter
  powerMeter = min(1.0f, (float)killCount / KILLS_FOR_POWER);
  
  // Check if we've reached the threshold to enable power mode
  if (killCount >= KILLS_FOR_POWER && !powerModeActive) {
    // We have enough kills to enable power mode when user activates it
    println("Power mode ready! Press 'P' to activate.");
  }
}

// Method to activate power mode
public void activatePowerMode() {
  if (killCount >= KILLS_FOR_POWER && !powerModeActive) {
    powerModeActive = true;
    powerModeTimer = POWER_MODE_DURATION;
    println("WIZARD POWER MODE ACTIVATED for " + POWER_MODE_DURATION + " seconds!");
    
    // Send OSC message to SuperCollider to inform about power mode activation
    oscP5.send(new OscMessage("/power_mode/start"), new NetAddress("127.0.0.1", 57120));
  } else if (powerModeActive) {
    println("Power mode already active! Time remaining: " + powerModeTimer);
  } else {
    println("Not enough power! Defeat " + (KILLS_FOR_POWER - killCount) + " more enemies.");
  }
}

// Method to deactivate power mode
public void deactivatePowerMode() {
  if (powerModeActive) {
    powerModeActive = false;
    println("Power mode deactivated.");
    
    // Send OSC message to SuperCollider to inform about power mode deactivation
    oscP5.send(new OscMessage("/power_mode/end"), new NetAddress("127.0.0.1", 57120));
  }
}
  
  public void handleOscMessage(OscMessage msg) {
    if (msg.checkAddrPattern("/fireball")) {
      int count = min(msg.get(0).intValue(), 3);
      for (int i = 0; i < count && fireballs.size() < MAX_FIREBALLS; i++) {
        createFireball();
      }
    }
    else if (msg.checkAddrPattern("/missile")) {
      int count = min(msg.get(0).intValue(), 6);
      for (int i = 0; i < count && missiles.size() < MAX_MISSILES; i++) {
        createMissile();
      }
    }
    else if (msg.checkAddrPattern("/potControl")) {
      handlePotControl(msg);
    }
  }
  
  public void handlePotControl(OscMessage msg) {
    int potIndex = msg.get(0).intValue();
    float value = msg.get(1).floatValue();
    
    switch(potIndex) {
      case 0:
        potWizardY = map(value, 0, 1, -1, 2);
        break;
      case 1:
        potSize = map(value, 0, 1, 0.2f, 8.0f);
        break;
      case 2:
        potBackground = value;
        updateBackgroundColor(value);
        break;
    }
  }
  
  public void updateBackgroundColor(float value) {
    float hue = map(value, 0, 1, 180, 360);
    float saturation = map(value, 0, 1, 30, 100);
    float brightness = map(value, 0, 1, 5, 60);
    colorMode(HSB, 360, 100, 100);
    bgColor = color(hue, saturation, brightness);
    colorMode(RGB, 255);
  }
  
  // Method to activate power mode
public void activatePowerMode() {
  if (killCount >= KILLS_FOR_POWER && !powerModeActive) {
    powerModeActive = true;
    powerModeTimer = POWER_MODE_DURATION;
    println("WIZARD POWER MODE ACTIVATED for " + POWER_MODE_DURATION + " seconds!");
    
    // Send OSC message to SuperCollider to inform about power mode activation
    oscP5.send(new OscMessage("/power_mode/start"), new NetAddress("127.0.0.1", 57120));
  } else if (powerModeActive) {
    println("Power mode already active! Time remaining: " + powerModeTimer);
  } else {
    println("Not enough power! Defeat " + (KILLS_FOR_POWER - killCount) + " more enemies.");
  }
}

// Method to deactivate power mode
public void deactivatePowerMode() {
  if (powerModeActive) {
    powerModeActive = false;
    println("Power mode deactivated.");
    
    // Send OSC message to SuperCollider to inform about power mode deactivation
    oscP5.send(new OscMessage("/power_mode/end"), new NetAddress("127.0.0.1", 57120));
  }
}
  
  public void updateProjectiles() {
    // Update and clean up fireballs
    for (int i = fireballs.size() - 1; i >= 0; i--) {
      Fireball f = fireballs.get(i);
      f.update();
      if (!f.active) fireballs.remove(i);
    }
    
    // Update and clean up missiles
    for (int i = missiles.size() - 1; i >= 0; i--) {
      MagicMissile m = missiles.get(i);
      m.update();
      if (!m.active) missiles.remove(i);
    }
  }
  
  public void checkCollisions() {
    ArrayList<Enemy> enemies = waveManager.getEnemies();
    
    // Check missile collisions
    for (MagicMissile missile : missiles) {
      if (!missile.active) continue;
      for (Enemy enemy : enemies) {
        if (enemy.isAlive() && enemy.checkCollision(missile.position, missile.hitboxRadius)) {
          enemy.takeDamage(1); // Magic missiles do 1 damage
          missile.active = false;
          break;
        }
      }
    }
    
    // Check fireball collisions
    for (Fireball fireball : fireballs) {
      if (!fireball.active) continue;
      for (Enemy enemy : enemies) {
        if (enemy.isAlive() && enemy.checkCollision(fireball.position, fireball.hitboxRadius)) {
          enemy.takeDamage(5); // Fireballs do 5 damage
          fireball.active = false;
          break;
        }
      }
    }
  }
  
  public void display() {
    // Display all game objects
    for (Fireball f : fireballs) f.display();
    for (MagicMissile m : missiles) m.display();
    waveManager.displayEnemies();
    wizard.display();
    
    // Display wave information
    fill(255);
    textAlign(CENTER, TOP);
    textSize(20);
    text(waveManager.getWaveStatus(), width/2, 30);
  }
  
  public void createFireball() {
    float x = wizard.position.x + FIREBALL_SPAWN_OFFSET.x;
    float y = wizard.position.y + FIREBALL_SPAWN_OFFSET.y;
    fireballs.add(new Fireball(x, y));
  }
  
  public void createMissile() {
    float x = wizard.position.x + MISSILE_SPAWN_OFFSET.x;
    float y = wizard.position.y + MISSILE_SPAWN_OFFSET.y;
    missiles.add(new MagicMissile(x, y));
  }
  
  public void clearProjectiles() {
    fireballs.clear();
    missiles.clear();
  }
  
  // Getter methods for debug display
  public int getFireballCount() { return fireballs.size(); }
  public int getMissileCount() { return missiles.size(); }
  public int getEnemyCount() { return waveManager.getEnemies().size(); }
  public float getWizardY() { return potWizardY; }
  public int getBgColor() { return bgColor; }
}
// Wizard.pde
class Wizard {
  PVector position;
  
  Wizard(float x, float y) {
    position = new PVector(x, y);
  }
  
  public void update() {
    float targetY = map(gameState.potWizardY, -1, 2, 0, height);
    position.y = constrain(targetY, 20, height - 20); // Light padding to keep sprite visible
  }
  
  public void display() {
  pushMatrix();
  translate(position.x, position.y);
  scale(-1, 1);
  
  if (wizardImg != null) {
    // Add a visual effect when power mode is active
    if (gameState.powerModeActive) {
      // Add a glowing effect around the wizard
      noStroke();
      fill(255, 150, 0, 150); // Orange glow
      ellipse(0, 0, 250, 250); // Larger than the wizard image
      
      // Could change to a different image here when available
      // For now, just change the tint
      tint(255, 220, 100); // Yellow tint
    }
    
    image(wizardImg, 0, 0);
    noTint(); // Reset tint
  } else {
    // Fallback shape
    fill(100);
    if (gameState.powerModeActive) {
      fill(255, 150, 0); // Orange for power mode
    }
    noStroke();
    ellipse(0, 0, 50, 100);
  }
}


  public void settings() { size(1024, 768, P2D); }

  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "wizardcore" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
