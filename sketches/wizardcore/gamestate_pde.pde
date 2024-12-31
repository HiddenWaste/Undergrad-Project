// GameState.pde
class GameState {
  Wizard wizard;
  ArrayList<Fireball> fireballs;
  ArrayList<MagicMissile> missiles;
  WaveManager waveManager;
  color bgColor;
  
  // Pot control variables
  float potWizardY = 0.5;
  float potSize = 1.0;
  float potBackground = 0.0;
  
  GameState() {
    wizard = new Wizard(width/8, height/2);
    fireballs = new ArrayList<Fireball>();
    missiles = new ArrayList<MagicMissile>();
    waveManager = new WaveManager();
    bgColor = color(0, 0, 30);
    
    // Start the first wave automatically
    waveManager.startFirstWave();
  }
  
  void handleOscMessage(OscMessage msg) {
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
  
  void handlePotControl(OscMessage msg) {
    int potIndex = msg.get(0).intValue();
    float value = msg.get(1).floatValue();
    
    switch(potIndex) {
      case 0:
        potWizardY = map(value, 0, 1, -1, 2);
        break;
      case 1:
        potSize = map(value, 0, 1, 0.2, 8.0);
        break;
      case 2:
        potBackground = value;
        updateBackgroundColor(value);
        break;
    }
  }
  
  void updateBackgroundColor(float value) {
    float hue = map(value, 0, 1, 180, 360);
    float saturation = map(value, 0, 1, 30, 100);
    float brightness = map(value, 0, 1, 5, 60);
    colorMode(HSB, 360, 100, 100);
    bgColor = color(hue, saturation, brightness);
    colorMode(RGB, 255);
  }
  
  void update() {
    wizard.update();
    updateProjectiles();
    waveManager.update();
    checkCollisions();
  }
  
  void updateProjectiles() {
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
  
  void checkCollisions() {
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
  
  void display() {
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
  
  void createFireball() {
    float x = wizard.position.x + FIREBALL_SPAWN_OFFSET.x;
    float y = wizard.position.y + FIREBALL_SPAWN_OFFSET.y;
    fireballs.add(new Fireball(x, y));
  }
  
  void createMissile() {
    float x = wizard.position.x + MISSILE_SPAWN_OFFSET.x;
    float y = wizard.position.y + MISSILE_SPAWN_OFFSET.y;
    missiles.add(new MagicMissile(x, y));
  }
  
  void clearProjectiles() {
    fireballs.clear();
    missiles.clear();
  }
  
  // Getter methods for debug display
  int getFireballCount() { return fireballs.size(); }
  int getMissileCount() { return missiles.size(); }
  int getEnemyCount() { return waveManager.getEnemies().size(); }
  float getWizardY() { return potWizardY; }
  color getBgColor() { return bgColor; }
}
