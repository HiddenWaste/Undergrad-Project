// WaveManager.pde
class WaveManager {
  int currentWave;
  int enemiesRemaining;
  boolean waveActive;
  float spawnTimer;
  float spawnInterval;
  float waveTransitionTimer;
  final float WAVE_TRANSITION_DELAY = 5.0; // 5 seconds between waves
  ArrayList<Enemy> enemies;
  
  WaveManager() {
    currentWave = 0;
    waveActive = false;
    spawnTimer = 0;
    waveTransitionTimer = 0;
    spawnInterval = 1.0;
    enemies = new ArrayList<Enemy>();
  }
  
  void startFirstWave() {
    waveTransitionTimer = WAVE_TRANSITION_DELAY;
    currentWave = 0; // Will become 1 when startNextWave is called
  }
  
  void update() {
    if (!waveActive) {
      // Handle wave transitions
      if (waveTransitionTimer > 0) {
        waveTransitionTimer -= 1.0/frameRate;
        if (waveTransitionTimer <= 0) {
          startNextWave();
        }
      }
      return;
    }
    
    // Update spawn timer when wave is active
    if (spawnTimer > 0) {
      spawnTimer -= 1.0/frameRate;
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
  
  void startNextWave() {
    currentWave++;
    waveActive = true;
    spawnTimer = 0;
    waveTransitionTimer = 0;
    
    // Set up wave configuration
    switch(currentWave) {
      case 1:
        enemiesRemaining = 2; // 2 goblins
        spawnInterval = 1.0;
        break;
      case 2:
        enemiesRemaining = 4; // 4 goblins
        spawnInterval = 0.8;
        break;
      case 3:
        enemiesRemaining = 12; // 8 goblins + 4 bats
        spawnInterval = 0.7;
        break;
      case 4:
        enemiesRemaining = 24; // 16 goblins + 8 bats
        spawnInterval = 0.6;
        break;
      case 5:
        enemiesRemaining = 48; // 32 goblins + 16 bats
        spawnInterval = 0.5;
        break;
      case 6:
        enemiesRemaining = 8; // 7 goblins + 1 dragon
        spawnInterval = 1.0;
        break;
      default:
        // Game complete
        currentWave = 6;
        waveActive = false;
        return;
    }
  }
  
  void spawnNextEnemy() {
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
  
  void updateEnemies() {
    for (int i = enemies.size() - 1; i >= 0; i--) {
      Enemy enemy = enemies.get(i);
      enemy.update();
      if (!enemy.isAlive()) {
        enemies.remove(i);
      }
    }
  }
  
  void displayEnemies() {
    for (Enemy enemy : enemies) {
      enemy.display();
    }
  }
  
  ArrayList<Enemy> getEnemies() {
    return enemies;
  }
  
  boolean isWaveActive() {
    return waveActive;
  }
  
  int getCurrentWave() {
    return currentWave;
  }
  
  String getWaveStatus() {
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
