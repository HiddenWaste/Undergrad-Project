import oscP5.*;
import netP5.*;

// main/main.pde
SceneManager sceneManager;

void setup() {
  size(800, 600, P2D);
  sceneManager = new SceneManager();
  
  // Manually register scenes
  // This is more reliable in Processing than dynamic loading
  sceneManager.addScene("BouncingBall", new BouncingBall());
  sceneManager.addScene("Vaporwave", new Vaporwave());
  sceneManager.addScene("FloweringFractal", new FloweringFractal());
  sceneManager.addScene("TanWave", new TanWaveScene());
  
  // Start with default scene
  sceneManager.switchToScene("BouncingBall");
}

void draw() {
  sceneManager.update();
  sceneManager.draw();
  
  // Debug info
  fill(255);
  textSize(16);
  text("FPS: " + (int)frameRate, 10, 20);
  text("Press 1-3 to switch scenes", 10, 40);
  text("Current scene: " + sceneManager.getCurrentSceneName(), 10, 60);
}

void keyPressed() {
  switch(key) {
    case '1': sceneManager.switchToScene("BouncingBall"); break;
    case '2': sceneManager.switchToScene("Vaporwave"); break;
    case '3': sceneManager.switchToScene("FloweringFractal"); break;
    case '4': sceneManager.switchToScene("TanWave"); break;
  }
}
