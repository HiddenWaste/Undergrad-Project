// main/Scene.pde
abstract class Scene {
  protected PGraphics buffer;
  protected boolean isInitialized = false;
  
  void init(int w, int h) {
    if (!isInitialized) {
      buffer = createGraphics(w, h, P2D);
      setup();
      isInitialized = true;
    }
  }
  
  abstract void setup();
  abstract void update();
  abstract void draw();
  abstract void cleanup();
}