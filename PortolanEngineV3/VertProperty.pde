class VertProperty {
  boolean boundary;
  java.util.ArrayList<Integer> adj;
  GPoint center;
  float radius;

  VertProperty() {
    boundary = false;
    adj = new java.util.ArrayList<Integer>();
  }
}
