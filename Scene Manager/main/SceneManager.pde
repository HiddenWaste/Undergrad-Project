// main/SceneManager.pde
class SceneManager {
  private HashMap<String, Scene> scenes;
  private Scene currentScene;
  private String currentSceneName;
  
  SceneManager() {
    scenes = new HashMap<String, Scene>();
  }
  
  void addScene(String name, Scene scene) {
    scenes.put(name, scene);
    println("Added scene: " + name);
  }
  
  void switchToScene(String name) {
    if (scenes.containsKey(name)) {
      println("Switching to scene: " + name);
      if (currentScene != null) {
        currentScene.cleanup();
      }
      currentScene = scenes.get(name);
      currentSceneName = name;
      currentScene.init(width, height);
    } else {
      println("Scene not found: " + name);
    }
  }
  
  String getCurrentSceneName() {
    return currentSceneName;
  }
  
  String[] getSceneNames() {
    return scenes.keySet().toArray(new String[0]);
  }
  
  void update() {
    if (currentScene != null) {
      currentScene.update();
    }
  }
  
  void draw() {
    if (currentScene != null) {
      currentScene.draw();
      image(currentScene.buffer, 0, 0);
    }
  }
}