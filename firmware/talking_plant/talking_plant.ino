#include "src/PlantContract.h"
#include "src/PlantReadingEncoder.h"

void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 2000) {
  }
  Serial.println("[boot] talking_plant skeleton");
}

void loop() {
  delay(1000);
}
